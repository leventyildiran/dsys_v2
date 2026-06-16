import 'package:dsys_v2/features/fatura/services/fatura_excel_sablon_servisi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaturaExcelSablonServisi', () {
    test('USEM kursiyer listesi — YATAN TUTAR KDV dahil %10', () {
      const dump = '''
--- SHEET: Sayfa1 ---
Fatura Listesi- İHA-1 Pilot
SIRA NO | AD-SOYAD | T.C. KİMLİK NO | ADRES | YATAN TUTAR
1 | ALİ ÇETİNDUR | 10280798498 | Manisa | 4000
''';
      final sonuc = FaturaExcelSablonServisi.parse(dump);
      expect(sonuc.basarili, isTrue);
      expect(sonuc.birimOnerisi, 'USEM');
      expect(sonuc.faturalar.length, 1);
      expect(sonuc.faturalar.first.firmaAdi, 'ALİ ÇETİNDUR');
      expect(sonuc.faturalar.first.vergiNo, '10280798498');
      expect(sonuc.faturalar.first.matrah, closeTo(3636.36, 0.02));
      expect(sonuc.faturalar.first.genelToplam, closeTo(4000, 0.01));
      expect(sonuc.faturalar.first.kdvOrani, 10);
    });

    test('TÖMER ödeme listesi — pasaport', () {
      const dump = '''
--- SHEET: Sayfa1 ---
NO | AD SOYAD | ADRES | PASAPORT NO | KUR DÖNEMİ | ÜCRET TÜRÜ | TUTAR
1 | TAMERLAN TIMURKHANOV | Uşak | N15431736 | 2024/1. KUR | KUR | 7500
''';
      final sonuc = FaturaExcelSablonServisi.parse(
        dump,
        dosyaAdi: 'TÖMER 1. KUR.xlsx',
      );
      expect(sonuc.basarili, isTrue);
      expect(sonuc.birimOnerisi, 'TÖMER');
      expect(sonuc.faturalar.first.vergiNo, 'N15431736');
      expect(sonuc.faturalar.first.matrah, closeTo(6818.18, 0.02));
      expect(sonuc.faturalar.first.genelToplam, closeTo(7500, 0.01));
    });

    test('TÖMER LİSTE sayfası', () {
      const dump = '''
--- SHEET: LİSTE ---
JAMSHID OTEKOV
ÜNALAN MAH. | A2406161 | 7500
YENISH GARLYYEV
KURTULUŞ MAH. | A1991271 | 7500
''';
      final sonuc = FaturaExcelSablonServisi.parse(
        dump,
        dosyaAdi: 'KUR FATURASI.xls',
      );
      expect(sonuc.basarili, isTrue);
      expect(sonuc.tur, FaturaExcelSablonTuru.tomerListeSayfasi);
      expect(sonuc.faturalar.length, 2);
    });
  });
}
