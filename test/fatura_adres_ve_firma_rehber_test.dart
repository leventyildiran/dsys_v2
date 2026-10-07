import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/core/models/firma_model.dart';
import 'package:dsys_v2/features/fatura/models/fatura_model.dart';
import 'package:dsys_v2/features/fatura/services/fatura_offline_parser.dart';

void main() {
  group('Fatura Adres ve Firma Rehberi Testleri', () {
    test('1. FaturaModel.fromJson adres alanını düzgün ayrıştırmalı', () {
      final json = {
        'id': '1',
        'firmaAdi': 'Örnek Tekstil A.Ş.',
        'adres': 'Organize Sanayi Bölgesi 12. Cadde No:5 Nilüfer / BURSA',
        'vergiDairesi': 'Nilüfer',
        'vergiNo': '1234567890',
        'tarih': '07.10.2026',
        'matrah': 1000.0,
        'kdvTutari': 200.0,
        'genelToplam': 1200.0,
        'kalemler': [
          {'cinsi': 'Analiz', 'miktar': 1, 'fiyat': 1000.0}
        ],
      };

      final fatura = FaturaModel.fromJson(json);
      expect(fatura.firmaAdi, 'Örnek Tekstil A.Ş.');
      expect(fatura.adres, 'Organize Sanayi Bölgesi 12. Cadde No:5 Nilüfer / BURSA');
      expect(fatura.vergiDairesi, 'Nilüfer');
      expect(fatura.vergiNo, '1234567890');
    });

    test('2. FaturaOfflineParser serbest metinden adresi ve firmayı çıkarmalı', () {
      final metin = '''
SAYIN: YILDIZ ENERJİ SAN. VE TİC. A.Ş.
Adres: Demirtaş Mah. Barboros Cad. No:44 Osmangazi / BURSA
Vergi Dairesi: Osmangazi
VKN: 9876543210
Tarih: 07.10.2026

Numune Analiz Hizmeti   1   1500,00 TL
Toplam Tutar: 1500,00 TL
''';

      final faturalar = FaturaOfflineParser.parse(metin);
      expect(faturalar.isNotEmpty, isTrue);
      final f = faturalar.first;
      expect(f.firmaAdi, contains('YILDIZ ENERJİ'));
      expect(f.adres, contains('Demirtaş Mah. Barboros Cad. No:44 Osmangazi / BURSA'));
    });

    test('3. FirmaModel toJson ve fromJson adresi doğru korumalı', () {
      final firma = FirmaModel(
        id: 'f1',
        firmaAdi: 'Bursa Yazılım Ltd. Şti.',
        adres: 'Fethiye Mah. Sanayi Cad. No:12 Nilüfer / BURSA',
        vergiDairesi: 'Çekirge',
        vergiNo: '1122334455',
      );

      final json = firma.toJson();
      expect(json['adres'], 'Fethiye Mah. Sanayi Cad. No:12 Nilüfer / BURSA');

      final parsed = FirmaModel.fromJson(json, 'f1');
      expect(parsed.adres, firma.adres);
      expect(parsed.firmaAdi, firma.firmaAdi);
      expect(parsed.vergiNo, firma.vergiNo);
    });

    test('4. FaturaOfflineParser firma adından sonraki satırdaki açık adresi yakalamalı', () {
      final metin = '''
Firma Adı: KAYA MAKİNA SANAYİ LTD. ŞTİ.
Organize Sanayi Bölgesi Pembe Cadde No 18 Nilüfer BURSA
Vergi Dairesi: Nilüfer
VKN: 5432167890
Tarih: 07.10.2026

Numune Analizi   1   2500,00 TL
Toplam: 2500,00 TL
''';

      final faturalar = FaturaOfflineParser.parse(metin);
      expect(faturalar.isNotEmpty, isTrue);
      final f = faturalar.first;
      expect(f.firmaAdi, contains('KAYA MAKİNA'));
      expect(f.adres, contains('Organize Sanayi Bölgesi Pembe Cadde No 18 Nilüfer BURSA'));
    });

    test('5. FaturaOfflineParser Talep Formu bloklarından adres ve vergi bilgilerini çıkarmalı', () {
      final metin = '''
MELBES NO: MEL-2026-999
NUMUNE NO: NUM-888
Sayın: AKDENİZ GIDA A.Ş.
Adres: Çallı Mah. Vatan Cad. No:10 Muratpaşa / ANTALYA
Vergi Dairesi: Muratpaşa
Vergi No: 1234567891
Tarih: 01.10.2026
Su Analiz Raporu   1   3.000,00
Toplam Tutar: 3.000,00
''';

      final faturalar = FaturaOfflineParser.parse(metin);
      expect(faturalar.isNotEmpty, isTrue);
      final f = faturalar.first;
      expect(f.firmaAdi, contains('AKDENİZ GIDA'));
      expect(f.adres, contains('Çallı Mah. Vatan Cad. No:10 Muratpaşa / ANTALYA'));
      expect(f.vergiDairesi, 'Muratpaşa');
      expect(f.vergiNo, '1234567891');
    });
  });
}
