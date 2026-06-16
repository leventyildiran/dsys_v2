/// Word OOXML (document.xml) ayrıştırma — tablolar ve renkler birebir korunur.
import '../models/yk_karar_model.dart';
import 'yk_tablo_kolon_haritasi.dart';

class DocxOoxmlUtil {
  static int findTagOpen(String xml, String tag, [int fromIndex = 0]) {
    final prefix = '<$tag';
    var idx = fromIndex;
    while (idx < xml.length) {
      idx = xml.indexOf(prefix, idx);
      if (idx == -1) return -1;
      if (idx + prefix.length >= xml.length) return -1;
      final next = xml[idx + prefix.length];
      if (next == '>' || next == ' ' || next == '/') return idx;
      idx += prefix.length;
    }
    return -1;
  }

  static ({String xml, int end})? extractElement(String xml, String tag, [int fromIndex = 0]) {
    final openTag = '<$tag';
    final closeTag = '</$tag>';
    final start = findTagOpen(xml, tag, fromIndex);
    if (start == -1) return null;

    var depth = 0;
    var pos = start;
    while (pos < xml.length) {
      final nextOpen = findTagOpen(xml, tag, pos);
      final nextClose = xml.indexOf(closeTag, pos);
      if (nextClose == -1) return null;
      if (nextOpen != -1 && nextOpen < nextClose) {
        depth++;
        pos = nextOpen + openTag.length;
      } else {
        depth--;
        pos = nextClose + closeTag.length;
        if (depth == 0) {
          return (xml: xml.substring(start, pos), end: pos);
        }
      }
    }
    return null;
  }

  static List<DocxBodyBlock> extractBodyBlocks(String bodyInner) {
    final blocks = <DocxBodyBlock>[];
    var i = 0;
    while (i < bodyInner.length) {
      while (i < bodyInner.length && bodyInner[i] != '<') {
        i++;
      }
      if (i >= bodyInner.length) break;
      if (bodyInner.substring(i).startsWith('<w:sectPr')) break;

      String? tag;
      if (RegExp(r'^<w:p[ >/]').hasMatch(bodyInner.substring(i))) {
        tag = 'w:p';
      } else if (RegExp(r'^<w:tbl[ >/]').hasMatch(bodyInner.substring(i))) {
        tag = 'w:tbl';
      } else {
        i++;
        continue;
      }

      final el = extractElement(bodyInner, tag, i);
      if (el == null) break;
      blocks.add(DocxBodyBlock(type: tag, xml: el.xml));
      i = el.end;
    }
    return blocks;
  }

  static String? extractBodyInner(String documentXml) {
    final match = RegExp(r'<w:body>([\s\S]*)</w:body>').firstMatch(documentXml);
    return match?.group(1);
  }

  static String extractSectPr(String documentXml) {
    final match = RegExp(r'<w:sectPr\b[^>]*>[\s\S]*?</w:sectPr>').firstMatch(documentXml);
    return match?.group(0) ?? '';
  }

  static String extractDocumentOpen(String documentXml) {
    final match = RegExp(r'<w:document\b[^>]*>').firstMatch(documentXml);
    return match?.group(0) ??
        '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">';
  }

