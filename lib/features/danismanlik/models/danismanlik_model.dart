import '../../personel/models/personel_model.dart';

/// Danışmanlık türü enum tanımı.
enum DanismanlikTuru {
  standart('standart', 'Standart Danışmanlık'),
  sanayiIsbirligi58k('sanayi_isbirligi_58k', 'Sanayi İşbirliği (58/k)');

  const DanismanlikTuru(this.value, this.displayName);
  final String value;
  final String displayName;

  static DanismanlikTuru fromString(String value) {
    return DanismanlikTuru.values.firstWhere(
      (t) => t.value == value,
      orElse: () => DanismanlikTuru.standart,
    );
  }
}

/// Danışmanlık durumu enum tanımı.
enum DanismanlikDurum {
  bekliyor('bekliyor', 'Bekliyor'),
  aktif('aktif', 'Aktif'),
  tamamlandi('tamamlandi', 'Tamamlandı'),
  iptal('iptal', 'İptal');

  const DanismanlikDurum(this.value, this.displayName);
  final String value;
  final String displayName;

  static DanismanlikDurum fromString(String value) {
    return DanismanlikDurum.values.firstWhere(
      (t) => t.value == value,
      orElse: () => DanismanlikDurum.bekliyor,
    );
  }
}

/// Personel görev atama modeli.
class PersonelGorevAtama {
  PersonelGorevAtama({
    required this.personel,
    this.payOrani = 100,
    this.faaliyetPuani = 0,
    this.dersSaati = 1,
    this.mesaiIci = true,
    this.faaliyetTuru,
  });

  final PersonelModel personel;
  int payOrani;
  double faaliyetPuani;
  double dersSaati;
  bool mesaiIci;
  String? faaliyetTuru;

  Map<String, dynamic> toMap() {
    return {
      'personel': personel.toMap(),
      'payOrani': payOrani,
      'faaliyetPuani': faaliyetPuani,
      'dersSaati': dersSaati,
      'mesaiIci': mesaiIci,
      'faaliyetTuru': faaliyetTuru,
    };
  }

  factory PersonelGorevAtama.fromMap(Map<String, dynamic> map) {
    return PersonelGorevAtama(
      personel: PersonelModel.fromMap(
        map['personel']['id'] ?? '',
        map['personel'],
      ),
      payOrani: (map['payOrani'] as num?)?.toInt() ?? 100,
      faaliyetPuani: (map['faaliyetPuani'] as num?)?.toDouble() ?? 0,
      dersSaati: (map['dersSaati'] as num?)?.toDouble() ?? 1,
      mesaiIci: map['mesaiIci'] as bool? ?? true,
      faaliyetTuru: map['faaliyetTuru'] as String?,
    );
  }
}

/// Ana danışmanlık modeli.
class DanismanlikModel {
  const DanismanlikModel({
    required this.id,
    required this.birimId,
    required this.firmaId,
    this.firmaUnvan,
    this.birimKisaAd,
    required this.danismanlikTuru,
    required this.konusu,
    required this.toplamTutar,
    required this.kdvOrani,
    required this.suresi,
    this.baslangicTarihi,
    this.bitisTarihi,
    this.durum = DanismanlikDurum.bekliyor,
    this.ykKararId,
    this.ykKararTarihi,
    this.ykKararNo,
    this.ykToplantiSayisi,
    this.birimKararTarihi,
    this.birimKararNo,
    this.birimToplantiSayisi,
    this.dagitimYkKararTarihi,
    this.dagitimYkKararNo,
    this.dagitimYkToplantiSayisi,
    this.hazinePayiOrani = 1,
    this.bapPayiOrani = 5,
    this.aracGerecPayiOrani = 45,
    this.dagitilabilirOran = 49,
    this.personeller = const [],
    this.createdAt,
  });

  final String id;
  final String birimId;
  final String firmaId;
  final String? firmaUnvan;
  final String? birimKisaAd;
  final DanismanlikTuru danismanlikTuru;
  final String konusu;
  final double toplamTutar;
  final int kdvOrani;
  final int suresi; // ay
  final DateTime? baslangicTarihi;
  final DateTime? bitisTarihi;
  final DanismanlikDurum durum;
  final String? ykKararId;

