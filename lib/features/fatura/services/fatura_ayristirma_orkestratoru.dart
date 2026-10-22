import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/models/sistem_ayarlari_model.dart';
import '../../../core/services/ai_extraction_service.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../models/fatura_model.dart';
import '../models/fatura_okuma_oturumu.dart';
import '../models/fatura_parse_kaynaklari.dart';
import 'excel_universal_parser.dart';
import 'fatura_butunluk_denetcisi.dart';
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
///
/// Güvenlik ağları:
/// - Her katmanın çıktısı [FaturaButunlukDenetcisi]'nden geçer; şüpheli alanlar
///   `okumaUyarilari` ile kullanıcıya gösterilir (sessiz düzeltme yok).
/// - Yapay zeka çıktısı kaynak metinle karşılaştırılır (uydurma tespiti).
/// - Yapay zekaya ulaşılamazsa (anahtar yok, internet yok, kota, hata) kural
///   motorunun kısmi sonucu uyarıyla birlikte döner; kullanıcı elle tamamlar.
class FaturaAyristirmaOrkestratoru {
  FaturaAyristirmaOrkestratoru({
    SistemAyarlariService? ayarlarService,
    FaturaGeminiOkuyucu? geminiOkuyucu,
    FaturaYerelOcr? yerelOcr,
    Future<SistemAyarlariModel> Function()? ayarlariOku,
  })  : _ayarlarServiceInstance = ayarlarService,
        _geminiOkuyucu = geminiOkuyucu ?? FaturaGeminiOkuyucu(),
        _yerelOcr = yerelOcr ?? const FaturaYerelOcr(),
        _ayarlariOku = ayarlariOku;

  SistemAyarlariService? _ayarlarServiceInstance;
  SistemAyarlariService get _ayarlarService =>
      _ayarlarServiceInstance ??= SistemAyarlariService();
  final FaturaGeminiOkuyucu _geminiOkuyucu;
  final FaturaYerelOcr _yerelOcr;
  final Future<SistemAyarlariModel> Function()? _ayarlariOku;
  String? _isletmeVknOnbellek;

  /// Yapay zekaya gönderilen metin bu sınırı aşarsa maliyet uyarısı verilir.
  static const int buyukMetinEsigi = 60000;

  Future<SistemAyarlariModel> _ayarlar() =>
      _ayarlariOku != null ? _ayarlariOku() : _ayarlarService.getAyarlar();

  /// İşletmenin kendi VKN'si (alıcı yerine düzenleyen okunmasını yakalamak için).
  /// Ayarlar okunamazsa denetim bu kontrolü atlar; okuma asla bu yüzden durmaz.
  Future<String> _isletmeVkn() async {
    if (_isletmeVknOnbellek != null) return _isletmeVknOnbellek!;
    try {
      _isletmeVknOnbellek = (await _ayarlar()).isletmeVkn;
    } catch (_) {
      _isletmeVknOnbellek = '';
    }
    return _isletmeVknOnbellek!;
  }

