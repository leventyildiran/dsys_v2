/// KDV oranı tanımı (örn. %10, %20).
///
/// Kurum bazlı yapılandırmada hangi KDV oranlarının kullanılacağını ve
/// doğrulama motorunun hangi oranları kontrol edeceğini belirler.
class KdvOranTanimi {
  final int oran; // 1, 8, 10, 20 ...
  final String? etiket; // boşsa "%<oran>" üretilir

  const KdvOranTanimi({required this.oran, this.etiket});

  String get gorunenEtiket => etiket ?? '%$oran';

  /// Doğrulama için kesir karşılığı (örn. 20 -> 0.20).
  double get kesir => oran / 100.0;

  Map<String, dynamic> toMap() => {'oran': oran, 'etiket': etiket};

  factory KdvOranTanimi.fromMap(Map<String, dynamic> map) => KdvOranTanimi(
        oran: (map['oran'] as num?)?.toInt() ?? 20,
        etiket: map['etiket'] as String?,
      );
}

/// Tevkifat türü tanımı (serbest pay/payda).
///
/// Sabit enum yerine kurum kendi tevkifat listesini tanımlayabilir
/// (örn. 9/10, 7/10, 5/10, 4/10, 3/10, 2/10 ...).
class TevkifatTanimi {
  final String etiket;
  final int pay;
  final int payda;

  const TevkifatTanimi({
    required this.etiket,
    required this.pay,
    required this.payda,
  });

  double get oran => payda == 0 ? 0.0 : pay / payda;

  Map<String, dynamic> toMap() => {
        'etiket': etiket,
        'pay': pay,
        'payda': payda,
      };

  factory TevkifatTanimi.fromMap(Map<String, dynamic> map) => TevkifatTanimi(
        etiket: map['etiket'] as String? ?? '9/10',
        pay: (map['pay'] as num?)?.toInt() ?? 9,
        payda: (map['payda'] as num?)?.toInt() ?? 10,
      );
}

/// Yıllık asgari ücret vergi istisnası tablosu.
///
/// Kurum yeni bir yıl (örn. 2026) eklemek istediğinde kod değiştirmeden
/// yapılandırmaya kayıt ekler. Tablo boşsa hesaplama motoru kendi yerleşik
/// (2025) tablosunu kullanmaya devam eder; böylece mevcut davranış birebir
/// korunur (parite).
class AsgariUcretYilTablosu {
  final int yil;

  /// Ay (1-12) -> aylık asgari ücret gelir vergisi matrahı (TL).
  final Map<int, double> aylikMatrah;

  /// Ay (1-12) -> aylık gelir vergisi istisnası tutarı (TL).
  final Map<int, double> aylikGelirVergisi;

  /// Ay (1-12) -> aylık damga vergisi istisnası tutarı (TL).
  final Map<int, double> aylikDamgaVergisi;

  const AsgariUcretYilTablosu({
    required this.yil,
    this.aylikMatrah = const {},
    this.aylikGelirVergisi = const {},
    this.aylikDamgaVergisi = const {},
  });

  Map<String, dynamic> toMap() => {
        'yil': yil,
        'aylikMatrah':
            aylikMatrah.map((k, v) => MapEntry('$k', v)),
        'aylikGelirVergisi':
            aylikGelirVergisi.map((k, v) => MapEntry('$k', v)),
        'aylikDamgaVergisi':
            aylikDamgaVergisi.map((k, v) => MapEntry('$k', v)),
      };

  factory AsgariUcretYilTablosu.fromMap(Map<String, dynamic> map) =>
      AsgariUcretYilTablosu(
        yil: (map['yil'] as num?)?.toInt() ?? 0,
        aylikMatrah: _aylikOku(map['aylikMatrah']),
        aylikGelirVergisi: _aylikOku(map['aylikGelirVergisi']),
        aylikDamgaVergisi: _aylikOku(map['aylikDamgaVergisi']),
      );

