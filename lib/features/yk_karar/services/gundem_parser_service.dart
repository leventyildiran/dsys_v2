import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../../../core/models/sistem_ayarlari_model.dart';
import '../models/yk_karar_model.dart';
import '../models/gundem_model.dart';
import '../../../core/models/sablon_model.dart';
import 'yk_karar_eslestirme_servisi.dart';
import 'docx_sablon_servisi.dart';
import 'pdf_kalite_servisi.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:http/http.dart' as http;

class GundemParserService {
  final YkKararEslestirmeServisi _eslestirme = YkKararEslestirmeServisi();
  final DocxSablonServisi _docxSablon = DocxSablonServisi();
  final PdfKaliteServisi _pdfKalite = PdfKaliteServisi();

  /// AI'a gidecek maksimum toplam örnek (1 ana + 1 yardımcı).
  static const int maxAiOrnekSayisi = 2;

  /// PDF → AI (varsa) → otomatik eşleştirme yedek zinciri ile karar üretir.
  Future<KararAnalizSonucu> analizEtVeKararUret({
    required Uint8List pdfBytes,
    required String birimAd,
    required String birimId,
    List<SablonModel>? birimeOzelSablonlar,
    List<YkKararModel>? gecmisKararlar,
    SablonModel? kararSablon,
  }) async {
    final kalite = await _pdfKalite.denetle(
      pdfBytes: pdfBytes,
      kararSablon: kararSablon,
    );

    if (!kalite.gecerli) {
      throw Exception(kalite.hatalar.join('\n'));
    }

    final pdfText = kalite.pdfText;
    final tumUyarilar = List<String>.from(kalite.uyarilar);

    final gecmis = gecmisKararlar ?? [];
    final ayarlar = await SistemAyarlariService().getAyarlar();
    final aiMevcut =
        ayarlar.geminiApiKey.isNotEmpty || ayarlar.deepseekApiKey.isNotEmpty;

    if (aiMevcut) {
      try {
        final karar = await _analizWithAi(
          pdfText: pdfText,
          birimAd: birimAd,
          birimId: birimId,
          birimeOzelSablonlar: birimeOzelSablonlar,
          gecmisKararlar: gecmis,
          kararSablon: kararSablon,
          ayarlar: ayarlar,
        );
        return KararAnalizSonucu(
          karar: karar.karar.copyWith(
            analizUyarilari: [...tumUyarilar, ...karar.karar.analizUyarilari],
          ),
          kaynak: KararAnalizKaynagi.yapayZeka,
          uyarilar: [...tumUyarilar, ...karar.karar.analizUyarilari],
          pdfKalite: kalite,
          eslesmeSkoru: karar.docxEslesme?.guvenSkoru,
          tabloDoldurma: karar.docxEslesme?.tabloDoldurma,
        );
      } catch (e) {
        debugPrint('[GundemParser] AI başarısız, otomatik eşleştirmeye geçiliyor: $e');
      }
    }

    // Yüksek güvenli eşleşme varsa AI'sız da doğrudan Word formatı kullanılabilir
    final karar = await _eslestirme.eslestirVeKararUret(
      pdfText: pdfText,
      birimAd: birimAd,
      birimId: birimId,
      gecmisKararlar: gecmis,
      kararSablon: kararSablon,
    );

    return KararAnalizSonucu(
      karar: karar.karar,
      kaynak: KararAnalizKaynagi.otomatikEslestirme,
      uyarilar: [...tumUyarilar, ...karar.uyarilar],
      pdfKalite: kalite,
      eslesmeSkoru: karar.eslesmeSkoru,
      tabloDoldurma: karar.tabloDoldurma,
    );
  }