  /// PDF metin katmanı gerçekten okunabilir mi? Bozuk font kodlaması (CID)
  /// veya yalnızca birkaç karakterlik başlık içeren taranmış PDF'leri eler;
  /// böylece bu belgeler boş sayılıp yerel OCR'a yönlendirilir.
  static bool anlamliMetinMi(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    final harfRakam = RegExp(r'[0-9A-Za-zÇĞİÖŞÜçğıöşü]').allMatches(t).length;
    if (harfRakam < 40) return false;
    final bozuk = RegExp(r'[\uFFFD\u0000-\u0008]').allMatches(t).length;
    return bozuk / t.length < 0.05;
  }

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
        return _sonuclandir(sonuc, kaynakMetin: csvText, aiUretimi: false, oturum: oturum);
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
        if (metin.isNotEmpty && !anlamliMetinMi(metin)) {
          oturum.log(
            '   ↳ Metin katmanı anlamsız/bozuk (taranmış belge veya kodlanmış font). Görüntü olarak işlenecek.',
            seviye: FaturaLogSeviyesi.uyari,
          );
          metin = '';
        }
      } else if (ext == 'txt' || ext == 'csv') {
        metin = utf8.decode(bytes, allowMalformed: true).trim();
      }
    }

    oturum.iptalKontrol();

    // Kural motorunun eksik ama boş olmayan sonucu: yapay zeka kullanılamazsa
    // kullanıcıya hiç sonuç vermemek yerine bu, uyarıyla birlikte sunulur.
    var kismiSonuc = <FaturaModel>[];
    String? kismiNeden;

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
        return _sonuclandir(
          yerelSonuc,
          kaynakMetin: metin,
          aiUretimi: false,
          oturum: oturum,
          kaynak: FaturaParseKaynaklari.cevrimdisi,
        );
      } else if (yerelSonuc.isNotEmpty) {
        kismiSonuc = yerelSonuc;
        kismiNeden = eksik;
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
          final ocrEksik = FaturaKaliteKapisi.eksikNedeni(ocrSonuc, metin);
          if (ocrSonuc.isNotEmpty && ocrEksik == null) {
            oturum.faturaEklendi(ocrSonuc.length, ucretsiz: true);
            oturum.dosyaIciIlerleme(1.0);
            oturum.log('🎉 Yerel OCR + Kural motoru ile ${ocrSonuc.length} fatura sıfır maliyetle çözüldü!', seviye: FaturaLogSeviyesi.basarili);
            return _sonuclandir(
              ocrSonuc,
              kaynakMetin: metin,
              aiUretimi: false,
              oturum: oturum,
              kaynak: FaturaParseKaynaklari.cevrimdisi,
              ekUyarilar: const ['Taranmış belgeden OCR ile okundu; rakamları belgeyle karşılaştırın.'],
            );
          } else if (ocrSonuc.isNotEmpty) {
            kismiSonuc = ocrSonuc;
            kismiNeden = ocrEksik;
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
    try {
      return await _yapayZekaIleOku(bytes: bytes, metin: metin, oturum: oturum);
    } on FaturaOkumaIptalEdildi {
      rethrow;
    } catch (e) {
      if (kismiSonuc.isEmpty) rethrow;
      final neden = e.toString().replaceFirst('Exception: ', '');
      oturum.log(
        '⚠️ Yapay zeka kullanılamadı ($neden). Kural motorunun kısmi sonucu gösteriliyor — eksikleri elle tamamlayın.',
        seviye: FaturaLogSeviyesi.uyari,
      );
      oturum.faturaEklendi(kismiSonuc.length, ucretsiz: true);
      oturum.dosyaIciIlerleme(1.0);
      return _sonuclandir(
        kismiSonuc,
        kaynakMetin: metin,
        aiUretimi: false,
        oturum: oturum,
        kaynak: FaturaParseKaynaklari.cevrimdisi,
        ekUyarilar: [
          'Yapay zekaya ulaşılamadı; bu fatura kural motorunun KISMİ sonucudur'
              '${kismiNeden != null ? ' ($kismiNeden)' : ''}. Tüm alanları kontrol edin.',
        ],
      );
    }
  }

  Future<List<FaturaModel>> _yapayZekaIleOku({
    required Uint8List? bytes,
    required String metin,
    required FaturaOkumaOturumu oturum,
  }) async {
    oturum.katmanDegisti('Katman 4: Gemini Flash AI');
    oturum.log('🤖 [KATMAN 4] Karmaşık tablo/evrak için Gemini Flash AI devrede...', seviye: FaturaLogSeviyesi.katman);
    oturum.dosyaIciIlerleme(0.8);

    final ayarlar = await _ayarlar();
    _isletmeVknOnbellek ??= ayarlar.isletmeVkn;
    if (ayarlar.geminiApiKey.trim().isEmpty) {
      throw Exception('API Anahtarı bulunamadı. Lütfen Sistem Ayarları sayfasından anahtarınızı girin.');
    }

    if (metin.length > buyukMetinEsigi) {
      oturum.log(
        '   ↳ Belge metni çok uzun (${metin.length} karakter); maliyet normalden yüksek olabilir. Mümkünse belgeyi bölerek yükleyin.',
        seviye: FaturaLogSeviyesi.uyari,
      );
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

    final parsedJsonList = jsonListesiCoz(yanit.metin);
    if (parsedJsonList.isEmpty) {
      if (yanit.kesildi) {
        throw Exception('Yapay zeka yanıtı çıktı sınırında kesildi (belge çok uzun). Belgeyi bölerek yükleyin.');
      }
      throw Exception('Yapay zeka yanıtı fatura JSON listesine dönüştürülemedi.');
    }
    if (yanit.kesildi) {
      oturum.log('   ↳ Yanıt sınırda kesildi; son fatura(lar) eksik olabilir.', seviye: FaturaLogSeviyesi.uyari);
    }

    final faturalar = parsedJsonList.map(FaturaModel.fromJson).toList();

    // Yapay zeka çıktısı da aynı kalite kapısından geçer; eksik çıktı sessizce
    // kabul edilmez, kullanıcıya gösterilir.
    final aiEksik = FaturaKaliteKapisi.eksikNedeni(faturalar, metin);

    oturum.faturaEklendi(faturalar.length, ucretsiz: false);
    oturum.dosyaIciIlerleme(1.0);
    oturum.log('✅ ${faturalar.length} fatura Gemini Flash ile ayrıştırıldı.', seviye: FaturaLogSeviyesi.basarili);

    return _sonuclandir(
      faturalar,
      kaynakMetin: metin,
      aiUretimi: true,
      oturum: oturum,
      kaynak: FaturaParseKaynaklari.sistemOkuma,
      ekUyarilar: [
        if (aiEksik != null) 'Yapay zeka çıktısı eksik: $aiEksik',
        if (yanit.kesildi) 'Yapay zeka yanıtı sınırda kesildi; fatura sayısını kontrol edin.',
      ],
    );
  }

  /// Ortak son adım: matematiksel doğrulama + bütünlük denetimi + terminal raporu.
  Future<List<FaturaModel>> _sonuclandir(
    List<FaturaModel> faturalar, {
    required String kaynakMetin,
    required bool aiUretimi,
    required FaturaOkumaOturumu oturum,
    String? kaynak,
    List<String> ekUyarilar = const [],
  }) async {
    final isletmeVkn = await _isletmeVkn();
    var uyariliSayisi = 0;

    for (var i = 0; i < faturalar.length; i++) {
      final f = faturalar[i];
      if (kaynak != null) f.parsedBy = kaynak;

      final once = FaturaOkumaAnlikGoruntusu.al(f);
      FaturaDogrulamaServisi.dogrulaVeTamamla(f);

      final uyarilar = <String>[
        ...ekUyarilar,
        ...FaturaButunlukDenetcisi.denetle(
          fatura: f,
          once: once,
          kaynakMetin: kaynakMetin,
          aiUretimi: aiUretimi,
          isletmeVkn: isletmeVkn,
        ),
      ];
      f.okumaUyarilari = uyarilar;

      if (uyarilar.isNotEmpty) {
        uyariliSayisi++;
        final ad = f.firmaAdi.trim().isEmpty ? 'firma adı yok' : f.firmaAdi.trim();
        oturum.log('   ⚠ Fatura ${i + 1} ($ad): ${uyarilar.length} kontrol uyarısı', seviye: FaturaLogSeviyesi.uyari);
        for (final u in uyarilar) {
          oturum.log('      • $u', seviye: FaturaLogSeviyesi.uyari);
        }
      }
    }

    if (faturalar.isNotEmpty) {
      oturum.log(
        uyariliSayisi == 0
            ? '🛡️ Bütünlük denetimi: ${faturalar.length} fatura tutarlı (VKN, tarih, toplam, belge kanıtı).'
            : '🛡️ Bütünlük denetimi: $uyariliSayisi/${faturalar.length} faturada kontrol edilmesi gereken alan var.',
        seviye: uyariliSayisi == 0 ? FaturaLogSeviyesi.basarili : FaturaLogSeviyesi.uyari,
      );
    }
    return faturalar;
  }

  /// Model yanıtındaki JSON dizisini (veya tek nesneyi) çözer.
  @visibleForTesting
  static List<Map<String, dynamic>> jsonListesiCoz(String text) {
    try {
      String cleanText = text.trim();
      if (cleanText.startsWith('```json')) cleanText = cleanText.substring(7);
      if (cleanText.startsWith('```')) cleanText = cleanText.substring(3);
      if (cleanText.endsWith('```')) cleanText = cleanText.substring(0, cleanText.length - 3);
      cleanText = cleanText.trim();

      // 1. Önce doğrudan tam metni parse etmeyi dene (en güvenli yöntem)
      try {
        final direct = jsonDecode(cleanText);
        if (direct is List) {
          return direct.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        }
        if (direct is Map) {
          return _maptenFaturaListesiCikar(Map<String, dynamic>.from(direct));
        }
      } catch (_) {
        // Doğrudan decode başarısız olursa kırpma yöntemlerine geç
      }

      // 2. Hangisi önce başlıyor: '[' mi yoksa '{' mi?
      final sList = cleanText.indexOf('[');
      final sObj = cleanText.indexOf('{');

      // Eğer obje önce başlıyorsa veya liste hiç yoksa, önce dış objeyi yakala
      if (sObj != -1 && (sList == -1 || sObj < sList)) {
        final eObj = cleanText.lastIndexOf('}');
        if (eObj > sObj) {
          try {
            final decodedObj = jsonDecode(cleanText.substring(sObj, eObj + 1));
            if (decodedObj is Map) {
              return _maptenFaturaListesiCikar(Map<String, dynamic>.from(decodedObj));
            }
          } catch (_) {}
        }
      }

      // Eğer liste önce başlıyorsa veya obje ayrıştırılamadıysa dış listeyi yakala
      if (sList != -1) {
        final eList = cleanText.lastIndexOf(']');
        if (eList > sList) {
          try {
            final decodedList = jsonDecode(cleanText.substring(sList, eList + 1));
            if (decodedList is List) {
              // Eğer bu liste kalem listesi değil de gerçek faturalar ise döndür
              final list = decodedList.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
              if (list.isNotEmpty) {
                // Kalem objesi ile fatura objesini ayırt et
                final ilkEleman = list.first;
                final faturaMi = ilkEleman.containsKey('firmaAdi') ||
                    ilkEleman.containsKey('matrah') ||
                    ilkEleman.containsKey('genelToplam') ||
                    ilkEleman.containsKey('vergiNo');
                if (faturaMi) return list;
              }
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('[FaturaAyristirmaOrkestratoru] JSON parse hatası: $e');
    }
    return [];
  }

  static List<Map<String, dynamic>> _maptenFaturaListesiCikar(Map<String, dynamic> map) {
    // 1. Obje doğrudan tek bir fatura mı?
    final tekFatura = map.containsKey('firmaAdi') ||
        map.containsKey('matrah') ||
        map.containsKey('genelToplam') ||
        map.containsKey('vergiNo');
    if (tekFatura) {
      return [map];
    }

    // 2. {"faturalar": [...]} veya {"invoices": [...]} gibi sarmalayıcı mı?
    for (final v in map.values) {
      if (v is List && v.isNotEmpty && v.first is Map) {
        final altListe = v.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();
        final ilk = altListe.first;
        if (ilk.containsKey('firmaAdi') ||
            ilk.containsKey('matrah') ||
            ilk.containsKey('genelToplam') ||
            ilk.containsKey('vergiNo')) {
          return altListe;
        }
      }
    }

    return [map];
  }
}
