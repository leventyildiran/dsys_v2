import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_belge_model.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_denetim_rapor_model.dart';
import 'package:dsys_v2/features/beyanname/services/beyanname_denetim_servisi.dart';

void main() {
  group('BeyannameDenetimServisi VKN & TCKN Doğrulama Testleri', () {
    test('Geçerli ve geçersiz VKN kontrolleri', () {
      // Geçersiz formatlar
      expect(BeyannameDenetimServisi.dogrulaVkn(''), isFalse);
      expect(BeyannameDenetimServisi.dogrulaVkn('123'), isFalse);
      expect(BeyannameDenetimServisi.dogrulaVkn('12345678901'), isFalse);
      expect(BeyannameDenetimServisi.dogrulaVkn('ABCDEFGHIJ'), isFalse);

      // Algoritmik geçerli VKN (örneğin bilinen resmi VKN'ler)
      // Test matematiksel algoritma tutarlılığı
      expect(BeyannameDenetimServisi.dogrulaVkn('1111111111'), isFalse);
    });

    test('Geçerli ve geçersiz TCKN kontrolleri', () {
      expect(BeyannameDenetimServisi.dogrulaTckn(''), isFalse);
      expect(BeyannameDenetimServisi.dogrulaTckn('01234567890'), isFalse); // 0 ile başlayamaz
      expect(BeyannameDenetimServisi.dogrulaTckn('1234567890'), isFalse); // 10 hane olamaz
      expect(BeyannameDenetimServisi.dogrulaTckn('11111111110'), isFalse); // Algoritma tutarsız
    });
  });

  group('9 Senaryolu Çapraz Denetim ve Mutabakat Testleri', () {
    test('Aylık ve Yıllık Mizan Tam Mutabakat Senaryosu', () {
      final birimSonuclari = {
        'DÖSİM': BirimMizanAnalizSonucu(
          birimAdi: 'DÖSİM',
          analizTarihi: DateTime.now(),
          hasilat600Aylik: 50000.0,
          hasilat600Kumulatif: 250000.0,
          krediKarti123: 15000.0,
          hesaplananKdvMatrah20: 50000.0,
          hesaplananKdv20: 10000.0,
          indirilecekKdvMatrah20: 20000.0,
          indirilecekKdv20: 4000.0,
          damgaVergisi360: 94.8,
          damgaMatrah: 10000.0,
          devredenKdv190: 5000.0,
        ),
      };

      // Önceki aylar toplamı: 200.000 TL + Bu ay 50.000 TL = 250.000 TL (Kümülatif ile tam eşit)
      final rapor = BeyannameDenetimServisi.denetleVeRaporOlustur(
        yil: 2026,
        ay: 9,
        birimSonuclari: birimSonuclari,
        toplamDosyaSayisi: 2,
        birimOncekiAylarHasilat: {'DÖSİM': 200000.0},
        oncekiAydanDevredenKdv: 5000.0,
      );

      expect(rapor.kritikHataSayisi, equals(0));
      expect(rapor.neredenNereyeListesi.isNotEmpty, isTrue);

      // Kümülatif kontrolünün başarılı olduğunu teyit et
      final kumulatifKontrol = rapor.denetimKontrolleri.firstWhere((k) => k.senaryoNo == 2);
      expect(kumulatifKontrol.seviye, equals(DenetimSeviyesi.bilgi));
    });

    test('Kümülatif Hasılat Uyuşmazlığı Tespiti (Senaryo 2)', () {
      final birimSonuclari = {
        'UBATAM': BirimMizanAnalizSonucu(
          birimAdi: 'UBATAM',
          analizTarihi: DateTime.now(),
          hasilat600Aylik: 100000.0,
          hasilat600Kumulatif: 800000.0, // Beklenen: 500k + 100k = 600k (Fark: 200k!)
        ),
      };

      final rapor = BeyannameDenetimServisi.denetleVeRaporOlustur(
        yil: 2026,
        ay: 9,
        birimSonuclari: birimSonuclari,
        toplamDosyaSayisi: 2,
        birimOncekiAylarHasilat: {'UBATAM': 500000.0},
        oncekiAydanDevredenKdv: 0.0,
      );

      final hataKontrol = rapor.denetimKontrolleri.firstWhere((k) => k.senaryoNo == 2);
      expect(hataKontrol.seviye, equals(DenetimSeviyesi.hata));
      expect(hataKontrol.fark, equals(-200000.0));
      expect(rapor.kritikHataSayisi, greaterThanOrEqualTo(1));
    });

    test('Ters Bakiye Tespiti (Senaryo 6)', () {
      final birimSonuclari = {
        'DTS': BirimMizanAnalizSonucu(
          birimAdi: 'DTS',
          analizTarihi: DateTime.now(),
          hasilat600Aylik: 40000.0,
          hasilat600Kumulatif: 40000.0,
          hamJson: {
            'is191TersBakiye': true, // 191 ters alacak bakiyesi verdi!
          },
        ),
      };

      final rapor = BeyannameDenetimServisi.denetleVeRaporOlustur(
        yil: 2026,
        ay: 9,
        birimSonuclari: birimSonuclari,
        toplamDosyaSayisi: 1,
        birimOncekiAylarHasilat: {},
        oncekiAydanDevredenKdv: 0.0,
      );

      final tersBakiyeKontrol = rapor.denetimKontrolleri.firstWhere((k) => k.senaryoNo == 6);
      expect(tersBakiyeKontrol.seviye, equals(DenetimSeviyesi.hata));
      expect(tersBakiyeKontrol.baslik, contains('191'));
    });

    test('190 Devreden KDV Uyuşmazlığı (Senaryo 5)', () {
      final birimSonuclari = {
        'DÖSİM': BirimMizanAnalizSonucu(
          birimAdi: 'DÖSİM',
          analizTarihi: DateTime.now(),
          devredenKdv190: 12000.0, // Mizanda 12.000 TL devir var
        ),
      };

      final rapor = BeyannameDenetimServisi.denetleVeRaporOlustur(
        yil: 2026,
        ay: 9,
        birimSonuclari: birimSonuclari,
        toplamDosyaSayisi: 1,
        birimOncekiAylarHasilat: {},
        oncekiAydanDevredenKdv: 10000.0, // Önceki ay beyannamesinde 10.000 TL devretmişti (2000 TL fark!)
      );

      final devirKontrol = rapor.denetimKontrolleri.firstWhere((k) => k.senaryoNo == 5);
      expect(devirKontrol.seviye, equals(DenetimSeviyesi.hata));
      expect(devirKontrol.fark, equals(2000.0));
    });
  });
}