  Future<_AiAnalizPaketi> _analizWithAi({
    required String pdfText,
    required String birimAd,
    required String birimId,
    List<SablonModel>? birimeOzelSablonlar,
    required List<YkKararModel> gecmisKararlar,
    SablonModel? kararSablon,
    required SistemAyarlariModel ayarlar,
  }) async {
    // Word arşivinden en uygun bölümü önceden bul (AI + offline için ortak)
    DocxEslesmeSonucu? docxEslesme;
    if (kararSablon != null && _docxSablon.isDocxSablon(kararSablon)) {
      docxEslesme = await _docxSablon.enIyiBolumuBul(
        sablon: kararSablon,
        pdfText: pdfText,
        tur: _turTespitEt(pdfText),
        gundem: false,
      );
    }

    final customTemplatesPrompt = await _sablonVeGecmisPrompt(
      pdfText: pdfText,
      birimAd: birimAd,
      kararSablon: kararSablon,
      gecmisKararlar: gecmisKararlar,
      docxEslesme: docxEslesme,
      tespitEdilenTur: _turTespitEt(pdfText),
    );

    final prompt = '''
Sen "Döner Sermaye Yürütme Kurulu Karar Raportörü"sün. Aşağıdaki metin, kurumun "$birimAd" isimli biriminden gelen resmi bir üst yazı, talep veya karar tutanağıdır.
Senin görevin, bu metni analiz edip resmi bir "Yürütme Kurulu Karar Metni" (Microsoft Word'de yazılabilecek formatlı) oluşturmaktır.

ÇOK ÖNEMLİ KURALLAR:
1. Gelen metinde BİRDEN FAZLA karar maddesi varsa (Örn: 2026/12, 2026/13), HİÇBİRİNİ ATLAMA. Hepsini TEK BİR karar metninin içine yaz.
2. KESİNLİKLE AŞAĞIDAKİ ANA ŞABLON CÜMLE YAPISINI KULLAN!
3. TABLO OLUŞTURMA! Tablolar Word şablonundan birebir kopyalanacak — sen yalnızca paragraf metnini (tarih, evrak no, açıklama) yaz.
4. kararMetni alanına Markdown tablo (| ... |) KOYMA. Tablo içermeyen düz metin yaz.
5. Tarih, evrak numarası, tutar gibi güncel verileri PDF'ten al ve metne yansıt.

$customTemplatesPrompt

Sadece JSON döndür.

Çıktı Formatı (JSON):
{
  "baslik": "Kısa ve öz genel başlık",
  "kararMetni": "Tablo İÇERMEYEN resmi karar paragraf metni",
  "tur": "danismanlik"
}

Gelen PDF Metni:
$pdfText
''';

    String jsonText = '';

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

    if (jsonText.isEmpty && ayarlar.deepseekApiKey.isNotEmpty) {
      final apiUrl = ayarlar.deepseekApiUrl.isEmpty
          ? 'https://api.deepseek.com/'
          : ayarlar.deepseekApiUrl;
      final url = apiUrl.endsWith('/')
          ? '${apiUrl}chat/completions'
          : '$apiUrl/chat/completions';
      final modelName =
          ayarlar.deepseekModel.isEmpty ? 'deepseek-chat' : ayarlar.deepseekModel;

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
                  'You are a precise YK Karar (Board Decision) parsing AI that outputs strictly in JSON.',
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
    }

    if (jsonText.isEmpty) {
      throw Exception('Yapay zeka yanıt vermedi veya bağlantı kurulamadı.');
    }

    final startIndex = jsonText.indexOf('{');
    final endIndex = jsonText.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1) {
      jsonText = jsonText.substring(startIndex, endIndex + 1);
    }

    final Map<String, dynamic> data = jsonDecode(jsonText);
    final kararMetni = data['kararMetni']?.toString() ?? '';
    final tablolar = YkKararEslestirmeServisi.tabloVerileriCikar(kararMetni);

    YkKararTuru tur;
    switch (data['tur']) {
      case 'danismanlik':
        tur = YkKararTuru.danismanlik;
        break;
      case 'butceAktarim':
        tur = YkKararTuru.butceAktarim;
        break;
      case 'ekOdeme':
        tur = YkKararTuru.disHekimligi;
        break;
      default:
        tur = YkKararTuru.diger;
    }

