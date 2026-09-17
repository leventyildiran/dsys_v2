import '../models/fatura_model.dart';
import '../../../core/turkce_format.dart';

/// Fatura kalemleri, matrah, KDV ve genel toplam arasında matematiksel
/// tutarlılığı denetleyen ve eksik alanları otomatik tamamlayan doğrulama servisi.
class FaturaDogrulamaServisi {
  FaturaDogrulamaServisi._();

  /// Verilen faturayı matematiksel kurallarla kontrol eder ve düzeltilmiş halini döner.
  static FaturaModel dogrulaVeTamamla(FaturaModel f) {
    // 1. Kalemlerin miktar x fiyat = tutar kontrolü
    final duzeltilmisKalemler = <Map<String, dynamic>>[];
    double hesaplananMatrah = 0.0;

    for (final rawKalem in f.kalemler) {
      final kalem = Map<String, dynamic>.from(rawKalem);
      
      final miktar = TurkceFormat.parseSayi(kalem['miktar'], fallback: 1.0);
      final safeMiktar = miktar <= 0 ? 1.0 : miktar;
      kalem['miktar'] = safeMiktar;

      double fiyat = TurkceFormat.parseSayi(kalem['fiyat'], fallback: 0.0);
      double tutar = TurkceFormat.parseSayi(kalem['tutar'], fallback: 0.0);

      if (fiyat > 0 && tutar <= 0) {
        tutar = fiyat * safeMiktar;
        kalem['tutar'] = tutar;
      } else if (tutar > 0 && fiyat <= 0) {
        fiyat = tutar / safeMiktar;
        kalem['fiyat'] = fiyat;
      } else if (fiyat > 0 && tutar > 0) {
        // İkisi de varsa çarpımı teyit et (küçük yuvarlama farkı toleransı: 0.05)
        final carpim = fiyat * safeMiktar;
        if ((carpim - tutar).abs() > 0.05) {
          tutar = carpim;
          kalem['tutar'] = tutar;
        }
      }

      hesaplananMatrah += tutar;
      duzeltilmisKalemler.add(kalem);
    }

    f.kalemler = duzeltilmisKalemler;

    // 2. Matrah & Genel Toplam sağlama
    double matrah = f.matrah;
    double genelToplam = f.genelToplam;
    double kdvOrani = f.kdvOrani;

    if (f.isKdvMuaf) {
      kdvOrani = 0.0;
      f.kdvOrani = 0.0;
      f.kdvTutari = 0.0;
    }

    // Matrah sıfır ama kalemler toplamı varsa:
    if (matrah <= 0 && hesaplananMatrah > 0) {
      matrah = hesaplananMatrah;
    }

    // Matrah sıfır ama genel toplam ve KDV oranı varsa (Geriye doğru hesaplama):
    if (matrah <= 0 && genelToplam > 0) {
      if (f.isKdvMuaf || kdvOrani <= 0) {
        matrah = genelToplam;
      } else {
        matrah = double.parse((genelToplam / (1 + (kdvOrani / 100))).toStringAsFixed(2));
      }
    }

    // Kalemler boşsa veya tek bir kalem varsa ve fiyatı 0 ise matrahı kaleme aktar
    if (f.kalemler.length == 1 && matrah > 0) {
      final tekFiyat = TurkceFormat.parseSayi(f.kalemler[0]['fiyat'], fallback: 0.0);
      if (tekFiyat <= 0) {
        f.kalemler[0]['fiyat'] = matrah;
        f.kalemler[0]['tutar'] = matrah;
        hesaplananMatrah = matrah;
      }
    }

    // 3. KDV Tutarı & Genel Toplam hesaplama
    double kdvTutari = 0.0;
    if (!f.isKdvMuaf && kdvOrani > 0 && matrah > 0) {
      kdvTutari = double.parse((matrah * (kdvOrani / 100)).toStringAsFixed(2));
      genelToplam = double.parse((matrah + kdvTutari).toStringAsFixed(2));
    } else {
      kdvTutari = 0.0;
      genelToplam = matrah;
    }

    f.matrah = double.parse(matrah.toStringAsFixed(2));
    f.kdvTutari = double.parse(kdvTutari.toStringAsFixed(2));
    f.genelToplam = double.parse(genelToplam.toStringAsFixed(2));

    return f;
  }

  /// Bir liste faturayı topluca doğrular.
  static List<FaturaModel> dogrulaList(List<FaturaModel> faturalar) {
    return faturalar.map(dogrulaVeTamamla).toList();
  }
}
