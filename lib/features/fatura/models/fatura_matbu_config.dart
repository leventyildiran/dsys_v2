import 'package:flutter/material.dart';
import '../../../core/turkce_format.dart';

/// Matbu A4 fatura alan etiketleri ve varsayılan koordinatları.
class FaturaMatbuConfig {
  FaturaMatbuConfig._();

  static const double a4Genislik = 595.28;
  static const double a4Yukseklik = 841.89;
  static const double varsayilanFontBoyutu = 10.0;
  static const double varsayilanKalemSatirAraligi = 19.0;
  static const int varsayilanSatirLimit = 10;

  /// KDV muaf matbu faturada basılacak kısa metin (yalnızca son sayfa).
  static const String kdvMuafMatbuMetin = 'MUAF';

  /// Numune açıklama alanı — KDV muaf metni yalnızca son sayfada eklenir.
  static String numuneAciklamaMatbuMetni({
    required String numuneAciklamasi,
    required String? aciklama,
    required bool isKdvMuaf,
    required bool sonSayfa,
  }) {
    final numuneAciklamaAlt = numuneAciklamasi.trim();
    final numuneMelbesSatir = numuneAciklamaAlt.toLowerCase().contains('melbes') &&
        numuneAciklamaAlt.toLowerCase().contains('numune');
    final parts = <String>[
      if (numuneAciklamaAlt.isNotEmpty && !numuneMelbesSatir) numuneAciklamaAlt,
      if (aciklama != null && aciklama.trim().isNotEmpty) aciklama.trim(),
      if (isKdvMuaf && sonSayfa) kdvMuafMatbuMetin,
    ];
    return parts.join(' | ');
  }

  /// Matbu baskı/kalibrasyonda yalnızca gerçek tutarlı kalemleri basar.
  /// Başlık/grup satırları (cinsi var, fiyat/tutar yok) miktar sütununu kaydırmasın.
  static List<Map<String, dynamic>> matbuKalemleri(
    List<Map<String, dynamic>> kalemler,
  ) {
    final kaynak = List<Map<String, dynamic>>.from(kalemler);
    final gercekKalemler = kaynak.where((k) {
      final cinsi = '${k['cinsi']}'.trim();
      if (cinsi.isEmpty) return false;
      final fiyat = TurkceFormat.parseSayi(k['fiyat'], fallback: 0);
      final tutar = TurkceFormat.parseSayi(k['tutar'], fallback: 0);
      return fiyat > 0 || tutar > 0;
    }).toList();
    if (gercekKalemler.isNotEmpty) return gercekKalemler;

    return kaynak.where((k) => '${k['cinsi']}'.trim().isNotEmpty).toList();
  }

  static const Map<String, String> alanEtiketleri = {
    'firmaAdi': 'Firma Adı',
    'adres': 'Adres',
    'vergiDairesi': 'Vergi Dairesi',
    'vkn': 'VKN / TC',
    'tarih': 'Tarih',
    'irsaliyeTarihi': 'İrsaliye Tarihi',
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
    'melbesKurum': 'Bakanlık / Kurum Adı',
    'melbes': 'MELBES No',
    'numuneNo': 'Numune No',
    'matrah': 'Matrah',
    'kdv': 'KDV Tutarı',
    'kdvOrani': 'KDV Oranı (%)',
    'genelToplam': 'Genel Toplam',
    'yaziylaTutar': 'Yazıyla Tutar',
    'hesapAdi': 'Hesap Adı',
    'iban': 'IBAN',
    'ekstraNot_0': '1. Özel Not',
    'ekstraNot_1': '2. Özel Not',
    'ekstraNot_2': '3. Özel Not',
    'ekstraNot_3': '4. Özel Not',
    'ekstraNot_4': '5. Özel Not',
  };

  static const Map<String, String> ornekMetinler = {
    'firmaAdi': 'ÖRNEK TEST A.Ş.',
    'adres': 'Merkez Mah. Test Sok. No:1 Ankara',
    'vergiDairesi': 'Çankaya',
    'vkn': '1234567890',
    'tarih': '07.06.2026',
    'irsaliyeTarihi': '05.06.2026',
    'irsaliyeNo': 'IRS-2026/001',
    'cinsi': 'Analiz Hizmet Bedeli',
    'miktar': '1',
    'fiyat': '1.500,00',
    'tutar': '1.500,00',
    'numuneAciklama': 'Su numunesi — klor analizi',
    'melbesKurum': 'Çevre Şehircilik ve İklim Değişikliği Bakanlığı',
    'melbes': 'Melbes Başvuru No: MEL-2026-0042',
    'numuneNo': 'Numune No: N-1087',
    'matrah': '1.500,00',
    'kdv': '300,00',
    'kdvOrani': '%20',
    'genelToplam': '1.800,00',
    'yaziylaTutar': 'BİN SEKİZ YÜZ TÜRK LİRASI SIFIR KURUŞTUR.',
    'hesapAdi': 'Ankara Üniversitesi UBATAM\n(VKN:1234567890)',
    'iban': 'TR00 0000 0000 0000 0000 0000 00',
    'ekstraNot_0': 'Sürükle: 1. Özel Not',
    'ekstraNot_1': 'Sürükle: 2. Özel Not',
    'ekstraNot_2': 'Sürükle: 3. Özel Not',
    'ekstraNot_3': 'Sürükle: 4. Özel Not',
    'ekstraNot_4': 'Sürükle: 5. Özel Not',
    'nakliYekunUstTutar': '1.500,00',
    'nakliYekunAltTutar': '1.500,00',
  };

  /// Alt bölüm: yalnızca son sayfada basılır (çok sayfalı fatura).
  static const altBolgeSonSayfaAlanlari = <String>{};

