import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/fatura/models/fatura_model.dart';
import 'package:dsys_v2/features/fatura/models/fatura_okuma_oturumu.dart';
import 'package:dsys_v2/features/fatura/services/fatura_gemini_okuyucu.dart';
import 'package:dsys_v2/features/fatura/services/fatura_kalite_kapisi.dart';
import 'package:dsys_v2/features/fatura/services/fatura_ayristirma_orkestratoru.dart';
import 'package:dsys_v2/features/fatura/services/vergi_kimlik_dogrulayici.dart';
import 'package:dsys_v2/features/fatura/services/fatura_butunluk_denetcisi.dart';

void main() {
  group('FaturaOkumaOturumu ve Terminal State Testleri', () {
    test('Oturum yaşam döngüsü ve maliyet sayacı doğru işlemeli', () {
      final oturum = FaturaOkumaOturumu(konsolaYaz: false);
      oturum.baslat(toplamDosya: 2);

      expect(oturum.calisiyor, isTrue);
      expect(oturum.ilerleme, equals(0.0));
      expect(oturum.faturaSayisi, equals(0));
      expect(oturum.tahminiMaliyetTl, equals(0.0));

      oturum.dosyaBasla(0, 'fatura1.pdf');
      oturum.faturaEklendi(1, ucretsiz: true);
      oturum.apiKullanimiEkle(token: 500, maliyetTl: 0.005);

      expect(oturum.faturaSayisi, equals(1));
      expect(oturum.ucretsizOkunanDosya, equals(1));
      expect(oturum.toplamToken, equals(500));
      expect(oturum.tahminiMaliyetTl, closeTo(0.005, 0.0001));

      oturum.tamamla();
      expect(oturum.calisiyor, isFalse);
      expect(oturum.ilerleme, equals(1.0));
      expect(FaturaOkumaOturumu.maliyetMetni(0.0), equals('0,00 TL'));
      expect(FaturaOkumaOturumu.maliyetMetni(0.005), equals('< 0,01 TL'));
      expect(FaturaOkumaOturumu.maliyetMetni(1.50), equals('1,50 TL'));
    });

    test('İptal istendiğinde FaturaOkumaIptalEdildi istisnası fırlatmalı', () {
      final oturum = FaturaOkumaOturumu(konsolaYaz: false);
      oturum.baslat();
      oturum.iptalEt();
      expect(oturum.iptalIstendi, isTrue);
      expect(() => oturum.iptalKontrol(), throwsA(isA<FaturaOkumaIptalEdildi>()));
    });
  });

  group('FaturaGeminiOkuyucu Maliyet ve Model Güvenlik Testleri', () {
    test('Adında "pro" geçen modeller kesinlikle reddedilmeli', () {
      expect(FaturaGeminiOkuyucu.ucuzModelMi('gemini-1.5-pro'), isFalse);
      expect(FaturaGeminiOkuyucu.ucuzModelMi('gemini-pro'), isFalse);
      expect(FaturaGeminiOkuyucu.ucuzModelMi('gemini-2.5-pro'), isFalse);
      expect(FaturaGeminiOkuyucu.ucuzModelMi('gemini-1.5-flash'), isTrue);
      expect(FaturaGeminiOkuyucu.ucuzModelMi('gemini-2.0-flash'), isTrue);
      expect(FaturaGeminiOkuyucu.ucuzModelMi('gemini-2.5-flash-lite'), isTrue);
    });

    test('Model listesi yalnızca Flash modellerini içermeli', () {
      final liste = FaturaGeminiOkuyucu.modelSirasi('gemini-1.5-pro');
      expect(liste.any((m) => m.contains('pro')), isFalse);
      expect(liste.every((m) => m.contains('flash')), isTrue);
    });

    test('Token maliyet hesaplaması doğru olmalı', () {
      // 1000 girdi, 500 çıktı @ gemini-2.0-flash ($0.10 / $0.40 per 1M)
      final tl = FaturaGeminiOkuyucu.maliyetHesapla(
        model: 'gemini-2.0-flash',
        girdi: 1000,
        cikti: 500,
        dusunce: 0,
      );
      // (1000 * 0.10 + 500 * 0.40) / 1M = (100 + 200) / 1M = 0.0003 USD * 42 = 0.0126 TL
      expect(tl, closeTo(0.0126, 0.001));
    });

    test('Birincil ve yedek anahtar ikisi de boşken hata fırlatmalı', () async {
      final reader = FaturaGeminiOkuyucu();
      expect(
        () => reader.oku(
          apiKey: '',
          yedekApiKey: '',
          prompt: 'test',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('FaturaKaliteKapisi Testleri', () {
    test('Eksiksiz fatura onaylanmalı (eksikNedeni null olmalı)', () {
      final f = FaturaModel.bos();
      f.firmaAdi = 'Test Madencilik A.Ş.';
      f.genelToplam = 1500.0;
      f.kalemler = [
        {
          'cinsi': 'Toprak Analizi',
          'miktar': 1.0,
          'fiyat': 1500.0,
          'tutar': 1500.0,
        }
      ];

      expect(FaturaKaliteKapisi.eksikNedeni([f], 'Fatura No: GIB12345678'), isNull);
    });

    test('Yer tutucu genel kalem adı ("fatura bedeli") eksik sayılmalı', () {
      final f = FaturaModel.bos();
      f.firmaAdi = 'Örnek Firma';
      f.genelToplam = 500.0;
      f.kalemler = [
        {
          'cinsi': 'Fatura Bedeli',
          'miktar': 1.0,
          'fiyat': 500.0,
          'tutar': 500.0,
        }
      ];

      final neden = FaturaKaliteKapisi.eksikNedeni([f], 'Fatura No: GIB12345678');
      expect(neden, isNotNull);
      expect(neden!.toLowerCase(), contains('fatura bedeli'));
    });
  });

  group('FaturaAyristirmaOrkestratoru Kademeli Okuma Testleri', () {
    test('Katman 2 (Çevrimdışı Kural Motoru) geçerli faturayı 0 TL maliyetle anında çözmeli', () async {
      const eArsivMetin = '''
      T.C. UŞAK ÜNİVERSİTESİ DÖNER SERMAYE İŞLETMESİ
      FATURA
      Fatura No: GIB2026000009999
      Tarih: 20.05.2026
      
      Sayın: ANADOLU MADENCİLİK VE SANAYİ TİC. A.Ş.
      Adres: Organize Sanayi Bölgesi Uşak
      VKN: 1234567890
      
      1 Ağır Metal Analizi 1 Adet 2.000,00 %20 400,00 2.000,00 TL
      
      Mal Hizmet Toplam Tutarı: 2.000,00 TL
      Hesaplanan KDV: 400,00 TL
      Ödenecek Tutar: 2.400,00 TL
      ''';

      final orkestrator = FaturaAyristirmaOrkestratoru();
      final oturum = FaturaOkumaOturumu(konsolaYaz: false);
      oturum.baslat(toplamDosya: 1);

      final faturalar = await orkestrator.ayristir(
        bytes: null,
        fileName: 'fatura.txt',
        rawText: eArsivMetin,
        oturum: oturum,
      );

      oturum.tamamla();

      expect(faturalar, isNotEmpty);
      expect(faturalar.first.firmaAdi, contains('ANADOLU MADENCİLİK'));
      expect(faturalar.first.genelToplam, equals(2400.0));
      // API'ye hiç gidilmemeli, maliyet sıfır olmalı:
      expect(oturum.apiCagriSayisi, equals(0));
      expect(oturum.tahminiMaliyetTl, equals(0.0));
      expect(oturum.ucretsizOkunanDosya, equals(1));
    });
  });

  group('VergiKimlikDogrulayici Algoritma Testleri', () {
    test('GİB MOD 10 VKN kuralı doğru çalışmalı', () {
      // Bilinen geçerli VKN örnekleri:
      expect(VergiKimlikDogrulayici.vknGecerliMi('6191268620'), isTrue);
      // '1234567890' matematiksel olarak MOD 10 sağlar:
      expect(VergiKimlikDogrulayici.vknGecerliMi('1234567890'), isTrue);
      // Geçersiz VKN:
      expect(VergiKimlikDogrulayici.vknGecerliMi('1234567891'), isFalse);
      expect(VergiKimlikDogrulayici.vknGecerliMi('1111111111'), isFalse);
      expect(VergiKimlikDogrulayici.vknGecerliMi('12345'), isFalse);
    });

    test('TC Kimlik No algoritması doğru çalışmalı', () {
      // 10 hane veya 11 hane ayrımı:
      expect(VergiKimlikDogrulayici.gecerliMi('6191268620'), isTrue);
      expect(VergiKimlikDogrulayici.gecerliMi('00000000000'), isFalse);
    });
  });

  group('FaturaButunlukDenetcisi Testleri', () {
    test('Tarih, tutar farkı ve işletme VKN uyarıları doğru üretilmeli', () {
      final f = FaturaModel.bos();
      f.firmaAdi = 'Test Kimya Ltd.';
      f.vergiNo = '8910123456';
      f.tarih = '01.01.2020'; // 2 yıldan eski tarih
      f.genelToplam = 1200.0;
      f.matrah = 1000.0;
      f.kdvTutari = 200.0;
      f.kalemler = [
        {'cinsi': 'Asit Analizi', 'miktar': 1, 'fiyat': 1000.0, 'tutar': 1000.0}
      ];

      // Belgedeki genel toplam ile hesaplanan arasında büyük fark simülasyonu:
      final once = FaturaOkumaAnlikGoruntusu(genelToplam: 1500.0, tarih: '01.01.2020');

      final uyarilar = FaturaButunlukDenetcisi.denetle(
        fatura: f,
        once: once,
        kaynakMetin: 'Test Kimya Asit Analizi 1000 TL',
        aiUretimi: true,
        isletmeVkn: '8910123456', // Kendi işletme VKN'si ile çakışma
        bugun: DateTime(2026, 10, 22),
      );

      expect(uyarilar.any((u) => u.contains('2 yıldan eski')), isTrue);
      expect(uyarilar.any((u) => u.contains('fark')), isTrue);
      expect(uyarilar.any((u) => u.contains('işletmenin kendi VKN')), isTrue);
    });
  });

  group('JSON Ayrıştırıcı Güçlendirme Testleri', () {
    test('İçinde "kalemler" listesi olan tek bir fatura objesi doğru ayrıştırılmalı (kalemler fatura sanılmamalı)', () {
      const jsonText = '''
      {
        "firmaAdi": "Hedef Tekstil Sanayi A.Ş.",
        "vergiNo": "6191268620",
        "matrah": 5000.0,
        "kdvTutari": 1000.0,
        "genelToplam": 6000.0,
        "kalemler": [
          {"cinsi": "Kumaş Mukavemet Testi", "miktar": 2, "fiyat": 1500.0, "tutar": 3000.0},
          {"cinsi": "Boya Haslığı Analizi", "miktar": 1, "fiyat": 2000.0, "tutar": 2000.0}
        ]
      }
      ''';

      final sonuc = FaturaAyristirmaOrkestratoru.jsonListesiCoz(jsonText);
      expect(sonuc.length, equals(1));
      expect(sonuc.first['firmaAdi'], equals('Hedef Tekstil Sanayi A.Ş.'));
      expect(sonuc.first['genelToplam'], equals(6000.0));
      expect(sonuc.first['kalemler'], isA<List>());
      expect((sonuc.first['kalemler'] as List).length, equals(2));
    });

    test('Doğrudan dizi olarak gelen çoklu faturalar doğru ayrıştırılmalı', () {
      const jsonListText = '''
      [
        {
          "firmaAdi": "Firma Bir",
          "vergiNo": "1111111111",
          "matrah": 100.0,
          "genelToplam": 120.0
        },
        {
          "firmaAdi": "Firma İki",
          "vergiNo": "2222222222",
          "matrah": 200.0,
          "genelToplam": 240.0
        }
      ]
      ''';

      final sonuc = FaturaAyristirmaOrkestratoru.jsonListesiCoz(jsonListText);
      expect(sonuc.length, equals(2));
      expect(sonuc[0]['firmaAdi'], equals('Firma Bir'));
      expect(sonuc[1]['firmaAdi'], equals('Firma İki'));
    });
  });
}
