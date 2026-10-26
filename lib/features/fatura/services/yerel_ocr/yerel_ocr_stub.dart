import 'package:flutter/foundation.dart';

/// Web dışı platformlarda (testler, masaüstü) tarayıcı tabanlı OCR yoktur.
bool get yerelOcrDestekleniyor => false;

Future<String> yerelOcrCalistir(Uint8List jpegBytes) async => '';

Future<Map<String, dynamic>> yerelBelgeTara(
  Uint8List bytes, {
  required bool isPdf,
  int maxSayfa = 6,
  bool ocrCalistir = true,
}) async =>
    const {'qrListesi': <String>[], 'ocrMetni': ''};
