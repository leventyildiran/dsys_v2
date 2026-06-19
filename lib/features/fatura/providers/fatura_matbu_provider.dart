import 'dart:async';

import 'package:flutter/material.dart';

import '../models/fatura_matbu_config.dart';
import '../models/fatura_matbu_kalibrasyon.dart';
import '../services/fatura_matbu_kalibrasyon_servisi.dart';

/// Matbu (ön basılı form) kalibrasyon ve koordinat yönetimi.
///
/// Sorumlulukları:
/// - `coordinates`, `globalOffset`, `fontBoyutu`, `satirAraligi` state
/// - Kalibrasyon ayarlarının Firestore + SharedPreferences ile yüklenmesi/kaydedilmesi
/// - Koordinat güncelleme (sürükleme, nudge, _kalemSenkronDelta)
/// - Matbu baskı modu toggle
/// - Nakli Yekün global toggle
///
/// Kuyruk state (pendingInvoices, currentIndex) bağımlılığı **yoktur**.
/// Kuyruk + kalibrasyon kesişen metotlar (`kalibrasyonFaturasi` vb.)
/// `BatchFaturaProvider`'da kalır ve her iki providere delegasyon yapar.
class FaturaMatbuProvider extends ChangeNotifier {
  // ── Matbu State ──────────────────────────────────────────

  /// Matbu kağıt üzerine basım: arka plan kapalı (sadece metin).
  bool matbuBaskiModu = true;

  double kalemSatirAraligi = FaturaMatbuConfig.varsayilanKalemSatirAraligi;
  double matbuFontBoyutu = FaturaMatbuConfig.varsayilanFontBoyutu;
  double globalOffsetDx = 0;
  double globalOffsetDy = 0;

  /// Global Nakli Yekün aktif/pasif (tüm faturalar).
  bool isNakliYekunAktif = false;

  Map<String, Offset> coordinates = FaturaMatbuConfig.varsayilanKoordinatlar();

  // ── Servisler ───────────────────────────────────────────
  final FaturaMatbuKalibrasyonServisi _matbuKalibrasyonServisi =
      FaturaMatbuKalibrasyonServisi();

  // ── Timer (debounced save) ──────────────────────────────
  Timer? _matbuAyarKaydetTimer;

  // ─────────────────────────────────────────────────────────
  // Constructor & Initialization
  // ─────────────────────────────────────────────────────────

  FaturaMatbuProvider() {
    unawaited(_loadMatbuAyarlari());
  }

  // ─────────────────────────────────────────────────────────
  // Coordinate Helpers
  // ─────────────────────────────────────────────────────────

  /// Global offset uygulanmış koordinat.
  Offset konum(String key) {
    final base = coordinates[key] ?? Offset.zero;
    return Offset(base.dx + globalOffsetDx, base.dy + globalOffsetDy);
  }

  void updateCoordinate(String key, Offset newOffset, {bool notify = true}) {
    coordinates[key] = Offset(
      newOffset.dx - globalOffsetDx,
      newOffset.dy - globalOffsetDy,
    );
    if (notify) {
      notifyListeners();
      _scheduleMatbuAyarKaydet();
    }
  }

  /// Sürükleme sırasında delta uygular (notify=false ile kasma önlenir).
  void updateCoordinateDelta(String key, Offset delta, {bool notify = true}) {
    final current = coordinates[key];
    if (current == null) return;
    coordinates[key] = Offset(current.dx + delta.dx, current.dy + delta.dy);
    if (notify) {
      notifyListeners();
      _scheduleMatbuAyarKaydet();
    }
  }

  void nudgeCoordinate(String key, double dx, double dy) {
    _kalemSenkronDelta(key, Offset(dx, dy));
  }

  /// Kalibrasyon sürükleme: kalem sütunları dikeyde birlikte hareket eder.
  void calibrationDragDelta(String key, Offset delta, {bool notify = true}) {
    _kalemSenkronDelta(key, delta, notify: notify);
  }

  void _kalemSenkronDelta(String key, Offset delta, {bool notify = true}) {
    const kalemKeys = FaturaMatbuKalibrasyon.kalemSutunlari;
    if (kalemKeys.contains(key)) {
      if (delta.dy != 0) {
        for (final k in kalemKeys) {
          updateCoordinateDelta(k, Offset(0, delta.dy), notify: false);
        }
      }
      if (delta.dx != 0) {
        updateCoordinateDelta(key, Offset(delta.dx, 0), notify: false);
      }
      FaturaMatbuKalibrasyon.senkronizeKalemDy(coordinates);
      if (notify) {
        notifyListeners();
        _scheduleMatbuAyarKaydet();
      }
      return;
    }
    updateCoordinateDelta(key, delta, notify: notify);
  }

