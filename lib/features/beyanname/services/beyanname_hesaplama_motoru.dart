import '../models/beyanname_model.dart';

/// 2025/2026 Yılı Aylık Asgari Ücret Vergi İstisnası Değerleri
class AsgariUcretIstisnasi {
  final double gelirVergisiIstisnasi;
  final double damgaVergisiIstisnasi;

  const AsgariUcretIstisnasi({
    required this.gelirVergisiIstisnasi,
    required this.damgaVergisiIstisnasi,
  });
}

/// KDV 1 Konsolide Özeti
class Kdv1KonsolideSonuc {
  final double matrah10Hesaplanan;
  final double kdv10Hesaplanan;
  final double matrah20Hesaplanan;
  final double kdv20Hesaplanan;
  final double toplamHesaplananKdv;
  final double toplamHesaplananMatrahVeKdv;

  final double matrah10Indirilecek;
  final double kdv10Indirilecek;
  final double matrah20Indirilecek;
  final double kdv20Indirilecek;
  final double toplamIndirilecekKdv;
  final double toplamIndirilecekMatrahVeKdv;

  final double odenecekKdv1;
  final double oncekiDonemdenDevredenKdv;
  final double sonrakiDonemeDevredenKdv;

  const Kdv1KonsolideSonuc({
    required this.matrah10Hesaplanan,
    required this.kdv10Hesaplanan,
    required this.matrah20Hesaplanan,
    required this.kdv20Hesaplanan,
    required this.toplamHesaplananKdv,
    required this.toplamHesaplananMatrahVeKdv,
    required this.matrah10Indirilecek,
    required this.kdv10Indirilecek,
    required this.matrah20Indirilecek,
    required this.kdv20Indirilecek,
    required this.toplamIndirilecekKdv,
    required this.toplamIndirilecekMatrahVeKdv,
    required this.odenecekKdv1,
    this.oncekiDonemdenDevredenKdv = 0.0,
    this.sonrakiDonemeDevredenKdv = 0.0,
  });
}

/// KDV 2 Tevkifat Konsolide Özeti
class Kdv2KonsolideSonuc {
  final Map<TevkifatTuru, Map<int, double>> matrahlar; // [Tür][Oran] -> Matrah
  final Map<TevkifatTuru, Map<int, double>> kdvler; // [Tür][Oran] -> KDV
  final Map<TevkifatTuru, Map<int, double>> tevkifatlar; // [Tür][Oran] -> Tevkifat

  final Map<TevkifatTuru, double> turKdvToplam;
  final Map<TevkifatTuru, double> turMatrahToplam;
  final Map<TevkifatTuru, double> turTevkifatToplam;

  final double butunKdvlerToplami;
  final double butunMatrahlarToplami;
  final double butunTevkifatlarToplami;

  const Kdv2KonsolideSonuc({
    required this.matrahlar,
    required this.kdvler,
    required this.tevkifatlar,
    required this.turKdvToplam,
    required this.turMatrahToplam,
    required this.turTevkifatToplam,
    required this.butunKdvlerToplami,
    required this.butunMatrahlarToplami,
    required this.butunTevkifatlarToplami,
  });
}

/// Muhtasar Konsolide Özeti
class MuhtasarKonsolideSonuc {
  final int toplamKisiSayisi;
  final double toplamBrutUcret;
  final double toplamGelirVergisi;
  final double toplamDamgaVergisi;
  final double toplamNetOdenen;
  final double toplamAylikGvMatrahi;

  final double asgariUcretGvIstisnasiToplami;
  final double asgariUcretDvIstisnasiToplami;

  final double muhtasarKesilenDamgaVergisi301;
  final double muhtasarDamgaVergisi302;
  final double toplamDamgaVergisi301Ve302;

  const MuhtasarKonsolideSonuc({
    required this.toplamKisiSayisi,
    required this.toplamBrutUcret,
    required this.toplamGelirVergisi,
    required this.toplamDamgaVergisi,
    required this.toplamNetOdenen,
    required this.toplamAylikGvMatrahi,
    required this.asgariUcretGvIstisnasiToplami,
    required this.asgariUcretDvIstisnasiToplami,
    required this.muhtasarKesilenDamgaVergisi301,
    required this.muhtasarDamgaVergisi302,
    required this.toplamDamgaVergisi301Ve302,
  });
}

/// Excel formülleriyle %100 uyumlu Beyanname Hesaplama Motoru
class BeyannameHesaplamaMotoru {
  BeyannameHesaplamaMotoru._();

  static double round(double val, [int decimals = 2]) {
    return double.parse(val.toStringAsFixed(decimals));
  }

