import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'excel_web_parser.dart';

/// Tüm platformlarda (Windows, Web, Linux, macOS, Android, iOS)
/// hiçbir harici CDN veya SheetJS zorunluluğu olmadan çalışan evrensel Excel ayrıştırıcı.
///
/// Desteklenen formatlar:
/// 1. Gerçek `.xlsx` (OpenXML ZIP arşivi) — Pure Dart / Archive ile doğrudan çözülür.
/// 2. HTML tablosu formatındaki `.xls` — Kamu/Banka sistemlerinin ürettiği HTML tabloları.
/// 3. CSV / TSV metin formatları — Noktalı virgül, sekme veya virgül ayrımı.
/// 4. Eski ikili BIFF8 `.xls` — Web'de güvenli JS interop ile, masaüstünde fallback ile.
class ExcelUniversalParser {
  /// Excel byte dizisinden metin/tablo satırlarını ayrıştırır.
  /// Çıktı formatı: Her satır "hücre1 | hücre2 | hücre3" şeklinde döner.
  static Future<String> extractText(Uint8List bytes, {String? fileName}) async {
    if (bytes.isEmpty) return '';

    // 1. Dosya imzasını (Magic Number) kontrol et
    final isZipXlsx = _isZipArchive(bytes);
    final isBiff8 = _isBiff8Excel(bytes);

    // 2. Eğer ZIP tabanlı modern XLSX ise pure Dart ile çöz
    if (isZipXlsx) {
      try {
        final text = _parseXlsxWithArchive(bytes);
        if (text.trim().isNotEmpty) {
          debugPrint('[ExcelUniversalParser] .xlsx pure-Dart ile başarıyla okundu.');
          return text;
        }
      } catch (e) {
        debugPrint('[ExcelUniversalParser] .xlsx archive ayrıştırma hatası: $e');
      }
    }

    // 3. Dosya metin (HTML veya CSV) olabilir mi kontrol et
    final asText = _tryDecodeText(bytes);
    if (asText != null && asText.trim().isNotEmpty) {
      // HTML Tablosu mu? (Örn: <table>...<tr>...<td>...)
      if (_isHtmlTable(asText)) {
        try {
          final htmlTableText = _parseHtmlTable(asText);
          if (htmlTableText.trim().isNotEmpty) {
            debugPrint('[ExcelUniversalParser] HTML Tablo formatlı .xls başarıyla okundu.');
            return htmlTableText;
          }
        } catch (e) {
          debugPrint('[ExcelUniversalParser] HTML tablo ayrıştırma hatası: $e');
        }
      }

      // CSV veya TSV formatı mı?
      if (_isCsvOrTsv(asText)) {
        try {
          final csvText = _parseDelimitedText(asText);
          if (csvText.trim().isNotEmpty) {
            debugPrint('[ExcelUniversalParser] CSV/TSV metin başarıyla ayrıştırıldı.');
            return csvText;
          }
        } catch (e) {
          debugPrint('[ExcelUniversalParser] CSV ayrıştırma hatası: $e');
        }
      }
    }

    // 4. Eğer Web ortamındaysak ve dosya BIFF8 .xls ise Web JS interop'u dene
    if (kIsWeb) {
      try {
        final webText = await ExcelWebParser.extractTextFromExcel(bytes);
        if (webText.trim().isNotEmpty) {
          debugPrint('[ExcelUniversalParser] Web SheetJS ile başarıyla okundu.');
          return webText;
        }
      } catch (e) {
        debugPrint('[ExcelUniversalParser] Web SheetJS hatası: $e');
      }
    }

    // 5. İkili BIFF8 dosyasından ham metin çıkarma (Son çare fallback)
    if (isBiff8) {
      final biffFallback = _extractStringsFromBinary(bytes);
      if (biffFallback.trim().isNotEmpty) {
        return biffFallback;
      }
    }

    throw Exception(
      'Excel dosyası okunamadı. Lütfen dosyanın bozuk olmadığından veya '
      'desteklenen formatta (.xlsx, .xls, .csv) olduğundan emin olun.',
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Pure Dart XLSX (OpenXML) Parser
  // ─────────────────────────────────────────────────────────────

  static bool _isZipArchive(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // PK\x03\x04
    return bytes[0] == 0x50 &&
        bytes[1] == 0x4B &&
        bytes[2] == 0x03 &&
        bytes[3] == 0x04;
  }

  static bool _isBiff8Excel(Uint8List bytes) {
    if (bytes.length < 8) return false;
    // D0 CF 11 E0 A1 B1 1A E1 (Compound File Binary Format / OLE)
    return bytes[0] == 0xD0 &&
        bytes[1] == 0xCF &&
        bytes[2] == 0x11 &&
        bytes[3] == 0xE0;
  }

  static String _parseXlsxWithArchive(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: false);

    // 1. Shared Strings tablosunu yükle (xl/sharedStrings.xml)
    final sharedStrings = <String>[];
    final sstFile = archive.findFile('xl/sharedStrings.xml') ??
        archive.findFile('xl/SharedStrings.xml');
    if (sstFile != null) {
      final sstXml = utf8.decode(sstFile.content as List<int>, allowMalformed: true);
      _parseSharedStrings(sstXml, sharedStrings);
    }

    // 2. Çalışma sayfalarını bul (xl/worksheets/sheet*.xml)
    final sheetFiles = archive.files.where((f) {
      final name = f.name.toLowerCase();
      return name.startsWith('xl/worksheets/sheet') && name.endsWith('.xml');
    }).toList();

    if (sheetFiles.isEmpty) return '';

    // Sheet numaralarına göre sırala (sheet1, sheet2...)
    sheetFiles.sort((a, b) => a.name.compareTo(b.name));

    final buffer = StringBuffer();

    for (final sFile in sheetFiles) {
      final sheetName = sFile.name.split('/').last.replaceAll('.xml', '');
      buffer.writeln('--- SHEET: $sheetName ---');

      final sheetXml = utf8.decode(sFile.content as List<int>, allowMalformed: true);
      final rows = _parseWorksheetXml(sheetXml, sharedStrings);

      for (final row in rows) {
        if (row.any((c) => c.trim().isNotEmpty)) {
          buffer.writeln(row.join(' | '));
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  static void _parseSharedStrings(String xml, List<String> list) {
    // Her <si> bloğunu ayıkla
    final siRegex = RegExp(r'<si\b[^>]*>([\s\S]*?)<\/si>', caseSensitive: false);
    final tRegex = RegExp(r'<t\b[^>]*>([\s\S]*?)<\/t>', caseSensitive: false);

    for (final siMatch in siRegex.allMatches(xml)) {
      final siContent = siMatch.group(1) ?? '';
      final tMatches = tRegex.allMatches(siContent);
      if (tMatches.isNotEmpty) {
        final sb = StringBuffer();
        for (final tm in tMatches) {
          sb.write(tm.group(1) ?? '');
        }
        list.add(_decodeXmlEntities(sb.toString()));
      } else {
        list.add('');
      }
    }
  }

  static List<List<String>> _parseWorksheetXml(
    String xml,
    List<String> sharedStrings,
  ) {
    final rowsList = <List<String>>[];

    // <row r="1">...</row>
    final rowRegex = RegExp(r'<row\b[^>]*>([\s\S]*?)<\/row>', caseSensitive: false);
    // <c r="A1" t="s"><v>0</v></c> veya <c r="A1"><is><t>metin</t></is></c>
    final cRegex = RegExp(r'<c\b([^>]*)>([\s\S]*?)<\/c>', caseSensitive: false);
    final rAttrRegex = RegExp(r'\br="([A-Z]+)(\d+)"', caseSensitive: false);
    final tAttrRegex = RegExp(r'\bt="([^"]+)"', caseSensitive: false);
    final vRegex = RegExp(r'<v\b[^>]*>([\s\S]*?)<\/v>', caseSensitive: false);
    final isTRegex = RegExp(r'<is\b[^>]*>[\s\S]*?<t\b[^>]*>([\s\S]*?)<\/t>[\s\S]*?<\/is>', caseSensitive: false);

    for (final rowMatch in rowRegex.allMatches(xml)) {
      final rowContent = rowMatch.group(1) ?? '';
      final cellMap = <int, String>{};
      int maxCol = -1;

      for (final cMatch in cRegex.allMatches(rowContent)) {
        final cAttrs = cMatch.group(1) ?? '';
        final cBody = cMatch.group(2) ?? '';

        // Hücre koordinatı: A1, B1, AA1 vb.
        int colIndex = -1;
        final rMatch = rAttrRegex.firstMatch(cAttrs);
        if (rMatch != null) {
          final colLetters = rMatch.group(1)?.toUpperCase() ?? '';
          colIndex = _colLettersToIndex(colLetters);
        }

        final tMatch = tAttrRegex.firstMatch(cAttrs);
        final cellType = tMatch?.group(1);

        String value = '';
        final vMatch = vRegex.firstMatch(cBody);
        final rawVal = vMatch?.group(1)?.trim();

        if (cellType == 's' && rawVal != null) {
          // Shared string indeksi
          final sIdx = int.tryParse(rawVal);
          if (sIdx != null && sIdx >= 0 && sIdx < sharedStrings.length) {
            value = sharedStrings[sIdx];
          }
        } else if (cellType == 'inlineStr') {
          final isMatch = isTRegex.firstMatch(cBody);
          value = _decodeXmlEntities(isMatch?.group(1) ?? '');
        } else if (rawVal != null) {
          value = _decodeXmlEntities(rawVal);
        }

        // Temizle
        value = value.replaceAll('\n', ' ').replaceAll('\r', ' ').trim();

        if (colIndex >= 0) {
          cellMap[colIndex] = value;
          if (colIndex > maxCol) maxCol = colIndex;
        } else {
          // Kolon belirtilmemişse sırayla ekle
          maxCol++;
          cellMap[maxCol] = value;
        }
      }

      if (maxCol >= 0) {
        final row = List<String>.generate(
          maxCol + 1,
          (i) => cellMap[i] ?? '',
        );
        rowsList.add(row);
      }
    }

    return rowsList;
  }

  static int _colLettersToIndex(String letters) {
    int result = 0;
    for (int i = 0; i < letters.length; i++) {
      result = result * 26 + (letters.codeUnitAt(i) - 64);
    }
    return result - 1; // 0 tabanlı
  }

  static String _decodeXmlEntities(String s) {
    return s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
  }

  // ─────────────────────────────────────────────────────────────
  // 2. HTML Tablo (.xls) Parser
  // ─────────────────────────────────────────────────────────────

  static String? _tryDecodeText(Uint8List bytes) {
    try {
      // Önce UTF-8 dene
      return utf8.decode(bytes);
    } catch (_) {
      try {
        // Windows-1254 / ISO-8859-9 (Türkçe) fallback
        return latin1.decode(bytes);
      } catch (_) {
        return null;
      }
    }
  }

  static bool _isHtmlTable(String text) {
    final lower = text.toLowerCase();
    return lower.contains('<table') && lower.contains('<tr');
  }

  static String _parseHtmlTable(String html) {
    final buffer = StringBuffer();
    buffer.writeln('--- SHEET: Tablo 1 ---');

    final trRegex = RegExp(r'<tr\b[^>]*>([\s\S]*?)<\/tr>', caseSensitive: false);
    final tdRegex = RegExp(r'<(td|th)\b[^>]*>([\s\S]*?)<\/\1>', caseSensitive: false);

    for (final tr in trRegex.allMatches(html)) {
      final rowContent = tr.group(1) ?? '';
      final cells = <String>[];

      for (final cellMatch in tdRegex.allMatches(rowContent)) {
        var val = cellMatch.group(2) ?? '';
        // HTML etiketlerini temizle
        val = val.replaceAll(RegExp(r'<[^>]*>'), '');
        // HTML özel karakterlerini çevir
        val = val
            .replaceAll('&nbsp;', ' ')
            .replaceAll('&amp;', '&')
            .replaceAll('&lt;', '<')
            .replaceAll('&gt;', '>')
            .replaceAll('&quot;', '"')
            .replaceAll('\n', ' ')
            .replaceAll('\r', ' ')
            .trim();
        cells.add(val);
      }

      if (cells.any((c) => c.isNotEmpty)) {
        buffer.writeln(cells.join(' | '));
      }
    }

    return buffer.toString();
  }

  // ─────────────────────────────────────────────────────────────
  // 3. CSV / TSV Parser
  // ─────────────────────────────────────────────────────────────

  static bool _isCsvOrTsv(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).take(5).toList();
    if (lines.isEmpty) return false;

    // Yaygın ayrıştırıcıları kontrol et: ;, \t, ,
    int semiCount = 0;
    int tabCount = 0;
    int commaCount = 0;

    for (final l in lines) {
      semiCount += l.split(';').length - 1;
      tabCount += l.split('\t').length - 1;
      commaCount += l.split(',').length - 1;
    }

    return semiCount >= 2 || tabCount >= 2 || commaCount >= 2;
  }

  static String _parseDelimitedText(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    if (lines.isEmpty) return '';

    // İlk satırlara bakarak ayrıştırıcı seç
    final sample = lines.take(5).join('\n');
    final semi = sample.split(';').length;
    final tab = sample.split('\t').length;
    final comma = sample.split(',').length;

    String sep = ';';
    if (tab > semi && tab > comma) {
      sep = '\t';
    } else if (comma > semi && comma > tab) {
      sep = ',';
    }

    final buffer = StringBuffer();
    buffer.writeln('--- SHEET: Liste ---');

    for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final parts = line.split(sep).map((p) => p.trim().replaceAll('"', '')).toList();
      if (parts.any((p) => p.isNotEmpty)) {
        buffer.writeln(parts.join(' | '));
      }
    }

    return buffer.toString();
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Binary BIFF8 Fallback
  // ─────────────────────────────────────────────────────────────

  static String _extractStringsFromBinary(Uint8List bytes) {
    final buffer = StringBuffer();
    buffer.writeln('--- SHEET: İkili Tablo ---');

    // Basit bir ASCII/UTF-8 string tarayıcı
    final currentStr = <int>[];
    final foundStrings = <String>[];

    for (int i = 0; i < bytes.length; i++) {
      final b = bytes[i];
      if ((b >= 32 && b <= 126) || b == 10 || b == 13 || b >= 160) {
        currentStr.add(b);
      } else {
        if (currentStr.length >= 3) {
          try {
            final s = utf8.decode(currentStr, allowMalformed: true).trim();
            if (s.length >= 3 && !s.startsWith('<?xml') && !s.startsWith('<html')) {
              foundStrings.add(s);
            }
          } catch (_) {}
        }
        currentStr.clear();
      }
    }

    if (foundStrings.isNotEmpty) {
      buffer.writeln(foundStrings.join(' | '));
    }

    return buffer.toString();
  }
}
