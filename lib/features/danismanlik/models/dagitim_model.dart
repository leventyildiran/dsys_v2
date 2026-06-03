/// Personel bazlı taksit dağıtım modeli.
///
/// Firestore yolu: `danismanliklar/{danismanlikId}/taksitler/{taksitId}/dagitim/{personelId}`
class DagitimModel {
  const DagitimModel({
    required this.personelId,
    required this.adSoyad,
    required this.unvan,
    required this.unvanKatsayisi,
    required this.toplamPuan,
    required this.bireyselPuan,
    required this.brutHakedis,
    this.tavanKontrol = false,
    this.odenebilirHakedis,
    this.fazlalikHavuzTutari,
  });

  final String personelId;
  final String adSoyad;
  final String unvan;
  final double unvanKatsayisi;
  final double toplamPuan;
  final double bireyselPuan; // puan × unvan katsayısı
  final double brutHakedis; // bireyselPuan × ekOdemeKatsayisi
  final bool tavanKontrol; // EYDMA aşıyor mu?
  final double? odenebilirHakedis;
  final double? fazlalikHavuzTutari;

  factory DagitimModel.fromMap(String personelId, Map<String, dynamic> map) {
    return DagitimModel(
      personelId: personelId,
      adSoyad: map['adSoyad'] as String? ?? '',
      unvan: map['unvan'] as String? ?? '',
      unvanKatsayisi: (map['unvanKatsayisi'] as num?)?.toDouble() ?? 1.0,
      toplamPuan: (map['toplamPuan'] as num?)?.toDouble() ?? 0.0,
      bireyselPuan: (map['bireyselPuan'] as num?)?.toDouble() ?? 0.0,
      brutHakedis: (map['brutHakedis'] as num?)?.toDouble() ?? 0.0,
      tavanKontrol: map['tavanKontrol'] as bool? ?? false,
      odenebilirHakedis: (map['odenebilirHakedis'] as num?)?.toDouble(),
      fazlalikHavuzTutari: (map['fazlalikHavuzTutari'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adSoyad': adSoyad,
      'unvan': unvan,
      'unvanKatsayisi': unvanKatsayisi,
      'toplamPuan': toplamPuan,
      'bireyselPuan': bireyselPuan,
      'brutHakedis': brutHakedis,
      'tavanKontrol': tavanKontrol,
      'odenebilirHakedis': odenebilirHakedis,
      'fazlalikHavuzTutari': fazlalikHavuzTutari,
    };
  }
}
