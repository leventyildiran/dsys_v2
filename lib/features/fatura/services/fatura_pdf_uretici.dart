import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../core/turkce_format.dart';
import '../models/fatura_matbu_config.dart';
import '../models/fatura_model.dart';
import '../models/fatura_prefs_keys.dart';

/// Provider'dan bağımsız, saf PDF üretim motoru.
/// Tüm girdiler parametre olarak alınır — state'siz çalışır.
class FaturaPdfUretici {
  FaturaPdfUretici._();

  static pw.Font? _pdfFontRegular;
  static pw.Font? _pdfFontBold;

  /// Türkçe karakter desteği için Tinos fontları (statik cache).
  static Future<(pw.Font regular, pw.Font bold)> _pdfFontlari() async {
    _pdfFontRegular ??= await PdfGoogleFonts.tinosRegular();
    _pdfFontBold ??= await PdfGoogleFonts.tinosBold();
    return (_pdfFontRegular!, _pdfFontBold!);
  }

  /// Fatura için PDF üretir.
  ///
  /// [includeBackground] null ise [matbuBaskiModu]'na göre karar verilir.
  static Future<Uint8List> generatePdf({
    required FaturaModel invoice,
    required Map<String, Offset> coordinates,
    required double kalemSatirAraligi,
    required double matbuFontBoyutu,
    required double globalOffsetDx,
    required double globalOffsetDy,
    required bool matbuBaskiModu,
    required String isletmeVknFallback,
    String? sistemHesapAdi,
    String? sistemIban,
    bool? includeBackground,
    Uint8List? bgImageBytes,
  }) async {
    final arkaPlanGoster = includeBackground ?? !matbuBaskiModu;

    try {
      final (fontRegular, fontBold) = await _pdfFontlari();
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(base: fontRegular, bold: fontBold),
      );
      const int satirLimit = FaturaPrefsKeys.pdfSatirLimit;

      pw.MemoryImage? bgImage;
      if (arkaPlanGoster) {
        final raw = bgImageBytes ??
            (await rootBundle.load('assets/images/fatura_sablon.jpeg'))
                .buffer
                .asUint8List();
        bgImage = pw.MemoryImage(raw);
      }

      Offset konum(String key) {
        final base = coordinates[key] ?? Offset.zero;
        return Offset(base.dx + globalOffsetDx, base.dy + globalOffsetDy);
      }

      final kalemler = FaturaMatbuConfig.matbuKalemleri(invoice.kalemler);
      if (kalemler.isEmpty) {
        kalemler.add({
          'cinsi': invoice.numuneAciklamasi.isNotEmpty
              ? invoice.numuneAciklamasi
              : 'Hizmet Bedeli',
          'miktar': 1,
          'fiyat': invoice.matrah,
        });
      }

      final toplamSayfa = (kalemler.length / satirLimit).ceil().clamp(1, 9999);
      var oncekiSayfaToplam = 0.0;

      pw.TextStyle metin({pw.FontWeight? weight}) => pw.TextStyle(
            fontSize: matbuFontBoyutu,
            fontWeight: weight,
            font: weight == pw.FontWeight.bold ? fontBold : fontRegular,
          );

      for (var sayfaIndex = 0; sayfaIndex < toplamSayfa; sayfaIndex++) {
        final baslangic = sayfaIndex * satirLimit;
        final bitis = (baslangic + satirLimit > kalemler.length)
            ? kalemler.length
            : baslangic + satirLimit;
        final sayfaSatirlari = kalemler.sublist(baslangic, bitis);

        final sayfaToplami = sayfaSatirlari.fold<double>(0, (acc, item) {
          final fiyat = double.tryParse(item['fiyat'].toString()) ?? 0.0;
          final miktar = double.tryParse(item['miktar'].toString()) ?? 1.0;
          return acc + (fiyat * miktar);
        });
        final araToplam = oncekiSayfaToplam + sayfaToplami;
        final sonSayfa = sayfaIndex == toplamSayfa - 1;
        final ilkSayfa = sayfaIndex == 0;

        pdf.addPage(
          pw.Page(
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.zero,
              buildBackground: bgImage == null
                  ? null
                  : (context) => pw.FullPage(
                      ignoreMargins: true,
                      child: pw.Image(bgImage!, fit: pw.BoxFit.fill),
                    ),
            ),
            build: (context) {
              final children = <pw.Widget>[];

              if (ilkSayfa) {
                if (invoice.firmaAdi.trim().isNotEmpty) {
                  children.add(pw.Positioned(
                    top: konum('firmaAdi').dy,
                    left: konum('firmaAdi').dx,
                    child: pw.SizedBox(
                      width: 270,
                      child: pw.Text(invoice.firmaAdi,
                          style: metin(weight: pw.FontWeight.bold)),
                    ),
                  ));
                }
                if (invoice.adres.trim().isNotEmpty) {
                  children.add(pw.Positioned(
                    top: konum('adres').dy,
                    left: konum('adres').dx,
                    child: pw.SizedBox(
                      width: 270,
                      child: pw.Text(invoice.adres, style: metin()),
                    ),
                  ));
                }
                if (invoice.vergiDairesi.trim().isNotEmpty) {
                  children.add(pw.Positioned(
                    top: konum('vergiDairesi').dy,
                    left: konum('vergiDairesi').dx,
                    child: pw.Text(invoice.vergiDairesi, style: metin()),
                  ));
                }
                if (invoice.vergiNo.trim().isNotEmpty) {
                  children.add(pw.Positioned(
                    top: konum('vkn').dy,
                    left: konum('vkn').dx,
                    child: pw.Text(invoice.vergiNo, style: metin()),
                  ));
                }
              }

              if (invoice.tarih.trim().isNotEmpty) {
                children.add(pw.Positioned(
                  top: konum('tarih').dy,
                  left: konum('tarih').dx,
                  child: pw.Text(invoice.tarih, style: metin()),
                ));
              }
              if (invoice.irsaliyeTarihi.trim().isNotEmpty) {
                children.add(pw.Positioned(
                  top: konum('irsaliyeTarihi').dy,
                  left: konum('irsaliyeTarihi').dx,
                  child: pw.Text(invoice.irsaliyeTarihi, style: metin()),
                ));
              }
              if (invoice.irsaliyeNo.trim().isNotEmpty) {
                children.add(pw.Positioned(
                  top: konum('irsaliyeNo').dy,
                  left: konum('irsaliyeNo').dx,
                  child: pw.Text(invoice.irsaliyeNo, style: metin()),
                ));
              }

              if (invoice.nakliYekunAktif && oncekiSayfaToplam > 0) {
                children.addAll([
                  pw.Positioned(
                    top: konum('nakliYekunUstYazi').dy,
                    left: konum('nakliYekunUstYazi').dx,
                    child: pw.Text('Nakli Yekün (Önceki Sayfa)',
                        style: metin(weight: pw.FontWeight.bold)),
                  ),
                  pw.Positioned(
                    top: konum('nakliYekunUstTutar').dy,
                    left: konum('nakliYekunUstTutar').dx,
                    child: pw.Text(TurkceFormat.para(oncekiSayfaToplam),
                        style: metin(weight: pw.FontWeight.bold)),
                  ),
                ]);
              }

              for (final entry in sayfaSatirlari.asMap().entries) {
                final index = entry.key;
                final item = entry.value;
                final currentTop =
                    konum('cinsi').dy + (index * kalemSatirAraligi);
                final fiyat =
                    double.tryParse(item['fiyat'].toString()) ?? 0.0;
                final miktar =
                    double.tryParse(item['miktar'].toString()) ?? 1.0;
                final satirTutar = fiyat * miktar;

                children.addAll([
                  pw.Positioned(
                    top: currentTop,
                    left: konum('cinsi').dx,
                    child: pw.SizedBox(
                      width: 255,
                      child: pw.Text('${item['cinsi']}', style: metin()),
                    ),
                  ),
                  pw.Positioned(
                    top: currentTop,
                    left: konum('miktar').dx,
                    child: pw.Text(
                      miktar == miktar.roundToDouble()
                          ? miktar.toInt().toString()
                          : TurkceFormat.ondalik(miktar),
                      style: metin(),
                    ),
                  ),
                  pw.Positioned(
                    top: currentTop,
                    left: konum('fiyat').dx,
                    child:
                        pw.Text(TurkceFormat.para(fiyat), style: metin()),
                  ),
                  pw.Positioned(
                    top: currentTop,
                    left: konum('tutar').dx,
                    child: pw.Text(TurkceFormat.para(satirTutar),
                        style: metin()),
                  ),
                ]);
              }

              if (invoice.nakliYekunAktif && !sonSayfa) {
                children.addAll([
                  pw.Positioned(
                    top: konum('nakliYekunAltYazi').dy,
                    left: konum('nakliYekunAltYazi').dx,
                    child: pw.Text('Nakli Yekün (Devreden)',
                        style: metin(weight: pw.FontWeight.bold)),
                  ),
                  pw.Positioned(
                    top: konum('nakliYekunAltTutar').dy,
                    left: konum('nakliYekunAltTutar').dx,
                    child: pw.Text(TurkceFormat.para(araToplam),
                        style: metin(weight: pw.FontWeight.bold)),
                  ),
                ]);
              } else if (invoice.nakliYekunAktif &&
                  toplamSayfa == 1 &&
                  sonSayfa) {
                children.addAll([
                  pw.Positioned(
                    top: konum('nakliYekunAltYazi').dy,
                    left: konum('nakliYekunAltYazi').dx,
                    child: pw.Text('Nakli Yekün (Devreden)',
                        style: metin(weight: pw.FontWeight.bold)),
                  ),
                  pw.Positioned(
                    top: konum('nakliYekunAltTutar').dy,
                    left: konum('nakliYekunAltTutar').dx,
                    child: pw.Text(TurkceFormat.para(sayfaToplami),
                        style: metin(weight: pw.FontWeight.bold)),
                  ),
                ]);
              }

              if (sonSayfa) {
                final numuneAciklamaAlt = invoice.numuneAciklamasi.trim();
                final numuneAciklamaMelbesSatiri =
                    numuneAciklamaAlt.toLowerCase().contains('melbes') &&
                    numuneAciklamaAlt.toLowerCase().contains('numune');
                final ustAciklamalar = [
                  if (numuneAciklamaAlt.isNotEmpty &&
                      !numuneAciklamaMelbesSatiri)
                    numuneAciklamaAlt,
                  if (invoice.aciklama != null &&
                      invoice.aciklama!.trim().isNotEmpty)
                    invoice.aciklama!,
                  if (invoice.isKdvMuaf) 'KDV\'den Muaftır (İstisna)',
                ].join(' | ');

                if (ustAciklamalar.isNotEmpty) {
                  children.add(pw.Positioned(
                    top: konum('numuneAciklama').dy,
                    left: konum('numuneAciklama').dx,
                    child: pw.Text(ustAciklamalar, style: metin()),
                  ));
                }

                final melbes = invoice.melbesNo.trim();
                final numune = invoice.numuneNo.trim();
                final kurumOnEki = invoice.melbesKurumOnEki.trim();
                final melbesSatir = FaturaMatbuConfig.formatMelbesNumuneSatir(
                  melbes: melbes,
                  numune: numune,
                  kurumOnEki: kurumOnEki.isNotEmpty ? kurumOnEki : null,
                );
                if (melbesSatir.isNotEmpty) {
                  children.add(pw.Positioned(
                    top: konum('melbes').dy,
                    left: konum('melbes').dx,
                    child: pw.SizedBox(
                      width: 500,
                      child: pw.Text(melbesSatir, style: metin()),
                    ),
                  ));
                } else if (kurumOnEki.isNotEmpty) {
                  children.add(pw.Positioned(
                    top: konum('melbes').dy,
                    left: konum('melbes').dx,
                    child: pw.SizedBox(
                      width: 500,
                      child: pw.Text(kurumOnEki, style: metin()),
                    ),
                  ));
                }

                children.addAll([
                  pw.Positioned(
                    top: konum('matrah').dy,
                    left: konum('matrah').dx,
                    child: pw.Text(TurkceFormat.para(invoice.matrah),
                        style: metin()),
                  ),
                  pw.Positioned(
                    top: konum('kdv').dy,
                    left: konum('kdv').dx,
                    child: pw.Text(TurkceFormat.para(invoice.kdvTutari),
                        style: metin()),
                  ),
                  if (!invoice.isKdvMuaf)
                    pw.Positioned(
                      top: konum('kdvOrani')?.dy ?? konum('kdv').dy,
                      left: konum('kdvOrani')?.dx ?? (konum('kdv').dx - 30),
                      child: pw.Text('%${invoice.kdvOrani.toInt()}',
                          style: metin()),
                    ),
                  pw.Positioned(
                    top: konum('genelToplam').dy,
                    left: konum('genelToplam').dx,
                    child: pw.Text(TurkceFormat.para(invoice.genelToplam),
                        style: metin(weight: pw.FontWeight.bold)),
                  ),
                  pw.Positioned(
                    top: konum('yaziylaTutar').dy,
                    left: konum('yaziylaTutar').dx,
                    child: pw.SizedBox(
                      width: 420,
                      child: pw.Text(
                          TurkceFormat.sayiyiYaziyaCevir(
                              invoice.genelToplam),
                          style: metin()),
                    ),
                  ),
                ]);

                final hesapAdiHam =
                    (invoice.hesapAdi?.trim().isNotEmpty == true)
                        ? invoice.hesapAdi!
                        : (sistemHesapAdi ?? '');
                final hesapAdi = FaturaMatbuConfig.formatHesapAdiMatbu(
                  hesapAdiHam,
                  fallbackVkn: isletmeVknFallback,
                );
                if (hesapAdi.isNotEmpty) {
                  children.add(pw.Positioned(
                    top: konum('hesapAdi').dy,
                    left: konum('hesapAdi').dx,
                    child: pw.Text(hesapAdi, style: metin()),
                  ));
                }

                final iban = (invoice.iban?.trim().isNotEmpty == true)
                    ? invoice.iban!
                    : (sistemIban ?? '');
                if (iban.isNotEmpty) {
                  children.add(pw.Positioned(
                    top: konum('iban').dy,
                    left: konum('iban').dx,
                    child: pw.Text(iban, style: metin()),
                  ));
                }
              }

              if (toplamSayfa > 1) {
                children.add(pw.Positioned(
                  top: 20,
                  right: 20,
                  child: pw.Text(
                    'Sayfa ${sayfaIndex + 1}/$toplamSayfa',
                    style: metin(weight: pw.FontWeight.bold),
                  ),
                ));
              }

              return pw.Stack(children: children);
            },
          ),
        );
        oncekiSayfaToplam = araToplam;
      }

