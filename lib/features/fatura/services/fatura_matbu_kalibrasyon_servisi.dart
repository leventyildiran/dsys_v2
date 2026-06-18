import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../models/fatura_matbu_kalibrasyon.dart';

/// Matbu kalibrasyon: önce Firestore (kurumsal), yedek SharedPreferences (tarayıcı).
class FaturaMatbuKalibrasyonServisi {
  FaturaMatbuKalibrasyonServisi({
    SistemAyarlariService? sistemAyarlariService,
  }) : _sistemAyarlari = sistemAyarlariService ?? SistemAyarlariService();

  final SistemAyarlariService _sistemAyarlari;

  static const _prefsSurumKey = 'fatura_matbu_kalibrasyon_surum';

  Future<FaturaMatbuKalibrasyon?> yukleFirestore() async {
    try {
      final doc = await _sistemAyarlari.getHamAlan('matbuKalibrasyon');
      if (doc == null || doc.isEmpty) return null;
      return FaturaMatbuKalibrasyon.fromMap(doc).normalize();
    } catch (e) {
      debugPrint('Matbu kalibrasyon Firestore okunamadı: $e');
      return null;
    }
  }

  Future<void> kaydetFirestore(FaturaMatbuKalibrasyon ayar) async {
    await _sistemAyarlari.kaydetHamAlan(
      'matbuKalibrasyon',
      ayar.normalize().toMap(),
    );
  }

  Future<FaturaMatbuKalibrasyon> yukleYerel() async {
    final prefs = await SharedPreferences.getInstance();
    final varsayilan = FaturaMatbuKalibrasyon.varsayilan();
    final koordinatlar = Map<String, Offset>.from(varsayilan.koordinatlar);

    for (final key in koordinatlar.keys) {
      final dx = prefs.getDouble('${key}_dx');
      final dy = prefs.getDouble('${key}_dy');
      if (dx != null && dy != null) {
        koordinatlar[key] = Offset(dx, dy);
      }
    }

    final surum = prefs.getInt(_prefsSurumKey) ?? 0;
    return FaturaMatbuKalibrasyon(
      surum: surum,
      koordinatlar: koordinatlar,
      kalemSatirAraligi: prefs.getDouble('fatura_kalem_satir_araligi') ??
          varsayilan.kalemSatirAraligi,
      fontBoyutu: prefs.getDouble('fatura_matbu_font_boyutu') ??
          varsayilan.fontBoyutu,
      globalOffsetDx: prefs.getDouble('fatura_global_offset_dx') ?? 0,
      globalOffsetDy: prefs.getDouble('fatura_global_offset_dy') ?? 0,
      matbuBaskiModu: prefs.getBool('fatura_matbu_baski_modu') ?? true,
    ).normalize();
  }

  Future<void> kaydetYerel(FaturaMatbuKalibrasyon ayar) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = ayar.normalize();

    for (final entry in normalized.koordinatlar.entries) {
      await prefs.setDouble('${entry.key}_dx', entry.value.dx);
      await prefs.setDouble('${entry.key}_dy', entry.value.dy);
    }
    await prefs.setInt(_prefsSurumKey, FaturaMatbuKalibrasyon.guncelSurum);
    await prefs.setDouble(
      'fatura_kalem_satir_araligi',
      normalized.kalemSatirAraligi,
    );
    await prefs.setDouble('fatura_matbu_font_boyutu', normalized.fontBoyutu);
    await prefs.setDouble('fatura_global_offset_dx', normalized.globalOffsetDx);
    await prefs.setDouble('fatura_global_offset_dy', normalized.globalOffsetDy);
    await prefs.setBool('fatura_matbu_baski_modu', normalized.matbuBaskiModu);
  }

  Future<void> temizleYerel() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = FaturaMatbuKalibrasyon.varsayilan().koordinatlar.keys;
    for (final key in keys) {
      await prefs.remove('${key}_dx');
      await prefs.remove('${key}_dy');
    }
    await prefs.remove(_prefsSurumKey);
    await prefs.remove('fatura_kalem_satir_araligi');
    await prefs.remove('fatura_matbu_font_boyutu');
    await prefs.remove('fatura_global_offset_dx');
    await prefs.remove('fatura_global_offset_dy');
    await prefs.remove('fatura_matbu_baski_modu');
  }
}
