/// Personel bazlı taksit dağıtım modeli.
///
/// Firestore yolu: `danismanliklar/{danismanlikId}/taksitler/{taksitId}/dagitim/{personelId}`
class DagitimModel {
  const DagitimModel({
    required this.personelId,
    required this.adSoyad,
    required this.unvan,
    required this.unvanKatsayisi,
    required this.ekGosterge,
    required this.faaliyetTuru,
    required this.faaliyetAdeti,
    required this.faaliyetTabanPuani,
    this.mesaiIci = true,
    required this.toplamPuan,
    required this.bireyselPuan,
    required this.brutHakedis,
    this.tavanKontrol = false,
    this.tavanLimitTutari,
    this.odenebilirHakedis,
    this.fazlalikHavuzTutari,
  });

  final String personelId;
  final String adSoyad;
  final String unvan;
  final double unvanKatsayisi;
  final int ekGosterge;
  final String faaliyetTuru;
  final int faaliyetAdeti;
  final double faaliyetTabanPuani;
  final bool mesaiIci;

  final double toplamPuan;
  final double bireyselPuan; // puan × unvan katsayısı
  final double brutHakedis; // bireyselPuan × ekOdemeKatsayisi
  final bool tavanKontrol; // EYDMA aşıyor mu?
  final double? tavanLimitTutari; // Devlete göre alınabilecek max tutar
  final double? odenebilirHakedis; // Kesintiden sonra yatan net tutar
  final double? fazlalikHavuzTutari; // Limite takılıp devlete kalan tutar

  factory DagitimModel.fromMap(String personelId, Map<String, dynamic> map) {
    return DagitimModel(
      personelId: personelId,
      adSoyad: map['adSoyad'] as String? ?? '',
      unvan: map['unvan'] as String? ?? '',
      unvanKatsayisi: (map['unvanKatsayisi'] as num?)?.toDouble() ?? 1.0,
      ekGosterge: (map['ekGosterge'] as num?)?.toInt() ?? 160,
      faaliyetTuru: map['faaliyetTuru'] as String? ?? 'Belirtilmedi',
      faaliyetAdeti: (map['faaliyetAdeti'] as num?)?.toInt() ?? 1,
      faaliyetTabanPuani: (map['faaliyetTabanPuani'] as num?)?.toDouble() ?? 0.0,
      mesaiIci: map['mesaiIci'] as bool? ?? true,
      toplamPuan: (map['toplamPuan'] as num?)?.toDouble() ?? 0.0,
      bireyselPuan: (map['bireyselPuan'] as num?)?.toDouble() ?? 0.0,
      brutHakedis: (map['brutHakedis'] as num?)?.toDouble() ?? 0.0,
      tavanKontrol: map['tavanKontrol'] as bool? ?? false,
      tavanLimitTutari: (map['tavanLimitTutari'] as num?)?.toDouble(),
      odenebilirHakedis: (map['odenebilirHakedis'] as num?)?.toDouble(),
      fazlalikHavuzTutari: (map['fazlalikHavuzTutari'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'adSoyad': adSoyad,
      'unvan': unvan,
      'unvanKatsayisi': unvanKatsayisi,
      'ekGosterge': ekGosterge,
      'faaliyetTuru': faaliyetTuru,
      'faaliyetAdeti': faaliyetAdeti,
      'faaliyetTabanPuani': faaliyetTabanPuani,
      'mesaiIci': mesaiIci,
      'toplamPuan': toplamPuan,
      'bireyselPuan': bireyselPuan,
      'brutHakedis': brutHakedis,
      'tavanKontrol': tavanKontrol,
      'tavanLimitTutari': tavanLimitTutari,
      'odenebilirHakedis': odenebilirHakedis,
      'fazlalikHavuzTutari': fazlalikHavuzTutari,
    };
  }
}
