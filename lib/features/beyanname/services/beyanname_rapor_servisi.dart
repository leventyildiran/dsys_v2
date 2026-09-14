import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/turkce_format.dart';
import '../../birim/models/birim_model.dart';
import '../providers/beyanname_provider.dart';

/// İlgili Aya Özel Resmi Konsolide Beyanname & Tahakkuk Raporlama Servisi
class BeyannameRaporServisi {
  BeyannameRaporServisi._();

  static const List<String> _ayAdlari = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  /// Seçili ayın kurumsal PDF raporunu üretip tarayıcı yazdırma/indirme penceresinde açar.
  static Future<void> aylikRaporuYazdir(BuildContext context, BeyannameProvider provider) async {
    final pdfData = await aylikRaporPdfUret(provider);
    final ayAd = _ayAdlari[provider.seciliAy - 1].toUpperCase();
    final dosyaAdi = 'BEYANNAME_${provider.seciliYil}_$ayAd.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: dosyaAdi,
    );
  }

  /// Seçili aya özel tam teşekküllü resmi PDF belgesi üretir
  static Future<Uint8List> aylikRaporPdfUret(BeyannameProvider provider) async {
    final pdf = pw.Document();

    // Türkçe karakter destekli fontlar
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final k1 = provider.kdv1Sonuc;
    final k2 = provider.kdv2Sonuc;
    final m = provider.muhtasarSonuc;
    final icmaller = provider.birimIcmalListesi;
    final ayAd = _ayAdlari[provider.seciliAy - 1];

    final genelOdenecekKdv1 = k1.odenecekKdv1;
    final genelTevkifatKdv2 = k2.butunTevkifatlarToplami;
    final genelMuhtasarGv = m.toplamGelirVergisi;
    final genelMuhtasarDv = m.toplamDamgaVergisi;
    final genelDamga301 = m.muhtasarKesilenDamgaVergisi301;

    final toplamVergiTahakkuku = genelOdenecekKdv1 +
        genelTevkifatKdv2 +
        genelMuhtasarGv +
        genelMuhtasarDv +
        genelDamga301;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
        build: (pw.Context context) {
          return [
            // ==================== 1. KURUMSAL BAŞLIK ====================
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'T.C. UŞAK ÜNİVERSİTESİ DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ',
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                    ),
                    pw.SizedBox(height: 3),
                    pw.Text(
                      'AYLIK BİRİM VERGİ VE BEYANNAME TAHAKKUK İCMAL RAPORU',
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.blue50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                    border: pw.Border.all(color: PdfColors.blue300),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'DÖNEM: $ayAd ${provider.seciliYil}',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                      ),
                      pw.Text(
                        'Rapor Tarihi: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}',
                        style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 12),

            // ==================== 2. KONSOLİDE YÖNETİCİ KPI ÖZETİ ====================
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _kpiKutusu(
                    baslik: 'ÖDENECEK KDV 1',
                    tutar: TurkceFormat.para(genelOdenecekKdv1),
                    renk: PdfColors.blue800,
                  ),
                  _kpiKutusu(
                    baslik: 'KDV 2 TEVKİFAT',
                    tutar: TurkceFormat.para(genelTevkifatKdv2),
                    renk: PdfColors.amber900,
                  ),
                  _kpiKutusu(
                    baslik: 'MUHTASAR (GV+DV)',
                    tutar: TurkceFormat.para(genelMuhtasarGv + genelMuhtasarDv),
                    renk: PdfColors.green800,
                  ),
                  _kpiKutusu(
                    baslik: '301 KESİLEN DAMGA',
                    tutar: TurkceFormat.para(genelDamga301),
                    renk: PdfColors.purple800,
                  ),
                  _kpiKutusu(
                    baslik: 'GENEL TOPLAM TAHAKKUK',
                    tutar: TurkceFormat.para(toplamVergiTahakkuku),
                    renk: PdfColors.red900,
                    isBold: true,
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // ==================== 3. BİRİM BAZLI VERGİ DAĞILIMI TABLOSU ====================
            pw.Text(
              'BİRİM BAZLI TAHAKKUK VE VERGİ DAĞILIMI TABLOSU',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 4),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(3.0),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(1.2),
                3: pw.FlexColumnWidth(1.2),
                4: pw.FlexColumnWidth(1.2),
                5: pw.FlexColumnWidth(1.2),
                6: pw.FlexColumnWidth(1.4),
              },
              children: [
                // Tablo Başlığı
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th('BİRİM ADI', align: pw.TextAlign.left),
                    _th('KDV 1 NET'),
                    _th('MUHTASAR GV'),
                    _th('MUHTASAR DV'),
                    _th('KESİLEN DAMGA (301)'),
                    _th('KDV 2 TEVKİFAT'),
                    _th('TOPLAM ÖDENECEK'),
                  ],
                ),
                // Birim Satırları
                ...icmaller.map((b) {
                  final kdv1Tutar = b.kdv1Tutari;
                  final muhtasarGv = b.muhtasarGelir;
                  final muhtasarDv = b.muhtasarDamga;
                  final kesilenDamga = b.muhtasarKesilenDamga;
                  final kdv2Toplam = b.kdv2Toplam;
                  final satirToplam = kdv1Tutar + muhtasarGv + muhtasarDv + kesilenDamga + kdv2Toplam;
                  final kisaAd = BirimAdlandirma.kisaAdGetir(b.birimAdi);
                  final tamAd = BirimAdlandirma.tamAdGetir(b.birimAdi);

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              kisaAd,
                              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
                            ),
                            pw.Text(
                              tamAd,
                              style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                              maxLines: 1,
                              overflow: pw.TextOverflow.clip,
                            ),
                          ],
                        ),
                      ),
                      _td(kdv1Tutar < 0 ? '(-) ${TurkceFormat.para(kdv1Tutar.abs())}' : TurkceFormat.para(kdv1Tutar)),
                      _td(TurkceFormat.para(muhtasarGv)),
                      _td(TurkceFormat.para(muhtasarDv)),
                      _td(TurkceFormat.para(kesilenDamga)),
                      _td(TurkceFormat.para(kdv2Toplam)),
                      _td(TurkceFormat.para(satirToplam), isBold: true, renk: PdfColors.blue900),
                    ],
                  );
                }),
                // Genel Toplam Satırı
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    _td('GENEL TOPLAMLAR', isBold: true, align: pw.TextAlign.left, renk: PdfColors.blue900),
                    _td(TurkceFormat.para(icmaller.fold(0.0, (s, x) => s + x.kdv1Tutari)), isBold: true),
                    _td(TurkceFormat.para(icmaller.fold(0.0, (s, x) => s + x.muhtasarGelir)), isBold: true),
                    _td(TurkceFormat.para(icmaller.fold(0.0, (s, x) => s + x.muhtasarDamga)), isBold: true),
                    _td(TurkceFormat.para(icmaller.fold(0.0, (s, x) => s + x.muhtasarKesilenDamga)), isBold: true),
                    _td(TurkceFormat.para(icmaller.fold(0.0, (s, x) => s + x.kdv2Toplam)), isBold: true),
                    _td(TurkceFormat.para(toplamVergiTahakkuku), isBold: true, renk: PdfColors.red900),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 14),

            // ==================== 4. KDV 2 TEVKİFATLI FİRMALAR DÖKÜMÜ (ÖZET) ====================
            if (provider.tevkifatKayitlari.isNotEmpty) ...[
              pw.Text(
                'KDV 2 TEVKİFAT KESİNTİSİ YAPILAN FİRMALAR VE ALIMLAR LİSTESİ',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.amber900),
              ),
              pw.SizedBox(height: 4),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3.0),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(1.5),
                  3: pw.FlexColumnWidth(1.0),
                  4: pw.FlexColumnWidth(1.2),
                  5: pw.FlexColumnWidth(1.2),
                  6: pw.FlexColumnWidth(1.2),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.amber50),
                    children: [
                      _th('FİRMA / KİŞİ ADI', align: pw.TextAlign.left),
                      _th('VERGİ / TC NO'),
                      _th('BİRİM'),
                      _th('TÜR'),
                      _th('MATRAH'),
                      _th('KDV TUTARI'),
                      _th('TEVKİFAT'),
                    ],
                  ),
                  ...provider.tevkifatKayitlari.map((f) {
                    final birimKisa = f.birimAdi != null && f.birimAdi!.isNotEmpty
                        ? BirimAdlandirma.kisaAdGetir(f.birimAdi)
                        : '-';
                    return pw.TableRow(
                      children: [
                        _td(f.firmaAdi, isBold: true, align: pw.TextAlign.left),
                        _td(f.vergiTcNo),
                        _td(birimKisa),
                        _td('${f.etiket} (%${f.kdvOrani})'),
                        _td(TurkceFormat.para(f.matrahTutari)),
                        _td(TurkceFormat.para(f.kdvTutari)),
                        _td(TurkceFormat.para(f.tevkifatTutari), isBold: true, renk: PdfColors.amber900),
                      ],
                    );
                  }),
                ],
              ),
            ],

            pw.Spacer(),

            // ==================== 5. RESMİ İMZA VE ONAY ALANI ====================
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _imzaBloku('Hazırlayan / Düzenleyen', 'Gelir & Vergi Tahakkuk Servisi'),
                _imzaBloku('Kontrol Eden', 'Muhasebe Yetkilisi'),
                _imzaBloku('Onaylayan', 'Döner Sermaye İşletme Müdürü'),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // --- Yardımcı PDF Bileşenleri ---
  static pw.Widget _kpiKutusu({
    required String baslik,
    required String tutar,
    required PdfColor renk,
    bool isBold = false,
  }) {
    return pw.Column(
      children: [
        pw.Text(
          baslik,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          tutar,
          style: pw.TextStyle(
            fontSize: 11.5,
            fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: renk,
          ),
        ),
      ],
    );
  }

  static pw.Widget _th(String metin, {pw.TextAlign align = pw.TextAlign.center}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        metin,
        textAlign: align,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey900),
      ),
    );
  }

  static pw.Widget _td(
    String metin, {
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.right,
    PdfColor? renk,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: pw.Text(
        metin,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: renk ?? PdfColors.grey900,
        ),
      ),
    );
  }

  static pw.Widget _imzaBloku(String unvan, String gorev) {
    return pw.Container(
      width: 170,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Column(
        children: [
          pw.Text(unvan, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
          pw.Text(gorev, style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600)),
          pw.SizedBox(height: 24),
          pw.Text('İmza / Tarih', style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey400)),
        ],
      ),
    );
  }
}
