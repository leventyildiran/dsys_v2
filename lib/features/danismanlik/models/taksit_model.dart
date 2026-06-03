/// Taksit durumu enum tanımı.
enum TaksitDurum {
  taslak('taslak', 'Taslak'),
  mudurOnayinda('mudur_onayinda', 'Müdür Onayında'),
  merkezOnayinda('merkez_onayinda', 'Merkez Onayında'),
  ykGundeminde('yk_gundeminde', 'YK Gündeminde'),
  onaylandi('onaylandi', 'Onaylandı'),
  odendi('odendi', 'Ödendi'),
  gecikti('gecikti', 'Gecikti');

  const TaksitDurum(this.value, this.displayName);
  final String value;
  final String displayName;

  static TaksitDurum fromString(String value) {
    return TaksitDurum.values.firstWhere(
      (t) => t.value == value,
      orElse: () => TaksitDurum.taslak,
    );
  }
}

/// Aylık taksit modeli.
class TaksitModel {
  const TaksitModel({
    required this.id,
    required this.ayNo,
    required this.brutTutar,
    this.durum = TaksitDurum.taslak,
    this.odemeTarihi,
    this.birimEvrakTarihi,
    this.birimEvrakSayisi,
    this.birimKurulTarihi,
    this.birimToplantiSayisi,
    this.birimKararNo,
    this.hazinePayi,
    this.bapPayi,
    this.aracGerecPayi,
    this.dagitilabilirTutar,
    this.toplamPuan,
    this.ekOdemeKatsayisi,
  });

  final String id;
  final int ayNo;
  final double brutTutar;
  final TaksitDurum durum;
  final DateTime? odemeTarihi;

  // Evrak bilgileri
  final String? birimEvrakTarihi;
  final String? birimEvrakSayisi;
  final String? birimKurulTarihi;
  final String? birimToplantiSayisi;
  final String? birimKararNo;

  // Hesaplama sonuçları
  final double? hazinePayi;
  final double? bapPayi;
  final double? aracGerecPayi;
  final double? dagitilabilirTutar;
  final double? toplamPuan;
  final double? ekOdemeKatsayisi;

  factory TaksitModel.fromMap(String id, Map<String, dynamic> map) {
    return TaksitModel(
      id: id,
      ayNo: (map['ayNo'] as num?)?.toInt() ?? 0,
      brutTutar: (map['brutTutar'] as num?)?.toDouble() ?? 0.0,
      durum: TaksitDurum.fromString(map['durum'] as String? ?? ''),
      odemeTarihi: map['odemeTarihi'] != null
          ? DateTime.tryParse(map['odemeTarihi'] as String)
          : null,
      birimEvrakTarihi: map['birimEvrakTarihi'] as String?,
      birimEvrakSayisi: map['birimEvrakSayisi'] as String?,
      birimKurulTarihi: map['birimKurulTarihi'] as String?,
      birimToplantiSayisi: map['birimToplantiSayisi'] as String?,
      birimKararNo: map['birimKararNo'] as String?,
      hazinePayi: (map['hazinePayi'] as num?)?.toDouble(),
      bapPayi: (map['bapPayi'] as num?)?.toDouble(),
      aracGerecPayi: (map['aracGerecPayi'] as num?)?.toDouble(),
      dagitilabilirTutar: (map['dagitilabilirTutar'] as num?)?.toDouble(),
      toplamPuan: (map['toplamPuan'] as num?)?.toDouble(),
      ekOdemeKatsayisi: (map['ekOdemeKatsayisi'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ayNo': ayNo,
      'brutTutar': brutTutar,
      'durum': durum.value,
      'odemeTarihi': odemeTarihi?.toIso8601String(),
      'birimEvrakTarihi': birimEvrakTarihi,
      'birimEvrakSayisi': birimEvrakSayisi,
      'birimKurulTarihi': birimKurulTarihi,
      'birimToplantiSayisi': birimToplantiSayisi,
      'birimKararNo': birimKararNo,
      'hazinePayi': hazinePayi,
      'bapPayi': bapPayi,
      'aracGerecPayi': aracGerecPayi,
      'dagitilabilirTutar': dagitilabilirTutar,
      'toplamPuan': toplamPuan,
      'ekOdemeKatsayisi': ekOdemeKatsayisi,
    };
  }

  TaksitModel copyWith({
    int? ayNo,
    double? brutTutar,
    TaksitDurum? durum,
    DateTime? odemeTarihi,
    String? birimEvrakTarihi,
    String? birimEvrakSayisi,
    String? birimKurulTarihi,
    String? birimToplantiSayisi,
    String? birimKararNo,
    double? hazinePayi,
    double? bapPayi,
    double? aracGerecPayi,
    double? dagitilabilirTutar,
    double? toplamPuan,
    double? ekOdemeKatsayisi,
  }) {
    return TaksitModel(
      id: id,
      ayNo: ayNo ?? this.ayNo,
      brutTutar: brutTutar ?? this.brutTutar,
      durum: durum ?? this.durum,
      odemeTarihi: odemeTarihi ?? this.odemeTarihi,
      birimEvrakTarihi: birimEvrakTarihi ?? this.birimEvrakTarihi,
      birimEvrakSayisi: birimEvrakSayisi ?? this.birimEvrakSayisi,
      birimKurulTarihi: birimKurulTarihi ?? this.birimKurulTarihi,
      birimToplantiSayisi: birimToplantiSayisi ?? this.birimToplantiSayisi,
      birimKararNo: birimKararNo ?? this.birimKararNo,
      hazinePayi: hazinePayi ?? this.hazinePayi,
      bapPayi: bapPayi ?? this.bapPayi,
      aracGerecPayi: aracGerecPayi ?? this.aracGerecPayi,
      dagitilabilirTutar: dagitilabilirTutar ?? this.dagitilabilirTutar,
      toplamPuan: toplamPuan ?? this.toplamPuan,
      ekOdemeKatsayisi: ekOdemeKatsayisi ?? this.ekOdemeKatsayisi,
    );
  }
}
