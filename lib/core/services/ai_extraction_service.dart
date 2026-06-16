import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/sistem_ayarlari_model.dart';
import 'sistem_ayarlari_service.dart';

class AIExtractionService {
  final SistemAyarlariService _ayarlarService = SistemAyarlariService();

  Future<List<Map<String, dynamic>>> extractBatchData(
    String rawBatchText, {
    List<int>? pdfBytes,
  }) async {
    final ayarlar = await _ayarlarService.getAyarlar();

    // Prompt hazırlığı
    final prompt = _buildPrompt(rawBatchText);

    // 1. GEMINI DENEMESİ (Farklı Modellerle Auto-Healing)
    if (ayarlar.geminiApiKey.isNotEmpty) {
      // Uzun süre desteklenecek (LTS) güncel ve stabil modeller
      final denemeModelleri = [
        'gemini-1.5-flash',     // En hızlı ve maliyetsiz, varsayılan (Multimodal)
        'gemini-1.5-pro',       // Daha yavaş ama çok daha zeki (Multimodal)
        'gemini-1.5-flash-8b'   // Çok hafif ve hızlı alternatif
      ];
      
      int deneme = 0;
      
      while (deneme < denemeModelleri.length) {
        final seciliModel = denemeModelleri[deneme];
        try {
          print('Gemini API ($seciliModel) ile ayrıştırma deneniyor... (Deneme: ${deneme + 1})');
          final model = GenerativeModel(
            model: seciliModel,
            apiKey: ayarlar.geminiApiKey,
          );
          
          final contentParts = <Part>[];
          if (pdfBytes != null && pdfBytes.isNotEmpty) {
            contentParts.add(DataPart('application/pdf', pdfBytes));
          }
          contentParts.add(TextPart(prompt));

          final response = await model.generateContent([Content.multi(contentParts)]);
          final text = response.text?.trim() ?? '';

          final parsed = _parseJson(text);
          if (parsed.isNotEmpty) {
            for (var p in parsed) {
              p['parsedBy'] = 'Tier 1 - $seciliModel (Başarılı)';
            }
            return parsed;
          } else if (text.isNotEmpty) {
            print('$seciliModel JSON formatı boş döndürdü, diğer modele geçiliyor...');
          }
        } catch (e) {
          print('$seciliModel hatası: $e');
        }
        
        deneme++;
        if (deneme < denemeModelleri.length) {
          // Çok kısa bir nefes alma payı
          await Future.delayed(const Duration(seconds: 2));
        }
      }
      print('Tüm Gemini modelleri (Flash ve Pro) başarısız oldu. DeepSeek/Offline yedeğe geçiliyor.');
    }

    // 2. DEEPSEEK DENEMESİ (Fallback)
    if (ayarlar.deepseekApiKey.isNotEmpty &&
        ayarlar.deepseekApiUrl.isNotEmpty) {
      try {
        print('DeepSeek API ile ayrıştırma deneniyor...');
        final url = ayarlar.deepseekApiUrl.endsWith('/')
            ? '${ayarlar.deepseekApiUrl}chat/completions'
            : '${ayarlar.deepseekApiUrl}/chat/completions';
        final modelName = ayarlar.deepseekModel.isEmpty
            ? 'deepseek-chat'
            : ayarlar.deepseekModel;

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
                'content':
                    'You are a precise invoice parsing AI that outputs strictly in JSON.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.1,
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          final content = decoded['choices']?[0]?['message']?['content'] ?? '';

          final parsed = _parseJson(content);
          if (parsed.isNotEmpty) {
            for (var p in parsed) {
              p['parsedBy'] = 'Tier 2 - DeepSeek Fallback (Başarılı)';
            }
            return parsed;
          }
        } else {
          print(
            'DeepSeek API Hatası: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e) {
        print('DeepSeek hatası: $e');
      }
    }

    // Tüm AI denemeleri başarısızsa boş dön
    throw Exception(
      'Yapay zeka faturayı okuyamadı. Lütfen API anahtarlarını kontrol edin.',
    );
  }

  String _buildPrompt(String rawText) {
    return '''
Aşağıdaki metin ham bir analiz faturası / makbuzu dökümüdür.
Lütfen bu metinden faturadaki kalemleri ve temel bilgileri çıkart.

Benden beklenen JSON formatı SADECE aşağıdaki gibi bir LİSTE (Array) olmalıdır:
[
  {
    "id": "Rastgele benzersiz bir ID (1, 2, 3 gibi)",
    "firmaAdi": "Müşterinin / Firmanın tam adı",
    "vergiDairesi": "Vergi Dairesi",
    "vergiNo": "Vergi veya TC No",
    "tarih": "Fatura veya İşlem Tarihi (DD.MM.YYYY vb. formatta)",
    "irsaliyeNo": "İrsaliye Numarası",
    "melbesNo": "Melbes numarası",
    "numuneNo": "Numune Numarası",
    "numuneAciklamasi": "Varsa numune açıklaması",
    "tahminiBirim": "Belgeden anlaşılan Şube/Birim adı (TÖMER, UBATAM, TARIMSAL, SATIN ALMA vb.)",
    "hizmetTipi": "EĞİTİM|DANIŞMANLIK|SATIŞ|ANALİZ|TEKSTİL_TASARIM|DİĞER",
    "kursAdi": "kurs/program adı (TÖMER/USEM ise)",
    "kurNo": (Sayısal, varsa),
    "odemeTipi": "KUR_FATURA|STS_FATURA|KATKI_PAYI|AVANS|DİĞER",
    "ytbOgrencisi": (true/false, kursiyer YTB'liyse),
    "urunTuru": "YUMURTA|BAL|TAVUK|DİĞER (tarımsal ise)",
    "tedarikYontemi": "TEK_KAYNAK|İHALE|PAZARLIK|DİĞER (satın alma ise)",
    "donem": "Ocak 2025 gibi dönem bilgisi",
    "aciklama": "serbest genel açıklama",
    "matrah": KDV Hariç toplam tutar (Sayısal),
    "kdvTutari": KDV tutarı (Sayısal, eğer 0 ise kdvMuaf demektir),
    "genelToplam": KDV dahil toplam tutar (Sayısal),
    "isKdvMuaf": (KDV 0 ise true, değilse false),
    "kalemler": [
      {
        "cinsi": "Kalem Adı",
        "miktar": Adet (sayısal),
        "fiyat": Birim fiyat veya o kalemin satır tutarı (sayısal)
      }
    ]
  }
]

ÖNEMLİ KURALLAR:
1. SADECE JSON ÇIKTISI VER. Yorum yapma, açıklamalar ekleme, markdown tickleri (```json) ekleme veya başa/sona yazı koyma!
2. Faturadaki HER BİR HİZMET VEYA ÜRÜN KALEMİNİ eksiksiz olarak 'kalemler' dizisine ayrı bir obje olarak ekle. Hiçbir kalemi atlama veya birleştirme. Faturada ne kadar kalem varsa hepsi dizide olmalı!
3. Faturada birden fazla müşteri verisi varsa liste içine birden fazla obje koy.
4. "kalemler" listesinde, "fiyat" kısmına virgülleri noktaya çevirerek bir Number koy (örn: 1540.50). 
5. DİKKAT: Eğer bir alana dair veri (örneğin Melbes No, Numune No, İrsaliye No) belgede YOKSA, KESİNLİKLE uydurma yapma ve o alanı boş string ("") olarak bırak. Sadece metinde net olarak geçen değerleri kullan.

Ham Fatura Metni:
$rawText
''';
  }

  /// Uzun Excel listeleri (örn: 200 kişilik kursiyer listesi) için sadece başlık haritası çıkarır
  Future<Map<String, dynamic>> extractExcelMapping(
    String excelCsvPreview,
  ) async {
    final ayarlar = await _ayarlarService.getAyarlar();

    final prompt =
        '''
Aşağıda bir Excel dosyasının ilk 15 satırının CSV dökümü bulunuyor.
Bu dosya bir müşteri/kursiyer listesi olabilir. Lütfen satırlara bakarak, hangi sütunun hangi faturasal veriye denk geldiğini bul.
Sütun endeksleri 0'dan başlar (Yani ilk sütun 0'dır).

Çıktın SADECE JSON olacak ve şu formatta olacak:
{
  "isBatchList": true,
  "startRowIndex": 1, // Verilerin gerçekte başladığı satır (başlıkları atlayarak)
  "mapping": {
    "firmaAdi": 0,    // Müşteri Adı / Firma Adının olduğu sütun numarası
    "tcVkn": 1,       // TC Kimlik / VKN'nin olduğu sütun numarası (yoksa -1)
    "matrah": 4       // KDV hariç tutarın (veya ödenen toplam tutarın) olduğu sütun numarası
  }
}

Eğer bu dosya bir toplu müşteri listesi değil de, düz bir fatura şablonuysa "isBatchList": false döndür. SADECE JSON döndür.

CSV Önizleme:
$excelCsvPreview
''';

    if (ayarlar.geminiApiKey.isNotEmpty) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: ayarlar.geminiApiKey,
        );
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim() ?? '';
        final parsed = _parseJsonStrict(text);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (e) {
        print('Mapping hatası: $e');
      }
    }

