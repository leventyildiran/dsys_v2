class HizmetModel {
  String id;
  String birimAdi;
  String hizmetAdi;
  double fiyat;

  HizmetModel({
    required this.id,
    required this.birimAdi,
    required this.hizmetAdi,
    required this.fiyat,
  });

  factory HizmetModel.fromJson(Map<String, dynamic> json, String documentId) {
    return HizmetModel(
      id: documentId,
      birimAdi: json['birimAdi'] ?? '',
      hizmetAdi: json['hizmetAdi'] ?? '',
      fiyat: (json['fiyat'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'birimAdi': birimAdi,
      'hizmetAdi': hizmetAdi,
      'fiyat': fiyat,
    };
  }
}
