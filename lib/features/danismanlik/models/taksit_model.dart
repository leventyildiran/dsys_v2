import 'danismanlik_model.dart';

/// Taksit durumu enum tanımı.
enum TaksitDurum {
  taslak('taslak', 'Taslak (Bekliyor)'),
  faturaKesildi('fatura_kesildi', 'Fatura Kesildi'),
  paraGeldi('para_geldi', 'Para Kuruma Geldi'),
  dagitimHesaplandi('dagitim_hesaplandi', 'Dağıtım Hesaplandı'),
  ykOnaylandi('yk_onaylandi', 'YKK Onaylandı'),
  odendi('odendi', 'Hocalara Ödendi'),
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

extension TaksitDurumExtension on TaksitDurum {
  String getDisplayName(DanismanlikTuru tur) {
    switch (this) {
      case TaksitDurum.faturaKesildi:
        if (tur == DanismanlikTuru.egitimKuru) return 'Tahsilat/Dekont Geldi';
        return 'Fatura Kesildi';
      case TaksitDurum.paraGeldi:
        if (tur == DanismanlikTuru.egitimKuru) return 'Bütçe Toplandı';
        return 'Para Kuruma Geldi';
      case TaksitDurum.dagitimHesaplandi:
        return 'Dağıtım Hesaplandı';
      case TaksitDurum.odendi:
        return 'Hocalara Ödendi';
      default:
        return displayName;
    }
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
    this.ykKararTarihi,
    this.ykToplantiSayisi,
    this.ykKararNo,
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

  // Evrak bilgileri (BYK)
  final String? birimEvrakTarihi;
  final String? birimEvrakSayisi;
  final String? birimKurulTarihi;
  final String? birimToplantiSayisi;
  final String? birimKararNo;

  // Evrak bilgileri (YKK)
  final String? ykKararTarihi;
  final String? ykToplantiSayisi;
  final String? ykKararNo;

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
      ykKararTarihi: map['ykKararTarihi'] as String?,
      ykToplantiSayisi: map['ykToplantiSayisi'] as String?,
      ykKararNo: map['ykKararNo'] as String?,
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
      'ykKararTarihi': ykKararTarihi,
      'ykToplantiSayisi': ykToplantiSayisi,
      'ykKararNo': ykKararNo,
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
    String? ykKararTarihi,
    String? ykToplantiSayisi,
    String? ykKararNo,
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
      ykKararTarihi: ykKararTarihi ?? this.ykKararTarihi,
      ykToplantiSayisi: ykToplantiSayisi ?? this.ykToplantiSayisi,
      ykKararNo: ykKararNo ?? this.ykKararNo,
      hazinePayi: hazinePayi ?? this.hazinePayi,
      bapPayi: bapPayi ?? this.bapPayi,
      aracGerecPayi: aracGerecPayi ?? this.aracGerecPayi,
      dagitilabilirTutar: dagitilabilirTutar ?? this.dagitilabilirTutar,
      toplamPuan: toplamPuan ?? this.toplamPuan,
      ekOdemeKatsayisi: ekOdemeKatsayisi ?? this.ekOdemeKatsayisi,
    );
  }
}
