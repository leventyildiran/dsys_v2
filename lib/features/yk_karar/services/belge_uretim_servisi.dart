import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:archive/archive.dart';
import '../models/yk_karar_model.dart';
import '../../danismanlik/models/danismanlik_model.dart';
import '../../../core/turkce_format.dart';
import '../../../core/models/sistem_ayarlari_model.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../models/gundem_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// Word (DOCX) ve PDF belgeleri üretmek için servis (v2).
/// 
/// Orijinal dsys şablonları kullanılarak (assets/templates) Karar
/// ve Gündem çıktıları tamamen birebir formatta oluşturulur.
class BelgeUretimServisi {
  
  /// Aktif karar için orijinal şablon ile Word belgesi oluşturur ve indirir (Web uyumlu).
  static Future<void> kararWordIndir(YkKararModel karar) async {
    try {
      final ayarlar = await SistemAyarlariService().getAyarlar();
      final buffer = StringBuffer();
      buffer.writeln(karar.kararMetni);
      buffer.writeln();
      buffer.writeln();

      if (karar.tabloVerileri.isNotEmpty) {
        // Faaliyet cetveli başlığı gibi algılanması için
        buffer.writeln('GELİR GETİRİCİ FAALİYET CETVELİ BAŞLIĞI');
        buffer.writeln('─' * 80);
        final columns = karar.tabloVerileri.first.keys.toList();
        
        // Tablo başlık satırı (| ile ayrılmış)
        buffer.writeln('| ' + columns.join(' | ') + ' |');
        
        // Tablo verileri
        for (final row in karar.tabloVerileri) {
          final cells = columns.map((col) => row[col]?.toString() ?? '').toList();
          buffer.writeln('| ' + cells.join(' | ') + ' |');
        }
        buffer.writeln();
      }

      final bytes = await _buildDocxFromTemplate(buffer.toString(), isKarar: true, kurulUyeleri: ayarlar.kurulUyeleri);
      
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'Karar_${karar.kararNo.replaceAll('/', '_')}.docx')
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        debugPrint('Web harici indirme henüz desteklenmiyor.');
      }
    } catch (e) {
      debugPrint('[BelgeUretimServisi.kararWordIndir] Hata: $e');
      rethrow;
    }
  }

  static Future<Uint8List> kararPdfUret(YkKararModel karar) async {
    final pdf = pw.Document();

    final fontRegular = await PdfGoogleFonts.tinosRegular();
    final fontBold = await PdfGoogleFonts.tinosBold();

    final ayarlar = await SistemAyarlariService().getAyarlar();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(left: 70, right: 50, top: 70, bottom: 50),
        build: (pw.Context context) {
          return [
            // Sol üst T.C. UŞAK ÜNİVERSİTESİ
            pw.Text(
              'T.C.\nUŞAK ÜNİVERSİTESİ',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontRegular, fontSize: 12),
            ),
            pw.SizedBox(height: 20),
            
            // Ana Başlık
            pw.Center(
              child: pw.Text(
                'DÖNER SERMAYE YÜRÜTME KURULU KARARLARI',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 5),

            // Toplantı Bilgileri Kutusu
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOPLANTI SAYISI: ${karar.toplantiNo.padLeft(2, '0')}', style: pw.TextStyle(font: fontRegular, fontSize: 11)),
                  pw.Text('KARAR TARİHİ: ${karar.kararTarihi}', style: pw.TextStyle(font: fontRegular, fontSize: 11)),
                ],
              ),
            ),
            pw.SizedBox(height: 15),

            // Giriş Paragrafı
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 20),
              child: pw.Text(
                'Uşak Üniversitesi Döner Sermaye Yürütme Kurulu Rektör Yardımcısı Prof. Dr. Selçuk SAMANLI başkanlığında ${karar.kararTarihi} tarihinde saat 14:00\' te toplandı. Gündem maddeleri görüşülerek aşağıdaki kararlar alındı.',
                textAlign: pw.TextAlign.justify,
                style: pw.TextStyle(font: fontRegular, fontSize: 12, lineSpacing: 1.5),
              ),
            ),
            pw.SizedBox(height: 15),

            // Karar Başlığı
            pw.Text(
              'KARAR 2026/${karar.kararNo}',
              style: pw.TextStyle(font: fontBold, fontSize: 12),
            ),
            pw.SizedBox(height: 5),

            // Karar Metni
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 20),
              child: pw.Paragraph(
                text: karar.kararMetni,
                style: pw.TextStyle(font: fontRegular, fontSize: 12, lineSpacing: 1.5),
                textAlign: pw.TextAlign.justify,
              ),
            ),

            // Tablo (Varsa)
            if (karar.tabloVerileri.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: karar.tabloVerileri.first.keys.map((k) => k.toUpperCase()).toList(),
                data: karar.tabloVerileri.map((row) => row.values.map((v) => v?.toString() ?? '').toList()).toList(),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
                cellStyle: pw.TextStyle(font: fontRegular, fontSize: 10),
                cellAlignment: pw.Alignment.center,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              ),
            ],

            pw.SizedBox(height: 15),
            
            pw.Center(
              child: pw.Text(
                'Katılanların oy birliği ile karar verildi.',
                style: pw.TextStyle(font: fontRegular, fontSize: 12),
              ),
            ),
            
            pw.SizedBox(height: 30),

            // İmza Tablosu
            pw.Table(
              border: pw.TableBorder.all(),
              columnWidths: {
                0: const pw.FlexColumnWidth(1),
                1: const pw.FlexColumnWidth(3),
                2: const pw.FlexColumnWidth(3),
                3: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Sıra No', style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Görevi', style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Üyenin Adı Soyadı', style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                    pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('İmzası', style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                  ]
                ),
                ...List.generate(ayarlar.kurulUyeleri.isEmpty ? 5 : ayarlar.kurulUyeleri.length, (index) {
                  final uye = ayarlar.kurulUyeleri.isNotEmpty ? ayarlar.kurulUyeleri[index] : null;
                  return pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('${index + 1}', style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(uye?.gorev ?? '', style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(uye?.adSoyad ?? '', style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('', style: pw.TextStyle(font: fontRegular, fontSize: 10))),
                    ]
                  );
                }),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Toplantı Gündemi için Word belgesi oluşturur (gundem_sablonu.docx kullanır)
  static Future<void> toplantiGundemWordIndir(ToplantiModel toplanti) async {
    try {
      final ayarlar = await SistemAyarlariService().getAyarlar();
      final buffer = StringBuffer();
      
      buffer.writeln('GÜNDEM');
      buffer.writeln();

      for (var i = 0; i < toplanti.gundemMaddeleri.length; i++) {
        final madde = toplanti.gundemMaddeleri[i];
        buffer.writeln('${i + 1}. ${madde.baslik}');
      }

      // isKarar = false diyerek gundem_sablonu.docx'i seçecek
      final bytes = await _buildDocxFromTemplate(
        buffer.toString(), 
        isKarar: false, 
        kurulUyeleri: ayarlar.kurulUyeleri
      );
      
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'Gundem_${toplanti.toplantiNo.replaceAll('/', '_')}.docx')
          ..click();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      debugPrint('[BelgeUretimServisi.toplantiGundemWordIndir] Hata: $e');
      rethrow;
    }
  }

  /// Tüm toplantı kararlarını tek bir Word belgesinde birleştirir.
  static Future<void> topluKararWordIndir(List<YkKararModel> kararlar, String toplantiNo) async {
    if (kararlar.isEmpty) return;

    try {
      final ayarlar = await SistemAyarlariService().getAyarlar();
      final buffer = StringBuffer();

      for (var i = 0; i < kararlar.length; i++) {
        final karar = kararlar[i];

        if (i > 0) {
          buffer.writeln('\n---\n'); // Sayfa sonu ayıracı olabilir ama şimdilik sadece boşluk.
        }

        buffer.writeln('KARAR NO: ${karar.kararNo}');
        buffer.writeln();
        buffer.writeln(karar.kararMetni);
        buffer.writeln();

        if (karar.tabloVerileri.isNotEmpty) {
          buffer.writeln('GELİR GETİRİCİ FAALİYET CETVELİ BAŞLIĞI');
          buffer.writeln('─' * 80);
          final columns = karar.tabloVerileri.first.keys.toList();
          buffer.writeln('| ' + columns.join(' | ') + ' |');
          
          for (final row in karar.tabloVerileri) {
            final cells = columns.map((col) => row[col]?.toString() ?? '').toList();
            buffer.writeln('| ' + cells.join(' | ') + ' |');
          }
          buffer.writeln();
        }
      }

      final bytes = await _buildDocxFromTemplate(buffer.toString(), isKarar: true, kurulUyeleri: ayarlar.kurulUyeleri);
      
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'Toplanti_$toplantiNo.docx')
          ..click();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      debugPrint('[BelgeUretimServisi.topluKararWordIndir] Hata: $e');
      rethrow;
    }
  }

  /// Danışmanlık Karar/Sözleşme taslağı için Word belgesi oluşturur.
  static Future<void> danismanlikWordIndir(DanismanlikModel danismanlik, String kararMetni) async {
    try {
      final ayarlar = await SistemAyarlariService().getAyarlar();
      final buffer = StringBuffer();
      
      buffer.writeln('KARAR');
      buffer.writeln();
      buffer.writeln('Danışmanlık Türü: ${danismanlik.danismanlikTuru.displayName}');
      buffer.writeln('Firma: ${danismanlik.firmaUnvan}');
      buffer.writeln('Konu: ${danismanlik.konusu}');
      buffer.writeln('Süre: ${danismanlik.suresi} Ay');
      buffer.writeln();
      buffer.writeln(kararMetni);

      final bytes = await _buildDocxFromTemplate(buffer.toString(), isKarar: true, kurulUyeleri: ayarlar.kurulUyeleri);
      
      if (kIsWeb) {
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.AnchorElement(href: url)
          ..setAttribute('download', 'Danismanlik_${danismanlik.firmaUnvan?.replaceAll(' ', '_') ?? 'Belge'}.docx')
          ..click();
        html.Url.revokeObjectUrl(url);
      }
    } catch (e) {
      debugPrint('[BelgeUretimServisi.danismanlikWordIndir] Hata: $e');
      rethrow;
    }
  }


  // ─────────────────────────────────────────────────────────────
  // Orijinal DOCX (Office Open XML) ÜRETİMİ (Şablon Tabanlı)
  // ─────────────────────────────────────────────────────────────

  /// Firebase'den veya Assets'ten şablonu yükler, word/document.xml dosyasını değiştirir ve ZIP olarak geri döndürür.
  static Future<Uint8List> _buildDocxFromTemplate(String content, {required bool isKarar, List<YkUyeModel>? kurulUyeleri}) async {
    List<int> templateBytes;
    final tur = isKarar ? 'yk_karar' : 'gundem';
    
    try {
      final sablonlarRef = FirebaseFirestore.instance.collection('sistemSablonlari');
      final query = await sablonlarRef.where('tur', isEqualTo: tur).orderBy('eklenmeTarihi', descending: true).limit(1).get();
      
      if (query.docs.isNotEmpty) {
        final url = query.docs.first['dosyaUrl'] as String;
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          templateBytes = response.bodyBytes;
        } else {
          throw Exception('Storage download failed');
        }
      } else {
        throw Exception('No template in DB');
      }
    } catch (e) {
      debugPrint('[BelgeUretimServisi] Firebase şablonu bulunamadı, varsayılan asset kullanılıyor: $e');
      final templatePath = isKarar
          ? 'assets/templates/karar_sablonu.docx'
          : 'assets/templates/gundem_sablonu.docx';

      final ByteData assetData = await rootBundle.load(templatePath);
      templateBytes = assetData.buffer.asUint8List(
        assetData.offsetInBytes,
        assetData.lengthInBytes,
      );
    }

    // ZIP arşivini aç
    final archive = ZipDecoder().decodeBytes(templateBytes);

    // word/document.xml dosyasını bul
    final docFileIndex = archive.files.indexWhere((f) => f.name == 'word/document.xml');
    if (docFileIndex == -1) {
      throw Exception('word/document.xml şablon içinde bulunamadı.');
    }
    final docFile = archive.files[docFileIndex];
    final originalXml = utf8.decode(docFile.content as List<int>, allowMalformed: true);

    // Şablondaki sayfa yapısını (sectPr: margins, headers, footers) korumak için sectPr tag'ini bul
    final sectPrMatch = RegExp(r'<w:sectPr\b[^>]*>.*?</w:sectPr>', dotAll: true).firstMatch(originalXml);
    final sectPrXml = sectPrMatch?.group(0) ?? '';

    // Şablondaki w:document açılış tag'ini (tüm xmlns tanımlarıyla birlikte) koru
    final documentOpenMatch = RegExp(r'<w:document\b[^>]*>', dotAll: true).firstMatch(originalXml);
    final documentOpenXml = documentOpenMatch?.group(0) ?? '''<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
            xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
            xmlns:o="urn:schemas-microsoft-com:office:office"
            xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"
            xmlns:m="http://schemas.openxmlformats.org/officeDocument/2006/math"
            xmlns:v="urn:schemas-microsoft-com:vml"
            xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"
            xmlns:w10="urn:schemas-microsoft-com:office:word"
            xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"
            xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml"
            xmlns:wpg="http://schemas.microsoft.com/office/word/2010/wordprocessingGroup"
            xmlns:wpi="http://schemas.microsoft.com/office/word/2010/wordprocessingInk"
            xmlns:wne="http://schemas.microsoft.com/office/word/2006/wordml"
            xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape"
            mc:Ignorable="w14">''';

    // Yeni body içeriğini üret
    final generatedBody = buildDocumentBodyXml(content, sectPrXml, kurulUyeleri);

    final finalDocXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
