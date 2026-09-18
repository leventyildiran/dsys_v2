import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/turkce_format.dart';
import '../../birim/models/birim_model.dart';
import '../models/beyanname_model.dart';
import '../providers/beyanname_provider.dart';

/// İlgili Aya Özel Resmi Konsolide Beyanname & Sayfa Bazlı Raporlama Servisi
class BeyannameRaporServisi {
  BeyannameRaporServisi._();

  static const List<String> _ayAdlari = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  static const List<String> _tabAdlari = [
    'KONSOLIDE_OZET',
    'BIRIM_BAZLI_VERGILER',
    'KDV1_MASASI',
    'KDV2_TEVKIFAT',
    'MUHTASAR_BORDRO',
    'DAMGA_VERGISI',
    '600_HASILAT_123',
  ];

  /// Seçili tabın (masanın) kurumsal PDF raporunu tarayıcı yazdırma/indirme penceresinde açar.
  static Future<void> sayfaRaporuYazdir(
    BuildContext context,
    BeyannameProvider provider,
    int tabIndex,
  ) async {
    final pdfData = await sayfaRaporuPdfUret(provider, tabIndex);
    final ayAd = _ayAdlari[provider.seciliAy - 1].toUpperCase();
    final tabTag = (tabIndex >= 0 && tabIndex < _tabAdlari.length)
        ? _tabAdlari[tabIndex]
        : 'RAPOR';
    final dosyaAdi = 'BEYANNAME_${provider.seciliYil}_${ayAd}_$tabTag.pdf';

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdfData,
      name: dosyaAdi,
    );
  }

  /// Seçili tabın PDF verisini üretir.
  static Future<Uint8List> sayfaRaporuPdfUret(
    BeyannameProvider provider,
    int tabIndex,
  ) async {
    switch (tabIndex) {
      case 0:
        return aylikRaporPdfUret(provider);
      case 1:
        return birimIcmalRaporPdfUret(provider);
      case 2:
        return kdv1RaporPdfUret(provider);
      case 3:
        return tevkifatRaporPdfUret(provider);
      case 4:
        return muhtasarRaporPdfUret(provider);
      case 5:
        return damgaRaporPdfUret(provider);
      case 6:
        return hasilat600RaporPdfUret(provider);
      default:
        return aylikRaporPdfUret(provider);
    }
  }

  /// Seçili ayın kurumsal konsolide PDF raporunu üretip tarayıcı yazdırma/indirme penceresinde açar.
  static Future<void> aylikRaporuYazdir(BuildContext context, BeyannameProvider provider) async {
    await sayfaRaporuYazdir(context, provider, 0);
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

  static pw.Widget _imzaBloklari() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _imzaBloku('Hazırlayan / Düzenleyen', 'Gelir & Vergi Tahakkuk Servisi'),
        _imzaBloku('Kontrol Eden', 'Muhasebe Yetkilisi'),
        _imzaBloku('Onaylayan', 'Döner Sermaye İşletme Müdürü'),
      ],
    );
  }

  static pw.Widget _ustKurumsalBaslik({
    required String raporBasligi,
    String? altBaslik,
    required BeyannameProvider provider,
    required String ayAd,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'T.C. UŞAK ÜNİVERSİTESİ DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ',
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 3),
            pw.Text(
              raporBasligi,
              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            ),
            if (altBaslik != null) ...[
              pw.SizedBox(height: 2),
              pw.Text(
                altBaslik,
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
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
                style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              ),
              pw.Text(
                'Tarih: ${DateTime.now().day}.${DateTime.now().month}.${DateTime.now().year}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 1. BİRİM BAZLI VERGİLER İCMAL CETVELİ
  // =========================================================================
  static Future<Uint8List> birimIcmalRaporPdfUret(BeyannameProvider provider) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final icmaller = provider.birimIcmalListesi;
    final ayAd = _ayAdlari[provider.seciliAy - 1];

    final topKdv1 = icmaller.fold(0.0, (s, x) => s + x.kdv1Tutari);
    final topDamgaVb = icmaller.fold(0.0, (s, x) => s + x.damgaVb);
    final topMuhtasarGelir = icmaller.fold(0.0, (s, x) => s + x.muhtasarGelir);
    final topMuhtasarDamga = icmaller.fold(0.0, (s, x) => s + x.muhtasarDamga);
    final topMuhtasarKesilen = icmaller.fold(0.0, (s, x) => s + x.muhtasarKesilenDamga);
    final topKdv2 = icmaller.fold(0.0, (s, x) => s + x.kdv2Toplam);
    final genelToplam = icmaller.fold(0.0, (s, x) => s + x.genelToplamOdenecek);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            _ustKurumsalBaslik(
              raporBasligi: 'BİRİM BAZLI VERGİ VE TAHAKKUK İCMAL CETVELİ',
              provider: provider,
              ayAd: ayAd,
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.green300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _kpiKutusu(baslik: 'KDV 1 TOPLAMI', tutar: TurkceFormat.para(topKdv1), renk: PdfColors.blue800),
                  _kpiKutusu(baslik: 'DAMGA V.B.', tutar: TurkceFormat.para(topDamgaVb), renk: PdfColors.purple800),
                  _kpiKutusu(baslik: 'MUHTASAR GELİR', tutar: TurkceFormat.para(topMuhtasarGelir), renk: PdfColors.teal800),
                  _kpiKutusu(baslik: 'MUHTASAR KESİLEN DAMGA', tutar: TurkceFormat.para(topMuhtasarKesilen), renk: PdfColors.indigo800),
                  _kpiKutusu(baslik: 'KDV 2 TEVKİFAT TOPLAM', tutar: TurkceFormat.para(topKdv2), renk: PdfColors.amber900),
                  _kpiKutusu(baslik: 'GENEL ÖDENECEK TOPLAM', tutar: TurkceFormat.para(genelToplam), renk: PdfColors.red900, isBold: true),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(3.0),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(1.1),
                3: pw.FlexColumnWidth(1.2),
                4: pw.FlexColumnWidth(1.1),
                5: pw.FlexColumnWidth(1.2),
                6: pw.FlexColumnWidth(1.2),
                7: pw.FlexColumnWidth(1.4),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _th('BİRİMLER', align: pw.TextAlign.left),
                    _th('KDV 1'),
                    _th('DAMGA V.B.'),
                    _th('MUHTASAR GELİR'),
                    _th('MUHTASAR DAMGA'),
                    _th('KESİLEN DAMGA (301)'),
                    _th('KDV 2 TEVKİFAT'),
                    _th('TOPLAM ÖDENECEK'),
                  ],
                ),
                ...icmaller.map((b) {
                  final kisaAd = BirimAdlandirma.kisaAdGetir(b.birimAdi);
                  final tamAd = BirimAdlandirma.tamAdGetir(b.birimAdi);
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(kisaAd, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text(tamAd, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600), maxLines: 1),
                          ],
                        ),
                      ),
                      _td(TurkceFormat.para(b.kdv1Tutari)),
                      _td(TurkceFormat.para(b.damgaVb)),
                      _td(TurkceFormat.para(b.muhtasarGelir)),
                      _td(TurkceFormat.para(b.muhtasarDamga)),
                      _td(TurkceFormat.para(b.muhtasarKesilenDamga)),
                      _td(TurkceFormat.para(b.kdv2Toplam)),
                      _td(TurkceFormat.para(b.genelToplamOdenecek), isBold: true, renk: PdfColors.blue900),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.green50),
                  children: [
                    _td('GENEL TOPLAMLAR', isBold: true, align: pw.TextAlign.left, renk: PdfColors.green900),
                    _td(TurkceFormat.para(topKdv1), isBold: true),
                    _td(TurkceFormat.para(topDamgaVb), isBold: true),
                    _td(TurkceFormat.para(topMuhtasarGelir), isBold: true),
                    _td(TurkceFormat.para(topMuhtasarDamga), isBold: true),
                    _td(TurkceFormat.para(topMuhtasarKesilen), isBold: true),
                    _td(TurkceFormat.para(topKdv2), isBold: true),
                    _td(TurkceFormat.para(genelToplam), isBold: true, renk: PdfColors.red900),
                  ],
                ),
              ],
            ),
            pw.Spacer(),
            _imzaBloklari(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // 2. KDV 1 MASASI RAPORU (HESAPLANAN & İNDİRİLECEK DENGESİ)
  // =========================================================================
  static Future<Uint8List> kdv1RaporPdfUret(BeyannameProvider provider) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final k1 = provider.kdv1Sonuc;
    final ayAd = _ayAdlari[provider.seciliAy - 1];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            _ustKurumsalBaslik(
              raporBasligi: '1 NO.LU KDV BEYANNAMESİ VE BİRİM MATRAH CETVELİ',
              provider: provider,
              ayAd: ayAd,
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.blue300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _kpiKutusu(baslik: 'HESAPLANAN MATRAH', tutar: TurkceFormat.para(k1.matrah10Hesaplanan + k1.matrah20Hesaplanan), renk: PdfColors.blue900),
                  _kpiKutusu(baslik: 'HESAPLANAN KDV', tutar: TurkceFormat.para(k1.toplamHesaplananKdv), renk: PdfColors.blue800),
                  _kpiKutusu(baslik: 'İNDİRİLECEK MATRAH', tutar: TurkceFormat.para(k1.matrah10Indirilecek + k1.matrah20Indirilecek), renk: PdfColors.indigo900),
                  _kpiKutusu(baslik: 'İNDİRİLECEK KDV', tutar: TurkceFormat.para(k1.toplamIndirilecekKdv), renk: PdfColors.indigo800),
                  _kpiKutusu(baslik: 'ÖNCEKİ DEVREDEN KDV', tutar: TurkceFormat.para(k1.oncekiDonemdenDevredenKdv), renk: PdfColors.grey800),
                  _kpiKutusu(
                    baslik: k1.sonrakiDonemeDevredenKdv > 0 ? 'DEVREDEN KDV' : 'ÖDENECEK KDV 1',
                    tutar: TurkceFormat.para(k1.sonrakiDonemeDevredenKdv > 0 ? k1.sonrakiDonemeDevredenKdv : k1.odenecekKdv1),
                    renk: k1.sonrakiDonemeDevredenKdv > 0 ? PdfColors.amber900 : PdfColors.red900,
                    isBold: true,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(2.5),
                1: pw.FlexColumnWidth(1.2),
                2: pw.FlexColumnWidth(1.1),
                3: pw.FlexColumnWidth(1.1),
                4: pw.FlexColumnWidth(1.1),
                5: pw.FlexColumnWidth(1.1),
                6: pw.FlexColumnWidth(1.3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue100),
                  children: [
                    _th('BİRİM ADI', align: pw.TextAlign.left),
                    _th('TOPLAM MATRAH'),
                    _th('HESAPLANAN %10'),
                    _th('HESAPLANAN %20'),
                    _th('İNDİRİLECEK %10'),
                    _th('İNDİRİLECEK %20'),
                    _th('NET KDV DENGESİ'),
                  ],
                ),
                ...provider.kdv1Satirlari.map((s) {
                  final kisaAd = BirimAdlandirma.kisaAdGetir(s.birimAdi);
                  final tamAd = BirimAdlandirma.tamAdGetir(s.birimAdi);
                  final netKdv = s.toplamHesaplananKdv - s.toplamIndirilecekKdv;

                  return pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(kisaAd, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text(tamAd, style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600), maxLines: 1),
                          ],
                        ),
                      ),
                      _td(TurkceFormat.para(s.toplamHesaplananMatrah), isBold: true, renk: PdfColors.blue900),
                      _td(TurkceFormat.para(s.hesaplananKdv10)),
                      _td(TurkceFormat.para(s.hesaplananKdv20)),
                      _td(TurkceFormat.para(s.indirilecekKdv10)),
                      _td(TurkceFormat.para(s.indirilecekKdv20)),
                      _td(
                        netKdv < 0 ? '(-) ${TurkceFormat.para(netKdv.abs())}' : TurkceFormat.para(netKdv),
                        isBold: true,
                        renk: netKdv >= 0 ? PdfColors.blue900 : PdfColors.amber900,
                      ),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.blue50),
                  children: [
                    _td('TOPLAMLAR', isBold: true, align: pw.TextAlign.left, renk: PdfColors.blue900),
                    _td(TurkceFormat.para(k1.matrah10Hesaplanan + k1.matrah20Hesaplanan), isBold: true, renk: PdfColors.blue900),
                    _td(TurkceFormat.para(provider.kdv1Satirlari.fold(0.0, (s, x) => s + x.hesaplananKdv10)), isBold: true),
                    _td(TurkceFormat.para(provider.kdv1Satirlari.fold(0.0, (s, x) => s + x.hesaplananKdv20)), isBold: true),
                    _td(TurkceFormat.para(provider.kdv1Satirlari.fold(0.0, (s, x) => s + x.indirilecekKdv10)), isBold: true),
                    _td(TurkceFormat.para(provider.kdv1Satirlari.fold(0.0, (s, x) => s + x.indirilecekKdv20)), isBold: true),
                    _td(TurkceFormat.para(k1.odenecekKdv1), isBold: true, renk: PdfColors.red900),
                  ],
                ),
              ],
            ),
            pw.Spacer(),
            _imzaBloklari(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // 3. KDV 2 TEVKİFATLI FATURA & FİRMA CETVELİ
  // =========================================================================
  static Future<Uint8List> tevkifatRaporPdfUret(BeyannameProvider provider) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final k2 = provider.kdv2Sonuc;
    final ayAd = _ayAdlari[provider.seciliAy - 1];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            _ustKurumsalBaslik(
              raporBasligi: '2 NO.LU KDV TEVKİFATLI ALIMLAR VE KESİNTİLER CETVELİ',
              provider: provider,
              ayAd: ayAd,
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.amber300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _kpiKutusu(
                    baslik: '9/10 TEVKİFATLAR',
                    tutar: TurkceFormat.para(k2.turTevkifatToplam[TevkifatTuru.dokuzBoluOn.etiket] ?? 0),
                    renk: PdfColors.amber900,
                  ),
                  _kpiKutusu(
                    baslik: '7/10 TEVKİFATLAR',
                    tutar: TurkceFormat.para(k2.turTevkifatToplam[TevkifatTuru.yediBoluOn.etiket] ?? 0),
                    renk: PdfColors.amber800,
                  ),
                  _kpiKutusu(
                    baslik: '5/10 TEVKİFATLAR',
                    tutar: TurkceFormat.para(k2.turTevkifatToplam[TevkifatTuru.besBoluOn.etiket] ?? 0),
                    renk: PdfColors.orange900,
                  ),
                  _kpiKutusu(
                    baslik: 'GENEL TEVKİFAT TOPLAMI',
                    tutar: TurkceFormat.para(k2.butunTevkifatlarToplami),
                    renk: PdfColors.red900,
                    isBold: true,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.6),
                1: pw.FlexColumnWidth(3.0),
                2: pw.FlexColumnWidth(1.3),
                3: pw.FlexColumnWidth(1.4),
                4: pw.FlexColumnWidth(1.2),
                5: pw.FlexColumnWidth(1.3),
                6: pw.FlexColumnWidth(1.3),
                7: pw.FlexColumnWidth(1.4),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.amber100),
                  children: [
                    _th('SIRA'),
                    _th('FİRMA / KİŞİ ADI', align: pw.TextAlign.left),
                    _th('VERGİ / TC NO'),
                    _th('BİRİM'),
                    _th('TÜR / ORAN'),
                    _th('MATRAH'),
                    _th('KDV TUTARI'),
                    _th('TEVKİFAT'),
                  ],
                ),
                ...provider.tevkifatKayitlari.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final f = entry.value;
                  final birimKisa = f.birimAdi != null && f.birimAdi!.isNotEmpty
                      ? BirimAdlandirma.kisaAdGetir(f.birimAdi)
                      : '-';

                  return pw.TableRow(
                    children: [
                      _td('$idx', align: pw.TextAlign.center),
                      _td(f.firmaAdi, isBold: true, align: pw.TextAlign.left),
                      _td(f.vergiTcNo),
                      _td(birimKisa),
                      _td('${f.etiket} (%${f.kdvOrani})', align: pw.TextAlign.center),
                      _td(TurkceFormat.para(f.matrahTutari)),
                      _td(TurkceFormat.para(f.kdvTutari)),
                      _td(TurkceFormat.para(f.tevkifatTutari), isBold: true, renk: PdfColors.amber900),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.amber50),
                  children: [
                    _td('', align: pw.TextAlign.center),
                    _td('GENEL TOPLAMLAR', isBold: true, align: pw.TextAlign.left, renk: PdfColors.amber900),
                    _td(''),
                    _td(''),
                    _td(''),
                    _td(TurkceFormat.para(provider.tevkifatKayitlari.fold(0.0, (s, x) => s + x.matrahTutari)), isBold: true),
                    _td(TurkceFormat.para(provider.tevkifatKayitlari.fold(0.0, (s, x) => s + x.kdvTutari)), isBold: true),
                    _td(TurkceFormat.para(k2.butunTevkifatlarToplami), isBold: true, renk: PdfColors.red900),
                  ],
                ),
              ],
            ),
            pw.Spacer(),
            _imzaBloklari(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // 4. MUHTASAR VE PRİM HİZMET BORDRO RAPORU
  // =========================================================================
  static Future<Uint8List> muhtasarRaporPdfUret(BeyannameProvider provider) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final m = provider.muhtasarSonuc;
    final ayAd = _ayAdlari[provider.seciliAy - 1];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            _ustKurumsalBaslik(
              raporBasligi: 'AYLIK MUHTASAR VE PRİM HİZMET BORDRO CETVELİ',
              provider: provider,
              ayAd: ayAd,
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.green50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.green300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _kpiKutusu(baslik: 'KİŞİ SAYISI', tutar: '${m.toplamKisiSayisi}', renk: PdfColors.grey900),
                  _kpiKutusu(baslik: 'BRÜT ÜCRET', tutar: TurkceFormat.para(m.toplamBrutUcret), renk: PdfColors.green900),
                  _kpiKutusu(baslik: 'GV MATRAHI', tutar: TurkceFormat.para(m.toplamAylikGvMatrahi), renk: PdfColors.teal900),
                  _kpiKutusu(baslik: 'GELİR VERGİSİ', tutar: TurkceFormat.para(m.toplamGelirVergisi), renk: PdfColors.red800),
                  _kpiKutusu(baslik: 'DAMGA VERGİSİ (302)', tutar: TurkceFormat.para(m.toplamDamgaVergisi), renk: PdfColors.purple800),
                  _kpiKutusu(baslik: 'KESİLEN DAMGA (301)', tutar: TurkceFormat.para(m.muhtasarKesilenDamgaVergisi301), renk: PdfColors.indigo800),
                  _kpiKutusu(baslik: 'NET ÖDENEN', tutar: TurkceFormat.para(m.toplamNetOdenen), renk: PdfColors.blue900, isBold: true),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.6),
                1: pw.FlexColumnWidth(2.2),
                2: pw.FlexColumnWidth(2.5),
                3: pw.FlexColumnWidth(0.8),
                4: pw.FlexColumnWidth(1.3),
                5: pw.FlexColumnWidth(1.3),
                6: pw.FlexColumnWidth(1.2),
                7: pw.FlexColumnWidth(1.2),
                8: pw.FlexColumnWidth(1.3),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.green100),
                  children: [
                    _th('SIRA'),
                    _th('BİRİM', align: pw.TextAlign.left),
                    _th('PERSONEL AD SOYAD', align: pw.TextAlign.left),
                    _th('KİŞİ'),
                    _th('BRÜT ÜCRET'),
                    _th('GV MATRAHI'),
                    _th('GELİR VERGİSİ'),
                    _th('DAMGA VERGİSİ'),
                    _th('NET ÖDENEN'),
                  ],
                ),
                ...provider.muhtasarSatirlari.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final p = entry.value;
                  final kisaBirim = BirimAdlandirma.kisaAdGetir(p.birimAdi);

                  return pw.TableRow(
                    children: [
                      _td('$idx', align: pw.TextAlign.center),
                      _td(kisaBirim, align: pw.TextAlign.left),
                      _td(p.adSoyad.isNotEmpty ? p.adSoyad : '-', isBold: true, align: pw.TextAlign.left),
                      _td('${p.kisiSayisi}', align: pw.TextAlign.center),
                      _td(TurkceFormat.para(p.brutUcret)),
                      _td(TurkceFormat.para(p.aylikGelirVergisiMatrahi)),
                      _td(TurkceFormat.para(p.gelirVergisi)),
                      _td(TurkceFormat.para(p.damgaVergisi)),
                      _td(TurkceFormat.para(p.netOdenen), isBold: true, renk: PdfColors.green900),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.green50),
                  children: [
                    _td('', align: pw.TextAlign.center),
                    _td('TOPLAMLAR', isBold: true, align: pw.TextAlign.left, renk: PdfColors.green900),
                    _td(''),
                    _td('${m.toplamKisiSayisi}', isBold: true, align: pw.TextAlign.center),
                    _td(TurkceFormat.para(m.toplamBrutUcret), isBold: true),
                    _td(TurkceFormat.para(m.toplamAylikGvMatrahi), isBold: true),
                    _td(TurkceFormat.para(m.toplamGelirVergisi), isBold: true),
                    _td(TurkceFormat.para(m.toplamDamgaVergisi), isBold: true),
                    _td(TurkceFormat.para(m.toplamNetOdenen), isBold: true, renk: PdfColors.green900),
                  ],
                ),
              ],
            ),
            pw.Spacer(),
            _imzaBloklari(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // 5. 360.03.05 DAMGA VERGİSİ MASASI RAPORU (BİNDE 9,48)
  // =========================================================================
  static Future<Uint8List> damgaRaporPdfUret(BeyannameProvider provider) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final ayAd = _ayAdlari[provider.seciliAy - 1];
    final topDamga = provider.damgaSatirlari.fold(0.0, (s, x) => s + x.damgaVergisi);
    final topMatrah = provider.damgaSatirlari.fold(0.0, (s, x) => s + x.matrah);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            _ustKurumsalBaslik(
              raporBasligi: '360.03.05 DAMGA VERGİSİ TAHAKKUK CETVELİ',
              altBaslik: 'Binde 9,48 İhale / Sözleşme Damga Vergisi Ters Matrah Hesabı',
              provider: provider,
              ayAd: ayAd,
            ),
            pw.SizedBox(height: 12),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.purple50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.purple300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _kpiKutusu(
                    baslik: 'MİZAN DAMGA VERGİSİ TOPLAMI',
                    tutar: TurkceFormat.para(topDamga),
                    renk: PdfColors.purple900,
                    isBold: true,
                  ),
                  _kpiKutusu(
                    baslik: 'HESAPLANAN MATRAH (DAMGA * 1000 / 9,48)',
                    tutar: TurkceFormat.para(topMatrah),
                    renk: PdfColors.blue900,
                    isBold: true,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.8),
                1: pw.FlexColumnWidth(3.5),
                2: pw.FlexColumnWidth(2.0),
                3: pw.FlexColumnWidth(2.2),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.purple100),
                  children: [
                    _th('SIRA'),
                    _th('BİRİM ADI', align: pw.TextAlign.left),
                    _th('DAMGA VERGİSİ (TL)'),
                    _th('HESAPLANAN MATRAH (TL)'),
                  ],
                ),
                ...provider.damgaSatirlari.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final d = entry.value;
                  final kisaAd = BirimAdlandirma.kisaAdGetir(d.birimAdi);

                  return pw.TableRow(
                    children: [
                      _td('$idx', align: pw.TextAlign.center),
                      _td(kisaAd, isBold: true, align: pw.TextAlign.left),
                      _td(TurkceFormat.para(d.damgaVergisi)),
                      _td(TurkceFormat.para(d.matrah), isBold: true, renk: PdfColors.purple900),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.purple50),
                  children: [
                    _td('', align: pw.TextAlign.center),
                    _td('GENEL TOPLAMLAR', isBold: true, align: pw.TextAlign.left, renk: PdfColors.purple900),
                    _td(TurkceFormat.para(topDamga), isBold: true),
                    _td(TurkceFormat.para(topMatrah), isBold: true, renk: PdfColors.purple900),
                  ],
                ),
              ],
            ),
            pw.Spacer(),
            _imzaBloklari(),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // =========================================================================
  // 6. 600 HASILAT VE 123 KREDİ KARTI RAPORU
  // =========================================================================
  static Future<Uint8List> hasilat600RaporPdfUret(BeyannameProvider provider) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    final ayAd = _ayAdlari[provider.seciliAy - 1];
    final prevMonthName = provider.seciliAy > 1 ? _ayAdlari[provider.seciliAy - 2] : 'Yok';

    final topOnceki = provider.hasiat600Satirlari.fold(0.0, (s, x) => s + x.oncekiAylarHasilat600);
    final topAylik = provider.hasiat600Satirlari.fold(0.0, (s, x) => s + x.aylikHasilat600);
    final topKumulatif = provider.hasiat600Satirlari.fold(0.0, (s, x) => s + x.kumulatifHasilat600);
    final topPos = provider.hasiat600Satirlari.fold(0.0, (s, x) => s + x.krediKarti123);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
        build: (pw.Context context) {
          return [
            _ustKurumsalBaslik(
              raporBasligi: '600 GELİR HESABI VE 123 KREDİ KARTI SATIŞLARI CETVELİ',
              altBaslik: 'Ocak-$prevMonthName Dönemleri Kümülatif Takibi ve POS Satış Dengesi',
              provider: provider,
              ayAd: ayAd,
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.cyan50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: PdfColors.cyan300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _kpiKutusu(baslik: 'ÖNCEKİ DÖNEMLER 600', tutar: TurkceFormat.para(topOnceki), renk: PdfColors.grey800),
                  _kpiKutusu(baslik: 'BU AYKİ 600 HASILAT', tutar: TurkceFormat.para(topAylik), renk: PdfColors.teal900),
                  _kpiKutusu(baslik: 'TOPLAM KÜMÜLATİF 600', tutar: TurkceFormat.para(topKumulatif), renk: PdfColors.blue900, isBold: true),
                  _kpiKutusu(baslik: '123 KREDİ KARTI / POS', tutar: TurkceFormat.para(topPos), renk: PdfColors.indigo900, isBold: true),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
              columnWidths: const {
                0: pw.FlexColumnWidth(0.6),
                1: pw.FlexColumnWidth(3.0),
                2: pw.FlexColumnWidth(1.8),
                3: pw.FlexColumnWidth(1.8),
                4: pw.FlexColumnWidth(2.0),
                5: pw.FlexColumnWidth(2.0),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.cyan100),
                  children: [
                    _th('SIRA'),
                    _th('GELİR SAĞLAYAN BİRİM', align: pw.TextAlign.left),
                    _th('ÖNCEKİ DÖNEMLER (600)'),
                    _th('BU AYKİ GELİR (600)'),
                    _th('TOPLAM KÜMÜLATİF (600)'),
                    _th('123 KREDİ KARTI / POS'),
                  ],
                ),
                ...provider.hasiat600Satirlari.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final h = entry.value;
                  final kisaAd = BirimAdlandirma.kisaAdGetir(h.birimAdi);

                  return pw.TableRow(
                    children: [
                      _td('$idx', align: pw.TextAlign.center),
                      _td(kisaAd, isBold: true, align: pw.TextAlign.left),
                      _td(TurkceFormat.para(h.oncekiAylarHasilat600)),
                      _td(TurkceFormat.para(h.aylikHasilat600)),
                      _td(TurkceFormat.para(h.kumulatifHasilat600), isBold: true, renk: PdfColors.blue900),
                      _td(TurkceFormat.para(h.krediKarti123), isBold: true, renk: PdfColors.indigo900),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.cyan50),
                  children: [
                    _td('', align: pw.TextAlign.center),
                    _td('GENEL TOPLAMLAR', isBold: true, align: pw.TextAlign.left, renk: PdfColors.teal900),
                    _td(TurkceFormat.para(topOnceki), isBold: true),
                    _td(TurkceFormat.para(topAylik), isBold: true),
                    _td(TurkceFormat.para(topKumulatif), isBold: true, renk: PdfColors.blue900),
                    _td(TurkceFormat.para(topPos), isBold: true, renk: PdfColors.indigo900),
                  ],
                ),
              ],
            ),
            pw.Spacer(),
            _imzaBloklari(),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
