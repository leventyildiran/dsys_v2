import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_belge_model.dart';
import 'package:dsys_v2/features/beyanname/models/beyanname_denetim_rapor_model.dart';
import 'package:dsys_v2/features/beyanname/services/beyanname_denetim_servisi.dart';
import 'package:dsys_v2/features/beyanname/services/mizan_deterministik_parser.dart';
import 'package:dsys_v2/features/fatura/services/yerel_ocr/gib_karekod_ve_ubl_cozucu.dart';

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
      expect(sonuc.krediKarti123, closeTo(30000.0, 0.01)); // 123 Borç Kalan (Bakiye)
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

    test('Senaryo 11: İki Birim Arasında Mükerrer 123 POS Tahsilat Tespiti', () {
      final birimSonuclari = {
        'Ağız ve Diş Sağlığı': BirimMizanAnalizSonucu(
          birimAdi: 'Ağız ve Diş Sağlığı',
          analizTarihi: DateTime.now(),
          krediKarti123: 3325718.15,
        ),
        'DTS': BirimMizanAnalizSonucu(
          birimAdi: 'DTS',
          analizTarihi: DateTime.now(),
          krediKarti123: 3325718.15, // Aynı tutar!
        ),
      };

      final rapor = BeyannameDenetimServisi.denetleVeRaporOlustur(
        yil: 2026,
        ay: 10,
        birimSonuclari: birimSonuclari,
        toplamDosyaSayisi: 2,
        birimOncekiAylarHasilat: {},
        oncekiAydanDevredenKdv: 0.0,
      );

      final senaryo11 = rapor.denetimKontrolleri.where((k) => k.senaryoNo == 11).firstOrNull;
      expect(senaryo11, isNotNull);
      expect(senaryo11!.seviye, equals(DenetimSeviyesi.hata));
      expect(senaryo11.baslik, contains('Mükerrer 123 POS'));
      expect(senaryo11.bulunanDeger, equals(3325718.15));
    });

    test('Konsolide Mizan Koruması: DTS yanlış yüklenen kurum mizanından 123 POS devralamaz', () {
      // 17 sayfalık konsolide kurum mizanı (600: 11.85M, 123: 3.32M)
      const konsolideMizanMetni = '''
123 BANKA KREDİ KARTLARINDAN ALACAKLAR HESABI 3.325.718,15 4.514.188,95 0,00 1.188.470,80
600 GELİRLER HESABI 0,00 11.852.016,76 0,00 11.852.016,76
''';
      // DTS'nin gerçek yıllık mizanı (600: 1.14M, 123: YOK)
      const dtsYillikMetin = '''
600 GELİRLER HESABI 0,00 1.147.750,00 0,00 1.147.750,00
''';

      final dtsSonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'Deri, Tekstil ve Seramik Tasarım Uygulama ve Araştırma Merkezi (DTS)',
        aylikMizanMetni: konsolideMizanMetni,
        yillikMizanMetni: dtsYillikMetin,
        oncekiAylarHasilat: 0.0,
      );

      // DTS'nin hasılatı kendi mizanı (1.14M) olmalı, konsolide mizan (11.8M) DTS'yi ezmemeli
      expect(dtsSonuc.hasilat600Kumulatif, equals(1147750.00));
      // DTS sağlık/hasta polikliniği olmadığı için 123 POS kesinlikle 0 TL olmalı
      expect(dtsSonuc.krediKarti123, equals(0.0));

      // Aynı konsolide mizan Diş Hekimliği için analiz edildiğinde Diş kendi POS'unu alır
      final disSonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'Ağız ve Diş Sağlığı Uygulama ve Araştırma Merkezi',
        aylikMizanMetni: konsolideMizanMetni,
        yillikMizanMetni: dtsYillikMetin,
        oncekiAylarHasilat: 0.0,
      );
      expect(disSonuc.krediKarti123, equals(3325718.15));
    });

    test('Tek Faturada 3 Farklı Tevkifat Oranı (9/10, 7/10, 5/10) ve %10 KDV Okuma', () {
      const cokluOranFaturaText = '''
e-Fatura
Fatura No: GİB2026000001234
SATICI:
GRAND DENTAL MEDİKAL SAN. VE TİC. LTD. ŞTİ.
Vergi No: 4110649065
ALICI:
TRAKYA ÜNİVERSİTESİ AĞIZ VE DİŞ SAĞLIĞI UYGULAMA VE ARAŞTIRMA MERKEZİ
VKN: 8960855757
KDV Tevkifat Özeti:
1) Temizlik Hizmeti %20 KDV 9/10 10.000,00 2.000,00 1.800,00
2) Bakım Onarım %20 KDV 7/10 5.000,00 1.000,00 700,00
3) Tıbbi Sarf Malzeme %10 KDV 5/10 20.000,00 2.000,00 1.000,00
''';

      final faturalar = MizanDeterministikParser.parseTevkifatFaturalari(cokluOranFaturaText);
      expect(faturalar.length, equals(3));

      final f910 = faturalar.firstWhere((f) => f['tevkifatOrani'] == '9/10');
      expect(f910['vergiTcNo'], equals('4110649065'));
      expect(f910['matrahTutari'], closeTo(10000.0, 0.01));
      expect(f910['kdvTutari'], closeTo(2000.0, 0.01));
      expect(f910['tevkifatTutari'], closeTo(1800.0, 0.01));
      expect(f910['kdvOrani'], equals(20));

      final f710 = faturalar.firstWhere((f) => f['tevkifatOrani'] == '7/10');
      expect(f710['matrahTutari'], closeTo(5000.0, 0.01));
      expect(f710['kdvTutari'], closeTo(1000.0, 0.01));
      expect(f710['tevkifatTutari'], closeTo(700.0, 0.01));
      expect(f710['kdvOrani'], equals(20));

      final f510 = faturalar.firstWhere((f) => f['tevkifatOrani'] == '5/10');
      expect(f510['matrahTutari'], closeTo(20000.0, 0.01));
      expect(f510['kdvTutari'], closeTo(2000.0, 0.01));
      expect(f510['tevkifatTutari'], closeTo(1000.0, 0.01));
      expect(f510['kdvOrani'], equals(10));

      // Aynı faturaNo'ya sahip farklı oranlı satırlar mükerrer sayılmamalı
      expect(BirimMizanAnalizSonucu.tevkifatSatiriMukerrerMi(f910, f710), isFalse);
      expect(BirimMizanAnalizSonucu.tevkifatSatiriMukerrerMi(f710, f510), isFalse);
      expect(BirimMizanAnalizSonucu.tevkifatSatiriMukerrerMi(f510, Map<String, dynamic>.from(f510)), isTrue);
    });

    test('Diş Hekimliği İhale Damga Vergisi (360.03.02 Karar Pulu & 360.03.03 Sözleşme) Okuma', () {
      const disMizanText = '''
HESAP KODU | HESAP ADI | BORÇ | ALACAK | BORÇ BAKİYESİ | ALACAK BAKİYESİ
360.03 | ÖDENECEK DAMGA VERGİSİ | 0,00 | 18.670,00 | 0,00 | 18.670,00
360.03.02 | İHALE KARAR PULU (BİNDE 5,69) | 0,00 | 5.690,00 | 0,00 | 5.690,00
360.03.03 | SÖZLEŞME DAMGA VERGİSİ (BİNDE 9,48) | 0,00 | 9.480,00 | 0,00 | 9.480,00
360.03.05 | ÖDEMELERDEN KESİLEN DAMGA VERGİSİ | 0,00 | 3.500,00 | 0,00 | 3.500,00
''';

      final disSonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'DİŞ HEKİMLİĞİ',
        aylikMizanMetni: disMizanText,
        yillikMizanMetni: '',
      );

      // Ebeveyn 360.03 ile alt hesaplar çift toplanmamalı;
      // 360.03.05 birim hakediş damgası olarak (3.500 TL),
      // 360.03.02 ve 360.03.03 ise ihale damga vergisi alanlarına ayrışmalı!
      expect(disSonuc.damgaVergisi360, closeTo(3500.0, 0.01));
      expect(disSonuc.ihaleKararPuluDamga360, closeTo(5690.0, 0.01));
      expect(disSonuc.ihaleSozlesmeDamga360, closeTo(9480.0, 0.01));
    });

    test('DÖSİM Mizanında Beyanname Ödeme Hareketleri (Borç > 0) ve Ebeveyn-Alt Hesap Çift Sayım Koruması', () {
      // DÖSİM mizanında önceki ayların beyanname ödemeleri Borç (50.000 TL) olarak yansımış,
      // toplam Alacak 52.500 TL, net Alacak Bakiyesi (bu ay ödenecek) ise 2.500 TL.
      // Ayrıca hem 360.03 hem 360.03.05 satırı mevcut (ebeveyn + alt hesap).
      const dosimMizanText = '''
HESAP KODU | HESAP ADI | BORÇ | ALACAK | BORÇ BAKİYESİ | ALACAK BAKİYESİ
360 | ÖDENECEK VERGİ VE FONLAR | 50.000,00 | 52.500,00 | 0,00 | 2.500,00
360.03 | ÖDENECEK DAMGA VERGİSİ | 50.000,00 | 52.500,00 | 0,00 | 2.500,00
360.03.05 | HAKEDİŞ DAMGA VERGİSİ | 50.000,00 | 52.500,00 | 0,00 | 2.500,00
360.03.09 | DİĞER BİRİMLER (UBATAM) DAMGA VERGİSİ | 0,00 | 4.000,00 | 0,00 | 4.000,00
''';

      final dosimSonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'DÖSİM',
        aylikMizanMetni: dosimMizanText,
        yillikMizanMetni: '',
      );

      // Brüt 52.500 TL veya 2x katlanmış 105.000 TL DEĞİL, sadece DÖSİM'in net kalan 2.500 TL'si alınmalı;
      // UBATAM alt hesabı (4.000 TL) DÖSİM'e dahil edilmemeli.
      expect(dosimSonuc.damgaVergisi360, closeTo(2500.0, 0.01));
    });

    test('DÖSİM Aylık + Yıllık + Yardımcı Defter (Muavin) 3lü Çapraz Çözümleme Testi', () {
      // Aylık mizanda diğer birimlerin tahakkukları (12.000 Diş + 4.500 UBATAM) ve geçen ayın
      // beyanname ödemesi (15.000 Borç) birleştiği için Alacak Kalan 2.448 TL görünüyor.
      const dosimAylikText = '''
HESAP KODU | HESAP ADI | BORÇ | ALACAK | BORÇ BAKİYESİ | ALACAK BAKİYESİ
360.03 | ÖDENECEK DAMGA VERGİSİ | 15.000,00 | 17.448,00 | 0,00 | 2.448,00
360.03.05 | ÖDEMELERDEN KESİLEN DAMGA VERGİSİ | 15.000,00 | 17.448,00 | 0,00 | 2.448,00
''';
      const dosimYillikText = '''
HESAP KODU | HESAP ADI | BORÇ | ALACAK | BORÇ BAKİYESİ | ALACAK BAKİYESİ
360.03.05 | ÖDEMELERDEN KESİLEN DAMGA VERGİSİ | 150.000,00 | 167.448,00 | 0,00 | 17.448,00
''';
      // Yardımcı Defter (Muavin) ise her fişin hangi birime ait olduğunu açıkça gösteriyor:
      const dosimYardimciMuavinText = '''
HESAP: 360.03.05 ÖDEMELERDEN KESİLEN DAMGA VERGİSİ
05.10.2026 | Yev: 101 | DİŞ HEKİMLİĞİ HAKEDİŞ DAMGA VERGİSİ TAHAKKUKU | 0,00 | 12.000,00 | 0,00 | 12.000,00
10.10.2026 | Yev: 115 | UBATAM MALZEME ALIMI DAMGA VERGİSİ | 0,00 | 4.500,00 | 0,00 | 16.500,00
15.10.2026 | Yev: 140 | DÖSİM MERKEZ KIRTASİYE ALIMI DAMGA VERGİSİ | 0,00 | 948,00 | 0,00 | 17.448,00
26.10.2026 | Yev: 190 | EYLÜL AYI DAMGA VERGİSİ BEYANNAME ÖDEMESİ | 15.000,00 | 0,00 | 0,00 | 2.448,00
TOPLAM | 15.000,00 | 17.448,00 | 0,00 | 2.448,00
''';

      final dosimMuavinSonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'DÖSİM',
        aylikMizanMetni: dosimAylikText,
        yillikMizanMetni: dosimYillikText,
        yardimciMizanMetni: dosimYardimciMuavinText,
      );

      // Yardımcı Defter (Muavin) üzerinden Diş (12.000), UBATAM (4.500) ve Beyanname Ödemesi (15.000 Borç)
      // ayıklanmalı; sadece DÖSİM'in öz damga vergisi olan 948,00 TL kalmalı!
      expect(dosimMuavinSonuc.damgaVergisi360, closeTo(948.0, 0.01));
      expect(dosimMuavinSonuc.damgaMatrah, closeTo(100000.0, 0.5));

      // Senaryo B: Aylık mizanda geçen ayın yüksek beyanname ödemesi (Borç: 40.000 TL) yüzünden
      // Aylık Alacak Kalan 0 görünürken, Yıllık Mizan'da geçmiş ay Alacak + bu ay Borç mahsuplaşıp
      // dönem sonu net 1.896,00 TL Alacak Bakiyesi bırakmışsa Yıllık Mizan ile kurtarılmalı:
      const aylikBorcAgirlikli = '''
HESAP KODU | HESAP ADI | BORÇ | ALACAK | BORÇ BAKİYESİ | ALACAK BAKİYESİ
360.03.05 | ÖDEMELERDEN KESİLEN DAMGA VERGİSİ | 40.000,00 | 1.896,00 | 38.104,00 | 0,00
''';
      const yillikNetBakiyeli = '''
HESAP KODU | HESAP ADI | BORÇ | ALACAK | BORÇ BAKİYESİ | ALACAK BAKİYESİ
360.03.05 | ÖDEMELERDEN KESİLEN DAMGA VERGİSİ | 140.000,00 | 141.896,00 | 0,00 | 1.896,00
''';
      final caprazSonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'DÖSİM',
        aylikMizanMetni: aylikBorcAgirlikli,
        yillikMizanMetni: yillikNetBakiyeli,
      );
      expect(caprazSonuc.damgaVergisi360, closeTo(1896.0, 0.01));
    });

    test('Mizan 360.04 KDV 2 Tevkifat Okuma ve GİB Karekod %10 KDV & Çoklu Oran Tespiti', () {
      const mizan36004Text = '''
HESAP KODU | HESAP ADI | BORÇ | ALACAK | BORÇ BAKİYESİ | ALACAK BAKİYESİ
360.04 | KDV TEVKİFATI | 0,00 | 274.976,45 | 0,00 | 274.976,45
360.04.01 | SORUMLU SIFATIYLA ÖDENECEK KDV | 0,00 | 274.976,45 | 0,00 | 274.976,45
''';
      final disSonuc = MizanDeterministikParser.analizEt(
        birimAdi: 'DİŞ HEKİMLİĞİ',
        aylikMizanMetni: mizan36004Text,
        yillikMizanMetni: '',
      );
      expect(disSonuc.kdv2Tevkifat360, closeTo(274976.45, 0.01));

      // GİB Karekod: Matrah 720.000, KDV 72.000, Tevkifat 64.800 -> %10 KDV ve 9/10 Tevkifat olmalı!
      const qrYuzde10 =
          '{"vkntckn":"4110649065","malhizmettoplam":720000,"kdvmatrah(10)":720000,"kdvmatrah(20)":0,"hesaplanankdv(10)":72000,"hesaplanankdv(20)":0,"vergidahil":792000,"odenecek":727200}';
      final qr10Sonuc = GibKarekodVeUblCozucu.cozGibKarekodJson(qrYuzde10);
      expect(qr10Sonuc, isNotNull);
      expect(qr10Sonuc!.kdvOrani, equals(10));
      expect(qr10Sonuc.tevkifatOrani, equals('9/10'));
      expect(qr10Sonuc.cokluOranKarisikMi, isFalse);

      // GİB Karekod: 1.248.612,48 Matrah, 249.722,50 KDV, 180.430,25 Tevkifat (7.225/10 -> Çoklu oran karışımı!)
      const qrKarisikOran =
          '{"vkntckn":"8610478535","malhizmettoplam":1248612.48,"hesaplanankdv(20)":249722.50,"vergidahil":1498334.98,"odenecek":1317904.73}';
      final qrKarisikSonuc = GibKarekodVeUblCozucu.cozGibKarekodJson(qrKarisikOran);
      expect(qrKarisikSonuc, isNotNull);
      expect(qrKarisikSonuc!.cokluOranKarisikMi, isTrue);
    });
  });
}
