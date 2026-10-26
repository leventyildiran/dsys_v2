import 'package:flutter/foundation.dart';

import '../tesseract_ocr_web.dart';

/// Web'de Tesseract.js, PDF.js ve jsQR (web/index.html içinde yüklü) cihazda çalışır; ücretsizdir.
bool get yerelOcrDestekleniyor => true;

Future<String> yerelOcrCalistir(Uint8List jpegBytes) =>
    TesseractOcrWeb.ocrFromImageBytes(jpegBytes);

Future<Map<String, dynamic>> yerelBelgeTara(
  Uint8List bytes, {
  required bool isPdf,
  int maxSayfa = 6,
  bool ocrCalistir = true,
}) =>
    TesseractOcrWeb.taraPdfVeyaGorsel(
      bytes,
      isPdf: isPdf,
      maxSayfa: maxSayfa,
      ocrCalistir: ocrCalistir,
    );
