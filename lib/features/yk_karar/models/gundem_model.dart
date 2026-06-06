/// Toplantı gündem modeli.
///
/// Yürütme Kurulu toplantı gündeminin karar maddelerini yönetir.
/// Firestore yolu: `toplantilar/{toplantiId}`
class ToplantiModel {
  const ToplantiModel({
    required this.id,
    required this.toplantiTarihi,
    required this.toplantiNo,
    this.gundemMaddeleri = const [],
    this.durum = ToplantiDurum.taslak,
    this.olusturmaTarihi,
    this.pdfUrls = const [],
  });

  final String id;
  final String toplantiTarihi;
  final String toplantiNo;
  final List<GundemMaddesi> gundemMaddeleri;
  final ToplantiDurum durum;
  final DateTime? olusturmaTarihi;
  final List<String> pdfUrls;

  factory ToplantiModel.fromMap(String id, Map<String, dynamic> map) {
    final maddelerData = map['gundemMaddeleri'] as List<dynamic>? ?? [];
    final pdfUrlsData = map['pdfUrls'] as List<dynamic>? ?? [];
    return ToplantiModel(
      id: id,
      toplantiTarihi: map['toplantiTarihi'] ?? '',
      toplantiNo: map['toplantiNo'] ?? '',
      gundemMaddeleri: maddelerData
          .map((m) => GundemMaddesi.fromMap(m as Map<String, dynamic>))
          .toList(),
      durum: ToplantiDurum.fromString(map['durum'] ?? 'taslak'),
      olusturmaTarihi: map['olusturmaTarihi'] != null
          ? DateTime.tryParse(map['olusturmaTarihi'])
          : null,
      pdfUrls: List<String>.from(pdfUrlsData),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'toplantiTarihi': toplantiTarihi,
      'toplantiNo': toplantiNo,
      'gundemMaddeleri': gundemMaddeleri.map((m) => m.toMap()).toList(),
      'durum': durum.value,
      'olusturmaTarihi': olusturmaTarihi?.toIso8601String(),
      'pdfUrls': pdfUrls,
    };
  }

  ToplantiModel copyWith({
    String? toplantiTarihi,
    String? toplantiNo,
    List<GundemMaddesi>? gundemMaddeleri,
    ToplantiDurum? durum,
    List<String>? pdfUrls,
  }) {
    return ToplantiModel(
      id: id,
      toplantiTarihi: toplantiTarihi ?? this.toplantiTarihi,
      toplantiNo: toplantiNo ?? this.toplantiNo,
      gundemMaddeleri: gundemMaddeleri ?? this.gundemMaddeleri,
      durum: durum ?? this.durum,
      olusturmaTarihi: olusturmaTarihi,
      pdfUrls: pdfUrls ?? this.pdfUrls,
    );
  }
}

/// Tek bir gündem maddesi.
class GundemMaddesi {
  const GundemMaddesi({
    required this.siraNo,
    required this.baslik,
    required this.tur,
    this.aciklama,
    this.birimId,
    this.birimAd,
    this.iliskiliKayitId,
  });

  final int siraNo;
  final String baslik;
  final GundemTuru tur;
  final String? aciklama;
  final String? birimId;
  final String? birimAd;
  final String? iliskiliKayitId; // Danışmanlık, bütçe aktarım vb. ID

  factory GundemMaddesi.fromMap(Map<String, dynamic> map) {
    return GundemMaddesi(
      siraNo: map['siraNo'] ?? 0,
      baslik: map['baslik'] ?? '',
      tur: GundemTuru.fromString(map['tur'] ?? 'diger'),
      aciklama: map['aciklama'],
      birimId: map['birimId'],
      birimAd: map['birimAd'],
      iliskiliKayitId: map['iliskiliKayitId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'siraNo': siraNo,
      'baslik': baslik,
      'tur': tur.value,
      'aciklama': aciklama,
      'birimId': birimId,
      'birimAd': birimAd,
      'iliskiliKayitId': iliskiliKayitId,
    };
  }

  GundemMaddesi copyWith({
    int? siraNo,
    String? baslik,
    GundemTuru? tur,
    String? aciklama,
    String? birimId,
    String? birimAd,
    String? iliskiliKayitId,
  }) {
    return GundemMaddesi(
      siraNo: siraNo ?? this.siraNo,
      baslik: baslik ?? this.baslik,
      tur: tur ?? this.tur,
      aciklama: aciklama ?? this.aciklama,
      birimId: birimId ?? this.birimId,
      birimAd: birimAd ?? this.birimAd,
      iliskiliKayitId: iliskiliKayitId ?? this.iliskiliKayitId,
    );
  }
}

/// Gündem maddesi türleri.
enum GundemTuru {
  danismanlik('danismanlik', 'Danışmanlık'),
  butceAktarim('butce_aktarim', 'Bütçe Aktarım'),
  ekOdeme('ek_odeme', 'Ek Ödeme'),
  disHekimligi('dis_hekimligi', 'Diş Hekimliği'),
  kursUcreti('kurs_ucreti', 'Kurs Ücreti'),
  diger('diger', 'Diğer');

  const GundemTuru(this.value, this.displayName);
  final String value;
  final String displayName;

  static GundemTuru fromString(String value) {
    return GundemTuru.values.firstWhere(
      (e) => e.value == value,
      orElse: () => GundemTuru.diger,
    );
  }
}

/// Toplantı durumları.
enum ToplantiDurum {
  taslak('taslak', 'Taslak'),
  hazirlaniyor('hazirlaniyor', 'Hazırlanıyor'),
  tamamlandi('tamamlandi', 'Tamamlandı');

  const ToplantiDurum(this.value, this.displayName);
  final String value;
  final String displayName;

  static ToplantiDurum fromString(String value) {
    return ToplantiDurum.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ToplantiDurum.taslak,
    );
  }
}
