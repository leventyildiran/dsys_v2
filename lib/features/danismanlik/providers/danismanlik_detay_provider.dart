import 'dart:async';

import 'package:flutter/foundation.dart';
import '../../../core/hesaplama_motoru.dart';
import '../../../core/karar_metni_servisi.dart';
import '../../../core/turkce_format.dart';
import '../../personel/services/personel_hakedis_service.dart';
import '../../yk_karar/models/yk_karar_model.dart';
import '../../yk_karar/services/yk_karar_service.dart';
import '../models/dagitim_model.dart';
import '../models/danismanlik_model.dart';
import '../models/taksit_model.dart';
import '../services/dagitim_service.dart';
import '../services/danismanlik_excel_hesaplama.dart';
import '../services/taksit_onay_akisi.dart';
import '../services/taksit_service.dart';

class DanismanlikDetayProvider extends ChangeNotifier {
  DanismanlikDetayProvider(
    this.danismanlik, {
    TaksitService? taksitService,
    DagitimService? dagitimService,
    PersonelHakedisService? hakedisService,
    YkKararService? ykKararService,
  })  : _taksitService = taksitService ?? TaksitService(),
        _dagitimService = dagitimService ?? DagitimService(),
        _hakedisService = hakedisService ?? PersonelHakedisService(),
        _ykKararService = ykKararService ?? YkKararService() {
    _initTaksitlerStream();
  }

  final DanismanlikModel danismanlik;
  final TaksitService _taksitService;
  final DagitimService _dagitimService;
  final PersonelHakedisService _hakedisService;
  final YkKararService _ykKararService;

  List<TaksitModel> _taksitler = [];
  List<TaksitModel> get taksitler => _taksitler;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  void _initTaksitlerStream() {
    _taksitSub?.cancel();
    _taksitSub = _taksitService.streamTaksitler(danismanlik.id).listen((data) {
      _taksitler = data;
      notifyListeners();
    });
  }

  StreamSubscription<List<TaksitModel>>? _taksitSub;

  @override
  void dispose() {
    _taksitSub?.cancel();
    super.dispose();
  }

