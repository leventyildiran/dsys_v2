import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/fatura/services/fatura_offline_parser.dart';
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
      expect(f.kalemler[0]['cinsi'], contains('Su ve Toprak'));
      expect(f.kalemler[0]['fiyat'], equals(2500.0));
      expect(f.kalemler[1]['cinsi'], contains('Numune Hazırlama'));
      expect(f.kalemler[1]['fiyat'], equals(500.0));
      expect(f.matrah, equals(3000.0));
      expect(f.genelToplam, equals(3600.0));
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
