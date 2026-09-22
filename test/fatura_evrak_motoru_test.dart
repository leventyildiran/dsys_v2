import 'package:flutter_test/flutter_test.dart';
import 'package:dsys_v2/features/fatura/models/fatura_matbu_config.dart';
import 'package:dsys_v2/features/fatura/models/fatura_model.dart';
import 'package:dsys_v2/features/fatura/services/fatura_offline_parser.dart';
import 'package:dsys_v2/features/fatura/services/fatura_dogrulama_servisi.dart';

void main() {
  group('A4 Kalibrasyon ve Standart Boyut Testleri', () {
    test('A4 genişlik ve yükseklik standart ISO 216 (72 dpi) pt değerinde olmalı', () {
      expect(FaturaMatbuConfig.a4Genislik, closeTo(595.28, 0.01));
      expect(FaturaMatbuConfig.a4Yukseklik, closeTo(841.89, 0.01));
    });
  });

  group('FaturaDogrulamaServisi Matematiksel Sağlama Testleri', () {
    test('Matrah ve KDV oranı bilindiğinde KDV tutarı ve Genel Toplam otomatik hesaplanmalı', () {
      final f = FaturaModel(
        id: 'test-1',
        firmaAdi: 'Test A.Ş.',
        adres: 'İstanbul',
        vergiDairesi: 'Kadıköy',
        vergiNo: '1234567890',
        tarih: '17.09.2026',
        irsaliyeNo: '',
        melbesNo: '',
        numuneNo: '',
        numuneAciklamasi: '',
        kalemler: [
          {'cinsi': 'Numune Analizi', 'miktar': 2, 'fiyat': 500.0, 'tutar': 1000.0},
        ],
        isKdvMuaf: false,
        matrah: 0.0,
        kdvOrani: 20.0,
        kdvTutari: 0.0,
        genelToplam: 0.0,
        parsedBy: 'Test',
      );

      final dogrulanmis = FaturaDogrulamaServisi.dogrulaVeTamamla(f);

      expect(dogrulanmis.matrah, equals(1000.0));
      expect(dogrulanmis.kdvTutari, equals(200.0));
      expect(dogrulanmis.genelToplam, equals(1200.0));
    });

    test('KDV Muaf faturada KDV oranı ve tutarı 0 olmalı, Genel Toplam Matraha eşit olmalı', () {
      final f = FaturaModel(
        id: 'test-2',
        firmaAdi: 'Muaf Kurum',
        adres: 'Ankara',
        vergiDairesi: 'Çankaya',
        vergiNo: '9876543210',
        tarih: '17.09.2026',
        irsaliyeNo: '',
        melbesNo: '',
        numuneNo: '',
        numuneAciklamasi: '',
        kalemler: [
          {'cinsi': 'Eğitim Hizmeti', 'miktar': 1, 'fiyat': 2500.0, 'tutar': 2500.0},
        ],
        isKdvMuaf: true,
        matrah: 2500.0,
        kdvOrani: 20.0,
        kdvTutari: 500.0,
        genelToplam: 3000.0,
        parsedBy: 'Test',
      );

      final dogrulanmis = FaturaDogrulamaServisi.dogrulaVeTamamla(f);

      expect(dogrulanmis.matrah, equals(2500.0));
      expect(dogrulanmis.kdvOrani, equals(0.0));
      expect(dogrulanmis.kdvTutari, equals(0.0));
      expect(dogrulanmis.genelToplam, equals(2500.0));
    });

    test('Sadece Genel Toplam ve KDV oranı bilindiğinde Matrah geriye doğru türetilmeli', () {
      final f = FaturaModel(
        id: 'test-3',
        firmaAdi: 'Geriye Türetme A.Ş.',
        adres: 'İzmir',
        vergiDairesi: 'Konak',
        vergiNo: '5555555555',
        tarih: '17.09.2026',
        irsaliyeNo: '',
        melbesNo: '',
        numuneNo: '',
        numuneAciklamasi: '',
        kalemler: [],
        isKdvMuaf: false,
        matrah: 0.0,
        kdvOrani: 20.0,
        kdvTutari: 0.0,
        genelToplam: 1200.0,
        parsedBy: 'Test',
      );

      final dogrulanmis = FaturaDogrulamaServisi.dogrulaVeTamamla(f);

      expect(dogrulanmis.matrah, equals(1000.0));
      expect(dogrulanmis.kdvTutari, equals(200.0));
      expect(dogrulanmis.genelToplam, equals(1200.0));
    });

    test('Muaf olmayan faturada KDV oranı 0 gelirse varsayılan %20 uygulanmalı', () {
      final f = FaturaModel(
        id: 'test-4',
        firmaAdi: 'Varsayilan KDV A.S.',
        adres: 'Usak',
        vergiDairesi: 'Merkez',
        vergiNo: '1111111111',
        tarih: '17.09.2026',
        irsaliyeNo: '',
        melbesNo: '',
        numuneNo: '',
        numuneAciklamasi: '',
        kalemler: [
          {'cinsi': 'Hizmet', 'miktar': 1, 'fiyat': 1000.0, 'tutar': 1000.0},
        ],
        isKdvMuaf: false,
        matrah: 1000.0,
        kdvOrani: 0.0,
        kdvTutari: 0.0,
        genelToplam: 1000.0,
        parsedBy: 'Test',
      );

      final dogrulanmis = FaturaDogrulamaServisi.dogrulaVeTamamla(f);

      expect(dogrulanmis.kdvOrani, equals(20.0));
      expect(dogrulanmis.kdvTutari, equals(200.0));
      expect(dogrulanmis.genelToplam, equals(1200.0));
    });

    test('Yeni fatura varsayılan KDV oranı %20 olmalı', () {
      expect(FaturaModel.bos().kdvOrani, equals(20.0));
      expect(fVarsayilanKdvOrani, equals(20.0));
    });
  });

  group('FaturaOfflineParser Birim Talep ve e-Arşiv Testleri', () {
    test('Birim talep üst yazılı metninden MELBES ve Numune blokları başarıyla ayrıştırılmalı', () {
      const talepMetni = '''
T.C. DOKUZ EYLÜL ÜNİVERSİTESİ
MERKEZİ ARAŞTIRMA LABORATUVARI UYGULAMA VE ARAŞTIRMA MERKEZİ (UBATAM)
Sayı: E-12345678-000-000000
Konu: Fatura Talebi

Aşağıda bilgileri yer alan analiz hizmetine ait faturanın düzenlenmesi hususunda gereğini arz ederim.

Fatura Bilgileri:
MELBES Başvuru No: MLB-2026-9988
Numune No: NM-4455
Firma: ACME ÇEVRE TEKNOLOJİLERİ SAN. VE TİC. LTD. ŞTİ.
Tarih: 15.09.2026

Hizmet / Analiz Kalemleri:
Atıksu Ağır Metal Analizi  * 2  1.500,00 TL
BOD5 Analiz Bedeli  * 1  750,00 TL

Toplam Fiyat: 3.750,00 TL
IBAN: TR330006200000000012345678
''';

      final sonuc = FaturaOfflineParser.parse(talepMetni);
      expect(sonuc.isNotEmpty, isTrue);

      final f = sonuc.first;
      expect(f.firmaAdi, contains('ACME ÇEVRE'));
      expect(f.melbesNo, equals('MLB-2026-9988'));
      expect(f.numuneNo, equals('NM-4455'));
      expect(f.kalemler.length, equals(2));
      expect(f.kalemler[0]['cinsi'], equals('Atıksu Ağır Metal Analizi'));
      expect(f.kalemler[0]['miktar'], equals(2));
      expect(f.kalemler[0]['fiyat'], equals(3000.0));
      expect(f.iban?.replaceAll(' ', ''), contains('TR330006200000000012345678'));
    });
  });
}
