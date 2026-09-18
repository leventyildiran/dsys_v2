import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/turkce_format.dart';
import 'danismanlik_excel_hesaplama.dart';

/// Manuel hesaplama ekranındaki verileri ve sonuçları temsil eden veri modeli.
class ManuelHesaplamaVerisi {
  const ManuelHesaplamaVerisi({
    required this.kurumAdi,
    required this.rektorlukAdi,
    required this.mudurlukAdi,
    required this.hizmetBasligi,
    required this.satirlar,
    required this.kdvOrani,
    required this.hazineOrani,
    required this.bapOrani,
    required this.aracGerecOrani,
    required this.personeller,
    this.manuelDonemKatsayisi,
    this.memurMaasKatsayisi = 1.387871,
    this.tavanUygula = false,
    this.is58k = false,
    this.is58e = false,
    this.gelirVergisiOrani = 15,
    this.odemeTekSeferde = true,
    this.toplamTaksitSayisi = 3,
    this.aktifTaksitNo = 1,
    this.ozelTaksitTutari,
    this.sozlesmeBaslangicTarihi,
    this.sozlesmeBitisTarihi,
    this.danismanlikDonemi,
    this.danismanlikYapilanAylar,
  });

  final String kurumAdi;
  final String rektorlukAdi;
  final String mudurlukAdi;
  final String hizmetBasligi;
  final List<ManuelListeSatiri> satirlar;
  final int kdvOrani;
  final int hazineOrani;
  final int bapOrani;
  final double aracGerecOrani;
  final List<ExcelPersonelGirdi> personeller;
  final double? manuelDonemKatsayisi;
  final double memurMaasKatsayisi;
  final bool tavanUygula;
  final bool is58k;
  final bool is58e;
  final int gelirVergisiOrani;
  final bool odemeTekSeferde;
  final int toplamTaksitSayisi;
  final int aktifTaksitNo;
  final double? ozelTaksitTutari;
  final DateTime? sozlesmeBaslangicTarihi;
  final DateTime? sozlesmeBitisTarihi;
  final String? danismanlikDonemi;
  final String? danismanlikYapilanAylar;

  static DateTime addMonths(DateTime date, int months) {
    var year = date.year;
    var month = date.month + months;
    while (month > 12) {
      year += 1;
      month -= 12;
    }
    while (month < 1) {
      year -= 1;
      month += 12;
    }
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(year, month, day);
  }

