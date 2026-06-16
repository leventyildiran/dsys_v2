import 'package:dsys_v2/features/danismanlik/models/danismanlik_model.dart';
import 'package:dsys_v2/features/danismanlik/services/danismanlik_excel_hesaplama.dart';
import 'package:dsys_v2/features/personel/models/personel_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DanismanlikExcelHesaplama — Neslihan ÖPÖZ VURAL örneği', () {
    test('Excel formülleri birebir (9600 brüt, 20 puan, 5 saat)', () {
      final kesinti = DanismanlikExcelHesaplama.kesintiler(kdvHaricGelir: 8000);
      expect(kesinti.hazinePayi, 80);
      expect(kesinti.bapPayi, 400);
      expect(kesinti.aracGerecPayi, 3600);
      expect(kesinti.katkiPayi, 3920);
      expect(kesinti.dagMaksAkademikPay, 3920);

      final sonuc = DanismanlikExcelHesaplama.hesapla(
        kesinti: kesinti,
        personeller: const [
          ExcelPersonelGirdi(
            personelId: '1',
            adSoyad: 'Neslihan ÖPÖZ VURAL',
            unvan: 'Öğr. Gör. Dr.',
            puan: 20,
            unvanKatsayisi: 2,
            ekGosterge: 160,
            dersSaati: 5,
            mesaiIci: true,
          ),
        ],
      );

      expect(sonuc.toplamPuan, 200); // 20*2*5
      expect(sonuc.donemKatsayi, 19.6); // 3920/200
      expect(sonuc.saglama, 3920); // 200*19.6
      expect(sonuc.personelSatirlari.first.kursSaatlikUcreti, 784); // 200*19.6/5
      expect(sonuc.personelSatirlari.first.brutHakedis, 3920);
      expect(sonuc.personelSatirlari.first.odenebilirHakedis, 3920);
      expect(sonuc.artikBakiye, 0);

      // Ek ders tavan: 160*1.387871*2 = 444.11872
      expect(
        sonuc.personelSatirlari.first.tavanSaatlikUcreti,
        closeTo(444.12, 0.01),
      );
    });

    test('Brüt 9600 taksitten matrah 8000', () {
      final d = DanismanlikModel(
        id: 't',
        birimId: 'dts',
        firmaId: 'f',
        danismanlikTuru: DanismanlikTuru.standart,
        konusu: 'Test',
        toplamTutar: 9600,
        kdvOrani: 20,
        suresi: 1,
        durum: DanismanlikDurum.aktif,
        personeller: [
          PersonelGorevAtama(
            personel: const PersonelModel(
              id: '1',
              adSoyad: 'Neslihan ÖPÖZ VURAL',
              unvan: 'Öğr. Gör. Dr.',
              tcKimlikNo: '',
              iban: '',
              unvanKatsayisi: 2,
              birimId: 'dts',
            ),
            faaliyetPuani: 20,
            dersSaati: 5,
          ),
        ],
      );

      final sonuc = DanismanlikExcelHesaplama.hesaplaDanismanlik(
        danismanlik: d,
        brutTaksitTutari: 9600,
      );

      expect(sonuc.kesinti.kdvHaricGelir, 8000);
      expect(sonuc.kesinti.katkiPayi, 3920);
    });
  });

  group('USEM KATKI PAYI HESAPLAMA örneği', () {
    test('Dilek DURUKAN — 1664 puan, katkı 16927,27, katsayı 10,17', () {
      final kesinti = DanismanlikExcelHesaplama.kesintiler(
        kdvHaricGelir: 34545.45,
        hazineOrani: 1,
        bapOrani: 5,
        aracGerecOrani: 0.45,
      );
      expect(kesinti.katkiPayi, closeTo(16927.28, 0.5));

      final sonuc = DanismanlikExcelHesaplama.hesapla(
        kesinti: kesinti,
        profil: DanismanlikExcelProfili.usemSurekliEgitim,
        personeller: const [
          ExcelPersonelGirdi(
            personelId: '1',
            adSoyad: 'Dilek DURUKAN',
            unvan: 'Öğr.Gör.',
            puan: 16,
            unvanKatsayisi: 2,
            ekGosterge: 160,
            dersSaati: 52,
            mesaiIci: true,
          ),
        ],
      );

      expect(sonuc.toplamPuan, 1664);
      expect(sonuc.donemKatsayi, 10.17);
      expect(sonuc.personelSatirlari.first.kursSaatlikUcreti, closeTo(325.44, 0.01));
      expect(
        sonuc.personelSatirlari.first.tavanSaatlikUcreti,
        closeTo(290.49, 0.01),
      );
    });
  });
}
