import '../models/fatura_model.dart';
import 'vergi_kimlik_dogrulayici.dart';

/// Doğrulama servisi alanları yeniden hesaplamadan ÖNCE alınan anlık görüntü.
///
/// [FaturaDogrulamaServisi] genel toplamı kalemlerden yeniden hesaplar ve boş
/// tarihe bugünü yazar. Bu iyi bir varsayılan, ama sessiz kalırsa yanlış
/// okunmuş bir kalem fiyatı "doğru" görünen bir toplamla gizlenir. Anlık
/// görüntü, bu farkların kullanıcıya gösterilmesini sağlar.
class FaturaOkumaAnlikGoruntusu {
  const FaturaOkumaAnlikGoruntusu({
    required this.genelToplam,
    required this.tarih,
  });

  factory FaturaOkumaAnlikGoruntusu.al(FaturaModel f) =>
      FaturaOkumaAnlikGoruntusu(genelToplam: f.genelToplam, tarih: f.tarih);

  /// Belgeden okunan (henüz yeniden hesaplanmamış) genel toplam.
  final double genelToplam;

  /// Belgeden okunan tarih (boşsa okunamamıştır).
  final String tarih;
}

/// Okunan faturayı kaynak belgeyle ve kurallarla karşılaştırıp kullanıcıya
/// gösterilecek kontrol uyarılarını üretir.
///
/// Felsefe (AGENTS.md): sistem otomatik önerir, ama emin olmadığı veriyi
/// sessizce kabul etmez — eksik/şüpheli alanı görünür bırakır. Uyarılar
/// faturayı reddetmez; kullanıcı her zaman elle düzeltebilir.
abstract final class FaturaButunlukDenetcisi {
  /// Belgedeki toplam ile hesaplanan toplam arasındaki kabul edilebilir fark.
  /// Satır bazlı KDV yuvarlaması küçük farklar doğurabilir.
  static double toplamToleransi(double tutar) {
    final oransal = tutar.abs() * 0.001;
    return oransal > 0.10 ? oransal : 0.10;
  }

  static List<String> denetle({
    required FaturaModel fatura,
    required FaturaOkumaAnlikGoruntusu once,
    required String kaynakMetin,
    required bool aiUretimi,
    bool gorselVeyaEkliBelge = false,
    String isletmeVkn = '',
    DateTime? bugun,
  }) {
    final uyarilar = <String>[];
    final simdi = bugun ?? DateTime.now();

    _tarihDenetle(once.tarih, simdi, uyarilar);
    _toplamDenetle(once.genelToplam, fatura.genelToplam, uyarilar);
    _kimlikDenetle(fatura, isletmeVkn, uyarilar);

    return uyarilar;
  }

  // ── Tarih ─────────────────────────────────────────────────────────────

  static void _tarihDenetle(String ham, DateTime simdi, List<String> u) {
    final tarih = ham.trim();
    if (tarih.isEmpty) {
      // Bilinçli tasarım: Belgede tarih yoksa faturanın kesildiği günün tarihi
      // otomatik atanır; kullanıcı dilerse manuel değiştirebilir. Uyarı üretilmez.
      return;
    }
    final t = tarihCoz(tarih);
    if (t == null) {
      u.add('Fatura tarihi ("$tarih") tanınan bir biçimde değil (GG.AA.YYYY).');
      return;
    }
    final bugun = DateTime(simdi.year, simdi.month, simdi.day);
    if (t.isAfter(bugun.add(const Duration(days: 1)))) {
      u.add('Fatura tarihi ($tarih) ileri bir tarih.');
    } else if (t.isBefore(DateTime(simdi.year - 2, simdi.month, simdi.day))) {
      u.add('Fatura tarihi ($tarih) 2 yıldan eski; doğru belge mi?');
    }
  }

