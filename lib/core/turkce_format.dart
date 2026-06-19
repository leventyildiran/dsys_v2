/// Türkçe para, tarih ve katsayı biçimlendirme yardımcıları.
///
/// SKILL.md kurallarına birebir uyar:
/// - Para: `120.000,00 TL` (binlik nokta, ondalık virgül)
/// - Tarih: `dd.MM.yyyy`
/// - Katsayı: `19,50` (virgülden sonra 2 basamak)
class TurkceFormat {
  TurkceFormat._();

  /// Para biçimlendirme: `120.000,00 TL`
  static String para(double tutar) {
    final isNegative = tutar < 0;
    tutar = tutar.abs();

    // 2 ondalık basamağa yuvarla
    final fixed = tutar.toStringAsFixed(2);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    // Binlik ayırıcı ekle
    final buffer = StringBuffer();
    final length = intPart.length;
    for (int i = 0; i < length; i++) {
      if (i > 0 && (length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(intPart[i]);
    }

    final formatted = '${isNegative ? '-' : ''}${buffer.toString()},$decPart TL';
    return formatted;
  }

  /// Kalem fiyat girişi (TL soneki ayrı gösterilir): `5.557,25`
  static String paraKalem(double tutar) {
    return para(tutar).replaceAll(' TL', '').trim();
  }

  /// Türkçe para metnini sayıya çevirir (`5.557,25` veya `5557.25`).
  static double parseSayi(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();

    var text = value.toString().trim();
    if (text.isEmpty) return fallback;
    text = text.replaceAll(' ', '');

    if (text.contains(',') && text.contains('.')) {
      text = text.replaceAll('.', '').replaceAll(',', '.');
    } else if (text.contains(',')) {
      text = text.replaceAll(',', '.');
    }

    text = text.replaceAll(RegExp(r'[^0-9\.\-]'), '');
    return double.tryParse(text) ?? fallback;
  }

  /// Tarih biçimlendirme: `dd.MM.yyyy`
  static String tarih(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day.$month.$year';
  }

  /// Katsayı biçimlendirme: `19,50`
  static String katsayi(double value) {
    final fixed = value.toStringAsFixed(2);
    return fixed.replaceAll('.', ',');
  }

  /// Sayıyı Türkçe ondalık formatına çevirir (binlik ayırıcısız).
  static String ondalik(double value, {int decimals = 2}) {
    return value.toStringAsFixed(decimals).replaceAll('.', ',');
  }

  /// Tutarı yazıyla Türkçe olarak döndürür: `1.800,00` → `BİN SEKİZ YÜZ TÜRK LİRASI SIFIR KURUŞTUR.`
  static String sayiyiYaziyaCevir(double tutar) {
    if (tutar == 0) return 'SIFIR TÜRK LİRASI SIFIR KURUŞTUR.';
    final parts = tutar.toStringAsFixed(2).split('.');
    final lira = int.parse(parts[0]);
    final kurus = int.parse(parts[1]);
    final liraYazi = lira == 0 ? 'SIFIR' : _convertNumberToWords(lira);
    final kurusYazi = kurus == 0 ? 'SIFIR' : _convertNumberToWords(kurus);
    return '$liraYazi TÜRK LİRASI $kurusYazi KURUŞTUR.';
  }

  static String _convertNumberToWords(int number) {
    const birler = [
      '', 'BİR', 'İKİ', 'ÜÇ', 'DÖRT', 'BEŞ', 'ALTI', 'YEDİ', 'SEKİZ', 'DOKUZ',
    ];
    const onlar = [
      '', 'ON', 'YİRMİ', 'OTUZ', 'KIRK', 'ELLİ', 'ALTMIŞ', 'YETMİŞ', 'SEKSEN', 'DOKSAN',
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
        if (yuzler > 0) groupText += yuzler == 1 ? 'YÜZ ' : '${birler[yuzler]} YÜZ ';
        if (onlarBasamagi > 0) groupText += '${onlar[onlarBasamagi]} ';
        if (birlerBasamagi > 0 && !(groupIndex == 1 && group == 1)) groupText += '${birler[birlerBasamagi]} ';
        groupText += '${binler[groupIndex]} ';
        result = groupText + result;
      }
      n ~/= 1000;
      groupIndex++;
    }
    return result.trim().replaceAll('  ', ' ');
  }
}
