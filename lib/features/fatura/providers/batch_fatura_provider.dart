import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/services/ai_extraction_service.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../../../core/models/sistem_ayarlari_model.dart';
import '../../../core/turkce_format.dart';
import '../../birim/models/birim_model.dart';
import '../models/fatura_matbu_baski_onizleme.dart';
import '../models/fatura_matbu_config.dart';
import '../models/fatura_arsiv_util.dart';
import '../models/fatura_model.dart';
import '../models/fatura_parse_kaynaklari.dart';
import '../models/fatura_onay_sonucu.dart';
import '../services/fatura_service.dart';
import '../services/fatura_offline_parser.dart';
import '../services/fatura_eslestirme_servisi.dart';
import '../services/fatura_arsiv_export_servisi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/excel_universal_parser.dart';
import '../services/fatura_pdf_uretici.dart';
import '../services/fatura_dogrulama_servisi.dart';
import '../services/tesseract_ocr_web.dart';
import '../../../core/services/google_vision_ocr_service.dart';
import 'package:flutter/foundation.dart';
import 'fatura_kuyruk_provider.dart';
import 'fatura_matbu_provider.dart';

/// Yürütme Kurulu toplu fatura oluşturma ana sağlayıcısı.
///
/// Bu sınıf artık bir **delegasyon katmanıdır**:
/// - Kuyruk (fatura listesi, CRUD, birim, validasyon) → [FaturaKuyrukProvider]
/// - Matbu kalibrasyon (koordinat, font, offset) → [FaturaMatbuProvider]
/// - PDF üretimi → [FaturaPdfUretici] (statik servis)
///
/// Kendi sorumluluğunda kalanlar:
/// - AI/Offline/Excel ayrıştırma orkestrasyonu (`loadBatch`, `loadExcelFile`)
/// - Arşiv yönetimi (`yukleArsivDurumu`, silme/indirme)
/// - Sistem ayarları (`sistemAyarlari`)
/// - Kalibrasyon önizleme bridge metotları (kuyruk + matbu kesişimi)
///
/// Dışarıya aynı API'yi sunar — mevcut UI kodu değişmez.
class BatchFaturaProvider extends ChangeNotifier {
  // ── İç sağlayıcılar ──────────────────────────────────────
  late final FaturaKuyrukProvider _kuyrukProvider;
  late final FaturaMatbuProvider _matbuProvider;

  FaturaKuyrukProvider get kuyrukProvider => _kuyrukProvider;
  FaturaMatbuProvider get matbuProvider => _matbuProvider;

  // ── AI & Servisler ───────────────────────────────────────
  final AIExtractionService _aiService = AIExtractionService();
  final FaturaService _faturaService = FaturaService();
  SistemAyarlariModel? sistemAyarlari;

  // ── Arşiv State ──────────────────────────────────────────
  FaturaTemizlikUyarisi? arsivUyarisi;
  Map<int, int> arsivYilSayilari = {};
  int mevcutYilArsivSayisi = 0;
  bool arsivYukleniyor = false;

  /// Son ayrıştırmanın hangi yöntemle yapıldığını UI'a bildirir.
  String? sonAyristirmaBilgisi;

  // ─────────────────────────────────────────────────────────
  // DELEGASYON: Kuyruk State
  // ─────────────────────────────────────────────────────────

  List<FaturaModel> get pendingInvoices => _kuyrukProvider.pendingInvoices;
  set pendingInvoices(List<FaturaModel> v) {
    _kuyrukProvider.pendingInvoices = v;
  }

  int get currentIndex => _kuyrukProvider.currentIndex;
  set currentIndex(int v) {
    _kuyrukProvider.currentIndex = v;
    final birimId = seciliBirimFor(v);
    if (birimId != _matbuProvider.aktifBirimId) {
      _matbuProvider.loadMatbuAyarlari(birimId);
    }
  }

  int dialogUpdateCounter = 0;
  Map<String, String> seciliBirimByFaturaId = {};
  int? geriYuklenenKuyrukSayisi;

  bool _syncingFromKuyruk = false;
  bool _syncingFromMatbu = false;

  void _kuyrukChanged() {
    if (_syncingFromKuyruk) return;
    _syncingFromKuyruk = true;
    // Yansıt: alt sağlayıcıdan gelen state'i üst katmana kopyala
    dialogUpdateCounter = _kuyrukProvider.dialogUpdateCounter;
    seciliBirimByFaturaId = _kuyrukProvider.seciliBirimByFaturaId;
    geriYuklenenKuyrukSayisi = _kuyrukProvider.geriYuklenenKuyrukSayisi;

    // Aktif fatura değiştiğinde veya birimi değiştiğinde kalibrasyonu yükle
    if (currentIndex >= 0 && currentIndex < pendingInvoices.length) {
      final birimId = seciliBirimFor(currentIndex);
      if (birimId != _matbuProvider.aktifBirimId) {
        _matbuProvider.loadMatbuAyarlari(birimId);
      }
    }

    _syncingFromKuyruk = false;
    notifyListeners();
  }

