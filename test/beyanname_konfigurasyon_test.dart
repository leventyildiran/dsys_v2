import 'package:flutter_test/flutter_test.dart';

import 'package:dsys_v2/features/beyanname/models/beyanname_konfigurasyonu.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_model.dart';
import 'package:dsys_v2/features/beyanname/services/beyanname_dogrulama.dart';
import 'package:dsys_v2/features/beyanname/services/beyanname_hesaplama_motoru.dart';

/// Faz 0 parite testleri.
///
/// Amaç: yeni `BeyannameKonfigurasyonu` varsayılanlarının, refactor öncesi
/// kod içine gömülü sabit değerlerle **birebir aynı** olduğunu kanıtlamak.
/// Böylece esneklik altyapısı eklenirken mevcut tek-kurum davranışı bozulmaz.
void main() {
  group('Config varsayılanı — bugünkü sabitlerle parite', () {
    test('damga oranı binde 9,48 / kesir 0,00948', () {
      expect(BeyannameKonfigurasyonu.varsayilanDamgaBinde, 9.48);
      expect(
        BeyannameKonfigurasyonu.varsayilanDamgaOrani,
        closeTo(0.00948, 1e-12),
      );
    });

    test('KDV oran seti %10 ve %20', () {
      final oranlar = BeyannameKonfigurasyonu.varsayilan.kdvOranlari
          .map((o) => o.oran)
          .toList();
      expect(oranlar, [10, 20]);
    });

    test('oranKesri doğru; tanımsız oran oran/100 döner', () {
      final k = BeyannameKonfigurasyonu.varsayilan;
      expect(k.oranKesri(10), 0.10);
      expect(k.oranKesri(20), 0.20);
      expect(k.oranKesri(99), closeTo(0.99, 1e-12));
    });

    test('tevkifat varsayılanları 9/10, 7/10, 5/10', () {
      final etiketler = BeyannameKonfigurasyonu.varsayilan.tevkifatTurleri
          .map((t) => t.etiket)
          .toList();
      expect(etiketler, ['9/10', '7/10', '5/10']);
      expect(
        BeyannameKonfigurasyonu.varsayilan.tevkifatTurleri.first.oran,
        closeTo(0.9, 1e-12),
      );
    });

    test('bloklar varsayılan hepsi açık', () {
      final b = BeyannameKonfigurasyonu.varsayilan.bloklar;
      expect(
        b.kdv1 &&
            b.kdv2 &&
            b.muhtasar &&
            b.damga301 &&
            b.damga302 &&
            b.hasiat600 &&
            b.krediKarti123,
        isTrue,
      );
    });
  });

  group('Damga hesabı — eski formülle birebir', () {
    test('matrahFromDamga varsayılan = eski 1000/9,48 formülü', () {
      // 94.800 TL damga -> binde 9,48 ile 10.000.000 TL matrah
      expect(BeyannameHesaplamaMotoru.matrahFromDamga(94800), 10000000.0);
      expect(
        BeyannameHesaplamaMotoru.matrahFromDamga(94800, binde: 9.48),
        10000000.0,
      );
    });

    test('damgaFromMatrah varsayılan = eski 0,00948 formülü', () {
      expect(BeyannameHesaplamaMotoru.damgaFromMatrah(10000000), 94800.0);
    });

    test('sıfır / negatif girişlerde güvenli', () {
      expect(BeyannameHesaplamaMotoru.matrahFromDamga(0), 0.0);
      expect(BeyannameHesaplamaMotoru.matrahFromDamga(-5), 0.0);
      expect(BeyannameHesaplamaMotoru.damgaFromMatrah(0), 0.0);
      expect(BeyannameHesaplamaMotoru.damgaFromMatrah(-5), 0.0);
    });
  });

  group('Doğrulama — config ile parite', () {
    List<Kdv1BirimSatiri> satirlar() => [
          const Kdv1BirimSatiri(
            birimId: 'ubatam',
            birimAdi: 'UBATAM',
            hesaplananMatrah20: 1000,
            hesaplananKdv20: 200,
          ),
        ];

    test('varsayılan config verilmediğinde de aynı sonucu verir', () {
      final a = BeyannameDogrulama.denetle(
        kdv1: satirlar(),
        tevkifat: const [],
        muhtasar: const [],
        hasiat600: const [],
      );
      final b = BeyannameDogrulama.denetle(
        kdv1: satirlar(),
        tevkifat: const [],
        muhtasar: const [],
        hasiat600: const [],
        konfig: BeyannameKonfigurasyonu.varsayilan,
      );
      expect(a.length, b.length);
      expect(BeyannameDogrulama.sayi(a, UyariSeviye.hata), 0);
    });

    test('özel KDV etiketi uyarı başlığına yansır', () {
      final k = BeyannameKonfigurasyonu(
        kdvOranlari: const [
          KdvOranTanimi(oran: 20, etiket: '%20 (genel)'),
        ],
      );
      final u = BeyannameDogrulama.denetle(
        kdv1: [
          const Kdv1BirimSatiri(
            birimId: 'x',
            birimAdi: 'X',
            hesaplananMatrah20: 1000,
            hesaplananKdv20: 0,
          ),
        ],
        tevkifat: const [],
        muhtasar: const [],
        hasiat600: const [],
        konfig: k,
      );
      expect(u.any((x) => x.baslik.contains('%20 (genel)')), isTrue);
    });
  });

  group('Serileştirme (Faz 1 hazırlığı)', () {
    test('toMap/fromMap round-trip değerleri korur', () {
      const orijinal = BeyannameKonfigurasyonu(
        kurumId: 'test-kurum',
        kdvOranlari: [
          KdvOranTanimi(oran: 1),
          KdvOranTanimi(oran: 8),
          KdvOranTanimi(oran: 20),
        ],
        tevkifatTurleri: [
          TevkifatTanimi(etiket: '4/10', pay: 4, payda: 10),
        ],
        damgaBinde: 7.59,
        bloklar: BeyannameBloklari(krediKarti123: false),
      );

      final tekrar = BeyannameKonfigurasyonu.fromMap(orijinal.toMap());

      expect(tekrar.kurumId, 'test-kurum');
      expect(tekrar.damgaBinde, 7.59);
      expect(tekrar.kdvOranlari.map((o) => o.oran).toList(), [1, 8, 20]);
      expect(tekrar.tevkifatTurleri.first.etiket, '4/10');
      expect(tekrar.bloklar.krediKarti123, isFalse);
      expect(tekrar.bloklar.kdv1, isTrue);
    });
  });
}
