import 'package:flutter/foundation.dart';

import 'yerel_ocr_stub.dart'
    if (dart.library.js_interop) 'yerel_ocr_web.dart' as platform;

/// Taranmış PDF'ler için cihaz içi (ücretsiz) OCR katmanı.
///
/// PDF içindeki gömülü JPEG sayfa görüntülerini çıkarır ve platform OCR'ına verir.
/// Hiçbir veri internete gönderilmez.
class FaturaYerelOcr {
  const FaturaYerelOcr();

  bool get destekleniyor => platform.yerelOcrDestekleniyor;

  Future<String> gorseldenMetin(Uint8List jpeg) =>
      platform.yerelOcrCalistir(jpeg);

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
