import 'dart:io';

String _xmlEscape(String text) {
  return text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

bool _isHeadingLine(String line) {
  final upper = line.toUpperCase();
  return upper.startsWith('KARAR NO') || 
         upper.startsWith('### KARAR NO') ||
         upper.startsWith('GÜNDEM MADDESİ') || 
         upper.startsWith('### GÜNDEM MADDESİ') ||
         upper.startsWith('TOPLANTI TUTANAĞI') ||
         upper.startsWith('YÜRÜTME KURULU KARARLARI');
}

bool _isNonIndentedLine(String line) {
  final upper = line.toUpperCase();
  if (upper.startsWith('KATILANLARIN OY BİRLİĞİ İLE KARAR VERİLDİ') ||
      upper.startsWith('OY BİRLİĞİ İLE KARAR VERİLDİ') ||
      upper.startsWith('GEREĞİNİN YAPILMASINI ARZ EDERİM') ||
      upper.startsWith('PROF. DR.') ||
      upper.startsWith('DOÇ. DR.') ||
      upper.startsWith('DR. ÖĞR. ÜYESİ') ||
      upper.contains('─')) return true;
  return false;
}

String _buildDocxTableXml(List<List<String>> tableData) {
  final buffer = StringBuffer();
  buffer.writeln('<w:tbl>');
  
  // Tablo özellikleri
  buffer.writeln('''
    <w:tblPr>
      <w:tblStyle w:val="TableGrid"/>
      <w:tblW w:w="5000" w:type="pct"/>
      <w:tblBorders>
        <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
        <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
      </w:tblBorders>
      <w:tblCellMar>
        <w:top w:w="120" w:type="dxa"/>
        <w:left w:w="150" w:type="dxa"/>
        <w:bottom w:w="120" w:type="dxa"/>
        <w:right w:w="150" w:type="dxa"/>
      </w:tblCellMar>
      <w:jc w:val="center"/>
    </w:tblPr>
  ''');
  
  if (tableData.isNotEmpty) {
    final colCount = tableData.first.length;
    buffer.writeln('<w:tblGrid>');
    for (int i = 0; i < colCount; i++) {
      buffer.writeln('<w:gridCol/>');
    }
    buffer.writeln('</w:tblGrid>');
  }
  
  for (int rowIndex = 0; rowIndex < tableData.length; rowIndex++) {
    final row = tableData[rowIndex];
    final isHeader = rowIndex == 0;
    buffer.writeln('<w:tr>');
    
    for (final cell in row) {
      final escaped = _xmlEscape(cell);
      buffer.writeln('<w:tc>');
      
      buffer.writeln('<w:tcPr>');
      buffer.writeln('<w:tcW w:w="0" w:type="auto"/>');
      if (isHeader) {
        buffer.writeln('<w:shd w:val="clear" w:color="auto" w:fill="B8CCE4" w:themeFill="accent1" w:themeFillTint="66"/>');
      }
      buffer.writeln('</w:tcPr>');
      
      buffer.writeln('<w:p>');
      buffer.writeln('<w:pPr>');
      buffer.writeln('<w:spacing w:before="60" w:after="60" w:line="240" w:lineRule="auto"/>');
      if (isHeader || RegExp(r'^\\d+(\\.\\d+)?\\s*([%₺]|TL)?\$').hasMatch(cell.trim())) {
        buffer.writeln('<w:jc w:val="center"/>');
      } else {
        buffer.writeln('<w:jc w:val="left"/>');
      }
      buffer.writeln('</w:pPr>');
      
      buffer.writeln('<w:r>');
      buffer.writeln('<w:rPr>');
      buffer.writeln('<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>');
      buffer.writeln('<w:sz w:val="22"/>'); 
      buffer.writeln('<w:szCs w:val="22"/>');
      if (isHeader) {
        buffer.writeln('<w:b/>'); 
      }
      buffer.writeln('</w:rPr>');
      buffer.writeln('<w:t xml:space="preserve">$escaped</w:t>');
      buffer.writeln('</w:r>');
      buffer.writeln('</w:p>');
      
      buffer.writeln('</w:tc>');
    }
    buffer.writeln('</w:tr>');
  }
  
  buffer.writeln('</w:tbl>');
  return buffer.toString();
}

String buildDocumentBodyXml(String content) {
  final lines = content.split('\n');
  final bodyContent = StringBuffer();
  
  List<List<String>>? currentTable;
  
  for (final line in lines) {
    final trimmed = line.trim();
    
    if (trimmed.startsWith('|') && trimmed.endsWith('|') && trimmed.length > 2) {
      if (trimmed.contains(RegExp(r'^\\|[\\s:-|]+\\$'))) {
        continue;
      }
      final cells = trimmed.split('|').map((c) => c.trim()).toList();
      if (cells.first.isEmpty) cells.removeAt(0);
      if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
      
      currentTable ??= [];
      currentTable.add(cells);
    } else {
      if (currentTable != null) {
        bodyContent.writeln(_buildDocxTableXml(currentTable));
        currentTable = null;
      }
      
      if (trimmed.isNotEmpty) {
        final escaped = _xmlEscape(trimmed);
        final isHeading = _isHeadingLine(trimmed);
        
        if (isHeading) {
          bodyContent.writeln('''
  <w:p>
    <w:pPr>
      <w:spacing w:before="240" w:after="120" w:line="360" w:lineRule="auto"/>
      <w:jc w:val="center"/>
    </w:pPr>
    <w:r>
      <w:rPr>
        <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>
        <w:b/>
        <w:sz w:val="24"/>
        <w:szCs w:val="24"/>
      </w:rPr>
      <w:t xml:space="preserve">$escaped</w:t>
    </w:r>
  </w:p>''');
        } else {
          final deservesIndent = !_isNonIndentedLine(trimmed);
          final indentXml = deservesIndent 
              ? '<w:ind w:leftChars="0" w:left="0" w:firstLineChars="0" w:firstLine="720"/>' 
              : '';
              
          bodyContent.writeln('''
  <w:p>
    <w:pPr>
      <w:spacing w:line="360" w:lineRule="auto"/>
      $indentXml
      <w:jc w:val="both"/>
    </w:pPr>
    <w:r>
      <w:rPr>
        <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>
        <w:sz w:val="24"/>
        <w:szCs w:val="24"/>
      </w:rPr>
      <w:t xml:space="preserve">$escaped</w:t>
    </w:r>
  </w:p>''');
        }
      }
    }
  }
  
  if (currentTable != null) {
    bodyContent.writeln(_buildDocxTableXml(currentTable));
  }
  
  return bodyContent.toString();
}

void main() {
  final markdownContent = '''
### KARAR NO: 2026/12
Orhan Şaşmaz Tekstil firmasının talep ettiği "Danışmanlık Hizmeti" için görevlendirilen öğretim elemanının katkı oranları.

| Adı Soyadı | Faaliyet Türü | Adet/Saat |
|---|---|---|
| Öğr. Gör. Dr. Neslihan | Tasarım | 20 Adet |
| | | Boş Hücre |

Karar verilmiştir.
''';

  final resultXml = buildDocumentBodyXml(markdownContent);
  File('simulate_output.xml').writeAsStringSync(resultXml);
  print('Simülasyon tamamlandı! simulate_output.xml oluşturuldu.');
}
