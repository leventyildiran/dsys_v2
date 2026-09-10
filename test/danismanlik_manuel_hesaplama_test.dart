import 'package:dsys_v2/features/danismanlik/services/danismanlik_excel_hesaplama.dart';
import 'package:dsys_v2/features/danismanlik/services/danismanlik_manuel_pdf_servisi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Manuel Hesaplama & PDF Servisi Testleri', () {
    test('Neslihan Hoca Excel Senaryosu - 9.600 TL toplam, KDV %20, 200 Puan', () async {
      final veri = ManuelHesaplamaVerisi(
        kurumAdi: 'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ',
        rektorlukAdi: 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ',
        mudurlukAdi: 'DERİ, TEKSTİL UYGULAMA VE ARAŞTIRMA MERKEZİ MÜDÜRLÜĞÜ',
        hizmetBasligi: 'ÖĞR. GÖR. Dr. Neslihan ÖPÖZ VURAL DANIŞMANLIK HİZMET GELİRLERİ',
        satirlar: [
          ManuelListeSatiri(sn: 1, tc: '11111111111', aciklama: 'Fatura Geliri', tutar: 9600.0),
        ],
        kdvOrani: 20,
        hazineOrani: 1,
        bapOrani: 5,
        aracGerecOrani: 0.45,
        manuelDonemKatsayisi: 19.50,
        personeller: const [
          ExcelPersonelGirdi(
            personelId: '1',
            adSoyad: 'Neslihan ÖPÖZ VURAL',
            unvan: 'Öğr. Gör. Dr.',
            puan: 20.0,
            unvanKatsayisi: 2.0,
            ekGosterge: 160,
            dersSaati: 5.0,
            mesaiIci: false,
          ),
        ],
      );

      // Toplam & KDV
      expect(veri.toplamTutar, 9600.0);
      expect(veri.kdvHaricGelir, 8000.0);
      expect(veri.kdvTutari, 1600.0);

      // Kesintiler
      final kesinti = veri.kesintiSonuc;
      expect(kesinti.hazinePayi, 80.0);
      expect(kesinti.bapPayi, 400.0);
      expect(kesinti.aracGerecPayi, 3600.0);
      expect(kesinti.katkiPayi, 3920.0);
      expect(kesinti.dagMaksAkademikPay, 3920.0);

      // Katkı Payı & Dönem Katsayısı
      final excel = veri.excelSonuc;
      expect(excel.toplamPuan, 200.0); // 20 * 2.0 * 5.0
      expect(excel.donemKatsayi, 19.50);
      expect(excel.saglama, 3900.0); // 200 * 19.50
      expect(excel.artikBakiye, 20.0); // 3920 - 3900

      // Personel Satırı
      final pSonuc = excel.personelSatirlari.first;
      expect(pSonuc.kursSaatlikUcreti, 780.0); // 3900 / 5
      expect(pSonuc.odenebilirHakedis, 3900.0);

      // PDF Üretimi
      final pdfBytes = await ManuelHesaplamaPdfServisi.pdfUret(veri);
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(1000));
    });

    test('Çoklu Kişi / DTS Bilirkişi Heyeti Senaryosu - 5 Hoca Katkı ve Hakediş Dağılımı', () {
      const kesinti = ExcelKesintiSonuc(
        kdvHaricGelir: 5000.0,
        hazinePayi: 50.0,
        bapPayi: 250.0,
        aracGerecPayi: 2250.0,
        katkiPayi: 2450.00,
        dagMaksAkademikPay: 2450.00,
        toplam: 5000.0,
      );

      final sonuc = DanismanlikExcelHesaplama.hesapla(
        kesinti: kesinti,
        profil: DanismanlikExcelProfili.dtsDanismanlik,
        manualDonemKatsayi: 11.66,
        personeller: const [
          ExcelPersonelGirdi(
            personelId: '1',
            adSoyad: 'Eren ÖNER',
            unvan: 'Doç. Dr.',
            puan: 50.0,
            unvanKatsayisi: 1.0, // DTS bilirkişi tablosunda doğrudan puan çarpılır
            ekGosterge: 250,
            dersSaati: 1.0,
            mesaiIci: false,
          ),
          ExcelPersonelGirdi(
            personelId: '2',
            adSoyad: 'Sena DEMİRBAĞ',
            unvan: 'Dr. Öğr. Üyesi',
            puan: 40.0,
            unvanKatsayisi: 1.0,
            ekGosterge: 200,
            dersSaati: 1.0,
            mesaiIci: false,
          ),
          ExcelPersonelGirdi(
            personelId: '3',
            adSoyad: 'Neslihan ÖPÖZ VURAL',
            unvan: 'Öğr. Gör. Dr.',
            puan: 40.0,
            unvanKatsayisi: 1.0,
            ekGosterge: 160,
            dersSaati: 1.0,
            mesaiIci: false,
          ),
          ExcelPersonelGirdi(
            personelId: '4',
            adSoyad: 'Nilüfer ÜNAY ÇUBUKCU',
            unvan: 'Öğr. Gör.',
            puan: 40.0,
            unvanKatsayisi: 1.0,
            ekGosterge: 160,
            dersSaati: 1.0,
            mesaiIci: false,
          ),
          ExcelPersonelGirdi(
            personelId: '5',
            adSoyad: 'Esra SUNERLİ TOPAN',
            unvan: 'Öğr. Gör.',
            puan: 40.0,
            unvanKatsayisi: 1.0,
            ekGosterge: 160,
            dersSaati: 1.0,
            mesaiIci: false,
          ),
        ],
      );

      // Toplam puan
      expect(sonuc.toplamPuan, 210.0);
      expect(sonuc.donemKatsayi, 11.66);

      // Her hocanın alacağı tutar kontrolü
      expect(sonuc.personelSatirlari[0].odenebilirHakedis, 583.00); // 50 * 11.66
      expect(sonuc.personelSatirlari[1].odenebilirHakedis, 466.40); // 40 * 11.66
      expect(sonuc.personelSatirlari[2].odenebilirHakedis, 466.40); // 40 * 11.66
      expect(sonuc.personelSatirlari[3].odenebilirHakedis, 466.40); // 40 * 11.66
      expect(sonuc.personelSatirlari[4].odenebilirHakedis, 466.40); // 40 * 11.66

      // Toplam ödenen
      expect(sonuc.netOdemeToplam, 2448.60);
      expect(sonuc.artikBakiye, 1.40); // 2450.00 - 2448.60
    });

    test('Dinamik Havuz Paylaşımı - Dağıtılabilir Katkı Payı (3.920 TL) Puana Göre Kişiler Arası Paylaştırılır', () {
      final veri = ManuelHesaplamaVerisi(
        kurumAdi: 'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ',
        rektorlukAdi: 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ',
        mudurlukAdi: 'DERİ, TEKSTİL UYGULAMA VE ARAŞTIRMA MERKEZİ MÜDÜRLÜĞÜ',
        hizmetBasligi: 'DANIŞMANLIK HİZMET GELİRLERİ',
        satirlar: [
          ManuelListeSatiri(sn: 1, tc: '11111111111', aciklama: 'Fatura Geliri', tutar: 9600.0),
        ],
        kdvOrani: 20,
        hazineOrani: 1,
        bapOrani: 5,
        aracGerecOrani: 0.45,
        // manuelDonemKatsayisi VERİLMEZ (Dinamik Otomatik Dağıtım)
        personeller: const [
          ExcelPersonelGirdi(
            personelId: '1',
            adSoyad: 'Neslihan ÖPÖZ VURAL',
            unvan: 'Öğr. Gör. Dr.',
            puan: 20.0,
            unvanKatsayisi: 2.0,
            ekGosterge: 160,
            dersSaati: 5.0, // 200 Puan
            mesaiIci: false,
          ),
          ExcelPersonelGirdi(
            personelId: '2',
            adSoyad: 'Levent YILDIRAN',
            unvan: 'Öğr. Gör. Dr.',
            puan: 20.0,
            unvanKatsayisi: 2.0,
            ekGosterge: 160,
            dersSaati: 4.0, // 160 Puan
            mesaiIci: false,
          ),
        ],
      );

      final kesinti = veri.kesintiSonuc;
      expect(kesinti.katkiPayi, 3920.0);

      final excel = veri.excelSonuc;
      expect(excel.toplamPuan, 360.0);
      // 3920 / 360 = 10.88
      expect(excel.donemKatsayi, 10.88);

      final p1 = excel.personelSatirlari[0];
      final p2 = excel.personelSatirlari[1];
      expect(p1.odenebilirHakedis, 2176.0); // 200 * 10.88
      expect(p2.odenebilirHakedis, 1740.80); // 160 * 10.88

      // Toplam ödenen asla 3920 TL havuzunu aşamaz!
      expect(excel.netOdemeToplam, 3916.80);
      expect(excel.netOdemeToplam, lessThanOrEqualTo(kesinti.katkiPayi));
      expect(excel.artikBakiye, 3.20);
    });

    test('2547 Sayılı Kanun Madde 58/k (DONGSAN Senaryosu) - %15 Araç-Gereç, %85 Katkı Payı, %0 Hazine, %0 BAP', () async {
      final veri = ManuelHesaplamaVerisi(
        kurumAdi: 'T.C.\nUŞAK ÜNİVERSİTESİ REKTÖRLÜĞÜ',
        rektorlukAdi: 'DÖNER SERMAYE İŞLETME MÜDÜRLÜĞÜ',
        mudurlukAdi: 'MÜHENDİSLİK FAKÜLTESİ',
        hizmetBasligi: 'DONGSAN OTOMOTİV SAN. VE TİC. LTD. ŞTİ. DANIŞMANLIK HİZMETİ',
        satirlar: [
          ManuelListeSatiri(sn: 1, tc: '11111111111', aciklama: 'Fatura Geliri (DONGSAN)', tutar: 4205.62),
        ],
        kdvOrani: 20,
        hazineOrani: 0,
        bapOrani: 0,
        aracGerecOrani: 0.15,
        personeller: const [
          ExcelPersonelGirdi(
            personelId: '1',
            adSoyad: 'Dr. Öğr. Üyesi Deniz GÜRLER',
            unvan: 'Dr. Öğr. Üyesi',
            puan: 1.0,
            unvanKatsayisi: 1.0,
            ekGosterge: 200,
            dersSaati: 1.0,
            mesaiIci: false,
          ),
        ],
      );

      // Toplam & KDV
      expect(veri.toplamTutar, 4205.62);
      expect(veri.kdvHaricGelir, 3504.68);
      expect(veri.kdvTutari, 700.94);

      // Kesintiler (Hazine %0, BAP %0, A.G.P. %15, Katkı Payı %85)
      final kesinti = veri.kesintiSonuc;
      expect(kesinti.hazinePayi, 0.0);
      expect(kesinti.bapPayi, 0.0);
      expect(kesinti.aracGerecPayi, 525.70);
      expect(kesinti.katkiPayi, 2978.98);
      expect(kesinti.dagMaksAkademikPay, 2978.98);

      // Excel Sonuç (Tek hoca %100 pay alır, 2.978,98 TL)
      final excel = veri.excelSonuc;
      expect(excel.personelSatirlari.first.odenebilirHakedis, 2978.98);
      expect(excel.netOdemeToplam, 2978.98);
      expect(excel.artikBakiye, 0.0);

      // PDF üretimi de hatasız çalışmalı
      final pdfBytes = await ManuelHesaplamaPdfServisi.pdfUret(veri);
      expect(pdfBytes, isNotEmpty);
    });
  });
}
