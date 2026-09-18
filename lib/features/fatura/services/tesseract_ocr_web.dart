@JS()
library tesseract_ocr;

import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

@JS('Tesseract.recognize')
external JSPromise _recognize(JSAny image, JSString langs);

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
}
