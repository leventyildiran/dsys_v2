import '../../../core/hesaplama_motoru.dart';
import '../../../core/turkce_format.dart';
import '../models/dagitim_model.dart';
import '../models/danismanlik_model.dart';

/// Birim Excel şablon profilleri.
///
/// **DTS danışmanlık** — `Orhan ŞAŞMAZ … DTS Hesaplama tablo (Danışmanlık).xlsx`
/// - Sayfa: KATKI PAYI HESAPLAMA
/// - Memur maaş katsayısı: 1,387871 (ek ders tavanı)
///
/// **USEM sürekli eğitim** — `USEM KATKI PAYI HESAPLAMA.xlsx`
/// - Sayfa: DÖNEM EK KATSAYI HESAPLAMA (aynı sütunlar, farklı isim)
/// - Memur maaş katsayısı: 0,907796
/// - LİSTE sayfası: kursiyer ödemeleri → toplam kurs geliri
enum DanismanlikExcelProfili {
  dtsDanismanlik(
    katkiSekmeAdi: 'Katkı Payı',
    memurMaasKatsayisi: 1.387871,
  ),
  usemSurekliEgitim(
    katkiSekmeAdi: 'Dönem Ek Katsayı',
    memurMaasKatsayisi: 0.907796,
  );

  const DanismanlikExcelProfili({
    required this.katkiSekmeAdi,
    required this.memurMaasKatsayisi,
  });

  final String katkiSekmeAdi;
  final double memurMaasKatsayisi;
}

/// DTS / USEM Excel şablonu formüllerinin birebir Dart karşılığı.
class DanismanlikExcelHesaplama {
  DanismanlikExcelHesaplama._();

  /// DTS varsayılanı (geriye dönük uyumluluk).
  static const double memurMaasKatsayisiDts = 1.387871;

  /// USEM `DÖNEM EK KATSAYI HESAPLAMA` sayfasındaki değer.
  static const double memurMaasKatsayisiUsem = 0.907796;

  static DanismanlikExcelProfili profilFromDanismanlik(DanismanlikModel d) {
    final blob = [
      d.birimKisaAd,
      d.konusu,
      d.firmaUnvan,
    ].whereType<String>().join(' ').toLowerCase();
    if (blob.contains('usem') ||
        blob.contains('sürekli eğitim') ||
        blob.contains('surekli egitim')) {
      return DanismanlikExcelProfili.usemSurekliEgitim;
    }
    return DanismanlikExcelProfili.dtsDanismanlik;
  }

  static const Map<String, int> ekGostergeler = {
    'Profesör': 300,
    'Prof. Dr.': 300,
    'Doçent': 250,
    'Doç. Dr.': 250,
    'Dr.Öğr.Üyesi': 200,
    'Dr. Öğr. Üyesi': 200,
    'Öğr.Gör.Dr.': 160,
    'Öğr. Gör. Dr.': 160,
    'Öğr.Gör.': 160,
    'Öğr. Gör.': 160,
    'Arş.Gör.Dr.': 160,
    'Arş. Gör. Dr.': 160,
    'Arş.Gör.': 160,
  };

  static const Map<String, double> unvanKatsayilari = {
    'Profesör': 3.0,
    'Prof. Dr.': 3.0,
    'Doçent': 2.5,
    'Doç. Dr.': 2.5,
    'Dr.Öğr.Üyesi': 2.2,
    'Dr. Öğr. Üyesi': 2.2,
    'Öğr.Gör.Dr.': 2.0,
    'Öğr. Gör. Dr.': 2.0,
    'Öğr.Gör.': 2.0,
    'Öğr. Gör.': 2.0,
    'Arş.Gör.Dr.': 2.0,
    'Arş. Gör. Dr.': 2.0,
    'Arş.Gör.': 2.0,
  };

  static int ekGosterge(String unvan) {
    for (final e in ekGostergeler.entries) {
      if (unvan.contains(e.key.replaceAll('.', '')) ||
          unvan.startsWith(e.key)) {
        return e.value;
      }
    }
    return ekGostergeler[unvan] ?? 160;
  }

  static double unvanKatsayisi(String unvan, [double? kayitli]) {
    if (kayitli != null && kayitli > 0 && kayitli <= 3.5) return kayitli;
    for (final e in unvanKatsayilari.entries) {
      if (unvan.contains(e.key.split('.').first)) return e.value;
    }
    return unvanKatsayilari[unvan] ?? kayitli ?? 2.0;
  }

