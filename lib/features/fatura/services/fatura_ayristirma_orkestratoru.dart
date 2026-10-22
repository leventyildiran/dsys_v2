import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/services/ai_extraction_service.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../models/fatura_model.dart';
import '../models/fatura_okuma_oturumu.dart';
import '../models/fatura_parse_kaynaklari.dart';
import 'excel_universal_parser.dart';
import 'fatura_dogrulama_servisi.dart';
import 'fatura_gemini_okuyucu.dart';
import 'fatura_kalite_kapisi.dart';
import 'fatura_offline_parser.dart';
import 'yerel_ocr/fatura_yerel_ocr.dart';

/// 4 Kademeli Sıfır-Maliyet Odaklı Fatura Ayrıştırma Orkestratörü
///
/// Katman 1: Cihaz İçi Yerel Metin Çıkarıcı (0 TL)
/// Katman 2: Deterministik Kural Motoru (0 TL)
/// Katman 3: Cihaz İçi Yerel OCR (0 TL)
/// Katman 4: Son Çare: Salt Metin Gemini Flash (~0,001 TL, asla Pro yok)
class FaturaAyristirmaOrkestratoru {
  FaturaAyristirmaOrkestratoru({
    SistemAyarlariService? ayarlarService,
    FaturaGeminiOkuyucu? geminiOkuyucu,
    FaturaYerelOcr? yerelOcr,
  })  : _ayarlarServiceInstance = ayarlarService,
        _geminiOkuyucu = geminiOkuyucu ?? FaturaGeminiOkuyucu(),
        _yerelOcr = yerelOcr ?? const FaturaYerelOcr();

  SistemAyarlariService? _ayarlarServiceInstance;
  SistemAyarlariService get _ayarlarService =>
      _ayarlarServiceInstance ??= SistemAyarlariService();
  final FaturaGeminiOkuyucu _geminiOkuyucu;
  final FaturaYerelOcr _yerelOcr;

