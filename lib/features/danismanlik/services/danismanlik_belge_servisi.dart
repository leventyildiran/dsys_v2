import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/turkce_format.dart';
import '../models/dagitim_model.dart';
import '../models/danismanlik_model.dart';
import '../models/taksit_model.dart';
import 'danismanlik_excel_hesaplama.dart';

/// Danışmanlık gelir dağıtım tablosu PDF üretimi (Excel sayfalarına karşılık gelir).
class DanismanlikBelgeServisi {
  DanismanlikBelgeServisi._();

  static Future<Uint8List> dagitimPdfUret({
    required DanismanlikModel danismanlik,
    required DagitimHesapSonuc sonuc,
    TaksitModel? taksit,
  }) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.tinosRegular();
    final fontBold = await PdfGoogleFonts.tinosBold();

    final excel = sonuc.excelSonuc;
    final birim = danismanlik.birimKisaAd ?? 'Birim';
    final firma = danismanlik.firmaUnvan ?? danismanlik.konusu;
    final taksitEtiket = taksit != null ? ' — Ay ${taksit.ayNo}' : '';

    pw.TextStyle normal(double size) =>
        pw.TextStyle(font: fontRegular, fontSize: size);
    pw.TextStyle kalin(double size) =>
        pw.TextStyle(font: fontBold, fontSize: size);