  /// DAĞ. MAKS. PAY — B11 üzerinden kesintiler (Excel ROUND formülleri).
  static ExcelKesintiSonuc kesintiler({
    required double kdvHaricGelir,
    int hazineOrani = 1,
    int bapOrani = 5,
    double aracGerecOrani = 0.45,
  }) {
    final hazine = _round(kdvHaricGelir * (hazineOrani / 100), 2);
    final bap = _round(kdvHaricGelir * (bapOrani / 100), 2);
    final aracGerec = _round(kdvHaricGelir * aracGerecOrani, 2);
    // G18 = B11-(G15+G16+G17) — Excel birebir
    final katkiPayi = kdvHaricGelir - hazine - bap - aracGerec;
    final dagMaksAkademikPay = _round(kdvHaricGelir * 0.49, 2);

    return ExcelKesintiSonuc(
      kdvHaricGelir: kdvHaricGelir,
      hazinePayi: hazine,
      bapPayi: bap,
      aracGerecPayi: aracGerec,
      katkiPayi: katkiPayi,
      dagMaksAkademikPay: dagMaksAkademikPay,
      toplam: hazine + bap + aracGerec + katkiPayi,
    );
  }

  /// Brüt (KDV dahil) taksitten Excel matrahı.
  static ExcelKesintiSonuc kesintilerBrutten({
    required double brutTutar,
    required int kdvOrani,
    int hazineOrani = 1,
    int bapOrani = 5,
    double aracGerecOrani = 0.45,
  }) {
    final matrah = HesaplamaMotoru.kdvHaricMatrahHesapla(brutTutar, kdvOrani);
    final sonuc = kesintiler(
      kdvHaricGelir: matrah,
      hazineOrani: hazineOrani,
      bapOrani: bapOrani,
      aracGerecOrani: aracGerecOrani,
    );
    return sonuc;
  }

  static double kdvTutari(double matrah, int kdvOrani) =>
      _round(matrah * (kdvOrani / 100), 2);

  static double genelToplam(double matrah, int kdvOrani) =>
      _round(matrah + kdvTutari(matrah, kdvOrani), 2);

  /// Danışmanlık personel listesinden Excel girdi satırları üretir.
  static List<ExcelPersonelGirdi> personelGirdileriFromDanismanlik(
    DanismanlikModel danismanlik,
  ) {
    return danismanlik.personeller
        .where((p) => p.faaliyetPuani > 0)
        .map(
          (p) => ExcelPersonelGirdi(
            personelId: p.personel.id,
            adSoyad: p.personel.adSoyad,
            unvan: p.personel.unvan,
            puan: p.faaliyetPuani,
            unvanKatsayisi: unvanKatsayisi(
              p.personel.unvan,
              p.personel.unvanKatsayisi,
            ),
            ekGosterge: ekGosterge(p.personel.unvan),
            dersSaati: p.dersSaati > 0 ? p.dersSaati : 1,
            mesaiIci: p.mesaiIci,
            faaliyetTuru: p.faaliyetTuru ?? 'Danışmanlık',
          ),
        )
        .toList();
  }

  /// Otomatik katsayı (maksPay / toplamPuan, Excel C23 kuralı).
  static double otomatikDonemKatsayisi({
    required ExcelKesintiSonuc kesinti,
    required List<ExcelPersonelGirdi> personeller,
  }) {
    if (personeller.isEmpty) return 0;
    final satirlar = personeller
        .map(
          (p) => ExcelPersonelSonuc(
            girdi: p,
            bireyselNetKatkiPuani: p.puan * p.unvanKatsayisi * p.dersSaati,
          ),
        )
        .toList();
    final toplamPuan = satirlar.fold<double>(
      0,
      (s, x) => s + x.bireyselNetKatkiPuani,
    );
    return _donemKatsayiSaglama(kesinti.katkiPayi, toplamPuan, satirlar);
  }