  // Çatı karar bilgileri (Sözleşme YKK)
  final String? ykKararTarihi;
  final String? ykKararNo;
  final String? ykToplantiSayisi;

  // Birim Yönetim Kurulu Karar Bilgileri
  final String? birimKararTarihi;
  final String? birimKararNo;
  final String? birimToplantiSayisi;

  // Dağıtım Onayı YKK Bilgileri
  final String? dagitimYkKararTarihi;
  final String? dagitimYkKararNo;
  final String? dagitimYkToplantiSayisi;

  // Kesinti oranları (standart tür için)
  final int hazinePayiOrani;
  final int bapPayiOrani;
  final int aracGerecPayiOrani;
  final int dagitilabilirOran;

  final List<PersonelGorevAtama> personeller;

  final DateTime? createdAt;

  DanismanlikTuru get tur => danismanlikTuru;

  factory DanismanlikModel.fromMap(String id, Map<String, dynamic> map) {
    return DanismanlikModel(
      id: id,
      birimId: map['birimId'] as String? ?? '',
      firmaId: map['firmaId'] as String? ?? '',
      firmaUnvan: map['firmaUnvan'] as String?,
      birimKisaAd: map['birimKisaAd'] as String?,
      danismanlikTuru: DanismanlikTuru.fromString(
        map['danismanlikTuru'] as String? ?? '',
      ),
      konusu: map['konusu'] as String? ?? '',
      toplamTutar: (map['toplamTutar'] as num?)?.toDouble() ?? 0.0,
      kdvOrani: (map['kdvOrani'] as num?)?.toInt() ?? 20,
      suresi: (map['suresi'] as num?)?.toInt() ?? 0,
      baslangicTarihi: map['baslangicTarihi'] != null
          ? DateTime.tryParse(map['baslangicTarihi'] as String)
          : null,
      bitisTarihi: map['bitisTarihi'] != null
          ? DateTime.tryParse(map['bitisTarihi'] as String)
          : null,
      durum: DanismanlikDurum.fromString(map['durum'] as String? ?? ''),
      ykKararId: map['ykKararId'] as String?,
      ykKararTarihi: map['ykKararTarihi'] as String?,
      ykKararNo: map['ykKararNo'] as String?,
      ykToplantiSayisi: map['ykToplantiSayisi'] as String?,
      birimKararTarihi: map['birimKararTarihi'] as String?,
      birimKararNo: map['birimKararNo'] as String?,
      birimToplantiSayisi: map['birimToplantiSayisi'] as String?,
      dagitimYkKararTarihi: map['dagitimYkKararTarihi'] as String?,
      dagitimYkKararNo: map['dagitimYkKararNo'] as String?,
      dagitimYkToplantiSayisi: map['dagitimYkToplantiSayisi'] as String?,
      hazinePayiOrani: (map['hazinePayiOrani'] as num?)?.toInt() ?? 1,
      bapPayiOrani: (map['bapPayiOrani'] as num?)?.toInt() ?? 5,
      aracGerecPayiOrani: (map['aracGerecPayiOrani'] as num?)?.toInt() ?? 45,
      dagitilabilirOran: (map['dagitilabilirOran'] as num?)?.toInt() ?? 49,
      personeller:
          (map['personeller'] as List<dynamic>?)
              ?.map(
                (e) => PersonelGorevAtama.fromMap(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String)
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'birimId': birimId,
      'firmaId': firmaId,
      'firmaUnvan': firmaUnvan,
      'birimKisaAd': birimKisaAd,
      'danismanlikTuru': danismanlikTuru.value,
      'konusu': konusu,
      'toplamTutar': toplamTutar,
      'kdvOrani': kdvOrani,
      'suresi': suresi,
      'baslangicTarihi': baslangicTarihi?.toIso8601String(),
      'bitisTarihi': bitisTarihi?.toIso8601String(),
      'durum': durum.value,
      'ykKararId': ykKararId,
      'ykKararTarihi': ykKararTarihi,
      'ykKararNo': ykKararNo,
      'ykToplantiSayisi': ykToplantiSayisi,
      'birimKararTarihi': birimKararTarihi,
      'birimKararNo': birimKararNo,
      'birimToplantiSayisi': birimToplantiSayisi,
      'dagitimYkKararTarihi': dagitimYkKararTarihi,
      'dagitimYkKararNo': dagitimYkKararNo,
      'dagitimYkToplantiSayisi': dagitimYkToplantiSayisi,
      'hazinePayiOrani': hazinePayiOrani,
      'bapPayiOrani': bapPayiOrani,
      'aracGerecPayiOrani': aracGerecPayiOrani,
      'dagitilabilirOran': dagitilabilirOran,
      'personeller': personeller.map((e) => e.toMap()).toList(),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  DanismanlikModel copyWith({
    String? id,
    String? birimId,
    String? firmaId,
    String? firmaUnvan,
    String? birimKisaAd,
    DanismanlikTuru? danismanlikTuru,
    String? konusu,
    double? toplamTutar,
    int? kdvOrani,
    int? suresi,
    DateTime? baslangicTarihi,
    DateTime? bitisTarihi,
    DanismanlikDurum? durum,
    String? ykKararId,
    String? ykKararTarihi,
    String? ykKararNo,
    String? ykToplantiSayisi,
    String? birimKararTarihi,
    String? birimKararNo,
    String? birimToplantiSayisi,
    String? dagitimYkKararTarihi,
    String? dagitimYkKararNo,
    String? dagitimYkToplantiSayisi,
    int? hazinePayiOrani,
    int? bapPayiOrani,
    int? aracGerecPayiOrani,
    int? dagitilabilirOran,
    List<PersonelGorevAtama>? personeller,
    DateTime? createdAt,
  }) {
    return DanismanlikModel(
      id: id ?? this.id,
      birimId: birimId ?? this.birimId,
      firmaId: firmaId ?? this.firmaId,
      firmaUnvan: firmaUnvan ?? this.firmaUnvan,
      birimKisaAd: birimKisaAd ?? this.birimKisaAd,
      danismanlikTuru: danismanlikTuru ?? this.danismanlikTuru,
      konusu: konusu ?? this.konusu,
      toplamTutar: toplamTutar ?? this.toplamTutar,
      kdvOrani: kdvOrani ?? this.kdvOrani,
      suresi: suresi ?? this.suresi,
      baslangicTarihi: baslangicTarihi ?? this.baslangicTarihi,
      bitisTarihi: bitisTarihi ?? this.bitisTarihi,
      durum: durum ?? this.durum,
      ykKararId: ykKararId ?? this.ykKararId,
      ykKararTarihi: ykKararTarihi ?? this.ykKararTarihi,
      ykKararNo: ykKararNo ?? this.ykKararNo,
      ykToplantiSayisi: ykToplantiSayisi ?? this.ykToplantiSayisi,
      birimKararTarihi: birimKararTarihi ?? this.birimKararTarihi,
      birimKararNo: birimKararNo ?? this.birimKararNo,
      birimToplantiSayisi: birimToplantiSayisi ?? this.birimToplantiSayisi,
      dagitimYkKararTarihi: dagitimYkKararTarihi ?? this.dagitimYkKararTarihi,
      dagitimYkKararNo: dagitimYkKararNo ?? this.dagitimYkKararNo,
      dagitimYkToplantiSayisi:
          dagitimYkToplantiSayisi ?? this.dagitimYkToplantiSayisi,
      hazinePayiOrani: hazinePayiOrani ?? this.hazinePayiOrani,
      bapPayiOrani: bapPayiOrani ?? this.bapPayiOrani,
      aracGerecPayiOrani: aracGerecPayiOrani ?? this.aracGerecPayiOrani,
      dagitilabilirOran: dagitilabilirOran ?? this.dagitilabilirOran,
      personeller: personeller ?? this.personeller,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