  static Map<int, double> _aylikOku(dynamic raw) {
    if (raw is Map) {
      final out = <int, double>{};
      raw.forEach((k, v) {
        final ay = int.tryParse(k.toString());
        final tutar = (v as num?)?.toDouble();
        if (ay != null && tutar != null) out[ay] = tutar;
      });
      return out;
    }
    return const {};
  }
}

/// Kurum bazlı beyanname blok görünürlüğü.
///
/// Bir kurumda karşılığı olmayan tablo (örn. kredi kartı 123) gizlenebilir.
class BeyannameBloklari {
  final bool kdv1;
  final bool kdv2;
  final bool muhtasar;
  final bool damga301;
  final bool damga302;
  final bool hasiat600;
  final bool krediKarti123;

  const BeyannameBloklari({
    this.kdv1 = true,
    this.kdv2 = true,
    this.muhtasar = true,
    this.damga301 = true,
    this.damga302 = true,
    this.hasiat600 = true,
    this.krediKarti123 = true,
  });

  Map<String, dynamic> toMap() => {
        'kdv1': kdv1,
        'kdv2': kdv2,
        'muhtasar': muhtasar,
        'damga301': damga301,
        'damga302': damga302,
        'hasiat600': hasiat600,
        'krediKarti123': krediKarti123,
      };

  factory BeyannameBloklari.fromMap(Map<String, dynamic> map) =>
      BeyannameBloklari(
        kdv1: map['kdv1'] as bool? ?? true,
        kdv2: map['kdv2'] as bool? ?? true,
        muhtasar: map['muhtasar'] as bool? ?? true,
        damga301: map['damga301'] as bool? ?? true,
        damga302: map['damga302'] as bool? ?? true,
        hasiat600: map['hasiat600'] as bool? ?? true,
        krediKarti123: map['krediKarti123'] as bool? ?? true,
      );

  BeyannameBloklari copyWith({
    bool? kdv1,
    bool? kdv2,
    bool? muhtasar,
    bool? damga301,
    bool? damga302,
    bool? hasiat600,
    bool? krediKarti123,
  }) =>
      BeyannameBloklari(
        kdv1: kdv1 ?? this.kdv1,
        kdv2: kdv2 ?? this.kdv2,
        muhtasar: muhtasar ?? this.muhtasar,
        damga301: damga301 ?? this.damga301,
        damga302: damga302 ?? this.damga302,
        hasiat600: hasiat600 ?? this.hasiat600,
        krediKarti123: krediKarti123 ?? this.krediKarti123,
      );
}

/// Kurum bazlı beyanname yapılandırması.
///
/// Kod içindeki sabit varsayımların (KDV oranları, tevkifat türleri, damga
/// oranı, görünür bloklar) TAMAMINI tek kaynakta toplar.
///
/// ÖNEMLİ: [varsayilan] değerleri bugünkü sabit değerlerle birebir aynıdır;
/// bu yüzden mevcut tek-kurum kurulumu davranışı değişmez.
class BeyannameKonfigurasyonu {
  final String kurumId;
  final List<KdvOranTanimi> kdvOranlari;
  final List<TevkifatTanimi> tevkifatTurleri;

  /// Damga vergisi oranı "binde" cinsinden (varsayılan binde 9,48).
  final double damgaBinde;

  final BeyannameBloklari bloklar;

  /// Yıllık asgari ücret istisna tabloları. Boşsa motor yerleşik
  /// (2025) tablosunu kullanır — mevcut davranış değişmez.
  final List<AsgariUcretYilTablosu> asgariUcretTablolari;

  const BeyannameKonfigurasyonu({
    this.kurumId = '',
    this.kdvOranlari = varsayilanKdvOranlari,
    this.tevkifatTurleri = varsayilanTevkifatTurleri,
    this.damgaBinde = varsayilanDamgaBinde,
    this.bloklar = const BeyannameBloklari(),
    this.asgariUcretTablolari = const [],
  });

