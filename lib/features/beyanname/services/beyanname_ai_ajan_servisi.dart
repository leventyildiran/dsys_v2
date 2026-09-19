import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/services/sistem_ayarlari_service.dart';
import '../../../core/turkce_format.dart';
import '../../fatura/services/excel_universal_parser.dart';
import '../../fatura/services/fatura_offline_parser.dart';
import '../models/beyanname_belge_model.dart';
import '../models/beyanname_denetim_rapor_model.dart';
import 'beyanname_denetim_servisi.dart';

/// Canlı akış log mesajı
class AjanLogMesaji {
  final DateTime zaman;
  final String mesaj;
  final String? birimAdi;
  final double ilerlemeYuzdesi; // 0.0 - 1.0
  final bool isHata;
  final bool isBasarili;

  const AjanLogMesaji({
    required this.zaman,
    required this.mesaj,
    this.birimAdi,
    required this.ilerlemeYuzdesi,
    this.isHata = false,
    this.isBasarili = false,
  });

  String get formatliZaman {
    final s = zaman.hour.toString().padLeft(2, '0');
    final d = zaman.minute.toString().padLeft(2, '0');
    final sn = zaman.second.toString().padLeft(2, '0');
    return '$s:$d:$sn';
  }
}

/// Sıralı, kontrollü, hata dayanımlı ve faturadaki evrensel okuma modüllerini
/// kullanan Akıllı Beyanname Mizan & Belge Ajanı Servisi.
class BeyannameAiAjanServisi {
  final SistemAyarlariService _ayarlarService = SistemAyarlariService();

  static const List<String> _geminiModelFallbacks = [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
  ];

  /// Fatura modülündeki evrensel parser'ları ve PDF text extractor'ı kullanarak
  /// belge içeriğinden saf metni çıkarır.
  Future<String> belgeMetniniCikar(BirimYuklenenBelge belge) async {
    final bytes = belge.dosyaBytes;
    if (bytes == null || bytes.isEmpty) return '';

    // 1. Excel ise doğrudan fatura modülündeki ExcelUniversalParser'ı kullan (tekrar yazma!)
    if (belge.isExcel) {
      try {
        final text = await ExcelUniversalParser.extractText(
          bytes,
          fileName: belge.dosyaAdi,
        );
        if (text.trim().isNotEmpty) {
          debugPrint(
            '[BeyannameAiAjanServisi] Excel başarıyla ayrıştırıldı (${belge.dosyaAdi}): ${text.length} karakter.',
          );
          return text;
        }
      } catch (e) {
        debugPrint('[BeyannameAiAjanServisi] ExcelUniversalParser hatası: $e');
      }
    }

    // 2. PDF ise syncfusion_flutter_pdf ile metin katmanını çıkar
    if (belge.isPdf) {
      try {
        final doc = PdfDocument(inputBytes: bytes);
        final text = PdfTextExtractor(doc).extractText().trim();
        doc.dispose();
        debugPrint(
          '[BeyannameAiAjanServisi] PDF metin katmanı çıkarıldı (${belge.dosyaAdi}): ${text.length} karakter.',
        );
        return text;
      } catch (e) {
        debugPrint('[BeyannameAiAjanServisi] PDF metin çıkarma hatası: $e');
      }
    }

    // 3. Düz metin / CSV
    try {
      return utf8.decode(bytes, allowMalformed: true).trim();
    } catch (_) {
      return '';
    }
  }

  /// Sıralı (Sequential Queue) Analiz Akışı:
  /// Tek tek her birimi Gemini'ye okutur; o birim doğrulanana kadar sonrakine geçmez.
  Stream<AjanLogMesaji> siraliAnalizBaslat({
    required int yil,
    required int ay,
    required Map<String, Map<BirimBelgeSlotTuru, BirimYuklenenBelge>> yuklenenBelgeler,
    required Map<String, double> birimOncekiAylarHasilat,
    required double oncekiAydanDevredenKdv,
    required void Function(BeyannameAjanRaporu rapor) onTamamlandi,
    required void Function(String hataMesaji) onHata,
  }) async* {
    final ayarlar = await _ayarlarService.getAyarlar();
    if (ayarlar.geminiApiKey.isEmpty) {
      final msg = 'Gemini API Anahtarı Sistem Ayarlarında tanımlı değil!';
      yield AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '❌ HATA: $msg',
        ilerlemeYuzdesi: 0.0,
        isHata: true,
      );
      onHata(msg);
      return;
    }

