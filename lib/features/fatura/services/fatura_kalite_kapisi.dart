import '../models/fatura_model.dart';

/// Kural motoru (ücretsiz) sonucunun "API'ye gitmeden kabul edilebilir"
/// olup olmadığına karar verir.
///
/// Amaç: Yerel sonuç gerçekten eksiksizse para harcamamak; eksikse
/// kullanıcıya uydurma/eksik fatura sunmak yerine bir üst katmana geçmek.
abstract final class FaturaKaliteKapisi {
  /// Kural motorunun okuyamadığı durumlarda koyduğu yer tutucu kalem adları.
  static const Set<String> yerTutucuKalemAdlari = {'fatura bedeli'};

  static final RegExp _ettnRegex = RegExp(
    r'ETTN\s*[:：]?\s*([0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})',
  );
  static final RegExp _faturaNoRegex = RegExp(
    r'Fatura\s*No\s*[:：]\s*([A-Z0-9]{6,})',
    caseSensitive: false,
  );

  /// Metindeki farklı ETTN / Fatura No değerlerinden beklenen fatura sayısı.
  /// Aynı faturanın her sayfada tekrarlanan başlığı tek sayılır.
  static int beklenenFaturaSayisi(String metin) {
    if (metin.trim().isEmpty) return 0;
    final ettnler = _ettnRegex
        .allMatches(metin)
        .map((m) => m.group(1)!.toLowerCase())
        .toSet();
    final faturaNolar = _faturaNoRegex
        .allMatches(metin)
        .map((m) => m.group(1)!.toUpperCase())
        .toSet();
    return ettnler.length > faturaNolar.length
        ? ettnler.length
        : faturaNolar.length;
  }

  /// null → sonuç yeterli (API'ye gerek yok). Aksi halde kullanıcıya
  /// terminalde gösterilecek eksiklik nedeni.
  static String? eksikNedeni(List<FaturaModel> faturalar, String metin) {
    if (faturalar.isEmpty) return 'Kural motoru belgede fatura yapısı bulamadı.';

    final beklenen = beklenenFaturaSayisi(metin);
    if (beklenen > faturalar.length) {
      return 'Belgede $beklenen farklı fatura işareti var, kural motoru '
          '${faturalar.length} fatura çıkarabildi.';
    }

    for (var i = 0; i < faturalar.length; i++) {
      final f = faturalar[i];
      final no = 'Fatura ${i + 1}';
      if (f.firmaAdi.trim().length < 3) return '$no: firma/alıcı adı okunamadı.';
      if (f.genelToplam <= 0) return '$no: tutar okunamadı.';
      if (f.kalemler.isEmpty) return '$no: kalem satırı bulunamadı.';
      for (final k in f.kalemler) {
        final cinsi = (k['cinsi'] ?? '').toString().trim();
        if (cinsi.isEmpty) return '$no: kalem adı boş.';
        if (yerTutucuKalemAdlari.contains(cinsi.toLowerCase())) {
          return '$no: kalem satırları okunamadı (genel "$cinsi" kullanıldı).';
        }
        final fiyat = _sayi(k['fiyat']);
        if (fiyat <= 0) return '$no: "$cinsi" kaleminin fiyatı okunamadı.';
      }
    }
    return null;
  }

  static double _sayi(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }
}
