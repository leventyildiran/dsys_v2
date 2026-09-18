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
    varsayilanMemurMaasKatsayisi: 1.387871,
  ),
  usemSurekliEgitim(
    katkiSekmeAdi: 'Dönem Ek Katsayı',
    varsayilanMemurMaasKatsayisi: 0.907796,
  );

  const DanismanlikExcelProfili({
    required this.katkiSekmeAdi,
    required this.varsayilanMemurMaasKatsayisi,
  });

  final String katkiSekmeAdi;
  final double varsayilanMemurMaasKatsayisi;
}

/// DTS / USEM Excel şablonu formüllerinin birebir Dart karşılığı.
class DanismanlikExcelHesaplama {
  DanismanlikExcelHesaplama._();

  /// Güncel memur maaş katsayısı (ek ders tavanı)
  static const double memurMaasKatsayisiGuncel = 1.387871;

  static DanismanlikExcelProfili profilFromDanismanlik(DanismanlikModel d) {
    switch (d.tur) {
      case DanismanlikTuru.egitimKuru:
        return DanismanlikExcelProfili.usemSurekliEgitim;
      case DanismanlikTuru.standart:
      default:
        return DanismanlikExcelProfili.dtsDanismanlik;
    }
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
    if (ekGostergeler.containsKey(unvan)) return ekGostergeler[unvan]!;
    final clean = unvan.replaceAll(' ', '').replaceAll('.', '').toLowerCase();
    for (final e in ekGostergeler.entries) {
      final keyClean = e.key.replaceAll(' ', '').replaceAll('.', '').toLowerCase();
      if (clean == keyClean) return e.value;
    }
    for (final e in ekGostergeler.entries) {
      if (unvan.startsWith(e.key) || unvan.contains(e.key.replaceAll('.', ''))) {
        return e.value;
      }
    }
    return ekGostergeler[unvan] ?? 160;
  }

  static double unvanKatsayisi(String unvan, [double? kayitli]) {
    if (unvanKatsayilari.containsKey(unvan)) {
      return unvanKatsayilari[unvan]!;
    }
    final clean = unvan.replaceAll(' ', '').replaceAll('.', '').toLowerCase();
    for (final e in unvanKatsayilari.entries) {
      final keyClean = e.key.replaceAll(' ', '').replaceAll('.', '').toLowerCase();
      if (clean == keyClean) return e.value;
    }
    if (kayitli != null && kayitli > 0 && kayitli <= 3.5) return kayitli;
    for (final e in unvanKatsayilari.entries) {
      if (unvan.startsWith(e.key)) return e.value;
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
    final katkiPayi = _round(kdvHaricGelir - hazine - bap - aracGerec, 2);
    final dagMaksAkademikPay = katkiPayi;

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
    double? memurMaasKatsayisi,
    bool tavanUygula = false,
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

    final aktifMemurKatsayisi =
        memurMaasKatsayisi ?? profil.varsayilanMemurMaasKatsayisi;

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
      final bazSaatlik = p.ekGosterge * aktifMemurKatsayisi;
      final tavanSaatlik = p.mesaiIci ? bazSaatlik * 2 : bazSaatlik * 3.2;

      final tavanAsildi = kursSaatlik > tavanSaatlik && tavanSaatlik > 0;
      
      double odenebilir = brutHakedis;
      double havuz = 0.0;

      if (tavanAsildi && tavanUygula) {
        odenebilir = _round(tavanSaatlik * p.dersSaati, 2);
        havuz = _round(brutHakedis - odenebilir, 2);
      }

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
      netOdemeToplam: _round(netOdemeToplam, 2),
      havuzToplam: _round(havuzToplam + artikBakiye, 2),
      artikBakiye: artikBakiye,
    );
  }