    // Yalnızca en az 1 belgesi yüklenmiş aktif birimleri filtrele
    final doluBirimler = yuklenenBelgeler.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();

    if (doluBirimler.isEmpty) {
      final msg = 'Lütfen analiz edilecek birimlere en az bir mizan/belge yükleyiniz.';
      yield AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '⚠️ $msg',
        ilerlemeYuzdesi: 0.0,
        isHata: true,
      );
      onHata(msg);
      return;
    }

    int toplamDosya = 0;
    for (final b in doluBirimler) {
      toplamDosya += yuklenenBelgeler[b]?.length ?? 0;
    }

    yield AjanLogMesaji(
      zaman: DateTime.now(),
      mesaj: '🚀 Beyanname Ajanı Başlatıldı ($yil / ${ay.toString().padLeft(2, '0')}). Toplam $toplamDosya evrak sıralı kuyruğa alındı.',
      ilerlemeYuzdesi: 0.02,
    );

    final analizSonuclari = <String, BirimMizanAnalizSonucu>{};
    final toplamBirimSayisi = doluBirimler.length;

    // BİRİM BİRİM SIRALI İŞLEME DÖNGÜSÜ
    for (int i = 0; i < toplamBirimSayisi; i++) {
      final birimAdi = doluBirimler[i];
      final birimBelgeleri = yuklenenBelgeler[birimAdi] ?? {};

      final birimIlerlemeBaslangic = (i / toplamBirimSayisi);
      final birimIlerlemeBitis = ((i + 1) / toplamBirimSayisi);

      yield AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '⏳ [${i + 1}/$toplamBirimSayisi] $birimAdi için analiz başlatılıyor...',
        birimAdi: birimAdi,
        ilerlemeYuzdesi: birimIlerlemeBaslangic,
      );

      final aylikMizanBelgesi = birimBelgeleri[BirimBelgeSlotTuru.aylikMizan];
      final yillikMizanBelgesi = birimBelgeleri[BirimBelgeSlotTuru.yillikMizan];
      final digerBelge = birimBelgeleri[BirimBelgeSlotTuru.diger];

      // 1. Aylık Mizan Metni ve Dosyası
      String aylikMizanMetni = '';
      if (aylikMizanBelgesi != null) {
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📄 [$birimAdi] Aylık Mizan (${aylikMizanBelgesi.dosyaAdi}) okunuyor...',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.05 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );
        aylikMizanMetni = await belgeMetniniCikar(aylikMizanBelgesi);
      }

      // 2. Yıllık Mizan Metni
      String yillikMizanMetni = '';
      if (yillikMizanBelgesi != null) {
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📊 [$birimAdi] Yıllık Kümülatif Mizan (${yillikMizanBelgesi.dosyaAdi}) okunuyor...',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.15 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );
        yillikMizanMetni = await belgeMetniniCikar(yillikMizanBelgesi);
      }

      // 3. Diğer Belgeler (Fatura modülünün offline ayrıştırıcısı ile kontrol)
      String digerBelgeMetni = '';
      final tevkifatFaturaListesi = <Map<String, dynamic>>[];
      if (digerBelge != null) {
        digerBelgeMetni = await belgeMetniniCikar(digerBelge);
        // Faturada varsa kural tabanlı offline parser'ı dene
        try {
          final faturalar = FaturaOfflineParser.parse(digerBelgeMetni);
          for (final f in faturalar) {
            if (f.kalemler.isNotEmpty) {
              tevkifatFaturaListesi.add({
                'firmaAdi': f.firmaAdi,
                'vergiTcNo': f.vergiNo,
                'matrahTutari': f.matrah,
                'kdvTutari': f.kdvTutari,
                'tevkifatTutari': f.kdvTutari * 0.9, // Varsa oran
                'tevkifatOrani': '9/10',
              });
            }
          }
        } catch (_) {}
      }

      // 4. Gemini AI İstemi Hazırlama
      final prompt = _buildMizanPrompt(
        birimAdi: birimAdi,
        yil: yil,
        ay: ay,
        aylikMizanMetni: aylikMizanMetni,
        yillikMizanMetni: yillikMizanMetni,
        digerBelgeMetni: digerBelgeMetni,
      );

      final contentParts = <Part>[];
      // Eğer aylık mizan PDF ise ve multimodal destekleniyorsa DataPart ekle
      if (aylikMizanBelgesi != null && aylikMizanBelgesi.isPdf && aylikMizanBelgesi.dosyaBytes != null) {
        contentParts.add(DataPart('application/pdf', aylikMizanBelgesi.dosyaBytes!));
      }
      contentParts.add(TextPart(prompt));

      yield AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '🤖 [$birimAdi] Gemini AI derin mizan taraması ve hesap kodları tespiti yapılıyor...',
        birimAdi: birimAdi,
        ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.35 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
      );

      // 5. Kesintisiz Dayanıklı Gemini Çağrısı (Retry & Exponential Backoff)
      BirimMizanAnalizSonucu? sonuc;
      int denemeSayisi = 0;
      const maxDeneme = 5;

      while (denemeSayisi < maxDeneme) {
        denemeSayisi++;
        try {
          final aiResponseText = await _runGeminiWithFallback(
            apiKey: ayarlar.geminiApiKey,
            preferredModel: ayarlar.geminiModel,
            parts: contentParts,
          );

          if (aiResponseText != null && aiResponseText.isNotEmpty) {
            final parsedJson = _parseCleanJson(aiResponseText);
            if (parsedJson != null) {
              // Tevkifat faturalarını birleştir
              final aiTevkifat = (parsedJson['tevkifatFaturalari'] as List<dynamic>?)
                      ?.map((e) => Map<String, dynamic>.from(e as Map))
                      .toList() ??
                  [];
              aiTevkifat.addAll(tevkifatFaturaListesi);
              parsedJson['tevkifatFaturalari'] = aiTevkifat;
              parsedJson['birimAdi'] = birimAdi;
              parsedJson['analizTarihi'] = DateTime.now().toIso8601String();

              sonuc = BirimMizanAnalizSonucu.fromMap(parsedJson);
              break; // Başarılı, döngüden çık!
            }
          }

          throw Exception('Gemini geçersiz JSON çıktısı üretti.');
        } catch (e) {
          final hataStr = e.toString();
          debugPrint('[$birimAdi] Deneme $denemeSayisi/$maxDeneme hatası: $hataStr');

          if (denemeSayisi < maxDeneme) {
            final beklemeSaniye = denemeSayisi * 3; // 3s, 6s, 9s, 12s...
            yield AjanLogMesaji(
              zaman: DateTime.now(),
              mesaj: '⏳ [$birimAdi] Gemini yoğunluk/hata verdi. $beklemeSaniye saniye beklenip tekrar deneniyor (Deneme $denemeSayisi/$maxDeneme)...',
              birimAdi: birimAdi,
              ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.40 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
              isHata: true,
            );
            await Future.delayed(Duration(seconds: beklemeSaniye));
          } else {
            yield AjanLogMesaji(
              zaman: DateTime.now(),
              mesaj: '❌ [$birimAdi] $maxDeneme denemede okunamadı ($hataStr). Bu birim için sıfır/boş taslak oluşturuldu.',
              birimAdi: birimAdi,
              ilerlemeYuzdesi: birimIlerlemeBitis,
              isHata: true,
            );
            sonuc = BirimMizanAnalizSonucu(
              birimAdi: birimAdi,
              analizTarihi: DateTime.now(),
              aciklama: 'AI okuma hatası: $hataStr',
            );
          }
        }
      }

      analizSonuclari[birimAdi] = sonuc!;

      yield AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '✅ [${i + 1}/$toplamBirimSayisi] $birimAdi tamamlandı -> 600 Hasılat: ${TurkceFormat.para(sonuc.hasilat600Aylik)}, 123 POS: ${TurkceFormat.para(sonuc.krediKarti123)}, KDV: ${TurkceFormat.para(sonuc.toplamHesaplananKdv)}.',
        birimAdi: birimAdi,
        ilerlemeYuzdesi: birimIlerlemeBitis,
        isBasarili: true,
      );
    }

    // =========================================================================
    // TÜM BİRİMLER BİTTİĞİNDE 9 SENARYOLU KAPSAMLI DENETİM VE RAPORLAMA
    // =========================================================================
    yield AjanLogMesaji(
      zaman: DateTime.now(),
      mesaj: '🔍 Tüm birimler okundu. 9 Senaryolu Çapraz Denetim ve Mutabakat Motoru çalıştırılıyor...',
      ilerlemeYuzdesi: 0.95,
    );

    final rapor = BeyannameDenetimServisi.denetleVeRaporOlustur(
      yil: yil,
      ay: ay,
      birimSonuclari: analizSonuclari,
      toplamDosyaSayisi: toplamDosya,
      birimOncekiAylarHasilat: birimOncekiAylarHasilat,
      oncekiAydanDevredenKdv: oncekiAydanDevredenKdv,
    );

    yield AjanLogMesaji(
      zaman: DateTime.now(),
      mesaj: '🎉 Analiz ve Denetim Tamamlandı! ${rapor.analizEdilenBirimler.length} birim incelendi, ${rapor.denetimKontrolleri.length} mutabakat testi yapıldı (${rapor.kritikHataSayisi} Kritik Hata, ${rapor.uyariSayisi} İnceleme Uyarısı).',
      ilerlemeYuzdesi: 1.0,
      isBasarili: true,
    );

    onTamamlandi(rapor);
  }

  /// Gemini API'ye model fallback ve retry zinciri ile istek gönderir.
  Future<String?> _runGeminiWithFallback({
    required String apiKey,
    required List<Part> parts,
    String? preferredModel,
  }) async {
    final modelOrder = <String>[];
    String? cleanPreferred = preferredModel?.trim();
    if (cleanPreferred != null &&
        (cleanPreferred.isEmpty ||
            cleanPreferred == 'gemini-flash-latest' ||
            cleanPreferred == 'gemini-2.5-flash' ||
            cleanPreferred == 'gemini-2.0-flash' ||
            cleanPreferred == 'gemini-1.5-flash')) {
      cleanPreferred = 'gemini-3.6-flash';
    }

    if (cleanPreferred != null && cleanPreferred.isNotEmpty) {
      modelOrder.add(cleanPreferred);
    }
    for (final m in _geminiModelFallbacks) {
      if (!modelOrder.contains(m)) modelOrder.add(m);
    }

    final hasMedia = parts.any((p) => p is DataPart);
    final modelTimeout = Duration(seconds: hasMedia ? 180 : 60);

    Object? sonHata;
    for (final modelName in modelOrder) {
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          final model = GenerativeModel(model: modelName, apiKey: apiKey);
          final response = await model
              .generateContent([Content.multi(parts)])
              .timeout(modelTimeout);
          final text = response.text?.trim() ?? '';
          if (text.isNotEmpty) return text;
          break;
        } catch (e) {
          sonHata = e;
          final err = e.toString();
          final is503 = err.contains('503') ||
              err.contains('UNAVAILABLE') ||
              err.contains('high demand') ||
              err.contains('overloaded');
          if (is503 && attempt == 0) {
            await Future.delayed(const Duration(seconds: 3));
            continue;
          }
          break;
        }
      }
      await Future.delayed(const Duration(milliseconds: 250));
    }

    if (sonHata != null) throw Exception(sonHata.toString());
    return null;
  }

  /// JSON metnini güvenli temizleyip ayrıştırır
  Map<String, dynamic>? _parseCleanJson(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Regex ile ilk { ... } bloğunu bulmayı dene
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match != null) {
        try {
          final decoded = jsonDecode(match.group(0)!);
          if (decoded is Map<String, dynamic>) return decoded;
        } catch (_) {}
      }
    }
    return null;
  }

  /// Katı Türk Kamu Döner Sermaye Mizan Promptu
  String _buildMizanPrompt({
    required String birimAdi,
    required int yil,
    required int ay,
    required String aylikMizanMetni,
    required String yillikMizanMetni,
    required String digerBelgeMetni,
  }) {
    return '''
Sen Türkiye Cumhuriyeti Üniversiteleri Döner Sermaye İşletmeleri konusunda uzmanlaşmış kıdemli bir Mali Müşavir ve Beyanname Hazırlama Yapay Zeka Ajanısın.

GÖREV:
Aşağıda verilen "$birimAdi" birimine ait $yil yılı ${ay.toString().padLeft(2, '0')}. ay belgelerini (Aylık Mizan, Yıllık Kümülatif Mizan ve Ek Belgeler) incele.
Belgelerdeki muhasebe hesap kodlarından KDV 1, Damga Vergisi, 600 Hasılat ve 123 Kredi Kartı beyanname verilerini hatasız ve kuruşu kuruşuna çıkar.

ARANACAK HESAP KODLARI VE KURALLAR:
1. 600 HESABI (YURT İÇİ GELİRLER / HASILAT):
   - Aylık Mizandan: Sadece bu ayın 600 alacak hareketini veya dönem net gelirini bul -> "hasilat600Aylik"
   - Yıllık Mizandan: Yıl başından bu aya kadar olan kümülatif 600 alacak bakiyesini bul -> "hasilat600Kumulatif"
2. 123 HESABI (KREDİ KARTI / POS TAHSİLATLARI):
   - POS ile yapılan satış ve tahsilatların bu ayki borç tutarı (GİB Satır 45) -> "krediKarti123"
3. 391 HESABI (HESAPLANAN KDV):
   - %20 KDV oranı için Matrah ve KDV tutarını ayır: "hesaplananKdvMatrah20", "hesaplananKdv20"
   - %10 KDV oranı için Matrah ve KDV tutarını ayır: "hesaplananKdvMatrah10", "hesaplananKdv10"
4. 191 HESABI (İNDİRİLECEK KDV):
   - Mal ve hizmet alımlarında ödenen indirilecek KDV:
   - "indirilecekKdvMatrah20", "indirilecekKdv20"
   - "indirilecekKdvMatrah10", "indirilecekKdv10"
5. 360.03.05 HESABI (DAMGA VERGİSİ):
   - Hakediş ve ödemelerden kesilen Damga Vergisi tutarı (alacak kalanı): "damgaVergisi360"
   - Matrah (Damga / 0.00948): "damgaMatrah"
6. 190 HESABI (DEVREDEN KDV):
   - Mizanda devreden KDV borç kalanı varsa: "devredenKdv190"
7. TERS BAKİYE KONTROLLERİ:
   - 191 hesabı alacak bakiyesi veriyor mu? -> "is191TersBakiye": true/false
   - 391 hesabı borç bakiyesi veriyor mu? -> "is391TersBakiye": true/false
   - 600 hesabı borç bakiyesi veriyor mu? -> "is600TersBakiye": true/false

ÇIKTI FORMATI:
SADECE VE SADECE aşağıdaki JSON formatında bir nesne döndür (Markdown backtick dışında hiçbir açıklama veya ek yazı yazma):
{
  "hasilat600Aylik": 0.0,
  "hasilat600Kumulatif": 0.0,
  "krediKarti123": 0.0,
  "hesaplananKdvMatrah20": 0.0,
  "hesaplananKdv20": 0.0,
  "hesaplananKdvMatrah10": 0.0,
  "hesaplananKdv10": 0.0,
  "indirilecekKdvMatrah20": 0.0,
  "indirilecekKdv20": 0.0,
  "indirilecekKdvMatrah10": 0.0,
  "indirilecekKdv10": 0.0,
  "damgaVergisi360": 0.0,
  "damgaMatrah": 0.0,
  "muhtasarGelir360": 0.0,
  "muhtasarDamga360": 0.0,
  "devredenKdv190": 0.0,
  "is191TersBakiye": false,
  "is391TersBakiye": false,
  "is600TersBakiye": false,
  "tevkifatFaturalari": []
}

---
AYLIK MİZAN METNİ:
$aylikMizanMetni

---
YILLIK KÜMÜLATİF MİZAN METNİ:
$yillikMizanMetni

---
DİĞER BELGELER METNİ:
$digerBelgeMetni
''';
  }
}
