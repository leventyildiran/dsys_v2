import 'package:flutter/foundation.dart';

import '../tesseract_ocr_web.dart';

/// Web'de Tesseract.js (web/index.html içinde yüklü) cihazda çalışır; ücretsizdir.
bool get yerelOcrDestekleniyor => true;

Future<String> yerelOcrCalistir(Uint8List jpegBytes) =>
    TesseractOcrWeb.ocrFromImageBytes(jpegBytes);
