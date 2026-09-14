import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_model.dart';
import 'package:dsys_v2/features/beyanname/services/beyanname_dogrulama.dart';

/// `BeyannameDogrulama` saf (pure) olduğu için kolayca test edilebilir.
/// Amaç: kullanıcıyı hatadan koruyan uyarıların **doğru** üretildiğini
/// kanıtlamak ve yanlış alarm (false positive) vermediğini göstermek.
void main() {
  const bosTevkifat = <TevkifatFirmaKaydi>[];
  const bosMuhtasar = <MuhtasarSatiri>[];
  const bosHasiat = <Hasiat600BirimSatiri>[];

  group('BeyannameDogrulama — KDV 1', () {
    test('Tutarlı matrah/KDV girildiğinde uyarı üretmez', () {
      final uyarilar = BeyannameDogrulama.denetle(
        kdv1: const [
          Kdv1BirimSatiri(
            birimId: 'ubatam',
            birimAdi: 'UBATAM',
            hesaplananMatrah20: 100000,
            hesaplananKdv20: 20000,
          ),
        ],
        tevkifat: bosTevkifat,
        muhtasar: bosMuhtasar,
        hasiat600: bosHasiat,
      );
      expect(uyarilar, isEmpty);
    });

    test('KDV tutarı oranla uyuşmuyorsa hata üretir', () {
      final uyarilar = BeyannameDogrulama.denetle(
        kdv1: const [
          Kdv1BirimSatiri(
            birimId: 'ubatam',
            birimAdi: 'UBATAM',
            hesaplananMatrah20: 100000,
            hesaplananKdv20: 10000, // %20 için 20.000 olmalıydı
          ),
        ],
        tevkifat: bosTevkifat,
        muhtasar: bosMuhtasar,
        hasiat600: bosHasiat,
      );
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.hata), 1);
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.dikkat), 0);
    });

    test('Matrah girilip KDV boş bırakılırsa dikkat üretir', () {
      final uyarilar = BeyannameDogrulama.denetle(
        kdv1: const [
          Kdv1BirimSatiri(
            birimId: 'tomer',
            birimAdi: 'TÖMER',
            hesaplananMatrah20: 50000,
            hesaplananKdv20: 0,
          ),
        ],
        tevkifat: bosTevkifat,
        muhtasar: bosMuhtasar,
        hasiat600: bosHasiat,
      );
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.dikkat), 1);
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.hata), 0);
    });

    test('İndirilecek KDV fazlaysa devreden bilgi notu üretir', () {
      final uyarilar = BeyannameDogrulama.denetle(
        kdv1: const [
          Kdv1BirimSatiri(
            birimId: 'usem',
            birimAdi: 'USEM',
            hesaplananMatrah20: 1000,
            hesaplananKdv20: 200,
            indirilecekMatrah20: 10000,
            indirilecekKdv20: 2000,
          ),
        ],
        tevkifat: bosTevkifat,
        muhtasar: bosMuhtasar,
        hasiat600: bosHasiat,
      );
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.bilgi), 1);
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.hata), 0);
    });
  });

  group('BeyannameDogrulama — KDV 2 Tevkifat', () {
    test('Tevkifat tutarı KDV tutarından büyükse hata üretir', () {
      final uyarilar = BeyannameDogrulama.denetle(
        kdv1: const [],
        tevkifat: const [
          TevkifatFirmaKaydi(
            id: '1',
            firmaAdi: 'ÖRNEK A.Ş.',
            vergiTcNo: '1234567890',
            tevkifatTuru: TevkifatTuru.dokuzBoluOn,
            kdvOrani: 20,
            matrahTutari: 100000,
            kdvTutari: 20000,
            tevkifatTutari: 30000, // KDV'yi aşamaz
          ),
        ],
        muhtasar: bosMuhtasar,
        hasiat600: bosHasiat,
      );
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.hata), 1);
    });

    test('Doğru tevkifat oranı girildiğinde hata üretmez', () {
      final uyarilar = BeyannameDogrulama.denetle(
        kdv1: const [],
        tevkifat: const [
          TevkifatFirmaKaydi(
            id: '2',
            firmaAdi: 'DOĞRU LTD.',
            vergiTcNo: '9876543210',
            tevkifatTuru: TevkifatTuru.dokuzBoluOn,
            kdvOrani: 20,
            matrahTutari: 100000,
            kdvTutari: 20000,
            tevkifatTutari: 18000, // 20.000 * 9/10
          ),
        ],
        muhtasar: bosMuhtasar,
        hasiat600: bosHasiat,
      );
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.hata), 0);
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.dikkat), 0);
    });
  });

  group('BeyannameDogrulama — Muhtasar', () {
    test('Net ödenen brüt ücretten büyükse hata üretir', () {
      final uyarilar = BeyannameDogrulama.denetle(
        kdv1: const [],
        tevkifat: bosTevkifat,
        muhtasar: const [
          MuhtasarSatiri(
            id: '3',
            birimAdi: 'DTS',
            adSoyad: 'ALİ VELİ',
            brutUcret: 10000,
            gelirVergisi: 1500,
            netOdenen: 12000,
          ),
        ],
        hasiat600: bosHasiat,
      );
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.hata), 1);
    });

    test('Gelir vergisi boşsa dikkat üretir', () {
      final uyarilar = BeyannameDogrulama.denetle(
        kdv1: const [],
        tevkifat: bosTevkifat,
        muhtasar: const [
          MuhtasarSatiri(
            id: '4',
            birimAdi: 'DTS',
            adSoyad: 'AYŞE KAYA',
            brutUcret: 10000,
            gelirVergisi: 0,
            netOdenen: 8000,
          ),
        ],
        hasiat600: bosHasiat,
      );
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.dikkat), 1);
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.hata), 0);
    });
  });

  group('BeyannameDogrulama — 600 Hasılat', () {
    test('Kümülatif hasılat aylıktan küçükse hata üretir', () {
      final uyarilar = BeyannameDogrulama.denetle(
        kdv1: const [],
        tevkifat: bosTevkifat,
        muhtasar: bosMuhtasar,
        hasiat600: const [
          Hasiat600BirimSatiri(
            birimAdi: 'USEM',
            oncekiAylarHasilat600: 0,
            aylikHasilat600: 5000,
            kumulatifHasilat600: 1000,
          ),
        ],
      );
      expect(BeyannameDogrulama.sayi(uyarilar, UyariSeviye.hata), 1);
    });
  });

  group('BeyannameDogrulama — Boş giriş', () {
    test('Hiç veri girilmemişse uyarı üretmez', () {
      final uyarilar = BeyannameDogrulama.denetle(
        kdv1: const [],
        tevkifat: bosTevkifat,
        muhtasar: bosMuhtasar,
        hasiat600: bosHasiat,
      );
      expect(uyarilar, isEmpty);
    });
  });
}
