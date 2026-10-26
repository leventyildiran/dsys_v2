@JS()
library;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

@JS('Tesseract.recognize')
external JSPromise _recognize(JSAny image, JSString langs);

@JS('dsysYerelBelgeMotoru.taraBase64')
external JSPromise _taraBase64(
  JSString base64Data,
  JSBoolean isPdf,
  JSNumber maxSayfa,
  JSBoolean ocrCalistir,
);

class TesseractOcrWeb {
  static Future<String> ocrFromImageBytes(Uint8List imageBytes) async {
    if (!kIsWeb) return '';
    try {
      final base64String = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';

      // Call Tesseract.recognize
      final promise = _recognize(base64String.toJS, 'tur'.toJS);
      final resultJs = await promise.toDart;

      // Extract data.text from result
      final resultObj = resultJs as JSObject;
      final dataObj = resultObj.getProperty('data'.toJS) as JSObject;
      final textJs = dataObj.getProperty('text'.toJS) as JSString;

      return textJs.toDart;
    } catch (e) {
      debugPrint('Tesseract OCR Hatası: $e');
      return '';
    }
  }

  /// PDF.js + jsQR (GİB Karekod) + Tesseract.js ile hem PDF hem de görsel dosyaları
  /// tarayıcı içinde (0 TL maliyetle) çözümler.
  static Future<Map<String, dynamic>> taraPdfVeyaGorsel(
    Uint8List bytes, {
    required bool isPdf,
    int maxSayfa = 6,
    bool ocrCalistir = true,
  }) async {
    if (!kIsWeb || bytes.isEmpty) {
      return const {'qrListesi': <String>[], 'ocrMetni': ''};
    }
    try {
      final b64 = base64Encode(bytes);
      final promise = _taraBase64(
        b64.toJS,
        isPdf.toJS,
        maxSayfa.toJS,
        ocrCalistir.toJS,
      );
      final jsonStrJs = await promise.toDart;
      final jsonStr = (jsonStrJs as JSString).toDart;
      final decoded = jsonDecode(jsonStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (e) {
      debugPrint('dsysYerelBelgeMotoru Hatası: $e');
    }
    return const {'qrListesi': <String>[], 'ocrMetni': ''};
  }
}
