import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/material.dart' show ChangeNotifier;

/// Fatura yazdırma ve PDF oluşturma işlemlerini yöneten Provider.
class FaturaProvider extends ChangeNotifier {
  
  /// Matbu fatura şablonu üzerine verileri yerleştirerek PDF oluşturur.
  Future<Uint8List> generatePdf() async {
    // === KALİBRASYON ALANI ===
    // Bu değerleri değiştirerek matbu evrak üzerindeki yazıların yerlerini milimetrik ayarlayabilirsiniz.
    final double musteriAdTop = 135.0;
    final double musteriAdLeft = 80.0;
    final double vknTop = 160.0;
    final double vknLeft = 80.0;
    final double tarihTop = 135.0;
    final double tarihLeft = 460.0;
    final double melbesTop = 155.0;
    final double melbesLeft = 460.0;
    
    // Tablo (Kalemler) Koordinatları
    final double kalemlerBaslangicTop = 270.0;
    final double kalemSatirAraligi = 20.0;
    final double siraNoLeft = 40.0;
    final double cinsiLeft = 90.0;
    final double miktarLeft = 350.0;
    final double fiyatLeft = 420.0;
    final double tutarLeft = 490.0;

    // Alt Toplam Koordinatları
    final double yekunTop = 680.0;
    final double altToplamlarLeft = 490.0;

    // Font boyutu matbu evraka uygun olarak küçük seçildi
    const double standartFontSize = 10.0;

    final pdf = pw.Document();

    try {
      // Arka plan resmini yükle
      final bgImage = await rootBundle.load('assets/images/fatura_sablon.jpeg');

      // Örnek Kalemler (Gerçek uygulamada bunlar modelden gelecek)
      final items = [
        {'cinsi': 'Danışmanlık Hizmeti', 'miktar': 1, 'fiyat': 50000.00},
        {'cinsi': 'Sistem Kurulumu', 'miktar': 1, 'fiyat': 15000.50},
        {'cinsi': 'Yıllık Bakım', 'miktar': 1, 'fiyat': 8500.00},
      ];

      pdf.addPage(
        pw.Page(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            buildBackground: (context) {
              return pw.FullPage(
                ignoreMargins: true,
                child: pw.Image(
                  pw.MemoryImage(bgImage.buffer.asUint8List()),
                  fit: pw.BoxFit.cover,
                ),
              );
            },
          ),
          build: (context) {
            return pw.Stack(
              children: [
                // Müşteri Adı
                pw.Positioned(
                  top: musteriAdTop,
                  left: musteriAdLeft,
                  child: pw.Text('ÖRNEK MÜŞTERİ A.Ş.', style: const pw.TextStyle(fontSize: standartFontSize)),
                ),
                // VKN
                pw.Positioned(
                  top: vknTop,
                  left: vknLeft,
                  child: pw.Text('VKN: 1234567890', style: const pw.TextStyle(fontSize: standartFontSize)),
                ),
                // Tarih
                pw.Positioned(
                  top: tarihTop,
                  left: tarihLeft,
                  child: pw.Text('03.06.2026', style: const pw.TextStyle(fontSize: standartFontSize)),
                ),
                // MELBES No
                pw.Positioned(
                  top: melbesTop,
                  left: melbesLeft,
                  child: pw.Text('987654321', style: const pw.TextStyle(fontSize: standartFontSize)),
                ),
                
                // Kalemler (Döngü ile dinamik yerleştirme)
                ...items.asMap().entries.expand((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final currentTop = kalemlerBaslangicTop + (index * kalemSatirAraligi);
                  
                  return [
                    pw.Positioned(
                      top: currentTop,
                      left: siraNoLeft,
                      child: pw.Text('${index + 1}', style: const pw.TextStyle(fontSize: standartFontSize)),
                    ),
                    pw.Positioned(
                      top: currentTop,
                      left: cinsiLeft,
                      child: pw.Text('${item['cinsi']}', style: const pw.TextStyle(fontSize: standartFontSize)),
                    ),
                    pw.Positioned(
                      top: currentTop,
                      left: miktarLeft,
                      child: pw.Text('${item['miktar']}', style: const pw.TextStyle(fontSize: standartFontSize)),
                    ),
                    pw.Positioned(
                      top: currentTop,
                      left: fiyatLeft,
                      child: pw.Text('${(item['fiyat'] as double).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: standartFontSize)),
                    ),
                    pw.Positioned(
                      top: currentTop,
                      left: tutarLeft,
                      child: pw.Text('${((item['fiyat'] as double) * (item['miktar'] as int)).toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: standartFontSize)),
                    ),
                  ];
                }).toList(),

                // Toplam / Nakli Yekün
                pw.Positioned(
                  top: yekunTop,
                  left: altToplamlarLeft,
                  child: pw.Text(
                    '73500.50', 
                    style: pw.TextStyle(fontSize: standartFontSize, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
      );

      return pdf.save();
    } catch (e) {
      debugPrint('PDF Oluşturma Hatası: $e');
      rethrow;
    }
  }
}