  BeyannameKonfigurasyonu copyWith({
    String? kurumId,
    List<KdvOranTanimi>? kdvOranlari,
    List<TevkifatTanimi>? tevkifatTurleri,
    double? damgaBinde,
    BeyannameBloklari? bloklar,
    List<AsgariUcretYilTablosu>? asgariUcretTablolari,
  }) {
    return BeyannameKonfigurasyonu(
      kurumId: kurumId ?? this.kurumId,
      kdvOranlari: kdvOranlari ?? this.kdvOranlari,
      tevkifatTurleri: tevkifatTurleri ?? this.tevkifatTurleri,
      damgaBinde: damgaBinde ?? this.damgaBinde,
      bloklar: bloklar ?? this.bloklar,
      asgariUcretTablolari: asgariUcretTablolari ?? this.asgariUcretTablolari,
    );
  }

  // --- Varsayılanlar (bugünkü sabit değerler) ---

  /// Damga vergisi oranı: binde 9,48 (Mizan 360.03.05).
  static const double varsayilanDamgaBinde = 9.48;

  /// Damga oranının kesir karşılığı (0.00948).
  static double get varsayilanDamgaOrani => varsayilanDamgaBinde / 1000.0;

  static const List<KdvOranTanimi> varsayilanKdvOranlari = [
    KdvOranTanimi(oran: 10),
    KdvOranTanimi(oran: 20),
  ];

  static const List<TevkifatTanimi> varsayilanTevkifatTurleri = [
    TevkifatTanimi(etiket: '9/10', pay: 9, payda: 10),
    TevkifatTanimi(etiket: '7/10', pay: 7, payda: 10),
    TevkifatTanimi(etiket: '5/10', pay: 5, payda: 10),
  ];

  /// Tek-kurum davranışını birebir koruyan varsayılan yapılandırma.
  static const BeyannameKonfigurasyonu varsayilan = BeyannameKonfigurasyonu();

  // --- Sorgular ---

  /// Belirli bir KDV oranının kesir karşılığı; tanımlı değilse oran/100 döner.
  double oranKesri(int oran) {
    for (final o in kdvOranlari) {
      if (o.oran == oran) return o.kesir;
    }
    return oran / 100.0;
  }

  // --- Serileştirme (Faz 1: Firestore) ---

  Map<String, dynamic> toMap() => {
        'kurumId': kurumId,
        'kdvOranlari': kdvOranlari.map((e) => e.toMap()).toList(),
        'tevkifatTurleri': tevkifatTurleri.map((e) => e.toMap()).toList(),
        'damgaBinde': damgaBinde,
        'bloklar': bloklar.toMap(),
        'asgariUcretTablolari':
            asgariUcretTablolari.map((e) => e.toMap()).toList(),
      };

  factory BeyannameKonfigurasyonu.fromMap(Map<String, dynamic> map) =>
      BeyannameKonfigurasyonu(
        kurumId: map['kurumId'] as String? ?? '',
        kdvOranlari: (map['kdvOranlari'] as List<dynamic>?)
                ?.map((e) =>
                    KdvOranTanimi.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            varsayilanKdvOranlari,
        tevkifatTurleri: (map['tevkifatTurleri'] as List<dynamic>?)
                ?.map((e) =>
                    TevkifatTanimi.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList() ??
            varsayilanTevkifatTurleri,
        damgaBinde:
            (map['damgaBinde'] as num?)?.toDouble() ?? varsayilanDamgaBinde,
        bloklar: map['bloklar'] != null
            ? BeyannameBloklari.fromMap(
                Map<String, dynamic>.from(map['bloklar'] as Map))
            : const BeyannameBloklari(),
        asgariUcretTablolari: (map['asgariUcretTablolari'] as List<dynamic>?)
                ?.map((e) => AsgariUcretYilTablosu.fromMap(
                    Map<String, dynamic>.from(e as Map)))
                .toList() ??
            const [],
      );
}
