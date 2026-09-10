@JS()
import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('XLSX.read')
external JSAny _readXlsx(JSAny data, JSAny options);

@JS('XLSX.utils.sheet_to_csv')
external JSString _sheetToCsv(JSAny worksheet);

@JS('Reflect.get')
external JSAny? _jsGet(JSObject target, JSAny propertyKey);

extension type WorkBook._(JSObject _) implements JSObject {
  @JS('SheetNames')
  external JSArray get sheetNames;
  @JS('Sheets')
  external JSObject get sheets;
}

/// Parses an Excel file using SheetJS (in browser).
/// Returns a CSV-like text representation of sheets.
class ExcelWebParser {
  static Future<String> extractTextFromExcel(Uint8List bytes) async {
    if (!kIsWeb) return '';

    try {
      // Create Uint8Array for JS
      final jsData = bytes.toJS;
      final options = {'type': 'array'}.jsify();

      final jsWorkbook = _readXlsx(jsData, options as JSAny) as WorkBook;

      final sheetNames = jsWorkbook.sheetNames.dartify() as List;
      if (sheetNames.isEmpty) return '';

      final buffer = StringBuffer();
      final sheetsObj = jsWorkbook.sheets;

      for (final sName in sheetNames) {
        final sheetNameStr = sName.toString();
        final sheet = _jsGet(sheetsObj, sheetNameStr.toJS);
        if (sheet == null) continue;

        buffer.writeln('--- SHEET: $sheetNameStr ---');
        final csvJsString = _sheetToCsv(sheet);
        final csvDartString = csvJsString.toDart;
        final lines = csvDartString.split('\n');

        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          final cells = line.split(',').map((c) => c.trim().replaceAll('"', '')).toList();
          if (cells.any((c) => c.isNotEmpty)) {
            buffer.writeln(cells.join(' | '));
          }
        }
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('ExcelWebParser Hatası: $e');
      return '';
    }
  }
}
