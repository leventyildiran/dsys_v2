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
import '../../birim/services/birim_service.dart';
import '../models/fatura_matbu_config.dart';
import '../models/fatura_arsiv_util.dart';
import '../models/fatura_model.dart';
import '../services/fatura_service.dart';
import '../services/fatura_offline_parser.dart';
import '../services/fatura_arsiv_export_servisi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/excel_web_parser.dart';

class FaturaOnaySonucu {
  final int kaydedilen;
  final List<String> hatalar;

  const FaturaOnaySonucu({required this.kaydedilen, required this.hatalar});
}

class BatchFaturaProvider extends ChangeNotifier {
  List<FaturaModel> pendingInvoices = [];
  int currentIndex = 0;
  bool isNakliYekunAktif = false;
  int dialogUpdateCounter = 0;

  static pw.Font? _pdfFontRegular;
  static pw.Font? _pdfFontBold;

  /// Türkçe karakter desteği için Tinos (YK PDF ile aynı aile).
  Future<(pw.Font regular, pw.Font bold)> _pdfFontlari() async {
    _pdfFontRegular ??= await PdfGoogleFonts.tinosRegular();
    _pdfFontBold ??= await PdfGoogleFonts.tinosBold();
    return (_pdfFontRegular!, _pdfFontBold!);
  }

  /// Matbu kağıt üzerine basım: arka plan kapalı (sadece metin).
  bool matbuBaskiModu = true;

  double kalemSatirAraligi = FaturaMatbuConfig.varsayilanKalemSatirAraligi;
  double matbuFontBoyutu = FaturaMatbuConfig.varsayilanFontBoyutu;
  double globalOffsetDx = 0;
  double globalOffsetDy = 0;

  Map<String, Offset> coordinates = FaturaMatbuConfig.varsayilanKoordinatlar();

  final BirimService _birimService = BirimService();
  List<BirimModel> _birimlerList = [];
  Map<String, BirimModel> _birimlerById = {};
  Map<String, BirimModel> _birimlerCache = {};
  final AIExtractionService _aiService = AIExtractionService();
  final FaturaService _faturaService = FaturaService();
  SistemAyarlariModel? sistemAyarlari;

  /// Geçici Firestore arşiv durumu.
  FaturaTemizlikUyarisi? arsivUyarisi;
  Map<int, int> arsivYilSayilari = {};
  int mevcutYilArsivSayisi = 0;
  bool arsivYukleniyor = false;

  /// Son ayrıştırmanın hangi yöntemle yapıldığını UI'a bildirir.
  String? sonAyristirmaBilgisi;

  static const _kuyrukPrefsKey = 'fatura_pending_kuyruk_v1';
  Timer? _kuyrukKaydetTimer;

  /// Fatura id → seçili birim id (sayfa yenilemede korunur).
  Map<String, String> seciliBirimByFaturaId = {};

  /// Geri yükleme sonrası tek seferlik bildirim için.
  int? geriYuklenenKuyrukSayisi;

  void notifyDialogReturn() {
    dialogUpdateCounter++;
    notifyListeners();
  }

  Offset _konum(String key) {
    final base = coordinates[key] ?? Offset.zero;
    return Offset(base.dx + globalOffsetDx, base.dy + globalOffsetDy);
  }

  void updateCoordinate(String key, Offset newOffset, {bool notify = true}) {
    coordinates[key] = Offset(
      newOffset.dx - globalOffsetDx,
      newOffset.dy - globalOffsetDy,
    );
    if (notify) notifyListeners();
  }

  /// Sürükleme sırasında delta uygular (notify=false ile kasma önlenir).
  void updateCoordinateDelta(String key, Offset delta, {bool notify = true}) {
    final current = coordinates[key];
    if (current == null) return;
    coordinates[key] = Offset(current.dx + delta.dx, current.dy + delta.dy);
    if (notify) notifyListeners();
  }

  void nudgeCoordinate(String key, double dx, double dy) {
    updateCoordinateDelta(key, Offset(dx, dy));
  }

  void calibrationUiRefresh() => notifyListeners();

  void setKalemSatirAraligi(double value) {
    kalemSatirAraligi = value;
    notifyListeners();
  }

  void setMatbuFontBoyutu(double value) {
    matbuFontBoyutu = value;
    notifyListeners();
  }

  void setGlobalOffset(double dx, double dy) {
    globalOffsetDx = dx;
    globalOffsetDy = dy;
    notifyListeners();
  }

  void setMatbuBaskiModu(bool value) {
    matbuBaskiModu = value;
    notifyListeners();
  }

