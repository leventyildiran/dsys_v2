import 'package:flutter/foundation.dart';

/// Web dışı platformlarda (testler, masaüstü) yerel OCR yoktur.
bool get yerelOcrDestekleniyor => false;

Future<String> yerelOcrCalistir(Uint8List jpegBytes) async => '';
