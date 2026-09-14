import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/fatura/services/excel_universal_parser.dart';
import 'package:dsys_v2/features/birim/models/birim_model.dart';
import 'package:archive/archive.dart';

void main() {
  group('ExcelUniversalParser Testleri', () {
    test('1. HTML Tablo formatlı .xls içeriğini doğru ayrıştırmalı', () async {
      const htmlContent = '''
<html>
<body>
  <table>
    <tr>
      <th>Ad Soyad</th>
      <th>TC Kimlik</th>
      <th>Tutar</th>
    </tr>
    <tr>
      <td>Ahmet Yılmaz</td>
      <td>12345678901</td>
      <td>1.500,00</td>
    </tr>
    <tr>
      <td>Mehmet Demir</td>
      <td>98765432109</td>
      <td>2.750,50</td>
    </tr>
  </table>
</body>
</html>
''';
      final bytes = Uint8List.fromList(utf8.encode(htmlContent));
      final result = await ExcelUniversalParser.extractText(bytes, fileName: 'fatura.xls');

      expect(result.contains('Ad Soyad | TC Kimlik | Tutar'), true);
      expect(result.contains('Ahmet Yılmaz | 12345678901 | 1.500,00'), true);
      expect(result.contains('Mehmet Demir | 98765432109 | 2.750,50'), true);
    });

    test('2. Noktalı virgüllü CSV/TSV formatını doğru ayrıştırmalı', () async {
      const csvContent = '''
Cari Ünvan;Vergi No;Net Tutar;KDV
ABC Ltd Şti;1234567890;5000,00;1000,00
XYZ A.Ş.;9876543210;12000,00;2400,00
''';
      final bytes = Uint8List.fromList(utf8.encode(csvContent));
      final result = await ExcelUniversalParser.extractText(bytes, fileName: 'liste.csv');

      expect(result.contains('Cari Ünvan | Vergi No | Net Tutar | KDV'), true);
      expect(result.contains('ABC Ltd Şti | 1234567890 | 5000,00 | 1000,00'), true);
    });

    test('3. Yapay ZIP tabanlı XLSX arşivi ayrıştırma', () async {
      final archive = Archive();

      // Shared strings
      const sstXml = '''<?xml version="1.0" encoding="UTF-8"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="3" uniqueCount="3">
  <si><t>TÖMER Kursiyer</t></si>
  <si><t>11111111111</t></si>
  <si><t>Türkçe A1 Kursu</t></si>
</sst>''';
      archive.addFile(ArchiveFile('xl/sharedStrings.xml', sstXml.length, utf8.encode(sstXml)));

      // Worksheet
      const sheetXml = '''<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    <row r="1">
      <c r="A1" t="s"><v>0</v></c>
      <c r="B1" t="s"><v>1</v></c>
      <c r="C1"><v>3500.00</v></c>
    </row>
  </sheetData>
</worksheet>''';
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
      final result = await ExcelUniversalParser.extractText(zipBytes, fileName: 'test.xlsx');

      expect(result.contains('TÖMER Kursiyer | 11111111111 | 3500.00'), true);
    });
  });

  group('Varsayılan Birimler ve TÖMER / ADUM Testleri', () {
    test('Varsayılan birimler listesinde TÖMER ve ADUM resmi IBAN ile mevcut olmalı', () {
      final tomer = BirimModel.varsayilanBirimler.firstWhere((b) => b.kisaAd == 'TÖMER');
      expect(tomer.iban, 'TR040001001758672359525003');
      expect(tomer.vkn, '8960466329');
      expect(tomer.hesapAdi, 'Kurum Tek İdare Tahsilat Alt Hesabı /Türkçe Öğrenimi DSİ');

      final adum = BirimModel.varsayilanBirimler.firstWhere((b) => b.kisaAd == 'ADUM');
      expect(adum.iban, 'TR880001001758890982805002');
      expect(adum.vkn, '8960475707');
    });
  });
}
