import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_belge_model.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_denetim_rapor_model.dart';
import 'package:dsys_v2/features/beyanname/providers/beyanname_provider.dart';

void main() {
  group('Birim Bazlı Raporlama ve Çift İşleme (Idempotency) Koruması Testleri', () {
    late BeyannameProvider provider;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      provider = BeyannameProvider();
    });

    test('1. Her birim için ayrı rapor saklanır ve getBirimRaporu sadece o birimi döner', () {
      final tomerSonuc = BirimMizanAnalizSonucu(
        birimAdi: 'TÖMER',
        analizTarihi: DateTime.now(),
        hasilat600Aylik: 120000.0,
        hesaplananKdv20: 24000.0,
        damgaVergisi360: 450.0,
        tevkifatFaturalari: [
          {
            'firmaAdi': 'Tömer Tedarik Ltd.',
            'vergiTcNo': '1234567890',
            'matrahTutari': 10000.0,
            'kdvTutari': 2000.0,
            'tevkifatTutari': 1800.0,
            'tevkifatOrani': '9/10',
          }
        ],
      );

      final tomerRapor = BeyannameAjanRaporu(
        id: 'tomer_rapor_1',
        yil: 2026,
        ay: 9,
        olusturulmaTarihi: DateTime.now(),
        analizEdilenBirimler: ['TÖMER'],
        toplamDosyaSayisi: 2,
        birimSonuclari: {'TÖMER': tomerSonuc},
        neredenNereyeListesi: [
          const NeredenNereyeKaydi(
            birimAdi: 'TÖMER',
            kaynakBelge: 'Aylık Mizan',
            hesapKoduVeAdi: '600 Hasılat',
            bulunanTutar: 120000.0,
            hedefAlan: '600 Hasılat Masası',
          ),
        ],
        denetimKontrolleri: const [
          MutabakatKontrolKaydi(
            id: 'k1',
            senaryoNo: 1,
            birimAdi: 'TÖMER',
            baslik: '600 Hasılat Mutabakatı',
            seviye: DenetimSeviyesi.bilgi,
            aciklama: 'Mutabık',
          ),
        ],
      );

      // Provider'a raporu uygula
      provider.aiAjanVerileriniUygula(tomerRapor, uzerineEkle: false);

      // Birim sonucunu kontrol et
      final saklanan = provider.getBirimAnalizSonucu('TÖMER');
      expect(saklanan, isNotNull);
      expect(saklanan!.hasilat600Aylik, 120000.0);
      expect(saklanan.tevkifatFaturalari.length, 1);
    });

    test('2. aiAjanVerileriniUygula defalarca çağrıldığında tutarlar çiftlenmez (Idempotent)', () {
      final tomerSonuc = BirimMizanAnalizSonucu(
        birimAdi: 'TÖMER',
        analizTarihi: DateTime.now(),
        hasilat600Aylik: 100000.0,
        hasilat600Kumulatif: 500000.0,
        krediKarti123: 15000.0,
        hesaplananKdv20: 20000.0,
        damgaVergisi360: 948.0,
        tevkifatFaturalari: [
          {
            'firmaAdi': 'Temizlik Şirketi A.Ş.',
            'vergiTcNo': '9876543210',
            'matrahTutari': 5000.0,
            'kdvTutari': 1000.0,
            'tevkifatTutari': 900.0,
            'tevkifatOrani': '9/10',
          }
        ],
      );

      final rapor = BeyannameAjanRaporu(
        id: 'test_idempotent',
        yil: 2026,
        ay: 9,
        olusturulmaTarihi: DateTime.now(),
        analizEdilenBirimler: ['TÖMER'],
        toplamDosyaSayisi: 1,
        birimSonuclari: {'TÖMER': tomerSonuc},
        neredenNereyeListesi: const [],
        denetimKontrolleri: const [],
      );

      // 1. Kez uygula
      provider.aiAjanVerileriniUygula(rapor, uzerineEkle: false);
      // 2. Kez tekrar tıklandı varsayalım
      provider.aiAjanVerileriniUygula(rapor, uzerineEkle: false);
      // 3. Kez tekrar tıklandı varsayalım
      provider.aiAjanVerileriniUygula(rapor, uzerineEkle: false);

      // 600 Hasılat: 100.000 olmalı (300.000 olmamalı!)
      final hSatiri = provider.hasiat600Satirlari.firstWhere((x) => x.birimAdi == 'TÖMER');
      expect(hSatiri.aylikHasilat600, 100000.0);
      expect(hSatiri.kumulatifHasilat600, 500000.0);
      expect(hSatiri.krediKarti123, 15000.0);

      // Damga 360: 948 olmalı
      final dSatiri = provider.damgaSatirlari.firstWhere((x) => x.birimAdi == 'TÖMER');
      expect(dSatiri.damgaVergisi, 948.0);

      // KDV 1 Masası: 20.000 olmalı
      final kSatiri = provider.kdv1Satirlari.firstWhere((x) => x.birimAdi == 'TÖMER');
      expect(kSatiri.hesaplananKdv20, 20000.0);

      // KDV 2 Tevkifat Faturaları: SADECE 1 adet olmalı, 3 adet olmamalı!
      final tomerTevkifatlar = provider.tevkifatKayitlari.where((x) => x.birimAdi == 'TÖMER').toList();
      expect(tomerTevkifatlar.length, 1);
      expect(tomerTevkifatlar.first.matrahTutari, 5000.0);
      expect(tomerTevkifatlar.first.tevkifatTutari, 900.0);
    });

    test('3. tekilFaturaKaydet faturayı mükerrer yapmadan KDV 2 masasına ekler ve günceller', () {
      provider.tekilFaturaKaydet(
        birimAdi: 'TÖMER',
        faturaMap: {
          'firmaAdi': 'Kırtasiye Ltd.',
          'vergiTcNo': '5555555555',
          'matrahTutari': 2000.0,
          'kdvOrani': 20,
          'kdvTutari': 400.0,
          'tevkifatOrani': '9/10',
          'tevkifatTutari': 360.0,
        },
        masayaAktar: true,
      );

      // Aynı faturayı ufak bir düzeltmeyle tekrar kaydettiğimizde üzerine yazar, mükerrer yapmaz
      provider.tekilFaturaKaydet(
        birimAdi: 'TÖMER',
        faturaMap: {
          'firmaAdi': 'Kırtasiye Ltd. Şti.',
          'vergiTcNo': '5555555555',
          'matrahTutari': 2000.0,
          'kdvOrani': 20,
          'kdvTutari': 400.0,
          'tevkifatOrani': '9/10',
          'tevkifatTutari': 360.0,
        },
        masayaAktar: true,
      );

      final tomerFaturalar = provider.tevkifatKayitlari.where((x) => x.vergiTcNo == '5555555555').toList();
      expect(tomerFaturalar.length, 1);
      expect(tomerFaturalar.first.firmaAdi, 'Kırtasiye Ltd. Şti.');
    });

    test('4. birimMasalariniGeriCek masadaki verileri sıfırlar ancak belgeleri ve analizi korur', () {
      // 1. Önce TÖMER için belge ekle ve analiz sonucunu masaya uygula
      provider.belgeEkle(
        birimAdi: 'TÖMER',
        slotTuru: BirimBelgeSlotTuru.aylikMizan,
        dosyaAdi: 'tomer_aylik.xlsx',
        dosyaBoyutu: 1024,
        dosyaUzantisi: 'xlsx',
      );

      final tomerSonuc = BirimMizanAnalizSonucu(
        birimAdi: 'TÖMER',
        analizTarihi: DateTime.now(),
        hasilat600Aylik: 75000.0,
        hesaplananKdv20: 15000.0,
        damgaVergisi360: 300.0,
        tevkifatFaturalari: [
          {
            'firmaAdi': 'Hizmet Ltd.',
            'vergiTcNo': '1111222233',
            'matrahTutari': 10000.0,
            'kdvTutari': 2000.0,
            'tevkifatTutari': 1800.0,
          }
        ],
      );

      final rapor = BeyannameAjanRaporu(
        id: 'r_geri_cek',
        yil: 2026,
        ay: 9,
        olusturulmaTarihi: DateTime.now(),
        analizEdilenBirimler: ['TÖMER'],
        toplamDosyaSayisi: 1,
        birimSonuclari: {'TÖMER': tomerSonuc},
        neredenNereyeListesi: const [],
        denetimKontrolleri: const [],
      );
      provider.aiAjanVerileriniUygula(rapor, uzerineEkle: false);

      expect(provider.hasiat600Satirlari.firstWhere((x) => x.birimAdi == 'TÖMER').aylikHasilat600, 75000.0);
      expect(provider.tevkifatKayitlari.where((x) => x.birimAdi == 'TÖMER').length, 1);

      // 2. Şimdi masadan geri çek
      provider.birimMasalariniGeriCek('TÖMER');

      // Masadaki değerler sıfırlanmış olmalı
      final hSatiri = provider.hasiat600Satirlari.firstWhere((x) => x.birimAdi == 'TÖMER');
      expect(hSatiri.aylikHasilat600, 0.0);
      final kSatiri = provider.kdv1Satirlari.firstWhere((x) => x.birimAdi == 'TÖMER');
      expect(kSatiri.hesaplananKdv20, 0.0);
      final dSatiri = provider.damgaSatirlari.firstWhere((x) => x.birimAdi == 'TÖMER');
      expect(dSatiri.damgaVergisi, 0.0);
      expect(provider.tevkifatKayitlari.where((x) => x.birimAdi == 'TÖMER').isEmpty, isTrue);

      // Ancak yüklenen belge korunmalı
      expect(provider.getBirimBelgeleri('TÖMER').length, 1);
      expect(provider.getBirimAnalizSonucu('TÖMER'), isNotNull);
    });

    test('5. birimiTamamenSifirla hem belgeleri hem analizleri hem de masaları temizler', () {
      provider.belgeEkle(
        birimAdi: 'TÖMER',
        slotTuru: BirimBelgeSlotTuru.aylikMizan,
        dosyaAdi: 'tomer_aylik.xlsx',
        dosyaBoyutu: 1024,
        dosyaUzantisi: 'xlsx',
      );

      final tomerSonuc = BirimMizanAnalizSonucu(
        birimAdi: 'TÖMER',
        analizTarihi: DateTime.now(),
        hasilat600Aylik: 50000.0,
      );
      final rapor = BeyannameAjanRaporu(
        id: 'r_sifirla',
        yil: 2026,
        ay: 9,
        olusturulmaTarihi: DateTime.now(),
        analizEdilenBirimler: ['TÖMER'],
        toplamDosyaSayisi: 1,
        birimSonuclari: {'TÖMER': tomerSonuc},
        neredenNereyeListesi: const [],
        denetimKontrolleri: const [],
      );
      provider.aiAjanVerileriniUygula(rapor, uzerineEkle: false);

      // Tamamen sıfırla
      provider.birimiTamamenSifirla('TÖMER', masalariDaTemizle: true);

      // Belgeler ve analiz gitmiş olmalı
      expect(provider.getBirimBelgeleri('TÖMER').isEmpty, isTrue);
      expect(provider.getBirimAnalizSonucu('TÖMER'), isNull);

      // Masalardaki veriler sıfırlanmış olmalı
      final hSatiri = provider.hasiat600Satirlari.firstWhere((x) => x.birimAdi == 'TÖMER');
      expect(hSatiri.aylikHasilat600, 0.0);
    });

    test('6. belgeBiriminiDegistir yanlış birime yüklenen belgeyi başka birime taşır', () {
      provider.belgeEkle(
        birimAdi: 'TÖMER',
        slotTuru: BirimBelgeSlotTuru.aylikMizan,
        dosyaAdi: 'yanlis_yuklenen_dis_hekimligi_mizani.pdf',
        dosyaBoyutu: 2048,
        dosyaUzantisi: 'pdf',
      );

      final tomerBelgeleri = provider.getBirimBelgeleri('TÖMER');
      expect(tomerBelgeleri.length, 1);
      final belgeId = tomerBelgeleri.first.id;

      // Belgeyi DİŞ HEKİMLİĞİ'ne taşı
      provider.belgeBiriminiDegistir(
        eskiBirimAdi: 'TÖMER',
        yeniBirimAdi: 'DİŞ HEKİMLİĞİ FAKÜLTESİ',
        belgeId: belgeId,
      );

      // TÖMER'de belge kalmamış olmalı
      expect(provider.getBirimBelgeleri('TÖMER').isEmpty, isTrue);

      // DİŞ HEKİMLİĞİ'ne taşınmış olmalı
      final disBelgeleri = provider.getBirimBelgeleri('DİŞ HEKİMLİĞİ FAKÜLTESİ');
      expect(disBelgeleri.length, 1);
      expect(disBelgeleri.first.dosyaAdi, 'yanlis_yuklenen_dis_hekimligi_mizani.pdf');
      expect(disBelgeleri.first.birimAdi, 'DİŞ HEKİMLİĞİ FAKÜLTESİ');
    });

    test('7. aiAjanVerileriniUygula mizandaki Muhtasar GV ve DV stopajlarını Muhtasar masasına işler', () {
      final ubatamSonuc = BirimMizanAnalizSonucu(
        birimAdi: 'UBATAM',
        analizTarihi: DateTime.now(),
        hasilat600Aylik: 200000.0,
        damgaVergisi360: 1200.0,
        muhtasarGelir360: 7500.0,
        muhtasarDamga360: 420.0,
      );

      final rapor = BeyannameAjanRaporu(
        id: 'r_muhtasar_test',
        yil: 2026,
        ay: 9,
        olusturulmaTarihi: DateTime.now(),
        analizEdilenBirimler: ['UBATAM'],
        toplamDosyaSayisi: 1,
        birimSonuclari: {'UBATAM': ubatamSonuc},
        neredenNereyeListesi: const [],
        denetimKontrolleri: const [],
      );

      provider.aiAjanVerileriniUygula(rapor, uzerineEkle: false);

      // Muhtasar satırlarında UBATAM oluşmuş mu?
      final mSatiri = provider.muhtasarSatirlari.firstWhere((x) => x.birimAdi == 'UBATAM');
      expect(mSatiri.gelirVergisi, 7500.0);
      expect(mSatiri.damgaVergisi, 420.0);

      // Damga masasında UBATAM 360 damgası var mı?
      final dSatiri = provider.damgaSatirlari.firstWhere((x) => x.birimAdi == 'UBATAM');
      expect(dSatiri.damgaVergisi, 1200.0);

      // BirimVergiIcmalSatiri'ne yansımış mı?
      final icmal = provider.birimBazliVergiler.firstWhere((x) => x.birimAdi == 'UBATAM');
      expect(icmal.muhtasarGelir, 7500.0);
      expect(icmal.muhtasarDamga, 420.0);
      expect(icmal.muhtasarKesilenDamga, 1200.0);
    });
  });
}