  /// GG.AA.YYYY, GG/AA/YYYY, GG-AA-YYYY ve YYYY-AA-GG biçimlerini çözer.
  static DateTime? tarihCoz(String s) {
    final tr = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{4})$').firstMatch(s.trim());
    final iso = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})').firstMatch(s.trim());
    int? g, a, y;
    if (tr != null) {
      g = int.parse(tr.group(1)!);
      a = int.parse(tr.group(2)!);
      y = int.parse(tr.group(3)!);
    } else if (iso != null) {
      y = int.parse(iso.group(1)!);
      a = int.parse(iso.group(2)!);
      g = int.parse(iso.group(3)!);
    } else {
      return null;
    }
    if (a < 1 || a > 12 || g < 1 || g > 31) return null;
    final d = DateTime(y, a, g);
    // 31.02 gibi taşan tarihleri reddet.
    if (d.month != a || d.day != g) return null;
    return d;
  }

  // ── Tutar ─────────────────────────────────────────────────────────────

  static void _toplamDenetle(double belgedeki, double hesaplanan, List<String> u) {
    if (belgedeki <= 0 || hesaplanan <= 0) return;
    final fark = (belgedeki - hesaplanan).abs();
    if (fark > toplamToleransi(belgedeki)) {
      u.add(
        'Belgede okunan genel toplam ${trTutar(belgedeki)} TL, kalemler ve '
        'KDV\'den hesaplanan ${trTutar(hesaplanan)} TL (fark ${trTutar(fark)} TL). '
        'Kalem fiyatlarını veya KDV oranını kontrol edin.',
      );
    }
  }

  // ── VKN / TCKN ────────────────────────────────────────────────────────

  static const List<String> _duzenleyenIsaretleri = [
    'doner sermaye',
    'donersermaye',
  ];

  static void _kimlikDenetle(FaturaModel f, String isletmeVkn, List<String> u) {
    final no = VergiKimlikDogrulayici.sadeceRakam(f.vergiNo);
    if (no.isNotEmpty) {
      if (no.length != 10 && no.length != 11) {
        u.add('Vergi/TC kimlik no (${f.vergiNo}) 10 veya 11 hane değil.');
      } else if (!VergiKimlikDogrulayici.gecerliMi(no)) {
        u.add(
          '${no.length == 10 ? 'VKN' : 'TCKN'} ($no) GİB kontrol algoritmasını '
          'geçmiyor; bir hane yanlış okunmuş olabilir.',
        );
      }
      final isletme = VergiKimlikDogrulayici.sadeceRakam(isletmeVkn);
      if (isletme.isNotEmpty && isletme == no) {
        u.add(
          'Alıcı VKN\'si olarak işletmenin kendi VKN\'si ($no) okunmuş. '
          'Faturayı kesen değil, alan firmanın numarası olmalı.',
        );
      }
    }
    final firma = normalize(f.firmaAdi);
    if (_duzenleyenIsaretleri.any(firma.contains)) {
      u.add(
        'Firma adı olarak faturayı düzenleyen kurum ("${f.firmaAdi}") okunmuş '
        'olabilir; alıcı firmayı kontrol edin.',
      );
    }
  }

  // ── Matematiksel Formatlama ─────────────────────────────────────────────

  /// 1234.5 → "1.234,50"
  static String trTutar(double v) {
    final sabit = v.abs().toStringAsFixed(2);
    final parcalar = sabit.split('.');
    final tam = _binlikAyir(parcalar[0], '.');
    return '${v < 0 ? '-' : ''}$tam,${parcalar[1]}';
  }

  static String _binlikAyir(String tam, String ayrac) {
    final sb = StringBuffer();
    for (var i = 0; i < tam.length; i++) {
      if (i > 0 && (tam.length - i) % 3 == 0) sb.write(ayrac);
      sb.write(tam[i]);
    }
    return sb.toString();
  }

  /// Türkçe karakterleri katlayıp küçük harfe çevirir (OCR/PDF farklarına dayanıklı).
  static String normalize(String s) {
    const harita = {
      'İ': 'i', 'I': 'i', 'ı': 'i', 'Ş': 's', 'ş': 's', 'Ğ': 'g', 'ğ': 'g',
      'Ü': 'u', 'ü': 'u', 'Ö': 'o', 'ö': 'o', 'Ç': 'c', 'ç': 'c', 'Â': 'a',
      'â': 'a', 'Î': 'i', 'î': 'i', 'Û': 'u', 'û': 'u',
    };
    final sb = StringBuffer();
    for (final ch in s.split('')) {
      sb.write(harita[ch] ?? ch.toLowerCase());
    }
    return sb.toString();
  }
}
