import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:dsys_v2/features/beyanname/services/mizan_deterministik_parser.dart';

void main() {
  test('Gerçek DÖSİM PDF Dosyalarını Oku ve Analiz Et', () {
    final aylikFile = File('C:/Users/gumus/OneDrive/Desktop/BEYANNAME/EYLÜL 2026 BEYANNAME/1 - DÖSİM/Dösim Geçizi Mizan Aylık.pdf');
    final yillikFile = File('C:/Users/gumus/OneDrive/Desktop/BEYANNAME/EYLÜL 2026 BEYANNAME/1 - DÖSİM/Dösim Geçici Mizan Yıllık.pdf');
    final yardimciFile = File('C:/Users/gumus/OneDrive/Desktop/BEYANNAME/EYLÜL 2026 BEYANNAME/1 - DÖSİM/Dösim Yardımcı Defter Yıllık.pdf');

    expect(aylikFile.existsSync(), isTrue);
    expect(yillikFile.existsSync(), isTrue);
    expect(yardimciFile.existsSync(), isTrue);

    String extractPdf(File f, {int maxPages = 50}) {
      final doc = PdfDocument(inputBytes: f.readAsBytesSync());
      final extractor = PdfTextExtractor(doc);
      final sb = StringBuffer();
      final count = doc.pages.count < maxPages ? doc.pages.count : maxPages;
      for (int i = 0; i < count; i++) {
        sb.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
      }
      doc.dispose();
      return sb.toString();
    }

    final aylikText = extractPdf(aylikFile, maxPages: 10);
    final yillikText = extractPdf(yillikFile, maxPages: 20);
    final yardimciText = extractPdf(yardimciFile, maxPages: 297);

    final aylikMeta = MizanDeterministikParser.extractMetaVeri(aylikText);
    print('Aylık Meta: baslangic=${aylikMeta.baslangicTarihi}, bitis=${aylikMeta.bitisTarihi}, isYillik=${aylikMeta.isYillikKumulatif}');

    final sonuc = MizanDeterministikParser.analizEt(
      birimAdi: 'DÖSİM',
      aylikMizanMetni: aylikText,
      yillikMizanMetni: yillikText,
      yardimciMizanMetni: yardimciText,
    );

    print('=== GERÇEK DÖSİM ANALİZ SONUCU ===');
    print('Hasılat 600 Aylık: ${sonuc.hasilat600Aylik}');
    print('Hasılat 600 Kümülatif: ${sonuc.hasilat600Kumulatif}');
    print('Hesaplanan KDV 20: ${sonuc.hesaplananKdv20}');
    print('Damga 360: ${sonuc.damgaVergisi360}');
    print('Muhtasar Gelir 360: ${sonuc.muhtasarGelir360}');
    print('Muhtasar Damga 360: ${sonuc.muhtasarDamga360}');
    print('KDV 2 Tevkifat 360: ${sonuc.kdv2Tevkifat360}');

    // Doğrulamalar:
    expect(sonuc.muhtasarGelir360, equals(0.0), reason: 'DÖSİM Muhtasar Gelir Vergisi 0 TL olmalı (diğer birim aktarımı arındırıldı)');
    expect(sonuc.damgaVergisi360, equals(0.0), reason: 'DÖSİM 360.03.05 Damga Vergisi 0 TL olmalı');
    expect(sonuc.muhtasarDamga360, equals(677.18), reason: 'DÖSİM Muhtasar Damga Vergisi konsolide aktarımlardan arındırılmış Eylül bordro damgası olmalı');
    expect(sonuc.kdv2Tevkifat360, equals(0.0), reason: 'DÖSİM mizan KDV 2 tevkifat 0 TL olmalı');
  });
}