    // ── Sayfa 1: DAĞ. MAKS. PAY ──
    if (excel != null) {
      final k = excel.kesinti;
      final kdv = DanismanlikExcelHesaplama.kdvTutari(
        k.kdvHaricGelir,
        danismanlik.kdvOrani,
      );
      final genel = DanismanlikExcelHesaplama.genelToplam(
        k.kdvHaricGelir,
        danismanlik.kdvOrani,
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (_) => [
            pw.Center(
              child: pw.Text(
                '$birim — Danışmanlık Gelir Dağıtımı$taksitEtiket',
                style: kalin(13),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Center(child: pw.Text(firma, style: normal(10))),
            pw.SizedBox(height: 16),
            pw.Text('DAĞ. MAKS. PAY. HESAPLAMA', style: kalin(11)),
            pw.Divider(thickness: 0.5),
            _pdfSatir(
              'GELİR (KDV Hariç)',
              TurkceFormat.para(k.kdvHaricGelir),
              kalin: true,
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              '%${danismanlik.kdvOrani} KDV',
              TurkceFormat.para(kdv),
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              'TOPLAM TUTAR',
              TurkceFormat.para(genel),
              kalin: true,
              normal: normal,
              bold: kalin,
            ),
            pw.SizedBox(height: 12),
            pw.Text('GELİRDEN AKTARILACAK PAYLAR', style: kalin(10)),
            pw.Divider(thickness: 0.5),
            _pdfSatir(
              'HAZİNE PAYI (%${danismanlik.hazinePayiOrani})',
              TurkceFormat.para(k.hazinePayi),
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              'BAP PAYI (%${danismanlik.bapPayiOrani})',
              TurkceFormat.para(k.bapPayi),
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              'ARAÇ GEREÇ PAYI (%${danismanlik.aracGerecPayiOrani})',
              TurkceFormat.para(k.aracGerecPayi),
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              'KATKI PAYI',
              TurkceFormat.para(k.katkiPayi),
              kalin: true,
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              'TOPLAM',
              TurkceFormat.para(k.toplam),
              kalin: true,
              normal: normal,
              bold: kalin,
            ),
            pw.Divider(thickness: 0.5),
            _pdfSatir(
              'DAĞ. MAKS. AKADEMİK PAY (%49)',
              TurkceFormat.para(k.dagMaksAkademikPay),
              normal: normal,
              bold: kalin,
            ),
            if (sonuc.kararMetni.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Text('KARAR METNİ', style: kalin(10)),
              pw.SizedBox(height: 4),
              pw.Paragraph(
                text: sonuc.kararMetni,
                style: normal(9),
                textAlign: pw.TextAlign.justify,
              ),
            ],
          ],
        ),
      );

      // ── Sayfa 2: KATKI PAYI (yatay A4) ──
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(28),
          build: (ctx) => [
            pw.Text('KATKI PAYI HESAPLAMA$taksitEtiket', style: kalin(11)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headers: const [
                'Adı Soyadı',
                'Puan',
                'Unvan K.',
                'Ders Saati',
                'Bireysel Net Katkı',
                'Dönem Kats.',
                'Saatlik Ücret',
                'Tavan Saatlik',
                'Brüt Hakediş',
                'Net Ödenen',
              ],
              data: [
                ...excel.personelSatirlari.map((s) {
                  final p = s.girdi;
                  return [
                    '${p.unvan} ${p.adSoyad}',
                    p.puan.toStringAsFixed(0),
                    p.unvanKatsayisi.toStringAsFixed(1),
                    p.dersSaati.toStringAsFixed(0),
                    s.bireyselNetKatkiPuani.toStringAsFixed(0),
                    TurkceFormat.katsayi(s.donemKatsayi),
                    TurkceFormat.para(s.kursSaatlikUcreti),
                    TurkceFormat.para(s.tavanSaatlikUcreti),
                    TurkceFormat.para(s.brutHakedis),
                    TurkceFormat.para(s.odenebilirHakedis),
                  ];
                }),
                [
                  'TOPLAM PUAN',
                  '',
                  '',
                  '',
                  excel.toplamPuan.toStringAsFixed(0),
                  TurkceFormat.katsayi(excel.donemKatsayi),
                  '',
                  '',
                  '',
                  TurkceFormat.para(excel.netOdemeToplam),
                ],
              ],
              headerStyle: kalin(7),
              cellStyle: normal(7),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
              cellPadding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 3,
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Sağlama: ${TurkceFormat.para(excel.saglama)}',
                  style: normal(9),
                ),
                pw.Text(
                  'Artık Bakiye: ${TurkceFormat.para(excel.artikBakiye)}',
                  style: normal(9),
                ),
              ],
            ),
          ],
        ),
      );

      // ── Sayfa 3: LİSTE ──
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (_) => [
            pw.Text('LİSTE — Fatura / Gelir$taksitEtiket', style: kalin(11)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: const ['S.N', 'Açıklama', 'Tutar'],
              data: [
                ['1', firma, TurkceFormat.para(k.kdvHaricGelir)],
              ],
              headerStyle: kalin(9),
              cellStyle: normal(9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
            pw.SizedBox(height: 12),
            _pdfSatir(
              'GELİR',
              TurkceFormat.para(k.kdvHaricGelir),
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              'KDV',
              TurkceFormat.para(kdv),
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              'TOPLAM',
              TurkceFormat.para(genel),
              kalin: true,
              normal: normal,
              bold: kalin,
            ),
          ],
        ),
      );
    } else {
      // Sanayi 58/k veya Excel dışı hesaplama
      final k = sonuc.kesinti;
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (ctx) => [
            pw.Center(
              child: pw.Text(
                '$birim — Gelir Dağıtımı$taksitEtiket',
                style: kalin(13),
              ),
            ),
            pw.SizedBox(height: 12),
            _pdfSatir(
              'Matrah (KDV Hariç)',
              TurkceFormat.para(k.kdvHaricMatrah),
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              'Hazine Payı',
              TurkceFormat.para(k.hazinePayi),
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              'BAP Payı',
              TurkceFormat.para(k.bapPayi),
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              'Araç-Gereç Payı',
              TurkceFormat.para(k.aracGerecPayi),
              normal: normal,
              bold: kalin,
            ),
            _pdfSatir(
              'Dağıtılabilir',
              TurkceFormat.para(k.dagitilabilirTutar),
              kalin: true,
              normal: normal,
              bold: kalin,
            ),
            pw.SizedBox(height: 12),
            pw.Text('Personel Dağıtımı', style: kalin(10)),
            pw.TableHelper.fromTextArray(
              context: ctx,
              headers: const [
                'Ad Soyad',
                'Unvan',
                'Puan',
                'Brüt',
                'Net Ödenen',
              ],
              data: sonuc.dagitimlar
                  .map(
                    (d) => [
                      d.adSoyad,
                      d.unvan,
                      d.bireyselPuan.toStringAsFixed(0),
                      TurkceFormat.para(d.brutHakedis),
                      TurkceFormat.para(d.odenebilirHakedis ?? d.brutHakedis),
                    ],
                  )
                  .toList(),
              headerStyle: kalin(8),
              cellStyle: normal(8),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Dönem Katsayı: ${TurkceFormat.katsayi(sonuc.katsayi)} · Artık: ${TurkceFormat.para(sonuc.artikBakiye)}',
              style: normal(9),
            ),
          ],
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _pdfSatir(
    String etiket,
    String deger, {
    bool kalin = false,
    required pw.TextStyle Function(double) normal,
    required pw.TextStyle Function(double) bold,
  }) {
    final st = kalin ? bold(10) : normal(10);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(etiket, style: st)),
          pw.Text(deger, style: st),
        ],
      ),
    );
  }
}
