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

  group('Yasal Tavan Bilgi Notu Modu ve Otomatik Saat Dengeleme', () {
    test('Bilgi Notu modunda personelin hakedişi kesilmez (tam ödenir), tavan analizi ve önerilen saat üretilir', () {
      final kesinti = DanismanlikExcelHesaplama.kesintiler(kdvHaricGelir: 10000); // katkiPayi = 4900
      final sonuc = DanismanlikExcelHesaplama.hesapla(
        kesinti: kesinti,
        tavanUygula: true,
        katiKesintiUygula: false, // Bilgi Notu modu
        personeller: const [
          ExcelPersonelGirdi(
            personelId: '1',
            adSoyad: 'Test Hoca',
            unvan: 'Prof. Dr.',
            puan: 20,
            unvanKatsayisi: 3,
            ekGosterge: 300,
            dersSaati: 2, // Sembolik az saat
            mesaiIci: false,
          ),
        ],
      );

      final pSonuc = sonuc.personelSatirlari.first;
      // 2547 s.k. Madde 58: Tam hakediş ödenmeli, havuza aktarılmamalı
      expect(pSonuc.brutHakedis, closeTo(4900.0, 1.0));
      expect(pSonuc.odenebilirHakedis, pSonuc.brutHakedis);
      expect(pSonuc.havuzTutari, 0.0);
      expect(sonuc.netOdemeToplam, pSonuc.brutHakedis);
      expect(sonuc.artikBakiye, closeTo(0.40, 0.01));

      // Tavan analizi kontrolü:
      // tavanSaatlik = 300 * 1.387871 * 3.2 = 1332.356
      // kursSaatlik = 4899.6 / 2 = 2449.8 > 1332.36 -> tavanAsildi == true
      expect(pSonuc.tavanAsildi, isTrue);
      expect(sonuc.herhangiBirTavanAsildi, isTrue);

      // Önerilen saat: ceil(4899.6 / 1332.356) = 4 saat
      expect(pSonuc.onerilenSaat, 4.0);
    });

    test('Önerilen saat (4 saat) uygulandığında saatlik ücret tavanın altına iner, tavanAsildi false olur ve hakediş tam kalır', () {
      final kesinti = DanismanlikExcelHesaplama.kesintiler(kdvHaricGelir: 10000);
      final dengeliSonuc = DanismanlikExcelHesaplama.hesapla(
        kesinti: kesinti,
        tavanUygula: true,
        katiKesintiUygula: false,
        personeller: const [
          ExcelPersonelGirdi(
            personelId: '1',
            adSoyad: 'Test Hoca',
            unvan: 'Prof. Dr.',
            puan: 20,
            unvanKatsayisi: 3,
            ekGosterge: 300,
            dersSaati: 4, // 4 saat yapıldı (dengelendi)
            mesaiIci: false,
          ),
        ],
      );

      final pSonuc = dengeliSonuc.personelSatirlari.first;
      expect(pSonuc.brutHakedis, closeTo(4900.0, 2.0));
      expect(pSonuc.odenebilirHakedis, pSonuc.brutHakedis);
      expect(pSonuc.kursSaatlikUcreti, closeTo(1224.6, 1.0)); // < 1332.36
      expect(pSonuc.tavanAsildi, isFalse);
      expect(dengeliSonuc.herhangiBirTavanAsildi, isFalse);
    });

    test('Müdür Kuralı (Tavana Göre Dağıt): Ders saatleri sabitken tavanı aşan personele yasal tavan ödenir, aşan tutar havuza kalır', () {
      final kesinti = DanismanlikExcelHesaplama.kesintiler(kdvHaricGelir: 10000); // katkiPayi = 4900
      final sonuc = DanismanlikExcelHesaplama.hesapla(
        kesinti: kesinti,
        tavanUygula: true,
        katiKesintiUygula: true, // Müdür Kuralı: Tavana kilitli dağıtım
        personeller: const [
          ExcelPersonelGirdi(
            personelId: '1',
            adSoyad: 'Prof Hoca',
            unvan: 'Prof. Dr.',
            puan: 20,
            unvanKatsayisi: 3,
            ekGosterge: 300,
            dersSaati: 2, // 2 saat -> tavanSaatlik = 1332.36 TL -> 2 * 1332.36 = 2664.71 TL
            mesaiIci: false,
          ),
        ],
      );

      final p = sonuc.personelSatirlari.first;
      expect(p.tavanAsildi, isTrue);
      // Tavan sınırı: 2 saat * 1332.356 = 2664.71 TL
      expect(p.odenebilirHakedis, closeTo(2664.71, 0.1));
      // Havuza aktarılan bakiye: 4899.6 - 2664.71 = 2234.89 TL
      expect(p.havuzTutari, closeTo(2234.89, 0.2));
      expect(sonuc.netOdemeToplam, closeTo(2664.71, 0.1));
      expect(sonuc.toplamTavanKesintisi, closeTo(2234.89, 0.2));
    });

    test('Ortak Tek Katsayı (Listede En Yüksek Unvan Bazlı - Doçent 31,51)', () {
      final kesinti = DanismanlikExcelHesaplama.kesintiler(
        kdvHaricGelir: 72727.27, // katkiPayi = 35636.36 TL
      );

      // Memur maaş katsayısı: 1.575525
      // Ayşen Melda Çolak: Doçent (250 ek gosterge), unvan katsayisi 2.5, puan 10, ders saati 1, mesai içi
      // 1 saatlik tavan: 250 * 1.575525 * 2 = 787.76 TL
      // 1 saatlik net puan: 10 * 2.5 = 25 puan
      // En yüksek unvan katsayısı: 787.76 / 25 = 31.51!
      final sonuc = DanismanlikExcelHesaplama.hesapla(
        kesinti: kesinti,
        tavanUygula: true,
        katiKesintiUygula: true,
        memurMaasKatsayisi: 1.575525,
        personeller: const [
          ExcelPersonelGirdi(
            personelId: '1',
            adSoyad: 'Ayşen Melda ÇOLAK',
            unvan: 'Doçent',
            puan: 10,
            unvanKatsayisi: 2.5,
            ekGosterge: 250,
            dersSaati: 1,
            mesaiIci: true,
          ),
          ExcelPersonelGirdi(
            personelId: '2',
            adSoyad: 'Alkan AKKAYA',
            unvan: 'Öğr. Gör.',
            puan: 10,
            unvanKatsayisi: 2.0,
            ekGosterge: 160,
            dersSaati: 6.5,
            mesaiIci: true,
          ),
        ],
      );

      expect(sonuc.donemKatsayi, 31.51);
      expect(sonuc.enYuksekUnvanAdi, 'Doçent');
      expect(sonuc.enYuksekUnvanKatsayisi, 31.51);
      expect(sonuc.enYuksekUnvanAciklama, contains('Ayşen Melda ÇOLAK'));

      final aysen = sonuc.personelSatirlari.first;
      // 25 * 31.51 = 787.75 TL (Tam tavanını alır, tavana takılmaz)
      expect(aysen.odenebilirHakedis, 787.75);
      expect(aysen.havuzTutari, 0.0);
    });
  });
}
