import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/fatura/models/fatura_model.dart';
import 'package:dsys_v2/features/fatura/services/fatura_offline_parser.dart';
import 'package:dsys_v2/features/fatura/services/fatura_dogrulama_servisi.dart';
import 'package:dsys_v2/features/fatura/providers/fatura_kuyruk_provider.dart';
import 'package:dsys_v2/core/models/sistem_ayarlari_model.dart';
import 'package:dsys_v2/features/fatura/models/fatura_matbu_config.dart';

void main() {
  group('Fatura PDF Okuma ve Offline Parser Testleri', () {
    test('e-Arşiv / e-Fatura metninden dip toplamlar ve kalemler başarıyla çıkarılmalı', () {
      const ornekFaturaMetni = '''
      T.C. UŞAK ÜNİVERSİTESİ DÖNER SERMAYE İŞLETMESİ
      FATURA
      Fatura No: GIB2026000001234
      Tarih: 15.03.2026
      
      Sayın: ANADOLU MADENCİLİK VE SANAYİ TİC. A.Ş.
      Adres: Organize Sanayi Bölgesi 4. Cadde No:12 Uşak
      Vergi Dairesi: Uşak Vergi Dairesi
      VKN: 1234567890
      
      1 Su ve Toprak Ağır Metal Analizi 1 Adet 2.500,00 %20 500,00 2.500,00 TL
      2 Numune Hazırlama Bedeli 1 Adet 500,00 %20 100,00 500,00 TL
      
      Mal Hizmet Toplam Tutarı: 3.000,00 TL
      Hesaplanan KDV: 600,00 TL
      Ödenecek Tutar: 3.600,00 TL
      #ÜÇ BİN ALTI YÜZ TÜRK LİRASI#
      ''';

      final faturalar = FaturaOfflineParser.parse(ornekFaturaMetni);
      expect(faturalar, isNotEmpty);
      final f = faturalar.first;

      expect(f.firmaAdi, contains('ANADOLU MADENCİLİK'));
      expect(f.vergiNo, equals('1234567890'));
      expect(f.vergiDairesi, contains('Uşak'));
      expect(f.kalemler.length, equals(2));
      expect(f.kalemler[0]['cinsi'], equals('Su ve Toprak Ağır Metal Analizi'));
      expect(f.kalemler[0]['fiyat'], equals(2500.0));
      expect(f.kalemler[1]['cinsi'], equals('Numune Hazırlama Bedeli'));
      expect(f.kalemler[1]['fiyat'], equals(500.0));
      expect(f.matrah, equals(3000.0));
      expect(f.genelToplam, equals(3600.0));
    });

    test('Diş Hekimliği çok kalemli faturada kalem adları harfi harfine okunmalı ve uydurma yapılmamalı', () {
      const disFaturasi = '''
      T.C. UŞAK ÜNİVERSİTESİ DİŞ HEKİMLİĞİ FAKÜLTESİ
      E-ARŞİV FATURA
      Fatura No: DIS2026000005678
      Tarih: 18.04.2026
      
      Sayın: MEHMET YILMAZ
      Adres: Atatürk Mah. İnönü Cad. No:45 Merkez / Uşak
      TCKN: 11111111110
      
      1 Kompozit Dolgu Tedavisi 2 ADET 750,00 1.500,00 TL
      2 Kanal Tedavisi (Tek Kök) 1 ADET 1.200,00 1.200,00 TL
      3 Diş Taşı Temizliği (Detertraj) 1 ADET 800,00 800,00 TL
      
      Mal Hizmet Toplam Tutarı: 3.500,00 TL
      Hesaplanan KDV (%10): 350,00 TL
      Ödenecek Tutar: 3.850,00 TL
      ''';

      final faturalar = FaturaOfflineParser.parse(disFaturasi);
      expect(faturalar, isNotEmpty);
      final f = faturalar.first;

      expect(f.firmaAdi, equals('MEHMET YILMAZ'));
      expect(f.vergiNo, equals('11111111110'));
      expect(f.kalemler.length, equals(3));

      expect(f.kalemler[0]['cinsi'], equals('Kompozit Dolgu Tedavisi'));
      expect(f.kalemler[0]['miktar'], equals(2));
      expect(f.kalemler[0]['birimFiyat'], equals(750.0));
      expect(f.kalemler[0]['tutar'], equals(1500.0));

      expect(f.kalemler[1]['cinsi'], equals('Kanal Tedavisi (Tek Kök)'));
      expect(f.kalemler[1]['miktar'], equals(1));
      expect(f.kalemler[1]['birimFiyat'], equals(1200.0));

      expect(f.kalemler[2]['cinsi'], equals('Diş Taşı Temizliği (Detertraj)'));
      expect(f.kalemler[2]['miktar'], equals(1));
      expect(f.kalemler[2]['birimFiyat'], equals(800.0));

      final dogrulanmis = FaturaDogrulamaServisi.dogrulaVeTamamla(f);
      expect(dogrulanmis.matrah, equals(3500.0));
      expect(dogrulanmis.kdvTutari, equals(350.0));
      expect(dogrulanmis.genelToplam, equals(3850.0));
    });

    test('Kalem satırları ayrıştırılamasa dahi dip toplamdan fatura kurtarılmalı', () {
      const dipToplamFaturaMetni = '''
      E-ARŞİV FATURA
      Müşteri: KÖY KALKINMA KOOPERATİFİ
      Vergi No: 9876543210
      Tarih: 20.04.2026
      
      [Karmaşık taranmış tablo satırları okunamadı]
      
      Matrah: 4.000,00 TL
      KDV: 800,00 TL
      Genel Toplam: 4.800,00 TL
      ''';

      final faturalar = FaturaOfflineParser.parse(dipToplamFaturaMetni);
      expect(faturalar, isNotEmpty);
      final f = faturalar.first;

      expect(f.firmaAdi, contains('KÖY KALKINMA'));
      expect(f.vergiNo, equals('9876543210'));
      expect(f.kalemler, isNotEmpty);
      expect(f.matrah, equals(4000.0));
      expect(f.genelToplam, equals(4800.0));
    });

    test('KDV Dahil modunda girilen fiyat Genel Toplam olmalı, Matrah ve KDV içinden ayrıştırılmalı (%10 Diş)', () {
      final f = FaturaModel.bos(id: '1');
      f.kdvDahil = true;
      f.kdvOrani = 10.0;
      f.kalemler = [
        {'cinsi': 'Diş Tedavi Hizmeti', 'miktar': 1, 'fiyat': 1100.0}
      ];

      final dogrulanmis = FaturaDogrulamaServisi.dogrulaVeTamamla(f);
      expect(dogrulanmis.genelToplam, equals(1100.0));
      expect(dogrulanmis.matrah, equals(1000.0));
      expect(dogrulanmis.kdvTutari, equals(100.0));
      expect(dogrulanmis.kdvOrani, equals(10.0));
    });

    test('Yumurta satış listesi KDV Dahil (%1 KDV) olarak kuruşu kuruşuna doğru hesaplanmalı', () {
      const yumurtaMetni = '''
      YUMURTA SATIŞ LİSTESİ
      Tarih: 15.05.2026
      
      1 ALİ DEMİR 101,00 TL
      2 AYŞE KAYA 202,00 TL
      ''';

      final faturalar = FaturaOfflineParser.parse(yumurtaMetni);
      expect(faturalar, isNotEmpty);
      expect(faturalar.length, equals(2));

      final f1 = faturalar.first;
      expect(f1.firmaAdi, equals('ALİ DEMİR'));
      expect(f1.kdvDahil, isTrue);
      expect(f1.kdvOrani, equals(1.0));
      expect(f1.kalemler[0]['fiyat'], equals(100.0));
      expect(f1.kalemler[0]['birimFiyat'], equals(100.0));
      expect(f1.kalemler[0]['kdvDahilFiyat'], equals(101.0));
      expect(f1.genelToplam, equals(101.0));
      expect(f1.matrah, equals(100.0));
      expect(f1.kdvTutari, equals(1.0));

      final f2 = faturalar[1];
      expect(f2.firmaAdi, equals('AYŞE KAYA'));
      expect(f2.kalemler[0]['fiyat'], equals(200.0));
      expect(f2.kalemler[0]['kdvDahilFiyat'], equals(202.0));
      expect(f2.genelToplam, equals(202.0));
      expect(f2.matrah, equals(200.0));
      expect(f2.kdvTutari, equals(2.0));
    });

    test('KDV Dahil modunda 6 TL olan yumurta %10 KDV ile net birim fiyatı 5,45 TL ve matrahı 5,45 TL olmalı', () {
      final f = FaturaModel.bos();
      f.kdvDahil = true;
      f.kdvOrani = 10.0;
      f.kalemler = [
        {
          'cinsi': 'Yumurta Satışı',
          'miktar': 1.0,
          'fiyat': 6.0,
          'tutar': 6.0,
        }
      ];

      final dogrulanmis = FaturaDogrulamaServisi.dogrulaVeTamamla(f);
      expect(dogrulanmis.kdvDahil, isTrue);
      expect(dogrulanmis.kalemler[0]['fiyat'], equals(5.45));
      expect(dogrulanmis.kalemler[0]['birimFiyat'], equals(5.45));
      expect(dogrulanmis.kalemler[0]['tutar'], equals(5.45));
      expect(dogrulanmis.kalemler[0]['kdvDahilFiyat'], equals(6.0));
      expect(dogrulanmis.matrah, equals(5.45));
      expect(dogrulanmis.kdvTutari, equals(0.55));
      expect(dogrulanmis.genelToplam, equals(6.00));
    });

    test('FaturaKuyrukProvider KDV Dahil şalteri açılıp kapandığında birim fiyatı ve toplamları dinamik güncellemeli', () {
      final provider = FaturaKuyrukProvider();
      final fatura = FaturaModel.bos(id: 'test_kdv_dahil');
      fatura.kdvDahil = false;
      fatura.kdvOrani = 10.0;
      fatura.kalemler = [
        {
          'cinsi': 'Yumurta',
          'miktar': 1.0,
          'fiyat': 6.0,
          'tutar': 6.0,
        }
      ];

      provider.setInvoicesFromParse([fatura]);
      expect(provider.pendingInvoices[0].kalemler[0]['fiyat'], equals(6.0));

      // 1. KDV Dahil aç: 6 TL brüt -> 5.45 TL net birim fiyat
      provider.toggleKdvDahil(0, true);
      expect(provider.pendingInvoices[0].kdvDahil, isTrue);
      expect(provider.pendingInvoices[0].kalemler[0]['fiyat'], equals(5.45));
      expect(provider.pendingInvoices[0].kalemler[0]['tutar'], equals(5.45));
      expect(provider.pendingInvoices[0].matrah, equals(5.45));
      expect(provider.pendingInvoices[0].kdvTutari, equals(0.55));
      expect(provider.pendingInvoices[0].genelToplam, equals(6.00));

      // 2. KDV Dahil modunda fiyatı 11.00 TL (brüt) olarak güncelle -> 10.00 TL net
      provider.updateKalem(0, 0, 'fiyat', 11.0);
      expect(provider.pendingInvoices[0].kalemler[0]['fiyat'], equals(10.00));
      expect(provider.pendingInvoices[0].kalemler[0]['tutar'], equals(10.00));
      expect(provider.pendingInvoices[0].matrah, equals(10.00));
      expect(provider.pendingInvoices[0].kdvTutari, equals(1.00));
      expect(provider.pendingInvoices[0].genelToplam, equals(11.00));

      // 3. KDV Dahil kapat -> 11.00 TL net birim fiyata döner, üzerine %10 KDV eklenir
      provider.toggleKdvDahil(0, false);
      expect(provider.pendingInvoices[0].kdvDahil, isFalse);
      expect(provider.pendingInvoices[0].kalemler[0]['fiyat'], equals(11.00));
      expect(provider.pendingInvoices[0].kalemler[0]['tutar'], equals(11.00));
      expect(provider.pendingInvoices[0].matrah, equals(11.00));
      expect(provider.pendingInvoices[0].kdvTutari, equals(1.10));
      expect(provider.pendingInvoices[0].genelToplam, equals(12.10));
    });
  });

  group('Sistem Ayarları ve Gemini Model Testleri', () {
    test('SistemAyarlariModel varsayılan geminiModel gemini-3.6-flash olmalı', () {
      final bos = SistemAyarlariModel.empty();
      expect(bos.geminiModel, equals('gemini-3.6-flash'));

      final jsonModel = SistemAyarlariModel.fromJson({
        'hesapAdi': 'Test',
        'iban': 'TR123',
        'geminiApiKey': 'abc',
        'deepseekApiUrl': '',
        'deepseekApiKey': '',
        'deepseekModel': '',
      });
      expect(jsonModel.geminiModel, equals('gemini-3.6-flash'));
    });

    test('Kullanıcı özel model yazdığında model aynen korunmalı', () {
      final ozelModel = SistemAyarlariModel.fromJson({
        'hesapAdi': 'Test',
        'iban': 'TR123',
        'geminiApiKey': 'abc',
        'geminiModel': 'gemini-3.6-flash',
        'deepseekApiUrl': '',
        'deepseekApiKey': '',
        'deepseekModel': '',
      });
      expect(ozelModel.geminiModel, equals('gemini-3.6-flash'));
    });
  });

  group('Matbu Kalibrasyon Hizalama Testleri', () {
    test('Matbu koordinatları ve etiketleri eksiksiz tanımlı olmalı', () {
      final k = FaturaMatbuConfig.varsayilanKoordinatlar();
      expect(k.containsKey('matrah'), isTrue);
      expect(k.containsKey('kdv'), isTrue);
      expect(k.containsKey('genelToplam'), isTrue);
      expect(k.containsKey('cinsi'), isTrue);
      expect(k.containsKey('tutar'), isTrue);
    });
  });
}