  // ─────────────────────────────────────────────────────────
  // Calibration State (internal)
  // ─────────────────────────────────────────────────────────

  FaturaMatbuKalibrasyon _mevcutKalibrasyon() {
    return FaturaMatbuKalibrasyon(
      surum: FaturaMatbuKalibrasyon.guncelSurum,
      koordinatlar: Map<String, Offset>.from(coordinates),
      kalemSatirAraligi: kalemSatirAraligi,
      fontBoyutu: matbuFontBoyutu,
      globalOffsetDx: globalOffsetDx,
      globalOffsetDy: globalOffsetDy,
      matbuBaskiModu: matbuBaskiModu,
    );
  }

  void _kalibrasyonUygula(FaturaMatbuKalibrasyon ayar) {
    coordinates = Map<String, Offset>.from(ayar.koordinatlar);
    FaturaMatbuKalibrasyon.senkronizeKalemDy(coordinates);
    kalemSatirAraligi = ayar.kalemSatirAraligi;
    matbuFontBoyutu = ayar.fontBoyutu;
    globalOffsetDx = ayar.globalOffsetDx;
    globalOffsetDy = ayar.globalOffsetDy;
    matbuBaskiModu = ayar.matbuBaskiModu;
  }

  // ─────────────────────────────────────────────────────────
  // Property Setters
  // ─────────────────────────────────────────────────────────

  void setKalemSatirAraligi(double value) {
    kalemSatirAraligi = value;
    notifyListeners();
    _scheduleMatbuAyarKaydet();
  }

  void setMatbuFontBoyutu(double value) {
    matbuFontBoyutu = value;
    notifyListeners();
    _scheduleMatbuAyarKaydet();
  }

  void setGlobalOffset(double dx, double dy) {
    globalOffsetDx = dx;
    globalOffsetDy = dy;
    notifyListeners();
    _scheduleMatbuAyarKaydet();
  }

  void setMatbuBaskiModu(bool value) {
    matbuBaskiModu = value;
    notifyListeners();
    _scheduleMatbuAyarKaydet();
  }

  void toggleNakliYekunGlobal(bool value) {
    isNakliYekunAktif = value;
    notifyListeners();
    _scheduleMatbuAyarKaydet();
  }

  // ─────────────────────────────────────────────────────────
  // Persistence
  // ─────────────────────────────────────────────────────────

  Future<void> saveMatbuAyarlari() async {
    final ayar = _mevcutKalibrasyon().normalize();
    try {
      await _matbuKalibrasyonServisi.kaydetFirestore(ayar);
    } catch (e) {
      debugPrint('Matbu kalibrasyon Firestore kaydı başarısız: $e');
    }
    await _matbuKalibrasyonServisi.kaydetYerel(ayar);
  }

  Future<void> saveCoordinates() => saveMatbuAyarlari();

  Future<void> _loadMatbuAyarlari() async {
    FaturaMatbuKalibrasyon? ayar =
        await _matbuKalibrasyonServisi.yukleFirestore();
    ayar ??= await _matbuKalibrasyonServisi.yukleYerel();
    _kalibrasyonUygula(ayar.normalize());
    notifyListeners();
  }

  Future<void> resetCoordinates() async {
    await _matbuKalibrasyonServisi.temizleYerel();
    final varsayilan = FaturaMatbuKalibrasyon.varsayilan();
    _kalibrasyonUygula(varsayilan);
    try {
      await _matbuKalibrasyonServisi.kaydetFirestore(varsayilan);
    } catch (e) {
      debugPrint('Matbu varsayılan Firestore kaydı başarısız: $e');
    }
    notifyListeners();
  }

  void _scheduleMatbuAyarKaydet() {
    _matbuAyarKaydetTimer?.cancel();
    _matbuAyarKaydetTimer =
        Timer(const Duration(milliseconds: 400), () {
      unawaited(saveMatbuAyarlari());
    });
  }

  // ─────────────────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────────────────

  @override
  void dispose() {
    _matbuAyarKaydetTimer?.cancel();
    super.dispose();
  }
}