      return pdf.save();
    } catch (e) {
      debugPrint('PDF Oluşturma Hatası: $e');
      final errDoc = pw.Document();
      errDoc.addPage(
        pw.Page(
          build: (context) =>
              pw.Center(child: pw.Text('PDF oluşturulamadı: $e')),
        ),
      );
      return errDoc.save();
    }
  }

  /// Matbu baskı: arka plansız, doğrudan yazıcıya.
  static Future<void> matbuYazdir({
    required FaturaModel invoice,
    required Map<String, Offset> coordinates,
    required double kalemSatirAraligi,
    required double matbuFontBoyutu,
    required double globalOffsetDx,
    required double globalOffsetDy,
    required bool matbuBaskiModu,
    required String isletmeVknFallback,
    String? sistemHesapAdi,
    String? sistemIban,
  }) async {
    final bytes = await generatePdf(
      invoice: invoice,
      coordinates: coordinates,
      kalemSatirAraligi: kalemSatirAraligi,
      matbuFontBoyutu: matbuFontBoyutu,
      globalOffsetDx: globalOffsetDx,
      globalOffsetDy: globalOffsetDy,
      matbuBaskiModu: matbuBaskiModu,
      isletmeVknFallback: isletmeVknFallback,
      sistemHesapAdi: sistemHesapAdi,
      sistemIban: sistemIban,
      includeBackground: false,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
