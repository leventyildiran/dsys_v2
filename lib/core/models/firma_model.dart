class FirmaModel {
  String id;
  String firmaAdi;
  String adres;
  String vergiDairesi;
  String vergiNo;

  FirmaModel({
    required this.id,
    required this.firmaAdi,
    this.adres = '',
    required this.vergiDairesi,
    required this.vergiNo,
  });

  factory FirmaModel.fromJson(Map<String, dynamic> json, String documentId) {
    return FirmaModel(
      id: documentId,
      firmaAdi: json['firmaAdi'] ?? json['unvan'] ?? '',
      adres: json['adres'] ?? '',
      vergiDairesi: json['vergiDairesi'] ?? '',
      vergiNo: json['vergiNo'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'firmaAdi': firmaAdi,
      'adres': adres,
      'vergiDairesi': vergiDairesi,
      'vergiNo': vergiNo,
    };
  }
}
