import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_belge_model.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_model.dart';
import 'package:dsys_v2/features/beyanname/providers/beyanname_provider.dart';
import 'package:dsys_v2/features/beyanname/services/beyanname_denetim_servisi.dart';
import 'package:dsys_v2/features/beyanname/services/beyanname_hesaplama_motoru.dart';
import 'package:dsys_v2/features/beyanname/services/mizan_deterministik_parser.dart';
import 'package:dsys_v2/features/beyanname/services/beyanname_excel_servisi.dart';
import 'package:dsys_v2/features/beyanname/services/beyanname_rapor_servisi.dart';

void main() {
  group('BEYANNAME CANLI SİMÜLASYON VE UÇTAN UCA DOĞRULAMA TESTLERİ', () {
    late BeyannameProvider provider;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      provider = BeyannameProvider();
    });

    test('SİMÜLASYON 1: Tüm Birimlerin Mizan + Tevkifat Faturası Analizi ve Hesaplama Doğrulaması', () async {
      // 1. TÖMER Mizanı: 600 (Yurtiçi) + 601 (Yurtdışı Öğrenci Satışı) + 360 Muhtasar Stopajı
      const tomerMizan = '''
600 YURTİÇİ SATIŞLAR 0,00 300.000,00 0,00 300.000,00
601 YURTDIŞI EĞİTİM SATIŞLARI 0,00 50.000,00 0,00 50.000,00
610 SATIŞTAN İADELER 5.000,00 0,00 5.000,00 0,00
391.01.04 %10 HESAPLANAN KDV 0,00 34.500,00 0,00 34.500,00
191.01.04 %10 İNDİRİLECEK KDV 6.500,00 0,00 6.500,00 0,00
360.01.01 ÜCRET GELİR VERGİSİ 0,00 8.500,00 0,00 8.500,00
360.03.01 BORDRO DAMGA VERGİSİ 0,00 650,00 0,00 650,00
360.03.05 ÖDEMELERDEN KESİLEN DAMGA 0,00 1.250,00 0,00 1.250,00
''';

      final tomerSonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'TÖMER',
        aylikMizanMetni: tomerMizan,
        yillikMizanMetni: '',
      );

      // (300.000 + 50.000) - 5.000 = 345.000 TL net hasılat
      expect(tomerSonuc.hasilat600Aylik, 345000.0);
      expect(tomerSonuc.hesaplananKdv10, 34500.0);
      expect(tomerSonuc.hesaplananKdvMatrah10, 345000.0);
      expect(tomerSonuc.indirilecekKdv10, 6500.0);
      expect(tomerSonuc.muhtasarGelir360, 8500.0);
      expect(tomerSonuc.muhtasarDamga360, 650.0);
      expect(tomerSonuc.damgaVergisi360, 1250.0);

      // 2. Diş Hekimliği: 123 POS + Birden fazla 360 damga hesabı (İhale + Ödemeler)
      const disMizan = '''
600 YURTİÇİ SATIŞLAR 0,00 1.000.000,00 0,00 1.000.000,00
123 KREDİ KARTI VE POS ALACAKLARI 250.000,00 0,00 250.000,00 0,00
391.01.05 %20 HESAPLANAN KDV 0,00 200.000,00 0,00 200.000,00
191.01.05 %20 İNDİRİLECEK KDV 45.000,00 0,00 45.000,00 0,00
360.03.02 İHALE KARARLARI DAMGA VERGİSİ 0,00 4.500,00 0,00 4.500,00
360.03.05 DİĞER ÖDEMELER DAMGA VERGİSİ 0,00 2.500,00 0,00 2.500,00
''';

      final disFaturalar = [
        {
          'firmaAdi': 'Dental İmplant San. Ltd.',
          'vergiTcNo': '1234567890',
          'matrahTutari': 100000.0,
          'kdvTutari': 20000.0,
          'tevkifatTutari': 14000.0,
          'tevkifatOrani': '7/10',
        },
        {
          'firmaAdi': 'Medikal Temizlik Ltd.',
          'vergiTcNo': '9876543210',
          'matrahTutari': 50000.0,
          'kdvTutari': 10000.0,
          'tevkifatTutari': 2000.0,
          'tevkifatOrani': '2/10',
        },
      ];

      final disSonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'Diş Hekimliği Fakültesi',
        aylikMizanMetni: disMizan,
        yillikMizanMetni: '',
        ekTevkifatFaturalari: disFaturalar,
      );

      expect(disSonuc.krediKarti123, 250000.0);
      expect(disSonuc.hesaplananKdv20, 200000.0);
      expect(disSonuc.indirilecekKdv20, 45000.0);
      // 360.03.02 (4.500) + 360.03.05 (2.500) = 7.000 TL damga vergisi
      expect(disSonuc.damgaVergisi360, 7000.0);
      expect(disSonuc.tevkifatFaturalari.length, 2);

      // 3. TADAUM (Tarımsal Üretim): %1 KDV Tohum/Fide satışı + 4/10 ve 10/10 Tevkifat
      const tadaumMizan = '''
600 YURTİÇİ SATIŞLAR 0,00 80.000,00 0,00 80.000,00
391.01 %1 TOHUM VE TARIMSAL HESAPLANAN KDV 0,00 800,00 0,00 800,00
191.01 %1 GÜBRE VE ZİRAİ İNDİRİLECEK KDV 250,00 0,00 250,00 0,00
''';

      final tadaumFaturalar = [
        {
          'firmaAdi': 'Zirai İlaçlama A.Ş.',
          'vergiTcNo': '1112223334',
          'matrahTutari': 20000.0,
          'kdvTutari': 4000.0,
          'tevkifatTutari': 1600.0,
          'tevkifatOrani': '4/10',
        },
        {
          'firmaAdi': 'Kamu Güvenlik Hizmetleri',
          'vergiTcNo': '9998887776',
          'matrahTutari': 15000.0,
          'kdvTutari': 3000.0,
          'tevkifatTutari': 3000.0,
          'tevkifatOrani': '10/10',
        },
      ];

      final tadaumSonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'TADAUM',
        aylikMizanMetni: tadaumMizan,
        yillikMizanMetni: '',
        ekTevkifatFaturalari: tadaumFaturalar,
      );

      expect(tadaumSonuc.hesaplananKdv1, 800.0);
      expect(tadaumSonuc.hesaplananKdvMatrah1, 80000.0);
      expect(tadaumSonuc.indirilecekKdv1, 250.0);
      expect(tadaumSonuc.indirilecekKdvMatrah1, 25000.0);

      // 4. Yarın eklenebilecek yepyeni birim: Ziraat_Fakultesi_Ciftlik (Sıfır Hardcode Testi)
      const yeniBirimMizan = '''
600 YURTİÇİ SATIŞLAR 0,00 120.000,00 0,00 120.000,00
123 KREDİ KARTI POS 18.000,00 0,00 18.000,00 0,00
391.01.05 %20 HESAPLANAN KDV 0,00 24.000,00 0,00 24.000,00
191.01.05 %20 İNDİRİLECEK KDV 8.000,00 0,00 8.000,00 0,00
360.03.05 ÖDEMELERDEN KESİLEN DAMGA 0,00 500,00 0,00 500,00
''';

      final yeniBirimSonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'Ziraat Fakültesi Çiftlik İşletmesi',
        aylikMizanMetni: yeniBirimMizan,
        yillikMizanMetni: '',
      );

      expect(yeniBirimSonuc.hasilat600Aylik, 120000.0);
      expect(yeniBirimSonuc.krediKarti123, 18000.0);
      expect(yeniBirimSonuc.hesaplananKdv20, 24000.0);
      expect(yeniBirimSonuc.damgaVergisi360, 500.0);

      // 5. Konsolide Ajan Raporunu Oluştur ve Denetle
      final konsolideRapor = BeyannameDenetimServisi.denetleVeRaporOlustur(
        yil: 2026,
        ay: 9,
        birimSonuclari: {
          'TÖMER': tomerSonuc,
          'Diş Hekimliği': disSonuc,
          'TADAUM': tadaumSonuc,
          'Ziraat Çiftlik': yeniBirimSonuc,
        },
        toplamDosyaSayisi: 4,
        birimOncekiAylarHasilat: {},
        oncekiAydanDevredenKdv: 10000.0,
      );

      // Denetim kontrollerinde %1 KDV sağlaması var mı?
      final kdv1Denetim = konsolideRapor.denetimKontrolleri.where((k) => k.baslik.contains('%1 KDV'));
      expect(kdv1Denetim.isNotEmpty, isTrue);

      // 6. Masalara Aktar (aiAjanVerileriniUygula)
      provider.aiAjanVerileriniUygula(konsolideRapor, uzerineEkle: false);

      // KDV 1 Masasında TADAUM %1 verileri var mı?
      final tadaumK1 = provider.kdv1Satirlari.firstWhere((x) => x.birimAdi.contains('TADAUM'));
      expect(tadaumK1.hesaplananKdv1, 800.0);
      expect(tadaumK1.indirilecekKdv1, 250.0);

      // KDV 1 Konsolide Sonucunda %1 toplamı doğru mu?
      final k1Sonuc = provider.kdv1Sonuc;
      expect(k1Sonuc.matrah1Hesaplanan, 80000.0);
      expect(k1Sonuc.kdv1Hesaplanan, 800.0);
      expect(k1Sonuc.matrah1Indirilecek, 25000.0);
      expect(k1Sonuc.kdv1Indirilecek, 250.0);

      // KDV 2 Masasında 10/10, 7/10, 4/10, 2/10 Tevkifatlar doğru toplandı mı?
      final k2Sonuc = provider.kdv2Sonuc;
      expect(k2Sonuc.turTevkifatToplam['10/10'], 3000.0);
      expect(k2Sonuc.turTevkifatToplam['7/10'], 14000.0);
      expect(k2Sonuc.turTevkifatToplam['4/10'], 1600.0);
      expect(k2Sonuc.turTevkifatToplam['2/10'], 2000.0);
      expect(k2Sonuc.butunTevkifatlarToplami, 3000.0 + 14000.0 + 1600.0 + 2000.0);

      // 7. İdempotency (Çift İşleme Koruması) Doğrulaması:
      // Kullanıcı butona 3 kez daha tıklasa bile tutarlar ASLA katlanmaz!
      provider.aiAjanVerileriniUygula(konsolideRapor, uzerineEkle: false);
      provider.aiAjanVerileriniUygula(konsolideRapor, uzerineEkle: false);

      expect(provider.kdv1Sonuc.kdv1Hesaplanan, 800.0);
      expect(provider.kdv2Sonuc.butunTevkifatlarToplami, 20600.0);
      expect(provider.hasiat600ToplamAylik, 345000.0 + 1000000.0 + 80000.0 + 120000.0);

      // 8. Excel Dışa Aktarım Simülasyonu (Hata vermeden üretilmeli)
      final excelBytes = await BeyannameExcelServisi.excelUret(provider);
      expect(excelBytes.isNotEmpty, isTrue);

      // 9. PDF Rapor Dışa Aktarım Simülasyonu
      expect(provider.birimIcmalListesi.length, 4);
    });

    test('SİMÜLASYON 2: Hatalı Birim Sıfırlama ve Belge Taşıma Simülasyonu', () {
      provider.belgeYukle(
        birimAdi: 'TÖMER',
        slotTuru: BirimBelgeSlotTuru.aylikMizan,
        dosyaAdi: 'dis_yanlislikla_tomerde.xlsx',
        dosyaBoyutu: 2048,
        dosyaUzantisi: 'xlsx',
      );

      final tomerBelgeleri = provider.getBirimBelgeleri('TÖMER');
      expect(tomerBelgeleri.length, 1);
      final belgeId = tomerBelgeleri.first.id;

      // Yanlışlıkla TÖMER'e atılan belgeyi DİŞ HEKİMLİĞİ'ne taşı
      provider.belgeBiriminiDegistir(
        eskiBirimAdi: 'TÖMER',
        yeniBirimAdi: 'Diş Hekimliği Fakültesi',
        belgeId: belgeId,
      );

      expect(provider.getBirimBelgeleri('TÖMER').isEmpty, isTrue);
      expect(provider.getBirimBelgeleri('Diş Hekimliği Fakültesi').length, 1);
      expect(provider.getBirimBelgeleri('Diş Hekimliği Fakültesi').first.dosyaAdi, 'dis_yanlislikla_tomerde.xlsx');

      // TÖMER masalarını geri çek
      provider.birimMasalariniGeriCek('TÖMER');
      final tomerK1 = provider.kdv1Satirlari.where((x) => x.birimAdi == 'TÖMER');
      if (tomerK1.isNotEmpty) {
        expect(tomerK1.first.toplamHesaplananKdv, 0.0);
      }
    });
  });
}
