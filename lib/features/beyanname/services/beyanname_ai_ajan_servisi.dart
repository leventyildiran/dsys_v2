import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../core/models/sistem_ayarlari_model.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../../../core/turkce_format.dart';
import '../../fatura/services/excel_universal_parser.dart';
import '../../fatura/services/fatura_offline_parser.dart';
import '../models/beyanname_belge_model.dart';
import '../models/beyanname_denetim_rapor_model.dart';
import 'beyanname_denetim_servisi.dart';
import 'mizan_deterministik_parser.dart';

enum AjanLogSeviyesi { bilgi, uyari, hata, basarili }

/// Canlı akış log mesajı
class AjanLogMesaji {
  final DateTime zaman;
  final String mesaj;
  final String? birimAdi;
  final double ilerlemeYuzdesi; // 0.0 - 1.0
  final bool isHata;
  final bool isBasarili;
  final AjanLogSeviyesi seviye;

  const AjanLogMesaji({
    required this.zaman,
    required this.mesaj,
    this.birimAdi,
    this.ilerlemeYuzdesi = 0.0,
    this.isHata = false,
    this.isBasarili = false,
    this.seviye = AjanLogSeviyesi.bilgi,
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

  /// Fatura modülündeki evrensel parser'ları ve PDF text extractor'ı kullanarak
  /// belge içeriğinden saf metni çıkarır.
  /// belge içeriğinden saf metni çıkarır.
  Future<String> belgeMetniniCikar(
    BirimYuklenenBelge belge, {
    int? maxPagesOverride,
  }) async {
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

    // 2. PDF ise syncfusion_flutter_pdf ile metin katmanını çıkar (Sayfa sınırlandırmalı & event loop nefesli)
    if (belge.isPdf) {
      PdfDocument? doc;
      try {
        doc = PdfDocument(inputBytes: bytes);
        final totalPages = doc.pages.count;

        // Slot türüne ve sayfa sayısına göre güvenli sınır:
        // - Otomatik sınıflandırma / hızlı tarama için maxPagesOverride (örn. 2 sayfa)
        // - Geçici mizanlar normalde 2-25 sayfadır (max 35 sayfa yeterlidir)
        // - Yardımcı defterler yüzlerce sayfa olabilir (özet için ilk 15 sayfa yeterlidir)
        // - Diğer ek evraklar (max 20 sayfa yeterlidir)
        final defaultMax = belge.slotTuru == BirimBelgeSlotTuru.yardimciMizan
            ? 50
            : 100;
        final maxPages = maxPagesOverride ?? defaultMax;
        final pagesToExtract = min(totalPages, maxPages);

        final sb = StringBuffer();
        final extractor = PdfTextExtractor(doc);
        for (int p = 0; p < pagesToExtract; p++) {
          final pageText = extractor.extractText(startPageIndex: p, endPageIndex: p);
          sb.writeln(pageText);
          // Her sayfada browser event loop'a nefes aldır (Web donmasını ve "Sayfa Yanıt Vermiyor" uyarısını engelle!)
          await Future.delayed(const Duration(milliseconds: 10));
        }
        final text = sb.toString().trim();
        debugPrint(
          '[BeyannameAiAjanServisi] PDF metin katmanı çıkarıldı (${belge.dosyaAdi}, $pagesToExtract/$totalPages sayfa): ${text.length} karakter.',
        );
        return text;
      } catch (e) {
        debugPrint('[BeyannameAiAjanServisi] PDF metin çıkarma hatası: $e');
      } finally {
        doc?.dispose();
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
  /// Tek tek her birimi OpenRouter veya Gemini'ye okutur; o birim doğrulanana kadar sonrakine geçmez.
  /// [hizliDeterministikMod] true ise AI beklemeksizin doğrudan kural tabanlı deterministik motoru çalıştırır.
  Stream<AjanLogMesaji> siraliAnalizBaslat({
    required int yil,
    required int ay,
    required Map<String, Map<BirimBelgeSlotTuru, BirimYuklenenBelge>> yuklenenBelgeler,
    Map<String, List<BirimYuklenenBelge>>? birimBelgeListeleri,
    required Map<String, double> birimOncekiAylarHasilat,
    required double oncekiAydanDevredenKdv,
    String? sadeceBuBirim,
    bool hizliDeterministikMod = false,
    required void Function(BeyannameAjanRaporu rapor) onTamamlandi,
    required void Function(String hataMesaji) onHata,
  }) async* {
    final ayarlar = await _ayarlarService.getAyarlar();
    final hasGemini = ayarlar.geminiApiKey.trim().isNotEmpty;
    final hasOpenRouter = ayarlar.deepseekApiKey.trim().isNotEmpty;
    final bool isOfflineMod = hizliDeterministikMod || (!hasGemini && !hasOpenRouter);

    if (isOfflineMod) {
      yield AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: hizliDeterministikMod
            ? '⚡ Hızlı Kural Tabanlı Mizan Motoru başlatıldı (Anında & Deterministik Hesaplama).'
            : '⚡ Sistem Ayarlarında AI anahtarı tanımlı değil. Kural Tabanlı Deterministik Mizan Motoru devreye alındı (Çevrimdışı & Sıfır Maliyetli Çalışma).',
        ilerlemeYuzdesi: 0.01,
      );
    }

    // Birim başına tüm belgelerin eksiksiz listesini hazırla
    final Map<String, List<BirimYuklenenBelge>> aktifBirimDosyalari = {};
    if (birimBelgeListeleri != null && birimBelgeListeleri.isNotEmpty) {
      for (final e in birimBelgeListeleri.entries) {
        if (e.value.isNotEmpty) {
          aktifBirimDosyalari[e.key] = List.from(e.value);
        }
      }
    }
    // Geriye dönük uyumluluk: Eğer liste boşsa yuklenenBelgeler haritasından al
    if (aktifBirimDosyalari.isEmpty) {
      for (final e in yuklenenBelgeler.entries) {
        if (e.value.isNotEmpty) {
          aktifBirimDosyalari[e.key] = e.value.values.toList();
        }
      }
    }

    // Yalnızca en az 1 belgesi yüklenmiş aktif birimleri filtrele
    List<String> doluBirimler = aktifBirimDosyalari.entries
        .where((e) => e.value.isNotEmpty)
        .map((e) => e.key)
        .toList();

    if (sadeceBuBirim != null && sadeceBuBirim.trim().isNotEmpty) {
      final hedefBirim = sadeceBuBirim.trim();
      doluBirimler = doluBirimler.where((b) => b == hedefBirim).toList();
      if (doluBirimler.isEmpty) {
        final msg = '$hedefBirim birimi için henüz yüklenmiş bir mizan veya evrak bulunmuyor.';
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '⚠️ $msg',
          ilerlemeYuzdesi: 0.0,
          isHata: true,
        );
        onHata(msg);
        return;
      }
    } else if (doluBirimler.isEmpty) {
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
      toplamDosya += aktifBirimDosyalari[b]?.length ?? 0;
    }

    final motorBilgisi = isOfflineMod
        ? '⚡ Kural Tabanlı Deterministik Motor'
        : (hasGemini
            ? '🤖 Google Gemini (${ayarlar.geminiModel})${hasOpenRouter ? " [OpenRouter Yedekli]" : ""}'
            : '🌐 OpenRouter (${ayarlar.deepseekModel.isNotEmpty ? ayarlar.deepseekModel : "Varsayılan Model"})');

    yield AjanLogMesaji(
      zaman: DateTime.now(),
      mesaj: '🚀 Beyanname Ajanı Başlatıldı [$motorBilgisi] ($yil / ${ay.toString().padLeft(2, '0')}). Toplam $toplamDosya evrak sıralı kuyruğa alındı.',
      ilerlemeYuzdesi: 0.02,
    );

    final analizSonuclari = <String, BirimMizanAnalizSonucu>{};
    final toplamBirimSayisi = doluBirimler.length;

    // BİRİM BİRİM SIRALI İŞLEME DÖNGÜSÜ
    for (int i = 0; i < toplamBirimSayisi; i++) {
      final birimAdi = doluBirimler[i];
      final birimDosyalari = aktifBirimDosyalari[birimAdi] ?? [];

      final birimIlerlemeBaslangic = (i / toplamBirimSayisi);
      final birimIlerlemeBitis = ((i + 1) / toplamBirimSayisi);

      yield AjanLogMesaji(
        zaman: DateTime.now(),
        mesaj: '⏳ [${i + 1}/$toplamBirimSayisi] $birimAdi için analiz başlatılıyor (${birimDosyalari.length} evrak)...',
        birimAdi: birimAdi,
        ilerlemeYuzdesi: birimIlerlemeBaslangic,
      );

      final aylikMizanBelgesi = birimDosyalari.where((b) => b.slotTuru == BirimBelgeSlotTuru.aylikMizan).firstOrNull;
      final yillikMizanBelgesi = birimDosyalari.where((b) => b.slotTuru == BirimBelgeSlotTuru.yillikMizan).firstOrNull;
      final yardimciMizanBelgesi = birimDosyalari.where((b) => b.slotTuru == BirimBelgeSlotTuru.yardimciMizan).firstOrNull;

      // Ana mizan belgeleri haricindeki TÜM belgeler (Ödeme emirleri, faturalar, yolluklar, tevkifat evrakları)
      final ekBelgeler = birimDosyalari.where((b) =>
        b != aylikMizanBelgesi &&
        b != yillikMizanBelgesi &&
        b != yardimciMizanBelgesi,
      ).toList();

      // 1. Aylık Mizan Metni ve Dosyası
      String aylikMizanMetni = '';
      if (aylikMizanBelgesi != null) {
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📄 [$birimAdi] Aylık Mizan (${aylikMizanBelgesi.dosyaAdi}) okunuyor...',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.05 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );
        await Future.delayed(const Duration(milliseconds: 20));
        aylikMizanMetni = await belgeMetniniCikar(aylikMizanBelgesi);
      }

      // 2. Yardımcı Mizan (Muavin) Metni
      String yardimciMizanMetni = '';
      if (yardimciMizanBelgesi != null) {
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📑 [$birimAdi] Yardımcı Mizan (${yardimciMizanBelgesi.dosyaAdi}) taranıyor...',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.10 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );
        await Future.delayed(const Duration(milliseconds: 20));
        yardimciMizanMetni = await belgeMetniniCikar(yardimciMizanBelgesi);
      }

      // 3. Yıllık Mizan Metni
      String yillikMizanMetni = '';
      if (yillikMizanBelgesi != null) {
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📊 [$birimAdi] Yıllık Kümülatif Mizan (${yillikMizanBelgesi.dosyaAdi}) okunuyor...',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.15 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );
        await Future.delayed(const Duration(milliseconds: 20));
        yillikMizanMetni = await belgeMetniniCikar(yillikMizanBelgesi);
      }

      // 4. Diğer Belgeler (Tüm Tevkifat Faturaları, Ödeme Emirleri ve Ek Evraklar)
      final tevkifatFaturaListesi = <Map<String, dynamic>>[];
      final metindekiGecerliVknler = <String>[];

      if (ekBelgeler.isNotEmpty) {
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📁 [$birimAdi] Toplam ${ekBelgeler.length} adet ek evrak (ödeme emirleri ve faturalar) tek tek taranıyor...',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.18 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );

        for (int k = 0; k < ekBelgeler.length; k++) {
          final digerBelge = ekBelgeler[k];
          final digerBelgeMetni = await belgeMetniniCikar(digerBelge);
          try {
            final textForFatura = digerBelgeMetni.length > 25000
                ? digerBelgeMetni.substring(0, 25000)
                : digerBelgeMetni;

            // Belgedeki tüm resmi doğrulanmış VKN/TCKN adaylarını çıkar
            for (final match in RegExp(r'\b\d{10,11}\b').allMatches(textForFatura)) {
              final raw = match.group(0)!;
              if ((raw.length == 10 && BeyannameDenetimServisi.dogrulaVkn(raw)) ||
                  (raw.length == 11 && BeyannameDenetimServisi.dogrulaTckn(raw))) {
                if (!metindekiGecerliVknler.contains(raw)) {
                  metindekiGecerliVknler.add(raw);
                }
              }
            }

            // 1. Öncelik: Tevkifat faturasına özel deterministik ayrıştırıcı
            final ozelTevkifatlar = MizanDeterministikParser.parseTevkifatFaturalari(textForFatura);
            if (ozelTevkifatlar.isNotEmpty) {
              for (final ot in ozelTevkifatlar) {
                final mtr = TurkceFormat.parseSayi(ot['matrahTutari']);
                final mukerrer = tevkifatFaturaListesi.any(
                  (t) => mtr > 0 && (TurkceFormat.parseSayi(t['matrahTutari']) - mtr).abs() < 1.0,
                );
                if (!mukerrer) tevkifatFaturaListesi.add(ot);
              }
            } else {
              // 2. Yedek: FaturaOfflineParser
              final faturalar = FaturaOfflineParser.parse(textForFatura);
              for (final f in faturalar) {
                if (f.kalemler.isNotEmpty) {
                  var firma = f.firmaAdi.trim();
                  var vkn = f.vergiNo.trim();

                  if (firma.isEmpty ||
                      firma.toLowerCase() == 'firma' ||
                      firma.toLowerCase() == 'bilinmeyen firma' ||
                      firma.toUpperCase().contains('ÜNİVERSİTE')) {
                    for (final line in textForFatura.split('\n')) {
                      final l = line.trim();
                      final u = l.toUpperCase();
                      if (l.length > 5 &&
                          !u.contains('ÜNİVERSİTE') &&
                          !u.contains('DÖNER SERMAYE') &&
                          (u.contains('A.Ş') ||
                              u.contains('LTD') ||
                              u.contains('ŞTİ') ||
                              u.contains('TİC') ||
                              u.contains('SAN'))) {
                        firma = l;
                        break;
                      }
                    }
                  }

                  if (vkn.isEmpty ||
                      !(BeyannameDenetimServisi.dogrulaVkn(vkn) ||
                          BeyannameDenetimServisi.dogrulaTckn(vkn))) {
                    vkn = metindekiGecerliVknler.isNotEmpty ? metindekiGecerliVknler.first : '';
                  }

                  // Tevkifat oranını metinden algıla
                  String oranStr = '9/10';
                  double katsayi = 0.9;
                  final oranMatch = RegExp(r'\b([234579])\s*/\s*10\b').firstMatch(textForFatura);
                  if (oranMatch != null) {
                    final pay = int.parse(oranMatch.group(1)!);
                    oranStr = '$pay/10';
                    katsayi = pay / 10.0;
                  }

                  final mtr = f.matrah;
                  final mukerrer = tevkifatFaturaListesi.any(
                    (t) => mtr > 0 && (TurkceFormat.parseSayi(t['matrahTutari']) - mtr).abs() < 1.0,
                  );
                  if (!mukerrer) {
                    tevkifatFaturaListesi.add({
                      'firmaAdi': firma.isNotEmpty ? firma : 'Düzenleyen Firma',
                      'vergiTcNo': vkn,
                      'matrahTutari': f.matrah,
                      'kdvTutari': f.kdvTutari,
                      'tevkifatTutari': double.parse((f.kdvTutari * katsayi).toStringAsFixed(2)),
                      'tevkifatOrani': oranStr,
                    });
                  }
                }
              }
            }
          } catch (_) {}

          final taranmisBelge = digerBelgeMetni.trim().length < 50;
          if (taranmisBelge && isOfflineMod && hasGemini) {
            // Akıllı Hibrit OCR: mizanlar yerelde okundu; SADECE taranmış evrak Gemini Vision'a gider.
            yield AjanLogMesaji(
              zaman: DateTime.now(),
              mesaj: '📷 [$birimAdi] "${digerBelge.dosyaAdi}" taranmış resim; Gemini Vision OCR\'a gönderiliyor...',
              birimAdi: birimAdi,
              ilerlemeYuzdesi: birimIlerlemeBaslangic + (0.18 + (k / ekBelgeler.length) * 0.06) * (birimIlerlemeBitis - birimIlerlemeBaslangic),
            );
            try {
              final ocrFaturalar = await _taranmisFaturaOcr(ayarlar: ayarlar, belge: digerBelge);
              for (final f in ocrFaturalar) {
                final mtr = TurkceFormat.parseSayi(f['matrahTutari']);
                final mukerrer = tevkifatFaturaListesi.any(
                  (t) => mtr > 0 && (TurkceFormat.parseSayi(t['matrahTutari']) - mtr).abs() < 1.0,
                );
                if (!mukerrer) tevkifatFaturaListesi.add(f);
              }
              yield AjanLogMesaji(
                zaman: DateTime.now(),
                mesaj: '📷 [$birimAdi] "${digerBelge.dosyaAdi}" Gemini Vision ile okundu ve listeye eklendi (${ocrFaturalar.length} fatura).',
                birimAdi: birimAdi,
              );
            } catch (e) {
              yield AjanLogMesaji(
                zaman: DateTime.now(),
                mesaj: '⚠️ [$birimAdi] Taranmış evrak OCR başarısız: $e',
                birimAdi: birimAdi,
              );
            }
          } else if (taranmisBelge && isOfflineMod) {
            yield AjanLogMesaji(
              zaman: DateTime.now(),
              mesaj: '📷 [$birimAdi] "${digerBelge.dosyaAdi}" taranmış resim (dijital metin yok). Gemini API anahtarı tanımlı olmadığı için OCR yapılamadı.',
              birimAdi: birimAdi,
            );
          }

          // Çok sayıda dosya varsa (örn. 68 evrak) kullanıcıya her 10 dosyada veya son dosyada ilerleme bildir
          if (ekBelgeler.length > 5 && ((k + 1) % 10 == 0 || k == ekBelgeler.length - 1)) {
            yield AjanLogMesaji(
              zaman: DateTime.now(),
              mesaj: '📄 [$birimAdi] ${k + 1}/${ekBelgeler.length} evrak incelendi (${tevkifatFaturaListesi.length} tevkifat faturası tespit edildi).',
              birimAdi: birimAdi,
            );
          }
        }
      }

      await Future.delayed(const Duration(milliseconds: 15));

      // 5. Kural Tabanlı Deterministik Mizan Ayrıştırması (Her Zaman Çalışır)
      final deterministikSonuc = MizanDeterministikParser.analizEt(
        birimAdi: birimAdi,
        aylikMizanMetni: aylikMizanMetni,
        yillikMizanMetni: yillikMizanMetni,
        yardimciMizanMetni: yardimciMizanMetni,
        oncekiAylarHasilat: birimOncekiAylarHasilat[birimAdi] ?? 0.0,
        ekTevkifatFaturalari: tevkifatFaturaListesi,
      );

      final hasDeterministikVeri = deterministikSonuc.hasilat600Aylik > 0 ||
          deterministikSonuc.hasilat600Kumulatif > 0 ||
          deterministikSonuc.toplamHesaplananKdv > 0 ||
          deterministikSonuc.toplamIndirilecekKdv > 0 ||
          deterministikSonuc.damgaVergisi360 > 0;

      if (hasDeterministikVeri) {
        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: '📐 [$birimAdi] Kural tabanlı mizan tespiti: 600 Hasılat: ${TurkceFormat.para(deterministikSonuc.hasilat600Aylik)}, KDV: ${TurkceFormat.para(deterministikSonuc.toplamHesaplananKdv)}, Damga: ${TurkceFormat.para(deterministikSonuc.damgaVergisi360)}.',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.25 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );
      }

      BirimMizanAnalizSonucu? sonuc;

      // Çevrimdışı/Hızlı moddaysa VEYA ek fatura görseli olmayıp mizan kural tabanlı tam okunduysa doğrudan deterministik sonucu kullan!
      final bool mizanTamOkunduVeEkBelgeYok = hasDeterministikVeri && ekBelgeler.isEmpty;
      if (isOfflineMod || mizanTamOkunduVeEkBelgeYok) {
        sonuc = deterministikSonuc;
      } else {
        // AI İstemi Hazırlama
        final prompt = _buildMizanPrompt(
          birimAdi: birimAdi,
          yil: yil,
          ay: ay,
          aylikMizanMetni: aylikMizanMetni,
          yardimciMizanMetni: yardimciMizanMetni,
          yillikMizanMetni: yillikMizanMetni,
          digerBelgeMetni: ekBelgeler.isNotEmpty ? '(${ekBelgeler.length} adet ek evrak incelendi)' : '',
        );

        final contentParts = <Part>[];
        void addMediaPartIfApplicable(BirimYuklenenBelge? doc, String extractedText) {
          if (doc == null || doc.dosyaBytes == null || doc.dosyaBytes!.isEmpty) return;
          final ext = doc.dosyaUzantisi.toLowerCase().replaceAll('.', '').trim();
          if (ext == 'png') {
            contentParts.add(DataPart('image/png', doc.dosyaBytes!));
          } else if (ext == 'jpg' || ext == 'jpeg') {
            contentParts.add(DataPart('image/jpeg', doc.dosyaBytes!));
          } else if (ext == 'pdf') {
            if (doc.slotTuru == BirimBelgeSlotTuru.diger || extractedText.trim().length < 50) {
              if (doc.dosyaBytes!.length < 15 * 1024 * 1024) {
                contentParts.add(DataPart('application/pdf', doc.dosyaBytes!));
              }
            }
          }
        }

        addMediaPartIfApplicable(aylikMizanBelgesi, aylikMizanMetni);
        addMediaPartIfApplicable(yardimciMizanBelgesi, yardimciMizanMetni);
        addMediaPartIfApplicable(yillikMizanBelgesi, yillikMizanMetni);
        for (final eb in ekBelgeler) {
          addMediaPartIfApplicable(eb, '');
        }
        contentParts.add(TextPart(prompt));

        yield AjanLogMesaji(
          zaman: DateTime.now(),
          mesaj: hasGemini
              ? '🤖 [$birimAdi] Google Gemini AI ile derin belge ve tevkifat analizi yapılıyor...'
              : '🌐 [$birimAdi] OpenRouter üzerinden derin belge ve tevkifat analizi yapılıyor...',
          birimAdi: birimAdi,
          ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.35 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
        );

        int denemeSayisi = 0;
        const maxDeneme = 3;

        while (denemeSayisi < maxDeneme) {
          denemeSayisi++;
          try {
            final aiResponseText = await _calistirAiModel(
              ayarlar: ayarlar,
              prompt: prompt,
              geminiParts: contentParts,
            );

            if (aiResponseText != null && aiResponseText.isNotEmpty) {
              final parsedJson = _parseCleanJson(aiResponseText);
              if (parsedJson != null) {
                final aiTevkifat = (parsedJson['tevkifatFaturalari'] as List<dynamic>?)
                        ?.map((e) => Map<String, dynamic>.from(e as Map))
                        .toList() ??
                    [];

                // AI'dan gelen faturaların VKN'sini doğrula, OCR rakam kayması varsa metindeki gerçek VKN ile onar!
                for (final a in aiTevkifat) {
                  var aVNo = (a['vergiTcNo']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
                  final aMtr = TurkceFormat.parseSayi(a['matrahTutari']);
                  final isGecerli = (aVNo.length == 10 && BeyannameDenetimServisi.dogrulaVkn(aVNo)) ||
                      (aVNo.length == 11 && BeyannameDenetimServisi.dogrulaTckn(aVNo));

                  if (!isGecerli) {
                    // 1) Aynı matraha sahip offline faturada geçerli VKN varsa onu al
                    final eslesenOffline = tevkifatFaturaListesi.where((tf) {
                      final tfMtr = TurkceFormat.parseSayi(tf['matrahTutari']);
                      final tfVkn = (tf['vergiTcNo']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
                      final tfValid = (tfVkn.length == 10 && BeyannameDenetimServisi.dogrulaVkn(tfVkn)) ||
                          (tfVkn.length == 11 && BeyannameDenetimServisi.dogrulaTckn(tfVkn));
                      return tfValid && aMtr > 0 && (tfMtr - aMtr).abs() < 1.0;
                    });
                    if (eslesenOffline.isNotEmpty) {
                      a['vergiTcNo'] = eslesenOffline.first['vergiTcNo'];
                    } else if (aVNo.length >= 6 && metindekiGecerliVknler.isNotEmpty) {
                      // 2) İlk 6 hanesi eşleşen metindeki doğrulanmış VKN'yi al (örn: 4110649031 -> 4110649065)
                      final prefix = aVNo.substring(0, 6);
                      final prefixMatch = metindekiGecerliVknler.where((v) => v.startsWith(prefix));
                      if (prefixMatch.isNotEmpty) {
                        a['vergiTcNo'] = prefixMatch.first;
                      }
                    }
                  }
                }

                // Offline bulunan tevkifat faturalarını mükerrer kayıt oluşturmadan birleştir
                for (final tf in tevkifatFaturaListesi) {
                  final vNo = (tf['vergiTcNo']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
                  final mtr = TurkceFormat.parseSayi(tf['matrahTutari']);
                  final existingIdx = aiTevkifat.indexWhere((a) {
                    final aMtr = TurkceFormat.parseSayi(a['matrahTutari']);
                    return mtr > 0 && (aMtr - mtr).abs() < 1.0;
                  });
                  if (existingIdx == -1) {
                    aiTevkifat.add(tf);
                  } else {
                    // Mevcut kaydın VKN'si boş/geçersizse ve offline VKN geçerliyse güncelle
                    final curVNo = (aiTevkifat[existingIdx]['vergiTcNo']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
                    final curValid = (curVNo.length == 10 && BeyannameDenetimServisi.dogrulaVkn(curVNo)) ||
                        (curVNo.length == 11 && BeyannameDenetimServisi.dogrulaTckn(curVNo));
                    final tfValid = (vNo.length == 10 && BeyannameDenetimServisi.dogrulaVkn(vNo)) ||
                        (vNo.length == 11 && BeyannameDenetimServisi.dogrulaTckn(vNo));
                    if (!curValid && tfValid) {
                      aiTevkifat[existingIdx]['vergiTcNo'] = vNo;
                    }
                  }
                }

                parsedJson['tevkifatFaturalari'] = aiTevkifat;
                parsedJson['birimAdi'] = birimAdi;
                parsedJson['analizTarihi'] = DateTime.now().toIso8601String();

                // Deterministik mizan verileri varsa tüm sayısal mizan alanlarını koru (Sıfır veri kaybı!)
                if (hasDeterministikVeri) {
                  void koruSayi(String key, double detVal) {
                    if (detVal > 0 && TurkceFormat.parseSayi(parsedJson[key]) == 0) {
                      parsedJson[key] = detVal;
                    }
                  }

                  koruSayi('hasilat600Aylik', deterministikSonuc.hasilat600Aylik);
                  koruSayi('hasilat600Kumulatif', deterministikSonuc.hasilat600Kumulatif);
                  koruSayi('krediKarti123', deterministikSonuc.krediKarti123);
                  koruSayi('hesaplananKdv10', deterministikSonuc.hesaplananKdv10);
                  koruSayi('hesaplananKdvMatrah10', deterministikSonuc.hesaplananKdvMatrah10);
                  koruSayi('hesaplananKdv20', deterministikSonuc.hesaplananKdv20);
                  koruSayi('hesaplananKdvMatrah20', deterministikSonuc.hesaplananKdvMatrah20);
                  koruSayi('indirilecekKdv10', deterministikSonuc.indirilecekKdv10);
                  koruSayi('indirilecekKdvMatrah10', deterministikSonuc.indirilecekKdvMatrah10);
                  koruSayi('indirilecekKdv20', deterministikSonuc.indirilecekKdv20);
                  koruSayi('indirilecekKdvMatrah20', deterministikSonuc.indirilecekKdvMatrah20);
                  koruSayi('damgaVergisi360', deterministikSonuc.damgaVergisi360);
                  koruSayi('damgaMatrah', deterministikSonuc.damgaMatrah);
                  koruSayi('muhtasarGelir360', deterministikSonuc.muhtasarGelir360);
                  koruSayi('muhtasarDamga360', deterministikSonuc.muhtasarDamga360);
                  koruSayi('devredenKdv190', deterministikSonuc.devredenKdv190);
                  if (deterministikSonuc.yardimciMizanKullanildi) {
                    parsedJson['yardimciMizanKullanildi'] = true;
                    koruSayi('yardimciMizan391Toplam', deterministikSonuc.yardimciMizan391Toplam);
                    koruSayi('yardimciMizan191Toplam', deterministikSonuc.yardimciMizan191Toplam);
                    koruSayi('yardimciMizan600Toplam', deterministikSonuc.yardimciMizan600Toplam);
                  }
                }

                sonuc = BirimMizanAnalizSonucu.fromMap(parsedJson);
                break;
              }
            }

            throw Exception('Yapay zeka geçerli JSON çıktısı üretemedi.');
          } catch (e) {
            final hataStr = e.toString();
            debugPrint('[$birimAdi] Deneme $denemeSayisi/$maxDeneme hatası: $hataStr');

            if (denemeSayisi < maxDeneme) {
              final beklemeSaniye = denemeSayisi * 2;
              yield AjanLogMesaji(
                zaman: DateTime.now(),
                mesaj: '⏳ [$birimAdi] AI servisinden yanıt bekleniyor ($beklemeSaniye sn sonra tekrar denenecek: $denemeSayisi/$maxDeneme)...',
                birimAdi: birimAdi,
                ilerlemeYuzdesi: birimIlerlemeBaslangic + 0.40 * (birimIlerlemeBitis - birimIlerlemeBaslangic),
                isHata: true,
              );
              await Future.delayed(Duration(seconds: beklemeSaniye));
            } else {
              if (hasDeterministikVeri || tevkifatFaturaListesi.isNotEmpty) {
                yield AjanLogMesaji(
                  zaman: DateTime.now(),
                  mesaj: 'ℹ️ [$birimAdi] AI yanıt veremedi. Kural tabanlı deterministik analiz sonucu korundu.',
                  birimAdi: birimAdi,
                  ilerlemeYuzdesi: birimIlerlemeBitis,
                );
                sonuc = deterministikSonuc;
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

  /// Hibrit mod: yalnızca taranmış (metinsiz) ek evrakı Gemini Vision ile okur.
  /// Mizanlar gönderilmez; token maliyeti minimumdur.
  Future<List<Map<String, dynamic>>> _taranmisFaturaOcr({
    required SistemAyarlariModel ayarlar,
    required BirimYuklenenBelge belge,
  }) async {
    final bytes = belge.dosyaBytes;
    if (bytes == null || bytes.isEmpty || bytes.length > 15 * 1024 * 1024) return [];
    final ext = belge.dosyaUzantisi.toLowerCase().replaceAll('.', '').trim();
    final mime = ext == 'png'
        ? 'image/png'
        : (ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'application/pdf');
    final prompt = _buildSadeceFaturaOcrPrompt();
    final text = await _calistirAiModel(
      ayarlar: ayarlar,
      prompt: prompt,
      geminiParts: [DataPart(mime, bytes), TextPart(prompt)],
    );
    if (text == null || text.trim().isEmpty) return [];
    final json = _parseCleanJson(text);
    final liste = (json?['tevkifatFaturalari'] as List<dynamic>?) ?? const [];
    final sonuc = <Map<String, dynamic>>[];
    for (final e in liste) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final vkn = (m['vergiTcNo']?.toString() ?? '').replaceAll(RegExp(r'[^\d]'), '');
      final gecerli = (vkn.length == 10 && BeyannameDenetimServisi.dogrulaVkn(vkn)) ||
          (vkn.length == 11 && BeyannameDenetimServisi.dogrulaTckn(vkn));
      // Geçersiz VKN uydurulmaz; boş bırakılıp denetimde görünür kalır.
      m['vergiTcNo'] = gecerli ? vkn : '';
      final matrah = TurkceFormat.parseSayi(m['matrahTutari']);
      if (matrah <= 0) continue;
      m['matrahTutari'] = matrah;
      m['kdvTutari'] = TurkceFormat.parseSayi(m['kdvTutari']);
      m['tevkifatTutari'] = TurkceFormat.parseSayi(m['tevkifatTutari']);
      m['tevkifatOrani'] = m['tevkifatOrani']?.toString() ?? '9/10';
      m['firmaAdi'] = (m['firmaAdi']?.toString().trim().isNotEmpty ?? false)
          ? m['firmaAdi'].toString().trim()
          : 'Düzenleyen Firma';
      sonuc.add(m);
    }
    return sonuc;
  }

  String _buildSadeceFaturaOcrPrompt() {
    return '''
Ekteki belge taranmış bir fatura / ek evraktır. Yalnızca KDV TEVKİFATLI faturaları çıkar.
Kurallar: Rakam uydurma. Okuyamadığın alanı boş bırak. VKN 10, TCKN 11 hanedir.
Tutarları sayı olarak ver (ör. 12345.67). Tevkifat oranı "9/10", "7/10", "5/10", "2/10" biçimindedir.
SADECE şu JSON'u döndür, başka metin yazma:
{"tevkifatFaturalari":[{"firmaAdi":"","vergiTcNo":"","matrahTutari":0,"kdvTutari":0,"tevkifatTutari":0,"tevkifatOrani":"9/10"}]}
''';
  }

  /// Denetim uyarısı için kısa uzman mütalaası üretir (yalnızca metin, belge gönderilmez).
  Future<String> denetimMutalaasiAl({
    required String birimAdi,
    required String baslik,
    required String aciklama,
    double? beklenen,
    double? bulunan,
    double? fark,
  }) async {
    final ayarlar = await _ayarlarService.getAyarlar();
    if (ayarlar.geminiApiKey.trim().isEmpty && ayarlar.deepseekApiKey.trim().isEmpty) {
      throw Exception('Sistem Ayarlarında tanımlı bir AI API anahtarı yok.');
    }
    final prompt = '''
Sen Türk kamu üniversitesi döner sermaye işletmelerinde uzman bir mali müşavirsin.
Birim: $birimAdi
Denetim bulgusu: $baslik
Açıklama: $aciklama
Beklenen: ${beklenen ?? '-'} | Bulunan: ${bulunan ?? '-'} | Fark: ${fark ?? '-'}
Görev: Bu farkın olası nedenlerini, ilgili mevzuatı (KDVK, DVK, GVK) ve beyannamede yapılması gereken somut düzeltme adımlarını Türkçe, en fazla 10 madde halinde açıkla. Emin olmadığın konuda kesin hüküm verme.
''';
    final text = await _calistirAiModel(ayarlar: ayarlar, prompt: prompt);
    return (text ?? '').trim().isEmpty ? 'AI yanıt üretmedi.' : text!.trim();
  }

  /// Canlı sistem günlüğünü, 7 birimin çıkarılan mizan/fatura sonuçlarını ve
  /// 11 senaryolu çapraz denetim raporunu analiz ederek gözden kaçan anomalileri
  /// ve mevzuat risklerini bulan üst düzey AI Baş Denetçi & Mali Müşavir mütalaası üretir.
  Future<String> gunlukVeDenetimAiUzmanAnalizi({
    required int yil,
    required int ay,
    required List<AjanLogMesaji> loglar,
    required BeyannameAjanRaporu? rapor,
  }) async {
    final ayarlar = await _ayarlarService.getAyarlar();
    if (ayarlar.geminiApiKey.trim().isEmpty && ayarlar.deepseekApiKey.trim().isEmpty) {
      throw Exception(
        'Sistem Ayarlarında geçerli bir Google Gemini veya DeepSeek/OpenRouter API anahtarı tanımlı değil. Lütfen Sistem Ayarları sayfasından API anahtarınızı giriniz.',
      );
    }

    // 1. Log metnini formatla
    final logBuffer = StringBuffer();
    for (final l in loglar) {
      logBuffer.writeln('[${l.formatliZaman}] ${l.mesaj}');
    }
    final logMetni = logBuffer.toString();

    // 2. Rapor özeti ve birim rakamlarını formatla
    final raporBuffer = StringBuffer();
    if (rapor != null) {
      raporBuffer.writeln('BEYANNAME DÖNEMİ: $yil / ${ay.toString().padLeft(2, '0')}');
      raporBuffer.writeln('ANALİZ EDİLEN BİRİMLER:');
      for (final entry in rapor.birimSonuclari.entries) {
        final b = entry.value;
        raporBuffer.writeln(
          '- ${entry.key}: 600 Hasılat: ${TurkceFormat.para(b.hasilat600Aylik)} TL | '
          '123 POS: ${TurkceFormat.para(b.krediKarti123)} TL | '
          '391 Hesaplanan KDV: ${TurkceFormat.para(b.toplamHesaplananKdv)} TL (%10: ${TurkceFormat.para(b.hesaplananKdv10)}, %20: ${TurkceFormat.para(b.hesaplananKdv20)}) | '
          '191 İndirilecek KDV: ${TurkceFormat.para(b.toplamIndirilecekKdv)} TL | '
          '360 Damga Vergisi: ${TurkceFormat.para(b.damgaVergisi360)} TL | '
          'Tevkifat Fatura Sayısı: ${b.tevkifatFaturalari.length}',
        );
        if (b.tevkifatFaturalari.isNotEmpty) {
          for (final f in b.tevkifatFaturalari) {
            raporBuffer.writeln(
              '    * Fatura: ${f['firmaAdi']} (VKN: ${f['vergiTcNo']}) - Matrah: ${TurkceFormat.para(TurkceFormat.parseSayi(f['matrahTutari']))} TL, '
              'KDV: ${TurkceFormat.para(TurkceFormat.parseSayi(f['kdvTutari']))} TL, Tevkifat: ${TurkceFormat.para(TurkceFormat.parseSayi(f['tevkifatTutari']))} TL (${f['tevkifatOrani']})',
            );
          }
        }
      }

      raporBuffer.writeln('\nÇAPRAZ DENETİM VE MUTABAKAT TESTLERİ:');
      for (final d in rapor.denetimKontrolleri) {
        final durumStr = d.seviye == DenetimSeviyesi.bilgi
            ? 'BAŞARILI'
            : (d.seviye == DenetimSeviyesi.hata ? 'KRİTİK HATA' : 'İNCELEME UYARISI');
        final birimEtiket = d.birimAdi.isNotEmpty ? d.birimAdi : 'TÜM BİRİMLER';
        raporBuffer.writeln(
          '- [$durumStr] $birimEtiket - ${d.baslik}: ${d.aciklama} '
          '${d.fark != null ? '(Fark: ${TurkceFormat.para(d.fark!)})' : ''}',
        );
      }
    }

    final prompt = '''
Sen Türk Kamu Üniversitesi Döner Sermaye İşletmeleri (2547 sayılı YÖK Kanunu Md. 58, 5018 sayılı KMYKK), Katma Değer Vergisi Kanunu (KDVK 1, 17/1 sağlık hizmetleri istisnası, 17/2-b eğitim/kurs istisnası, 9/10 ve 7/10 KDV2 tevkifatı), Damga Vergisi Kanunu (binde 9,48 nispetli damga vergisi, 360.03.05 hesabı), Gelir Vergisi Kanunu (Muhtasar) ve Muhasebat Genel Müdürlüğü Döner Sermaye Hesap Planı (100, 102, 123 POS, 190, 191, 360, 391, 600) konularında 25 yıllık kıdemli Baş Denetçi, Yeminli Mali Müşavir (YMM) ve DSYS (Döner Sermaye Yönetim Sistemi) Baş Mimarı/Uzmanısın.

GÖREV:
Aşağıdaki canlı sistem günlüğünü (OCR okuma adımları, mizan ayrıştırmaları, tevkifat tespitleri), 7 döner sermaye biriminin çıkarılan rakamlarını ve 11 senaryolu çapraz mutabakat sonuçlarını satır satır denetle.
Kullanıcının gözünden kaçabilecek her türlü anomalileri, mevzuat uyumsuzluklarını ve riskleri bul, mali müşavir tavsiyeleriyle birlikte detaylı bir Baş Denetçi Raporu hazırla.

BİLGİ BANKASI VE KRİTİK DENETİM KURALLARI:
1. 123 KREDİ KARTI / POS KONTROLÜ:
   - Farklı birimlerin 123 POS tutarları kesinlikle birbirinin aynısı olamaz! Örneğin Diş Hekimliği ile DTS'nin POS tutarı kuruşu kuruşuna aynıysa (örn: 3.325.718,15 TL), bu bir dosya karışıklığı, mükerrer mizan yüklemesi veya veri aktarım hatasıdır; derhal kırmızı bayrakla uyar.
2. KDVK 17 İSTİSNALARI VE 600 HASILAT / KDV İLİŞKİSİ:
   - Ağız ve Diş Sağlığı Merkezi (Diş Hekimliği): 600 Hasılat yüksek olsa dahi (örn: 10 Milyon TL), KDVK Madde 17/1 (Üniversite hastane/sağlık hizmetleri) kapsamında KDV hesaplanmaz (0 TL olması mevzuata uygundur).
   - Sürekli Eğitim Merkezi (USEM): Kurs ve eğitim hasılatları KDVK Madde 17/2-b kapsamında KDV'den istisnadır. KDV'nin 0 TL olması mevzuatla tam uyumludur.
   - DTS, UBATAM, TÖMER, TADAUM, DÖSİM: Genel oranda (%20 veya %10) KDV'ye tabidir. Hasılat varken KDV olmaması durumunda uyarı verilmelidir.
3. 2 NOLU KDV TEVKİFAT FATURALARI:
   - Üniversiteye kesilen faturalarda tevkifat oranları 9/10 (temizlik, güvenlik, yemek, işgücü) veya 7/10 (yapım işleri, bakım-onarım, laboratuvar/dental) olmalıdır.
   - VKN 10 haneli, TCKN 11 haneli olmalıdır.
4. DAMGA VERGİSİ (360.03.05):
   - Kamu idarelerince yapılan istihkaktan binde 9,48 oranında damga vergisi kesilir.
5. MİZAN BÜTÜNLÜĞÜ VE EKSİK EVRAKLAR:
   - Bir birimde Aylık Mizan yoksa ve kümülatiften türetildiyse bunu açıkça belirt.
   - Ters bakiye (191'in alacak vermesi, 391'in borç vermesi vb.) olup olmadığını belirt.

DÖNEM: $yil / ${ay.toString().padLeft(2, '0')}

ANALİZ EDİLEN BİRİMLER VE BULGULAR:
${raporBuffer.toString()}

CANLI SİSTEM VE İŞLEM GÜNLÜĞÜ:
$logMetni

İSTENEN RAPOR FORMATI (Lütfen tam Türkçe ve Markdown formatında sun):
# 🏛️ T.C. Üniversite Döner Sermaye Beyanname Baş Denetçi Değerlendirmesi
## 🚨 1. Gözden Kaçan Kritik Bulgular ve Anomaliler
(Varsa 123 POS mükerrerliği, eksik evrak, VKN hataları vb.)
## ⚖️ 2. Vergi ve Mevzuat Uyumu Değerlendirmesi (KDVK 17, KDV2 Tevkifat, Damga)
(Birim birim mevzuata uygunluk durumları)
## 📋 3. Birim Bazlı Özet Tablo ve Tespitler
## 💡 4. Mali Müşavir Eylem Planı ve Düzeltme Önerileri
(Kullanıcının beyannameyi vermeden önce yapması gereken somut adımlar)
''';

    final text = await _calistirAiModel(ayarlar: ayarlar, prompt: prompt);
    return (text ?? '').trim().isEmpty ? 'AI Uzman Analizi yanıt üretemedi.' : text!.trim();
  }

  /// OpenRouter / OpenAI uyumlu REST API çağrısı
  Future<String?> _runOpenRouter({
    required String apiUrl,
    required String apiKey,
    required String modelName,
    required String prompt,
  }) async {
    final cleanUrl = apiUrl.trim().isEmpty
        ? 'https://openrouter.ai/api/v1'
        : apiUrl.trim();
    final base = cleanUrl.endsWith('/')
        ? cleanUrl.substring(0, cleanUrl.length - 1)
        : cleanUrl;
    final endpoint = base.endsWith('/chat/completions')
        ? base
        : '$base/chat/completions';
    final resolvedModel = modelName.trim().isEmpty
        ? 'google/gemini-2.0-flash-001'
        : modelName.trim();

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $apiKey',
        'HTTP-Referer': 'https://dsys.local',
        'X-Title': 'DSYS Beyanname',
      },
      body: jsonEncode({
        'model': resolvedModel,
        'messages': [
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'temperature': 0.1,
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        final choices = decoded['choices'] as List<dynamic>?;
        if (choices != null && choices.isNotEmpty) {
          final first = choices.first as Map<String, dynamic>;
          final msg = first['message'] as Map<String, dynamic>?;
          return msg?['content']?.toString();
        }
      }
    } else {
      throw Exception('OpenRouter Hatası (${response.statusCode}): ${response.body}');
    }
    return null;
  }

  /// Birincil olarak Google Gemini (tanımlıysa), yoksa veya hata verirse OpenRouter çalıştırır
  Future<String?> _calistirAiModel({
    required SistemAyarlariModel ayarlar,
    required String prompt,
    List<Part>? geminiParts,
  }) async {
    Object? sonHata;

    // 1. İLK TERCİH: Google Gemini Tanımlıysa Önce Onu Çağır (Fatura modülüyle aynı kurumsal standart)
    if (ayarlar.geminiApiKey.trim().isNotEmpty) {
      try {
        final parts = geminiParts ?? [TextPart(prompt)];
        final text = await _runGeminiWithFallback(
          apiKey: ayarlar.geminiApiKey,
          preferredModel: ayarlar.geminiModel,
          parts: parts,
        );
        if (text != null && text.trim().isNotEmpty) return text;
      } catch (e) {
        sonHata = e;
        debugPrint('[Beyanname AI] Gemini çağrısı hata verdi: $e');
        if (ayarlar.deepseekApiKey.trim().isEmpty) rethrow;
      }
    }

    // 2. YEDEK HAT: Gemini başarısız olduysa veya anahtarı yoksa OpenRouter devreye girer
    if (ayarlar.deepseekApiKey.trim().isNotEmpty) {
      try {
        debugPrint('[Beyanname AI] Gemini yanıt vermedi, OpenRouter yedeğine geçiliyor...');
        final text = await _runOpenRouter(
          apiUrl: ayarlar.deepseekApiUrl,
          apiKey: ayarlar.deepseekApiKey,
          modelName: ayarlar.deepseekModel,
          prompt: prompt,
        );
        if (text != null && text.trim().isNotEmpty) return text;
      } catch (e) {
        sonHata = e;
        debugPrint('[Beyanname AI] OpenRouter çağrısı da hata verdi: $e');
        rethrow;
      }
    }

    if (sonHata != null) throw Exception(sonHata.toString());
    return null;
  }

  /// Gemini API'ye model fallback ve retry zinciri ile istek gönderir.
  Future<String?> _runGeminiWithFallback({
    required String apiKey,
    required List<Part> parts,
    String? preferredModel,
  }) async {
    final modelOrder = <String>[];
    String? cleanPreferred = preferredModel?.trim();
    if (cleanPreferred != null && cleanPreferred.isNotEmpty) {
      modelOrder.add(cleanPreferred);
    }
    // Resmi Google Gemini modelleri ve yedek zinciri
    const officialModels = [
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-3.8-flash',
      'gemini-3.6-flash',
      'gemini-3.7-flash',
      'gemini-3.5-flash',
    ];
    for (final m in officialModels) {
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

    // Markdown ```json ... ``` bloğu varsa çıkar
    final mdMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(cleaned);
    if (mdMatch != null) {
      cleaned = mdMatch.group(1)!.trim();
    } else {
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();
    }

    // Trailing comma temizliği: , } veya , ] -> } veya ]
    cleaned = cleaned.replaceAll(RegExp(r',\s*([}\]])'), r'$1');

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      // Regex ile ilk { ... } bloğunu bulmayı dene
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
      if (match != null) {
        try {
          var block = match.group(0)!;
          block = block.replaceAll(RegExp(r',\s*([}\]])'), r'$1');
          final decoded = jsonDecode(block);
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
    required String yardimciMizanMetni,
    required String yillikMizanMetni,
    required String digerBelgeMetni,
  }) {
    return '''
Sen Türkiye Cumhuriyeti Üniversiteleri Döner Sermaye İşletmeleri konusunda uzmanlaşmış kıdemli bir Mali Müşavir ve Beyanname Hazırlama Yapay Zeka Ajanısın.

GÖREV:
Aşağıda verilen "$birimAdi" birimine ait $yil yılı ${ay.toString().padLeft(2, '0')}. ay belgelerini (Aylık Mizan, Yardımcı Mizan / Muavin, Yıllık Kümülatif Mizan ve Ek Belgeler) incele.
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
8. TEVKİFATLI FATURALAR (KDV 2 TEVKİFATI) VE DÜZENLEYEN FİRMA TESPİTİ:
   - Ekli belgelerde (taranmış PDF, imaj veya dijital fatura) yer alan faturaları bizzat incele.
   - Faturayı düzenleyen / satan firmanın tam ticari unvanını ("firmaAdi") doğrudan belgenin üzerinden oku.
   - Faturayı düzenleyen firmanın 10 haneli Vergi Kimlik Numarasını (VKN) veya 11 haneli T.C. Kimlik Numarasını ("vergiTcNo") faturanın üzerindeki VKN/TCKN/Vergi No alanından veya kaşeden oku.
   - Faturanın matrah tutarını ("matrahTutari"), KDV tutarını ("kdvTutari"), tevkifat tutarını ("tevkifatTutari") ve tevkifat oranını ("tevkifatOrani": "9/10", "5/10", "7/10", "2/10" vb.) kuruşu kuruşuna çıkar.
   - DİKKAT: Firma adı ve VKN ASLA uydurma veya varsayılan olamaz. Belgede basılı olan gerçek satıcı unvanını ve vergi numarasını çıkar. Herhangi bir firmaya ait olabilir (yazılım, medikal, temizlik, kırtasiye, teknik servis vb.).
   - Eğer fatura mevcut ancak mizandaki 600/391/191 hesaplarına henüz yansımamışsa veya tutarlar arasında mutabakatsızlık varsa "aciklama" alanına açıkça yaz.
9. YARDIMCI MİZAN (MUAVİN / ALT HESAP MİZANI) MUTABAKATI:
   - Eğer Yardımcı Mizan (Muavin) yüklenmişse; 391.20, 391.10 (%20 ve %10 KDV), 191.20, 191.10 ve 600 alt gelir kodlarını buradan kuruşu kuruşuna teyit et.
   - Yardımcı mizan alt toplamları ile Ana Mizan bakiyelerini karşılaştır. Fark varsa "aciklama" alanına yaz.
   - "yardimciMizanKullanildi": true/false,
   - "yardimciMizan391Toplam": 0.0,
   - "yardimciMizan191Toplam": 0.0,
   - "yardimciMizan600Toplam": 0.0

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
  "yardimciMizanKullanildi": false,
  "yardimciMizan391Toplam": 0.0,
  "yardimciMizan191Toplam": 0.0,
  "yardimciMizan600Toplam": 0.0,
  "tevkifatFaturalari": [
    {
      "firmaAdi": "Faturayı Düzenleyen Firmanın Tam Ticari Unvanı",
      "vergiTcNo": "Faturadaki 10 Haneli VKN veya 11 Haneli TCKN",
      "matrahTutari": 0.0,
      "kdvTutari": 0.0,
      "tevkifatTutari": 0.0,
      "tevkifatOrani": "9/10"
    }
  ],
  "aciklama": ""
}

---
AYLIK MİZAN METNİ:
$aylikMizanMetni

---
YARDIMCI MİZAN (MUAVİN) METNİ:
$yardimciMizanMetni

---
YILLIK KÜMÜLATİF MİZAN METNİ:
$yillikMizanMetni

---
DİĞER BELGELER METNİ:
$digerBelgeMetni
''';
  }
}
