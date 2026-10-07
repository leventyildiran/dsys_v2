import 'dart:typed_data';

/// Stub implementation for non-web platforms.
class ExcelWebParser {
  static Future<String> extractTextFromExcel(Uint8List bytes) async {
    return '';
  }
}
