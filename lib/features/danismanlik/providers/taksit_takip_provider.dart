import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/taksit_takip_kayit.dart';
import '../models/taksit_model.dart';
import '../providers/danismanlik_detay_provider.dart';
import '../services/taksit_onay_akisi.dart';
import '../services/taksit_service.dart';
import '../services/taksit_takip_service.dart';
import '../services/danismanlik_service.dart';

/// Konsolide taksit takip state yönetimi.
class TaksitTakipProvider extends ChangeNotifier {
  TaksitTakipProvider({
    TaksitTakipService? takipService,
    TaksitService? taksitService,
    DanismanlikService? danismanlikService,
  })  : _takipService = takipService ?? TaksitTakipService(),
        _taksitService = taksitService ?? TaksitService(),
        _danismanlikService = danismanlikService ?? DanismanlikService() {
    _abonelik = _takipService.streamKayitlar().listen(
      (kayitlar) {
        _kayitlar = kayitlar;
        _isLoading = false;
        notifyListeners();
      },
      onError: (e) {
        _hata = 'Taksitler yüklenemedi: $e';
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  final TaksitTakipService _takipService;
  final TaksitService _taksitService;
  final DanismanlikService _danismanlikService;

  StreamSubscription<List<TaksitTakipKayit>>? _abonelik;

  List<TaksitTakipKayit> _kayitlar = [];
  List<TaksitTakipKayit> get kayitlar => _kayitlar;

  TaksitDurum? _filtre;
  TaksitDurum? get filtre => _filtre;

  String _arama = '';
  String get arama => _arama;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  String? _hata;
  String? get hata => _hata;

  String? _basari;
  String? get basari => _basari;

  TaksitTakipIstatistik get istatistik => TaksitTakipIstatistik.hesapla(_kayitlar);

  List<TaksitTakipKayit> get filtrelenmis {
    final q = _arama.trim().toLowerCase();
    return _kayitlar.where((k) {
      final durumUyar = _filtre == null || k.taksit.durum == _filtre;
      final aramaUyar = q.isEmpty ||
          k.firmaEtiket.toLowerCase().contains(q) ||
          k.birimEtiket.toLowerCase().contains(q) ||
          k.danismanlik.konusu.toLowerCase().contains(q);
      return durumUyar && aramaUyar;
    }).toList()
      ..sort(_oncelikSirala);
  }

  List<TaksitTakipKayit> get oncelikliKayitlar {
    return _kayitlar
        .where((k) =>
            k.taksit.durum == TaksitDurum.gecikti ||
            k.taksit.durum == TaksitDurum.ykGundeminde ||
            k.taksit.durum == TaksitDurum.merkezOnayinda)
        .toList()
      ..sort(_oncelikSirala);
  }

  void filtreDegistir(TaksitDurum? durum) {
    _filtre = durum;
    notifyListeners();
  }

  void aramaDegistir(String value) {
    _arama = value;
    notifyListeners();
  }

  int _oncelikSirala(TaksitTakipKayit a, TaksitTakipKayit b) {
    final oa = _durumOnceligi(a.taksit.durum);
    final ob = _durumOnceligi(b.taksit.durum);
    if (oa != ob) return oa.compareTo(ob);
    return a.taksit.ayNo.compareTo(b.taksit.ayNo);
  }

  int _durumOnceligi(TaksitDurum durum) {
    switch (durum) {
      case TaksitDurum.gecikti:
        return 0;
      case TaksitDurum.ykGundeminde:
        return 1;
      case TaksitDurum.merkezOnayinda:
        return 2;
      case TaksitDurum.mudurOnayinda:
        return 3;
      case TaksitDurum.taslak:
        return 4;
      case TaksitDurum.onaylandi:
        return 5;
      case TaksitDurum.odendi:
        return 6;
    }
  }

  void mesajlariTemizle() {
    _hata = null;
    _basari = null;
    notifyListeners();
  }

  /// Taksiti bir sonraki onay adımına taşır.
  Future<bool> durumIlerlet(TaksitTakipKayit kayit) async {
    final hedef = TaksitOnayAkisi.sonrakiDurum(kayit.taksit.durum);
    if (hedef == null) return false;
    return _durumDegistir(kayit, hedef);
  }

  Future<bool> durumGeriAl(TaksitTakipKayit kayit) async {
    final hedef = TaksitOnayAkisi.oncekiDurum(kayit.taksit.durum);
    if (hedef == null) return false;
    return _durumDegistir(kayit, hedef);
  }

  Future<bool> _durumDegistir(TaksitTakipKayit kayit, TaksitDurum hedef) async {
    if (!TaksitOnayAkisi.gecisUygunMu(kayit.taksit.durum, hedef)) {
      _hata = 'Geçersiz durum geçişi.';
      notifyListeners();
      return false;
    }

    _isProcessing = true;
    _hata = null;
    _basari = null;
    notifyListeners();

    try {
      if (hedef == TaksitDurum.onaylandi) {
        final danismanlik = await _danismanlikService.getById(kayit.danismanlikId);
        if (danismanlik == null) {
          _hata = 'Danışmanlık bulunamadı.';
          return false;
        }
        final detay = DanismanlikDetayProvider(danismanlik);
        try {
          await detay.dagitimiHesaplaVeKaydet(
            kayit.taksit,
            DanismanlikDetayProvider.guncelIslemAyi(),
            true,
          );
          if (detay.error != null) {
            _hata = detay.error;
            return false;
          }
          _basari = 'Taksit onaylandı, dağıtım hesaplandı ve YK arşivine gönderildi.';
        } finally {
          detay.dispose();
        }
      } else if (hedef == TaksitDurum.odendi) {
        await _taksitService.updateDurum(kayit.danismanlikId, kayit.taksit.id, hedef);
        _basari = 'Taksit ödendi olarak işaretlendi.';
      } else {
        await _taksitService.updateDurum(kayit.danismanlikId, kayit.taksit.id, hedef);
        _basari = 'Durum "${hedef.displayName}" olarak güncellendi.';
      }
      return true;
    } catch (e) {
      _hata = 'İşlem hatası: $e';
      return false;
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _abonelik?.cancel();
    _takipService.cacheTemizle();
    super.dispose();
  }
}
