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
    'melbes': 'Çevre Şehircilik ve İklim Değişikliği Bakanlığı Melbes Başvuru No: MEL-2026-0042 Numune No: N-1087',
    'numuneNo': 'Numune No: N-1087',
    'matrah': '1.500,00',
    'kdv': '300,00',
    'genelToplam': '1.800,00',
    'yaziylaTutar': 'BİN SEKİZ YÜZ TÜRK LİRASI SIFIR KURUŞTUR.',
    'hesapAdi': 'Ankara Üniversitesi UBATAM\n(VKN:1234567890)',
    'iban': 'TR00 0000 0000 0000 0000 0000 00',
  };

  /// Uşak Üniversitesi Döner Sermaye işletme VKN (birim hesap adında yoksa kullanılır).
  static const String varsayilanIsletmeVkn = '2931062663';

  /// Matbu faturada işletme hesabı: birim adı üst satır, işletme VKN alt satır.
  /// [fallbackVkn] verilir ve metinde VKN yoksa alt satır otomatik eklenir.
  static String formatHesapAdiMatbu(String raw, {String? fallbackVkn}) {
    final trimmed = raw.replaceAll('\r\n', '\n').trim();
    if (trimmed.isEmpty) return trimmed;

    final lines = trimmed
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String result;

    if (lines.length >= 2) {
      final vknSatir = _normalizeVknSatir(lines.sublist(1).join(' '));
      if (vknSatir != null) {
        result = '${lines.first}\n$vknSatir';
      } else {
        result = trimmed;
      }
    } else {
      final vknBlok = RegExp(
        r'\s*\(VKN\s*:.*\)\s*$',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (vknBlok != null) {
        final ad = trimmed.substring(0, vknBlok.start).trim();
        final vknSatir = vknBlok.group(0)!.trim();
        result = ad.isNotEmpty ? '$ad\n$vknSatir' : trimmed;
      } else {
        result = trimmed;
      }
    }

    if (!_metindeVknVar(result)) {
      final vkn = (fallbackVkn ?? varsayilanIsletmeVkn).trim();
      if (vkn.isNotEmpty) {
        final ad = _hesapAdiSadeceAd(result);
        if (ad.isNotEmpty) return '$ad\n(VKN:$vkn)';
      }
    }

    return result;
  }

  static bool _metindeVknVar(String text) {
    return RegExp(r'\(VKN\s*:', caseSensitive: false).hasMatch(text) ||
        RegExp(r'(?<!\()VKN\s*:', caseSensitive: false).hasMatch(text);
  }

  static String _hesapAdiSadeceAd(String text) {
    final vknBlok = RegExp(
      r'\s*\(VKN\s*:.*\)\s*$',
      caseSensitive: false,
    ).firstMatch(text);
    if (vknBlok != null) {
      return text.substring(0, vknBlok.start).trim();
    }
    return text.split('\n').first.trim();
  }

  static String? _normalizeVknSatir(String line) {
    final t = line.trim();
    if (t.isEmpty) return null;
    if (RegExp(r'^\(VKN\s*:', caseSensitive: false).hasMatch(t)) return t;
    if (RegExp(r'^VKN\s*:', caseSensitive: false).hasMatch(t)) return '($t)';
    final digits = t.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10 || digits.length == 11) {
      return '(VKN:$digits)';
    }
    return null;
  }

  static const String varsayilanMelbesKurumOnEki =
      'Çevre Şehircilik ve İklim Değişikliği Bakanlığı';

  /// Matbu faturada MELBES alanı — yalnızca numara girilmişse etiket eklenir.
  static String formatMelbesMatbu(String raw, {String? kurumOnEki}) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (RegExp(r'melbes', caseSensitive: false).hasMatch(t)) return t;
    final kurum = kurumOnEki?.trim() ?? '';
    if (kurum.isNotEmpty) {
      return '$kurum Melbes Başvuru No: $t';
    }
    return 'Melbes Başvuru No: $t';
  }

  /// Matbu faturada Numune No alanı — yalnızca numara girilmişse etiket eklenir.
  static String formatNumuneNoMatbu(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (RegExp(r'numune', caseSensitive: false).hasMatch(t)) return t;
    return 'Numune No: $t';
  }

  /// Matbu: tek satırda kurum + MELBES + Numune No.
  static String formatMelbesNumuneSatir({
    required String melbes,
    required String numune,
    String? kurumOnEki,
  }) {
    final m = melbes.trim();
    final n = numune.trim();
    if (m.isEmpty && n.isEmpty) return '';

    final kurum = kurumOnEki?.trim() ?? '';

    if (m.isNotEmpty && n.isNotEmpty) {
      if (m.toLowerCase().contains('melbes') && n.toLowerCase().contains('numune')) {
        return '$m $n';
      }
      final melbesKisim = m.toLowerCase().contains('melbes')
          ? m
          : formatMelbesMatbu(m, kurumOnEki: kurum);
      final numuneKisim =
          n.toLowerCase().contains('numune') ? n : 'Numune No: $n';
      if (melbesKisim.toLowerCase().contains('numune')) return melbesKisim;
      return '$melbesKisim $numuneKisim';
    }

    if (m.isNotEmpty) return formatMelbesMatbu(m, kurumOnEki: kurum);
    return formatNumuneNoMatbu(n);
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