  static String paraText(String pXml) {
    return pXml
        .replaceAll(RegExp(r'<w:tab\s*/>'), '\t')
        .replaceAll(RegExp(r'<w:br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String blocksToPlainText(List<DocxBodyBlock> blocks) {
    return blocks
        .where((b) => b.type == 'w:p')
        .map((b) => paraText(b.xml))
        .where((t) => t.isNotEmpty)
        .join('\n');
  }

  /// Karar metni + veri tabloları (imza tablosu hariç) — editör ve önizleme için.
  static String blocksToDisplayText(List<DocxBodyBlock> blocks) {
    final parts = <String>[];
    for (final block in blocks) {
      if (block.type == 'w:p') {
        final t = paraText(block.xml);
        if (t.isNotEmpty) parts.add(t);
      } else if (block.type == 'w:tbl' && !isSignatureTable(block)) {
        final tbl = tableToPlainText(block.xml);
        if (tbl.isNotEmpty) parts.add(tbl);
      }
    }
    return parts.join('\n\n');
  }

  static String bodyXmlToDisplayText(String bodyXml) {
    final blocks = extractBodyBlocks(bodyXml);
    if (blocks.isEmpty) return paraText(bodyXml);
    return blocksToDisplayText(blocks);
  }

  /// OOXML gövdeden imza dışı tabloları satır/hücre listesi olarak çıkarır.
  static List<List<String>> extractDataTablesFromBodyXml(String bodyXml) {
    final blocks = extractBodyBlocks(bodyXml);
    final tables = <List<String>>[];
    for (final block in blocks) {
      if (block.type == 'w:tbl' && !isSignatureTable(block)) {
        tables.addAll(tableToRowLists(block.xml));
      }
    }
    return tables;
  }

  static List<List<String>> tableToRowLists(String tblXml) {
    final rows = _extractElements(tblXml, 'w:tr');
    return rows
        .map((r) => _rowCellTexts(r.xml))
        .where((cells) => cells.any((c) => c.trim().isNotEmpty))
        .toList();
  }

  static String tableToPlainText(String tblXml) {
    final rows = tableToRowLists(tblXml);
    if (rows.isEmpty) return '';
    return rows.map((cells) => cells.join('\t')).join('\n');
  }

  static bool isSignatureTable(DocxBodyBlock block) {
    if (block.type != 'w:tbl') return false;
    final t = paraText(block.xml).toLowerCase();
    return t.contains('sıra no') && t.contains('görevi') && t.contains('imzası');
  }

  /// KARAR 20XX/NN ile başlayan bölümleri ayırır.
  static List<DocxSection> splitKararSections(List<DocxBodyBlock> blocks) {
    final starts = <int>[];
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].type == 'w:p' &&
          RegExp(r'^KARAR\s+20\d{2}/\d+', caseSensitive: false).hasMatch(paraText(blocks[i].xml))) {
        starts.add(i);
      }
    }
    if (starts.isEmpty) return [];