  /// Tek bir belgeyi kademeli olarak ayrıştırır ve faturaları döner.
  Future<List<FaturaModel>> ayristir({
    required Uint8List? bytes,
    required String fileName,
    String? rawText,
    required FaturaOkumaOturumu oturum,
  }) async {
    oturum.iptalKontrol();
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    oturum.log('📄 Belge analiz ediliyor: $fileName', seviye: FaturaLogSeviyesi.bilgi);

    // ── Excel dosyaları için çevrimdışı parser ──
    if (ext == 'xls' || ext == 'xlsx') {
      oturum.katmanDegisti('Katman 2: Excel Evrensel Parser');
      oturum.log('⚡ Excel formatı tespit edildi. API çağrısı yapılmadan yerel okunuyor...', seviye: FaturaLogSeviyesi.katman);
      final csvText = await ExcelUniversalParser.extractText(bytes!, fileName: fileName);
      if (csvText.isEmpty) {
        throw Exception('Excel dosyası boş veya okunamadı.');
      }
      final sonuc = FaturaOfflineParser.parse(csvText);
      if (sonuc.isNotEmpty) {
        oturum.faturaEklendi(sonuc.length, ucretsiz: true);
        oturum.log('✅ Excel yerel motorla çözüldü: ${sonuc.length} fatura çıkarıldı (Maliyet: 0,00 TL)', seviye: FaturaLogSeviyesi.basarili);
        return FaturaDogrulamaServisi.dogrulaList(sonuc);
      }
      // Excel kural motorundan çıkmadıysa metin olarak devam et
      rawText = csvText;
    }

    String metin = (rawText ?? '').trim();

    // ─────────────────────────────────────────────────────────
    // KATMAN 1: Cihaz İçi Yerel Metin Çıkarıcı (0 TL)
    // ─────────────────────────────────────────────────────────
    if (metin.isEmpty && bytes != null && bytes.isNotEmpty) {
      oturum.katmanDegisti('Katman 1: Yerel Metin Çıkarıcı');
      oturum.log('🔍 [KATMAN 1] Cihaz içi dijital metin katmanı taranıyor (Maliyet: 0,00 TL)...', seviye: FaturaLogSeviyesi.katman);
      oturum.dosyaIciIlerleme(0.2);

      if (ext == 'pdf') {
        try {
          final doc = PdfDocument(inputBytes: bytes);
          metin = PdfTextExtractor(doc).extractText().trim();
          doc.dispose();
          oturum.log('   ↳ PDF dijital metni çıkarıldı (${metin.length} karakter)', seviye: FaturaLogSeviyesi.bilgi);
        } catch (e) {
          oturum.log('   ↳ PDF dijital metin okunamadı (taranmış görsel olabilir): $e', seviye: FaturaLogSeviyesi.uyari);
        }
      } else if (ext == 'txt' || ext == 'csv') {
        metin = utf8.decode(bytes, allowMalformed: true).trim();
      }
    }

    oturum.iptalKontrol();

    // ─────────────────────────────────────────────────────────
    // KATMAN 2: Deterministik Kural Motoru (0 TL, Sıfır API)
    // ─────────────────────────────────────────────────────────
    if (metin.isNotEmpty) {
      oturum.katmanDegisti('Katman 2: Kural Motoru');
      oturum.log('⚡ [KATMAN 2] Offline kural motoru devrede (0 TL)...', seviye: FaturaLogSeviyesi.katman);
      oturum.dosyaIciIlerleme(0.4);

      final yerelSonuc = FaturaOfflineParser.parse(metin);
      final eksik = FaturaKaliteKapisi.eksikNedeni(yerelSonuc, metin);

      if (eksik == null && yerelSonuc.isNotEmpty) {
        oturum.faturaEklendi(yerelSonuc.length, ucretsiz: true);
        oturum.dosyaIciIlerleme(1.0);
        oturum.log(
          '🎉 [BAŞARILI] Kural motoru tam eşleşti: ${yerelSonuc.length} fatura sıfır maliyetle ayrıştırıldı! (Maliyet: 0,00 TL)',
          seviye: FaturaLogSeviyesi.basarili,
        );
        for (final f in yerelSonuc) {
          f.parsedBy = FaturaParseKaynaklari.cevrimdisi;
        }
        return FaturaDogrulamaServisi.dogrulaList(yerelSonuc);
      } else if (yerelSonuc.isNotEmpty) {
        oturum.log('   ↳ Kural motoru kısmi okudu: $eksik', seviye: FaturaLogSeviyesi.uyari);
      } else {
        oturum.log('   ↳ Standart kural şablonu eşleşmedi, sonraki katmana geçiliyor.', seviye: FaturaLogSeviyesi.bilgi);
      }
    }

    oturum.iptalKontrol();

    // ─────────────────────────────────────────────────────────
    // KATMAN 3: Yerel Görsel / OCR Katmanı (0 TL)
    // ─────────────────────────────────────────────────────────
    if (metin.isEmpty && bytes != null && ext == 'pdf') {
      oturum.katmanDegisti('Katman 3: Yerel OCR');
      oturum.log('📷 [KATMAN 3] Taranmış PDF görseli tespit edildi, yerel OCR taranıyor...', seviye: FaturaLogSeviyesi.katman);
      oturum.dosyaIciIlerleme(0.6);

      final jpegs = FaturaYerelOcr.pdfIciJpegler(bytes);
      if (jpegs.isNotEmpty && _yerelOcr.destekleniyor) {
        oturum.log('   ↳ PDF içinde ${jpegs.length} sayfa görüntüsü bulundu, yerel OCR çalıştırılıyor...', seviye: FaturaLogSeviyesi.bilgi);
        final sb = StringBuffer();
        for (var idx = 0; idx < jpegs.length; idx++) {
          oturum.iptalKontrol();
          final sayfaMetni = await _yerelOcr.gorseldenMetin(jpegs[idx]);
          if (sayfaMetni.trim().isNotEmpty) {
            sb.writeln(sayfaMetni.trim());
          }
        }
        final ocrMetin = sb.toString().trim();
        if (ocrMetin.isNotEmpty) {
          metin = ocrMetin;
          oturum.log('   ↳ Yerel OCR metin çıkardı (${metin.length} karakter). Kural motoruna veriliyor...', seviye: FaturaLogSeviyesi.basarili);
          final ocrSonuc = FaturaOfflineParser.parse(metin);
          if (ocrSonuc.isNotEmpty && FaturaKaliteKapisi.eksikNedeni(ocrSonuc, metin) == null) {
            oturum.faturaEklendi(ocrSonuc.length, ucretsiz: true);
            oturum.dosyaIciIlerleme(1.0);
            oturum.log('🎉 Yerel OCR + Kural motoru ile ${ocrSonuc.length} fatura sıfır maliyetle çözüldü!', seviye: FaturaLogSeviyesi.basarili);
            return FaturaDogrulamaServisi.dogrulaList(ocrSonuc);
          }
        }
      } else {
        oturum.log('   ↳ Yerel OCR bu ortamda aktif değil veya resim bulunamadı.', seviye: FaturaLogSeviyesi.bilgi);
      }
    }

    oturum.iptalKontrol();

    // ─────────────────────────────────────────────────────────
    // KATMAN 4: Son Çare: Salt Metin Gemini Flash (~0,001 TL)
    // Asla Pro model çağrılmaz! Düşünme token'ı kapalıdır.
    // ─────────────────────────────────────────────────────────
    oturum.katmanDegisti('Katman 4: Gemini Flash AI');
    oturum.log('🤖 [KATMAN 4] Karmaşık tablo/evrak için Gemini Flash AI devrede...', seviye: FaturaLogSeviyesi.katman);
    oturum.dosyaIciIlerleme(0.8);

    final ayarlar = await _ayarlarService.getAyarlar();
    if (ayarlar.geminiApiKey.trim().isEmpty) {
      throw Exception('API Anahtarı bulunamadı. Lütfen Sistem Ayarları sayfasından anahtarınızı girin.');
    }

    final prompt = AIExtractionService.faturaPromptu(metin);

    // KATI KURAL: Eğer metin başarıyla çıkarıldıysa, devasa PDF dosyasını ASLA internete gönderme!
    // Yalnızca metin tamamen boşsa (taranmış resim) mecburen PDF görseli verilir.
    final gonderilecekPdf = metin.isEmpty ? bytes : null;

    if (gonderilecekPdf != null) {
      oturum.log('   ↳ Metin katmanı bulunamadığı için PDF görsel modunda gönderiliyor...', seviye: FaturaLogSeviyesi.uyari);
    } else {
      oturum.log('   ↳ Cihazda çıkarılmış arındırılmış metin gönderiliyor (Dev PDF yüklenmedi, maliyet minimum).', seviye: FaturaLogSeviyesi.bilgi);
    }

    final yanit = await _geminiOkuyucu.oku(
      apiKey: ayarlar.geminiApiKey,
      prompt: prompt,
      tercihModel: ayarlar.geminiModel,
      pdf: gonderilecekPdf,
      log: (mesaj, {uyari = false}) => oturum.log(mesaj, seviye: uyari ? FaturaLogSeviyesi.uyari : FaturaLogSeviyesi.bilgi),
      iptalKontrol: oturum.iptalKontrol,
    );

    oturum.apiKullanimiEkle(
      token: yanit.toplamToken,
      maliyetTl: yanit.maliyetTl,
    );

    oturum.log(
      '   ↳ Yanıt alındı: ${yanit.model} | Token: ${yanit.toplamToken} '
      '(Girdi: ${yanit.girdiToken}, Çıktı: ${yanit.ciktiToken}) | '
      'Tahmini Maliyet: ${FaturaOkumaOturumu.maliyetMetni(yanit.maliyetTl)}',
      seviye: FaturaLogSeviyesi.maliyet,
    );

    final parsedJsonList = _parseJsonList(yanit.metin);
    if (parsedJsonList.isEmpty) {
      throw Exception('Yapay zeka yanıtı fatura JSON listesine dönüştürülemedi.');
    }

    final faturalar = parsedJsonList.map(FaturaModel.fromJson).toList();
    for (final f in faturalar) {
      f.parsedBy = FaturaParseKaynaklari.sistemOkuma;
    }

    oturum.faturaEklendi(faturalar.length, ucretsiz: false);
    oturum.dosyaIciIlerleme(1.0);
    oturum.log('✅ ${faturalar.length} fatura Gemini Flash ile başarıyla ayrıştırıldı.', seviye: FaturaLogSeviyesi.basarili);

    return FaturaDogrulamaServisi.dogrulaList(faturalar);
  }

  List<Map<String, dynamic>> _parseJsonList(String text) {
    try {
      String cleanText = text.trim();
      if (cleanText.startsWith('```json')) cleanText = cleanText.substring(7);
      if (cleanText.startsWith('```')) cleanText = cleanText.substring(3);
      if (cleanText.endsWith('```')) cleanText = cleanText.substring(0, cleanText.length - 3);
      cleanText = cleanText.trim();

      int s = cleanText.indexOf('[');
      int e = cleanText.lastIndexOf(']');
      if (s != -1 && e != -1 && e >= s) {
        final decoded = jsonDecode(cleanText.substring(s, e + 1));
        if (decoded is List) return List<Map<String, dynamic>>.from(decoded);
      }

      int os = cleanText.indexOf('{');
      int oe = cleanText.lastIndexOf('}');
      if (os != -1 && oe != -1 && oe >= os) {
        final decoded = jsonDecode(cleanText.substring(os, oe + 1));
        if (decoded is Map) return [Map<String, dynamic>.from(decoded)];
      }
    } catch (e) {
      debugPrint('[FaturaAyristirmaOrkestratoru] JSON parse hatası: $e');
    }
    return [];
  }
}