    return _AiAnalizPaketi(
      karar: YkKararModel(
        id: '',
        toplantiId: '',
        toplantiNo: '',
        kararNo: '',
        baslik: data['baslik'] ?? docxEslesme?.baslik ?? 'Birim Kararı',
        kararMetni: kararMetni,
        birimAd: birimAd,
        birimId: birimId,
        iliskiliKayitId: '',
        kararTarihi: DateTime.now().toIso8601String().split('T')[0],
        tur: tur,
        durum: YkKararDurum.taslak,
        olusturmaTarihi: DateTime.now(),
        tabloVerileri: tablolar,
        docxBodyXml: docxEslesme?.docxBodyXml,
        eslesmeSkoru: docxEslesme?.guvenSkoru,
        analizKaynagi: KararAnalizKaynagi.yapayZeka.name,
        analizUyarilari: docxEslesme?.tabloDoldurma?.uyarilar ?? const [],
      ),
      docxEslesme: docxEslesme,
    );
  }

  YkKararTuru _turTespitEt(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('danışman') || lower.contains('danisman')) return YkKararTuru.danismanlik;
    if (lower.contains('bütçe aktar') || lower.contains('butce aktar')) return YkKararTuru.butceAktarim;
    if (lower.contains('diş hekim') || lower.contains('ek ödeme')) return YkKararTuru.disHekimligi;
    if (lower.contains('kurs ücret') ||
        lower.contains('katkı pay') ||
        lower.contains('faaliyet cetvel') ||
        lower.contains('gelir getirici')) {
      return YkKararTuru.kursUcreti;
    }
    return YkKararTuru.diger;
  }

  Future<String> _sablonVeGecmisPrompt({
    required String pdfText,
    required String birimAd,
    SablonModel? kararSablon,
    required List<YkKararModel> gecmisKararlar,
    DocxEslesmeSonucu? docxEslesme,
    required YkKararTuru tespitEdilenTur,
  }) async {
    final buffer = StringBuffer();

    if (kararSablon != null && _docxSablon.isDocxSablon(kararSablon)) {
      final ornekler = await _docxSablon.aiIcinOrnekleriSec(
        sablon: kararSablon,
        pdfText: pdfText,
        tur: tespitEdilenTur,
      );

      if (ornekler.isEmpty) {
        buffer.writeln(
          '--- UYARI: PDF ile arşiv arasında güvenilir eşleşme bulunamadı. '
          'Genel YK karar formatını kullan. ---',
        );
        buffer.writeln();
      } else {
        final ana = ornekler.first;
        buffer.writeln('=== ANA ŞABLON (BU FORMATI BİREBİR KULLAN) ===');
        buffer.writeln('Eşleşme skoru: ${ana.skor} | Tür: ${ana.tur.displayName} | Tablo: ${ana.section.tableCount}');
        buffer.writeln('Başlık: ${ana.section.baslik}');
        buffer.writeln(ana.section.plainText.length > 2000
            ? '${ana.section.plainText.substring(0, 2000)}...'
            : ana.section.plainText);
        buffer.writeln();

        if (ornekler.length > 1) {
          final yardimci = ornekler[1];
          buffer.writeln('--- YARDIMCI ÖRNEK (aynı tür, skor ${yardimci.skor}) ---');
          buffer.writeln('${yardimci.section.baslik}:');
          buffer.writeln(yardimci.section.plainText.length > 800
              ? '${yardimci.section.plainText.substring(0, 800)}...'
              : yardimci.section.plainText);
          buffer.writeln();
        }
      }
    }

    // Geçmiş karar: yalnızca arşiv eşleşmesi yoksa veya 1 adet destek
    if (gecmisKararlar.isNotEmpty &&
        (docxEslesme == null || !docxEslesme.yuksekGuven)) {
      buffer.writeln('--- GEÇMİŞ KARAR (destek, max 1) ---');
      final karar = gecmisKararlar.first;
      try {
        final decoded = jsonDecode(karar.kararMetni);
        if (decoded is List) {
          buffer.writeln(quill.Document.fromJson(decoded).toPlainText());
        } else {
          buffer.writeln(karar.kararMetni);
        }
      } catch (_) {
        buffer.writeln(karar.kararMetni);
      }
      buffer.writeln();
    }

    buffer.writeln('--------------------------------------------------------');
    return buffer.toString();
  }

  /// Eski ekranla (Gündem Yönetimi) uyumluluk için PDF metni çıkarma mock metodu
  String pdfMetniCikar(Uint8List bytes) {
    return 'Gündem 1: Deneme maddesi';
  }

  /// Eski ekranla uyumluluk için Gündem ayrıştırma mock metodu
  List<GundemMaddesi> metniGundemMaddelerineAyristir(String text) {
    return [
      GundemMaddesi(siraNo: 1, baslik: text, tur: GundemTuru.diger)
    ];
  }
}

class _AiAnalizPaketi {
  const _AiAnalizPaketi({required this.karar, this.docxEslesme});

  final YkKararModel karar;
  final DocxEslesmeSonucu? docxEslesme;
}
