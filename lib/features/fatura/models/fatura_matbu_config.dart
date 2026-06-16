import 'package:flutter/material.dart';

/// Matbu A4 fatura alan etiketleri ve varsayılan koordinatları.
class FaturaMatbuConfig {
  FaturaMatbuConfig._();

  static const double a4Genislik = 595;
  static const double a4Yukseklik = 842;
  static const double varsayilanFontBoyutu = 10.0;
  static const double varsayilanKalemSatirAraligi = 18.0;

  static const Map<String, String> alanEtiketleri = {
    'firmaAdi': 'Firma Adı',
    'adres': 'Adres',
    'vergiDairesi': 'Vergi Dairesi',
    'vkn': 'VKN / TC',
    'tarih': 'Tarih',
    'irsaliyeNo': 'İrsaliye No',
    'cinsi': 'Kalem — Cinsi',
    'miktar': 'Kalem — Miktar',
    'fiyat': 'Kalem — Fiyat',
    'tutar': 'Kalem — Tutar',
    'nakliYekunUstYazi': 'Nakli Yekün (Üst)',
    'nakliYekunUstTutar': 'Nakli Yekün Tutar (Üst)',
    'nakliYekunAltYazi': 'Nakli Yekün (Alt)',
    'nakliYekunAltTutar': 'Nakli Yekün Tutar (Alt)',
    'numuneAciklama': 'Numune Açıklaması',
    'melbes': 'MELBES No',
    'numuneNo': 'Numune No',
    'matrah': 'Matrah',
    'kdv': 'KDV Tutarı',
    'genelToplam': 'Genel Toplam',
    'yaziylaTutar': 'Yazıyla Tutar',
    'hesapAdi': 'Hesap Adı',
    'iban': 'IBAN',
  };

  static const Map<String, String> ornekMetinler = {
    'firmaAdi': 'ÖRNEK TEST A.Ş.',
    'adres': 'Merkez Mah. Test Sok. No:1 Ankara',
    'vergiDairesi': 'Çankaya',
    'vkn': '1234567890',
    'tarih': '07.06.2026',
    'irsaliyeNo': 'IRS-2026/001',
    'cinsi': 'Analiz Hizmet Bedeli',
    'miktar': '1',
    'fiyat': '1.500,00',
    'tutar': '1.500,00',
    'nakliYekunUstYazi': 'Nakli Yekün',
    'nakliYekunUstTutar': '750,00',
    'nakliYekunAltYazi': 'Nakli Yekün (Devreden)',
    'nakliYekunAltTutar': '750,00',
    'numuneAciklama': 'Su numunesi — klor analizi',
    'melbes': 'MEL-2026-0042',
    'numuneNo': 'N-1087',
    'matrah': '1.500,00',
    'kdv': '300,00',
    'genelToplam': '1.800,00',
    'yaziylaTutar': 'BİN SEKİZ YÜZ TÜRK LİRASI SIFIR KURUŞTUR.',
    'hesapAdi': 'Ankara Üniversitesi UBATAM\n(VKN:1234567890)',
    'iban': 'TR00 0000 0000 0000 0000 0000 00',
  };

  /// Matbu faturada işletme hesabı: birim adı üst satır, birim VKN alt satır.
  static String formatHesapAdiMatbu(String raw) {
    final trimmed = raw.replaceAll('\r\n', '\n').trim();
    if (trimmed.isEmpty) return trimmed;

    final lines = trimmed
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.length >= 2) {
      final vknSatir = _normalizeVknSatir(lines.sublist(1).join(' '));
      if (vknSatir != null) {
        return '${lines.first}\n$vknSatir';
      }
      return trimmed;
    }

    final vknBlok = RegExp(
      r'\s*\(VKN\s*:.*\)\s*$',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (vknBlok != null) {
      final ad = trimmed.substring(0, vknBlok.start).trim();
      final vknSatir = vknBlok.group(0)!.trim();
      if (ad.isNotEmpty) return '$ad\n$vknSatir';
    }

    return trimmed;
  }

  static String? _normalizeVknSatir(String line) {
    final t = line.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^\(VKN\s*:', caseSensitive: false).hasMatch(t)) return t;
    if (RegExp(r'^VKN\s*:', caseSensitive: false).hasMatch(t)) return '($t)';
    return null;
  }

  static Map<String, Offset> varsayilanKoordinatlar() => {
        'firmaAdi': const Offset(45, 135),
        'adres': const Offset(45, 155),
        'vergiDairesi': const Offset(145, 275),
        'vkn': const Offset(145, 295),
        'tarih': const Offset(470, 270),
        'irsaliyeNo': const Offset(470, 295),
        'cinsi': const Offset(50, 360),
        'miktar': const Offset(320, 360),
        'fiyat': const Offset(380, 360),
        'tutar': const Offset(510, 360),
        'nakliYekunUstYazi': const Offset(270, 340),
        'nakliYekunUstTutar': const Offset(510, 340),
        'nakliYekunAltYazi': const Offset(270, 580),
        'nakliYekunAltTutar': const Offset(510, 580),
        'numuneAciklama': const Offset(50, 600),
        'melbes': const Offset(50, 620),
        'numuneNo': const Offset(50, 640),
        'matrah': const Offset(470, 675),
        'kdv': const Offset(470, 705),
        'genelToplam': const Offset(470, 735),
        'yaziylaTutar': const Offset(90, 785),
        'hesapAdi': const Offset(90, 805),
        'iban': const Offset(90, 825),
      };
}