  /// 2025 Yılı Asgari Ücret İstisnaları tablosu (Excel Birebir)
  static final Map<int, AsgariUcretIstisnasi> istisnalar2025 = {
    1: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 3315.70, damgaVergisiIstisnasi: 197.38),
    2: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 3315.70, damgaVergisiIstisnasi: 197.38),
    3: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 3315.70, damgaVergisiIstisnasi: 197.38),
    4: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 3315.70, damgaVergisiIstisnasi: 197.38),
    5: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 3315.70, damgaVergisiIstisnasi: 197.38),
    6: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 3315.70, damgaVergisiIstisnasi: 197.38),
    7: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 3315.70, damgaVergisiIstisnasi: 197.38),
    8: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 4257.57, damgaVergisiIstisnasi: 197.38),
    9: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 4420.93, damgaVergisiIstisnasi: 197.38),
    10: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 4420.93, damgaVergisiIstisnasi: 197.38),
    11: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 4420.93, damgaVergisiIstisnasi: 197.38),
    12: const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 4420.93, damgaVergisiIstisnasi: 197.38),
  };

  static AsgariUcretIstisnasi getIstisna(int yil, int ay) {
    if (istisnalar2025.containsKey(ay)) {
      return istisnalar2025[ay]!;
    }
    return const AsgariUcretIstisnasi(gelirVergisiIstisnasi: 4420.93, damgaVergisiIstisnasi: 197.38);
  }

  /// KDV 1 Konsolide Hesaplama
  static Kdv1KonsolideSonuc hesaplaKdv1(
    List<Kdv1BirimSatiri> satirlar, {
    double oncekiDonemdenDevredenKdv = 0.0,
  }) {
    double matrah10H = 0;
    double kdv10H = 0;
    double matrah20H = 0;
    double kdv20H = 0;

    double matrah10I = 0;
    double kdv10I = 0;
    double matrah20I = 0;
    double kdv20I = 0;

    for (final s in satirlar) {
      matrah10H += s.hesaplananMatrah10;
      kdv10H += s.hesaplananKdv10;
      matrah20H += s.hesaplananMatrah20;
      kdv20H += s.hesaplananKdv20;

      matrah10I += s.indirilecekMatrah10;
      kdv10I += s.indirilecekKdv10;
      matrah20I += s.indirilecekMatrah20;
      kdv20I += s.indirilecekKdv20;
    }

    final topHesaplananKdv = round(kdv10H + kdv20H);
    final topHesaplananMatrahVeKdv = round(matrah10H + kdv10H + matrah20H + kdv20H);

    final topIndirilecekKdv = round(kdv10I + kdv20I);
    final topIndirilecekMatrahVeKdv = round(matrah10I + kdv10I + matrah20I + kdv20I);

    final toplamIndirimVeDevir = round(topIndirilecekKdv + oncekiDonemdenDevredenKdv);

    final odenecekKdv1 = (topHesaplananKdv > toplamIndirimVeDevir)
        ? round(topHesaplananKdv - toplamIndirimVeDevir)
        : 0.0;

    final sonrakiDonemeDevredenKdv = (toplamIndirimVeDevir > topHesaplananKdv)
        ? round(toplamIndirimVeDevir - topHesaplananKdv)
        : 0.0;

    return Kdv1KonsolideSonuc(
      matrah10Hesaplanan: round(matrah10H),
      kdv10Hesaplanan: round(kdv10H),
      matrah20Hesaplanan: round(matrah20H),
      kdv20Hesaplanan: round(kdv20H),
      toplamHesaplananKdv: topHesaplananKdv,
      toplamHesaplananMatrahVeKdv: topHesaplananMatrahVeKdv,
      matrah10Indirilecek: round(matrah10I),
      kdv10Indirilecek: round(kdv10I),
      matrah20Indirilecek: round(matrah20I),
      kdv20Indirilecek: round(kdv20I),
      toplamIndirilecekKdv: topIndirilecekKdv,
      toplamIndirilecekMatrahVeKdv: topIndirilecekMatrahVeKdv,
      odenecekKdv1: odenecekKdv1,
      oncekiDonemdenDevredenKdv: round(oncekiDonemdenDevredenKdv),
      sonrakiDonemeDevredenKdv: sonrakiDonemeDevredenKdv,
    );
  }

  /// KDV 2 Tevkifat Konsolide Hesaplama
  static Kdv2KonsolideSonuc hesaplaKdv2(List<TevkifatFirmaKaydi> kayitlar) {
    final matrahlar = <TevkifatTuru, Map<int, double>>{};
    final kdvler = <TevkifatTuru, Map<int, double>>{};
    final tevkifatlar = <TevkifatTuru, Map<int, double>>{};

    for (final tur in TevkifatTuru.values) {
      matrahlar[tur] = {8: 0.0, 10: 0.0, 18: 0.0, 20: 0.0};
      kdvler[tur] = {8: 0.0, 10: 0.0, 18: 0.0, 20: 0.0};
      tevkifatlar[tur] = {8: 0.0, 10: 0.0, 18: 0.0, 20: 0.0};
    }

    final turKdvToplam = <TevkifatTuru, double>{
      TevkifatTuru.dokuzBoluOn: 0.0,
      TevkifatTuru.yediBoluOn: 0.0,
      TevkifatTuru.besBoluOn: 0.0,
    };
    final turMatrahToplam = <TevkifatTuru, double>{
      TevkifatTuru.dokuzBoluOn: 0.0,
      TevkifatTuru.yediBoluOn: 0.0,
      TevkifatTuru.besBoluOn: 0.0,
    };
    final turTevkifatToplam = <TevkifatTuru, double>{
      TevkifatTuru.dokuzBoluOn: 0.0,
      TevkifatTuru.yediBoluOn: 0.0,
      TevkifatTuru.besBoluOn: 0.0,
    };

    double butunKdv = 0;
    double butunMatrah = 0;
    double butunTevkifat = 0;

    for (final k in kayitlar) {
      final oran = k.kdvOrani;
      final tur = k.tevkifatTuru;

      matrahlar[tur]![oran] = round((matrahlar[tur]![oran] ?? 0.0) + k.matrahTutari);
      kdvler[tur]![oran] = round((kdvler[tur]![oran] ?? 0.0) + k.kdvTutari);
      tevkifatlar[tur]![oran] = round((tevkifatlar[tur]![oran] ?? 0.0) + k.tevkifatTutari);

      turMatrahToplam[tur] = round(turMatrahToplam[tur]! + k.matrahTutari);
      turKdvToplam[tur] = round(turKdvToplam[tur]! + k.kdvTutari);
      turTevkifatToplam[tur] = round(turTevkifatToplam[tur]! + k.tevkifatTutari);

      butunMatrah += k.matrahTutari;
      butunKdv += k.kdvTutari;
      butunTevkifat += k.tevkifatTutari;
    }

    return Kdv2KonsolideSonuc(
      matrahlar: matrahlar,
      kdvler: kdvler,
      tevkifatlar: tevkifatlar,
      turKdvToplam: turKdvToplam,
      turMatrahToplam: turMatrahToplam,
      turTevkifatToplam: turTevkifatToplam,
      butunKdvlerToplami: round(butunKdv),
      butunMatrahlarToplami: round(butunMatrah),
      butunTevkifatlarToplami: round(butunTevkifat),
    );
  }

  /// Muhtasar Konsolide Hesaplama
  static MuhtasarKonsolideSonuc hesaplaMuhtasar({
    required List<MuhtasarSatiri> satirlar,
    required double muhtasarKesilenDamgaVergisi301,
    required int yil,
    required int ay,
  }) {
    int topKisi = 0;
    double topBrut = 0;
    double topGv = 0;
    double topDv = 0;
    double topNet = 0;
    double topMatrah = 0;

    for (final s in satirlar) {
      topKisi += s.kisiSayisi;
      topBrut += s.brutUcret;
      topGv += s.gelirVergisi;
      topDv += s.damgaVergisi;
      topNet += s.netOdenen;
      topMatrah += s.aylikGelirVergisiMatrahi;
    }

    final istisna = getIstisna(yil, ay);
    final topGvIstisna = round(topKisi * istisna.gelirVergisiIstisnasi);
    final topDvIstisna = round(topKisi * istisna.damgaVergisiIstisnasi);

    final muhtasarDv302 = round(topDv);
    final topDv301ve302 = round(muhtasarKesilenDamgaVergisi301 + muhtasarDv302);

    return MuhtasarKonsolideSonuc(
      toplamKisiSayisi: topKisi,
      toplamBrutUcret: round(topBrut),
      toplamGelirVergisi: round(topGv),
      toplamDamgaVergisi: round(topDv),
      toplamNetOdenen: round(topNet),
      toplamAylikGvMatrahi: round(topMatrah),
      asgariUcretGvIstisnasiToplami: topGvIstisna,
      asgariUcretDvIstisnasiToplami: topDvIstisna,
      muhtasarKesilenDamgaVergisi301: round(muhtasarKesilenDamgaVergisi301),
      muhtasarDamgaVergisi302: muhtasarDv302,
      toplamDamgaVergisi301Ve302: topDv301ve302,
    );
  }

  /// Damga Vergisi (Mizan 360.03.05 - Binde 9,48) Matrah Hesabı
  /// Excel Formülü: A4 = B4*1000/9.48
  static double matrahFromDamga(double damgaTutari) {
    if (damgaTutari <= 0) return 0.0;
    return round(damgaTutari * 1000 / 9.48);
  }

  /// Matrahtan Binde 9,48 Damga Vergisi Hesabı
  static double damgaFromMatrah(double matrah) {
    if (matrah <= 0) return 0.0;
    return round(matrah * 0.00948);
  }
}
