import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/services/ai_extraction_service.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../../../core/models/sistem_ayarlari_model.dart';
import '../../../core/turkce_format.dart';
import '../../birim/models/birim_model.dart';
import '../../../core/models/hizmet_model.dart';
import '../../../core/services/hizmet_service.dart';
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
import '../services/excel_web_parser.dart';
import '../services/fatura_pdf_uretici.dart';
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

  // ── PDF Font Cache ───────────────────────────────────────
  static pw.Font? _pdfFontRegular;
  static pw.Font? _pdfFontBold;

  Future<(pw.Font regular, pw.Font bold)> _pdfFontlari() async {
    _pdfFontRegular ??= await PdfGoogleFonts.tinosRegular();
    _pdfFontBold ??= await PdfGoogleFonts.tinosBold();
    return (_pdfFontRegular!, _pdfFontBold!);
  }

  // ── AI & Servisler ───────────────────────────────────────
  final AIExtractionService _aiService = AIExtractionService();
  final FaturaService _faturaService = FaturaService();
  final HizmetService _hizmetService = HizmetService();
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
  set currentIndex(int v) => _kuyrukProvider.currentIndex = v;

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

  Offset _konum(String key) => _matbuProvider.konum(key);

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

  void setGlobalOffset(double dx, double dy) {
    _matbuProvider.setGlobalOffset(dx, dy);
  }

  void setMatbuBaskiModu(bool value) {
    _matbuProvider.setMatbuBaskiModu(value);
  }

  Future<void> saveMatbuAyarlari() => _matbuProvider.saveMatbuAyarlari();
  Future<void> saveCoordinates() => _matbuProvider.saveCoordinates();
  Future<void> resetCoordinates() => _matbuProvider.resetCoordinates();

  void toggleNakliYekunGlobal(bool value) {
    _matbuProvider.toggleNakliYekunGlobal(value);
  }

  void calibrationUiRefresh() {
    notifyListeners();
    _matbuProvider.calibrationUiRefresh();
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

  KalibrasyonBaskiOnizleme kalibrasyonBaskiOnizlemesi() {
    final fatura = kalibrasyonFaturasi();
    final ornek = fatura.id == 'ornek';
    if (ornek) {
      return KalibrasyonBaskiOnizleme.ornek(
        isletmeVkn: _isletmeVknFallback(),
        yaziyla: TurkceFormat.sayiyiYaziyaCevir,
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
      yaziyla: TurkceFormat.sayiyiYaziyaCevir,
      canliVeri: true,
      baslik: baslik,
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
    await yukleArsivDurumu();
  }

  Future<FaturaOnaySonucu> approveAll() async {
    final sonuc = await _kuyrukProvider.approveAll();
    if (sonuc.kaydedilen > 0) await yukleArsivDurumu();
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
      arsivUyarisi = await _faturaService.eskiArsivOzetiniGetir();
      arsivYilSayilari = await _faturaService.tumYilSayilari();
      mevcutYilArsivSayisi = await _faturaService.mevcutYilArsivSayisi();
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
    final bytes = await FaturaPdfUretici.generatePdf(
      invoice: invoice,
      includeBackground: false,
      coordinates: _matbuProvider.coordinates,
      kalemSatirAraligi: _matbuProvider.kalemSatirAraligi,
      matbuFontBoyutu: _matbuProvider.matbuFontBoyutu,
      globalOffsetDx: _matbuProvider.globalOffsetDx,
      globalOffsetDy: _matbuProvider.globalOffsetDy,
      matbuBaskiModu: _matbuProvider.matbuBaskiModu,
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
    return FaturaPdfUretici.generatePdf(
      invoice: invoice,
      includeBackground: includeBackground,
      coordinates: _matbuProvider.coordinates,
      kalemSatirAraligi: _matbuProvider.kalemSatirAraligi,
      matbuFontBoyutu: _matbuProvider.matbuFontBoyutu,
      globalOffsetDx: _matbuProvider.globalOffsetDx,
      globalOffsetDy: _matbuProvider.globalOffsetDy,
      matbuBaskiModu: _matbuProvider.matbuBaskiModu,
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
  }) async {
    List<FaturaModel> sonuc = [];

    if (!cevrimdisi) {
      // Katman 1 — Arşiv eşleştirme
      try {
        final arsivKayitlar = await _faturaService.araFaturalar(
          FaturaArsivAramaFiltre(metin: ''),
        );
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

      // Katman 2 — AI
      if (sonuc.isEmpty) {
        try {
          final extractedData = await _aiService.extractBatchData(
            text,
            pdfBytes: pdfBytes,
          );
          sonuc = extractedData.map(FaturaModel.fromJson).toList();
          if (sonuc.isNotEmpty) {
            sonAyristirmaBilgisi = sonuc.first.parsedBy;
          }
        } catch (e) {
          debugPrint(
            'AI ayrıştırma başarısız, çevrimdışı parser deneniyor: $e',
          );
        }
      }
    }

    if (sonuc.isEmpty) {
      sonuc = FaturaOfflineParser.parse(text);
      if (sonuc.isNotEmpty) {
        sonAyristirmaBilgisi = sonuc.first.parsedBy;
      }
    }

    if (sonuc.isEmpty) {
      throw Exception(
        'Fatura okunamadı. AI anahtarı yoksa metin biçimini kontrol edin '
        'veya alanları manuel doldurun.',
      );
    }

    _kuyrukProvider.setInvoicesFromParse(sonuc);
  }

  Future<void> loadBatchOffline(String text) =>
      loadBatch(text, cevrimdisi: true);

  Future<void> loadExcelFile(Uint8List bytes, String fileName) async {
    final csvText = await ExcelWebParser.extractTextFromExcel(bytes);
    if (csvText.isEmpty) throw Exception('Excel dosyası boş veya okunamadı.');

    final lines = csvText.split('\n');
    final previewLines = lines.take(15).join('\n');

    Map<String, dynamic> mappingResult;
    try {
      mappingResult = await _aiService.extractExcelMapping(previewLines);
    } catch (e) {
      debugPrint('AI Excel eşleme başarısız, çevrimdışı parser deneniyor: $e');
      mappingResult = {'isBatchList': false};
    }

    if (mappingResult['isBatchList'] == true) {
      final mapData = mappingResult['mapping'] as Map<String, dynamic>;
      final startRow = (mappingResult['startRowIndex'] as int?) ?? 1;
      final newInvoices = <FaturaModel>[];

      final firmaIdx = mapData['firmaAdi'] as int?;
      final tcIdx = mapData['tcVkn'] as int?;
      final matrahIdx = mapData['matrah'] as int?;

      for (int i = startRow; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        final cells = line.split(' | ');
        String firma = '';
        String tc = '';
        double matrah = 0.0;

        if (firmaIdx != null && firmaIdx >= 0 && firmaIdx < cells.length) {
          firma = cells[firmaIdx].trim();
        }
        if (tcIdx != null && tcIdx >= 0 && tcIdx < cells.length) {
          tc = cells[tcIdx].trim();
        }
        if (matrahIdx != null && matrahIdx >= 0 && matrahIdx < cells.length) {
          matrah = parseTurkceSayi(cells[matrahIdx], fallback: 0.0);
        }

        if (firma.isNotEmpty && matrah > 0) {
          final inv = FaturaModel(
            id: '${DateTime.now().millisecondsSinceEpoch}$i',
            firmaAdi: firma,
            adres: '',
            vergiDairesi: '',
            vergiNo: tc,
            tarih: '',
            irsaliyeTarihi: '',
            irsaliyeNo: '',
            melbesNo: '',
            numuneNo: '',
            numuneAciklamasi: '',
            kalemler: [
              {'cinsi': 'Hizmet Bedeli', 'miktar': 1, 'fiyat': matrah},
            ],
            matrah: matrah,
            kdvOrani: 20.0,
            isKdvMuaf: false,
            kdvTutari: 0.0,
            genelToplam: 0.0,
            parsedBy: FaturaParseKaynaklari.excelToplu,
          );
          _kuyrukProvider.recalculateTotalsForInvoice(inv);
          newInvoices.add(inv);
        }
      }

      if (newInvoices.isEmpty) {
        throw Exception('Eşleşen satır bulunamadı veya veriler okunamadı.');
      }
      _kuyrukProvider.pendingInvoices = newInvoices;
      _kuyrukProvider.currentIndex = 0;
      _kuyrukProvider.seciliBirimByFaturaId.clear();
      _kuyrukProvider.notifyListeners();
      _kuyrukProvider.scheduleKuyrukKaydetExternal();
    } else {
      await loadBatch(csvText);
    }
  }

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
