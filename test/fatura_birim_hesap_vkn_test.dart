import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/birim/models/birim_model.dart';
import 'package:dsys_v2/features/fatura/models/fatura_matbu_config.dart';

void main() {
  group('Resmi Birimler, Hesap Adları ve VKN Eşleştirme Testleri', () {
    test('1. Tüm varsayılan birimler temiz hesap adları ve resmi VKN/IBAN değerlerine sahip olmalı', () {
      final birimler = BirimModel.varsayilanBirimler;

      // Hiçbir birimde 'Kurum Tek İdare Tahsilat Alt Hesabı' kalmamalı
      for (final b in birimler) {
        expect(b.hesapAdi?.contains('Kurum Tek İdare'), isFalse,
            reason: '${b.kisaAd} hesap adında Kurum Tek İdare ibaresi olmamalı');
      }

      // USEM / Sürekli Eğitim
      final usem = birimler.firstWhere((b) => b.kisaAd == 'USEM');
      expect(usem.hesapAdi, 'Sürekli Eğitim DSİ');
      expect(usem.vkn, '8960466257');
      expect(usem.iban, 'TR500001001758672355695003');

      // TÖMER
      final tomer = birimler.firstWhere((b) => b.kisaAd == 'TÖMER');
      expect(tomer.hesapAdi, 'Türkçe Öğrenimi DSİ');
      expect(tomer.vkn, '8960466329');
      expect(tomer.iban, 'TR040001001758672359525003');

      // Diş Hekimliği
      final dis = birimler.firstWhere((b) => b.kisaAd == 'Diş Hekimliği');
      expect(dis.hesapAdi, 'Ağız ve Diş Sağlığı DSİ');
      expect(dis.vkn, '8960475707');
      expect(dis.iban, 'TR880001001758890982805002');

      // UBATAM
      final ubatam = birimler.firstWhere((b) => b.kisaAd == 'UBATAM');
      expect(ubatam.hesapAdi, 'Bilimsel Analiz ve Teknolojik DSİ');
      expect(ubatam.vkn, '8960466311');
      expect(ubatam.iban, 'TR290001001758672359025003');

      // DTS
      final dts = birimler.firstWhere((b) => b.kisaAd == 'DTS');
      expect(dts.hesapAdi, 'Deri, Tekstil ve Seramik DSİ');
      expect(dts.vkn, '2931062663');
      expect(dts.iban, 'TR090001001758975714095007');

      // TADAUM
      final tadaum = birimler.firstWhere((b) => b.kisaAd == 'TADAUM');
      expect(tadaum.hesapAdi, 'Tarımsal ve Doğa Araştırmaları DSİ');
      expect(tadaum.vkn, '8240526649');
      expect(tadaum.iban, 'TR190001001758982110835002');

      // DÖSİM
      final dosim = birimler.firstWhere((b) => b.kisaAd == 'DÖSİM');
      expect(dosim.hesapAdi, 'DÖSİM');
      expect(dosim.vkn, '8960453664');
      expect(dosim.iban, 'TR850001001758517844115013');
    });

    test('2. BirimAdlandirma.temizleHesapAdi eski Kurum Tek İdare ön ekini temizlemeli', () {
      expect(
        BirimAdlandirma.temizleHesapAdi('Kurum Tek İdare Tahsilat Alt Hesabı /Sürekli Eğitim DSİ'),
        'Sürekli Eğitim DSİ',
      );
      expect(
        BirimAdlandirma.temizleHesapAdi('Kurum Tek İdare Tahsilat Alt Hesabı/DÖSİM'),
        'DÖSİM',
      );
      expect(
        BirimAdlandirma.temizleHesapAdi('Sürekli Eğitim DSİ'),
        'Sürekli Eğitim DSİ',
      );
    });

    test('3. FaturaMatbuConfig.formatHesapAdiMatbu Sürekli Eğitim DSİ için Potansiyel VKN yazmalı', () {
      final formatted = FaturaMatbuConfig.formatHesapAdiMatbu('Sürekli Eğitim DSİ', fallbackVkn: '8960466257');
      expect(formatted, 'Sürekli Eğitim DSİ\n(Potansiyel VKN:8960466257)');
    });

    test('4. Eski hatalı DTS VKN (2931062663) Sürekli Eğitimde kalınca doğru Potansiyel VKN ile düzeltilmeli', () {
      final eskiHataliGirdi = 'Kurum Tek İdare Tahsilat Alt Hesabı /Sürekli Eğitim DSİ\n(VKN:2931062663)';
      final duzeltilmis = FaturaMatbuConfig.formatHesapAdiMatbu(eskiHataliGirdi, fallbackVkn: '8960466257');
      expect(duzeltilmis, 'Sürekli Eğitim DSİ\n(Potansiyel VKN:8960466257)');
    });

    test('5. Deri Tekstil kendi VKNsini korumalı', () {
      final dtsFormat = FaturaMatbuConfig.formatHesapAdiMatbu('Deri, Tekstil ve Seramik DSİ', fallbackVkn: '2931062663');
      expect(dtsFormat, 'Deri, Tekstil ve Seramik DSİ\n(VKN:2931062663)');
    });
  });
}
