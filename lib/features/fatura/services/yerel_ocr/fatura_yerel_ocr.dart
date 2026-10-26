import 'package:flutter/foundation.dart';

import 'gib_karekod_ve_ubl_cozucu.dart';
import 'yerel_ocr_stub.dart'
    if (dart.library.js_interop) 'yerel_ocr_web.dart' as platform;

/// Yerel belge taraması sonucu (GİB Karekod / UBL verileri + Yerel OCR metni).
class YerelBelgeTaramaSonucu {
  final List<GibKarekodFaturaVerisi> gibFaturalari;
  final String ocrMetni;

  const YerelBelgeTaramaSonucu({
    this.gibFaturalari = const [],
    this.ocrMetni = '',
  });

  bool get veriVarMi => gibFaturalari.isNotEmpty || ocrMetni.trim().isNotEmpty;

  /// GİB Karekod sentetik metinleri ile OCR metninin birleştirilmiş hali.
  String get birlesikMetin {
    final sb = StringBuffer();
    for (final g in gibFaturalari) {
      sb.writeln(g.toSentetikFaturaMetni());
    }
    if (ocrMetni.trim().isNotEmpty) {
      sb.writeln(ocrMetni.trim());
    }
    return sb.toString().trim();
  }
}

/// Taranmış PDF ve görseller için cihaz içi (0 TL, ücretsiz) GİB Karekod + UBL + OCR katmanı.
///
/// 1) Ham bayt akışındaki gömülü GİB Karekod JSON ve UBL-TR XML verilerini yakalar.
/// 2) Web'de Mozilla PDF.js ile tüm PDF sayfalarını (FlateDecode, JBIG2, CCITTFax, JPEG dahil)
///    Canvas'a çizip önce `jsQR` ile GİB e-Fatura Karekodunu okur, ardından `Tesseract.js` ile Türkçe OCR yapar.
/// 3) Hiçbir veri internete veya harici bir bulut API'sine gönderilmez.
class FaturaYerelOcr {
  const FaturaYerelOcr();

  bool get destekleniyor => platform.yerelOcrDestekleniyor;

  Future<String> gorseldenMetin(Uint8List jpeg) =>
      platform.yerelOcrCalistir(jpeg);

  /// Hem PDF hem de resim (PNG/JPG) belgelerini cihaz içinde tarar:
  /// - GİB e-Fatura Karekodu (`jsQR` + gömülü akış)
  /// - UBL-TR gömülü XML
  /// - PDF.js + Tesseract.js Türkçe OCR
  Future<YerelBelgeTaramaSonucu> pdfVeyaGorselTara(
    Uint8List bytes, {
    required bool isPdf,
    int maxSayfa = 6,
    bool ocrCalistir = true,
  }) async {
    final gibListesi = <GibKarekodFaturaVerisi>[];

    // 1. Aşama: Ham baytlardan gömülü GİB Karekod JSON veya UBL-TR XML ara (0 ms, tüm platformlarda çalışır)
    final gomuluVeriler = GibKarekodVeUblCozucu.hamBaytlardanGomuluVeriCikar(bytes);
    for (final gv in gomuluVeriler) {
      gibListesi.add(gv);
    }

    String ocrMetni = '';

    // 2. Aşama: Tarayıcıda PDF.js Canvas + jsQR + Tesseract.js çalıştır
    if (destekleniyor) {
      final rawSonuc = await platform.yerelBelgeTara(
        bytes,
        isPdf: isPdf,
        maxSayfa: maxSayfa,
        ocrCalistir: ocrCalistir,
      );
      final qrStrings = (rawSonuc['qrListesi'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      for (final qr in qrStrings) {
        final cozulmusListe = GibKarekodVeUblCozucu.cozGibKarekodJsonListesi(qr);
        for (final cozulmus in cozulmusListe) {
          final mukerrer = gibListesi.any((x) =>
              x.tevkifatOrani == cozulmus.tevkifatOrani &&
              x.kdvOrani == cozulmus.kdvOrani &&
              ((x.faturaNo.isNotEmpty &&
                      x.faturaNo == cozulmus.faturaNo &&
                      (x.matrah - cozulmus.matrah).abs() < 0.05) ||
                  (x.saticiVknTckn == cozulmus.saticiVknTckn &&
                      (x.matrah - cozulmus.matrah).abs() < 0.05)));
          if (!mukerrer) {
            gibListesi.add(cozulmus);
          }
        }
      }
      ocrMetni = (rawSonuc['ocrMetni'] ?? '').toString().trim();

      // 3. Aşama (Yedek): Eğer PDF.js metin çıkaramadıysa ham JPEG akışlarını dene
      if (ocrMetni.isEmpty && ocrCalistir && isPdf) {
        final jpegs = pdfIciJpegler(bytes, maxAdet: maxSayfa);
        if (jpegs.isNotEmpty) {
          final sb = StringBuffer();
          for (final jp in jpegs) {
            final t = await gorseldenMetin(jp);
            if (t.trim().isNotEmpty) sb.writeln(t.trim());
          }
          ocrMetni = sb.toString().trim();
        }
      }
    }

    return YerelBelgeTaramaSonucu(
      gibFaturalari: gibListesi,
      ocrMetni: ocrMetni,
    );
  }

  /// Taranmış PDF'lerde sayfa başına gömülü JPEG akışlarını bulur.
  static List<Uint8List> pdfIciJpegler(Uint8List pdfBytes, {int maxAdet = 6}) {
    final bulunan = <Uint8List>[];
    var i = 0;
    while (i < pdfBytes.length - 1 && bulunan.length < maxAdet) {
      if (pdfBytes[i] == 0xFF && pdfBytes[i + 1] == 0xD8) {
        var end = i + 2;
        var kapandi = false;
        while (end < pdfBytes.length - 1) {
          if (pdfBytes[end] == 0xFF && pdfBytes[end + 1] == 0xD9) {
            end += 2;
            final parca = pdfBytes.sublist(i, end);
            // Küçük logo/ikonları atla; yalnızca sayfa boyutlu görüntüler.
            if (parca.length > 20 * 1024) bulunan.add(Uint8List.fromList(parca));
            i = end;
            kapandi = true;
            break;
          }
          end++;
        }
        if (!kapandi) break;
      } else {
        i++;
      }
    }
    return bulunan;
  }
}
