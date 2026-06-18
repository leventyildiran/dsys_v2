@JS()
library excel_web_parser;

import 'dart:js_interop';
import 'package:flutter/foundation.dart';

@JS('XLSX.read')
external JSAny _readXlsx(JSAny data, JSAny options);

@JS('XLSX.utils.sheet_to_json')
external JSArray _sheetToJson(JSAny worksheet, JSAny options);

extension type WorkBook._(JSObject _) implements JSObject {
  external JSArray get SheetNames;
  external JSObject get Sheets;
}

/// Parses an Excel file using SheetJS (in browser).
/// Returns a CSV-like text or JSON representation of the first sheet.
class ExcelWebParser {
  static Future<String> extractTextFromExcel(Uint8List bytes) async {
    if (!kIsWeb) {
      throw UnsupportedError('ExcelWebParser sadece Web platformunda çalışır.');
    }

    try {
      // Create Uint8Array for JS
      final jsData = bytes.toJS;
      final options = {'type': 'array'}.jsify();

      final jsWorkbook = _readXlsx(jsData, options as JSAny) as WorkBook;

      final sheetNames = jsWorkbook.SheetNames.dartify() as List;
      if (sheetNames.isEmpty) return '';

      final sheetsMap = jsWorkbook.Sheets.dartify() as Map?;
      if (sheetsMap == null) return '';

      final buffer = StringBuffer();
      final jsonOptions = {'header': 1}.jsify();

      for (final sName in sheetNames) {
        final sheetName = sName.toString();
        final sheet = sheetsMap[sheetName];
        if (sheet == null) continue;

        final rowArray = _sheetToJson(sheet as JSAny, jsonOptions as JSAny);
        final rowsList = rowArray.dartify() as List?;
        if (rowsList == null) continue;

        buffer.writeln('--- SHEET: $sheetName ---');

        for (final row in rowsList) {
          if (row == null) continue;
          final cellList = row as List;
          final rowValues = <String>[];
          for (final cell in cellList) {
            rowValues.add(cell?.toString() ?? '');
          }
          if (rowValues.any((element) => element.trim().isNotEmpty)) {
            buffer.writeln(rowValues.join(' | '));
          }
        }
        buffer.writeln();
      }

      return buffer.toString();
    } catch (e) {
      debugPrint('ExcelWebParser Hatası: $e');
      throw Exception(
        'Excel okuma hatası. Lütfen SheetJS yüklü olduğundan emin olun.',
      );
    }
  }
}