  /// 2547 Sayılı Kanun Madde 58/k — Puan ve saat tavanı YOKTUR.
  /// Kalan %85 pay doğrudan sözleşme ve taksit esaslarına göre personele ödenir.
  static DanismanlikExcelSonuc hesapla58k({
    required ExcelKesintiSonuc kesinti,
    required List<ExcelPersonelGirdi> personeller,
    required double odenecekTutar,
    double kalanBakiye = 0.0,
  }) {
    if (personeller.isEmpty) {
      return DanismanlikExcelSonuc(
        kesinti: kesinti,
        toplamPuan: 0,
        donemKatsayi: 1.0,
        saglama: 0,
        personelSatirlari: const [],
        artikBakiye: kesinti.katkiPayi,
      );
    }

    final satirlar = <ExcelPersonelSonuc>[];
    final dagitimlar = <DagitimModel>[];

    final n = personeller.length;
    // Eğer personel listesinde puan alanı girilmişse bunu sözleşme yüzdesi (%) kabul et
    double toplamOran = 0.0;
    for (final p in personeller) {
      toplamOran += (p.puan > 0 ? p.puan : (100.0 / n));
    }
    if (toplamOran <= 0) toplamOran = 100.0;
    final bolen = toplamOran > 100.0 ? toplamOran : 100.0;

    double netOdemeToplam = 0;

    for (var i = 0; i < personeller.length; i++) {
      final p = personeller[i];
      final girilenPuan = p.puan > 0 ? p.puan : (100.0 / n);
      final personelOrani = girilenPuan / bolen;
      final brutHakedis = _round(odenecekTutar * personelOrani, 2);

      netOdemeToplam += brutHakedis;

      satirlar.add(
        ExcelPersonelSonuc(
          girdi: p,
          bireyselNetKatkiPuani: 0,
          donemKatsayi: 1.0,
          kursSaatlikUcreti: 0,
          tavanSaatlikUcreti: 0,
          brutHakedis: brutHakedis,
          odenebilirHakedis: brutHakedis,
          havuzTutari: 0,
        ),
      );

      dagitimlar.add(
        DagitimModel(
          personelId: p.personelId,
          adSoyad: p.adSoyad,
          unvan: p.unvan,
          unvanKatsayisi: 1.0,
          ekGosterge: p.ekGosterge,
          faaliyetTuru: '2547 Sayılı Kanun Madde 58/k Sözleşmeli Danışmanlık',
          faaliyetAdeti: 1,
          faaliyetTabanPuani: girilenPuan,
          mesaiIci: false,
          toplamPuan: 0,
          bireyselPuan: 0,
          brutHakedis: brutHakedis,
          tavanKontrol: false,
          tavanLimitTutari: brutHakedis,
          odenebilirHakedis: brutHakedis,
          fazlalikHavuzTutari: 0,
        ),
      );
    }

    final dagitilmayanFark = _round(odenecekTutar - netOdemeToplam, 2);
    final nihaiArtikBakiye = kalanBakiye + (dagitilmayanFark > 0 ? dagitilmayanFark : 0.0);

    return DanismanlikExcelSonuc(
      kesinti: kesinti,
      toplamPuan: 0,
      donemKatsayi: 1.0,
      saglama: _round(netOdemeToplam, 2),
      personelSatirlari: satirlar,
      dagitimlar: dagitimlar,
      netOdemeToplam: _round(netOdemeToplam, 2),
      havuzToplam: 0,
      artikBakiye: _round(nihaiArtikBakiye, 2),
    );
  }

