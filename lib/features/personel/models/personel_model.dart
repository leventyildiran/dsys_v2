/// Üniversite personeli modeli (Akademik & İdari).
class PersonelModel {
  const PersonelModel({
    required this.id,
    this.tcKimlikNo = '',
    required this.adSoyad,
    this.unvan = '',
    this.unvanKatsayisi = 1.0,
    this.birimId = '',
    this.birimAdi,
    this.eposta,
    this.telefon,
    this.personelTuru = 'Akademik', // 'Akademik' | 'İdari'
    this.kaynak = 'manuel', // 'rehber' | 'manuel'
    this.rehberId,
    this.iban,
    this.aktif = true,
  });

  final String id;
  final String tcKimlikNo;
  final String adSoyad;
  final String unvan;
  final double unvanKatsayisi;
  final String birimId;
  final String? birimAdi;
  final String? eposta;
  final String? telefon;
  final String personelTuru;
  final String kaynak;
  final String? rehberId;
  final String? iban;
  final bool aktif;

  /// Ekranda listelenirken kullanılacak unvanlı etiket (Birim eklenmez, sadece unvan ve isim)
  String get tamAdGosterim {
    final u = unvan.trim();
    final ad = adSoyad.trim();
    return u.isNotEmpty ? '$u $ad' : ad;
  }

  /// Akademik unvana göre varsayılan katsayı türetir.
  static double varsayilanUnvanKatsayisi(String unvan) {
    final lower = unvan.trim().toLowerCase();
    if (lower.contains('prof')) return 3.0;
    if (lower.contains('doç') || lower.contains('doc')) return 2.5;
    if (lower.contains('dr. öğr') || lower.contains('dr.öğr') || lower.contains('öğretim üyesi') || lower.contains('ogretim uyesi') || lower.contains('yrd') || lower.contains('yard')) return 2.2;
    if (lower.contains('öğr') || lower.contains('ogr') || lower.contains('arş') || lower.contains('ars') || lower.contains('uzman') || lower.contains('okutman')) return 2.0;
    return 2.0;
  }

  factory PersonelModel.fromMap(String id, Map<String, dynamic> map) {
    final unvan = map['unvan'] as String? ?? '';
    final kayitli = (map['unvanKatsayisi'] as num?)?.toDouble();
    return PersonelModel(
      id: id,
      tcKimlikNo: map['tcKimlikNo'] as String? ?? '',
      adSoyad: map['adSoyad'] as String? ?? '',
      unvan: unvan,
      unvanKatsayisi: (kayitli != null && kayitli > 1.0)
          ? kayitli
          : varsayilanUnvanKatsayisi(unvan),
      birimId: map['birimId'] as String? ?? '',
      birimAdi: map['birimAdi'] as String?,
      eposta: map['eposta'] as String?,
      telefon: map['telefon'] as String?,
      personelTuru: map['personelTuru'] as String? ?? 'Akademik',
      kaynak: map['kaynak'] as String? ?? 'manuel',
      rehberId: map['rehberId'] as String?,
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
      if (birimAdi != null) 'birimAdi': birimAdi,
      if (eposta != null) 'eposta': eposta,
      if (telefon != null) 'telefon': telefon,
      'personelTuru': personelTuru,
      'kaynak': kaynak,
      if (rehberId != null) 'rehberId': rehberId,
      if (iban != null) 'iban': iban,
      'aktif': aktif,
    };
  }

  PersonelModel copyWith({
    String? tcKimlikNo,
    String? adSoyad,
    String? unvan,
    double? unvanKatsayisi,
    String? birimId,
    String? birimAdi,
    String? eposta,
    String? telefon,
    String? personelTuru,
    String? kaynak,
    String? rehberId,
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
      birimAdi: birimAdi ?? this.birimAdi,
      eposta: eposta ?? this.eposta,
      telefon: telefon ?? this.telefon,
      personelTuru: personelTuru ?? this.personelTuru,
      kaynak: kaynak ?? this.kaynak,
      rehberId: rehberId ?? this.rehberId,
      iban: iban ?? this.iban,
      aktif: aktif ?? this.aktif,
    );
  }
}