  /// KATKI PAYI + tavan — Excel satır formülleri.
  ///
  /// [manualDonemKatsayi] verilirse otomatik hesap yerine bu katsayı kullanılır
  /// (manuel müdahale / Excel'deki elle girilen dönem katsayısı).
  static DanismanlikExcelSonuc hesapla({
    required ExcelKesintiSonuc kesinti,
    required List<ExcelPersonelGirdi> personeller,
    double? manualDonemKatsayi,
    DanismanlikExcelProfili profil = DanismanlikExcelProfili.dtsDanismanlik,
  }) {
    if (personeller.isEmpty) {
      return DanismanlikExcelSonuc(
        kesinti: kesinti,
        toplamPuan: 0,
        donemKatsayi: 0,
        saglama: 0,
        personelSatirlari: const [],
        artikBakiye: kesinti.katkiPayi,
      );
    }

    final satirlar = <ExcelPersonelSonuc>[];
    double toplamPuan = 0;

    for (final p in personeller) {
      // E10 = B10*C10*D10
      final bireysel = p.puan * p.unvanKatsayisi * p.dersSaati;
      toplamPuan += bireysel;
      satirlar.add(
        ExcelPersonelSonuc(girdi: p, bireyselNetKatkiPuani: bireysel),
      );
    }

    final maksPay = kesinti.katkiPayi;
    final donemKatsayi = manualDonemKatsayi != null
        ? double.parse(manualDonemKatsayi.toStringAsFixed(2))
        : _donemKatsayiSaglama(maksPay, toplamPuan, satirlar);
    final saglama = _round(toplamPuan * donemKatsayi, 2);

    double netOdemeToplam = 0;
    double havuzToplam = 0;
    final dagitimlar = <DagitimModel>[];

    for (var i = 0; i < satirlar.length; i++) {
      final s = satirlar[i];
      final p = s.girdi;

      // Brüt hakediş = bireysel × katsayı (Excel sağlama satırı)
      final brutHakedis = _round(s.bireyselNetKatkiPuani * donemKatsayi, 2);

      // D27 = A27*B27/C27 — Kursun 1 saatlik ücreti
      final kursSaatlik = p.dersSaati > 0
          ? _round(s.bireyselNetKatkiPuani * donemKatsayi / p.dersSaati, 2)
          : 0.0;

      // C32 = A32*B32*2, D32 = C32*1.6  → mesai dışı = A*B*3.2
      final bazSaatlik = p.ekGosterge * profil.memurMaasKatsayisi;
      final tavanSaatlik = p.mesaiIci ? bazSaatlik * 2 : bazSaatlik * 3.2;

      final tavanAsildi = kursSaatlik > tavanSaatlik;
      // Excel KATKI PAYI sayfası brüt hakedişi doğrudan yazar; tavan ayrı bilgi bloğudur.
      final odenebilir = brutHakedis;
      final havuz = 0.0;

      netOdemeToplam += odenebilir;
      havuzToplam += havuz;

      dagitimlar.add(
        DagitimModel(
          personelId: p.personelId,
          adSoyad: p.adSoyad,
          unvan: p.unvan,
          unvanKatsayisi: p.unvanKatsayisi,
          ekGosterge: p.ekGosterge,
          faaliyetTuru: p.faaliyetTuru,
          faaliyetAdeti: p.dersSaati.round(),
          faaliyetTabanPuani: p.puan,
          mesaiIci: p.mesaiIci,
          toplamPuan: toplamPuan,
          bireyselPuan: s.bireyselNetKatkiPuani,
          brutHakedis: brutHakedis,
          tavanKontrol: tavanAsildi,
          tavanLimitTutari: _round(tavanSaatlik * p.dersSaati, 2),
          odenebilirHakedis: odenebilir,
          fazlalikHavuzTutari: havuz,
        ),
      );

      satirlar[i] = s.copyWith(
        donemKatsayi: donemKatsayi,
        kursSaatlikUcreti: kursSaatlik,
        tavanSaatlikUcreti: tavanSaatlik,
        brutHakedis: brutHakedis,
        odenebilirHakedis: odenebilir,
        havuzTutari: havuz,
      );
    }

    final brutToplam = satirlar.fold<double>(0, (s, x) => s + x.brutHakedis);
    final artikBakiye = _round(maksPay - brutToplam, 2);

    return DanismanlikExcelSonuc(
      kesinti: kesinti,
      toplamPuan: toplamPuan,
      donemKatsayi: donemKatsayi,
      saglama: saglama,
      personelSatirlari: satirlar,
      dagitimlar: dagitimlar,
      netOdemeToplam: netOdemeToplam,
      havuzToplam: havuzToplam + artikBakiye,
      artikBakiye: artikBakiye,
    );
  }

  static DanismanlikExcelSonuc hesaplaDanismanlik({
    required DanismanlikModel danismanlik,
    required double brutTaksitTutari,
  }) {
    final kesinti = kesintilerBrutten(
      brutTutar: brutTaksitTutari,
      kdvOrani: danismanlik.kdvOrani,
      hazineOrani: danismanlik.hazinePayiOrani,
      bapOrani: danismanlik.bapPayiOrani,
      aracGerecOrani: danismanlik.aracGerecPayiOrani / 100,
    );

    final personeller = personelGirdileriFromDanismanlik(danismanlik);
    return hesapla(
      kesinti: kesinti,
      personeller: personeller,
      profil: profilFromDanismanlik(danismanlik),
    );
  }

  /// Excel C23 kuralı: katsayı 2 hane; toplam hakediş maks payı aşarsa 0,01 düşür.
  static double _donemKatsayiSaglama(
    double maksPay,
    double toplamPuan,
    List<ExcelPersonelSonuc> satirlar,
  ) {
    if (toplamPuan <= 0) return 0;
    var katsayi = double.parse((maksPay / toplamPuan).toStringAsFixed(2));

    while (true) {
      var toplam = 0.0;
      for (final s in satirlar) {
        toplam += _round(s.bireyselNetKatkiPuani * katsayi, 2);
      }
      if (toplam > maksPay + 0.001) {
        katsayi = double.parse((katsayi - 0.01).toStringAsFixed(2));
        if (katsayi < 0) return 0;
      } else {
        break;
      }
    }
    return katsayi;
  }

