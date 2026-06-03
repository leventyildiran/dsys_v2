import 'dart:math';

/// Personel puan modeli — hesaplama motoru için.
class PersonelPuanModel {
  const PersonelPuanModel({
    required this.personelId,
    required this.faaliyetPuani,
    required this.unvanKatsayisi,
  });

  final String personelId;
  final double faaliyetPuani;
  final double unvanKatsayisi;

  /// Bireysel ağırlıklı puan.
  double get bireyselPuan => faaliyetPuani * unvanKatsayisi;
}

/// Kesinti hesaplama sonucu.
class KesintiBilgisi {
  const KesintiBilgisi({
    required this.kdvHaricMatrah,
    required this.hazinePayi,
    required this.bapPayi,
    required this.aracGerecPayi,
    required this.dagitilabilirTutar,
    this.birimKalani,
  });

  final double kdvHaricMatrah;
  final double hazinePayi;
  final double bapPayi;
  final double aracGerecPayi;
  final double dagitilabilirTutar;
  final double? birimKalani; // Sadece 58/k için

  double get toplamKesinti => hazinePayi + bapPayi + aracGerecPayi;
}

/// DSYS Hesaplama Motoru.
///
/// SKILL.md ve implementation_plan.md'deki formüllere birebir sadık kalır.
/// Tüm hesaplamalar pure Dart fonksiyonlarıdır (side-effect yok).
class HesaplamaMotoru {
  HesaplamaMotoru._();

  // ─────────────────────────────────────────────────────────────
  // 1. KDV & KESİNTİ HESAPLAMA
  // ─────────────────────────────────────────────────────────────

  /// KDV dahil tutardan KDV hariç matrahı bulur.
  /// `kdvHaricMatrah = ROUND( brutTaksitTutarı / (1 + (kdvOrani / 100)), 2 )`
  static double kdvHaricMatrahHesapla(double brutTutar, int kdvOrani) {
    return _round(brutTutar / (1 + (kdvOrani / 100)), 2);
  }

  /// Standart danışmanlık kesinti hesaplaması.
  static KesintiBilgisi standartKesintiler({
    required double brutTutar,
    required int kdvOrani,
    required int hazinePayiOrani,
    required int bapPayiOrani,
    required int aracGerecPayiOrani,
  }) {
    final matrah = kdvHaricMatrahHesapla(brutTutar, kdvOrani);
    final hazine = _round(matrah * (hazinePayiOrani / 100), 2);
    final bap = _round(matrah * (bapPayiOrani / 100), 2);
    final aracGerec = _round(matrah * (aracGerecPayiOrani / 100), 2);
    final dagitilabilir = matrah - (hazine + bap + aracGerec);

    return KesintiBilgisi(
      kdvHaricMatrah: matrah,
      hazinePayi: hazine,
      bapPayi: bap,
      aracGerecPayi: aracGerec,
      dagitilabilirTutar: dagitilabilir,
    );
  }

  /// Sanayi İşbirliği (YÖK 58/k) kesinti hesaplaması.
  /// Hazine, BAP, Araç-Gereç = 0. Dağıtılabilir = %85.
  static KesintiBilgisi sanayiIsbirligiKesintiler({
    required double brutTutar,
    required int kdvOrani,
  }) {
    final matrah = kdvHaricMatrahHesapla(brutTutar, kdvOrani);
    final dagitilabilir = _round(matrah * 0.85, 2);
    final birimKalani = matrah - dagitilabilir;

    return KesintiBilgisi(
      kdvHaricMatrah: matrah,
      hazinePayi: 0.0,
      bapPayi: 0.0,
      aracGerecPayi: 0.0,
      dagitilabilirTutar: dagitilabilir,
      birimKalani: birimKalani,
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. KURUŞ YUVARLAMA KATSAYI SİMÜLASYONU
  // ─────────────────────────────────────────────────────────────

  /// Kuruş taşma simülasyonu.
  ///
  /// Katsayıyı 0.01'er düşürerek toplam hakedişin dağıtılabilir
  /// tutarı aşmamasını garanti eder.
  static double katsayiSimulasyonu(
    double dagitilabilirTutar,
    double toplamPuan,
    List<PersonelPuanModel> personeller,
  ) {
    double katsayi =
        double.parse((dagitilabilirTutar / toplamPuan).toStringAsFixed(2));

    while (true) {
      double hakedisToplam = 0.0;

      for (var personel in personeller) {
        double bireyselPuan = personel.faaliyetPuani * personel.unvanKatsayisi;
        double hakedis =
            double.parse((bireyselPuan * katsayi).toStringAsFixed(2));
        hakedisToplam += hakedis;
      }

      if (hakedisToplam > dagitilabilirTutar) {
        katsayi = double.parse((katsayi - 0.01).toStringAsFixed(2));
      } else {
        break;
      }
    }
    return katsayi;
  }

  /// Artık bakiye hesaplaması.
  /// `artikBakiye = DagitilabilirTutar - SUM(ROUND(bireyselPuan * Katsayi, 2))`
  static double artikBakiyeHesapla(
    double dagitilabilirTutar,
    double katsayi,
    List<PersonelPuanModel> personeller,
  ) {
    double toplam = 0.0;
    for (var personel in personeller) {
      double bireyselPuan = personel.faaliyetPuani * personel.unvanKatsayisi;
      double hakedis =
          double.parse((bireyselPuan * katsayi).toStringAsFixed(2));
      toplam += hakedis;
    }
    return dagitilabilirTutar - toplam;
  }

  // ─────────────────────────────────────────────────────────────
  // 3. EYDMA YASAL TAVAN KONTROLÜ
  // ─────────────────────────────────────────────────────────────

  /// EYDMA değerini hesaplar.
  /// `eydma = (gostergeEk + gostergeMakamTemsil) * memurMaasKatsayisi`
  static double eydmaHesapla({
    required double gostergeEk,
    required double gostergeMakamTemsil,
    required double memurMaasKatsayisi,
  }) {
    return (gostergeEk + gostergeMakamTemsil) * memurMaasKatsayisi;
  }

  /// Unvan tavanını hesaplar.
  /// `unvanTavani = eydma * (unvanTavanCarpani / 100)`
  static double unvanTavaniHesapla(double eydma, double unvanTavanCarpani) {
    return eydma * (unvanTavanCarpani / 100);
  }

  /// Kalan tavan limitini hesaplar ve ödenebilir/fazlalık tutarları döner.
  static ({double odenebilirHakedis, double fazlalikHavuzTutari}) tavanKontrol({
    required double unvanTavani,
    required double toplamAylikMevcutGelir,
    required double yeniHesaplananHakedis,
  }) {
    final kalanTavanLimiti = max(0.0, unvanTavani - toplamAylikMevcutGelir);

    if (yeniHesaplananHakedis > kalanTavanLimiti) {
      return (
        odenebilirHakedis: kalanTavanLimiti,
        fazlalikHavuzTutari: yeniHesaplananHakedis - kalanTavanLimiti,
      );
    } else {
      return (
        odenebilirHakedis: yeniHesaplananHakedis,
        fazlalikHavuzTutari: 0.0,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // YARDIMCI
  // ─────────────────────────────────────────────────────────────

  /// 2 ondalık hassasiyetle yuvarlar.
  static double _round(double value, int decimals) {
    final mod = pow(10.0, decimals);
    return ((value * mod).roundToDouble()) / mod;
  }
}
