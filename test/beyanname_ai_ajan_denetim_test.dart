import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_belge_model.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_denetim_rapor_model.dart';
import 'package:dsys_v2/features/beyanname/services/beyanname_denetim_servisi.dart';
import 'package:dsys_v2/features/beyanname/services/mizan_deterministik_parser.dart';

void main() {
  group('BeyannameDenetimServisi VKN & TCKN Doğrulama Testleri', () {
    test('Geçerli ve geçersiz VKN kontrolleri (Resmi GİB MOD-10)', () {
      // Geçersiz formatlar
      expect(BeyannameDenetimServisi.dogrulaVkn(''), isFalse);
      expect(BeyannameDenetimServisi.dogrulaVkn('123'), isFalse);
      expect(BeyannameDenetimServisi.dogrulaVkn('12345678901'), isFalse);
      expect(BeyannameDenetimServisi.dogrulaVkn('ABCDEFGHIJ'), isFalse);
      expect(BeyannameDenetimServisi.dogrulaVkn('1111111111'), isFalse);
      expect(BeyannameDenetimServisi.dogrulaVkn('0000000000'), isFalse);

      // Gerçek resmi firma VKN'leri (GİB algoritmasıyla doğrulanmalı)
      expect(BeyannameDenetimServisi.dogrulaVkn('4110649065'), isTrue); // Grand Dental
      expect(BeyannameDenetimServisi.dogrulaVkn('6191268620'), isTrue); // Metasoft
      expect(BeyannameDenetimServisi.dogrulaVkn('6210490464'), isTrue); // Miroğlu
      expect(BeyannameDenetimServisi.dogrulaVkn('8340057092'), isTrue); // Kone Asansör
      expect(BeyannameDenetimServisi.dogrulaVkn('8960855757'), isTrue); // Trakya Üniv. DÖSİM
      expect(BeyannameDenetimServisi.dogrulaVkn('8960706737'), isTrue); // Trakya Üniv.

      // OCR hatalı VKN (son iki hane bozuk) reddedilmeli
      expect(BeyannameDenetimServisi.dogrulaVkn('4110649031'), isFalse);
    });

    test('Geçerli ve geçersiz TCKN kontrolleri', () {
      expect(BeyannameDenetimServisi.dogrulaTckn(''), isFalse);
      expect(BeyannameDenetimServisi.dogrulaTckn('01234567890'), isFalse); // 0 ile başlayamaz
      expect(BeyannameDenetimServisi.dogrulaTckn('1234567890'), isFalse); // 10 hane olamaz
      expect(BeyannameDenetimServisi.dogrulaTckn('11111111110'), isFalse); // Tekdüze rakam olamaz
    });
  });

  group('MizanDeterministikParser Otomatik Hesaplama ve Belge Tanıma Testleri', () {
    test('Excel Pipe (|) Formatlı Mizan ve Yardımcı Mizan %10 / %20 KDV Ayrıştırma', () {
      const aylikMizanText = '''
HESAP KODU | HESAP ADI | BORÇ | ALACAK | BORÇ BAKİYESİ | ALACAK BAKİYESİ
123 | KREDİ KARTLARINDAN ALACAKLAR | 45.000,00 | 15.000,00 | 30.000,00 | 0,00
190 | DEVREDEN KDV | 12.500,00 | 0,00 | 12.500,00 | 0,00
191 | İNDİRİLECEK KDV | 8.000,00 | 0,00 | 8.000,00 | 0,00
360 | ÖDENECEK VERGİ VE FONLAR | 0,00 | 450,50 | 0,00 | 450,50
360.03 | ÖDENECEK DAMGA VERGİSİ | 0,00 | 450,50 | 0,00 | 450,50
391 | HESAPLANAN KDV | 0,00 | 25.000,00 | 0,00 | 25.000,00
600 | YURTİÇİ SATIŞLAR | 0,00 | 150.000,00 | 0,00 | 150.000,00
''';

      const yardimciMizanText = '''
391.01.04 %10 HESAPLANAN KDV | 0,00 | 5.000,00 | 0,00 | 5.000,00
391.01.05 %20 HESAPLANAN KDV | 0,00 | 20.000,00 | 0,00 | 20.000,00
191.01.04 %10 İNDİRİLECEK KDV | 2.000,00 | 0,00 | 2.000,00 | 0,00
191.01.05 %20 İNDİRİLECEK KDV | 6.000,00 | 0,00 | 6.000,00 | 0,00
''';

      const yillikMizanText = '''
600 | YURTİÇİ SATIŞLAR | 0,00 | 850.000,00 | 0,00 | 850.000,00
''';

      final sonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'DİŞ HEKİMLİĞİ',
        aylikMizanMetni: aylikMizanText,
        yillikMizanMetni: yillikMizanText,
        yardimciMizanMetni: yardimciMizanText,
      );

      expect(sonuc.hasilat600Aylik, closeTo(150000.0, 0.01));
      expect(sonuc.hasilat600Kumulatif, closeTo(850000.0, 0.01));
      expect(sonuc.krediKarti123, closeTo(45000.0, 0.01)); // 123 Borç hareketi
      expect(sonuc.devredenKdv190, closeTo(12500.0, 0.01));
      expect(sonuc.damgaVergisi360, closeTo(450.50, 0.01));

      // Yardımcı mizandan %10 ve %20 kırılımı doğru alınmalı
      expect(sonuc.hesaplananKdv10, closeTo(5000.0, 0.01));
      expect(sonuc.hesaplananKdvMatrah10, closeTo(50000.0, 0.01));
      expect(sonuc.hesaplananKdv20, closeTo(20000.0, 0.01));
      expect(sonuc.hesaplananKdvMatrah20, closeTo(100000.0, 0.01));

      expect(sonuc.indirilecekKdv10, closeTo(2000.0, 0.01));
      expect(sonuc.indirilecekKdv20, closeTo(6000.0, 0.01));
    });

    test('Tevkifat Faturası Deterministik Okuma (Grand Dental VKN & 7/10 Oran)', () {
      const faturaText = '''
e-Fatura
SATICI:
GRAND DENTAL MEDİKAL SAN. VE TİC. LTD. ŞTİ.
Vergi No: 4110649065
ALICI:
TRAKYA ÜNİVERSİTESİ AĞIZ VE DİŞ SAĞLIĞI UYGULAMA VE ARAŞTIRMA MERKEZİ
VKN: 8960855757
Mal Hizmet Toplam Tutarı: 10.000,00 TL
Hesaplanan KDV (%20): 2.000,00 TL
KDV Tevkifat (7/10): 1.400,00 TL
Ödenecek Tutar: 10.600,00 TL
''';

      final faturalar = MizanDeterministikParser.parseTevkifatFaturalari(faturaText);
      expect(faturalar.length, equals(1));
      expect(faturalar.first['vergiTcNo'], equals('4110649065'));
      expect(faturalar.first['tevkifatOrani'], equals('7/10'));
      expect(faturalar.first['matrahTutari'], closeTo(10000.0, 0.01));
      expect(faturalar.first['kdvTutari'], closeTo(2000.0, 0.01));
      expect(faturalar.first['tevkifatTutari'], closeTo(1400.0, 0.01));
    });

    test('Otomatik Belge Sınıflandırma (Birim ve Slot Tespiti)', () {
      final aktifBirimler = ['DÖSİM', 'UBATAM', 'DİŞ HEKİMLİĞİ', 'TÖMER'];

      final s1 = MizanDeterministikParser.otomatikBelgeSiniflandir(
        dosyaAdi: 'UBATAM_Ocak_Subat_Kumulatif_Mizan.xlsx',
        metin: 'Başlangıç Tarihi: 01.01.2026 Bitiş: 30.09.2026\n600 YURTİÇİ SATIŞLAR',
        aktifBirimler: aktifBirimler,
      );
      expect(s1.birimAdi, equals('UBATAM'));
      expect(s1.slotTuru, equals(BirimBelgeSlotTuru.yillikMizan));

      final s2 = MizanDeterministikParser.otomatikBelgeSiniflandir(
        dosyaAdi: 'Dis_Hekimligi_Tevkifat_Fatura.pdf',
        metin: 'e-Fatura Senaryo: TICARIFATURA Tevkifat Oranı: 9/10',
        aktifBirimler: aktifBirimler,
      );
      expect(s2.birimAdi, equals('DİŞ HEKİMLİĞİ'));
      expect(s2.slotTuru, equals(BirimBelgeSlotTuru.diger));
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