$documentOpenXml
  <w:body>
$generatedBody
  </w:body>
</w:document>''';

    final docFileData = utf8.encode(finalDocXml);

    // Yeni ZIP arşivi oluşturup dosyaları aktar
    final newArchive = Archive();
    for (final f in archive.files) {
      if (f.name == 'word/document.xml') {
        newArchive.addFile(ArchiveFile('word/document.xml', docFileData.length, docFileData));
      } else {
        newArchive.addFile(f);
      }
    }

    final zipData = ZipEncoder().encode(newArchive);
    return Uint8List.fromList(zipData!);
  }

  /// Gelen metin satırlarını ve tablolarını w:body formatına dönüştürür.
  static String buildDocumentBodyXml(String content, String sectPrXml, List<YkUyeModel>? kurulUyeleri) {
    final lines = content.split('\n');
    final bodyContent = StringBuffer();
    
    List<List<String>>? currentTable;
    
    for (final line in lines) {
      final trimmed = line.trim();
      
      if (trimmed.startsWith('|') && trimmed.endsWith('|') && trimmed.length > 2) {
        // Tablo satırı
        if (trimmed.contains(RegExp(r'^\|[\s:-|]+$'))) {
          continue; // Tablo ayracı (|---|) ise atla
        }
        final cells = trimmed.split('|')
            .map((c) => c.trim())
            .toList();
        if (cells.first.isEmpty) cells.removeAt(0);
        if (cells.isNotEmpty && cells.last.isEmpty) cells.removeLast();
        
        currentTable ??= [];
        currentTable.add(cells);
      } else {
        // Tablo dışı satır. Varsa önceki tabloyu yazdır.
        if (currentTable != null) {
          bodyContent.writeln(_buildDocxTableXml(currentTable));
          currentTable = null;
        }
        
        if (trimmed.isNotEmpty) {
          final escaped = _xmlEscape(trimmed);
          final isHeading = _isHeadingLine(trimmed);
          
          if (isHeading) {
            // Başlık paragrafları
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
            // Normal paragraflar
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
    
    // İmza tablosunu ekle
    if (kurulUyeleri != null && kurulUyeleri.isNotEmpty) {
      bodyContent.writeln('''
      <w:p>
        <w:pPr>
          <w:spacing w:before="360" w:after="120" w:line="360" w:lineRule="auto"/>
          <w:ind w:leftChars="0" w:left="0" w:firstLineChars="0" w:firstLine="720"/>
          <w:jc w:val="both"/>
        </w:pPr>
        <w:r>
          <w:rPr>
            <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>
            <w:sz w:val="24"/>
            <w:szCs w:val="24"/>
          </w:rPr>
          <w:t>Katılanların oy birliği ile karar verildi.</w:t>
        </w:r>
      </w:p>
      <w:p><w:pPr><w:spacing w:after="240"/></w:pPr></w:p>
      ''');

      final signatureTable = <List<String>>[
        ['Sıra No', 'Görevi', 'Üyenin Adı Soyadı', 'İmzası'],
      ];
      for (int i = 0; i < kurulUyeleri.length; i++) {
        final uye = kurulUyeleri[i];
        signatureTable.add([
          '${i + 1}',
          uye.gorev,
          uye.adSoyad,
          '',
        ]);
      }
      bodyContent.writeln(_buildDocxTableXml(signatureTable));
    }

    // Sayfa yapısını (margins, header/footer referansları vb.) en sona ekle
    if (sectPrXml.isNotEmpty) {
      bodyContent.writeln(sectPrXml);
    }
    
    return bodyContent.toString();
  }

  static bool _isHeadingLine(String line) {
    final upper = line.toUpperCase();
    if (upper.startsWith('KARAR ') || upper.startsWith('GÜNDEM ')) return true;
    if (upper == 'GELİR GETİRİCİ FAALİYET CETVELİ' || 
        upper == 'DAĞITIM ÖZETİ' || 
        upper == 'İMZA TABLOSU' ||
        upper == 'GELİR GETİRİCİ FAALİYET CETVELİ BAŞLIĞI') return true;
    return false;
  }

  static bool _isNonIndentedLine(String line) {
    final upper = line.toUpperCase();
    if (upper == 'T.C.' || 
        upper.startsWith('UŞAK ÜNİVERSİTESİ') || 
        upper.startsWith('DÖNER SERMAYE') ||
        upper.contains('TOPLANTI SAYISI:') ||
        upper.contains('KARAR TARİHİ:') ||
        upper.contains('─')) return true;
    return false;
  }

  static String _buildDocxTableXml(List<List<String>> tableData) {
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
        if (isHeader || RegExp(r'^\d+(\.\d+)?\s*([%₺]|TL)?$').hasMatch(cell.trim())) {
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

  static String _xmlEscape(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}
