/// GİB Vergi Kimlik Numarası (VKN) ve T.C. Kimlik Numarası (TCKN) algoritmik
/// doğrulaması. Fatura okuma zincirinin tamamı (kural motoru, bütünlük
/// denetçisi) bu tek kaynağı kullanır.
abstract final class VergiKimlikDogrulayici {
  /// Boşluk, nokta, tire gibi ayraçları atarak yalnızca rakamları döner.
  static String sadeceRakam(String deger) =>
      deger.replaceAll(RegExp(r'[^0-9]'), '');

  /// Resmi GİB VKN (10 hane) MOD 10 algoritması.
  static bool vknGecerliMi(String vkn) {
    if (vkn.length != 10 || !RegExp(r'^\d{10}$').hasMatch(vkn)) return false;
    if (vkn.split('').toSet().length == 1) return false;
    var toplam = 0;
    for (var i = 0; i < 9; i++) {
      final c = int.parse(vkn[i]);
      final v1 = (c + 10 - (i + 1)) % 10;
      if (v1 == 9) {
        toplam += 9;
      } else if (v1 != 0) {
        var v2 = (v1 * (1 << (9 - i))) % 9;
        if (v2 == 0) v2 = 9;
        toplam += v2;
      }
    }
    final sonHane = (10 - (toplam % 10)) % 10;
    return sonHane == int.parse(vkn[9]);
  }

  /// T.C. Kimlik Numarası (11 hane) algoritması.
  static bool tcknGecerliMi(String tckn) {
    if (tckn.length != 11 || !RegExp(r'^[1-9]\d{10}$').hasMatch(tckn)) {
      return false;
    }
    final d = tckn.split('').map(int.parse).toList();
    final tek = d[0] + d[2] + d[4] + d[6] + d[8];
    final cift = d[1] + d[3] + d[5] + d[7];
    var d10 = ((tek * 7) - cift) % 10;
    if (d10 < 0) d10 += 10;
    if (d10 != d[9]) return false;
    var ilkOnToplam = 0;
    for (var i = 0; i < 10; i++) {
      ilkOnToplam += d[i];
    }
    return (ilkOnToplam % 10) == d[10];
  }

  /// 10 haneyse VKN, 11 haneyse TCKN kuralını uygular.
  static bool gecerliMi(String deger) {
    final r = sadeceRakam(deger);
    if (r.length == 10) return vknGecerliMi(r);
    if (r.length == 11) return tcknGecerliMi(r);
    return false;
  }
}
