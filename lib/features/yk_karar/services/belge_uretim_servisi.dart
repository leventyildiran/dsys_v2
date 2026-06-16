import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:pdf/pdf.dart';
import 'package:file_saver/file_saver.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:archive/archive.dart';
import '../models/yk_karar_model.dart';
import '../../danismanlik/models/danismanlik_model.dart';
import '../../../core/models/sistem_ayarlari_model.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/sablon_model.dart';
import '../models/gundem_model.dart';
import 'docx_ooxml_util.dart';
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
      final Uint8List bytes;

      if (karar.docxBodyXml != null && karar.docxBodyXml!.isNotEmpty) {
        bytes = await _buildDocxFromOoxmlKararlar([
          karar,
        ], kurulUyeleri: ayarlar.kurulUyeleri);
      } else {
        final buffer = StringBuffer();
        buffer.writeln(karar.kararMetni);
        bytes = await _buildDocxFromTemplate(
          buffer.toString(),
          isKarar: true,
          kurulUyeleri: ayarlar.kurulUyeleri,
        );
      }

      await FileSaver.instance.saveFile(
        name: 'Karar_${karar.kararNo.replaceAll('/', '_')}.docx',
        bytes: bytes,
        mimeType: MimeType.microsoftWord,
      );
    } catch (e) {
      debugPrint('[BelgeUretimServisi.kararWordIndir] Hata: $e');
      rethrow;
    }
  }

  /// Karar metnini düz metin olarak döndürür (Quill JSON veya plain).
  static String kararDuzMetin(YkKararModel karar) {
    try {
      final decoded = jsonDecode(karar.kararMetni);
      if (decoded is List) {
        return quill.Document.fromJson(decoded).toPlainText().trim();
      }
    } catch (_) {}
    return karar.kararMetni.trim();
  }

  /// Tablo başlıkları ve satırları — PDF önizleme ve ekran için.
  static ({List<String> headers, List<List<String>> rows})? kararTabloVerisi(
    YkKararModel karar,
  ) {
    if (karar.tabloVerileri.isNotEmpty) {
      final cols = karar.tabloVerileri.first.keys.toList();
      return (
        headers: cols,
        rows: karar.tabloVerileri
            .map((r) => cols.map((c) => r[c]?.toString() ?? '').toList())
            .toList(),
      );
    }
    if (karar.docxBodyXml != null && karar.docxBodyXml!.contains('<w:tbl')) {
      final tables = DocxOoxmlUtil.extractDataTablesFromBodyXml(
        karar.docxBodyXml!,
      );
      if (tables.isEmpty) return null;
      final header = tables.first;
      final data = tables.length > 1 ? tables.sublist(1) : <List<String>>[];
      return (headers: header, rows: data);
    }
    return null;
  }

  static Future<void> kararPdfIndir(YkKararModel karar) async {
    final bytes = await kararPdfUret(karar);
    await FileSaver.instance.saveFile(
      name: 'Karar_${karar.kararNo.replaceAll('/', '_')}.pdf',
      bytes: bytes,
      mimeType: MimeType.pdf,
    );
  }

  static Future<Uint8List> kararPdfUret(YkKararModel karar) async {
    final pdf = pw.Document();
    final metin = kararDuzMetin(karar);
    final tablo = kararTabloVerisi(karar);

    final fontRegular = await PdfGoogleFonts.tinosRegular();
    final fontBold = await PdfGoogleFonts.tinosBold();

    final ayarlar = await SistemAyarlariService().getAyarlar();
    final kararBaslik = karar.kararNo.isNotEmpty
        ? 'KARAR ${karar.kararNo}'
        : 'KARAR';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          left: 70,
          right: 50,
          top: 70,
          bottom: 50,
        ),
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
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOPLANTI SAYISI: ${karar.toplantiNo.padLeft(2, '0')}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 11),
                  ),
                  pw.Text(
                    'KARAR TARİHİ: ${karar.kararTarihi}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 11),
                  ),
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
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 12,
                  lineSpacing: 1.5,
                ),
              ),
            ),
            pw.SizedBox(height: 15),

            pw.Text(
              kararBaslik,
              style: pw.TextStyle(font: fontBold, fontSize: 12),
            ),
            pw.SizedBox(height: 5),

            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 20),
              child: pw.Paragraph(
                text: metin,
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 12,
                  lineSpacing: 1.5,
                ),
                textAlign: pw.TextAlign.justify,
              ),
            ),

            if (tablo != null && tablo.rows.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                headers: tablo.headers.map((h) => h.toUpperCase()).toList(),
                data: tablo.rows,
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
                cellStyle: pw.TextStyle(font: fontRegular, fontSize: 10),
                cellAlignment: pw.Alignment.center,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey300,
                ),
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
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        'Sıra No',
                        style: pw.TextStyle(font: fontRegular, fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        'Görevi',
                        style: pw.TextStyle(font: fontRegular, fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        'Üyenin Adı Soyadı',
                        style: pw.TextStyle(font: fontRegular, fontSize: 10),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(5),
                      child: pw.Text(
                        'İmzası',
                        style: pw.TextStyle(font: fontRegular, fontSize: 10),
                      ),
                    ),
                  ],
                ),
                ...List.generate(
                  ayarlar.kurulUyeleri.isEmpty
                      ? 5
                      : ayarlar.kurulUyeleri.length,
                  (index) {
                    final uye = ayarlar.kurulUyeleri.isNotEmpty
                        ? ayarlar.kurulUyeleri[index]
                        : null;
                    return pw.TableRow(
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            '${index + 1}',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            uye?.gorev ?? '',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            uye?.adSoyad ?? '',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                            ),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            '',
                            style: pw.TextStyle(
                              font: fontRegular,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
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
        kurulUyeleri: ayarlar.kurulUyeleri,
      );

      await FileSaver.instance.saveFile(
        name: 'Gundem_${toplanti.toplantiNo.replaceAll('/', '_')}.docx',
        bytes: bytes,
        mimeType: MimeType.microsoftWord,
      );
    } catch (e) {
      debugPrint('[BelgeUretimServisi.toplantiGundemWordIndir] Hata: $e');
      rethrow;
    }
  }

  /// Tüm toplantı kararlarını tek bir Word belgesinde birleştirir.
  /// Karar defterine yapıştırılacak ana toplantı çıktısıdır.
  static Future<void> topluKararWordIndir(
    List<YkKararModel> kararlar,
    String toplantiNo,
  ) async {
    await kararlarWordIndir(
      kararlar,
      dosyaAdi: 'Toplanti_${toplantiNo.replaceAll('/', '_')}',
    );
  }

  /// Seçili birime ait tüm kararları tek Word belgesinde indirir.
  ///
  /// Bir toplantıda aynı birime ait birden fazla karar varsa ayrı ayrı değil,
  /// aynı resmi şablon ve tek imza alanıyla birlikte üretilir.
  static Future<void> birimKararWordIndir(
    List<YkKararModel> kararlar, {
    required String toplantiNo,
    required String birimAd,
  }) async {
    await kararlarWordIndir(
      kararlar,
      dosyaAdi:
          'Toplanti_${toplantiNo.replaceAll('/', '_')}_${_dosyaAdiTemizle(birimAd)}',
    );
  }

  /// Karar listesini ana YK karar şablonu ve imza alanıyla Word olarak indirir.
  static Future<void> kararlarWordIndir(
    List<YkKararModel> kararlar, {
    required String dosyaAdi,
  }) async {
    if (kararlar.isEmpty) return;

    try {
      final bytes = await kararlarWordBytes(kararlar);

      await FileSaver.instance.saveFile(
        name: '$dosyaAdi.docx',
        bytes: bytes,
        mimeType: MimeType.microsoftWord,
      );
    } catch (e) {
      debugPrint('[BelgeUretimServisi.kararlarWordIndir] Hata: $e');
      rethrow;
    }
  }

  /// Toplantıdaki tüm birim kararlarını editör/önizleme için birleşik metin yapar.
  static String anaKararBirlesikMetin(List<YkKararModel> kararlar) {
    final buffer = StringBuffer();
    for (var i = 0; i < kararlar.length; i++) {
      final karar = kararlar[i];
      if (i > 0) buffer.writeln();
      final baslik = karar.kararNo.isNotEmpty
          ? 'KARAR ${karar.kararNo}'
          : 'KARAR ${i + 1}';
      buffer.writeln(baslik);
      if (karar.birimAd.trim().isNotEmpty) {
        buffer.writeln(karar.birimAd);
      }
      buffer.writeln();
      buffer.writeln(kararDuzMetin(karar));
      buffer.writeln();
      final tablo = kararTabloVerisi(karar);
      if (tablo != null && tablo.rows.isNotEmpty) {
        buffer.writeln('| ${tablo.headers.join(' | ')} |');
        buffer.writeln('| ${tablo.headers.map((_) => '---').join(' | ')} |');
        for (final row in tablo.rows) {
          buffer.writeln('| ${row.join(' | ')} |');
        }
        buffer.writeln();
      }
    }
    return buffer.toString().trim();
  }

  /// Karar listesini ana YK karar şablonu ve imza alanıyla Word bytes üretir.
  static Future<Uint8List> kararlarWordBytes(
    List<YkKararModel> kararlar,
  ) async {
    final ayarlar = await SistemAyarlariService().getAyarlar();
    final hasOoxml = kararlar.any(
      (k) => k.docxBodyXml != null && k.docxBodyXml!.isNotEmpty,
    );

    if (hasOoxml) {
      return _buildDocxFromOoxmlKararlar(
        kararlar,
        kurulUyeleri: ayarlar.kurulUyeleri,
      );
    }

    return _buildDocxFromTemplate(
      anaKararBirlesikMetin(kararlar),
      isKarar: true,
      kurulUyeleri: ayarlar.kurulUyeleri,
    );
  }

  /// Karar listesini resmi A4 PDF olarak üretir.
  ///
  /// Ana toplantı çıktısı veya birim bazlı gönderim çıktısı için aynı düzeni
  /// kullanır; imza alanı belgenin sonunda bir kez yer alır.
  static Future<Uint8List> kararlarPdfUret(
    List<YkKararModel> kararlar, {
    String? belgeBasligi,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.tinosRegular();
    final fontBold = await PdfGoogleFonts.tinosBold();
    final ayarlar = await SistemAyarlariService().getAyarlar();
    final ilkKarar = kararlar.isNotEmpty ? kararlar.first : null;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.only(
          left: 70,
          right: 50,
          top: 70,
          bottom: 50,
        ),
        build: (pw.Context context) {
          return [
            pw.Text(
              'T.C.\nUŞAK ÜNİVERSİTESİ',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(font: fontRegular, fontSize: 12),
            ),
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                belgeBasligi ?? 'DÖNER SERMAYE YÜRÜTME KURULU KARARLARI',
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 16,
                  color: PdfColors.grey700,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.black, width: 1),
              ),
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOPLANTI SAYISI: ${ilkKarar?.toplantiNo.padLeft(2, '0') ?? ''}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 11),
                  ),
                  pw.Text(
                    'KARAR TARİHİ: ${ilkKarar?.kararTarihi ?? ''}',
                    style: pw.TextStyle(font: fontRegular, fontSize: 11),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 15),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 20),
              child: pw.Text(
                'Uşak Üniversitesi Döner Sermaye Yürütme Kurulu Rektör Yardımcısı Prof. Dr. Selçuk SAMANLI başkanlığında ${ilkKarar?.kararTarihi ?? ''} tarihinde saat 14:00\' te toplandı. Gündem maddeleri görüşülerek aşağıdaki kararlar alındı.',
                textAlign: pw.TextAlign.justify,
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 12,
                  lineSpacing: 1.5,
                ),
              ),
            ),
            pw.SizedBox(height: 15),
            ..._pdfKararBolumleri(
              kararlar,
              fontRegular: fontRegular,
              fontBold: fontBold,
              context: context,
            ),
            pw.SizedBox(height: 15),
            pw.Center(
              child: pw.Text(
                'Katılanların oy birliği ile karar verildi.',
                style: pw.TextStyle(font: fontRegular, fontSize: 12),
              ),
            ),
            pw.SizedBox(height: 30),
            _pdfImzaTablosu(ayarlar.kurulUyeleri, fontRegular: fontRegular),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Kararların OOXML parçalarını birebir birleştirir.
  static Future<Uint8List> _buildDocxFromOoxmlKararlar(
    List<YkKararModel> kararlar, {
    List<YkUyeModel>? kurulUyeleri,
  }) async {
    final templateBytes = await _loadKararTemplateBytes();
    final archive = ZipDecoder().decodeBytes(templateBytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
    );
    final originalXml = utf8.decode(
      docFile.content as List<int>,
      allowMalformed: true,
    );

    final sectPrXml = DocxOoxmlUtil.extractSectPr(originalXml);
    final documentOpenXml = DocxOoxmlUtil.extractDocumentOpen(originalXml);

    final bodyParts = <String>[];
    for (var i = 0; i < kararlar.length; i++) {
      if (i > 0) bodyParts.add(DocxOoxmlUtil.pageBreakXml());
      final karar = kararlar[i];
      if (karar.docxBodyXml != null && karar.docxBodyXml!.isNotEmpty) {
        bodyParts.add(karar.docxBodyXml!);
      } else {
        bodyParts.add(buildDocumentBodyXml(karar.kararMetni, '', null));
      }
    }

    if (kurulUyeleri != null && kurulUyeleri.isNotEmpty) {
      bodyParts.add(
        buildDocumentBodyXml(
          'Katılanların oy birliği ile karar verildi.',
          '',
          kurulUyeleri,
        ),
      );
    }
    if (sectPrXml.isNotEmpty) bodyParts.add(sectPrXml);

    final finalDocXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
$documentOpenXml
  <w:body>
    ${bodyParts.join('\n    ')}
  </w:body>
</w:document>''';

    return _replaceDocumentXmlInArchive(archive, finalDocXml);
  }

  static List<pw.Widget> _pdfKararBolumleri(
    List<YkKararModel> kararlar, {
    required pw.Font fontRegular,
    required pw.Font fontBold,
    required pw.Context context,
  }) {
    final widgets = <pw.Widget>[];
    for (var i = 0; i < kararlar.length; i++) {
      final karar = kararlar[i];
      if (i > 0) widgets.add(pw.SizedBox(height: 16));
      widgets.add(
        pw.Text(
          karar.kararNo.isNotEmpty
              ? 'KARAR ${karar.kararNo}'
              : 'KARAR ${i + 1}',
          style: pw.TextStyle(font: fontBold, fontSize: 12),
        ),
      );
      widgets.add(pw.SizedBox(height: 5));
      widgets.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 20),
          child: pw.Paragraph(
            text: kararDuzMetin(karar),
            style: pw.TextStyle(
              font: fontRegular,
              fontSize: 12,
              lineSpacing: 1.5,
            ),
            textAlign: pw.TextAlign.justify,
          ),
        ),
      );

      final tablo = kararTabloVerisi(karar);
      if (tablo != null && tablo.rows.isNotEmpty) {
        widgets.add(pw.SizedBox(height: 10));
        widgets.add(
          pw.TableHelper.fromTextArray(
            context: context,
            headers: tablo.headers.map((h) => h.toUpperCase()).toList(),
            data: tablo.rows,
            headerStyle: pw.TextStyle(font: fontBold, fontSize: 9),
            cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
            cellAlignment: pw.Alignment.center,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
          ),
        );
      }
    }
    return widgets;
  }

  static pw.Widget _pdfImzaTablosu(
    List<YkUyeModel> uyeler, {
    required pw.Font fontRegular,
  }) {
    return pw.Table(
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
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'Sıra No',
                style: pw.TextStyle(font: fontRegular, fontSize: 10),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'Görevi',
                style: pw.TextStyle(font: fontRegular, fontSize: 10),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'Üyenin Adı Soyadı',
                style: pw.TextStyle(font: fontRegular, fontSize: 10),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(5),
              child: pw.Text(
                'İmzası',
                style: pw.TextStyle(font: fontRegular, fontSize: 10),
              ),
            ),
          ],
        ),
        ...List.generate(uyeler.isEmpty ? 5 : uyeler.length, (index) {
          final uye = uyeler.isNotEmpty ? uyeler[index] : null;
          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  '${index + 1}',
                  style: pw.TextStyle(font: fontRegular, fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  uye?.gorev ?? '',
                  style: pw.TextStyle(font: fontRegular, fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  uye?.adSoyad ?? '',
                  style: pw.TextStyle(font: fontRegular, fontSize: 10),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: pw.Text(
                  '',
                  style: pw.TextStyle(font: fontRegular, fontSize: 10),
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  static String _dosyaAdiTemizle(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'_+'), '_');
  }

  /// Sistem Ayarları'ndaki Word şablonunu yükler; yoksa assets'e düşer.
  /// [preferOrtak]: true ise birim arşivleri yerine "Tüm Birimler" şablonunu tercih eder (dış kapak).
  static Future<List<int>> _loadSablonBytes(
    String tur, {
    bool preferOrtak = true,
  }) async {
    try {
      final snapshot = await FirestoreService()
          .collection('sistemSablonlari')
          .where('tur', isEqualTo: tur)
          .get();

      if (snapshot.docs.isEmpty) throw Exception('Firestore şablon yok');

      final sablonlar = snapshot.docs
          .map((d) => SablonModel.fromJson(d.data(), d.id))
          .where((s) => s.dosyaUzantisi == '.docx' || s.dosyaUzantisi == '.doc')
          .toList();

      if (sablonlar.isEmpty) throw Exception('Word şablonu yok');

      int oncelik(SablonModel s) {
        final ortak =
            s.birimId == null && (s.birimAd == null || s.birimAd!.isEmpty);
        if (preferOrtak && ortak) return 0;
        if (!preferOrtak && !ortak) return 1;
        if (ortak) return 2;
        return 3;
      }

      sablonlar.sort((a, b) {
        final p = oncelik(a).compareTo(oncelik(b));
        if (p != 0) return p;
        return b.eklenmeTarihi.compareTo(a.eklenmeTarihi);
      });

      final url = sablonlar.first.dosyaUrl;
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        debugPrint(
          '[BelgeUretimServisi] Şablon yüklendi: ${sablonlar.first.sablonAdi} ($tur)',
        );
        return response.bodyBytes;
      }
      throw Exception('Storage indirme hatası: ${response.statusCode}');
    } catch (e) {
      debugPrint(
        '[BelgeUretimServisi] Firebase şablonu kullanılamadı ($tur), asset: $e',
      );
      final templatePath = tur == 'yk_karar'
          ? 'assets/templates/karar_sablonu.docx'
          : 'assets/templates/gundem_sablonu.docx';
      final assetData = await rootBundle.load(templatePath);
      return assetData.buffer.asUint8List(
        assetData.offsetInBytes,
        assetData.lengthInBytes,
      );
    }
  }

  static Future<List<int>> _loadKararTemplateBytes() =>
      _loadSablonBytes('yk_karar');

  static Uint8List _replaceDocumentXmlInArchive(
    Archive archive,
    String finalDocXml,
  ) {
    final docFileData = utf8.encode(finalDocXml);
    final newArchive = Archive();
    for (final f in archive.files) {
      if (f.name == 'word/document.xml') {
        newArchive.addFile(
          ArchiveFile('word/document.xml', docFileData.length, docFileData),
        );
      } else {
        newArchive.addFile(f);
      }
    }
    final zipData = ZipEncoder().encode(newArchive);
    return Uint8List.fromList(zipData);
  }

  /// Danışmanlık Karar/Sözleşme taslağı için Word belgesi oluşturur.
  static Future<void> danismanlikWordIndir(
    DanismanlikModel danismanlik,
    String kararMetni,
  ) async {
    try {
      final ayarlar = await SistemAyarlariService().getAyarlar();
      final buffer = StringBuffer();

      buffer.writeln('KARAR');
      buffer.writeln();
      buffer.writeln(
        'Danışmanlık Türü: ${danismanlik.danismanlikTuru.displayName}',
      );
      buffer.writeln('Firma: ${danismanlik.firmaUnvan}');
      buffer.writeln('Konu: ${danismanlik.konusu}');
      buffer.writeln('Süre: ${danismanlik.suresi} Ay');
      buffer.writeln();
      buffer.writeln(kararMetni);

      final bytes = await _buildDocxFromTemplate(
        buffer.toString(),
        isKarar: true,
        kurulUyeleri: ayarlar.kurulUyeleri,
      );

      await FileSaver.instance.saveFile(
        name:
            'Danismanlik_${danismanlik.firmaUnvan?.replaceAll(' ', '_') ?? 'Belge'}.docx',
        bytes: bytes,
        mimeType: MimeType.microsoftWord,
      );
    } catch (e) {
      debugPrint('[BelgeUretimServisi.danismanlikWordIndir] Hata: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Orijinal DOCX (Office Open XML) ÜRETİMİ (Şablon Tabanlı)
  // ─────────────────────────────────────────────────────────────

  /// Firebase'den veya Assets'ten şablonu yükler, word/document.xml dosyasını değiştirir ve ZIP olarak geri döndürür.
  static Future<Uint8List> _buildDocxFromTemplate(
    String content, {
    required bool isKarar,
    List<YkUyeModel>? kurulUyeleri,
  }) async {
    final tur = isKarar ? 'yk_karar' : 'gundem';
    final templateBytes = await _loadSablonBytes(tur);
    final archive = ZipDecoder().decodeBytes(templateBytes);

    // word/document.xml dosyasını bul
    final docFileIndex = archive.files.indexWhere(
      (f) => f.name == 'word/document.xml',
    );
    if (docFileIndex == -1) {
      throw Exception('word/document.xml şablon içinde bulunamadı.');
    }
    final docFile = archive.files[docFileIndex];
    final originalXml = utf8.decode(
      docFile.content as List<int>,
      allowMalformed: true,
    );

    // Şablondaki sayfa yapısını (sectPr: margins, headers, footers) korumak için sectPr tag'ini bul
    final sectPrMatch = RegExp(
      r'<w:sectPr\b[^>]*>.*?</w:sectPr>',
      dotAll: true,
    ).firstMatch(originalXml);
    final sectPrXml = sectPrMatch?.group(0) ?? '';

    // Şablondaki w:document açılış tag'ini (tüm xmlns tanımlarıyla birlikte) koru
    final documentOpenMatch = RegExp(
      r'<w:document\b[^>]*>',
      dotAll: true,
    ).firstMatch(originalXml);
    final documentOpenXml =
        documentOpenMatch?.group(0) ??
        '''<w:document xmlns:wpc="http://schemas.microsoft.com/office/word/2010/wordprocessingCanvas"
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
    final generatedBody = buildDocumentBodyXml(
      content,
      sectPrXml,
      kurulUyeleri,
    );

    final finalDocXml =
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
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
        newArchive.addFile(
          ArchiveFile('word/document.xml', docFileData.length, docFileData),
        );
      } else {
        newArchive.addFile(f);
      }
    }

    final zipData = ZipEncoder().encode(newArchive);
    return Uint8List.fromList(zipData);
  }

  /// Gelen metin satırlarını ve tablolarını w:body formatına dönüştürür.
  static String buildDocumentBodyXml(
    String content,
    String sectPrXml,
    List<YkUyeModel>? kurulUyeleri,
  ) {
    final lines = content.split('\n');
    final bodyContent = StringBuffer();

    List<List<String>>? currentTable;

    for (final line in lines) {
      final trimmed = line.trim();

      if (trimmed.startsWith('|') &&
          trimmed.endsWith('|') &&
          trimmed.length > 2) {
        // Tablo satırı
        if (trimmed.contains(RegExp(r'^\|[\s:-|]+$'))) {
          continue; // Tablo ayracı (|---|) ise atla
        }
        final cells = trimmed.split('|').map((c) => c.trim()).toList();
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
        signatureTable.add(['${i + 1}', uye.gorev, uye.adSoyad, '']);
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
    if (upper.startsWith('KARAR ') || upper.startsWith('GÜNDEM ')) {
      return true;
    }
    if (upper == 'GELİR GETİRİCİ FAALİYET CETVELİ' ||
        upper == 'DAĞITIM ÖZETİ' ||
        upper == 'İMZA TABLOSU' ||
        upper == 'GELİR GETİRİCİ FAALİYET CETVELİ BAŞLIĞI') {
      return true;
    }
    return false;
  }

  static bool _isNonIndentedLine(String line) {
    final upper = line.toUpperCase();
    if (upper == 'T.C.' ||
        upper.startsWith('UŞAK ÜNİVERSİTESİ') ||
        upper.startsWith('DÖNER SERMAYE') ||
        upper.contains('TOPLANTI SAYISI:') ||
        upper.contains('KARAR TARİHİ:') ||
        upper.contains('─')) {
      return true;
    }
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
          buffer.writeln(
            '<w:shd w:val="clear" w:color="auto" w:fill="B8CCE4" w:themeFill="accent1" w:themeFillTint="66"/>',
          );
        }
        buffer.writeln('</w:tcPr>');

        buffer.writeln('<w:p>');
        buffer.writeln('<w:pPr>');
        buffer.writeln(
          '<w:spacing w:before="60" w:after="60" w:line="240" w:lineRule="auto"/>',
        );
        if (isHeader ||
            RegExp(r'^\d+(\.\d+)?\s*([%₺]|TL)?$').hasMatch(cell.trim())) {
          buffer.writeln('<w:jc w:val="center"/>');
        } else {
          buffer.writeln('<w:jc w:val="left"/>');
        }
        buffer.writeln('</w:pPr>');

        buffer.writeln('<w:r>');
        buffer.writeln('<w:rPr>');
        buffer.writeln(
          '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>',
        );
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
