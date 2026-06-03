/// Akademik personel modeli.
class PersonelModel {
  const PersonelModel({
    required this.id,
    required this.tcKimlikNo,
    required this.adSoyad,
    required this.unvan,
    required this.unvanKatsayisi,
    required this.birimId,
    this.iban,
    this.aktif = true,
  });

  final String id;
  final String tcKimlikNo;
  final String adSoyad;
  final String unvan;
  final double unvanKatsayisi;
  final String birimId;
  final String? iban;
  final bool aktif;

  factory PersonelModel.fromMap(String id, Map<String, dynamic> map) {
    return PersonelModel(
      id: id,
      tcKimlikNo: map['tcKimlikNo'] as String? ?? '',
      adSoyad: map['adSoyad'] as String? ?? '',
      unvan: map['unvan'] as String? ?? '',
      unvanKatsayisi: (map['unvanKatsayisi'] as num?)?.toDouble() ?? 1.0,
      birimId: map['birimId'] as String? ?? '',
      iban: map['iban'] as String?,
      aktif: map['aktif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tcKimlikNo': tcKimlikNo,
      'adSoyad': adSoyad,
      'unvan': unvan,
      'unvanKatsayisi': unvanKatsayisi,
      'birimId': birimId,
      'iban': iban,
      'aktif': aktif,
    };
  }

  PersonelModel copyWith({
    String? tcKimlikNo,
    String? adSoyad,
    String? unvan,
    double? unvanKatsayisi,
    String? birimId,
    String? iban,
    bool? aktif,
  }) {
    return PersonelModel(
      id: id,
      tcKimlikNo: tcKimlikNo ?? this.tcKimlikNo,
      adSoyad: adSoyad ?? this.adSoyad,
      unvan: unvan ?? this.unvan,
      unvanKatsayisi: unvanKatsayisi ?? this.unvanKatsayisi,
      birimId: birimId ?? this.birimId,
      iban: iban ?? this.iban,
      aktif: aktif ?? this.aktif,
    );
  }
}
