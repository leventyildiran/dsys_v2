/// Personel aylık toplam hakediş takip modeli.
///
/// Firestore yolu: `personel/{personelId}/aylikToplamHakedis/{yilAy}`
/// EYDMA yasal tavan kontrolünde kullanılır.
class AylikHakedisModel {
  const AylikHakedisModel({
    required this.yilAy,
    this.donerSermaye = 0.0,
    this.ikinciOgretim = 0.0,
    this.toplam = 0.0,
  });

  /// Dönem anahtarı: "2026-04" formatında.
  final String yilAy;

  /// Döner sermaye gelirleri toplamı.
  final double donerSermaye;

  /// İkinci öğretim gelirleri toplamı.
  final double ikinciOgretim;

  /// Tüm gelir kaynaklarının toplamı.
  final double toplam;

  factory AylikHakedisModel.fromMap(String yilAy, Map<String, dynamic> map) {
    return AylikHakedisModel(
      yilAy: yilAy,
      donerSermaye: (map['donerSermaye'] as num?)?.toDouble() ?? 0.0,
      ikinciOgretim: (map['ikinciOgretim'] as num?)?.toDouble() ?? 0.0,
      toplam: (map['toplam'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'donerSermaye': donerSermaye,
      'ikinciOgretim': ikinciOgretim,
      'toplam': toplam,
    };
  }

  AylikHakedisModel copyWith({
    double? donerSermaye,
    double? ikinciOgretim,
    double? toplam,
  }) {
    return AylikHakedisModel(
      yilAy: yilAy,
      donerSermaye: donerSermaye ?? this.donerSermaye,
      ikinciOgretim: ikinciOgretim ?? this.ikinciOgretim,
      toplam: toplam ?? this.toplam,
    );
  }
}