  static bool altBolgeAlanMi(String alan) => false;

  /// Kalibrasyon önizlemesi ile PDF baskısında aynı metin biçimi.
  static Map<String, String> ornekBaskiMetinleri({String? isletmeVkn}) {
    const matrah = 1500.0;
    const kdv = 300.0;
    const genel = 1800.0;
    final hesap = formatHesapAdiMatbu(
      ornekMetinler['hesapAdi']!,
      fallbackVkn: isletmeVkn ?? varsayilanIsletmeVkn,
    );

    return {
      'firmaAdi': ornekMetinler['firmaAdi']!,
      'adres': ornekMetinler['adres']!,
      'vergiDairesi': ornekMetinler['vergiDairesi']!,
      'vkn': ornekMetinler['vkn']!,
      'tarih': ornekMetinler['tarih']!,
      'irsaliyeTarihi': ornekMetinler['irsaliyeTarihi']!,
      'irsaliyeNo': ornekMetinler['irsaliyeNo']!,
      'cinsi': ornekMetinler['cinsi']!,
      'miktar': ornekMetinler['miktar']!,
      'fiyat': TurkceFormat.para(1500),
      'tutar': TurkceFormat.para(1500),
      'numuneAciklama': ornekMetinler['numuneAciklama']!,
      'melbesKurum': ornekMetinler['melbesKurum']!,
      'melbes': ornekMetinler['melbes']!,
      'numuneNo': ornekMetinler['numuneNo']!,
      'matrah': TurkceFormat.para(matrah),
      'kdv': TurkceFormat.para(kdv),
      'kdvOrani': '%20',
      'genelToplam': TurkceFormat.para(genel),
      'yaziylaTutar': ornekMetinler['yaziylaTutar']!,
      'hesapAdi': hesap,
      'iban': ornekMetinler['iban']!,
      'ekstraNot_0': ornekMetinler['ekstraNot_0']!,
      'ekstraNot_1': ornekMetinler['ekstraNot_1']!,
      'ekstraNot_2': ornekMetinler['ekstraNot_2']!,
      'ekstraNot_3': ornekMetinler['ekstraNot_3']!,
      'ekstraNot_4': ornekMetinler['ekstraNot_4']!,
    };
  }

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

  /// Matbu: bakanlık/kurum adı (ayrı alan).
  static String formatMelbesKurumMatbu(String raw) => raw.trim();

  /// Matbu: yalnızca MELBES numarası — kurum ayrı alanda.
  static String formatMelbesNoMatbu(String raw) {
    final m = raw.trim();
    if (m.isEmpty) return m;
    if (m.toLowerCase().contains('melbes')) return m;
    return 'Melbes No: $m';
  }

  /// Matbu faturada MELBES alanı — kurum ile birleşik (eski tek satır).
  static String formatMelbesMatbu(String raw, {String? kurumOnEki}) {
    final m = raw.trim();
    if (m.isEmpty) return m;
    if (m.toLowerCase().contains('melbes')) return m;
    return 'Melbes No: $m';
  }

  /// Matbu faturada Numune No alanı — yalnızca numara girilmişse etiket eklenir.
  static String formatNumuneNoMatbu(String raw) {
    final n = raw.trim();
    if (n.isEmpty) return n;
    if (n.toLowerCase().contains('numune')) return n;
    return 'Numune No: $n';
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
      if (m.toLowerCase().contains('melbes') &&
          n.toLowerCase().contains('numune')) {
        return '$m $n';
      }
      final melbesKisim = m.toLowerCase().contains('melbes')
          ? m
          : formatMelbesMatbu(m, kurumOnEki: kurum);
      final numuneKisim = n.toLowerCase().contains('numune')
          ? n
          : 'Numune No: $n';
      if (melbesKisim.toLowerCase().contains('numune')) return melbesKisim;
      return '$melbesKisim $numuneKisim';
    }

    if (m.isNotEmpty) return formatMelbesMatbu(m, kurumOnEki: kurum);
    return formatNumuneNoMatbu(n);
  }

  static Map<String, Offset> varsayilanKoordinatlar() => {
    'firmaAdi': const Offset(33, 233),
    'adres': const Offset(29, 261),
    'vergiDairesi': const Offset(148, 313),
    'vkn': const Offset(147, 340),
    'tarih': const Offset(404, 304),
    'irsaliyeTarihi': const Offset(403, 318),
    'irsaliyeNo': const Offset(403, 334),
    'cinsi': const Offset(36.08, 398.62),
    'miktar': const Offset(293, 398.62),
    'fiyat': const Offset(344.43, 398.62),
    'tutar': const Offset(447.14, 398.62),
    'numuneAciklama': const Offset(38, 561),
    'melbesKurum': const Offset(39, 606),
    'melbes': const Offset(295, 607),
    'numuneNo': const Offset(40, 585),
    'nakliYekunUstYazi': const Offset(34, 382),
    'nakliYekunUstTutar': const Offset(470, 380),
    'nakliYekunAltYazi': const Offset(33, 568),
    'nakliYekunAltTutar': const Offset(447, 567),
    'matrah': const Offset(459, 668.35),
    'kdv': const Offset(460, 695.35),
    'kdvOrani': const Offset(387, 664),
    'genelToplam': const Offset(461, 722.35),
    'yaziylaTutar': const Offset(81, 755.35),
    'hesapAdi': const Offset(41, 801.35),
    'iban': const Offset(344, 807.35),
    'ekstraNot_0': const Offset(-253, 613),
    'ekstraNot_1': const Offset(-246, 637),
    'ekstraNot_2': const Offset(-247, 658),
    'ekstraNot_3': const Offset(-246, 679),
    'ekstraNot_4': const Offset(-242, 697),
  };
}