  /// 2547 Sayılı Kanun Madde 58/e — Üniversite imkânları kullanılmaksızın verilen danışmanlık.
  /// Kesintiler: %1 Hazine, %5 BAP, Kullanıcının belirlediği Birim/Kurum Payı (varsayılan %15).
  /// Kalan tutar (varsayılan %79) dağıtılabilir katkı payıdır.
  /// Gelir Vergisi (varsayılan %15) ve Damga Vergisi (%0.759) stopajına tabidir.
  static DanismanlikExcelSonuc hesapla58e({
    required ExcelKesintiSonuc kesinti,
    required List<ExcelPersonelGirdi> personeller,
    required double odenecekTutar,
    double kalanBakiye = 0.0,
    int gelirVergisiOrani = 15,
    double damgaVergisiOrani = 0.00759,
    bool tavanUygula = false,
    double? memurMaasKatsayisi,
  }) {
    if (personeller.isEmpty) {
      return DanismanlikExcelSonuc(
        kesinti: kesinti,
        toplamPuan: 0,
        donemKatsayi: 1.0,
        saglama: 0,
        personelSatirlari: const [],
        artikBakiye: kesinti.katkiPayi,
      );
    }

    final satirlar = <ExcelPersonelSonuc>[];
    final dagitimlar = <DagitimModel>[];

    final n = personeller.length;
    double toplamOran = 0.0;
    for (final p in personeller) {
      toplamOran += (p.puan > 0 ? p.puan : (100.0 / n));
    }
    if (toplamOran <= 0) toplamOran = 100.0;
    final bolen = toplamOran > 100.0 ? toplamOran : 100.0;

    double netOdemeToplam = 0;
    double havuzToplam = 0;
    double brutToplam = 0;

    for (var i = 0; i < personeller.length; i++) {
      final p = personeller[i];
      final girilenPuan = p.puan > 0 ? p.puan : (100.0 / n);
      final personelOrani = girilenPuan / bolen;
      final brutHakedis = _round(odenecekTutar * personelOrani, 2);
      brutToplam += brutHakedis;

      // Tavan kontrolü
      final aktifMemurKatsayisi = memurMaasKatsayisi ?? memurMaasKatsayisiGuncel;
      final bazSaatlik = p.ekGosterge * aktifMemurKatsayisi;
      final tavanSaatlik = p.mesaiIci ? bazSaatlik * 2 : bazSaatlik * 3.2;
      final tavanTutari = _round(tavanSaatlik * (p.dersSaati > 0 ? p.dersSaati : 10), 2);

      final tavanAsildi = brutHakedis > tavanTutari && tavanTutari > 0;
      double odenebilirBrut = brutHakedis;
      double havuz = 0.0;

      if (tavanAsildi && tavanUygula) {
        odenebilirBrut = tavanTutari;
        havuz = _round(brutHakedis - odenebilirBrut, 2);
      }

      // Vergi kesintileri
      final gelirVergisi = _round(odenebilirBrut * (gelirVergisiOrani / 100), 2);
      final damgaVergisi = _round(odenebilirBrut * damgaVergisiOrani, 2);
      final netEleGecen = _round(odenebilirBrut - gelirVergisi - damgaVergisi, 2);

      netOdemeToplam += netEleGecen;
      havuzToplam += havuz;

      satirlar.add(
        ExcelPersonelSonuc(
          girdi: p,
          bireyselNetKatkiPuani: p.puan,
          donemKatsayi: 1.0,
          kursSaatlikUcreti: p.dersSaati > 0 ? _round(brutHakedis / p.dersSaati, 2) : 0,
          tavanSaatlikUcreti: tavanSaatlik,
          brutHakedis: brutHakedis,
          odenebilirHakedis: netEleGecen,
          havuzTutari: havuz,
        ),
      );

      dagitimlar.add(
        DagitimModel(
          personelId: p.personelId,
          adSoyad: p.adSoyad,
          unvan: p.unvan,
          unvanKatsayisi: p.unvanKatsayisi,
          ekGosterge: p.ekGosterge,
          faaliyetTuru: '2547 Sayılı Kanun Madde 58/e Danışmanlık ve Hizmet Geliri',
          faaliyetAdeti: p.dersSaati.round() > 0 ? p.dersSaati.round() : 1,
          faaliyetTabanPuani: p.puan,
          mesaiIci: p.mesaiIci,
          toplamPuan: toplamOran,
          bireyselPuan: p.puan,
          brutHakedis: brutHakedis,
          tavanKontrol: tavanAsildi,
          tavanLimitTutari: tavanTutari,
          odenebilirHakedis: netEleGecen,
          fazlalikHavuzTutari: havuz,
        ),
      );
    }

    final dagitilmayanFark = _round(odenecekTutar - brutToplam, 2);
    final nihaiArtikBakiye = kalanBakiye + (dagitilmayanFark > 0 ? dagitilmayanFark : 0.0);

    return DanismanlikExcelSonuc(
      kesinti: kesinti,
      toplamPuan: toplamOran,
      donemKatsayi: 1.0,
      saglama: _round(odenecekTutar, 2),
      personelSatirlari: satirlar,
      dagitimlar: dagitimlar,
      netOdemeToplam: _round(netOdemeToplam, 2),
      havuzToplam: _round(havuzToplam, 2),
      artikBakiye: _round(nihaiArtikBakiye, 2),
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
    String? adSoyad,
    String? unvan,
    double? puan,
    double? unvanKatsayisi,
    int? ekGosterge,
    double? dersSaati,
    bool? mesaiIci,
    String? faaliyetTuru,
  }) {
    return ExcelPersonelGirdi(
      personelId: personelId,
      adSoyad: adSoyad ?? this.adSoyad,
      unvan: unvan ?? this.unvan,
      puan: puan ?? this.puan,
      unvanKatsayisi: unvanKatsayisi ?? this.unvanKatsayisi,
      ekGosterge: ekGosterge ?? this.ekGosterge,
      dersSaati: dersSaati ?? this.dersSaati,
      mesaiIci: mesaiIci ?? this.mesaiIci,
      faaliyetTuru: faaliyetTuru ?? this.faaliyetTuru,
    );
  }

  Map<String, dynamic> toMap() => {
    'personelId': personelId,
    'adSoyad': adSoyad,
    'unvan': unvan,
    'puan': puan,
    'unvanKatsayisi': unvanKatsayisi,
    'ekGosterge': ekGosterge,
    'dersSaati': dersSaati,
    'mesaiIci': mesaiIci,
    'faaliyetTuru': faaliyetTuru,
  };

  factory ExcelPersonelGirdi.fromMap(Map<String, dynamic> map) => ExcelPersonelGirdi(
    personelId: map['personelId'] as String? ?? '',
    adSoyad: map['adSoyad'] as String? ?? '',
    unvan: map['unvan'] as String? ?? '',
    puan: (map['puan'] as num?)?.toDouble() ?? 20.0,
    unvanKatsayisi: (map['unvanKatsayisi'] as num?)?.toDouble() ?? 2.0,
    ekGosterge: (map['ekGosterge'] as num?)?.toInt() ?? 160,
    dersSaati: (map['dersSaati'] as num?)?.toDouble() ?? 5.0,
    mesaiIci: map['mesaiIci'] as bool? ?? false,
    faaliyetTuru: map['faaliyetTuru'] as String? ?? 'Danışmanlık',
  );
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

  bool get herhangiBirTavanAsildi => personelSatirlari.any(
        (s) => s.kursSaatlikUcreti > s.tavanSaatlikUcreti && s.tavanSaatlikUcreti > 0,
      );

  double get maksimumTavanSaatlik => personelSatirlari.isEmpty
      ? 0.0
      : personelSatirlari.map((s) => s.tavanSaatlikUcreti).reduce((a, b) => a > b ? a : b);

  double get toplamTavanKesintisi => personelSatirlari.fold<double>(
        0.0,
        (sum, s) => sum + s.havuzTutari,
      );
}