    final sections = <DocxSection>[];
    for (var s = 0; s < starts.length; s++) {
      final start = starts[s];
      var end = s + 1 < starts.length ? starts[s + 1] : blocks.length;
      // İmza tablosundan önce kes
      for (var j = start; j < end; j++) {
        if (isSignatureTable(blocks[j])) {
          end = j;
          break;
        }
      }
      final sectionBlocks = blocks.sublist(start, end);
      final title = paraText(sectionBlocks.first.xml);
      sections.add(DocxSection(
        baslik: title,
        blocks: sectionBlocks,
        plainText: blocksToPlainText(sectionBlocks),
      ));
    }
    return sections;
  }

  /// Gündem 01: ... ile başlayan bölümleri ayırır.
  static List<DocxSection> splitGundemSections(List<DocxBodyBlock> blocks) {
    final starts = <int>[];
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i].type == 'w:p' &&
          RegExp(r'^G[üu]ndem\s+\d+', caseSensitive: false).hasMatch(paraText(blocks[i].xml))) {
        starts.add(i);
      }
    }
    if (starts.isEmpty) return [];

    final sections = <DocxSection>[];
    for (var s = 0; s < starts.length; s++) {
      final start = starts[s];
      final end = s + 1 < starts.length ? starts[s + 1] : blocks.length;
      final sectionBlocks = blocks.sublist(start, end);
      final title = paraText(sectionBlocks.first.xml);
      sections.add(DocxSection(
        baslik: title,
        blocks: sectionBlocks,
        plainText: blocksToPlainText(sectionBlocks),
      ));
    }
    return sections;
  }

  static String sectionToBodyXml(DocxSection section) {
    return section.blocks.map((b) => b.xml).join('\n');
  }

  static String pageBreakXml() =>
      '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';

  /// w:t düğümlerindeki metinleri sırayla değiştirir — tablo yapısına dokunmaz.
  static String replaceTextNodes(String xml, List<String Function(String old)> replacers) {
    var result = xml;
    for (final replacer in replacers) {
      result = result.replaceAllMapped(
        RegExp(r'<w:t(?:\s+xml:space="preserve")?>([\s\S]*?)</w:t>'),
        (m) {
          final old = m.group(1) ?? '';
          final neu = replacer(old);
          if (neu == old) return m.group(0)!;
          final preserve = neu.contains(' ') ? ' xml:space="preserve"' : '';
          return '<w:t$preserve>${_xmlEscape(neu)}</w:t>';
        },
      );
    }
    return result;
  }

  /// Paragraf metinlerini + tablo hücrelerini PDF verisiyle uyarlar.
  /// Tablo YAPISINA (satır/sütun/renk) dokunmaz — yalnızca hücre metni güncellenir.
  static String adaptSectionFromPdf(
    String bodyXml,
    String pdfText,
    List<Map<String, dynamic>> tabloVerileri, {
    YkKararTuru tur = YkKararTuru.diger,
  }) {
    return adaptSectionFromPdfWithReport(
      bodyXml,
      pdfText,
      tabloVerileri,
      tur: tur,
    ).bodyXml;
  }

  static TabloDoldurmaSonucu adaptSectionFromPdfWithReport(
    String bodyXml,
    String pdfText,
    List<Map<String, dynamic>> tabloVerileri, {
    YkKararTuru tur = YkKararTuru.diger,
  }) {
    var xml = adaptSectionDatesAndRefs(bodyXml, pdfText);
    final tabloSonuc = fillTablesFromPdfDataWithReport(xml, tabloVerileri, tur: tur);
    return TabloDoldurmaSonucu(
      bodyXml: tabloSonuc.bodyXml,
      doldurulanHucre: tabloSonuc.doldurulanHucre,
      atlananHucre: tabloSonuc.atlananHucre,
      eslesmeyenSatir: tabloSonuc.eslesmeyenSatir,
      uyarilar: tabloSonuc.uyarilar,
    );
  }

  /// Editördeki düz metni yalnızca w:p paragraflarına yazar; tablolara dokunmaz.
  static String mergeParagraphsIntoBodyXml(String bodyXml, String editorPlainText) {
    final cleaned = editorPlainText
        .replaceAll('[Tablolar Word şablonundan birebir korunuyor]', '')
        .trim();
    final lines = cleaned.split('\n').map((l) => l.trimRight()).toList();

    final blocks = extractBodyBlocks(bodyXml);
    final out = StringBuffer();
    var lineIdx = 0;

    for (final block in blocks) {
      if (block.type == 'w:tbl') {
        out.write(block.xml);
        continue;
      }

      final oldText = paraText(block.xml);
      if (oldText.isEmpty) {
        out.write(block.xml);
        continue;
      }

      if (lineIdx < lines.length) {
        final line = lines[lineIdx].trim();
        lineIdx++;
        out.write(line.isEmpty ? block.xml : _setParagraphText(block.xml, line));
      } else {
        out.write(block.xml);
      }
    }

    return out.toString();
  }

  static String adaptSectionDatesAndRefs(String bodyXml, String pdfText) {
    final eskiTarihler = _findAll(r'\d{2}[./]\d{2}[./]\d{4}', bodyXml);
    final yeniTarihler = _findAll(r'\d{2}[./]\d{2}[./]\d{4}', pdfText);
    final eskiEvrak = _findAll(r'E-?\d[\d-]*', bodyXml, caseSensitive: false);
    final yeniEvrak = _findAll(r'E-?\d[\d-]*', pdfText, caseSensitive: false);

    var idxT = 0;
    var idxE = 0;
    return replaceTextNodes(bodyXml, [
      (old) {
        if (RegExp(r'^\d{2}[./]\d{2}[./]\d{4}$').hasMatch(old) &&
            idxT < eskiTarihler.length &&
            old == eskiTarihler[idxT] &&
            idxT < yeniTarihler.length) {
          return yeniTarihler[idxT++];
        }
        if (RegExp(r'^E-?\d', caseSensitive: false).hasMatch(old) &&
            idxE < eskiEvrak.length &&
            old.toUpperCase() == eskiEvrak[idxE].toUpperCase() &&
            idxE < yeniEvrak.length) {
          return yeniEvrak[idxE++];
        }
        return old;
      },
    ]);
  }

  /// Şablondaki w:tbl bloklarının hücre metinlerini PDF tablo verisiyle doldurur.
  /// Satır/sütun eklemez veya silmez — renk ve kenarlıklar korunur.
  static String fillTablesFromPdfData(
    String bodyXml,
    List<Map<String, dynamic>> tabloVerileri, {
    YkKararTuru tur = YkKararTuru.diger,
  }) {
    return fillTablesFromPdfDataWithReport(bodyXml, tabloVerileri, tur: tur).bodyXml;
  }

  static TabloDoldurmaSonucu fillTablesFromPdfDataWithReport(
    String bodyXml,
    List<Map<String, dynamic>> tabloVerileri, {
    YkKararTuru tur = YkKararTuru.diger,
  }) {
    if (tabloVerileri.isEmpty) {
      return TabloDoldurmaSonucu(
        bodyXml: bodyXml,
        doldurulanHucre: 0,
        atlananHucre: 0,
        eslesmeyenSatir: 0,
      );
    }

    final buffer = StringBuffer();
    var searchFrom = 0;
    var doldurulan = 0;
    var atlanan = 0;
    var eslesmeyenSatir = 0;
    final uyarilar = <String>[];

    while (searchFrom < bodyXml.length) {
      final tblStart = findTagOpen(bodyXml, 'w:tbl', searchFrom);
      if (tblStart == -1) {
        buffer.write(bodyXml.substring(searchFrom));
        break;
      }

      buffer.write(bodyXml.substring(searchFrom, tblStart));
      final tbl = extractElement(bodyXml, 'w:tbl', tblStart);
      if (tbl == null) {
        buffer.write(bodyXml.substring(tblStart));
        break;
      }

      final tblText = paraText(tbl.xml).toLowerCase();
      if (tblText.contains('sıra no') && tblText.contains('imzası')) {
        buffer.write(tbl.xml);
      } else {
        final sonuc = _fillSingleTableWithReport(tbl.xml, tabloVerileri, tur: tur);
        buffer.write(sonuc.bodyXml);
        doldurulan += sonuc.doldurulanHucre;
        atlanan += sonuc.atlananHucre;
        eslesmeyenSatir += sonuc.eslesmeyenSatir;
        uyarilar.addAll(sonuc.uyarilar);
      }
      searchFrom = tbl.end;
    }

    return TabloDoldurmaSonucu(
      bodyXml: buffer.toString(),
      doldurulanHucre: doldurulan,
      atlananHucre: atlanan,
      eslesmeyenSatir: eslesmeyenSatir,
      uyarilar: uyarilar,
    );
  }

  static TabloDoldurmaSonucu _fillSingleTableWithReport(
    String tblXml,
    List<Map<String, dynamic>> tabloVerileri, {
    required YkKararTuru tur,
  }) {
    final rows = _extractElements(tblXml, 'w:tr');
    if (rows.isEmpty || tabloVerileri.isEmpty) {
      return TabloDoldurmaSonucu(
        bodyXml: tblXml,
        doldurulanHucre: 0,
        atlananHucre: 0,
        eslesmeyenSatir: 0,
      );
    }

    var headerRowCount = 1;
    if (rows.length > 1 && _rowHasShd(rows[0].xml) && _rowHasShd(rows[1].xml)) {
      headerRowCount = 2;
    }

    final headerCells = _rowCellTexts(rows.first.xml);
    final pdfKeys = tabloVerileri.first.keys.toList();
    final columnMap = _buildColumnMap(headerCells, pdfKeys, tur);

    var result = tblXml;
    var dataIdx = 0;
    var doldurulan = 0;
    var atlanan = 0;
    final uyarilar = <String>[];

    for (var c = 0; c < columnMap.length; c++) {
      if (columnMap[c] == null && headerCells[c].trim().isNotEmpty) {
        uyarilar.add('Kolon eşleşmedi: "${headerCells[c]}"');
      }
    }

    for (var r = headerRowCount; r < rows.length; r++) {
      if (dataIdx >= tabloVerileri.length) {
        atlanan += _extractElements(rows[r].xml, 'w:tc').length;
        continue;
      }

      final rowData = tabloVerileri[dataIdx++];
      final cells = _extractElements(rows[r].xml, 'w:tc');
      var newRowXml = rows[r].xml;

      for (var c = 0; c < cells.length; c++) {
        String? value;
        if (c < columnMap.length && columnMap[c] != null) {
          value = rowData[columnMap[c]!]?.toString() ?? '';
        } else {
          atlanan++;
          continue;
        }

        if (value.trim().isEmpty) {
          atlanan++;
          continue;
        }

        final newCell = _setCellText(cells[c].xml, value);
        newRowXml = newRowXml.replaceFirst(cells[c].xml, newCell);
        doldurulan++;
      }

      result = result.replaceFirst(rows[r].xml, newRowXml);
    }

    final veriSatirlari = rows.length - headerRowCount;
    final eslesmeyenSatir = (veriSatirlari - tabloVerileri.length).clamp(0, veriSatirlari);

    return TabloDoldurmaSonucu(
      bodyXml: result,
      doldurulanHucre: doldurulan,
      atlananHucre: atlanan,
      eslesmeyenSatir: eslesmeyenSatir,
      uyarilar: uyarilar,
    );
  }

  static List<({String xml, int end})> _extractElements(String xml, String tag) {
    final elements = <({String xml, int end})>[];
    var from = 0;
    while (from < xml.length) {
      final el = extractElement(xml, tag, from);
      if (el == null) break;
      elements.add(el);
      from = el.end;
    }
    return elements;
  }

  static bool _rowHasShd(String trXml) => trXml.contains('w:shd');

  static List<String> _rowCellTexts(String trXml) {
    return _extractElements(trXml, 'w:tc').map((c) => paraText(c.xml)).toList();
  }

  static List<String?> _buildColumnMap(
    List<String> headers,
    List<String> pdfAnahtarlari,
    YkKararTuru tur,
  ) {
    return List.generate(headers.length, (i) {
      return YkTabloKolonHaritasi.kolonAnahtariBul(
        tur: tur,
        sablonBaslik: headers[i],
        pdfAnahtarlari: pdfAnahtarlari,
        kolonIndex: i,
      );
    });
  }

  static String _setParagraphText(String pXml, String newText) {
    final escaped = _xmlEscape(newText);
    final preserve = newText.contains(' ') ? ' xml:space="preserve"' : '';

    if (RegExp(r'<w:t[ >]').hasMatch(pXml)) {
      var first = true;
      return pXml.replaceAllMapped(
        RegExp(r'<w:t(?:\s+xml:space="preserve")?>([\s\S]*?)</w:t>'),
        (m) {
          if (first) {
            first = false;
            return '<w:t$preserve>$escaped</w:t>';
          }
          return '<w:t></w:t>';
        },
      );
    }

    if (RegExp(r'<w:p[ >]').hasMatch(pXml)) {
      return pXml.replaceFirst(
        RegExp(r'(<w:p\b[^>]*>)'),
        '<w:p><w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/></w:rPr>'
        '<w:t$preserve>$escaped</w:t></w:r></w:p>',
      );
    }
    return pXml;
  }

  static String _setCellText(String tcXml, String newText) {
    final escaped = _xmlEscape(newText);
    final preserve = newText.contains(' ') ? ' xml:space="preserve"' : '';

    if (RegExp(r'<w:t[ >]').hasMatch(tcXml)) {
      // İlk w:t'yi güncelle, diğerlerini temizle (yapı korunur)
      var result = tcXml;
      var first = true;
      result = result.replaceAllMapped(
        RegExp(r'<w:t(?:\s+xml:space="preserve")?>([\s\S]*?)</w:t>'),
        (m) {
          if (first) {
            first = false;
            return '<w:t$preserve>$escaped</w:t>';
          }
          return '<w:t></w:t>';
        },
      );
      return result;
    }

    // Boş hücreye metin ekle
    if (RegExp(r'<w:p[ >]').hasMatch(tcXml)) {
      return tcXml.replaceFirst(
        RegExp(r'(<w:p\b[^>]*>\s*<w:pPr>[\s\S]*?</w:pPr>)?'),
        '<w:p><w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/></w:rPr>'
        '<w:t$preserve>$escaped</w:t></w:r></w:p>',
      );
    }
    return tcXml;
  }

  static List<String> _findAll(String pattern, String text, {bool caseSensitive = true}) {
    return RegExp(pattern, caseSensitive: caseSensitive)
        .allMatches(text)
        .map((m) => m.group(0)!)
        .toList();
  }

  static String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;');
  }
}

class DocxBodyBlock {
  const DocxBodyBlock({required this.type, required this.xml});
  final String type;
  final String xml;
}

class DocxSection {
  const DocxSection({
    required this.baslik,
    required this.blocks,
    required this.plainText,
  });

  final String baslik;
  final List<DocxBodyBlock> blocks;
  final String plainText;

  String get bodyXml => DocxOoxmlUtil.sectionToBodyXml(this);
  int get tableCount => blocks.where((b) => b.type == 'w:tbl').length;
}