  static String ayAdiYil(DateTime date) {
    const aylar = [
      '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    return '${aylar[date.month]} ${date.year}';
  }

  /// Aktif taksitin geçerli olduğu danışmanlık hizmet dönemi (örn: "24.07.2026 - 24.08.2026")
  String get aktifTaksitTarihAraligi {
    if (danismanlikDonemi != null && danismanlikDonemi!.trim().isNotEmpty) {
      return danismanlikDonemi!.trim();
    }
    if (sozlesmeBaslangicTarihi != null) {
      final start = addMonths(sozlesmeBaslangicTarihi!, aktifTaksitNo - 1);
      final end = addMonths(sozlesmeBaslangicTarihi!, aktifTaksitNo);
      return '${TurkceFormat.tarih(start)} - ${TurkceFormat.tarih(end)}';
    }
    return '';
  }

  /// Tüm sözleşme süresi (örn: "24.07.2026 - 24.10.2026 (3 Ay)")
  String get sozlesmeSuresiMetni {
    if (sozlesmeBaslangicTarihi != null) {
      final bitis = sozlesmeBitisTarihi ?? addMonths(sozlesmeBaslangicTarihi!, toplamTaksitSayisi);
      return '${TurkceFormat.tarih(sozlesmeBaslangicTarihi!)} - ${TurkceFormat.tarih(bitis)} ($toplamTaksitSayisi Ay)';
    }
    return '';
  }

  /// Danışmanlık yapılan aylar (örn: "Temmuz 2026 - Ağustos 2026")
  String get aylarMetni {
    if (danismanlikYapilanAylar != null && danismanlikYapilanAylar!.trim().isNotEmpty) {
      return danismanlikYapilanAylar!.trim();
    }
    if (sozlesmeBaslangicTarihi != null) {
      final start = addMonths(sozlesmeBaslangicTarihi!, aktifTaksitNo - 1);
      final end = addMonths(sozlesmeBaslangicTarihi!, aktifTaksitNo);
      return '${ayAdiYil(start)} - ${ayAdiYil(end)}';
    }
    return '';
  }

  double get toplamTutar => satirlar.fold(0.0, (sum, s) => sum + s.tutar);
  double get kdvHaricGelir => double.parse((toplamTutar / (1 + (kdvOrani / 100))).toStringAsFixed(2));
  double get kdvTutari => double.parse((toplamTutar - kdvHaricGelir).toStringAsFixed(2));

  ExcelKesintiSonuc get kesintiSonuc => DanismanlikExcelHesaplama.kesintiler(
        kdvHaricGelir: kdvHaricGelir,
        hazineOrani: hazineOrani,
        bapOrani: bapOrani,
        aracGerecOrani: aracGerecOrani,
      );

  double get buAykiDagitilacakPay58k {
    if ((!is58k && !is58e) || odemeTekSeferde) return kesintiSonuc.katkiPayi;
    if (ozelTaksitTutari != null && ozelTaksitTutari! > 0) return ozelTaksitTutari!;
    final pay = toplamTaksitSayisi > 0
        ? (kesintiSonuc.katkiPayi / toplamTaksitSayisi)
        : kesintiSonuc.katkiPayi;
    return double.parse(pay.toStringAsFixed(2));
  }

  double get kalanDevredenBakiye58k {
    if ((!is58k && !is58e) || odemeTekSeferde) return 0.0;
    final kalan = kesintiSonuc.katkiPayi - buAykiDagitilacakPay58k;
    return kalan > 0 ? double.parse(kalan.toStringAsFixed(2)) : 0.0;
  }

  DanismanlikExcelSonuc get excelSonuc {
    if (is58k) {
      return DanismanlikExcelHesaplama.hesapla58k(
        kesinti: kesintiSonuc,
        personeller: personeller,
        odenecekTutar: buAykiDagitilacakPay58k,
        kalanBakiye: kalanDevredenBakiye58k,
      );
    }
    if (is58e) {
      return DanismanlikExcelHesaplama.hesapla58e(
        kesinti: kesintiSonuc,
        personeller: personeller,
        odenecekTutar: buAykiDagitilacakPay58k,
        kalanBakiye: kalanDevredenBakiye58k,
        gelirVergisiOrani: gelirVergisiOrani,
        tavanUygula: tavanUygula,
        memurMaasKatsayisi: memurMaasKatsayisi,
      );
    }
    return DanismanlikExcelHesaplama.hesapla(
      kesinti: kesintiSonuc,
      personeller: personeller,
      manualDonemKatsayi: manuelDonemKatsayisi,
      memurMaasKatsayisi: memurMaasKatsayisi,
      tavanUygula: tavanUygula,
    );
  }
}

class ManuelListeSatiri {
  ManuelListeSatiri({
    required this.sn,
    this.tc = '',
    this.aciklama = '',
    this.tutar = 0.0,
  });

  int sn;
  String tc;
  String aciklama;
  double tutar;

  ManuelListeSatiri copyWith({
    int? sn,
    String? tc,
    String? aciklama,
    double? tutar,
  }) {
    return ManuelListeSatiri(
      sn: sn ?? this.sn,
      tc: tc ?? this.tc,
      aciklama: aciklama ?? this.aciklama,
      tutar: tutar ?? this.tutar,
    );
  }

  Map<String, dynamic> toMap() => {
    'sn': sn,
    'tc': tc,
    'aciklama': aciklama,
    'tutar': tutar,
  };

  factory ManuelListeSatiri.fromMap(Map<String, dynamic> map) => ManuelListeSatiri(
    sn: map['sn'] as int? ?? 1,
    tc: map['tc'] as String? ?? '',
    aciklama: map['aciklama'] as String? ?? '',
    tutar: (map['tutar'] as num?)?.toDouble() ?? 0.0,
  );
}

/// Manuel hesaplama sayfalarını ve özetini yazdırılabilir PDF'e dönüştüren servis.
class ManuelHesaplamaPdfServisi {
  ManuelHesaplamaPdfServisi._();