  Future<void> saveMatbuAyarlari() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in coordinates.entries) {
      await prefs.setDouble('${entry.key}_dx', entry.value.dx);
      await prefs.setDouble('${entry.key}_dy', entry.value.dy);
    }
    await prefs.setDouble('fatura_kalem_satir_araligi', kalemSatirAraligi);
    await prefs.setDouble('fatura_matbu_font_boyutu', matbuFontBoyutu);
    await prefs.setDouble('fatura_global_offset_dx', globalOffsetDx);
    await prefs.setDouble('fatura_global_offset_dy', globalOffsetDy);
    await prefs.setBool('fatura_matbu_baski_modu', matbuBaskiModu);
  }

  Future<void> saveCoordinates() => saveMatbuAyarlari();

  Future<void> _loadMatbuAyarlari() async {
    final prefs = await SharedPreferences.getInstance();
    coordinates.forEach((key, value) {
      final dx = prefs.getDouble('${key}_dx');
      final dy = prefs.getDouble('${key}_dy');
      if (dx != null && dy != null) {
        coordinates[key] = Offset(dx, dy);
      }
    });
    kalemSatirAraligi = prefs.getDouble('fatura_kalem_satir_araligi') ??
        FaturaMatbuConfig.varsayilanKalemSatirAraligi;
    matbuFontBoyutu = prefs.getDouble('fatura_matbu_font_boyutu') ??
        FaturaMatbuConfig.varsayilanFontBoyutu;
    globalOffsetDx = prefs.getDouble('fatura_global_offset_dx') ?? 0;
    globalOffsetDy = prefs.getDouble('fatura_global_offset_dy') ?? 0;
    matbuBaskiModu = prefs.getBool('fatura_matbu_baski_modu') ?? true;
    notifyListeners();
  }

  Future<void> resetCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in coordinates.keys) {
      await prefs.remove('${key}_dx');
      await prefs.remove('${key}_dy');
    }
    await prefs.remove('fatura_kalem_satir_araligi');
    await prefs.remove('fatura_matbu_font_boyutu');
    await prefs.remove('fatura_global_offset_dx');
    await prefs.remove('fatura_global_offset_dy');

    coordinates = FaturaMatbuConfig.varsayilanKoordinatlar();
    kalemSatirAraligi = FaturaMatbuConfig.varsayilanKalemSatirAraligi;
    matbuFontBoyutu = FaturaMatbuConfig.varsayilanFontBoyutu;
    globalOffsetDx = 0;
    globalOffsetDy = 0;
    notifyListeners();
  }

  Future<void> _loadSistemAyarlari() async {
    sistemAyarlari = await SistemAyarlariService().getAyarlar();
    notifyListeners();
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

  void toggleNakliYekunGlobal(bool value) {
    isNakliYekunAktif = value;
    _queueChanged();
  }

  BatchFaturaProvider() {
    _initializeEmpty();
    _fetchBirimler();
    _loadSistemAyarlari();
    _loadMatbuAyarlari();
    unawaited(_loadKuyruk());
  }

  bool _kayitWorthyQueue() =>
      pendingInvoices.any((f) => !yerTutucuMu(f));

  Future<void> _loadKuyruk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kuyrukPrefsKey);
      if (raw == null || raw.isEmpty) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = data['invoices'] as List<dynamic>? ?? [];
      if (list.isEmpty) return;

      final invoices = list
          .map((e) => FaturaModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (invoices.every(yerTutucuMu)) {
        await prefs.remove(_kuyrukPrefsKey);
        return;
      }

      pendingInvoices = invoices;
      currentIndex = (data['currentIndex'] as int?) ?? 0;
      if (currentIndex >= pendingInvoices.length) currentIndex = 0;
      isNakliYekunAktif = data['isNakliYekunAktif'] == true;

      final birimMap = data['seciliBirimByFaturaId'] as Map<String, dynamic>?;
      if (birimMap != null) {
        seciliBirimByFaturaId =
            birimMap.map((k, v) => MapEntry(k, v.toString()));
      }

      geriYuklenenKuyrukSayisi =
          invoices.where((f) => !yerTutucuMu(f)).length;
      notifyListeners();
    } catch (e) {
      debugPrint('Fatura kuyruk geri yüklenemedi: $e');
    }
  }

  void _scheduleKuyrukKaydet() {
    _kuyrukKaydetTimer?.cancel();
    _kuyrukKaydetTimer = Timer(const Duration(milliseconds: 500), () {
      unawaited(_persistKuyruk());
    });
  }

  Future<void> _persistKuyruk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_kayitWorthyQueue()) {
        await prefs.remove(_kuyrukPrefsKey);
        return;
      }
      final payload = jsonEncode({
        'invoices': pendingInvoices.map((f) => f.toMap()).toList(),
        'currentIndex': currentIndex,
        'isNakliYekunAktif': isNakliYekunAktif,
        'seciliBirimByFaturaId': seciliBirimByFaturaId,
        'savedAt': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_kuyrukPrefsKey, payload);
    } catch (e) {
      debugPrint('Fatura kuyruk kaydedilemedi: $e');
    }
  }

  void _queueChanged() {
    notifyListeners();
    _scheduleKuyrukKaydet();
  }

  int? consumeGeriYuklemeBildirimi() {
    final n = geriYuklenenKuyrukSayisi;
    geriYuklenenKuyrukSayisi = null;
    return n;
  }

  String? seciliBirimFor(int index) {
    if (index < 0 || index >= pendingInvoices.length) return null;
    return seciliBirimByFaturaId[pendingInvoices[index].id];
  }

  void setSeciliBirim(int index, String birimId) {
    if (index < 0 || index >= pendingInvoices.length) return;
    seciliBirimByFaturaId[pendingInvoices[index].id] = birimId;
    applyBirimToInvoice(index, birimId);
  }

  Future<void> kuyruguTemizle() async {
    _kuyrukKaydetTimer?.cancel();
    seciliBirimByFaturaId.clear();
    _initializeEmpty();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kuyrukPrefsKey);
    notifyListeners();
  }

  static String _arsivUyarisiPrefsKey(int yil) => 'fatura_arsiv_uyari_${yil}_kapatildi';

  /// Geçici arşivde arama (tarih + metin).
  Future<List<FaturaArsivKayit>> araArsiv(FaturaArsivAramaFiltre filtre) async {
    return _faturaService.araFaturalar(filtre);
  }

  /// Arşiv yönetim paneli açıldığında özet yükler.
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

  /// Yıl başı (Ocak–Mart) temizlik diyaloğu gösterilmeli mi?
  Future<bool> yilBasiTemizlikDialoguGosterilmeli() async {
    if (!FaturaArsivUtil.yilBasiTemizlikDonemi()) return false;
    if (arsivUyarisi == null || !arsivUyarisi!.gosterilmeli) return false;

    final prefs = await SharedPreferences.getInstance();
    final key = _arsivUyarisiPrefsKey(FaturaArsivUtil.suAnkiYil());
    return !(prefs.getBool(key) ?? false);
  }

  /// Bu yıl için temizlik uyarısını "daha sonra" olarak işaretle.
  Future<void> yilBasiUyarisiErtele() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_arsivUyarisiPrefsKey(FaturaArsivUtil.suAnkiYil()), true);
  }

  /// Belirtilen yılın geçici arşivini siler.
  Future<int> silYilArsivi(int yil) async {
    final adet = await _faturaService.silYilArsivi(yil);
    await yukleArsivDurumu();
    return adet;
  }

  /// Mevcut yıldan önceki tüm geçici arşivi siler.
  Future<int> silTumEskiArsiv() async {
    final adet = await _faturaService.silTumEskiArsiv();
    await yukleArsivDurumu();
    return adet;
  }

  /// Belirtilen yılın arşivini JSON olarak indirir.
  Future<void> indirYilArsiviJson(int yil) async {
    final kayitlar = await _faturaService.yilArsiviniGetir(yil);
    if (kayitlar.isEmpty) throw Exception('$yil yılında indirilecek kayıt yok.');
    await FaturaArsivExportServisi.indirJson(yil, kayitlar);
  }

  /// Belirtilen yılın arşivini CSV (Excel) olarak indirir.
  Future<void> indirYilArsiviCsv(int yil) async {
    final kayitlar = await _faturaService.yilArsiviniGetir(yil);
    if (kayitlar.isEmpty) throw Exception('$yil yılında indirilecek kayıt yok.');
    await FaturaArsivExportServisi.indirCsv(yil, kayitlar);
  }

  /// Eski yılların tamamını ZIP (JSON+CSV) olarak indirir.
  Future<int> indirEskiArsivZip() async {
    final yilKayitlari = await _faturaService.eskiArsivKayitlariniGetir();
    if (yilKayitlari.isEmpty) throw Exception('İndirilecek eski arşiv yok.');
    await FaturaArsivExportServisi.indirYillikZip(yilKayitlari);
    var toplam = 0;
    for (final liste in yilKayitlari.values) {
      toplam += liste.length;
    }
    return toplam;
  }

  /// Önce yedek indirir, sonra eski arşivi siler.
  Future<({int indirilen, int silinen})> indirVeSilEskiArsiv() async {
    final yilKayitlari = await _faturaService.eskiArsivKayitlariniGetir();
    if (yilKayitlari.isEmpty) throw Exception('Silinecek eski arşiv yok.');
    await FaturaArsivExportServisi.indirYillikZip(yilKayitlari);
    var indirilen = 0;
    for (final liste in yilKayitlari.values) {
      indirilen += liste.length;
    }
    final silinen = await silTumEskiArsiv();
    return (indirilen: indirilen, silinen: silinen);
  }


  void _initializeEmpty() {
    pendingInvoices = [FaturaModel.bos()];
    currentIndex = 0;
  }

  Map<String, BirimModel> get birimlerCache => _birimlerCache;
  List<BirimModel> get birimler => _birimlerList;

  String getBirimKategori(String? birimIdOrAd) {
    final birim = findBirim(birimIdOrAd);
    if (birim == null) return 'genel';
    
    final ad = birim.kisaAd.toLowerCase();
    if (ad.contains('tömer') || ad.contains('usem')) return 'kurs';
    if (ad.contains('tarım') || ad.contains('tadaum')) return 'tarimsal';
    if (ad.contains('ubatam') || ad.contains('analiz')) return 'analiz';
    if (ad.contains('dösim') || ad.contains('dts') || ad.contains('deri')) return 'hizmet';
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

  void applyBirimToInvoice(int invoiceIndex, String birimIdOrAd) {
    final birim = findBirim(birimIdOrAd);
    if (birim == null) return;
    final invoice = pendingInvoices[invoiceIndex];
    invoice.iban = birim.iban;
    invoice.hesapAdi = birim.hesapAdi != null
        ? FaturaMatbuConfig.formatHesapAdiMatbu(birim.hesapAdi!)
        : null;
    final birimEtiket = birim.kisaAd.isNotEmpty ? birim.kisaAd : birim.ad;
    for (var i = 0; i < invoice.kalemler.length; i++) {
      invoice.kalemler[i] = {...invoice.kalemler[i], 'birimAdi': birimEtiket};
    }
    _queueChanged();
  }

  Future<void> _fetchBirimler() async {
    try {
      final birimler = await _birimService.getAll(onlyActive: true);
      _birimlerList = birimler;
      _birimlerById = {for (final b in birimler) b.id: b};
      _birimlerCache = {};
      for (final b in birimler) {
        _birimlerCache[b.ad] = b;
        if (b.kisaAd.isNotEmpty) _birimlerCache[b.kisaAd] = b;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Birimler çekilirken hata: $e');
    }
  }

  void _updateIbanForInvoice(FaturaModel invoice) {
    if (invoice.kalemler.isEmpty) return;
    final birimAdi = invoice.kalemler.first['birimAdi'] as String?;
    final birim = findBirim(birimAdi);
    if (birim == null) return;
    if (birim.iban != null && birim.iban!.isNotEmpty) {
      invoice.iban = birim.iban;
    }
    if (birim.hesapAdi != null && birim.hesapAdi!.isNotEmpty) {
      invoice.hesapAdi = FaturaMatbuConfig.formatHesapAdiMatbu(birim.hesapAdi!);
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

  bool _ubatamZorunluAlanGecerliMi(FaturaModel invoice) {
    final birim = _invoiceBirim(invoice);
    if (birim == null) return false;
    final ad = birim.ad.toLowerCase();
    final kisaAd = birim.kisaAd.toLowerCase();
    return ad.contains('ubatam') || kisaAd == 'ubatam';
  }

  /// UBATAM dışı birimlerde MELBES ve Numune No zorunlu değildir.
  List<String> eksikAlanlarForInvoice(FaturaModel invoice) {
    final eksik = <String>[];
    if (invoice.firmaAdi.trim().isEmpty) eksik.add('Firma Adı');
    if (invoice.tarih.trim().isEmpty) eksik.add('Tarih');
    if (invoice.iban == null || invoice.iban!.trim().isEmpty) eksik.add('IBAN');
    if (invoice.hesapAdi == null || invoice.hesapAdi!.trim().isEmpty) eksik.add('Hesap Adı');
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

  /// Metni faturaya çevirir.
  /// [cevrimdisi] true ise doğrudan kural tabanlı parser kullanılır.
  /// false ise önce AI denenir, başarısız olursa otomatik olarak
  /// çevrimdışı parser'a düşülür (internet/AI yoksa iş durmaz).
  Future<void> loadBatch(String text, {bool cevrimdisi = false}) async {
    List<FaturaModel> sonuc = [];

    if (!cevrimdisi) {
      try {
        final extractedData = await _aiService.extractBatchData(text);
        sonuc = extractedData.map(FaturaModel.fromJson).toList();
        sonAyristirmaBilgisi = sonuc.isEmpty ? null : 'Yapay zeka ile okundu';
      } catch (e) {
        debugPrint('AI ayrıştırma başarısız, çevrimdışı parser deneniyor: $e');
      }
    }

    if (sonuc.isEmpty) {
      sonuc = FaturaOfflineParser.parse(text);
      if (sonuc.isNotEmpty) {
        sonAyristirmaBilgisi = 'Çevrimdışı (kural tabanlı) okundu';
      }
    }

    if (sonuc.isEmpty) {
      throw Exception(
        'Fatura okunamadı. AI anahtarı yoksa metin biçimini kontrol edin '
        'veya alanları manuel doldurun.',
      );
    }

    seciliBirimByFaturaId.clear();
    for (final inv in sonuc) {
      _updateIbanForInvoice(inv);
      if (inv.tahminiBirim != null && inv.tahminiBirim!.trim().isNotEmpty) {
        final predicted = findBirim(inv.tahminiBirim);
        if (predicted != null) {
          seciliBirimByFaturaId[inv.id] = predicted.id;
        }
      }
    }
    pendingInvoices = sonuc;
    currentIndex = 0;
    _queueChanged();
  }

  /// Çevrimdışı (AI'sız) ayrıştırma için kısayol.
  Future<void> loadBatchOffline(String text) => loadBatch(text, cevrimdisi: true);

  /// Başlangıç yer tutucusu mu? (henüz kullanıcı işlem yapmadı)
  /// parsedBy değerinden bağımsız: firma adı ve kalem yoksa yer tutucudur.
  static bool yerTutucuMu(FaturaModel f) =>
      f.firmaAdi.isEmpty && f.kalemler.isEmpty;

  /// Manuel giriş için kuyruğa boş bir fatura ekler.
  void addBlankInvoice() {
    final bos = FaturaModel.bos(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
    )..parsedBy = 'Manuel Giriş';

    // Yer tutucu (boş) faturalar varsa temizle; içeriği olan faturalara dokunma.
    final hepsiBos = pendingInvoices.every(yerTutucuMu);
    if (hepsiBos) {
      pendingInvoices = [bos];
    } else {
      pendingInvoices.add(bos);
    }
    currentIndex = pendingInvoices.length - 1;
    _queueChanged();
  }

  /// Mevcut faturanın birebir kopyasını kuyruğa ekler.
  /// Seçili birim bilgisi de kopyalanır — IBAN/HesapAdı kopya kartta da dolu görünür.
  void duplicateInvoice(int index) {
    if (index < 0 || index >= pendingInvoices.length) return;
    final src = pendingInvoices[index];
    final newId = DateTime.now().microsecondsSinceEpoch.toString();
    final copy = FaturaModel.fromJson(src.toMap())
      ..id = newId
      ..parsedBy = 'Kopya';
    // Kaynak faturanın seçili birimini yeni ID ile kopyala.
    final kaynakBirimId = seciliBirimByFaturaId[src.id];
    if (kaynakBirimId != null) {
      seciliBirimByFaturaId[newId] = kaynakBirimId;
    }
    pendingInvoices.insert(index + 1, copy);
    _queueChanged();
  }

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
          matrah = double.tryParse(
                cells[matrahIdx]
                    .replaceAll(RegExp(r'[^0-9,\.]'), '')
                    .replaceAll(',', '.'),
              ) ??
              0.0;
        }

        if (firma.isNotEmpty && matrah > 0) {
          final inv = FaturaModel(
            id: '${DateTime.now().millisecondsSinceEpoch}$i',
            firmaAdi: firma,
            adres: '',
            vergiDairesi: '',
            vergiNo: tc,
            tarih: '',
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
            parsedBy: 'Excel Toplu Aktarım',
          );
          _recalculateTotals(inv);
          newInvoices.add(inv);
        }
      }

      if (newInvoices.isEmpty) {
        throw Exception('Eşleşen satır bulunamadı veya veriler okunamadı.');
      }
      pendingInvoices = newInvoices;
      currentIndex = 0;
      seciliBirimByFaturaId.clear();
      _queueChanged();
    } else {
      await loadBatch(csvText);
    }
  }

  void _recalculateTotals(FaturaModel invoice) {
    double matrah = 0;
    for (var kalem in invoice.kalemler) {
      final miktar = double.tryParse(kalem['miktar'].toString()) ?? 0.0;
      final fiyat = double.tryParse(kalem['fiyat'].toString()) ?? 0.0;
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

  void addKalem(int index) {
    if (index < 0 || index >= pendingInvoices.length) return;
    pendingInvoices[index].kalemler.add({
      'cinsi': 'Yeni Kalem',
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

  Future<void> approveInvoice(int index, {bool validateRequired = true}) async {
    if (index < 0 || index >= pendingInvoices.length) return;
    final invoice = pendingInvoices[index];
    if (validateRequired) {
      _validateInvoice(invoice);
    }
    await _faturaService.saveFatura(invoice);
    await yukleArsivDurumu();
    final removedId = invoice.id;
    pendingInvoices.removeAt(index);
    seciliBirimByFaturaId.remove(removedId);
    if (pendingInvoices.isEmpty) _initializeEmpty();
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

    if (kaydedilenIdler.isNotEmpty) await yukleArsivDurumu();
    pendingInvoices.removeWhere((inv) {
      if (kaydedilenIdler.contains(inv.id)) {
        seciliBirimByFaturaId.remove(inv.id);
        return true;
      }
      return false;
    });
    if (pendingInvoices.isEmpty) _initializeEmpty();
    _queueChanged();
    return FaturaOnaySonucu(kaydedilen: kaydedilenIdler.length, hatalar: hatalar);
  }

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
      case 'irsaliyeNo':
        currentInvoice.irsaliyeNo = value.toString();
      case 'melbesNo':
        currentInvoice.melbesNo = value.toString();
      case 'numuneNo':
        currentInvoice.numuneNo = value.toString();
      case 'numuneAciklamasi':
        currentInvoice.numuneAciklamasi = value.toString();
      case 'matrah':
        currentInvoice.matrah =
            double.tryParse(value.toString()) ?? currentInvoice.matrah;
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
        currentInvoice.kdvOrani =
            double.tryParse(value.toString()) ?? currentInvoice.kdvOrani;
        _recalculateTotals(currentInvoice);
      case 'kdvTutari':
        if (!currentInvoice.isKdvMuaf) {
          currentInvoice.kdvTutari =
              double.tryParse(value.toString()) ?? currentInvoice.kdvTutari;
        }
      case 'genelToplam':
        currentInvoice.genelToplam =
            double.tryParse(value.toString()) ?? currentInvoice.genelToplam;
      case 'iban':
        currentInvoice.iban = value?.toString();
      case 'hesapAdi':
        currentInvoice.hesapAdi = value?.toString();
      case 'hizmetTipi':
        currentInvoice.hizmetTipi = value?.toString();
      case 'kursAdi':
        currentInvoice.kursAdi = value?.toString();
      case 'kurNo':
        currentInvoice.kurNo = value != null ? int.tryParse(value.toString()) : null;
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

  FaturaModel ornekFatura() {
    return FaturaModel(
      id: 'ornek',
      firmaAdi: FaturaMatbuConfig.ornekMetinler['firmaAdi']!,
      adres: FaturaMatbuConfig.ornekMetinler['adres']!,
      vergiDairesi: FaturaMatbuConfig.ornekMetinler['vergiDairesi']!,
      vergiNo: FaturaMatbuConfig.ornekMetinler['vkn']!,
      tarih: FaturaMatbuConfig.ornekMetinler['tarih']!,
      irsaliyeNo: FaturaMatbuConfig.ornekMetinler['irsaliyeNo']!,
      melbesNo: FaturaMatbuConfig.ornekMetinler['melbes']!,
      numuneNo: FaturaMatbuConfig.ornekMetinler['numuneNo']!,
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
      parsedBy: 'Kalibrasyon Testi',
    );
  }

  Future<void> matbuYazdir(FaturaModel invoice) async {
    final bytes = await generatePdf(invoice, includeBackground: false);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<Uint8List> generatePdf(
    FaturaModel invoice, {
    bool? includeBackground,
  }) async {
    final arkaPlanGoster = includeBackground ?? !matbuBaskiModu;

    try {
      final (fontRegular, fontBold) = await _pdfFontlari();
      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: fontRegular,
          bold: fontBold,
        ),
      );
      const int satirLimit = 10;

      pw.MemoryImage? bgImage;
      if (arkaPlanGoster) {
        final raw = await rootBundle.load('assets/images/fatura_sablon.jpeg');
        bgImage = pw.MemoryImage(raw.buffer.asUint8List());
      }

      final kalemler = List<Map<String, dynamic>>.from(invoice.kalemler);
      if (kalemler.isEmpty) {
        kalemler.add({
          'cinsi': invoice.numuneAciklamasi.isNotEmpty
              ? invoice.numuneAciklamasi
              : 'Hizmet Bedeli',
          'miktar': 1,
          'fiyat': invoice.matrah,
        });
      }

      final toplamSayfa = (kalemler.length / satirLimit).ceil().clamp(1, 9999);
      var oncekiSayfaToplam = 0.0;

      pw.TextStyle metin({pw.FontWeight? weight}) => pw.TextStyle(
            fontSize: matbuFontBoyutu,
            fontWeight: weight,
            font: weight == pw.FontWeight.bold ? fontBold : fontRegular,
          );

      for (var sayfaIndex = 0; sayfaIndex < toplamSayfa; sayfaIndex++) {
        final baslangic = sayfaIndex * satirLimit;
        final bitis = (baslangic + satirLimit > kalemler.length)
            ? kalemler.length
            : baslangic + satirLimit;
        final sayfaSatirlari = kalemler.sublist(baslangic, bitis);

        final sayfaToplami = sayfaSatirlari.fold<double>(0, (acc, item) {
          final fiyat = double.tryParse(item['fiyat'].toString()) ?? 0.0;
          final miktar = double.tryParse(item['miktar'].toString()) ?? 1.0;
          return acc + (fiyat * miktar);
        });
        final araToplam = oncekiSayfaToplam + sayfaToplami;
        final sonSayfa = sayfaIndex == toplamSayfa - 1;
        final ilkSayfa = sayfaIndex == 0;

        pdf.addPage(
          pw.Page(
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.zero,
              buildBackground: bgImage == null
                  ? null
                  : (context) => pw.FullPage(
                        ignoreMargins: true,
                        child: pw.Image(bgImage!, fit: pw.BoxFit.fill),
                      ),
            ),
            build: (context) {
              final children = <pw.Widget>[];

              if (ilkSayfa) {
                if (invoice.firmaAdi.trim().isNotEmpty) {
                  children.add(
                    pw.Positioned(
                      top: _konum('firmaAdi').dy,
                      left: _konum('firmaAdi').dx,
                      child: pw.SizedBox(
                        width: 270,
                        child: pw.Text(
                          invoice.firmaAdi,
                          style: metin(weight: pw.FontWeight.bold),
                        ),
                      ),
                    ),
                  );
                }
                if (invoice.adres.trim().isNotEmpty) {
                  children.add(
                    pw.Positioned(
                      top: _konum('adres').dy,
                      left: _konum('adres').dx,
                      child: pw.SizedBox(
                        width: 270,
                        child: pw.Text(invoice.adres, style: metin()),
                      ),
                    ),
                  );
                }
                if (invoice.vergiDairesi.trim().isNotEmpty) {
                  children.add(
                    pw.Positioned(
                      top: _konum('vergiDairesi').dy,
                      left: _konum('vergiDairesi').dx,
                      child: pw.Text(invoice.vergiDairesi, style: metin()),
                    ),
                  );
                }
                if (invoice.vergiNo.trim().isNotEmpty) {
                  children.add(
                    pw.Positioned(
                      top: _konum('vkn').dy,
                      left: _konum('vkn').dx,
                      child: pw.Text(invoice.vergiNo, style: metin()),
                    ),
                  );
                }
              }

              if (invoice.tarih.trim().isNotEmpty) {
                children.add(
                  pw.Positioned(
                    top: _konum('tarih').dy,
                    left: _konum('tarih').dx,
                    child: pw.Text(invoice.tarih, style: metin()),
                  ),
                );
              }
              if (invoice.irsaliyeNo.trim().isNotEmpty) {
                children.add(
                  pw.Positioned(
                    top: _konum('irsaliyeNo').dy,
                    left: _konum('irsaliyeNo').dx,
                    child: pw.Text(invoice.irsaliyeNo, style: metin()),
                  ),
                );
              }

              if (isNakliYekunAktif && oncekiSayfaToplam > 0) {
                children.addAll([
                  pw.Positioned(
                    top: _konum('nakliYekunUstYazi').dy,
                    left: _konum('nakliYekunUstYazi').dx,
                    child: pw.Text(
                      'Nakli Yekün (Önceki Sayfa)',
                      style: metin(weight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Positioned(
                    top: _konum('nakliYekunUstTutar').dy,
                    left: _konum('nakliYekunUstTutar').dx,
                    child: pw.Text(
                      TurkceFormat.ondalik(oncekiSayfaToplam),
                      style: metin(weight: pw.FontWeight.bold),
                    ),
                  ),
                ]);
              }

              for (final entry in sayfaSatirlari.asMap().entries) {
                final index = entry.key;
                final item = entry.value;
                final currentTop = _konum('cinsi').dy + (index * kalemSatirAraligi);
                final fiyat = double.tryParse(item['fiyat'].toString()) ?? 0.0;
                final miktar = double.tryParse(item['miktar'].toString()) ?? 1.0;
                final satirTutar = fiyat * miktar;

                children.addAll([
                  pw.Positioned(
                    top: currentTop,
                    left: _konum('cinsi').dx,
                    child: pw.Text('${item['cinsi']}', style: metin()),
                  ),
                  pw.Positioned(
                    top: currentTop,
                    left: _konum('miktar').dx,
                    child: pw.Text(
                      miktar == miktar.roundToDouble()
                          ? miktar.toInt().toString()
                          : TurkceFormat.ondalik(miktar),
                      style: metin(),
                    ),
                  ),
                  pw.Positioned(
                    top: currentTop,
                    left: _konum('fiyat').dx,
                    child: pw.Text(TurkceFormat.ondalik(fiyat), style: metin()),
                  ),
                  pw.Positioned(
                    top: currentTop,
                    left: _konum('tutar').dx,
                    child: pw.Text(TurkceFormat.ondalik(satirTutar), style: metin()),
                  ),
                ]);
              }

              if (isNakliYekunAktif && !sonSayfa) {
                children.addAll([
                  pw.Positioned(
                    top: _konum('nakliYekunAltYazi').dy,
                    left: _konum('nakliYekunAltYazi').dx,
                    child: pw.Text(
                      'Nakli Yekün (Devreden)',
                      style: metin(weight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Positioned(
                    top: _konum('nakliYekunAltTutar').dy,
                    left: _konum('nakliYekunAltTutar').dx,
                    child: pw.Text(
                      TurkceFormat.ondalik(araToplam),
                      style: metin(weight: pw.FontWeight.bold),
                    ),
                  ),
                ]);
              }

              if (sonSayfa) {
                final ustAciklamalar = [
                  if (invoice.numuneAciklamasi.trim().isNotEmpty) invoice.numuneAciklamasi,
                  if (invoice.aciklama != null && invoice.aciklama!.trim().isNotEmpty) invoice.aciklama!,
                  if (invoice.isKdvMuaf) 'KDV\'den Muaftır (İstisna)'
                ].join(' | ');

                if (ustAciklamalar.isNotEmpty) {
                  children.add(
                    pw.Positioned(
                      top: _konum('numuneAciklama').dy,
                      left: _konum('numuneAciklama').dx,
                      child: pw.Text(ustAciklamalar, style: metin()),
                    ),
                  );
                }
                if (invoice.melbesNo.trim().isNotEmpty) {
                  children.add(
                    pw.Positioned(
                      top: _konum('melbes').dy,
                      left: _konum('melbes').dx,
                      child: pw.Text(invoice.melbesNo, style: metin()),
                    ),
                  );
                }
                if (invoice.numuneNo.trim().isNotEmpty) {
                  children.add(
                    pw.Positioned(
                      top: _konum('numuneNo').dy,
                      left: _konum('numuneNo').dx,
                      child: pw.Text(invoice.numuneNo, style: metin()),
                    ),
                  );
                }
                children.addAll([
                  pw.Positioned(
                    top: _konum('matrah').dy,
                    left: _konum('matrah').dx,
                    child: pw.Text(TurkceFormat.ondalik(invoice.matrah), style: metin()),
                  ),
                  pw.Positioned(
                    top: _konum('kdv').dy,
                    left: _konum('kdv').dx,
                    child: pw.Text(
                      TurkceFormat.ondalik(invoice.kdvTutari),
                      style: metin(),
                    ),
                  ),
                  pw.Positioned(
                    top: _konum('genelToplam').dy,
                    left: _konum('genelToplam').dx,
                    child: pw.Text(
                      TurkceFormat.ondalik(invoice.genelToplam),
                      style: metin(weight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Positioned(
                    top: _konum('yaziylaTutar').dy,
                    left: _konum('yaziylaTutar').dx,
                    child: pw.SizedBox(
                      width: 420,
                      child: pw.Text(
                        _sayiyiYaziyaCevir(invoice.genelToplam),
                        style: metin(),
                      ),
                    ),
                  ),
                ]);

                final hesapAdiHam = (invoice.hesapAdi?.trim().isNotEmpty == true)
                    ? invoice.hesapAdi!
                    : (sistemAyarlari?.hesapAdi ?? '');
                final hesapAdi =
                    FaturaMatbuConfig.formatHesapAdiMatbu(hesapAdiHam);
                if (hesapAdi.isNotEmpty) {
                  children.add(
                    pw.Positioned(
                      top: _konum('hesapAdi').dy,
                      left: _konum('hesapAdi').dx,
                      child: pw.Text(hesapAdi, style: metin()),
                    ),
                  );
                }

                final iban = (invoice.iban?.trim().isNotEmpty == true)
                    ? invoice.iban!
                    : (sistemAyarlari?.iban ?? '');
                if (iban.isNotEmpty) {
                  children.add(
                    pw.Positioned(
                      top: _konum('iban').dy,
                      left: _konum('iban').dx,
                      child: pw.Text(iban, style: metin()),
                    ),
                  );
                }
              }

              // Sayfa numarası: çok sayfalıysa her zaman göster (matbu modda da).
              if (toplamSayfa > 1) {
                children.add(
                  pw.Positioned(
                    top: 20,
                    right: 20,
                    child: pw.Text(
                      'Sayfa ${sayfaIndex + 1}/$toplamSayfa',
                      style: metin(weight: pw.FontWeight.bold),
                    ),
                  ),
                );
              }

              return pw.Stack(children: children);
            },
          ),
        );
        oncekiSayfaToplam = araToplam;
      }

      return pdf.save();
    } catch (e) {
      debugPrint('PDF Oluşturma Hatası: $e');
      final errDoc = pw.Document();
      errDoc.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Text('PDF oluşturulamadı: $e'),
          ),
        ),
      );
      return errDoc.save();
    }
  }

  String _sayiyiYaziyaCevir(double tutar) {
    if (tutar == 0) return 'SIFIR TÜRK LİRASI SIFIR KURUŞTUR.';

    final parts = tutar.toStringAsFixed(2).split('.');
    final lira = int.parse(parts[0]);
    final kurus = int.parse(parts[1]);

    final liraYazi = lira == 0 ? 'SIFIR' : _convertNumberToWords(lira);
    final kurusYazi = kurus == 0 ? 'SIFIR' : _convertNumberToWords(kurus);

    return '$liraYazi TÜRK LİRASI $kurusYazi KURUŞTUR.';
  }

  String _convertNumberToWords(int number) {
    const birler = [
      '',
      'BİR',
      'İKİ',
      'ÜÇ',
      'DÖRT',
      'BEŞ',
      'ALTI',
      'YEDİ',
      'SEKİZ',
      'DOKUZ',
    ];
    const onlar = [
      '',
      'ON',
      'YİRMİ',
      'OTUZ',
      'KIRK',
      'ELLİ',
      'ALTMIŞ',
      'YETMİŞ',
      'SEKSEN',
      'DOKSAN',
    ];
    const binler = ['', 'BİN', 'MİLYON', 'MİLYAR'];

    if (number == 0) return 'SIFIR';

    var result = '';
    var groupIndex = 0;
    var n = number;

    while (n > 0) {
      final group = n % 1000;
      if (group > 0) {
        var groupText = '';
        final yuzler = group ~/ 100;
        final onlarBasamagi = (group % 100) ~/ 10;
        final birlerBasamagi = group % 10;

        if (yuzler > 0) {
          groupText += yuzler == 1 ? 'YÜZ ' : '${birler[yuzler]} YÜZ ';
        }
        if (onlarBasamagi > 0) {
          groupText += '${onlar[onlarBasamagi]} ';
        }
        if (birlerBasamagi > 0 && !(groupIndex == 1 && group == 1)) {
          groupText += '${birler[birlerBasamagi]} ';
        }
        groupText += '${binler[groupIndex]} ';
        result = groupText + result;
      }
      n ~/= 1000;
      groupIndex++;
    }

    return result.trim().replaceAll('  ', ' ');
  }
}
