import 'turkce_format.dart';

/// Şablon yer tutucu doğrulama sonucu.
class SablonDogrulamaSonucu {
  const SablonDogrulamaSonucu({
    required this.gecerli,
    required this.eksikAlanlar,
    required this.doluAlanlar,
  });

  final bool gecerli;
  final List<String> eksikAlanlar;
  final List<String> doluAlanlar;

  double get tamamlanmaOrani =>
      doluAlanlar.isEmpty && eksikAlanlar.isEmpty
          ? 0.0
          : doluAlanlar.length / (doluAlanlar.length + eksikAlanlar.length);
}

/// YK Karar metni üretim/önizleme servisi.
///
/// Şablon A (standart) ve Şablon B (sanayi 58/k) karar metinlerini
/// placeholder değerleriyle doldurur. Tüm biçimlendirme kurallarını
/// (para, tarih, katsayı, tipografik tırnak) otomatik uygular.
class KararMetniServisi {
  KararMetniServisi._();

  // ─────────────────────────────────────────────────────────────
  // ŞABLONLAR
  // ─────────────────────────────────────────────────────────────

  /// Şablon A: Standart Danışmanlık Karar Şablonu
  static const String sablonStandart = 'Üniversitemiz {BIRIM_AD} '
      'Müdürlüğü\u2019nün {BIRIM_EVRAK_TARIHI} tarih ve {BIRIM_EVRAK_SAYISI} '
      'sayılı yazısı ile {BIRIM_KURUL_TARIHI} tarih, {BIRIM_TOPLANTI_SAYI} '
      'toplantı sayılı ve {BIRIM_KARAR_NO} numaralı kararına istinaden; '
      'Döner Sermaye Yürütme Kurulu\u2019nun {YK_KARAR_TARIHI} tarih ve '
      '{YK_KARAR_NO} sayılı kararı ile {FIRMA_UNVAN}\u2019nin talep ettiği '
      '\u201C{ISIN_KONUSU}\u201D kapsamında {DANISMANLIK_SURESI} ay süreyle '
      'Danışmanlık Hizmeti için görevlendirilen {HOCA_UNVAN} {HOCA_AD_SOYAD} '
      'tarafından verilen danışmanlık hizmetine istinaden elde edilen gelirden '
      'ayrılan katkı payından aşağıdaki gelir getirici faaliyet cetveli '
      'doğrultusunda, dönem ek ödeme katsayısının {KATSAYI} şeklinde '
      'belirlenmesi ve elde edilen puanlara göre hesaplanacak katkı payı '
      'dağıtımının gerçekleştirilmesine;';

  /// Şablon B: Sanayi İşbirliği (58/k) Karar Şablonu
  static const String sablonSanayiIsbirligi = 'Üniversitemiz Yönetim '
      'Kurulunun {UYK_KARAR_TARIHI} tarih, {UYK_TOPLANTI_SAYI} toplantı '
      'sayılı, {UYK_KARAR_NO} numaralı kararıyla 2547 Sayılı Yükseköğretim '
      'Kanunun 58. maddesinin (k) fıkrası kapsamında {FIRMA_UNVAN} ye teknik '
      'danışmanlık hizmeti vermek üzere görevlendirilen {HOCA_UNVAN} '
      '{HOCA_AD_SOYAD} tarafından {HIZMET_BASLANGIC_TARIHI}-'
      '{HIZMET_BITIS_TARIHI} ({DANISMANLIK_SURESI} Aylık) tarihleri arasında '
      'gerçekleştirilen hizmet için elde edilen {GELIR_TUTARI} TL gelirden '
      'ayrılan {KATKI_PAYI_TUTARI} TL katkı payının adı geçen öğretim '
      'üyesine tahakkuk ettirilmesine;';

  // ─────────────────────────────────────────────────────────────
  // ANA FONKSİYONLAR
  // ─────────────────────────────────────────────────────────────

  /// Standart danışmanlık için gerekli tüm placeholder anahtarları.
  static List<String> get standartGerekliAlanlar => const [
        'BIRIM_AD',
        'BIRIM_EVRAK_TARIHI',
        'BIRIM_EVRAK_SAYISI',
        'BIRIM_KURUL_TARIHI',
        'BIRIM_TOPLANTI_SAYI',
        'BIRIM_KARAR_NO',
        'YK_KARAR_TARIHI',
        'YK_KARAR_NO',
        'FIRMA_UNVAN',
        'ISIN_KONUSU',
        'DANISMANLIK_SURESI',
        'HOCA_UNVAN',
        'HOCA_AD_SOYAD',
        'KATSAYI',
      ];

