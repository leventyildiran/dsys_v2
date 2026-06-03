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
}