    // Fallback or not found
    return {"isBatchList": false};
  }

  dynamic _parseJsonStrict(String text) {
    String cleanText = text.trim();
    if (cleanText.startsWith('```json'))
      cleanText = cleanText.substring(7);
    else if (cleanText.startsWith('```'))
      cleanText = cleanText.substring(3);
    if (cleanText.endsWith('```'))
      cleanText = cleanText.substring(0, cleanText.length - 3);
    cleanText = cleanText.trim();
    try {
      return jsonDecode(cleanText);
    } catch (e) {
      return {};
    }
  }

  List<Map<String, dynamic>> _parseJson(String text) {
    try {
      String cleanText = text.trim();

      // Bazen LLM ```json ... ``` etiketleri ekler, onları temizle.
      if (cleanText.startsWith('```json')) {
        cleanText = cleanText.substring(7);
      } else if (cleanText.startsWith('```')) {
        cleanText = cleanText.substring(3);
      }

      if (cleanText.endsWith('```')) {
        cleanText = cleanText.substring(0, cleanText.length - 3);
      }

      cleanText = cleanText.trim();

      int startIndex = cleanText.indexOf('[');
      int endIndex = cleanText.lastIndexOf(']');

      if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
        cleanText = cleanText.substring(startIndex, endIndex + 1);
        final List<dynamic> decodedList = jsonDecode(cleanText);
        return List<Map<String, dynamic>>.from(decodedList);
      }
    } catch (e) {
      print('JSON Parse hatası: $e');
    }
    return [];
  }

  /// Yürütme Kurulu Kararı (YKK) metninden akademik personel ve faaliyet verilerini çeker
  Future<List<Map<String, dynamic>>> extractDanismanlikData(
    String rawKararText,
  ) async {
    final ayarlar = await _ayarlarService.getAyarlar();

    // Prompt hazırlığı
    final prompt = _buildDanismanlikPrompt(rawKararText);

    // GEMINI DENEMESİ
    if (ayarlar.geminiApiKey.isNotEmpty) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: ayarlar.geminiApiKey,
        );
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim() ?? '';

        final parsed = _parseJson(text);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      } catch (e) {
        print('Gemini danışmanlık hatası: $e');
      }
    }

    // DEEPSEEK DENEMESİ
    if (ayarlar.deepseekApiKey.isNotEmpty &&
        ayarlar.deepseekApiUrl.isNotEmpty) {
      try {
        final url = ayarlar.deepseekApiUrl.endsWith('/')
            ? '${ayarlar.deepseekApiUrl}chat/completions'
            : '${ayarlar.deepseekApiUrl}/chat/completions';
        final modelName = ayarlar.deepseekModel.isEmpty
            ? 'deepseek-chat'
            : ayarlar.deepseekModel;

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
                'content':
                    'You are a precise data extraction AI that outputs strictly in JSON.',
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.1,
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          final content = decoded['choices']?[0]?['message']?['content'] ?? '';

          final parsed = _parseJson(content);
          if (parsed.isNotEmpty) {
            return parsed;
          }
        }
      } catch (e) {
        print('DeepSeek danışmanlık hatası: $e');
      }
    }

    throw Exception(
      'Yapay zeka kararı okuyamadı. Lütfen API anahtarlarını veya kararın metnini kontrol edin.',
    );
  }

  String _buildDanismanlikPrompt(String rawText) {
    return '''
Aşağıdaki metin bir Üniversite Yönetim/Yürütme Kurulu Kararı (YKK) metnidir.
Bu metin, genellikle bir 'Danışmanlık' veya 'Döner Sermaye Projesi' kapsamında akademisyenlerin hangi faaliyetleri kaç adet veya saat yaptığını gösterir.

Lütfen bu metinden akademisyenlerin listesini ve yaptıkları faaliyetleri çıkart.
Aynı kişinin birden fazla faaliyeti varsa, JSON içerisinde aynı kişinin ismini kullanarak farklı bir obje (satır) olarak ekle.

Benden beklenen JSON formatı SADECE aşağıdaki gibi bir LİSTE (Array) olmalıdır:
[
  {
    "adSoyad": "Öğretim elemanının unvanı ve adı soyadı (Örn: Öğr. Gör. Dr. Neslihan ÖPÖZ VURAL)",
    "unvan": "Kısa Unvan (Örn: Profesör, Doçent, Dr.Öğr.Üyesi, Öğr.Gör.Dr., Öğr.Gör., Arş.Gör.Dr., Arş.Gör.)",
    "faaliyetTuru": "Yapılan İşin Adı (Örn: Eğitim, Tasarım, 3 Boyutlu Görsel Hazırlama, Teknik Uygulama)",
    "faaliyetAdeti": Miktar (Saat veya Adet değeri, sayısal, örn: 15),
    "faaliyetTabanPuani": Metinde geçiyorsa o faaliyetin taban puanı (sayısal, örn: 20. Eğer metinde yazmıyorsa 0 ver),
    "mesaiIci": true veya false (Metinde 'mesai dışı' veya '%60 artırımlı' geçmiyorsa varsayılan olarak true ver)
  }
]

ÖNEMLİ KURALLAR:
1. SADECE JSON ÇIKTISI VER. Yorum yapma.
2. Unvan kısmını tam metinden süzüp standart kısa hallerinden birini (Profesör, Doçent, Dr.Öğr.Üyesi, Öğr.Gör.Dr., Öğr.Gör., Arş.Gör.Dr., Arş.Gör.) eşleştir.
3. Fiyat, para birimi, oran gibi verileri değil sadece FAALİYET ADETİ/SAATİ ve PUANI bilgilerini çek.

Ham Karar Metni:
$rawText
''';
  }
}
