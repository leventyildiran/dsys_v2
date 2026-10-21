import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/beyanname/services/mizan_deterministik_parser.dart';

void main() {
  group('MizanDeterministikParser Testleri', () {
    test('Çok satırlı Muhasebat standart mizan bloğu doğru ayrıştırılır', () {
      const sampleText = '''
GEÇİCİ MİZAN
T.C. Maliye Bakanlığı
Muhasebat Genel Müdürlüğü
Muhasebe Birimi
: UBATAM MÜDÜRLÜĞÜ
Başlangıç Tarihi
: 01.09.2026
Bitiş Tarihi
: 30.09.2026
Hesap
Hesap Adı
Borç (TL)
Alacak (TL)
Borç Kalan (TL)
Alacak Kalan (TL)
Hesap
191.05
İndirilecek KDV Hesabı-%20
16.247,44
16.247,44
0,00
0,00
191.05
391.05
Hesaplanan KDV Hesabı-%20
108.310,43
108.310,43
0,00
0,00
391.05
600
YURTİÇİ SATIŞLAR HESABI
0,00
541.552,17
0,00
541.552,17
600
360.03.05
Ödemelerden Kesilen Damga Vergisi
2.424,84
770,12
1.654,72
0,00
360.03.05
''';

      final meta = MizanDeterministikParser.extractMetaVeri(sampleText);
      expect(meta.muhasebeBirimi, contains('UBATAM'));
      expect(meta.baslangicTarihi, '01.09.2026');
      expect(meta.isYillikKumulatif, isFalse);

      final hesaplar = MizanDeterministikParser.parseHesaplar(sampleText);
      expect(hesaplar.containsKey('191.05'), isTrue);
      expect(hesaplar['191.05']!.borc, 16247.44);

      expect(hesaplar.containsKey('391.05'), isTrue);
      expect(hesaplar['391.05']!.alacak, 108310.43);

      expect(hesaplar.containsKey('600'), isTrue);
      expect(hesaplar['600']!.alacak, 541552.17);

      expect(hesaplar.containsKey('360.03.05'), isTrue);
      expect(hesaplar['360.03.05']!.alacak, 770.12);

      final sonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'UBATAM',
        aylikMizanMetni: sampleText,
        yillikMizanMetni: '',
      );

      expect(sonuc.hasilat600Aylik, 541552.17);
      expect(sonuc.hesaplananKdv20, 108310.43);
      expect(sonuc.hesaplananKdvMatrah20, 541552.17);
      expect(sonuc.indirilecekKdv20, 16247.44);
      expect(sonuc.damgaVergisi360, 770.12);
      expect(sonuc.damgaMatrah, closeTo(81236.29, 0.05));
    });

    test('Yıllık kümülatif mizan ve önceki aylar hasılatı doğru hesaplanır', () {
      const yillikText = '''
Hesap
Hesap Adı
Borç (TL)
Alacak (TL)
Borç Kalan (TL)
Alacak Kalan (TL)
Hesap
600
YURTİÇİ SATIŞLAR HESABI
0,00
1.147.750,00
0,00
1.147.750,00
600
190
DEVREDEN KDV HESABI
25.000,00
0,00
25.000,00
0,00
190
''';

      final sonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'DTS',
        aylikMizanMetni: '',
        yillikMizanMetni: yillikText,
        oncekiAylarHasilat: 873500.0,
      );

      expect(sonuc.hasilat600Kumulatif, 1147750.0);
      expect(sonuc.hasilat600Aylik, 1147750.0 - 873500.0); // 274.250,00 TL
      expect(sonuc.devredenKdv190, 25000.0);
    });

    test('Tek satırlı yatay mizan formatı da başarıyla ayrıştırılır', () {
      const horizontalText = '''
600 YURTİÇİ SATIŞLAR HESABI 0,00 180.000,00 0,00 180.000,00
391.05 Hesaplanan KDV %20 0,00 36.000,00 0,00 36.000,00
191.05 İndirilecek KDV %20 12.000,00 0,00 12.000,00 0,00
''';

      final sonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'DÖSİM',
        aylikMizanMetni: horizontalText,
        yillikMizanMetni: '',
      );

      expect(sonuc.hasilat600Aylik, 180000.0);
      expect(sonuc.hesaplananKdv20, 36000.0);
      expect(sonuc.indirilecekKdv20, 12000.0);
    });

    test('610 Satıştan İadeler hesabı 600 Hasılatından net satış olarak düşülür', () {
      const textWith610 = '''
600 YURTİÇİ SATIŞLAR HESABI 0,00 100.000,00 0,00 100.000,00
610 SATIŞTAN İADELER HESABI (-) 5.000,00 0,00 5.000,00 0,00
391.05 Hesaplanan KDV %20 0,00 20.000,00 0,00 20.000,00
''';

      final sonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'DİŞ HEKİMLİĞİ',
        aylikMizanMetni: textWith610,
        yillikMizanMetni: '',
      );

      // 100.000 - 5.000 = 95.000 net hasılat
      expect(sonuc.hasilat600Aylik, 95000.0);
    });

    test('360.03 ana hesabı ve Muhtasar (360.01.01 Gelir & 360.03.01 Damga) doğru ayrıştırılır', () {
      const sampleText = '''
360.01.01 GELİR VERGİSİ STOPAJI 0,00 4.500,00 0,00 4.500,00
360.03.01 ÜCRET DAMGA VERGİSİ 0,00 350,00 0,00 350,00
360.03.02 İHALE KARARLARI DAMGA VERGİSİ 0,00 1.200,00 0,00 1.200,00
360.03.05 ÖDEMELERDEN KESİLEN DAMGA 0,00 800,00 0,00 800,00
600 YURTİÇİ SATIŞLAR 0,00 50.000,00 0,00 50.000,00
''';

      final sonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'TÖMER',
        aylikMizanMetni: sampleText,
        yillikMizanMetni: '',
      );

      // Muhtasar stopajları
      expect(sonuc.muhtasarGelir360, 4500.0);
      expect(sonuc.muhtasarDamga360, 350.0);

      // Damga: Ücret damgası (350 TL) hariç diğer damgalar: 1.200 + 800 = 2.000 TL
      expect(sonuc.damgaVergisi360, 2000.0);
    });

    test('Yardımcı Defterden (Muavin) Damga ve Muhtasar başarıyla okunur', () {
      const anaMizan = '''
600 YURTİÇİ SATIŞLAR 0,00 100.000,00 0,00 100.000,00
360 ÖDENECEK VERGİ VE FONLAR 0,00 15.000,00 0,00 15.000,00
''';
      const yardimciMizan = '''
360.01.01 ÜCRETLERDEN KESİLEN GELİR VERGİSİ 0,00 6.000,00 0,00 6.000,00
360.03.01 BORDRO DAMGA VERGİSİ 0,00 500,00 0,00 500,00
360.03.05 HAKEDİŞ VE DİĞER ÖDEMELER DAMGA V. 0,00 1.500,00 0,00 1.500,00
''';

      final sonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'UZEM',
        aylikMizanMetni: anaMizan,
        yillikMizanMetni: '',
        yardimciMizanMetni: yardimciMizan,
      );

      expect(sonuc.muhtasarGelir360, 6000.0);
      expect(sonuc.muhtasarDamga360, 500.0);
      expect(sonuc.damgaVergisi360, 1500.0);
    });
  });
}