  static Future<Uint8List> pdfUret(ManuelHesaplamaVerisi veri) async {
    final pdf = pw.Document();
    final fontRegular = await PdfGoogleFonts.tinosRegular();
    final fontBold = await PdfGoogleFonts.tinosBold();

    pw.TextStyle normal(double size) => pw.TextStyle(font: fontRegular, fontSize: size);
    pw.TextStyle kalin(double size) => pw.TextStyle(font: fontBold, fontSize: size);

    final kesinti = veri.kesintiSonuc;
    final excel = veri.excelSonuc;

    // ─────────────────────────────────────────────────────────────
    // SAYFA 1: HESAPLAMA ÖZETİ (YÖNETİM VE İCMAL FORMU)
    // ─────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => [
          _baslikAlani(veri, kalin, normal),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            decoration: pw.BoxDecoration(
              color: PdfColors.blueGrey800,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Center(
              child: pw.Text(
                'DANIŞMANLIK / KURS GELİR DAĞITIM VE HESAPLAMA İCMAL ÖZETİ',
                style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.white),
              ),
            ),
          ),
          pw.SizedBox(height: 14),

          // Özet 2 Kolon Grid
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Sol Kolon: Gelir ve Paylar
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('1. GELİR VE KESİNTİ TABLOSU', style: kalin(10)),
                      pw.Divider(thickness: 0.5),
                      _pdfSatir('Toplam Tahsilat (KDV Dahil)', TurkceFormat.para(veri.toplamTutar), kalin: true, normal: normal, bold: kalin),
                      _pdfSatir('KDV Oranı & Tutarı', '%${veri.kdvOrani}  (${TurkceFormat.para(veri.kdvTutari)})', normal: normal, bold: kalin),
                      _pdfSatir('GELİR (KDV Hariç Matrah)', TurkceFormat.para(kesinti.kdvHaricGelir), kalin: true, normal: normal, bold: kalin),
                      pw.SizedBox(height: 6),
                      pw.Text('Aktarılacak Yasal Paylar:', style: kalin(9)),
                      _pdfSatir('• Hazine Payı (%${veri.hazineOrani})', TurkceFormat.para(kesinti.hazinePayi), normal: normal, bold: kalin),
                      _pdfSatir('• BAP Payı (%${veri.bapOrani})', TurkceFormat.para(kesinti.bapPayi), normal: normal, bold: kalin),
                      _pdfSatir('• Araç Gereç Payı (%${(veri.aracGerecOrani * 100).toStringAsFixed(0)})', TurkceFormat.para(kesinti.aracGerecPayi), normal: normal, bold: kalin),
                      pw.Divider(thickness: 0.5),
                      _pdfSatir('Dağıtılabilir Katkı Payı', TurkceFormat.para(kesinti.katkiPayi), kalin: true, normal: normal, bold: kalin),
                      _pdfSatir('Maks. Akademik Pay (%49)', TurkceFormat.para(kesinti.dagMaksAkademikPay), normal: normal, bold: kalin),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 14),
              // Sağ Kolon: Katsayı ve Dağıtım Sonuçları (58/k ise Sözleşmeli Taksit Dağıtımı)
              pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(veri.is58k
                          ? '2. SÖZLEŞME & TAKSİT İCMALİ (58/k)'
                          : (veri.is58e ? '2. SÖZLEŞME & VERGİ İCMALİ (58/e)' : '2. KATSAYI VE HAKEDİŞ DAĞITIMI'), style: kalin(10)),
                      pw.Divider(thickness: 0.5),
                      if (veri.is58k || veri.is58e) ...[
                        _pdfSatir('Ödeme Şekli', veri.odemeTekSeferde ? 'Tek Seferde Tam Ödeme' : '${veri.toplamTaksitSayisi} Taksitli Ödeme', kalin: true, normal: normal, bold: kalin),
                        if (!veri.odemeTekSeferde) ...[
                          _pdfSatir('Aktif Taksit', '${veri.aktifTaksitNo} / ${veri.toplamTaksitSayisi}. Taksit', normal: normal, bold: kalin),
                          if (veri.aktifTaksitTarihAraligi.isNotEmpty)
                            _pdfSatir('Hizmet Dönemi (Aktif Taksit)', veri.aktifTaksitTarihAraligi, kalin: true, normal: normal, bold: kalin),
                          if (veri.aylarMetni.isNotEmpty)
                            _pdfSatir('Danışmanlık Yapılan Aylar', veri.aylarMetni, normal: normal, bold: kalin),
                          _pdfSatir('Bu Ayki Taksit Tutarı', TurkceFormat.para(veri.buAykiDagitilacakPay58k), kalin: true, normal: normal, bold: kalin),
                          _pdfSatir('Gelecek Aylara Devreden', TurkceFormat.para(veri.kalanDevredenBakiye58k), normal: normal, bold: kalin),
                        ] else ...[
                          if (veri.aktifTaksitTarihAraligi.isNotEmpty)
                            _pdfSatir('Danışmanlık Hizmet Dönemi', veri.aktifTaksitTarihAraligi, kalin: true, normal: normal, bold: kalin),
                          _pdfSatir('Dağıtılabilir Brüt Pay', TurkceFormat.para(kesinti.katkiPayi), kalin: true, normal: normal, bold: kalin),
                        ],
                        if (veri.is58e) ...[
                          _pdfSatir('Gelir Vergisi (Stopaj)', '%${veri.gelirVergisiOrani}', normal: normal, bold: kalin),
                          _pdfSatir('Damga Vergisi', '%0,759', normal: normal, bold: kalin),
                          _pdfSatir('Net Ele Geçecek Tutar', TurkceFormat.para(excel.netOdemeToplam), kalin: true, normal: normal, bold: kalin),
                        ],
                        if (veri.is58k) ...[
                          _pdfSatir('Vergi Muafiyeti', 'Gelir & Damga Vergisi %0 (Muaf)', normal: normal, bold: kalin),
                          _pdfSatir('Tavan Sınırı', 'Uygulanmaz (Tavana Takılmaz)', normal: normal, bold: kalin),
                        ],
                        if (veri.sozlesmeSuresiMetni.isNotEmpty)
                          _pdfSatir('Sözleşme Kapsamı & Süresi', veri.sozlesmeSuresiMetni, normal: normal, bold: kalin),
                      ] else ...[
                        _pdfSatir('Toplam Net Katkı Puanı', excel.toplamPuan.toStringAsFixed(0), kalin: true, normal: normal, bold: kalin),
                        _pdfSatir('Dönem Ek Ödeme Katsayısı', TurkceFormat.katsayi(excel.donemKatsayi), kalin: true, normal: normal, bold: kalin),
                        _pdfSatir('Hesaplama Sağlaması (Puan x Katsayı)', TurkceFormat.para(excel.saglama), normal: normal, bold: kalin),
                        _pdfSatir('Net Ödenecek Hakediş Toplamı', TurkceFormat.para(excel.netOdemeToplam), kalin: true, normal: normal, bold: kalin),
                        _pdfSatir('Artık Bakiye / Birim Havuzu', TurkceFormat.para(excel.artikBakiye), normal: normal, bold: kalin),
                      ],
                      pw.SizedBox(height: 10),
                      pw.Container(
                        padding: const pw.EdgeInsets.all(6),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey100,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Dağıtım Güvence Kontrolü:', style: kalin(8.5)),
                            pw.SizedBox(height: 2),
                            pw.Text(
                              excel.saglama <= kesinti.katkiPayi + 0.01
                                  ? ((veri.is58k || veri.is58e) ? '✓ Dağıtılan tutar hak edilen payı aşmamaktadır.' : '✓ Sağlama tutarı dağıtılabilir payı aşmamaktadır.')
                                  : '⚠ DİKKAT: Dağıtılan tutar hak edilen payı aşmaktadır!',
                              style: pw.TextStyle(
                                font: fontRegular,
                                fontSize: 8,
                                color: excel.saglama <= kesinti.katkiPayi + 0.01 ? PdfColors.green800 : PdfColors.red800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 14),
          pw.Text(veri.is58k ? '3. PERSONEL SÖZLEŞMELİ HAKEDİŞ DETAYI' : (veri.is58e ? '3. PERSONEL HAKEDİŞ VE VERGİ KESİNTİLERİ (58/e)' : '3. PERSONEL HAKEDİŞ VE TAVAN DETAYI'), style: kalin(10)),
          pw.SizedBox(height: 4),

          if (veri.is58k)
            pw.TableHelper.fromTextArray(
              headers: const [
                'Adı Soyadı & Unvanı',
                'Faaliyet / Hizmet',
                'Sözleşme Payı',
                'Puan & Katsayı',
                'Taksit No',
                'Ödenecek Tutar (TL)',
              ],
              data: [
                ...excel.personelSatirlari.map((s) {
                  final p = s.girdi;
                  return [
                    '${p.unvan} ${p.adSoyad}',
                    p.faaliyetTuru,
                    '%100 (Sözleşmeli)',
                    'Muaf (Puan Yok)',
                    veri.odemeTekSeferde ? 'Tek Sefer' : '${veri.aktifTaksitNo}/${veri.toplamTaksitSayisi}',
                    TurkceFormat.para(s.odenebilirHakedis),
                  ];
                }),
              ],
              headerStyle: kalin(8),
              cellStyle: normal(8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            )
          else if (veri.is58e)
            pw.TableHelper.fromTextArray(
              headers: const [
                'Adı Soyadı & Unvanı',
                'Faaliyet / Hizmet',
                'Brüt Hak Ediş',
                'Gelir V. (Stopaj)',
                'Damga V.',
                'Net Ele Geçecek (TL)',
              ],
              data: [
                ...excel.personelSatirlari.map((s) {
                  final p = s.girdi;
                  final brut = s.brutHakedis;
                  final gv = brut * (veri.gelirVergisiOrani / 100);
                  final dv = brut * 0.00759;
                  final net = s.odenebilirHakedis;
                  return [
                    '${p.unvan} ${p.adSoyad}',
                    p.faaliyetTuru,
                    TurkceFormat.para(brut),
                    '%${veri.gelirVergisiOrani} (${TurkceFormat.para(gv)})',
                    TurkceFormat.para(dv),
                    TurkceFormat.para(net),
                  ];
                }),
              ],
              headerStyle: kalin(8),
              cellStyle: normal(8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            )
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Adı Soyadı & Unvanı',
                'Puan',
                'Unvan K.',
                'Saat',
                'Net Katkı Puanı',
                'Saatlik Ücret',
                'Ek Ders Tavanı',
                'Alacağı Tutar (TL)',
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
                    TurkceFormat.para(s.kursSaatlikUcreti),
                    TurkceFormat.para(s.tavanSaatlikUcreti),
                    TurkceFormat.para(s.odenebilirHakedis),
                  ];
                }),
              ],
              headerStyle: kalin(8),
              cellStyle: normal(8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            ),

          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
              border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  veri.is58k
                      ? '2547 Sayılı Kanun Madde 58/k Uyarınca Sözleşmeli Danışmanlık Şerhi:'
                      : '2547 ve 2914 Sayılı Kanunlar Uyarınca 3,2 Katı Yasal Tavan Şerhi:',
                  style: kalin(8),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  veri.is58k
                      ? 'İşbu ödeme, 2547 sayılı Kanun Madde 58/k uyarınca yapılan sanayi/bireysel danışmanlık sözleşmesine istinaden tahakkuk ettirilmiştir. Matrah üzerinden %15 kurum/araç-gereç payı kesildikten sonra kalan %85 tutar doğrudan danışmana ${veri.odemeTekSeferde ? "tek seferde" : "sözleşme taksitlerine bölünerek"} ödenmektedir. Puan hesabı ve saatlik ek ders tavanı aranmaz.'
                      : (excel.herhangiBirTavanAsildi
                          ? 'İşbu hesaplamada yer alan ve hesaplanan saatlik ücreti mesai dışı 3,2 katını (${TurkceFormat.para(excel.maksimumTavanSaatlik)}/Saat) aşan personele yasal tavan uygulanmış; tavanı aşan toplam ${TurkceFormat.para(excel.toplamTavanKesintisi)} tutar döner sermaye birim havuzuna devredilmiştir. Hiçbir personele yasal tavanın üzerinde ödeme yapılmamıştır.'
                          : 'İşbu hesaplama icmalinde yer alan tüm öğretim elemanlarının saatlik ücretleri, 2914 sayılı Kanun uyarınca belirlenen mesai dışı ek ders ücreti tavanı olan 3,2 katını (${TurkceFormat.para(excel.maksimumTavanSaatlik)}/Saat) GEÇMEMİŞTİR. Dağıtım ve ödemeler mevzuata tam uygundur.'),
                  style: normal(7.5),
                ),
              ],
            ),
          ),

          pw.Spacer(),
          // İmza Alanı
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Hazırlayan / Raportör', style: kalin(9)),
                  pw.SizedBox(height: 28),
                  pw.Text('.... / .... / 202...', style: normal(8)),
                  pw.Text('İmza', style: normal(8)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Döner Sermaye İşletme Müdürü', style: kalin(9)),
                  pw.SizedBox(height: 28),
                  pw.Text('.... / .... / 202...', style: normal(8)),
                  pw.Text('İmza', style: normal(8)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text('Harcama Yetkilisi / Onay', style: kalin(9)),
                  pw.SizedBox(height: 28),
                  pw.Text('.... / .... / 202...', style: normal(8)),
                  pw.Text('İmza / Mühür', style: normal(8)),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // ─────────────────────────────────────────────────────────────
    // SAYFA 2: LİSTE (EXCEL LİSTE SEKME KARŞILIĞI)
    // ─────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          _baslikAlani(veri, kalin, normal),
          pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: const pw.BoxDecoration(color: PdfColors.grey300),
            child: pw.Center(
              child: pw.Text('FATURA VE GELİR LİSTESİ', style: kalin(10)),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['S.N', 'T.C. Kimlik No', 'Açıklama', 'Tutar (TL)'],
            data: [
              ...veri.satirlar.map((s) => [
                    s.sn.toString(),
                    s.tc,
                    s.aciklama,
                    TurkceFormat.para(s.tutar),
                  ]),
              [
                '',
                '',
                'T  O  P  L  A  M',
                TurkceFormat.para(veri.toplamTutar),
              ],
            ],
            headerStyle: kalin(9),
            cellStyle: normal(9),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          ),
          pw.SizedBox(height: 14),
          pw.TableHelper.fromTextArray(
            headers: const ['GELİR (KDV Hariç)', '%20 KDV', 'TOPLAM'],
            data: [
              [
                TurkceFormat.para(kesinti.kdvHaricGelir),
                TurkceFormat.para(veri.kdvTutari),
                TurkceFormat.para(veri.toplamTutar),
              ]
            ],
            headerStyle: kalin(9),
            cellStyle: kalin(9),
            cellAlignment: pw.Alignment.center,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ],
      ),
    );

    // ─────────────────────────────────────────────────────────────
    // SAYFA 3: DAĞ. MAKS. PAY. HESAPLAMA (EXCEL 2. SEKME KARŞILIĞI)
    // ─────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          _baslikAlani(veri, kalin, normal),
          pw.SizedBox(height: 16),
          pw.Text('DAĞ. MAKS. PAY. HESAPLAMA', style: kalin(12)),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 6),
          _pdfSatir('GELİR (KDV Hariç)', TurkceFormat.para(kesinti.kdvHaricGelir), kalin: true, normal: normal, bold: kalin),
          _pdfSatir('%${veri.kdvOrani} KDV', TurkceFormat.para(veri.kdvTutari), normal: normal, bold: kalin),
          _pdfSatir('TOPLAM TUTAR', TurkceFormat.para(veri.toplamTutar), kalin: true, normal: normal, bold: kalin),
          pw.SizedBox(height: 18),
          pw.Text('GELİRDEN AKTARILACAK PAYLAR', style: kalin(11)),
          pw.Divider(thickness: 0.5),
          pw.SizedBox(height: 4),
          _pdfSatir('HAZİNE PAYI (%${veri.hazineOrani})', TurkceFormat.para(kesinti.hazinePayi), normal: normal, bold: kalin),
          _pdfSatir('BİLİMSEL ARAŞTIRMA PROJELERİ PAYI (%${veri.bapOrani})', TurkceFormat.para(kesinti.bapPayi), normal: normal, bold: kalin),
          _pdfSatir('ARAÇ GEREÇ PAYI (%${(veri.aracGerecOrani * 100).toStringAsFixed(0)})', TurkceFormat.para(kesinti.aracGerecPayi), normal: normal, bold: kalin),
          _pdfSatir('KATKI PAYI', TurkceFormat.para(kesinti.katkiPayi), kalin: true, normal: normal, bold: kalin),
          pw.Divider(thickness: 0.5),
          _pdfSatir('TOPLAM', TurkceFormat.para(kesinti.toplam), kalin: true, normal: normal, bold: kalin),
          pw.Divider(thickness: 1),
          pw.SizedBox(height: 6),
          _pdfSatir('DAĞ. MAKS. AKADEMİK PAY (%49)', TurkceFormat.para(kesinti.dagMaksAkademikPay), kalin: true, normal: normal, bold: kalin),
        ],
      ),
    );

    // ─────────────────────────────────────────────────────────────
    // SAYFA 4: KATKI PAYI / DÖNEM EK KATSAYISI (EXCEL 3. SEKME)
    // ─────────────────────────────────────────────────────────────
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Text('KATKI PAYI / DÖNEM EK KATSAYI HESAPLAMA', style: kalin(12)),
          pw.SizedBox(height: 4),
          pw.Text(veri.hizmetBasligi, style: normal(9)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            context: ctx,
            headers: const [
              'Adı Soyadı',
              'Puan',
              'Unvan K.',
              'Saat',
              'Bireysel Net Katkı',
              'Dönem Kats.',
              'Kurs Saatlik Ücret',
              'Ek Ders Tavanı',
              'Brüt Hakediş',
              'Ödenebilir Hakediş',
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
                'TOPLAM',
                '',
                '',
                '',
                excel.toplamPuan.toStringAsFixed(0),
                TurkceFormat.katsayi(excel.donemKatsayi),
                '',
                '',
                TurkceFormat.para(excel.saglama),
                TurkceFormat.para(excel.netOdemeToplam),
              ],
            ],
            headerStyle: kalin(8),
            cellStyle: normal(8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Dağıtılacak Maksimum Akademik Pay: ${TurkceFormat.para(kesinti.dagMaksAkademikPay)}', style: kalin(9)),
              pw.Text('Hesaplama Sağlaması (Puan x Katsayı): ${TurkceFormat.para(excel.saglama)}', style: kalin(9)),
              pw.Text('Artık Bakiye (Birim Havuzu): ${TurkceFormat.para(excel.artikBakiye)}', style: kalin(9)),
            ],
          ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _baslikAlani(
    ManuelHesaplamaVerisi veri,
    pw.TextStyle Function(double) kalin,
    pw.TextStyle Function(double) normal,
  ) {
    return pw.Center(
      child: pw.Column(
        children: [
          pw.Text(veri.kurumAdi, style: kalin(11), textAlign: pw.TextAlign.center),
          if (veri.rektorlukAdi.isNotEmpty)
            pw.Text(veri.rektorlukAdi, style: kalin(10), textAlign: pw.TextAlign.center),
          if (veri.mudurlukAdi.isNotEmpty &&
              veri.mudurlukAdi.trim().toLowerCase() != veri.rektorlukAdi.trim().toLowerCase())
            pw.Text(veri.mudurlukAdi, style: kalin(10), textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 4),
          pw.Text(veri.hizmetBasligi, style: kalin(9), textAlign: pw.TextAlign.center),
        ],
      ),
    );
  }

  static pw.Widget _pdfSatir(
    String etiket,
    String deger, {
    bool kalin = false,
    required pw.TextStyle Function(double) normal,
    required pw.TextStyle Function(double) bold,
  }) {
    final style = kalin ? bold(9.5) : normal(9);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(etiket, style: style),
          pw.Text(deger, style: style),
        ],
      ),
    );
  }
}
