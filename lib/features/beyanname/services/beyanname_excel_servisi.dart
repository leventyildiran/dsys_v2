import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_xlsio/xlsio.dart' as xlsio;
import 'package:file_saver/file_saver.dart';
import '../../../core/turkce_format.dart';
import '../models/beyanname_model.dart';
import '../providers/beyanname_provider.dart';

/// Defterdarlık ve Vergi Dairesi İncelemesine Uygun Birebir Excel (.xlsx) Üretim Servisi
class BeyannameExcelServisi {
  BeyannameExcelServisi._();

  static const List<String> _ayAdlari = [
    'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
  ];

  /// Defterdarlık için resmi çok sayfalı Excel tablosunu üretir ve bilgisayara indirir.
  static Future<void> defterdarlikExceliniIndir(BeyannameProvider provider) async {
    final bytes = await excelUret(provider);
    final ayAd = _ayAdlari[provider.seciliAy - 1].toUpperCase();
    final dosyaAdi = 'DEFTERDARLIK_BEYANNAME_${provider.seciliYil}_$ayAd';

    await FileSaver.instance.saveFile(
      name: dosyaAdi,
      bytes: bytes,
      ext: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  /// 3 Çalışma Sayfalı (Birim Bazlı Vergiler, Ana Sayfa, 600 Hasılat & Mizan) Excel Üretir
  static Future<Uint8List> excelUret(BeyannameProvider provider) async {
    final xlsio.Workbook workbook = xlsio.Workbook(3);
    final ayAd = _ayAdlari[provider.seciliAy - 1];
    final prevMonthName = provider.seciliAy > 1 ? _ayAdlari[provider.seciliAy - 2] : '';

    // =========================================================================
    // SAYFA 1: BİRİM BAZLI VERGİLER (Defterdarlık'ın ana incelediği detay cetveli)
    // =========================================================================
    final xlsio.Worksheet sheet1 = workbook.worksheets[0];
    sheet1.name = 'Birim Bazlı Vergiler';
    sheet1.showGridLines = true;

    // Başlık
    sheet1.getRangeByName('A1:H1').merge();
    sheet1.getRangeByName('A1').setText('T.C. UŞAK ÜNİVERSİTESİ DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ');
    sheet1.getRangeByName('A1').cellStyle.bold = true;
    sheet1.getRangeByName('A1').cellStyle.fontSize = 12;
    sheet1.getRangeByName('A1').cellStyle.hAlign = xlsio.HAlignType.center;

    sheet1.getRangeByName('A2:H2').merge();
    sheet1.getRangeByName('A2').setText('$ayAd ${provider.seciliYil} DÖNEMİ BİRİM BAZLI VERGİ VE BEYANNAME CETVELİ');
    sheet1.getRangeByName('A2').cellStyle.bold = true;
    sheet1.getRangeByName('A2').cellStyle.fontSize = 11;
    sheet1.getRangeByName('A2').cellStyle.fontColor = '#15803D';
    sheet1.getRangeByName('A2').cellStyle.hAlign = xlsio.HAlignType.center;

    // Tablo 1 Başlıkları
    final headers1 = [
      'BİRİMLER',
      'KDV 1',
      'DAMGA V.B.',
      'MUHTASAR GELİR',
      'MUHTASAR DAMGA',
      'MUHTASAR KESİLEN DAMGA',
      'MUHTASAR TOPLAM ÖDENECEK',
      'TOPLAM ÖDENECEK VERGİ',
    ];

    for (int col = 0; col < headers1.length; col++) {
      final cell = sheet1.getRangeByIndex(4, col + 1);
      cell.setText(headers1[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#DCFCE7';
      cell.cellStyle.fontColor = '#14532D';
      cell.cellStyle.hAlign = col == 0 ? xlsio.HAlignType.left : xlsio.HAlignType.right;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      cell.cellStyle.borders.all.color = '#86EFAC';
    }

    final icmaller = provider.birimIcmalListesi;
    int row1 = 5;

    for (final b in icmaller) {
      final isTomer = BirimAdlandirma.canonicalKey(b.birimAdi) == 'tomer';
      final rowColor = isTomer ? '#FEF9C3' : '#FFFFFF';

      sheet1.getRangeByIndex(row1, 1).setText(b.birimAdi);
      sheet1.getRangeByIndex(row1, 1).cellStyle.bold = true;
      sheet1.getRangeByIndex(row1, 1).cellStyle.hAlign = xlsio.HAlignType.left;

      final vals = [
        b.kdv1Tutari,
        b.damgaVb,
        b.muhtasarGelir,
        b.muhtasarDamga,
        b.muhtasarKesilenDamga,
        b.muhtasarToplam,
        b.genelToplamOdenecek,
      ];

      for (int c = 0; c < vals.length; c++) {
        final cell = sheet1.getRangeByIndex(row1, c + 2);
        cell.setNumber(vals[c]);
        cell.numberFormat = '#,##0.00';
        cell.cellStyle.hAlign = xlsio.HAlignType.right;
        if (c == vals.length - 1) {
          cell.cellStyle.bold = true;
          cell.cellStyle.fontColor = '#1D4ED8';
        }
      }

      for (int c = 1; c <= 8; c++) {
        final cell = sheet1.getRangeByIndex(row1, c);
        cell.cellStyle.backColor = rowColor;
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        cell.cellStyle.borders.all.color = '#E2E8F0';
      }
      row1++;
    }

    // Diş Damga - Karar Pulu Satırı
    sheet1.getRangeByIndex(row1, 1).setText('DİŞ DAMGA-KARAR PULU');
    sheet1.getRangeByIndex(row1, 1).cellStyle.bold = true;
    for (int c = 2; c <= 8; c++) {
      final cell = sheet1.getRangeByIndex(row1, c);
      cell.setNumber(0.0);
      cell.numberFormat = '#,##0.00';
      cell.cellStyle.hAlign = xlsio.HAlignType.right;
    }
    for (int c = 1; c <= 8; c++) {
      final cell = sheet1.getRangeByIndex(row1, c);
      cell.cellStyle.backColor = '#F0FDF4';
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      cell.cellStyle.borders.all.color = '#E2E8F0';
    }
    row1++;

    // Tablo 1 TOPLAMLAR
    final topKdv1 = icmaller.fold(0.0, (s, x) => s + x.kdv1Tutari);
    final topDamgaVb = icmaller.fold(0.0, (s, x) => s + x.damgaVb);
    final topMuhtasarGelir = icmaller.fold(0.0, (s, x) => s + x.muhtasarGelir);
    final topMuhtasarDamga = icmaller.fold(0.0, (s, x) => s + x.muhtasarDamga);
    final topMuhtasarKesilen = icmaller.fold(0.0, (s, x) => s + x.muhtasarKesilenDamga);
    final topMuhtasarToplam = icmaller.fold(0.0, (s, x) => s + x.muhtasarToplam);
    final topGenelOdenecek = topKdv1 + topDamgaVb + topMuhtasarToplam;

    sheet1.getRangeByIndex(row1, 1).setText('TOPLAMLAR');
    sheet1.getRangeByIndex(row1, 1).cellStyle.bold = true;

    final topVals1 = [
      topKdv1,
      topDamgaVb,
      topMuhtasarGelir,
      topMuhtasarDamga,
      topMuhtasarKesilen,
      topMuhtasarToplam,
      topGenelOdenecek,
    ];

    for (int c = 0; c < topVals1.length; c++) {
      final cell = sheet1.getRangeByIndex(row1, c + 2);
      cell.setNumber(topVals1[c]);
      cell.numberFormat = '#,##0.00';
      cell.cellStyle.bold = true;
      cell.cellStyle.hAlign = xlsio.HAlignType.right;
      cell.cellStyle.fontColor = '#14532D';
    }

    for (int c = 1; c <= 8; c++) {
      final cell = sheet1.getRangeByIndex(row1, c);
      cell.cellStyle.backColor = '#BBF7D0';
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.medium;
      cell.cellStyle.borders.all.color = '#15803D';
    }

    // Tablo 2: KDV 2 TEVKİFAT BİRİM DAĞILIMI
    int row2 = row1 + 3;
    sheet1.getRangeByName('A$row2:E$row2').merge();
    sheet1.getRangeByName('A$row2').setText('KDV 2 TEVKİFAT BİRİM DAĞILIMI (9/10, 7/10, 5/10 ORANLARI)');
    sheet1.getRangeByName('A$row2').cellStyle.bold = true;
    sheet1.getRangeByName('A$row2').cellStyle.fontSize = 11;
    sheet1.getRangeByName('A$row2').cellStyle.fontColor = '#92400E';

    row2++;
    final headers2 = ['BİRİMLER', '9 / 10 (%90)', '7 / 10 (%70)', '5 / 10 (%50)', 'TOPLAM KDV 2'];
    for (int col = 0; col < headers2.length; col++) {
      final cell = sheet1.getRangeByIndex(row2, col + 1);
      cell.setText(headers2[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#FEF3C7';
      cell.cellStyle.fontColor = '#92400E';
      cell.cellStyle.hAlign = col == 0 ? xlsio.HAlignType.left : xlsio.HAlignType.right;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      cell.cellStyle.borders.all.color = '#FDE68A';
    }

    row2++;
    for (final b in icmaller) {
      sheet1.getRangeByIndex(row2, 1).setText(b.birimAdi);
      sheet1.getRangeByIndex(row2, 1).cellStyle.bold = true;

      final vals2 = [
        b.kdv2DokuzBoluOn,
        b.kdv2YediBoluOn,
        b.kdv2BesBoluOn,
        b.kdv2Toplam,
      ];

      for (int c = 0; c < vals2.length; c++) {
        final cell = sheet1.getRangeByIndex(row2, c + 2);
        cell.setNumber(vals2[c]);
        cell.numberFormat = '#,##0.00';
        cell.cellStyle.hAlign = xlsio.HAlignType.right;
        if (c == vals2.length - 1) {
          cell.cellStyle.bold = true;
          cell.cellStyle.fontColor = '#B45309';
        }
      }

      for (int c = 1; c <= 5; c++) {
        final cell = sheet1.getRangeByIndex(row2, c);
        cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        cell.cellStyle.borders.all.color = '#E2E8F0';
      }
      row2++;
    }

    // Tablo 2 Toplam Satırı
    final topKdv2Dokuz = icmaller.fold(0.0, (s, x) => s + x.kdv2DokuzBoluOn);
    final topKdv2Yedi = icmaller.fold(0.0, (s, x) => s + x.kdv2YediBoluOn);
    final topKdv2Bes = icmaller.fold(0.0, (s, x) => s + x.kdv2BesBoluOn);
    final topKdv2Genel = icmaller.fold(0.0, (s, x) => s + x.kdv2Toplam);

    sheet1.getRangeByIndex(row2, 1).setText('TOPLAM KDV 2 ÖDENECEK TEVKİFAT');
    sheet1.getRangeByIndex(row2, 1).cellStyle.bold = true;

    final topVals2 = [topKdv2Dokuz, topKdv2Yedi, topKdv2Bes, topKdv2Genel];
    for (int c = 0; c < topVals2.length; c++) {
      final cell = sheet1.getRangeByIndex(row2, c + 2);
      cell.setNumber(topVals2[c]);
      cell.numberFormat = '#,##0.00';
      cell.cellStyle.bold = true;
      cell.cellStyle.hAlign = xlsio.HAlignType.right;
      cell.cellStyle.fontColor = '#78350F';
    }
    for (int c = 1; c <= 5; c++) {
      final cell = sheet1.getRangeByIndex(row2, c);
      cell.cellStyle.backColor = '#FDE68A';
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.medium;
      cell.cellStyle.borders.all.color = '#D97706';
    }

    sheet1.autoFitColumn(1);
    for (int c = 2; c <= 8; c++) {
      sheet1.setColumnWidthInPixels(c, 125);
    }

    // =========================================================================
    // SAYFA 2: ANA SAYFA (Mizan & Konsolide Beyanname)
    // =========================================================================
    final xlsio.Worksheet sheet2 = workbook.worksheets[1];
    sheet2.name = 'Ana Sayfa (Mizan)';
    sheet2.showGridLines = true;

    sheet2.getRangeByName('A1:F1').merge();
    sheet2.getRangeByName('A1').setText('KONSOLİDE BEYANNAME VE MİZAN MUTABAKAT ÖZETİ');
    sheet2.getRangeByName('A1').cellStyle.bold = true;
    sheet2.getRangeByName('A1').cellStyle.fontSize = 12;
    sheet2.getRangeByName('A1').cellStyle.hAlign = xlsio.HAlignType.center;

    // KDV 1 Konsolide Tablosu
    final k1 = provider.kdv1Sonuc;
    sheet2.getRangeByName('A3:D3').merge();
    sheet2.getRangeByName('A3').setText('1. KDV 1 KONSOLİDE VERGİ BİLGİLERİ');
    sheet2.getRangeByName('A3').cellStyle.bold = true;
    sheet2.getRangeByName('A3').cellStyle.fontColor = '#1D4ED8';

    final kdv1Headers = ['KDV 1 KALEMİ', 'MATRAH TUTARI', 'VERGİ TUTARI', 'TOPLAM'];
    for (int c = 0; c < kdv1Headers.length; c++) {
      final cell = sheet2.getRangeByIndex(4, c + 1);
      cell.setText(kdv1Headers[c]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#DBEAFE';
      cell.cellStyle.fontColor = '#1E40AF';
      cell.cellStyle.hAlign = c == 0 ? xlsio.HAlignType.left : xlsio.HAlignType.right;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      cell.cellStyle.borders.all.color = '#93C5FD';
    }

    final kdv1Rows = [
      ['%10 Hesaplanan Satışlar', k1.matrah10Hesaplanan, k1.kdv10Hesaplanan, k1.matrah10Hesaplanan + k1.kdv10Hesaplanan],
      ['%20 Hesaplanan Satışlar', k1.matrah20Hesaplanan, k1.kdv20Hesaplanan, k1.matrah20Hesaplanan + k1.kdv20Hesaplanan],
      ['TOPLAM HESAPLANAN KDV', 0.0, k1.toplamHesaplananKdv, k1.toplamHesaplananMatrahVeKdv],
      ['%10 İndirilecek Alımlar', k1.matrah10Indirilecek, k1.kdv10Indirilecek, k1.matrah10Indirilecek + k1.kdv10Indirilecek],
      ['%20 İndirilecek Alımlar', k1.matrah20Indirilecek, k1.kdv20Indirilecek, k1.matrah20Indirilecek + k1.kdv20Indirilecek],
      ['TOPLAM İNDİRİLECEK KDV', 0.0, k1.toplamIndirilecekKdv, k1.toplamIndirilecekMatrahVeKdv],
      ['Önceki Dönemden Devreden KDV', 0.0, provider.oncekiAydanDevredenKdv, provider.oncekiAydanDevredenKdv],
      ['ÖDENECEK KDV 1', 0.0, k1.odenecekKdv1, k1.odenecekKdv1],
      ['SONRAKİ DÖNEME DEVREDEN KDV', 0.0, k1.sonrakiDonemeDevredenKdv, k1.sonrakiDonemeDevredenKdv],
    ];

    for (int r = 0; r < kdv1Rows.length; r++) {
      final rowIdx = 5 + r;
      final label = kdv1Rows[r][0] as String;
      final mtr = kdv1Rows[r][1] as double;
      final vrg = kdv1Rows[r][2] as double;
      final top = kdv1Rows[r][3] as double;

      sheet2.getRangeByIndex(rowIdx, 1).setText(label);
      sheet2.getRangeByIndex(rowIdx, 2).setNumber(mtr);
      sheet2.getRangeByIndex(rowIdx, 3).setNumber(vrg);
      sheet2.getRangeByIndex(rowIdx, 4).setNumber(top);

      for (int c = 2; c <= 4; c++) {
        sheet2.getRangeByIndex(rowIdx, c).numberFormat = '#,##0.00';
        sheet2.getRangeByIndex(rowIdx, c).cellStyle.hAlign = xlsio.HAlignType.right;
      }

      final isBold = label.startsWith('TOPLAM') || label.startsWith('ÖDENECEK') || label.startsWith('SONRAKİ');
      if (isBold) {
        for (int c = 1; c <= 4; c++) {
          sheet2.getRangeByIndex(rowIdx, c).cellStyle.bold = true;
          sheet2.getRangeByIndex(rowIdx, c).cellStyle.backColor = label.startsWith('ÖDENECEK') ? '#DCFCE7' : '#F1F5F9';
        }
      }

      for (int c = 1; c <= 4; c++) {
        sheet2.getRangeByIndex(rowIdx, c).cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        sheet2.getRangeByIndex(rowIdx, c).cellStyle.borders.all.color = '#E2E8F0';
      }
    }

    // KDV 2 Tevkifatlı Firmalar
    int rowKdv2 = 16;
    sheet2.getRangeByName('A$rowKdv2:F$rowKdv2').merge();
    sheet2.getRangeByName('A$rowKdv2').setText('2. KDV 2 TEVKİFATLI FİRMALAR CETVELİ');
    sheet2.getRangeByName('A$rowKdv2').cellStyle.bold = true;
    sheet2.getRangeByName('A$rowKdv2').cellStyle.fontColor = '#B45309';

    rowKdv2++;
    final tevkifatHeaders = ['FİRMA / KİŞİ ADI', 'VERGİ / TC NO', 'TÜR / ORAN', 'MATRAH TUTARI', 'KDV TUTARI', 'TEVKİFAT TUTARI'];
    for (int col = 0; col < tevkifatHeaders.length; col++) {
      final cell = sheet2.getRangeByIndex(rowKdv2, col + 1);
      cell.setText(tevkifatHeaders[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#FEF3C7';
      cell.cellStyle.fontColor = '#92400E';
      cell.cellStyle.hAlign = col == 0 ? xlsio.HAlignType.left : xlsio.HAlignType.right;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      cell.cellStyle.borders.all.color = '#FDE68A';
    }

    rowKdv2++;
    for (final f in provider.tevkifatKayitlari) {
      sheet2.getRangeByIndex(rowKdv2, 1).setText(f.firmaAdi);
      sheet2.getRangeByIndex(rowKdv2, 2).setText(f.vergiTcNo);
      sheet2.getRangeByIndex(rowKdv2, 3).setText('${f.tevkifatTuru.etiket} (%${f.kdvOrani})');
      sheet2.getRangeByIndex(rowKdv2, 4).setNumber(f.matrahTutari);
      sheet2.getRangeByIndex(rowKdv2, 5).setNumber(f.kdvTutari);
      sheet2.getRangeByIndex(rowKdv2, 6).setNumber(f.tevkifatTutari);

      for (int c = 4; c <= 6; c++) {
        sheet2.getRangeByIndex(rowKdv2, c).numberFormat = '#,##0.00';
        sheet2.getRangeByIndex(rowKdv2, c).cellStyle.hAlign = xlsio.HAlignType.right;
      }
      sheet2.getRangeByIndex(rowKdv2, 6).cellStyle.bold = true;
      sheet2.getRangeByIndex(rowKdv2, 6).cellStyle.fontColor = '#B45309';

      for (int c = 1; c <= 6; c++) {
        sheet2.getRangeByIndex(rowKdv2, c).cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        sheet2.getRangeByIndex(rowKdv2, c).cellStyle.borders.all.color = '#E2E8F0';
      }
      rowKdv2++;
    }

    // Tevkifat Toplam Satırı
    sheet2.getRangeByIndex(rowKdv2, 1).setText('BÜTÜN TEVKİFAT TÜRLERİ TOPLAMI');
    sheet2.getRangeByIndex(rowKdv2, 1).cellStyle.bold = true;
    final topTevkifat = provider.kdv2Sonuc.butunTevkifatlarToplami;
    sheet2.getRangeByIndex(rowKdv2, 6).setNumber(topTevkifat);
    sheet2.getRangeByIndex(rowKdv2, 6).numberFormat = '#,##0.00';
    sheet2.getRangeByIndex(rowKdv2, 6).cellStyle.bold = true;
    sheet2.getRangeByIndex(rowKdv2, 6).cellStyle.hAlign = xlsio.HAlignType.right;
    for (int c = 1; c <= 6; c++) {
      final cell = sheet2.getRangeByIndex(rowKdv2, c);
      cell.cellStyle.backColor = '#FDE68A';
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.medium;
      cell.cellStyle.borders.all.color = '#D97706';
    }

    sheet2.autoFitColumn(1);
    sheet2.setColumnWidthInPixels(2, 120);
    sheet2.setColumnWidthInPixels(3, 110);
    sheet2.setColumnWidthInPixels(4, 120);
    sheet2.setColumnWidthInPixels(5, 120);
    sheet2.setColumnWidthInPixels(6, 130);

    // =========================================================================
    // SAYFA 3: 600 HASILAT & 123 (Mizan Kümülatif Mutabakat)
    // =========================================================================
    final xlsio.Worksheet sheet3 = workbook.worksheets[2];
    sheet3.name = '600 Hasılat & Mizan';
    sheet3.showGridLines = true;

    sheet3.getRangeByName('A1:E1').merge();
    sheet3.getRangeByName('A1').setText('600 HASILAT & 123 KREDİ KARTI (MİZAN MUTABAKAT VE KÜMÜLATİF CETVELİ)');
    sheet3.getRangeByName('A1').cellStyle.bold = true;
    sheet3.getRangeByName('A1').cellStyle.fontSize = 12;
    sheet3.getRangeByName('A1').cellStyle.hAlign = xlsio.HAlignType.center;

    final labelPrev = provider.seciliAy > 1
        ? 'ÖNCEKİ DÖNEMLER (Ocak - $prevMonthName)'
        : 'ÖNCEKİ DÖNEMLER (Yok)';

    final headers3 = [
      'BİRİM ADI',
      labelPrev,
      'BU AY AYLIK HASILAT',
      'YILLIK KÜMÜLATİF HASILAT',
      '123 KREDİ KARTI',
    ];

    for (int col = 0; col < headers3.length; col++) {
      final cell = sheet3.getRangeByIndex(3, col + 1);
      cell.setText(headers3[col]);
      cell.cellStyle.bold = true;
      cell.cellStyle.fontSize = 10;
      cell.cellStyle.backColor = '#E0F2FE';
      cell.cellStyle.fontColor = '#0369A1';
      cell.cellStyle.hAlign = col == 0 ? xlsio.HAlignType.left : xlsio.HAlignType.right;
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
      cell.cellStyle.borders.all.color = '#BAE6FD';
    }

    int row3 = 4;
    for (final h in provider.hasiat600Satirlari) {
      sheet3.getRangeByIndex(row3, 1).setText(h.birimAdi);
      sheet3.getRangeByIndex(row3, 1).cellStyle.bold = true;

      sheet3.getRangeByIndex(row3, 2).setNumber(h.oncekiAylarHasilat600);
      sheet3.getRangeByIndex(row3, 3).setNumber(h.aylikHasilat600);
      sheet3.getRangeByIndex(row3, 4).setNumber(h.kumulatifHasilat600);
      sheet3.getRangeByIndex(row3, 5).setNumber(h.krediKarti123);

      for (int c = 2; c <= 5; c++) {
        sheet3.getRangeByIndex(row3, c).numberFormat = '#,##0.00';
        sheet3.getRangeByIndex(row3, c).cellStyle.hAlign = xlsio.HAlignType.right;
      }
      sheet3.getRangeByIndex(row3, 4).cellStyle.bold = true;
      sheet3.getRangeByIndex(row3, 4).cellStyle.fontColor = '#0284C7';

      for (int c = 1; c <= 5; c++) {
        sheet3.getRangeByIndex(row3, c).cellStyle.borders.all.lineStyle = xlsio.LineStyle.thin;
        sheet3.getRangeByIndex(row3, c).cellStyle.borders.all.color = '#E2E8F0';
      }
      row3++;
    }

    // 600 Masası Toplam Satırı (Mizan Kümülatif Karşılaştırma)
    final topOnceki600 = provider.hasiat600Satirlari.fold(0.0, (s, x) => s + x.oncekiAylarHasilat600);
    final topAylik600 = provider.hasiat600Satirlari.fold(0.0, (s, x) => s + x.aylikHasilat600);
    final topKumulatif600 = provider.hasiat600ToplamKumulatif;
    final topKrediKarti123 = provider.krediKarti123Toplam;

    sheet3.getRangeByIndex(row3, 1).setText('GENEL TOPLAMLAR (MİZAN DENKLİĞİ)');
    sheet3.getRangeByIndex(row3, 1).cellStyle.bold = true;

    final topVals3 = [topOnceki600, topAylik600, topKumulatif600, topKrediKarti123];
    for (int c = 0; c < topVals3.length; c++) {
      final cell = sheet3.getRangeByIndex(row3, c + 2);
      cell.setNumber(topVals3[c]);
      cell.numberFormat = '#,##0.00';
      cell.cellStyle.bold = true;
      cell.cellStyle.hAlign = xlsio.HAlignType.right;
      cell.cellStyle.fontColor = '#0369A1';
    }

    for (int c = 1; c <= 5; c++) {
      final cell = sheet3.getRangeByIndex(row3, c);
      cell.cellStyle.backColor = '#BAE6FD';
      cell.cellStyle.borders.all.lineStyle = xlsio.LineStyle.medium;
      cell.cellStyle.borders.all.color = '#0284C7';
    }

    sheet3.autoFitColumn(1);
    sheet3.setColumnWidthInPixels(2, 160);
    sheet3.setColumnWidthInPixels(3, 140);
    sheet3.setColumnWidthInPixels(4, 150);
    sheet3.setColumnWidthInPixels(5, 130);

    // Byte dizisine dönüştür
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }
}