  static double _round(double v, int d) {
    final m = _pow10(d);
    return ((v * m).roundToDouble()) / m;
  }

  static double _pow10(int d) {
    var r = 1.0;
    for (var i = 0; i < d; i++) {
      r *= 10;
    }
    return r;
  }
}

class ExcelKesintiSonuc {
  const ExcelKesintiSonuc({
    required this.kdvHaricGelir,
    required this.hazinePayi,
    required this.bapPayi,
    required this.aracGerecPayi,
    required this.katkiPayi,
    required this.dagMaksAkademikPay,
    required this.toplam,
  });

  final double kdvHaricGelir;
  final double hazinePayi;
  final double bapPayi;
  final double aracGerecPayi;
  final double katkiPayi;
  final double dagMaksAkademikPay;
  final double toplam;
}

class ExcelPersonelGirdi {
  const ExcelPersonelGirdi({
    required this.personelId,
    required this.adSoyad,
    required this.unvan,
    required this.puan,
    required this.unvanKatsayisi,
    required this.ekGosterge,
    required this.dersSaati,
    this.mesaiIci = true,
    this.faaliyetTuru = 'Danışmanlık',
  });

  final String personelId;
  final String adSoyad;
  final String unvan;
  final double puan;
  final double unvanKatsayisi;
  final int ekGosterge;
  final double dersSaati;
  final bool mesaiIci;
  final String faaliyetTuru;

  ExcelPersonelGirdi copyWith({
    double? puan,
    double? unvanKatsayisi,
    int? ekGosterge,
    double? dersSaati,
    bool? mesaiIci,
    String? faaliyetTuru,
  }) {
    return ExcelPersonelGirdi(
      personelId: personelId,
      adSoyad: adSoyad,
      unvan: unvan,
      puan: puan ?? this.puan,
      unvanKatsayisi: unvanKatsayisi ?? this.unvanKatsayisi,
      ekGosterge: ekGosterge ?? this.ekGosterge,
      dersSaati: dersSaati ?? this.dersSaati,
      mesaiIci: mesaiIci ?? this.mesaiIci,
      faaliyetTuru: faaliyetTuru ?? this.faaliyetTuru,
    );
  }
}

class ExcelPersonelSonuc {
  const ExcelPersonelSonuc({
    required this.girdi,
    required this.bireyselNetKatkiPuani,
    this.donemKatsayi = 0,
    this.kursSaatlikUcreti = 0,
    this.tavanSaatlikUcreti = 0,
    this.brutHakedis = 0,
    this.odenebilirHakedis = 0,
    this.havuzTutari = 0,
  });

  final ExcelPersonelGirdi girdi;
  final double bireyselNetKatkiPuani;
  final double donemKatsayi;
  final double kursSaatlikUcreti;
  final double tavanSaatlikUcreti;
  final double brutHakedis;
  final double odenebilirHakedis;
  final double havuzTutari;

  ExcelPersonelSonuc copyWith({
    double? donemKatsayi,
    double? kursSaatlikUcreti,
    double? tavanSaatlikUcreti,
    double? brutHakedis,
    double? odenebilirHakedis,
    double? havuzTutari,
  }) {
    return ExcelPersonelSonuc(
      girdi: girdi,
      bireyselNetKatkiPuani: bireyselNetKatkiPuani,
      donemKatsayi: donemKatsayi ?? this.donemKatsayi,
      kursSaatlikUcreti: kursSaatlikUcreti ?? this.kursSaatlikUcreti,
      tavanSaatlikUcreti: tavanSaatlikUcreti ?? this.tavanSaatlikUcreti,
      brutHakedis: brutHakedis ?? this.brutHakedis,
      odenebilirHakedis: odenebilirHakedis ?? this.odenebilirHakedis,
      havuzTutari: havuzTutari ?? this.havuzTutari,
    );
  }
}

class DanismanlikExcelSonuc {
  const DanismanlikExcelSonuc({
    required this.kesinti,
    required this.toplamPuan,
    required this.donemKatsayi,
    required this.saglama,
    required this.personelSatirlari,
    this.dagitimlar = const [],
    this.netOdemeToplam = 0,
    this.havuzToplam = 0,
    this.artikBakiye = 0,
  });

  final ExcelKesintiSonuc kesinti;
  final double toplamPuan;
  final double donemKatsayi;
  final double saglama;
  final List<ExcelPersonelSonuc> personelSatirlari;
  final List<DagitimModel> dagitimlar;
  final double netOdemeToplam;
  final double havuzToplam;
  final double artikBakiye;

  String get donemKatsayiMetin => TurkceFormat.katsayi(donemKatsayi);
}