  void _matbuChanged() {
    if (_syncingFromMatbu) return;
    _syncingFromMatbu = true;
    _syncingFromMatbu = false;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // Constructor
  // ─────────────────────────────────────────────────────────

  BatchFaturaProvider() {
    _kuyrukProvider = FaturaKuyrukProvider();
    _matbuProvider = FaturaMatbuProvider();
    _kuyrukProvider.addListener(_kuyrukChanged);
    _matbuProvider.addListener(_matbuChanged);
    _loadSistemAyarlari();
  }

  // ─────────────────────────────────────────────────────────
  // DELEGASYON: Matbu State (public field → getter)
  // ─────────────────────────────────────────────────────────

  bool get matbuBaskiModu => _matbuProvider.matbuBaskiModu;
  set matbuBaskiModu(bool v) => _matbuProvider.matbuBaskiModu = v;

  double get kalemSatirAraligi => _matbuProvider.kalemSatirAraligi;
  set kalemSatirAraligi(double v) => _matbuProvider.kalemSatirAraligi = v;

  double get matbuFontBoyutu => _matbuProvider.matbuFontBoyutu;
  set matbuFontBoyutu(double v) => _matbuProvider.matbuFontBoyutu = v;

  int get satirLimit => _matbuProvider.satirLimit;
  set satirLimit(int v) => _matbuProvider.satirLimit = v;

  String get nakliYekunUstMetin => _matbuProvider.nakliYekunUstMetin;
  set nakliYekunUstMetin(String v) => _matbuProvider.nakliYekunUstMetin = v;

  String get nakliYekunAltMetin => _matbuProvider.nakliYekunAltMetin;
  set nakliYekunAltMetin(String v) => _matbuProvider.nakliYekunAltMetin = v;

  double get globalOffsetDx => _matbuProvider.globalOffsetDx;
  set globalOffsetDx(double v) => _matbuProvider.globalOffsetDx = v;

  double get globalOffsetDy => _matbuProvider.globalOffsetDy;
  set globalOffsetDy(double v) => _matbuProvider.globalOffsetDy = v;

  Map<String, Offset> get coordinates => _matbuProvider.coordinates;
  set coordinates(Map<String, Offset> v) => _matbuProvider.coordinates = v;

  bool get isNakliYekunAktif => _matbuProvider.isNakliYekunAktif;
  set isNakliYekunAktif(bool v) => _matbuProvider.isNakliYekunAktif = v;

  // ─────────────────────────────────────────────────────────
  // DELEGASYON: Coordinate Helpers
  // ─────────────────────────────────────────────────────────

  void updateCoordinate(String key, Offset newOffset, {bool notify = true}) {
    _matbuProvider.updateCoordinate(key, newOffset, notify: notify);
  }

  void updateCoordinateDelta(String key, Offset delta, {bool notify = true}) {
    _matbuProvider.updateCoordinateDelta(key, delta, notify: notify);
  }

  void nudgeCoordinate(String key, double dx, double dy) {
    _matbuProvider.nudgeCoordinate(key, dx, dy);
  }

  void calibrationDragDelta(String key, Offset delta, {bool notify = true}) {
    _matbuProvider.calibrationDragDelta(key, delta, notify: notify);
  }

  // ─────────────────────────────────────────────────────────
  // DELEGASYON: Matbu Property Setters
  // ─────────────────────────────────────────────────────────

  void setKalemSatirAraligi(double value) {
    _matbuProvider.setKalemSatirAraligi(value);
  }

  void setMatbuFontBoyutu(double value) {
    _matbuProvider.setMatbuFontBoyutu(value);
  }

  void setSatirLimit(int value) {
    _matbuProvider.setSatirLimit(value);
  }

  void setNakliYekunUstMetin(String value) {
    _matbuProvider.setNakliYekunUstMetin(value);
  }

  void setNakliYekunAltMetin(String value) {
    _matbuProvider.setNakliYekunAltMetin(value);
  }

  void setGlobalOffset(double dx, double dy) {
    _matbuProvider.setGlobalOffset(dx, dy);
  }

  void setMatbuBaskiModu(bool value) {
    _matbuProvider.setMatbuBaskiModu(value);
  }

  Future<void> saveMatbuAyarlari() => _matbuProvider.saveMatbuAyarlari();
  Future<void> saveCoordinates() => _matbuProvider.saveCoordinates();
  Future<void> resetCoordinates() => _matbuProvider.resetCoordinates();
  Future<void> loadMatbuAyarlari(String? birimId) =>
      _matbuProvider.loadMatbuAyarlari(birimId);

  void toggleNakliYekunGlobal(bool value) {
    _matbuProvider.toggleNakliYekunGlobal(value);
  }

  void calibrationUiRefresh() {
    _matbuProvider.calibrationUiRefresh();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // BRIDGE: Kalibrasyon önizleme (kuyruk + matbu kesişimi)
  // ─────────────────────────────────────────────────────────

  Map<String, String> ornekBaskiMetinleri() =>
      FaturaMatbuConfig.ornekBaskiMetinleri(isletmeVkn: _isletmeVknFallback());

  FaturaModel ornekFatura() {
    return FaturaModel(
      id: 'ornek',
      firmaAdi: FaturaMatbuConfig.ornekMetinler['firmaAdi']!,
      adres: FaturaMatbuConfig.ornekMetinler['adres']!,
      vergiDairesi: FaturaMatbuConfig.ornekMetinler['vergiDairesi']!,
      vergiNo: FaturaMatbuConfig.ornekMetinler['vkn']!,
      tarih: FaturaMatbuConfig.ornekMetinler['tarih']!,
      irsaliyeTarihi: FaturaMatbuConfig.ornekMetinler['irsaliyeTarihi']!,
      irsaliyeNo: FaturaMatbuConfig.ornekMetinler['irsaliyeNo']!,
      melbesNo: 'MEL-2026-0042',
      melbesKurumOnEki: FaturaMatbuConfig.varsayilanMelbesKurumOnEki,
      numuneNo: 'N-1087',
      numuneAciklamasi: FaturaMatbuConfig.ornekMetinler['numuneAciklama']!,
      kalemler: [
        {
          'cinsi': FaturaMatbuConfig.ornekMetinler['cinsi'],
          'miktar': 1,
          'fiyat': 1500.0,
        },
      ],
      isKdvMuaf: false,
      matrah: 1500,
      kdvOrani: 20,
      kdvTutari: 300,
      genelToplam: 1800,
      iban: FaturaMatbuConfig.ornekMetinler['iban'],
      hesapAdi: FaturaMatbuConfig.ornekMetinler['hesapAdi'],
      parsedBy: FaturaParseKaynaklari.kalibrasyon,
    );
  }

  int? _kalibrasyonFaturaIndex() {
    if (_kuyrukProvider.pendingInvoices.isEmpty) return null;
    if (_kuyrukProvider.currentIndex >= 0 &&
        _kuyrukProvider.currentIndex < _kuyrukProvider.pendingInvoices.length &&
        !FaturaKuyrukProvider.yerTutucuMu(
            _kuyrukProvider.pendingInvoices[_kuyrukProvider.currentIndex])) {
      return _kuyrukProvider.currentIndex;
    }
    for (var i = 0; i < _kuyrukProvider.pendingInvoices.length; i++) {
      if (!FaturaKuyrukProvider.yerTutucuMu(_kuyrukProvider.pendingInvoices[i])) {
        return i;
      }
    }
    return null;
  }

  FaturaModel kalibrasyonFaturasi() {
    final idx = _kalibrasyonFaturaIndex();
    if (idx != null) return _kuyrukProvider.pendingInvoices[idx];
    return ornekFatura();
  }

  int kalibrasyonFaturaIndex() =>
      _kalibrasyonFaturaIndex() ?? _kuyrukProvider.currentIndex;

  int _aktifKalibrasyonSayfasi = 1;
  int get aktifKalibrasyonSayfasi => _aktifKalibrasyonSayfasi;

  void setAktifKalibrasyonSayfasi(int s) {
    _aktifKalibrasyonSayfasi = s;
    notifyListeners();
  }

  int get kalibrasyonToplamSayfasi {
    final fatura = kalibrasyonFaturasi();
    final ornek = fatura.id == 'ornek';
    if (ornek) {
      final kalemlerHam = FaturaMatbuConfig.matbuKalemleri(fatura.kalemler);
      if (kalemlerHam.isEmpty) return 1;
      return (kalemlerHam.length / satirLimit).ceil().clamp(1, 9999);
    }
    final kalemlerHam = FaturaMatbuConfig.matbuKalemleri(fatura.kalemler);
    if (kalemlerHam.isEmpty) return 1;
    return (kalemlerHam.length / satirLimit).ceil().clamp(1, 9999);
  }

  KalibrasyonBaskiOnizleme kalibrasyonBaskiOnizlemesi([int? sayfaNo]) {
    final fatura = kalibrasyonFaturasi();
    final ornek = fatura.id == 'ornek';
    if (ornek) {
      return KalibrasyonBaskiOnizleme.ornek(
        isletmeVkn: _isletmeVknFallback(),
        yaziyla: TurkceFormat.sayiyiYaziyaCevir,
        sayfaNo: sayfaNo ?? 1,
        satirLimit: satirLimit,
      );
    }
    final baslik = fatura.firmaAdi.trim().isNotEmpty
        ? fatura.firmaAdi.trim()
        : 'Sıradaki fatura';
    return KalibrasyonBaskiOnizleme.fromFatura(
      fatura,
      isletmeVkn: _isletmeVknFallback(),
      sistemHesapAdi: sistemAyarlari?.hesapAdi,
      sistemIban: sistemAyarlari?.iban,
      sayfaNo: sayfaNo ?? _aktifKalibrasyonSayfasi,
      yaziyla: TurkceFormat.sayiyiYaziyaCevir,
      canliVeri: true,
      baslik: baslik,
      satirLimit: satirLimit,
    );
  }

  // ─────────────────────────────────────────────────────────
  // DELEGASYON: Kuyruk CRUD
  // ─────────────────────────────────────────────────────────

  static bool yerTutucuMu(FaturaModel f) =>
      FaturaKuyrukProvider.yerTutucuMu(f);

  void notifyDialogReturn() {
    _kuyrukProvider.notifyDialogReturn();
  }

  int? consumeGeriYuklemeBildirimi() {
    return _kuyrukProvider.consumeGeriYuklemeBildirimi();
  }

  void addBlankInvoice() {
    _kuyrukProvider.addBlankInvoice();
  }

  /// Arşivdeki bir faturayı kuyruğa alır ve kuyruk index'ini döner.
  /// Zaten kuyrukta ise tekrar eklemez (mevcut index döner).
  int arsivFaturasiniKuyrugaAl(FaturaModel fatura) =>
      _kuyrukProvider.arsivFaturasiniEkle(fatura);

  void duplicateInvoice(int index) {
    _kuyrukProvider.duplicateInvoice(index);
  }

  void removeInvoice(int index) {
    _kuyrukProvider.removeInvoice(index);
  }

  Future<void> approveInvoice(int index,
      {bool validateRequired = true}) async {
    await _kuyrukProvider.approveInvoice(index,
        validateRequired: validateRequired);
    yukleArsivDurumu(); // don't await to avoid UI blocking
  }

  Future<FaturaOnaySonucu> approveAll() async {
    final sonuc = await _kuyrukProvider.approveAll();
    if (sonuc.kaydedilen > 0) yukleArsivDurumu(); // don't await
    return sonuc;
  }

  Future<void> kuyruguTemizle() async {
    await _kuyrukProvider.kuyruguTemizle();
  }

  void addKalem(int index) {
    _kuyrukProvider.addKalem(index);
  }

  void updateKalem(int invoiceIndex, int kalemIndex, String key,
      dynamic value) {
    _kuyrukProvider.updateKalem(invoiceIndex, kalemIndex, key, value);
  }

  void removeKalem(int invoiceIndex, int kalemIndex) {
    _kuyrukProvider.removeKalem(invoiceIndex, kalemIndex);
  }

  void addEkstraNot(int index) {
    _kuyrukProvider.addEkstraNot(index);
  }

  void updateEkstraNot(int invoiceIndex, int notIndex, String value) {
    _kuyrukProvider.updateEkstraNot(invoiceIndex, notIndex, value);
  }

  void removeEkstraNot(int invoiceIndex, int notIndex) {
    _kuyrukProvider.removeEkstraNot(invoiceIndex, notIndex);
  }

  void updateField(int index, String field, dynamic value) {
    _kuyrukProvider.updateField(index, field, value);
  }

  void toggleKdvMuaf(int index, bool value) {
    _kuyrukProvider.toggleKdvMuaf(index, value);
  }

  void setInvoiceNakliYekun(int index, bool value) {
    _kuyrukProvider.setInvoiceNakliYekun(index, value);
  }

  bool nakliAlanlariGoster(FaturaModel invoice) =>
      _kuyrukProvider.nakliAlanlariGoster(invoice);

  List<String> eksikAlanlarForInvoice(FaturaModel invoice) =>
      _kuyrukProvider.eksikAlanlarForInvoice(invoice);

  // ─────────────────────────────────────────────────────────
  // DELEGASYON: Birim İşlemleri
  // ─────────────────────────────────────────────────────────

  Map<String, BirimModel> get birimlerCache => _kuyrukProvider.birimlerCache;
  List<BirimModel> get birimler => _kuyrukProvider.birimler;

  String getBirimKategori(String? birimIdOrAd) =>
      _kuyrukProvider.getBirimKategori(birimIdOrAd);

  BirimModel? findBirim(String? key) => _kuyrukProvider.findBirim(key);

  String? seciliBirimFor(int index) =>
      _kuyrukProvider.seciliBirimFor(index);

  String? seciliBirimIbanFor(int index) =>
      _kuyrukProvider.seciliBirimIbanFor(index);

  bool ibanEslesiyorMu(int index) =>
      _kuyrukProvider.ibanEslesiyorMu(index);

  String? gecerliSeciliBirimFor(int index) =>
      _kuyrukProvider.gecerliSeciliBirimFor(index);

  void setSeciliBirim(int index, String birimId) {
    _kuyrukProvider.setSeciliBirim(index, birimId);
    _matbuProvider.loadMatbuAyarlari(birimId);
  }

  void applyBirimToInvoice(int invoiceIndex, String birimIdOrAd) {
    _kuyrukProvider.applyBirimToInvoice(invoiceIndex, birimIdOrAd);
  }

  Future<void> refreshBirimler() async {
    await _kuyrukProvider.refreshBirimler();
  }

  String? getFiyatUyarisi(String? birimAdi, String cinsi, double fiyat) =>
      _kuyrukProvider.getFiyatUyarisi(birimAdi, cinsi, fiyat);

  double parseTurkceSayi(dynamic value, {double fallback = 0.0}) {
    return TurkceFormat.parseSayi(value, fallback: fallback);
  }

  // ─────────────────────────────────────────────────────────
  // Sistem Ayarları
  // ─────────────────────────────────────────────────────────

  Future<void> _loadSistemAyarlari() async {
    sistemAyarlari = await SistemAyarlariService().getAyarlar();
    notifyListeners();
  }

  String _isletmeVknFallback() {
    final vkn = sistemAyarlari?.isletmeVkn.trim() ?? '';
    return vkn.isNotEmpty ? vkn : FaturaMatbuConfig.varsayilanIsletmeVkn;
  }

  // ─────────────────────────────────────────────────────────
  // Arşiv Yönetimi
  // ─────────────────────────────────────────────────────────

  static String _arsivUyarisiPrefsKey(int yil) =>
      'fatura_arsiv_uyari_${yil}_kapatildi';

  Future<List<FaturaArsivKayit>> araArsiv(FaturaArsivAramaFiltre filtre) async {
    return _faturaService.araFaturalar(filtre);
  }

  Future<void> yukleArsivDurumu() async {
    arsivYukleniyor = true;
    notifyListeners();
    try {
      final tumSayilar = await _faturaService.tumYilSayilari();
      arsivYilSayilari = tumSayilar;
      arsivUyarisi = await _faturaService.eskiArsivOzetiniGetir(
        cacheYilSayilari: tumSayilar,
      );
      mevcutYilArsivSayisi = await _faturaService.mevcutYilArsivSayisi(
        cacheYilSayilari: tumSayilar,
      );
    } catch (e) {
      debugPrint('Arşiv durumu yüklenemedi: $e');
    } finally {
      arsivYukleniyor = false;
      notifyListeners();
    }
  }

  Future<bool> yilBasiTemizlikDialoguGosterilmeli() async {
    if (!FaturaArsivUtil.yilBasiTemizlikDonemi()) return false;
    if (arsivUyarisi == null || !arsivUyarisi!.gosterilmeli) return false;
    final prefs = await SharedPreferences.getInstance();
    final key = _arsivUyarisiPrefsKey(FaturaArsivUtil.suAnkiYil());
    return !(prefs.getBool(key) ?? false);
  }

  Future<void> yilBasiUyarisiErtele() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _arsivUyarisiPrefsKey(FaturaArsivUtil.suAnkiYil()),
      true,
    );
  }

