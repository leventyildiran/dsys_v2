import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_model.dart';
import 'package:dsys_v2/features/beyanname/services/beyanname_hesaplama_motoru.dart';

void main() {
  group('EYLÜL 2025 BEYANNAME.xlsx Tersine Mühendislik Testleri', () {
    test('KDV 1: Hesaplanan 64.372,28 TL - İndirilecek 26.359,68 TL = 38.012,60 TL', () {
      final satirlar = [
        // DTS: %20 Hesaplanan KDV: 1.000 TL, Matrah: 5.000 TL
        const Kdv1BirimSatiri(
          birimId: 'dts',
          birimAdi: 'DTS',
          hesaplananKdv20: 1000.0,
          hesaplananMatrah20: 5000.0,
        ),
        // UBATAM: %20 Hesaplanan KDV: 63.372,28 TL, Matrah: 316.861,40 TL
        // İndirilecek %10: KDV 414,50 TL, Matrah: 4.145,00 TL
        // İndirilecek %20: KDV 18.351,18 TL, Matrah: 91.755,90 TL
        const Kdv1BirimSatiri(
          birimId: 'ubatam',
          birimAdi: 'UBATAM',
          hesaplananKdv20: 63372.28,
          hesaplananMatrah20: 316861.40,
          indirilecekKdv10: 414.50,
          indirilecekMatrah10: 4145.00,
          indirilecekKdv20: 18351.18,
          indirilecekMatrah20: 91755.90,
        ),
        // TÖMER: İndirilecek %10: KDV 980 TL, Matrah: 9.800 TL, İndirilecek %20: KDV 5.039 TL, Matrah: 25.195 TL
        const Kdv1BirimSatiri(
          birimId: 'tomer',
          birimAdi: 'TÖMER',
          indirilecekKdv10: 980.0,
          indirilecekMatrah10: 9800.0,
          indirilecekKdv20: 5039.0,
          indirilecekMatrah20: 25195.0,
        ),
        // USEM: İndirilecek %10: KDV 625 TL, Matrah: 6.250 TL, İndirilecek %20: KDV 950 TL, Matrah: 4.750 TL
        const Kdv1BirimSatiri(
          birimId: 'usem',
          birimAdi: 'USEM',
          indirilecekKdv10: 625.0,
          indirilecekMatrah10: 6250.0,
          indirilecekKdv20: 950.0,
          indirilecekMatrah20: 4750.0,
        ),
      ];

      final sonuc = BeyannameHesaplamaMotoru.hesaplaKdv1(satirlar);

      expect(sonuc.matrah20Hesaplanan, 321861.40);
      expect(sonuc.toplamHesaplananKdv, 64372.28);
      expect(sonuc.toplamHesaplananMatrahVeKdv, 386233.68);

      expect(sonuc.matrah10Indirilecek, 20195.00);
      expect(sonuc.kdv10Indirilecek, 2019.50);
      expect(sonuc.matrah20Indirilecek, 121700.90);
      expect(sonuc.kdv20Indirilecek, 24340.18);
      expect(sonuc.toplamIndirilecekKdv, 26359.68);

      expect(sonuc.odenecekKdv1, 38012.60);
    });

    test('KDV 2: Tevkifatlar 9/10 (76.252,58 TL) + 7/10 (8.280,02 TL) = 84.532,60 TL', () {
      final firmalar = [
        // 9/10
        const TevkifatFirmaKaydi(
          id: '1',
          firmaAdi: 'GRAND DENTAL DİŞ PROTEZ LAB. HİZ.TİC.LTD.ŞTİ.',
          vergiTcNo: '4110649065',
          tevkifatTuru: TevkifatTuru.dokuzBoluOn,
          kdvOrani: 10,
          matrahTutari: 540000.0,
          kdvTutari: 54000.0,
          tevkifatTutari: 48600.0,
        ),
        const TevkifatFirmaKaydi(
          id: '2',
          firmaAdi: 'METASOFT BİLGİ TEKNOLOJİLERİ A.Ş.',
          vergiTcNo: '6191268620',
          tevkifatTuru: TevkifatTuru.dokuzBoluOn,
          kdvOrani: 20,
          matrahTutari: 113872.0,
          kdvTutari: 22774.40,
          tevkifatTutari: 20496.96,
        ),
        const TevkifatFirmaKaydi(
          id: '3',
          firmaAdi: 'MİROĞLU ÇEVRE SANAYİ TİCARET A.Ş.',
          vergiTcNo: '6210490464',
          tevkifatTuru: TevkifatTuru.dokuzBoluOn,
          kdvOrani: 20,
          matrahTutari: 39753.44,
          kdvTutari: 7950.69,
          tevkifatTutari: 7155.62,
        ),
        // 7/10
        const TevkifatFirmaKaydi(
          id: '4',
          firmaAdi: 'KONE ASANSÖR SANAYİ VE TİCARET ANONİM ŞİRKETİ',
          vergiTcNo: '8340057092',
          tevkifatTuru: TevkifatTuru.yediBoluOn,
          kdvOrani: 20,
          matrahTutari: 2394.0,
          kdvTutari: 478.80,
          tevkifatTutari: 335.16,
        ),
        const TevkifatFirmaKaydi(
          id: '5',
          firmaAdi: 'UŞAK NK MÜHENDİSLİK ELEKTRİK OTOMOTİV SANAYİ VE TİC. LİMİTED ŞİRKETİ',
          vergiTcNo: '8960855757',
          tevkifatTuru: TevkifatTuru.yediBoluOn,
          kdvOrani: 20,
          matrahTutari: 36250.0,
          kdvTutari: 7250.0,
          tevkifatTutari: 5075.0,
        ),
        const TevkifatFirmaKaydi(
          id: '6',
          firmaAdi: 'UŞAK NOKTA ENERJİ YAPI MÜH. TEKS. TAR. VE HAYV. SAN. VE TİC. LTD. ŞTİ.',
          vergiTcNo: '8960706737',
          tevkifatTuru: TevkifatTuru.yediBoluOn,
          kdvOrani: 20,
          matrahTutari: 20499.0,
          kdvTutari: 4099.80,
          tevkifatTutari: 2869.86,
        ),
      ];

      final sonuc = BeyannameHesaplamaMotoru.hesaplaKdv2(firmalar);

      expect(sonuc.turTevkifatToplam[TevkifatTuru.dokuzBoluOn.etiket], closeTo(76252.58, 0.01));
      expect(sonuc.turTevkifatToplam[TevkifatTuru.yediBoluOn.etiket], closeTo(8280.02, 0.01));
      expect(sonuc.turTevkifatToplam[TevkifatTuru.besBoluOn.etiket], 0.0);

      expect(sonuc.butunTevkifatlarToplami, closeTo(84532.60, 0.01));
      expect(sonuc.butunMatrahlarToplami, closeTo(752768.44, 0.01));
      expect(sonuc.butunKdvlerToplami, closeTo(96553.69, 0.01));
    });

    test('Damga Vergisi Binde 9,48 Matrah Ters Hesabı', () {
      // USEM Damga: 104,28 TL -> Matrah: 11.000 TL
      final matrahUsem = BeyannameHesaplamaMotoru.matrahFromDamga(104.28);
      expect(matrahUsem, closeTo(11000.0, 0.1));

      // UBATAM Damga: 761,70 TL -> Matrah: 80.348,10 TL
      final matrahUbatam = BeyannameHesaplamaMotoru.matrahFromDamga(761.70);
      expect(matrahUbatam, closeTo(80348.10, 0.1));

      // Toplam Matrah 91.348,10 TL -> Damga 865,98 TL
      expect(BeyannameHesaplamaMotoru.damgaFromMatrah(91348.10), closeTo(865.98, 0.01));
    });

    test('Muhtasar Konsolide ve Asgari Ücret İstisnaları (Eylül)', () {
      final bordro = [
        const MuhtasarSatiri(
          id: '1',
          birimAdi: 'DTS',
          kisiSayisi: 4,
          brutUcret: 55078.80,
          gelirVergisi: 5512.32,
          damgaVergisi: 418.03,
          netOdenen: 49148.45,
          aylikGelirVergisiMatrahi: 91093.68,
        ),
        const MuhtasarSatiri(
          id: '2',
          birimAdi: 'DÖSİM',
          kisiSayisi: 1,
          brutUcret: 18388.47,
          gelirVergisi: 0.0,
          damgaVergisi: 417.35,
          netOdenen: 73903.70,
          aylikGelirVergisiMatrahi: 18388.47,
        ),
        const MuhtasarSatiri(
          id: '3',
          birimAdi: 'UBATAM',
          kisiSayisi: 3,
          brutUcret: 47614.65,
          gelirVergisi: 9450.35,
          damgaVergisi: 361.39,
          netOdenen: 37802.91,
          aylikGelirVergisiMatrahi: 74997.52,
        ),
        const MuhtasarSatiri(
          id: '4',
          birimAdi: 'USEM',
          kisiSayisi: 1,
          brutUcret: 7488.0,
          gelirVergisi: 1497.60,
          damgaVergisi: 56.83,
          netOdenen: 5933.57,
          aylikGelirVergisiMatrahi: 18865.76,
        ),
      ];

      final sonuc = BeyannameHesaplamaMotoru.hesaplaMuhtasar(
        satirlar: bordro,
        muhtasarKesilenDamgaVergisi301: 865.98,
        yil: 2025,
        ay: 9, // Eylül
      );

      expect(sonuc.toplamKisiSayisi, 9);
      expect(sonuc.toplamBrutUcret, 128569.92);
      expect(sonuc.toplamGelirVergisi, 16460.27);
      expect(sonuc.toplamDamgaVergisi, 1253.60);
      expect(sonuc.toplamAylikGvMatrahi, 203345.43);

      // Asgari Ücret İstisnaları (Eylül: 4.420,93 TL * 9 = 39.788,37 TL)
      expect(sonuc.asgariUcretGvIstisnasiToplami, closeTo(39788.37, 0.01));
      // Asgari Ücret DV İstisnası (197,38 TL * 9 = 1.776,42 TL)
      expect(sonuc.asgariUcretDvIstisnasiToplami, closeTo(1776.42, 0.01));

      // 301 (865,98) + 302 (1.253,60) = 2.119,58 TL
      expect(sonuc.muhtasarKesilenDamgaVergisi301, 865.98);
      expect(sonuc.muhtasarDamgaVergisi302, 1253.60);
      expect(sonuc.toplamDamgaVergisi301Ve302, closeTo(2119.58, 0.01));
    });
  });
}
