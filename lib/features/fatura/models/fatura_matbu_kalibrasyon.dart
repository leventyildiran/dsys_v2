import 'package:flutter/material.dart';
import 'fatura_matbu_config.dart';

/// Matbu A4 kalibrasyon ayarları — Firestore + yerel yedek.
class FaturaMatbuKalibrasyon {
  FaturaMatbuKalibrasyon({
    required this.surum,
    required this.koordinatlar,
    required this.kalemSatirAraligi,
    required this.fontBoyutu,
    required this.globalOffsetDx,
    required this.globalOffsetDy,
    required this.matbuBaskiModu,
    required this.satirLimit,
    required this.nakliYekunUstMetin,
    required this.nakliYekunAltMetin,
  });

  /// Şema değişince artırılır; eski kayıtlar varsayılanlarla birleştirilir.
  static const int guncelSurum = 5;

  static const kalemSutunlari = {'cinsi', 'miktar', 'fiyat', 'tutar'};

  /// PDF'te basılmayan; kalibrasyon listesinde gösterilmez.
  static const gizliAlanlar = <String>{};

  /// Kalem satırında dikey konum hep cinsi satırından; PDF ile aynı.
  static void senkronizeKalemDy(Map<String, Offset> koordinatlar) {
    final cinsi = koordinatlar['cinsi'];
    if (cinsi == null) return;
    for (final key in kalemSutunlari) {
      if (key == 'cinsi') continue;
      final mevcut = koordinatlar[key];
      if (mevcut == null) continue;
      koordinatlar[key] = Offset(mevcut.dx, cinsi.dy);
    }
  }

  final int surum;
  final Map<String, Offset> koordinatlar;
  final double kalemSatirAraligi;
  final double fontBoyutu;
  final double globalOffsetDx;
  final double globalOffsetDy;
  final bool matbuBaskiModu;
  final int satirLimit;
  final String nakliYekunUstMetin;
  final String nakliYekunAltMetin;

  factory FaturaMatbuKalibrasyon.varsayilan() {
    return FaturaMatbuKalibrasyon(
      surum: guncelSurum,
      koordinatlar: FaturaMatbuConfig.varsayilanKoordinatlar(),
      kalemSatirAraligi: FaturaMatbuConfig.varsayilanKalemSatirAraligi,
      fontBoyutu: FaturaMatbuConfig.varsayilanFontBoyutu,
      globalOffsetDx: 0,
      globalOffsetDy: 0,
      matbuBaskiModu: true,
      satirLimit: FaturaMatbuConfig.varsayilanSatirLimit,
      nakliYekunUstMetin: 'Nakli Yekün (Devreden)',
      nakliYekunAltMetin: 'Nakli Yekün (Devreden)',
    );
  }

  factory FaturaMatbuKalibrasyon.fromMap(Map<String, dynamic> map) {
    final varsayilan = FaturaMatbuKalibrasyon.varsayilan();
    final hamKoord = map['koordinatlar'] as Map<String, dynamic>? ?? {};
    final koordinatlar = Map<String, Offset>.from(varsayilan.koordinatlar);

    for (final entry in hamKoord.entries) {
      final v = entry.value;
      if (v is Map) {
        final dx = (v['dx'] as num?)?.toDouble();
        final dy = (v['dy'] as num?)?.toDouble();
        if (dx != null && dy != null) {
          koordinatlar[entry.key] = Offset(dx, dy);
        }
      }
    }

    FaturaMatbuKalibrasyon.senkronizeKalemDy(koordinatlar);

    return FaturaMatbuKalibrasyon(
      surum: (map['surum'] as num?)?.toInt() ?? 0,
      koordinatlar: koordinatlar,
      kalemSatirAraligi:
          (map['kalemSatirAraligi'] as num?)?.toDouble() ??
          varsayilan.kalemSatirAraligi,
      fontBoyutu:
          (map['fontBoyutu'] as num?)?.toDouble() ?? varsayilan.fontBoyutu,
      globalOffsetDx:
          (map['globalOffsetDx'] as num?)?.toDouble() ?? 0,
      globalOffsetDy:
          (map['globalOffsetDy'] as num?)?.toDouble() ?? 0,
      matbuBaskiModu: map['matbuBaskiModu'] as bool? ?? true,
      satirLimit: (map['satirLimit'] as num?)?.toInt() ??
          varsayilan.satirLimit,
      nakliYekunUstMetin: map['nakliYekunUstMetin'] as String? ?? 'Nakli Yekün (Devreden)',
      nakliYekunAltMetin: map['nakliYekunAltMetin'] as String? ?? 'Nakli Yekün (Devreden)',
    );
  }

  /// Eski şema kayıtlarını güncel varsayılanlarla birleştirir.
  FaturaMatbuKalibrasyon normalize() {
    final varsayilan = FaturaMatbuKalibrasyon.varsayilan();
    final birlesik = Map<String, Offset>.from(varsayilan.koordinatlar);

    for (final entry in koordinatlar.entries) {
      if (gizliAlanlar.contains(entry.key)) continue;
      birlesik[entry.key] = entry.value;
    }

    if (surum < guncelSurum) {
      // Yeni eklenen veya yeniden konumlanan üst-sağ alanlar varsayılanla güncellenir.
      for (final key in ['tarih', 'irsaliyeTarihi', 'irsaliyeNo']) {
        birlesik[key] = varsayilan.koordinatlar[key]!;
      }
    }

    FaturaMatbuKalibrasyon.senkronizeKalemDy(birlesik);

    return FaturaMatbuKalibrasyon(
      surum: guncelSurum,
      koordinatlar: birlesik,
      kalemSatirAraligi: kalemSatirAraligi,
      fontBoyutu: fontBoyutu,
      globalOffsetDx: globalOffsetDx,
      globalOffsetDy: globalOffsetDy,
      matbuBaskiModu: matbuBaskiModu,
      satirLimit: satirLimit,
      nakliYekunUstMetin: nakliYekunUstMetin,
      nakliYekunAltMetin: nakliYekunAltMetin,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'surum': guncelSurum,
      'kalemSatirAraligi': kalemSatirAraligi,
      'fontBoyutu': fontBoyutu,
      'globalOffsetDx': globalOffsetDx,
      'globalOffsetDy': globalOffsetDy,
      'matbuBaskiModu': matbuBaskiModu,
      'satirLimit': satirLimit,
      'nakliYekunUstMetin': nakliYekunUstMetin,
      'nakliYekunAltMetin': nakliYekunAltMetin,
      'koordinatlar': {
        for (final e in koordinatlar.entries)
          if (!gizliAlanlar.contains(e.key))
            e.key: {'dx': e.value.dx, 'dy': e.value.dy},
      },
    };
  }

  bool kalibrasyondaGoster(String alan) => !gizliAlanlar.contains(alan);
}
