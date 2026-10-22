import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/fatura/models/fatura_model.dart';
import 'package:dsys_v2/features/fatura/models/fatura_okuma_oturumu.dart';
import 'package:dsys_v2/features/fatura/services/fatura_gemini_okuyucu.dart';
import 'package:dsys_v2/features/fatura/services/fatura_kalite_kapisi.dart';
import 'package:dsys_v2/features/fatura/services/fatura_ayristirma_orkestratoru.dart';

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
}