  /// Sanayi işbirliği (58/k) için gerekli placeholder anahtarları.
  static List<String> get sanayiGerekliAlanlar => const [
        'UYK_KARAR_TARIHI',
        'UYK_TOPLANTI_SAYI',
        'UYK_KARAR_NO',
        'FIRMA_UNVAN',
        'HOCA_UNVAN',
        'HOCA_AD_SOYAD',
        'HIZMET_BASLANGIC_TARIHI',
        'HIZMET_BITIS_TARIHI',
        'DANISMANLIK_SURESI',
        'GELIR_TUTARI',
        'KATKI_PAYI_TUTARI',
      ];

  /// Şablonu doğrular: hangi alanlar dolu, hangileri eksik.
  static SablonDogrulamaSonucu dogrula({
    required bool isStandart,
    required Map<String, String?> veriler,
  }) {
    final gerekliAlanlar =
        isStandart ? standartGerekliAlanlar : sanayiGerekliAlanlar;

    final eksikler = <String>[];
    final dolular = <String>[];

    for (final alan in gerekliAlanlar) {
      final deger = veriler[alan];
      if (deger == null || deger.trim().isEmpty) {
        eksikler.add(alan);
      } else {
        dolular.add(alan);
      }
    }

    return SablonDogrulamaSonucu(
      gecerli: eksikler.isEmpty,
      eksikAlanlar: eksikler,
      doluAlanlar: dolular,
    );
  }

  /// Karar metnini üretir. Eksik alanlar `{ALAN_ADI}` olarak kalır.
  ///
  /// [veriler] map'indeki değerler otomatik biçimlendirilir:
  /// - `_TARIHI` ile bitenler → tarih formatı
  /// - `_TUTARI` ile bitenler → para formatı
  /// - `KATSAYI` → katsayı formatı
  static String metinUret({
    required bool isStandart,
    required Map<String, String?> veriler,
  }) {
    String sablon = isStandart ? sablonStandart : sablonSanayiIsbirligi;

    for (final entry in veriler.entries) {
      final anahtar = entry.key;
      final deger = entry.value;

      if (deger != null && deger.trim().isNotEmpty) {
        sablon = sablon.replaceAll('{$anahtar}', deger);
      }
    }

    return sablon;
  }

  /// Veriler haritasını biçimlendirme kurallarıyla düzenler.
  ///
  /// Ham değerleri şablon motoru formatlarına çevirir:
  /// - Para: `120.000,00 TL`
  /// - Tarih: `dd.MM.yyyy`
  /// - Katsayı: `19,50`
  static Map<String, String> bicimlendir(Map<String, dynamic> hamVeriler) {
    final sonuc = <String, String>{};

    for (final entry in hamVeriler.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value == null) continue;

      if (value is double && key.contains('TUTARI')) {
        // Para biçimlendirme (TL suffix'siz çünkü şablonda TL yazıyor)
        sonuc[key] = TurkceFormat.para(value).replaceAll(' TL', '');
      } else if (value is double && key == 'KATSAYI') {
        sonuc[key] = TurkceFormat.katsayi(value);
      } else if (value is DateTime) {
        sonuc[key] = TurkceFormat.tarih(value);
      } else {
        sonuc[key] = value.toString();
      }
    }

    return sonuc;
  }

  /// Placeholder anahtar adını kullanıcı dostu Türkçe etikete çevirir.
  static String alanEtiketi(String anahtar) {
    const etiketler = {
      'BIRIM_AD': 'Birim Adı',
      'BIRIM_EVRAK_TARIHI': 'Birim Evrak Tarihi',
      'BIRIM_EVRAK_SAYISI': 'Birim Evrak Sayısı',
      'BIRIM_KURUL_TARIHI': 'Birim Kurul Tarihi',
      'BIRIM_TOPLANTI_SAYI': 'Birim Toplantı Sayısı',
      'BIRIM_KARAR_NO': 'Birim Karar No',
      'YK_KARAR_TARIHI': 'YK Karar Tarihi',
      'YK_KARAR_NO': 'YK Karar No',
      'FIRMA_UNVAN': 'Firma Ünvanı',
      'ISIN_KONUSU': 'İşin Konusu',
      'DANISMANLIK_SURESI': 'Danışmanlık Süresi',
      'HOCA_UNVAN': 'Hoca Ünvanı',
      'HOCA_AD_SOYAD': 'Hoca Ad Soyad',
      'KATSAYI': 'Ek Ödeme Katsayısı',
      'UYK_KARAR_TARIHI': 'ÜYK Karar Tarihi',
      'UYK_TOPLANTI_SAYI': 'ÜYK Toplantı Sayısı',
      'UYK_KARAR_NO': 'ÜYK Karar No',
      'HIZMET_BASLANGIC_TARIHI': 'Hizmet Başlangıç Tarihi',
      'HIZMET_BITIS_TARIHI': 'Hizmet Bitiş Tarihi',
      'GELIR_TUTARI': 'Gelir Tutarı',
      'KATKI_PAYI_TUTARI': 'Katkı Payı Tutarı',
    };
    return etiketler[anahtar] ?? anahtar;
  }
}
