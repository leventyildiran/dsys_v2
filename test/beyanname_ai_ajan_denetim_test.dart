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

    test('190 Devreden KDV: Biri 0 Diğeri Pozitif Olduğunda Uyuşmazlık Tespiti (Senaryo 5)', () {
      final birimSonuclari = {
        'DÖSİM': BirimMizanAnalizSonucu(
          birimAdi: 'DÖSİM',
          analizTarihi: DateTime.now(),
          devredenKdv190: 25000.0, // Mizanda 25.000 TL var
        ),
      };

      // Sistemde önceki aydan devir 0.0 girilmiş
      final rapor = BeyannameDenetimServisi.denetleVeRaporOlustur(
        yil: 2026,
        ay: 9,
        birimSonuclari: birimSonuclari,
        toplamDosyaSayisi: 1,
        birimOncekiAylarHasilat: {},
        oncekiAydanDevredenKdv: 0.0,
      );

      final devirKontrol = rapor.denetimKontrolleri.firstWhere((k) => k.senaryoNo == 5);
      expect(devirKontrol.seviye, equals(DenetimSeviyesi.hata));
      expect(devirKontrol.bulunanDeger, equals(25000.0));
    });

    test('Senaryo 8: Dinamik Oran (2/10) ve Eksik VKN Kontrolü', () {
      final birimSonuclari = {
        'DÖSİM': BirimMizanAnalizSonucu(
          birimAdi: 'DÖSİM',
          analizTarihi: DateTime.now(),
          tevkifatFaturalari: [
            {
              'firmaAdi': 'Temizlik A.Ş.',
              'vergiTcNo': '', // Boş VKN!
              'matrahTutari': 10000.0,
              'kdvTutari': 2000.0,
              'tevkifatOrani': '2/10',
              'tevkifatTutari': 400.0, // 2000 * 0.2 = 400 (Doğru hesap)
            },
          ],
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

      // Boş VKN hata olarak yakalanmalı
      final vknKontrol = rapor.denetimKontrolleri.firstWhere((k) => k.senaryoNo == 8 && k.baslik.contains('Eksik VKN'));
      expect(vknKontrol.seviye, equals(DenetimSeviyesi.hata));

      // 2/10 matematiksel olarak doğru hesaplandığı için uyarı vermemeli
      final farkKontrolleri = rapor.denetimKontrolleri.where((k) => k.senaryoNo == 8 && k.baslik.contains('Hesaplama Farkı'));
      expect(farkKontrolleri, isEmpty);
    });

    test('Senaryo 9: Belge - Mizan Mutabakatı ve AI Notu Tespiti', () {
      final birimSonuclari = {
        'UBATAM': BirimMizanAnalizSonucu(
          birimAdi: 'UBATAM',
          analizTarihi: DateTime.now(),
          aciklama: 'Analiz laboratuvarına ait 15.000 TL tevkifatlı fatura mizana henüz yansımamış.',
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

      final senaryo9 = rapor.denetimKontrolleri.firstWhere((k) => k.senaryoNo == 9);
      expect(senaryo9.seviye, equals(DenetimSeviyesi.uyari));
      expect(senaryo9.aciklama, contains('yansımamış'));
    });

    test('BirimMizanAnalizSonucu.fromMap String ve Tip Güvenliği Testi', () {
      // AI bazen sayıları ve booleanları string veya formatlı döndürür
      final rawMap = {
        'birimAdi': 'UBATAM',
        'analizTarihi': '2026-09-15T10:00:00.000',
        'hasilat600Aylik': '125.500,50', // Formatlı string sayı
        'hasilat600Kumulatif': '650000.0', // Düz string sayı
        'krediKarti123': 45000, // int
        'hesaplananKdvMatrah20': '125500.50',
        'hesaplananKdv20': '25100.10',
        'yardimciMizanKullanildi': 'true', // String boolean
        'tevkifatFaturalari': [
          {
            'firmaAdi': 'X Ltd',
            'vergiTcNo': '1234567890',
            'matrahTutari': '10.000,00',
            'kdvTutari': '2.000,00',
            'tevkifatTutari': '1.800,00',
            'tevkifatOrani': '9/10',
          }
        ],
      };

      // Type cast hatası vermeden parse etmeli
      final parsed = BirimMizanAnalizSonucu.fromMap(rawMap);
      expect(parsed.hasilat600Aylik, equals(125500.50));
      expect(parsed.hasilat600Kumulatif, equals(650000.0));
      expect(parsed.krediKarti123, equals(45000.0));
      expect(parsed.yardimciMizanKullanildi, isTrue);
      expect(parsed.tevkifatFaturalari.first['matrahTutari'], equals(10000.0));
      expect(parsed.tevkifatFaturalari.first['tevkifatTutari'], equals(1800.0));
    });
  });
}