  /// Yeni taksit oluşturur (Sadece taslak olarak).
  Future<void> yeniTaksitEkle(int ayNo, double brutTutar) async {
    _setLoading(true);
    try {
      final taksit = TaksitModel(
        id: '',
        ayNo: ayNo,
        brutTutar: brutTutar,
        durum: TaksitDurum.taslak,
      );
      await _taksitService.create(danismanlik.id, taksit);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Taksit dağıtımını hesaplar (kaydetmeden önizleme).
  Future<DagitimHesapSonuc?> dagitimHesapla(
    TaksitModel taksit,
    String islemAyi,
  ) async {
    try {
      return await _hesaplaDagitim(taksit, islemAyi);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  static String guncelIslemAyi() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Excel personel girdileri ve isteğe bağlı manuel katsayı ile hesaplar.
  DagitimHesapSonuc? hesaplaExcelFromGirdiler({
    required TaksitModel taksit,
    required List<ExcelPersonelGirdi> personeller,
    double? manualDonemKatsayi,
  }) {
    if (danismanlik.tur != DanismanlikTuru.standart) return null;

    final excel = DanismanlikExcelHesaplama.hesapla(
      kesinti: DanismanlikExcelHesaplama.kesintilerBrutten(
        brutTutar: taksit.brutTutar,
        kdvOrani: danismanlik.kdvOrani,
        hazineOrani: danismanlik.hazinePayiOrani,
        bapOrani: danismanlik.bapPayiOrani,
        aracGerecOrani: danismanlik.aracGerecPayiOrani / 100,
      ),
      personeller: personeller,
      manualDonemKatsayi: manualDonemKatsayi,
      profil: DanismanlikExcelHesaplama.profilFromDanismanlik(danismanlik),
    );

    final k = excel.kesinti;
    final kesinti = KesintiBilgisi(
      kdvHaricMatrah: k.kdvHaricGelir,
      hazinePayi: k.hazinePayi,
      bapPayi: k.bapPayi,
      aracGerecPayi: k.aracGerecPayi,
      dagitilabilirTutar: k.katkiPayi,
    );

    final veriler = _kararMetniVerileriHazirla(
      excel.donemKatsayi,
      k.katkiPayi,
    );
    final kararMetni = KararMetniServisi.metinUret(
      isStandart: true,
      veriler: veriler,
    );

    return DagitimHesapSonuc(
      kesinti: kesinti,
      katsayi: excel.donemKatsayi,
      dagitimlar: excel.dagitimlar,
      kararMetni: kararMetni,
      artikBakiye: excel.artikBakiye,
      excelSonuc: excel,
    );
  }

  /// Önceden hesaplanmış sonucu kaydeder (Excel ekranındaki manuel düzenlemeler).
  Future<void> dagitimiKaydetSonuc(
    TaksitModel taksit,
    String islemAyi,
    DagitimHesapSonuc sonuc,
    bool arshiveGonder,
  ) async {
    _setLoading(true);
    try {
      await _dagitimiKaydet(taksit, islemAyi, sonuc, arshiveGonder);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Taksit dağıtımını hesaplar ve eğer istenirse sisteme/arşive kaydeder.
  Future<void> dagitimiHesaplaVeKaydet(
    TaksitModel taksit,
    String islemAyi,
    bool arshiveGonder,
  ) async {
    _setLoading(true);
    try {
      final sonuc = await _hesaplaDagitim(taksit, islemAyi);
      if (sonuc == null) return;
      await _dagitimiKaydet(taksit, islemAyi, sonuc, arshiveGonder);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _dagitimiKaydet(
    TaksitModel taksit,
    String islemAyi,
    DagitimHesapSonuc sonuc,
    bool arshiveGonder,
  ) async {
    final kesinti = sonuc.kesinti;
    final katsayi = sonuc.katsayi;
    final dagitimlar = sonuc.dagitimlar;

    final guncelTaksit = taksit.copyWith(
      hazinePayi: kesinti.hazinePayi,
      bapPayi: kesinti.bapPayi,
      aracGerecPayi: kesinti.aracGerecPayi,
      dagitilabilirTutar: kesinti.dagitilabilirTutar,
      toplamPuan: sonuc.dagitimlar.isNotEmpty
          ? sonuc.dagitimlar.first.toplamPuan
          : 0,
      ekOdemeKatsayisi: katsayi,
      durum: arshiveGonder ? TaksitDurum.onaylandi : TaksitDurum.taslak,
    );

    await _taksitService.update(danismanlik.id, taksit.id, guncelTaksit);
    await _dagitimService.topluKaydet(danismanlik.id, taksit.id, dagitimlar);

    if (arshiveGonder) {
      for (final d in dagitimlar) {
        if (d.odenebilirHakedis != null && d.odenebilirHakedis! > 0) {
          await _hakedisService.donerSermayeEkle(
            d.personelId,
            islemAyi,
            d.odenebilirHakedis!,
          );
        }
      }

      final ykKarar = YkKararModel(
        id: '',
        kararNo:
            'DSYS-${DateTime.now().year}-${taksit.id.substring(0, taksit.id.length.clamp(0, 4)).toUpperCase()}',
        toplantiId: '',
        toplantiNo: '',
        birimId: danismanlik.birimId,
        birimAd: danismanlik.birimKisaAd ?? 'Birim',
        tur: YkKararTuru.danismanlik,
        baslik: '${danismanlik.firmaUnvan} Danışmanlık Dağılımı',
        kararMetni: sonuc.kararMetni,
        kararTarihi: DateTime.now().toIso8601String().split('T').first,
        olusturmaTarihi: DateTime.now(),
        tabloVerileri: dagitimlar.map((d) {
          return {
            'Personel': '${d.unvan} ${d.adSoyad}',
            'Brüt Hakediş': TurkceFormat.para(d.brutHakedis),
            'Kesinti/Taşan': TurkceFormat.para(d.fazlalikHavuzTutari ?? 0.0),
            'Net Ödenen': TurkceFormat.para(d.odenebilirHakedis ?? 0.0),
          };
        }).toList(),
      );

      await _ykKararService.kararCreate(ykKarar);
    }
  }

  Future<DagitimHesapSonuc?> _hesaplaDagitim(
    TaksitModel taksit,
    String islemAyi,
  ) async {
    if (danismanlik.tur == DanismanlikTuru.standart) {
      final excel = DanismanlikExcelHesaplama.hesaplaDanismanlik(
        danismanlik: danismanlik,
        brutTaksitTutari: taksit.brutTutar,
      );

      final k = excel.kesinti;
      final kesinti = KesintiBilgisi(
        kdvHaricMatrah: k.kdvHaricGelir,
        hazinePayi: k.hazinePayi,
        bapPayi: k.bapPayi,
        aracGerecPayi: k.aracGerecPayi,
        dagitilabilirTutar: k.katkiPayi,
      );

      final veriler = _kararMetniVerileriHazirla(
        excel.donemKatsayi,
        k.katkiPayi,
      );
      final kararMetni = KararMetniServisi.metinUret(
        isStandart: true,
        veriler: veriler,
      );

      return DagitimHesapSonuc(
        kesinti: kesinti,
        katsayi: excel.donemKatsayi,
        dagitimlar: excel.dagitimlar,
        kararMetni: kararMetni,
        artikBakiye: excel.artikBakiye,
        excelSonuc: excel,
      );
    }

    // Sanayi 58/k — mevcut motor
    final kesinti = HesaplamaMotoru.sanayiIsbirligiKesintiler(
      brutTutar: taksit.brutTutar,
      kdvOrani: danismanlik.kdvOrani,
    );

    final personelPuanlar = danismanlik.personeller
        .where((p) => p.faaliyetPuani > 0)
        .map((p) => PersonelPuanModel(
              personelId: p.personel.id,
              faaliyetPuani: p.faaliyetPuani,
              unvanKatsayisi: p.personel.unvanKatsayisi,
            ))
        .toList();

    double toplamPuan = 0;
    for (final p in personelPuanlar) {
      toplamPuan += p.bireyselPuan;
    }

    double katsayi = 0;
    if (toplamPuan > 0 && kesinti.dagitilabilirTutar > 0) {
      katsayi = HesaplamaMotoru.katsayiSimulasyonu(
        kesinti.dagitilabilirTutar,
        toplamPuan,
        personelPuanlar,
      );
    }

    final dagitimlar = <DagitimModel>[];
    for (final p in danismanlik.personeller) {
      if (p.faaliyetPuani <= 0) continue;

      final bireyselPuan = p.faaliyetPuani * p.personel.unvanKatsayisi;
      final brutHakedis =
          double.parse((bireyselPuan * katsayi).toStringAsFixed(2));

      final eydma = HesaplamaMotoru.eydmaHesapla(
        gostergeEk: 4000,
        gostergeMakamTemsil: 6000,
        memurMaasKatsayisi: 0.907796,
      );
      final unvanTavani = HesaplamaMotoru.unvanTavaniHesapla(eydma, 1200);

      final aylikMevcutGelir =
          await _hakedisService.toplamAylikGelir(p.personel.id, islemAyi);

      final tavanSonucu = HesaplamaMotoru.tavanKontrol(
        unvanTavani: unvanTavani,
        toplamAylikMevcutGelir: aylikMevcutGelir,
        yeniHesaplananHakedis: brutHakedis,
      );

      dagitimlar.add(DagitimModel(
        personelId: p.personel.id,
        adSoyad: p.personel.adSoyad,
        unvan: p.personel.unvan,
        unvanKatsayisi: p.personel.unvanKatsayisi,
        ekGosterge: 160,
        faaliyetTuru: 'Genel',
        faaliyetAdeti: 1,
        faaliyetTabanPuani: p.faaliyetPuani,
        toplamPuan: toplamPuan,
        bireyselPuan: bireyselPuan,
        brutHakedis: brutHakedis,
        tavanKontrol: tavanSonucu.fazlalikHavuzTutari > 0,
        odenebilirHakedis: tavanSonucu.odenebilirHakedis,
        fazlalikHavuzTutari: tavanSonucu.fazlalikHavuzTutari,
      ));
    }

    double artikBakiye = kesinti.dagitilabilirTutar;
    for (final d in dagitimlar) {
      artikBakiye -= d.brutHakedis;
    }
    artikBakiye = double.parse(artikBakiye.toStringAsFixed(2));

    final veriler =
        _kararMetniVerileriHazirla(katsayi, kesinti.dagitilabilirTutar);
    final kararMetni = KararMetniServisi.metinUret(
      isStandart: false,
      veriler: veriler,
    );

    return DagitimHesapSonuc(
      kesinti: kesinti,
      katsayi: katsayi,
      dagitimlar: dagitimlar,
      kararMetni: kararMetni,
      artikBakiye: artikBakiye,
    );
  }

  Future<void> taksitSil(String taksitId) async {
    _setLoading(true);
    try {
      await _taksitService.delete(danismanlik.id, taksitId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Onay hattında bir adım ilerletir. YK onayında dağıtım hesaplar.
  Future<bool> durumIlerlet(TaksitModel taksit) async {
    final hedef = TaksitOnayAkisi.sonrakiDurum(taksit.durum);
    if (hedef == null) return false;

    if (hedef == TaksitDurum.onaylandi) {
      await dagitimiHesaplaVeKaydet(taksit, guncelIslemAyi(), true);
      return _error == null;
    }
    if (hedef == TaksitDurum.odendi) {
      await _taksitService.updateDurum(danismanlik.id, taksit.id, hedef);
      return true;
    }
    try {
      await _taksitService.updateDurum(danismanlik.id, taksit.id, hedef);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> durumGeriAl(TaksitModel taksit) async {
    final hedef = TaksitOnayAkisi.oncekiDurum(taksit.durum);
    if (hedef == null) return false;
    try {
      await _taksitService.updateDurum(danismanlik.id, taksit.id, hedef);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Map<String, String?> _kararMetniVerileriHazirla(double katsayi, double dagitilabilirTutar) {
    final isStandart = danismanlik.tur == DanismanlikTuru.standart;
    final hocaUnvan = danismanlik.personeller.isNotEmpty ? danismanlik.personeller.first.personel.unvan : '';
    final hocaAdSoyad = danismanlik.personeller.isNotEmpty ? danismanlik.personeller.first.personel.adSoyad : '';

    if (isStandart) {
      return {
        'BIRIM_AD': danismanlik.birimKisaAd,
        'BIRIM_EVRAK_TARIHI': null,
        'BIRIM_EVRAK_SAYISI': null,
        'BIRIM_KURUL_TARIHI': null,
        'BIRIM_TOPLANTI_SAYI': null,
        'BIRIM_KARAR_NO': null,
        'YK_KARAR_TARIHI': danismanlik.ykKararTarihi,
        'YK_KARAR_NO': danismanlik.ykKararNo,
        'FIRMA_UNVAN': danismanlik.firmaUnvan,
        'ISIN_KONUSU': danismanlik.konusu,
        'DANISMANLIK_SURESI': danismanlik.suresi > 0 ? danismanlik.suresi.toString() : null,
        'HOCA_UNVAN': hocaUnvan,
        'HOCA_AD_SOYAD': hocaAdSoyad,
        'KATSAYI': katsayi > 0 ? TurkceFormat.katsayi(katsayi) : null,
      };
    } else {
      return {
        'UYK_KARAR_TARIHI': danismanlik.ykKararTarihi,
        'UYK_TOPLANTI_SAYI': danismanlik.ykToplantiSayisi,
        'UYK_KARAR_NO': danismanlik.ykKararNo,
        'FIRMA_UNVAN': danismanlik.firmaUnvan,
        'HOCA_UNVAN': hocaUnvan,
        'HOCA_AD_SOYAD': hocaAdSoyad,
        'HIZMET_BASLANGIC_TARIHI': danismanlik.baslangicTarihi != null ? TurkceFormat.tarih(danismanlik.baslangicTarihi!) : null,
        'HIZMET_BITIS_TARIHI': danismanlik.bitisTarihi != null ? TurkceFormat.tarih(danismanlik.bitisTarihi!) : null,
        'DANISMANLIK_SURESI': danismanlik.suresi > 0 ? danismanlik.suresi.toString() : null,
        'GELIR_TUTARI': danismanlik.toplamTutar > 0
            ? TurkceFormat.para(danismanlik.toplamTutar).replaceAll(' TL', '')
            : null,
        'KATKI_PAYI_TUTARI': dagitilabilirTutar > 0
            ? TurkceFormat.para(dagitilabilirTutar).replaceAll(' TL', '')
            : null,
      };
    }
  }
}
