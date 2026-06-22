import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/turkce_format.dart';
import '../../birim/models/birim_model.dart';
import '../../birim/services/birim_service.dart';
import '../../../core/models/hizmet_model.dart';
import '../../../core/services/hizmet_service.dart';
import '../models/fatura_matbu_config.dart';
import '../models/fatura_model.dart';
import '../models/fatura_onay_sonucu.dart';
import '../models/fatura_parse_kaynaklari.dart';
import '../models/fatura_prefs_keys.dart';
import '../services/fatura_service.dart';

/// Kuyruk (pending invoices) yönetimi + fatura CRUD + birim işlemleri.
///
/// Sorumlulukları:
/// - `pendingInvoices` listesi ve `currentIndex`
/// - SharedPreferences ile otomatik kuyruk persistence
/// - Fatura ekleme/kopyalama/silme/onaylama
/// - Kalem ekleme/güncelleme/silme
/// - Alan bazlı güncelleme (`updateField`)
/// - Birim seçimi ve IBAN/hesap adı doldurma
/// - UBATAM validasyonu
class FaturaKuyrukProvider extends ChangeNotifier {
  // ── Kuyruk State ────────────────────────────────────────
  List<FaturaModel> pendingInvoices = [];
  int currentIndex = 0;
  Map<String, String> seciliBirimByFaturaId = {};
  int? geriYuklenenKuyrukSayisi;

  // ── Birim & Hizmet Cache ────────────────────────────────
  final BirimService _birimService = BirimService();
  List<BirimModel> _birimlerList = [];
  Map<String, BirimModel> _birimlerById = {};
  Map<String, BirimModel> _birimlerCache = {};
  final HizmetService _hizmetService = HizmetService();
  List<HizmetModel> _tumHizmetler = [];

  // ── Servisler ───────────────────────────────────────────
  final FaturaService _faturaService = FaturaService();

  // ── Timer ───────────────────────────────────────────────
  Timer? _kuyrukKaydetTimer;

  // ── Dialog için notify ──────────────────────────────────
  int dialogUpdateCounter = 0;

  void notifyDialogReturn() {
    dialogUpdateCounter++;
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────
  // Constructor & Initialization
  // ─────────────────────────────────────────────────────────

  FaturaKuyrukProvider() {
    _initializeEmpty();
    _fetchBirimler();
    unawaited(_loadKuyruk());
  }

  void _initializeEmpty() {
    pendingInvoices = [FaturaModel.bos()];
    currentIndex = 0;
  }

  // ─────────────────────────────────────────────────────────
  // Queue Persistence
  // ─────────────────────────────────────────────────────────

  bool _kayitWorthyQueue() => pendingInvoices.any((f) => !yerTutucuMu(f));

  static bool yerTutucuMu(FaturaModel f) =>
      f.firmaAdi.isEmpty && f.kalemler.isEmpty;

  Future<void> _loadKuyruk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(FaturaPrefsKeys.kuyruk);
      if (raw == null || raw.isEmpty) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = data['invoices'] as List<dynamic>? ?? [];
      if (list.isEmpty) return;

      final invoices = list
          .map((e) => FaturaModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (invoices.every(yerTutucuMu)) {
        await prefs.remove(FaturaPrefsKeys.kuyruk);
        return;
      }

      pendingInvoices = invoices;
      currentIndex = (data['currentIndex'] as int?) ?? 0;
      if (currentIndex >= pendingInvoices.length) currentIndex = 0;

      final birimMap = data['seciliBirimByFaturaId'] as Map<String, dynamic>?;
      if (birimMap != null) {
        seciliBirimByFaturaId =
            birimMap.map((k, v) => MapEntry(k, v.toString()));
      }

      _reapplySelectedBirimlerToInvoices();

      geriYuklenenKuyrukSayisi =
          invoices.where((f) => !yerTutucuMu(f)).length;
      notifyListeners();
    } catch (e) {
      debugPrint('Sistem ayarları yüklenemedi: $e');
    }

    try {
      _tumHizmetler = await _hizmetService.getAllHizmetler();
    } catch (e) {
      debugPrint('Hizmetler yüklenemedi: $e');
    }

    notifyListeners();
  }

