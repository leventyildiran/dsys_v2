import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../models/yk_karar_model.dart';
import '../models/gundem_model.dart';
import 'package:http/http.dart' as http;

class GundemParserService {
  /// PDF byte dizisini metne çevirir.
  Future<String> _extractTextFromPdf(Uint8List pdfBytes) async {
    try {
      final document = PdfDocument(inputBytes: pdfBytes);
      final textExtractor = PdfTextExtractor(document);
      final text = textExtractor.extractText();
      document.dispose();
      return text;
    } catch (e) {
      debugPrint('PDF Okuma Hatası: $e');
      throw Exception('PDF dosyası okunamadı veya bozuk.');
    }
  }

  /// PDF dosyasını okuyup, yapay zekaya göndererek doğrudan bir YK Kararı taslağı üretir.
  Future<YkKararModel> analizEtVeKararUret({
    required Uint8List pdfBytes,
    required String birimAd,
  }) async {
    final pdfText = await _extractTextFromPdf(pdfBytes);
    
    if (pdfText.trim().isEmpty) {
      throw Exception('PDF içerisinden hiçbir metin bulunamadı. Lütfen taranmış resim (fotoğraf) yerine metin tabanlı bir PDF yükleyin.');
    }

    final prompt = '''
Sen "Döner Sermaye Yürütme Kurulu Karar Raportörü"sün. Aşağıdaki metin, kurumun "${birimAd}" isimli biriminden gelen resmi bir üst yazı, talep veya karar tutanağıdır.
Senin görevin, bu metni analiz edip resmi bir "Yürütme Kurulu Karar Metni" (Microsoft Word'de yazılabilecek formatlı) oluşturmaktır.

ÇOK ÖNEMLİ KURALLAR:
1. Gelen metinde BİRDEN FAZLA karar maddesi varsa (Örn: 2026/12, 2026/13), HİÇBİRİNİ ATLAMA. Hepsini TEK BİR karar metninin içine, Markdown başlıkları (### KARAR NO: ...) ile alt alta yaz.
2. Her kararın arasına boşluk ve yatay çizgi (`---`) koy.
3. KESİNLİKLE AŞAĞIDAKİ ŞABLON CÜMLE YAPILARINI KULLAN! Gelen derme çatma metinleri bu resmi formata dönüştür.
4. Kişilerin, unvanların ve puanların/ücretlerin olduğu listeleri KESİNLİKLE Markdown tablosu ( | Adı Soyadı | Puan | ) olarak oluştur.
5. TABLO KURALLARI: PDF'teki orijinal tabloları BİREBİR kopyala. Hiçbir satırı veya sütunu atlama! Eğer hücre (cell) boşsa bile Markdown'da o hücreyi karşılık gelecek şekilde boş bırak ( | | ). Hücreleri kaydırma, kısaltma yapma. Orijinal tablo neyse Markdown'a aynen aktar.

--- ÖRNEK ŞABLONLAR (BU DİLİ VE YAPIYI BİREBİR KULLAN) ---

Örnek 1 (Danışmanlık - Tablolu):
### KARAR NO: 2026/12
Orhan Şaşmaz Tekstil İnşaat Turizm Sanayi ve Ticaret Ltd. Şti. firmasının talep ettiği "Danışmanlık Hizmeti" için 1 aylık süreyle görevlendirilen öğretim elemanının katkı oranlarının aşağıdaki şekilde belirlenmesine oy birliği ile karar verilmiştir.
| Adı Soyadı | Faaliyet Türü | Adet/Saat |
|---|---|---|
| Öğr. Gör. Dr. Neslihan ÖPÖZ VURAL | Tasarım | 20 Adet |
| Öğr. Gör. Dr. Neslihan ÖPÖZ VURAL | Teknik Uygulama | 20 Saat |

Örnek 2 (Danışmanlık - Düz Tutar):
### KARAR NO: 2026/14
Tantanlar Tekstil firmasının talep ettiği "Yapay Zekâ Fotoğrafçılığı Hizmeti" için Öğr. Gör. Fatih AYTEKİN’in görevlendirilmesine ve 67.500,00 TL + KDV hizmet bedelinin Döner Sermaye Yürütme Kuruluna sunulmasına oy birliği ile karar verilmiştir.

Örnek 3 (Ek Ödeme):
### KARAR NO:
Üniversitemiz Ağız ve Diş Sağlığı Uygulama ve Araştırma Merkezi Müdürlüğü’nün 08.05.2026 tarih ve E-79337011-840-348572 sayılı yazısı ile gönderilen; 07.05.2026 tarih, 22 toplantı sayılı ve ekli Fakülte Yönetim Kurulu Kararı ile teklif edilen; 2026 mali yılı içerisinde Merkez hesabında toplanan döner sermaye gelirleri bakiyesinden ilgili dönem için; Merkezde görevli akademik ve idari personellere dağıtılacak ek ödeme, yönetici payı ve mesai dışı ücretli tedavi ödemesinin ... Yönergesi gereğince uygun olduğuna oy birliği ile karar verilmiştir.

--------------------------------------------------------

Sadece JSON döndür. JSON nesnesinin "kararMetni" alanına tüm kararları birleştirip yaz.

Çıktı Formatı (JSON):
{
  "baslik": "Kısa ve öz genel başlık (Örn: Çeşitli Danışmanlık Görevlendirmeleri)",
  "kararMetni": "Oluşturduğun resmi ve tam karar metni (İçinde markdown tabloları barındıran)",
  "tur": "danismanlik"
}

Gelen PDF Metni:
$pdfText
''';

    final ayarlar = await SistemAyarlariService().getAyarlar();
    
    if (ayarlar.geminiApiKey.isEmpty && ayarlar.deepseekApiKey.isEmpty) {
      throw Exception('Gemini veya DeepSeek API Anahtarı bulunamadı. Lütfen Sistem Ayarları sayfasından en az bir API anahtarı girin.');
    }

    String jsonText = '';

    // 1. GEMINI DENEMESİ
    if (ayarlar.geminiApiKey.isNotEmpty) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: ayarlar.geminiApiKey,
        );
        final response = await model.generateContent([Content.text(prompt)]);
        jsonText = response.text?.trim() ?? '';
      } catch (e) {
        debugPrint('Gemini Analiz Hatası: $e');
      }
    }

    // 2. DEEPSEEK YEDEK
    if (jsonText.isEmpty && ayarlar.deepseekApiKey.isNotEmpty) {
      try {
        final apiUrl = ayarlar.deepseekApiUrl.isEmpty ? 'https://api.deepseek.com/' : ayarlar.deepseekApiUrl;
        final url = apiUrl.endsWith('/')
            ? '${apiUrl}chat/completions'
            : '${apiUrl}/chat/completions';
        final modelName = ayarlar.deepseekModel.isEmpty ? 'deepseek-chat' : ayarlar.deepseekModel;

        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer ${ayarlar.deepseekApiKey}',
          },
          body: jsonEncode({
            'model': modelName,
            'messages': [
              {
                'role': 'system',
                'content': 'You are a precise YK Karar (Board Decision) parsing AI that outputs strictly in JSON.',
              },
              {'role': 'user', 'content': prompt}
            ],
            'temperature': 0.1,
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          jsonText = decoded['choices']?[0]?['message']?['content'] ?? '';
        } else {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
      } catch (e) {
        debugPrint('DeepSeek Analiz Hatası: $e');
        throw Exception('DeepSeek Hatası: $e');
      }
    }

    if (jsonText.isEmpty) {
      throw Exception('Yapay zeka analiz yaparken bir hata oluştu veya API bağlantısı kurulamadı.');
    }

    try {
      // JSON formatını güvenli hale getir
      final startIndex = jsonText.indexOf('{');
      final endIndex = jsonText.lastIndexOf('}');
      if (startIndex != -1 && endIndex != -1) {
        jsonText = jsonText.substring(startIndex, endIndex + 1);
      }

      final Map<String, dynamic> data = jsonDecode(jsonText);
      
      YkKararTuru tur;
      switch (data['tur']) {
        case 'danismanlik': tur = YkKararTuru.danismanlik; break;
        case 'butceAktarim': tur = YkKararTuru.butceAktarim; break;
        case 'ekOdeme': tur = YkKararTuru.disHekimligi; break;
        default: tur = YkKararTuru.diger;
      }

      return YkKararModel(
        id: '',
        toplantiId: '',
        toplantiNo: '',
        kararNo: '',
        baslik: data['baslik'] ?? 'Birim Kararı',
        kararMetni: data['kararMetni'] ?? '',
        birimAd: birimAd,
        birimId: '',
        iliskiliKayitId: '',
        kararTarihi: DateTime.now().toIso8601String().split('T')[0],
        tur: tur,
        durum: YkKararDurum.taslak,
        olusturmaTarihi: DateTime.now(),
      );
    } catch (e) {
      debugPrint('JSON Çözümleme Hatası: $e');
      throw Exception('Yapay zeka çıktısı işlenirken hata oluştu: $e');
    }
  }

  /// Eski ekranla (Gündem Yönetimi) uyumluluk için PDF metni çıkarma mock metodu
  String pdfMetniCikar(Uint8List bytes) {
    // Şimdilik sadece dummy veri dönüyoruz, ileride Gündem Yönetimi güncellendiğinde kalkacak
    return 'Gündem 1: Deneme maddesi';
  }

  /// Eski ekranla uyumluluk için Gündem ayrıştırma mock metodu
  List<GundemMaddesi> metniGundemMaddelerineAyristir(String text) {
    return [
      GundemMaddesi(siraNo: 1, baslik: text, tur: GundemTuru.diger)
    ];
  }
}