  Future<int> silYilArsivi(int yil) async {
    final adet = await _faturaService.silYilArsivi(yil);
    await yukleArsivDurumu();
    return adet;
  }

  Future<int> silTumEskiArsiv() async {
    final adet = await _faturaService.silTumEskiArsiv();
    await yukleArsivDurumu();
    return adet;
  }

  Future<void> indirYilArsiviJson(int yil) async {
    final kayitlar = await _faturaService.yilArsiviniGetir(yil);
    if (kayitlar.isEmpty) {
      throw Exception('$yil yılında indirilecek kayıt yok.');
    }
    await FaturaArsivExportServisi.indirJson(yil, kayitlar);
  }

  Future<void> indirYilArsiviCsv(int yil) async {
    final kayitlar = await _faturaService.yilArsiviniGetir(yil);
    if (kayitlar.isEmpty) {
      throw Exception('$yil yılında indirilecek kayıt yok.');
    }
    await FaturaArsivExportServisi.indirCsv(yil, kayitlar);
  }

  Future<int> indirEskiArsivZip() async {
    final yilKayitlari = await _faturaService.eskiArsivKayitlariniGetir();
    if (yilKayitlari.isEmpty) {
      throw Exception('İndirilecek eski arşiv yok.');
    }
    await FaturaArsivExportServisi.indirYillikZip(yilKayitlari);
    var toplam = 0;
    for (final liste in yilKayitlari.values) {
      toplam += liste.length;
    }
    return toplam;
  }