  void _scheduleKuyrukKaydet() {
    _kuyrukKaydetTimer?.cancel();
    _kuyrukKaydetTimer =
        Timer(FaturaPrefsKeys.kuyrukKayitGecikmesi, () {
      unawaited(_persistKuyruk());
    });
  }

  Future<void> _persistKuyruk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_kayitWorthyQueue()) {
        await prefs.remove(FaturaPrefsKeys.kuyruk);
        return;
      }
      final payload = jsonEncode({
        'invoices': pendingInvoices.map((f) => f.toMap()).toList(),
        'currentIndex': currentIndex,
        'seciliBirimByFaturaId': seciliBirimByFaturaId,
        'savedAt': DateTime.now().toIso8601String(),
      });
      await prefs.setString(FaturaPrefsKeys.kuyruk, payload);
    } catch (e) {
      debugPrint('Fatura kuyruk kaydedilemedi: $e');
    }
  }

  void _queueChanged() {
    notifyListeners();
    _scheduleKuyrukKaydet();
  }

  Future<void> kuyruguTemizle() async {
    _kuyrukKaydetTimer?.cancel();
    seciliBirimByFaturaId.clear();
    _initializeEmpty();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(FaturaPrefsKeys.kuyruk);
    notifyListeners();
  }

  int? consumeGeriYuklemeBildirimi() {
    final n = geriYuklenenKuyrukSayisi;
    geriYuklenenKuyrukSayisi = null;
    return n;
  }

  // ─────────────────────────────────────────────────────────
  // Invoice CRUD
  // ─────────────────────────────────────────────────────────

  void addBlankInvoice() {
    final bos = FaturaModel.bos(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
    )..parsedBy = FaturaParseKaynaklari.manuel;
    bos.kalemler.add({'cinsi': '', 'miktar': 1, 'fiyat': 0.0});
    final hepsiBos = pendingInvoices.every(yerTutucuMu);
    if (hepsiBos) {
      pendingInvoices = [bos];
    } else {
      pendingInvoices.add(bos);
    }
    currentIndex = pendingInvoices.length - 1;
    _queueChanged();
  }

  void duplicateInvoice(int index) {
    if (index < 0 || index >= pendingInvoices.length) return;
    final src = pendingInvoices[index];
    final newId = DateTime.now().microsecondsSinceEpoch.toString();
    final copy = FaturaModel.fromJson(src.toMap())
      ..id = newId
      ..parsedBy = FaturaParseKaynaklari.kopya;
    final kaynakBirimId = seciliBirimByFaturaId[src.id];
    if (kaynakBirimId != null) {
      seciliBirimByFaturaId[newId] = kaynakBirimId;
    }
    pendingInvoices.insert(index + 1, copy);
    _queueChanged();
  }

  void removeInvoice(int index) {
    if (index < 0 || index >= pendingInvoices.length) return;
    final removedId = pendingInvoices[index].id;
    pendingInvoices.removeAt(index);
    seciliBirimByFaturaId.remove(removedId);
    if (pendingInvoices.isEmpty) _initializeEmpty();
    _queueChanged();
  }

  Future<void> approveInvoice(int index,
      {bool validateRequired = true}) async {
    if (index < 0 || index >= pendingInvoices.length) return;
    final invoice = pendingInvoices[index];
    if (validateRequired) {
      _validateInvoice(invoice);
    }
    await _faturaService.saveFatura(invoice);
    final removedId = invoice.id;
    pendingInvoices.removeAt(index);
    seciliBirimByFaturaId.remove(removedId);
    if (pendingInvoices.isEmpty) _initializeEmpty();
    _queueChanged();
  }

  Future<FaturaOnaySonucu> approveAll() async {
    final hatalar = <String>[];
    final kaydedilenIdler = <String>[];

    for (var i = 0; i < pendingInvoices.length; i++) {
      final invoice = pendingInvoices[i];
      if (invoice.kalemler.isEmpty) continue;
      final etiket = invoice.firmaAdi.trim().isEmpty
          ? 'Fatura #${i + 1}'
          : invoice.firmaAdi;
      try {
        _validateInvoice(invoice);
        await _faturaService.saveFatura(invoice);
        kaydedilenIdler.add(invoice.id);
      } catch (e) {
        hatalar.add('$etiket: $e');
      }
    }

    pendingInvoices.removeWhere((inv) {
      if (kaydedilenIdler.contains(inv.id)) {
        seciliBirimByFaturaId.remove(inv.id);
        return true;
      }
      return false;
    });
    if (pendingInvoices.isEmpty) _initializeEmpty();
    _queueChanged();
    return FaturaOnaySonucu(
      kaydedilen: kaydedilenIdler.length,
      hatalar: hatalar,
    );
  }

  // ─────────────────────────────────────────────────────────
  // Kalem Operations
  // ─────────────────────────────────────────────────────────

  void addKalem(int index) {
    if (index < 0 || index >= pendingInvoices.length) return;
    pendingInvoices[index].kalemler.add({
      'cinsi': '',
      'miktar': 1,
      'fiyat': 0.0,
    });
    _recalculateTotals(pendingInvoices[index]);
    _queueChanged();
  }

  void updateKalem(int invoiceIndex, int kalemIndex, String key, dynamic value) {
    if (invoiceIndex < 0 || invoiceIndex >= pendingInvoices.length) return;
    final currentInvoice = pendingInvoices[invoiceIndex];
    if (kalemIndex < 0 || kalemIndex >= currentInvoice.kalemler.length) return;
    currentInvoice.kalemler[kalemIndex][key] = value;
    if (key == 'birimAdi') _updateIbanForInvoice(currentInvoice);
    if (key == 'miktar' || key == 'fiyat') _recalculateTotals(currentInvoice);
    _queueChanged();
  }

  void removeKalem(int invoiceIndex, int kalemIndex) {
    if (invoiceIndex < 0 || invoiceIndex >= pendingInvoices.length) return;
    final currentInvoice = pendingInvoices[invoiceIndex];
    if (kalemIndex < 0 || kalemIndex >= currentInvoice.kalemler.length) return;
    currentInvoice.kalemler.removeAt(kalemIndex);
    _recalculateTotals(currentInvoice);
    _queueChanged();
  }

  void addEkstraNot(int index) {
    if (index < 0 || index >= pendingInvoices.length) return;
    if (pendingInvoices[index].ekstraNotlar.length >= 5) return; // Limit to 5
    pendingInvoices[index].ekstraNotlar.add('');
    _queueChanged();
  }

  void updateEkstraNot(int invoiceIndex, int notIndex, String value) {
    if (invoiceIndex < 0 || invoiceIndex >= pendingInvoices.length) return;
    final ekstraNotlar = pendingInvoices[invoiceIndex].ekstraNotlar;
    if (notIndex < 0 || notIndex >= ekstraNotlar.length) return;
    ekstraNotlar[notIndex] = value;
    _queueChanged();
  }

  void removeEkstraNot(int invoiceIndex, int notIndex) {
    if (invoiceIndex < 0 || invoiceIndex >= pendingInvoices.length) return;
    final ekstraNotlar = pendingInvoices[invoiceIndex].ekstraNotlar;
    if (notIndex < 0 || notIndex >= ekstraNotlar.length) return;
    ekstraNotlar.removeAt(notIndex);
    _queueChanged();
  }

  // ─────────────────────────────────────────────────────────
  // Field Update
  // ─────────────────────────────────────────────────────────

  void updateField(int index, String field, dynamic value) {
    if (index < 0 || index >= pendingInvoices.length) return;
    final currentInvoice = pendingInvoices[index];

    switch (field) {
      case 'firmaAdi':
        currentInvoice.firmaAdi = value.toString();
      case 'adres':
        currentInvoice.adres = value.toString();
      case 'vergiDairesi':
        currentInvoice.vergiDairesi = value.toString();
      case 'vergiNo':
        currentInvoice.vergiNo = value.toString();
      case 'tarih':
        currentInvoice.tarih = value.toString();
      case 'irsaliyeTarihi':
        currentInvoice.irsaliyeTarihi = value.toString();
      case 'irsaliyeNo':
        currentInvoice.irsaliyeNo = value.toString();
      case 'melbesNo':
        currentInvoice.melbesNo = value.toString();
      case 'melbesTam':
        currentInvoice.melbesNo = value.toString();
        currentInvoice.melbesKurumOnEki = ''; // Düzenleme yapıldığında öneki silip tamamını no'ya atıyoruz
      case 'melbesKurumOnEki':
        currentInvoice.melbesKurumOnEki = value.toString();
      case 'numuneNo':
        currentInvoice.numuneNo = value.toString();
      case 'numuneAciklamasi':
        currentInvoice.numuneAciklamasi = value.toString();
      case 'matrah':
        currentInvoice.matrah = TurkceFormat.parseSayi(
          value,
          fallback: currentInvoice.matrah,
        );
        if (!currentInvoice.isKdvMuaf) {
          currentInvoice.kdvTutari =
              currentInvoice.matrah * (currentInvoice.kdvOrani / 100.0);
          currentInvoice.genelToplam =
              currentInvoice.matrah + currentInvoice.kdvTutari;
        } else {
          currentInvoice.kdvTutari = 0.0;
          currentInvoice.genelToplam = currentInvoice.matrah;
        }
      case 'kdvOrani':
        currentInvoice.kdvOrani = TurkceFormat.parseSayi(
          value,
          fallback: currentInvoice.kdvOrani,
        );
        _recalculateTotals(currentInvoice);
      case 'kdvTutari':
        if (!currentInvoice.isKdvMuaf) {
          currentInvoice.kdvTutari = TurkceFormat.parseSayi(
            value,
            fallback: currentInvoice.kdvTutari,
          );
        }
      case 'genelToplam':
        currentInvoice.genelToplam = TurkceFormat.parseSayi(
          value,
          fallback: currentInvoice.genelToplam,
        );
      case 'iban':
        currentInvoice.iban = value?.toString();
      case 'hesapAdi':
        currentInvoice.hesapAdi = value?.toString();
      case 'hizmetTipi':
        currentInvoice.hizmetTipi = value?.toString();
      case 'kursAdi':
        currentInvoice.kursAdi = value?.toString();
      case 'kurNo':
        currentInvoice.kurNo =
            value != null ? int.tryParse(value.toString()) : null;
      case 'odemeTipi':
        currentInvoice.odemeTipi = value?.toString();
      case 'ytbOgrencisi':
        currentInvoice.ytbOgrencisi = value == true;
      case 'isKdvMuaf':
        currentInvoice.isKdvMuaf = value == true;
        _recalculateTotals(currentInvoice);
      case 'urunTuru':
        currentInvoice.urunTuru = value?.toString();
      case 'tedarikYontemi':
        currentInvoice.tedarikYontemi = value?.toString();
      case 'donem':
        currentInvoice.donem = value?.toString();
      case 'aciklama':
        currentInvoice.aciklama = value?.toString();
    }
    _queueChanged();
  }

  void toggleKdvMuaf(int index, bool value) {
    if (index < 0 || index >= pendingInvoices.length) return;
    final currentInvoice = pendingInvoices[index];
    currentInvoice.isKdvMuaf = value;
    if (value) {
      currentInvoice.kdvTutari = 0.0;
      currentInvoice.genelToplam = currentInvoice.matrah;
    } else {
      currentInvoice.kdvTutari =
          currentInvoice.matrah * (currentInvoice.kdvOrani / 100.0);
      currentInvoice.genelToplam =
          currentInvoice.matrah + currentInvoice.kdvTutari;
    }
    _queueChanged();
  }

  // ─────────────────────────────────────────────────────────
  // Validation
  // ─────────────────────────────────────────────────────────

  bool _ubatamZorunluAlanGecerliMi(FaturaModel invoice) {
    final birim = _invoiceBirim(invoice);
    if (birim == null) return false;
    final ad = birim.ad.toLowerCase();
    final kisaAd = birim.kisaAd.toLowerCase();
    return ad.contains('ubatam') || kisaAd == 'ubatam';
  }

  List<String> eksikAlanlarForInvoice(FaturaModel invoice) {
    final eksik = <String>[];
    if (invoice.firmaAdi.trim().isEmpty) eksik.add('Firma Adı');
    if (invoice.tarih.trim().isEmpty) eksik.add('Tarih');
    if (invoice.iban == null || invoice.iban!.trim().isEmpty) eksik.add('IBAN');
    if (invoice.hesapAdi == null || invoice.hesapAdi!.trim().isEmpty)
      eksik.add('Hesap Adı');
    if (invoice.kalemler.isEmpty) eksik.add('En az 1 kalem');
    if (_ubatamZorunluAlanGecerliMi(invoice)) {
      if (invoice.melbesNo.trim().isEmpty) eksik.add('MELBES No');
      if (invoice.numuneNo.trim().isEmpty) eksik.add('Numune No');
    }
    return eksik;
  }

  void _validateInvoice(FaturaModel invoice) {
    final eksik = eksikAlanlarForInvoice(invoice);
    if (eksik.isNotEmpty) {
      throw Exception('Eksik alanlar: ${eksik.join(', ')}');
    }
  }

  // ─────────────────────────────────────────────────────────
  // Birim Operations
  // ─────────────────────────────────────────────────────────

  Map<String, BirimModel> get birimlerCache => _birimlerCache;
  List<BirimModel> get birimler => _birimlerList;

  String getBirimKategori(String? birimIdOrAd) {
    final birim = findBirim(birimIdOrAd);
    if (birim == null) return 'genel';
    final ad = birim.kisaAd.toLowerCase();
    if (ad.contains('tömer') || ad.contains('usem')) return 'kurs';
    if (ad.contains('tarım') || ad.contains('tadaum')) return 'tarimsal';
    if (ad.contains('ubatam') || ad.contains('analiz')) return 'analiz';
    if (ad.contains('dösim') || ad.contains('dts') || ad.contains('deri'))
      return 'hizmet';
    if (ad.contains('satın alma')) return 'satin_alma';
    return 'genel';
  }

  BirimModel? findBirim(String? key) {
    if (key == null || key.isEmpty) return null;
    if (_birimlerById.containsKey(key)) return _birimlerById[key];
    if (_birimlerCache.containsKey(key)) return _birimlerCache[key];
    final norm = key.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    for (final b in _birimlerList) {
      final adNorm = b.ad.toLowerCase().replaceAll(RegExp(r'\s+'), '');
      final kisa = b.kisaAd.toLowerCase();
      if (adNorm == norm || kisa == norm) return b;
      if (adNorm.contains(norm) || norm.contains(kisa)) return b;
    }
    return null;
  }

  String? seciliBirimFor(int index) {
    if (index < 0 || index >= pendingInvoices.length) return null;
    return seciliBirimByFaturaId[pendingInvoices[index].id];
  }

  String? seciliBirimIbanFor(int index) {
    final birim = findBirim(seciliBirimFor(index));
    final iban = birim?.iban?.trim() ?? '';
    return iban.isEmpty ? null : iban;
  }

  bool ibanEslesiyorMu(int index) {
    if (index < 0 || index >= pendingInvoices.length) return false;
    final faturaIban = pendingInvoices[index].iban?.trim() ?? '';
    final birimIban = seciliBirimIbanFor(index)?.trim() ?? '';
    if (faturaIban.isEmpty || birimIban.isEmpty) return false;
    String normalize(String v) =>
        v.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    return normalize(faturaIban) == normalize(birimIban);
  }

  String? gecerliSeciliBirimFor(int index) {
    final id = seciliBirimFor(index);
    if (id == null) return null;
    return _birimlerById.containsKey(id) ? id : null;
  }

  void setSeciliBirim(int index, String birimId) {
    if (index < 0 || index >= pendingInvoices.length) return;
    seciliBirimByFaturaId[pendingInvoices[index].id] = birimId;
    applyBirimToInvoice(index, birimId);
    notifyDialogReturn();
  }

  Future<void> refreshBirimler() async {
    await _fetchBirimler(reapplyAndPersist: true);
    _hizmetService.getAllHizmetler(forceRefresh: true).then((val) {
      _tumHizmetler = val;
      notifyListeners();
    });
  }

  String? getFiyatUyarisi(String? birimAdi, String cinsi, double fiyat) {
    if (birimAdi == null || cinsi.trim().isEmpty) return null;
    final sistemHizmeti = _tumHizmetler
        .where(
          (h) =>
              h.birimAdi.toLowerCase() == birimAdi.toLowerCase() &&
              h.hizmetAdi.toLowerCase() == cinsi.trim().toLowerCase(),
        )
        .firstOrNull;
    if (sistemHizmeti != null && sistemHizmeti.fiyat != fiyat) {
      return 'Sistemdeki Liste Fiyatı: ${sistemHizmeti.fiyat.toStringAsFixed(2)} TL';
    }
    return null;
  }

  String _isletmeVknFallback(String? sistemVkn) {
    final vkn = sistemVkn?.trim() ?? '';
    return vkn.isNotEmpty ? vkn : FaturaMatbuConfig.varsayilanIsletmeVkn;
  }

  String? _formatHesapAdi(String? raw, String isletmeVkn) {
    if (raw == null || raw.trim().isEmpty) return null;
    return FaturaMatbuConfig.formatHesapAdiMatbu(
      raw,
      fallbackVkn: isletmeVkn,
    );
  }

  void applyBirimToInvoice(int invoiceIndex, String birimIdOrAd) {
    final birim = findBirim(birimIdOrAd);
    if (birim == null) return;
    final invoice = pendingInvoices[invoiceIndex];
    _applyBirimModelToInvoice(invoice, birim, '');
    _queueChanged();
  }

  void _applyBirimModelToInvoice(
      FaturaModel invoice, BirimModel birim, String isletmeVkn) {
    invoice.iban = birim.iban;
    invoice.hesapAdi = _formatHesapAdi(birim.hesapAdi, isletmeVkn);
    final ad = birim.ad.toLowerCase();
    final kisaAd = birim.kisaAd.toLowerCase();
    if ((ad.contains('ubatam') || kisaAd == 'ubatam') &&
        invoice.melbesKurumOnEki.trim().isEmpty) {
      invoice.melbesKurumOnEki = FaturaMatbuConfig.varsayilanMelbesKurumOnEki;
    }
    final birimEtiket = birim.kisaAd.isNotEmpty ? birim.kisaAd : birim.ad;
    for (var i = 0; i < invoice.kalemler.length; i++) {
      invoice.kalemler[i] = {...invoice.kalemler[i], 'birimAdi': birimEtiket};
    }
  }

  void _reapplySelectedBirimlerToInvoices({bool scheduleSave = false}) {
    if (_birimlerById.isEmpty || pendingInvoices.isEmpty) return;
    for (var i = 0; i < pendingInvoices.length; i++) {
      final invoice = pendingInvoices[i];
      final birimId = seciliBirimByFaturaId[invoice.id];
      final birim = birimId == null ? null : _birimlerById[birimId];
      if (birim == null) continue;
      _applyBirimModelToInvoice(invoice, birim, '');
    }
    if (scheduleSave) _scheduleKuyrukKaydet();
  }

  Future<void> _fetchBirimler({bool reapplyAndPersist = false}) async {
    try {
      final birimler = await _birimService.getAll(onlyActive: true);
      _birimlerList = birimler;
      _birimlerById = {for (final b in birimler) b.id: b};
      _birimlerCache = {};
      for (final b in birimler) {
        _birimlerCache[b.ad] = b;
        if (b.kisaAd.isNotEmpty) _birimlerCache[b.kisaAd] = b;
      }
      _reapplySelectedBirimlerToInvoices(scheduleSave: reapplyAndPersist);
      notifyListeners();
    } catch (e) {
      debugPrint('Birimler çekilirken hata: $e');
    }
  }

  void _updateIbanForInvoice(FaturaModel invoice) {
    final birim = _invoiceBirim(invoice);
    if (birim == null) return;
    if (birim.iban != null && birim.iban!.isNotEmpty) {
      invoice.iban = birim.iban;
    }
    if (birim.hesapAdi != null && birim.hesapAdi!.isNotEmpty) {
      invoice.hesapAdi = _formatHesapAdi(birim.hesapAdi, '');
    }
  }

  BirimModel? _invoiceBirim(FaturaModel invoice) {
    final seciliBirimId = seciliBirimByFaturaId[invoice.id];
    if (seciliBirimId != null && _birimlerById.containsKey(seciliBirimId)) {
      return _birimlerById[seciliBirimId];
    }
    if (invoice.kalemler.isEmpty) return null;
    final birimAdi = invoice.kalemler.first['birimAdi'] as String?;
    return findBirim(birimAdi);
  }

  // ─────────────────────────────────────────────────────────
  // Recalculate
  // ─────────────────────────────────────────────────────────

  void _recalculateTotals(FaturaModel invoice) {
    double matrah = 0;
    for (var kalem in invoice.kalemler) {
      final miktar = TurkceFormat.parseSayi(kalem['miktar'], fallback: 0.0);
      final fiyat = TurkceFormat.parseSayi(kalem['fiyat'], fallback: 0.0);
      matrah += miktar * fiyat;
    }
    invoice.matrah = matrah;
    if (invoice.isKdvMuaf) {
      invoice.kdvTutari = 0.0;
      invoice.genelToplam = matrah;
    } else {
      invoice.kdvTutari = matrah * (invoice.kdvOrani / 100.0);
      invoice.genelToplam = matrah + invoice.kdvTutari;
    }
  }

  // ─────────────────────────────────────────────────────────
  // External Helpers (BatchFaturaProvider / UI tarafından kullanılır)
  // ─────────────────────────────────────────────────────────

  /// Dışarıdan toplu hesaplama (örn. loadBatch sonrası).
  void recalculateTotalsForInvoice(FaturaModel invoice) {
    _recalculateTotals(invoice);
  }

  /// Dışarıdan IBAN güncelleme.
  void updateIbanForInvoiceExternal(FaturaModel invoice) {
    _updateIbanForInvoice(invoice);
  }

  /// Dışarıdan kuyruk kaydetme zamanlayıcısını tetikleme.
  void scheduleKuyrukKaydetExternal() {
    _scheduleKuyrukKaydet();
  }

  /// Nakli Yekün bayrağını ayarla.
  void setInvoiceNakliYekun(int index, bool value) {
    if (index < 0 || index >= pendingInvoices.length) return;
    pendingInvoices[index].nakliYekunAktif = value;
    _queueChanged();
  }

  /// Kalibrasyon/önizleme: yalnızca faturanın kendi nakli bayrağı.
  bool nakliAlanlariGoster(FaturaModel invoice) => invoice.nakliYekunAktif;

  /// AI/parse sonrası kuyruğu toplu güncelle.
  /// Her fatura için: toplamları yeniden hesapla, IBAN güncelle,
  /// tahmini birim varsa bul ve uygula.
  void setInvoicesFromParse(List<FaturaModel> invoices) {
    seciliBirimByFaturaId.clear();
    for (final inv in invoices) {
      _recalculateTotals(inv);
      _updateIbanForInvoice(inv);
      if (inv.tahminiBirim != null && inv.tahminiBirim!.trim().isNotEmpty) {
        final predicted = findBirim(inv.tahminiBirim);
        if (predicted != null) {
          seciliBirimByFaturaId[inv.id] = predicted.id;
          _updateIbanForInvoice(inv);
        }
      }
    }
    pendingInvoices = invoices;
    currentIndex = 0;
    _queueChanged();
  }

  // ─────────────────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _kuyrukKaydetTimer?.cancel();
    super.dispose();
  }
}