  Future<({int indirilen, int silinen})> indirVeSilEskiArsiv() async {
    final yilKayitlari = await _faturaService.eskiArsivKayitlariniGetir();
    if (yilKayitlari.isEmpty) {
      throw Exception('Silinecek eski arşiv yok.');
    }
    await FaturaArsivExportServisi.indirYillikZip(yilKayitlari);
    var indirilen = 0;
    for (final liste in yilKayitlari.values) {
      indirilen += liste.length;
    }
    final silinen = await silTumEskiArsiv();
    return (indirilen: indirilen, silinen: silinen);
  }

  // ─────────────────────────────────────────────────────────
  // PDF Üretimi (FaturaPdfUretici'ye delegasyon)
  // ─────────────────────────────────────────────────────────

  Future<void> matbuYazdir(FaturaModel invoice) async {
    final birimId = seciliBirimByFaturaId[invoice.id];
    if (birimId != null && birimId != _matbuProvider.aktifBirimId) {
      await _matbuProvider.loadMatbuAyarlari(birimId);
    }
    final bytes = await FaturaPdfUretici.generatePdf(
      invoice: invoice,
      includeBackground: false,
      coordinates: _matbuProvider.coordinates,
      kalemSatirAraligi: _matbuProvider.kalemSatirAraligi,
      matbuFontBoyutu: _matbuProvider.matbuFontBoyutu,
      globalOffsetDx: _matbuProvider.globalOffsetDx,
      globalOffsetDy: _matbuProvider.globalOffsetDy,
      matbuBaskiModu: _matbuProvider.matbuBaskiModu,
      satirLimit: _matbuProvider.satirLimit,
      nakliYekunUstMetin: _matbuProvider.nakliYekunUstMetin,
      nakliYekunAltMetin: _matbuProvider.nakliYekunAltMetin,
      isletmeVknFallback: _isletmeVknFallback(),
      sistemHesapAdi: sistemAyarlari?.hesapAdi,
      sistemIban: sistemAyarlari?.iban,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<Uint8List> generatePdf(
    FaturaModel invoice, {
    bool? includeBackground,
  }) async {
    final birimId = seciliBirimByFaturaId[invoice.id];
    if (birimId != null && birimId != _matbuProvider.aktifBirimId) {
      await _matbuProvider.loadMatbuAyarlari(birimId);
    }
    return FaturaPdfUretici.generatePdf(
      invoice: invoice,
      includeBackground: includeBackground,
      coordinates: _matbuProvider.coordinates,
      kalemSatirAraligi: _matbuProvider.kalemSatirAraligi,
      matbuFontBoyutu: _matbuProvider.matbuFontBoyutu,
      globalOffsetDx: _matbuProvider.globalOffsetDx,
      globalOffsetDy: _matbuProvider.globalOffsetDy,
      matbuBaskiModu: _matbuProvider.matbuBaskiModu,
      satirLimit: _matbuProvider.satirLimit,
      nakliYekunUstMetin: _matbuProvider.nakliYekunUstMetin,
      nakliYekunAltMetin: _matbuProvider.nakliYekunAltMetin,
      isletmeVknFallback: _isletmeVknFallback(),
      sistemHesapAdi: sistemAyarlari?.hesapAdi,
      sistemIban: sistemAyarlari?.iban,
    );
  }

  Future<Uint8List> generateBatchPdf(
    List<FaturaModel> invoices, {
    bool? includeBackground,
  }) async {
    return FaturaPdfUretici.generateBatchPdf(
      invoices: invoices,
      includeBackground: includeBackground,
      coordinates: _matbuProvider.coordinates,
      kalemSatirAraligi: _matbuProvider.kalemSatirAraligi,
      matbuFontBoyutu: _matbuProvider.matbuFontBoyutu,
      globalOffsetDx: _matbuProvider.globalOffsetDx,
      globalOffsetDy: _matbuProvider.globalOffsetDy,
      matbuBaskiModu: _matbuProvider.matbuBaskiModu,
      satirLimit: _matbuProvider.satirLimit,
      nakliYekunUstMetin: _matbuProvider.nakliYekunUstMetin,
      nakliYekunAltMetin: _matbuProvider.nakliYekunAltMetin,
      isletmeVknFallback: _isletmeVknFallback(),
      sistemHesapAdi: sistemAyarlari?.hesapAdi,
      sistemIban: sistemAyarlari?.iban,
    );
  }

  // ─────────────────────────────────────────────────────────
  // AI & Batch Parsing (Orkestrasyon — burada kalır)
  // ─────────────────────────────────────────────────────────

  Future<void> loadBatch(
    String text, {
    bool cevrimdisi = false,
    Uint8List? pdfBytes,
    bool append = false,
  }) async {
    List<FaturaModel> sonuc = [];

    debugPrint('[loadBatch] Gelen evrak: metin=${text.length} karakter, pdfBytes=${pdfBytes?.length ?? 0} byte');
    if (text.trim().isNotEmpty) {
      final onizleme = text.length > 400 ? '${text.substring(0, 400)}...' : text;
      debugPrint('[loadBatch] Metin önizleme:\n$onizleme');
    }

    // ── Katman 0 — Yerel kural motoru (HER ZAMAN, koşulsuz, ilk sırada) ──
    // 0.01s, internet gerektirmez, hata vermez.
    if (text.trim().isNotEmpty) {
      sonuc = FaturaOfflineParser.parse(text);
      if (sonuc.isNotEmpty) {
        debugPrint('[loadBatch] Yerel parser başarılı: ${sonuc.length} fatura (${sonuc.first.parsedBy})');
        sonAyristirmaBilgisi = sonuc.first.parsedBy;
      } else {
        debugPrint('[loadBatch] Yerel parser faturayı tanıyamadı, arşiv/AI katmanına geçiliyor.');
      }
    }

    // ── Katman 0.5 — Tesseract.js Yerel OCR (Eğer metin boşsa ve PDF ise) ──
    if (sonuc.isEmpty && text.trim().isEmpty && pdfBytes != null && pdfBytes.isNotEmpty && kIsWeb) {
      debugPrint('[loadBatch] PDF metin katmanı boş. Tesseract.js yerel OCR deneniyor...');
      try {
        final jpegs = GoogleVisionOcrService.pdfIciJpegleriCikar(pdfBytes);
        final ocrParts = <String>[];
        for (final jpeg in jpegs) {
          final ocrText = await TesseractOcrWeb.ocrFromImageBytes(jpeg);
          if (ocrText.trim().isNotEmpty) ocrParts.add(ocrText.trim());
        }
        final finalOcr = ocrParts.join('\n\n');
        if (finalOcr.trim().isNotEmpty) {
           text = finalOcr;
           debugPrint('[loadBatch] Tesseract yerel OCR başarılı:\n$finalOcr');
           // Yeniden yerel parser'ı dene
           sonuc = FaturaOfflineParser.parse(text);
           if (sonuc.isNotEmpty) {
             sonAyristirmaBilgisi = '${sonuc.first.parsedBy} (Yerel OCR ile)';
             for (var s in sonuc) { s.parsedBy = sonAyristirmaBilgisi; }
           }
        }
      } catch (e) {
        debugPrint('[loadBatch] Tesseract.js OCR hatası: $e');
      }
    }

    // ── Katman 1 — Arşiv eşleştirme (yerel parser boş döndüyse) ──
    if (sonuc.isEmpty && !cevrimdisi && text.trim().isNotEmpty) {
      try {
        final arsivKayitlar = await _faturaService.araFaturalar(
          FaturaArsivAramaFiltre(metin: ''),
        ).timeout(const Duration(seconds: 3), onTimeout: () => []);
        final gecmis = arsivKayitlar.map((e) => e.fatura).toList();
        final eslesmeSonuc = FaturaEslestirmeServisi.eslestir(
          rawText: text,
          gecmisFaturalar: gecmis,
        );
        if (eslesmeSonuc != null) {
          sonuc = [eslesmeSonuc.fatura];
          final skor = eslesmeSonuc.skor;
          final dusukSkor = skor < FaturaEslestirmeServisi.yuksekGuvenSkoru;
          sonAyristirmaBilgisi = dusukSkor
              ? 'Arşiv şablonundan dolduruldu (eşleşme skoru: $skor — kontrol edin)'
              : 'Arşiv şablonundan dolduruldu (eşleşme skoru: $skor)';
        }
      } catch (e) {
        debugPrint('Eşleştirme servisi hatası: $e');
      }
    }

    // ── Katman 2 — AI (son çare, yerel + arşiv ikisi de boş döndüyse) ──
    if (sonuc.isEmpty && !cevrimdisi) {
      try {
        final hasPdf = pdfBytes != null && pdfBytes.isNotEmpty;
        final aiTimeout = Duration(seconds: hasPdf ? 45 : 20);
        debugPrint('[loadBatch] AI katmanı çağrılıyor (timeout: ${aiTimeout.inSeconds}s)...');

        final extractedData = await _aiService.extractBatchData(
          text,
          pdfBytes: pdfBytes,
        ).timeout(aiTimeout, onTimeout: () {
          debugPrint('AI ayrıştırma zaman aşımına uğradı (${aiTimeout.inSeconds}s).');
          return [];
        });
        sonuc = extractedData.map(FaturaModel.fromJson).toList();
        if (sonuc.isNotEmpty) {
          sonAyristirmaBilgisi = sonuc.first.parsedBy;
        }
      } catch (e) {
        debugPrint('AI ayrıştırma başarısız: $e');
      }
    }

    if (sonuc.isEmpty) {
      throw Exception(
        'Fatura okunamadı. AI anahtarı yoksa metin biçimini kontrol edin '
        'veya alanları manuel doldurun.',
      );
    }

    sonuc = FaturaDogrulamaServisi.dogrulaList(sonuc);
    _kuyrukProvider.setInvoicesFromParse(sonuc, append: append);
  }

  // ─────────────────────────────────────────────────────────
  // Excel / Toplu Liste — TAM OFFLINE (AI kullanılmaz)
  // ─────────────────────────────────────────────────────────

  Future<void> loadExcelFile(
    Uint8List bytes,
    String fileName, {
    bool append = false,
  }) async {
    final csvText = await ExcelUniversalParser.extractText(bytes, fileName: fileName);
    if (csvText.isEmpty) throw Exception('Excel dosyası boş veya okunamadı.');

    final lines = csvText
        .split('\n')
        .map((l) => l.replaceAll('\r', ''))
        .where((l) => l.isNotEmpty)
        .toList();

    // Dosya yumurtayla mı ilgili?
    final isYumurta = fileName.toLowerCase().contains('yumurt') ||
        csvText.toLowerCase().contains('yumurt');

    // Başlık satırını bul
    final baslikSonucu = _excelBasliklariBul(lines, isYumurta: isYumurta);

    if (baslikSonucu == null) {
      // 1. Şans: Birim fatura form şablonu (VERİ GİRİŞ / FATURA sheet veya form düzeni)
      final offlineSonuc = FaturaOfflineParser.parse(csvText);
      if (offlineSonuc.isNotEmpty && offlineSonuc.first.kalemler.isNotEmpty) {
        sonAyristirmaBilgisi = offlineSonuc.first.parsedBy;
        final dogrulanmis = FaturaDogrulamaServisi.dogrulaList(offlineSonuc);
        _kuyrukProvider.setInvoicesFromParse(dogrulanmis, append: append);
        return;
      }

      throw Exception(
        'Excel dosyasından fatura verisi çıkarılamadı.\n'
        'Liste faturası için "Ad-Soyad", "TC No", "Tutar" sütunları; '
        'veya birim Excel şablonu ("VERİ GİRİŞ" / "FATURA") gereklidir.',
      );
    }

    // Başlık satırından sonraki satırları faturaya çevir
    final faturalar = <FaturaModel>[];
    for (int i = baslikSonucu.startRow; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty || line.startsWith('---')) continue;

      final fatura = _satirFaturayaDonustur(
        satirIndex: i,
        line: line,
        kolonlar: baslikSonucu.kolonlar,
        isYumurta: isYumurta,
      );
      if (fatura != null) faturalar.add(fatura);
    }

    if (faturalar.isEmpty) {
      // Başlık bulundu ama satırlar dolmadıysa form şablonu olarak son bir kez dene
      final offlineSonuc = FaturaOfflineParser.parse(csvText);
      if (offlineSonuc.isNotEmpty && offlineSonuc.first.kalemler.isNotEmpty) {
        sonAyristirmaBilgisi = offlineSonuc.first.parsedBy;
        final dogrulanmis = FaturaDogrulamaServisi.dogrulaList(offlineSonuc);
        _kuyrukProvider.setInvoicesFromParse(dogrulanmis, append: append);
        return;
      }

      throw Exception(
        'Excel dosyasından hiç fatura oluşturulamadı.\n'
        'Başlıklar bulundu (satır ${baslikSonucu.startRow}) '
        'ancak geçerli veri satırı yok. '
        'Firma adı ve tutar dolu satırlar gereklidir.',
      );
    }

    final dogrulanmis = FaturaDogrulamaServisi.dogrulaList(faturalar);
    _kuyrukProvider.setInvoicesFromParse(dogrulanmis, append: append);
  }

  // ─── Başlık tespiti ───────────────────────────────────────

  _ExcelBaslikSonucu? _excelBasliklariBul(
    List<String> lines, {
    required bool isYumurta,
  }) {
    for (int i = 0; i < lines.length && i < 25; i++) {
      final line = lines[i];
      if (line.startsWith('---')) continue; // SHEET: satırı

      final cells = line.split(' | ');
      final normCells = cells.map(_norm).toList();

      // Başlık satırı için asgari: firma/isim sütunu VE tutar sütunu olmalı
      int firmaIdx = -1;
      int tcIdx = -1;
      int matrahIdx = -1;     // KDV dahil / toplam / genel tutar
      int kdvHaricIdx = -1;   // KDV hariç / matrah
      int kdvTutarIdx = -1;   // KDV tutarı (oran değil)
      int miktarIdx = -1;
      int birimFiyatIdx = -1;
      int adresIdx = -1;

      for (int c = 0; c < normCells.length; c++) {
        final n = normCells[c];

        // Firma / İsim / Cari
        if (_icerir(n, [
          'ad-soyad', 'ad soyad', 'adi soyadi', 'isim', 'musteri',
          'alici', 'unvan', 'firma adi', 'firma ad', 'cari', 'cari unvan',
          'kurum', 'ad ve soyad', 'ilgili', 'ad / soyad'
        ])) {
          firmaIdx = c;
        }

        // TC / VKN / Kimlik
        if (_icerir(n, [
          'tc no', 'tc.no', 'tc kimlik', 'vkn', 'vergi no',
          'kimlik no', 'vergi/tc', 'v.no'
        ]) || n == 'tc' || n == 'vkn' || n == 'kimlik') {
          tcIdx = c;
        }

        // KDV Dahil (toplam / genel toplam / tutar) — öncelikli tutar
        if (_icerir(n, [
          'kdv dahil', 'kdv dahil fiyat', 'kdvli tutar',
          'genel toplam', 'toplam tutar', 'fatura tutari',
          'odenecek tutar', 'odenecek', 'odenen tutar',
          'net tutar', 'toplam', 'tutar', 'bedel', 'yekun'
        ])) {
          matrahIdx = c;
        }

        // KDV Hariç (matrah)
        if (_icerir(n, [
          'kdv haric', 'kdv hariç fiyat', 'kdvsiz',
          'matrah', 'kdv haric fiyat', 'kdvsiz tutar', 'vergisiz'
        ])) {
          kdvHaricIdx = c;
        }

        // KDV tutarı (para değeri, oran değil)
        if (_icerir(n, ['kdv (%', 'kdv%', 'kdv tutari', 'kdv miktar', 'kdv degeri']) ||
            (n.contains('kdv') && !n.contains('dahil') &&
             !n.contains('haric') && !n.contains('oran'))) {
          kdvTutarIdx = c;
        }

        // Miktar / Adet
        if (_icerir(n, [
          'adet', 'miktar', 'sayi', 'yumurta adet',
          'yumurta / adet', 'koli', 'kg'
        ])) {
          miktarIdx = c;
        }

        // Birim Fiyat
        if (_icerir(n, [
          'birim fiyat', 'b.fiyat', 'birim fiyati',
          'fiyat', 'birim', 'ucret'
        ])) {
          birimFiyatIdx = c;
        }

        // Adres
        if (_icerir(n, ['adres', 'il', 'ilce', 'sehir'])) {
          adresIdx = c;
        }
      }

      // Firma ve en az bir tutar sütunu zorunlu
      if (firmaIdx == -1) continue;
      if (matrahIdx == -1 && kdvHaricIdx == -1 && birimFiyatIdx == -1) continue;

      // matrahIdx yoksa kdvHaricIdx'i kullan, o da yoksa birimFiyatIdx
      if (matrahIdx == -1) {
        matrahIdx = kdvHaricIdx != -1 ? kdvHaricIdx : birimFiyatIdx;
      }

      return _ExcelBaslikSonucu(
        startRow: i + 1,
        kolonlar: _ExcelKolonlar(
          firmaIdx: firmaIdx,
          tcIdx: tcIdx,
          matrahIdx: matrahIdx,
          kdvHaricIdx: kdvHaricIdx,
          kdvTutarIdx: kdvTutarIdx,
          miktarIdx: miktarIdx,
          birimFiyatIdx: birimFiyatIdx,
          adresIdx: adresIdx,
        ),
      );
    }
    return null;
  }

  // ─── Satırdan fatura üretimi ──────────────────────────────

  FaturaModel? _satirFaturayaDonustur({
    required int satirIndex,
    required String line,
    required _ExcelKolonlar kolonlar,
    required bool isYumurta,
  }) {
    final cells = line.split(' | ');

    String cell(int idx) =>
        (idx >= 0 && idx < cells.length) ? cells[idx].trim() : '';

    final firma = cell(kolonlar.firmaIdx);
    if (firma.isEmpty) return null;

    final tc = cell(kolonlar.tcIdx);
    final adres = cell(kolonlar.adresIdx);

    // Tutar: önce KDV dahil, sonra KDV hariç, sonra birim fiyat
    double matrahBrut = parseTurkceSayi(cell(kolonlar.matrahIdx), fallback: 0);
    double matrahNet = kolonlar.kdvHaricIdx >= 0
        ? parseTurkceSayi(cell(kolonlar.kdvHaricIdx), fallback: 0)
        : 0;
    double birimFiyat = kolonlar.birimFiyatIdx >= 0
        ? parseTurkceSayi(cell(kolonlar.birimFiyatIdx), fallback: 0)
        : 0;
    int miktar = kolonlar.miktarIdx >= 0
        ? parseTurkceSayi(cell(kolonlar.miktarIdx), fallback: 1).toInt()
        : 1;
    if (miktar <= 0) miktar = 1;

    // KDV oranı ve tutarı — Yumurta için varsayılan %10
    final varsayilanKdvOrani = isYumurta ? 10.0 : 20.0;
    double kdvOrani = varsayilanKdvOrani;

    double genelToplam;
    double matrah; // KDV hariç matrah (fatura modeli)

    if (matrahBrut > 0 && matrahNet > 0) {
      // Her ikisi de doluysa gerçek KDV oranını hesapla
      genelToplam = matrahBrut;
      matrah = matrahNet;
      final kdvTutar = genelToplam - matrah;
      if (matrah > 0) kdvOrani = (kdvTutar / matrah * 100).roundToDouble();
    } else if (matrahBrut > 0) {
      // Sadece KDV dahil tutar var
      genelToplam = matrahBrut;
      matrah = genelToplam / (1 + kdvOrani / 100);
    } else if (matrahNet > 0) {
      // Sadece KDV hariç var
      matrah = matrahNet;
      genelToplam = matrah * (1 + kdvOrani / 100);
    } else if (birimFiyat > 0) {
      // Sadece birim fiyat var
      matrah = birimFiyat * miktar;
      genelToplam = matrah * (1 + kdvOrani / 100);
    } else {
      return null; // Tutar yok, atla
    }

    final kdvTutari = genelToplam - matrah;
    final cinsi = isYumurta ? 'Yumurta' : 'Hizmet Bedeli';

    return FaturaModel(
      id: '${DateTime.now().millisecondsSinceEpoch}_$satirIndex',
      firmaAdi: firma,
      adres: adres,
      vergiDairesi: '',
      vergiNo: tc,
      tarih: TurkceFormat.tarih(DateTime.now()),
      irsaliyeTarihi: '',
      irsaliyeNo: '',
      melbesNo: '',
      numuneNo: '',
      numuneAciklamasi: '',
      urunTuru: isYumurta ? 'YUMURTA' : 'DİĞER',
      kalemler: [
        {'cinsi': cinsi, 'miktar': miktar, 'fiyat': birimFiyat > 0 ? birimFiyat : (matrah / miktar)},
      ],
      matrah: double.parse(matrah.toStringAsFixed(2)),
      kdvOrani: kdvOrani,
      isKdvMuaf: false,
      kdvTutari: double.parse(kdvTutari.toStringAsFixed(2)),
      genelToplam: double.parse(genelToplam.toStringAsFixed(2)),
      parsedBy: FaturaParseKaynaklari.excelToplu,
    );
  }

  // ─── Yardımcı: Normalize + İçerik kontrolü ───────────────

  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ş', 's')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .trim();

  static bool _icerir(String normStr, List<String> anahtar) =>
      anahtar.any((k) => normStr.contains(k));

  // ─────────────────────────────────────────────────────────
  // Çevrimdışı metin yükleme (Offline Batch)
  // ─────────────────────────────────────────────────────────

  Future<void> loadBatchOffline(String text) =>
      loadBatch(text, cevrimdisi: true);

  // ─────────────────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _kuyrukProvider.removeListener(_kuyrukChanged);
    _matbuProvider.removeListener(_matbuChanged);
    _kuyrukProvider.dispose();
    _matbuProvider.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Yardımcı veri sınıfları — Excel başlık tespiti için
// ─────────────────────────────────────────────────────────────────────────────

class _ExcelKolonlar {
  final int firmaIdx;
  final int tcIdx;
  final int matrahIdx;
  final int kdvHaricIdx;
  final int kdvTutarIdx;
  final int miktarIdx;
  final int birimFiyatIdx;
  final int adresIdx;

  const _ExcelKolonlar({
    required this.firmaIdx,
    required this.tcIdx,
    required this.matrahIdx,
    required this.kdvHaricIdx,
    required this.kdvTutarIdx,
    required this.miktarIdx,
    required this.birimFiyatIdx,
    required this.adresIdx,
  });
}

class _ExcelBaslikSonucu {
  final int startRow;
  final _ExcelKolonlar kolonlar;

  const _ExcelBaslikSonucu({required this.startRow, required this.kolonlar});
}
