// Hizmet Tipi seçenekleri
const fHizmetTipleri = [
  'EĞİTİM',
  'DANIŞMANLIK',
  'SATIŞ',
  'ANALİZ',
  'TEKSTİL_TASARIM',
  'DİĞER'
];

// Ödeme Tipi (TÖMER/USEM vb.)
const fOdemeTipleri = [
  'KUR_FATURA',
  'STS_FATURA',
  'KATKI_PAYI',
  'AVANS',
  'DİĞER'
];

// Ürün Türü (Tarımsal)
const fUrunTurleri = ['YUMURTA', 'BAL', 'TAVUK', 'DİĞER'];

// Tedarik Yöntemi (Satın Alma)
const fTedarikYontemleri = ['TEK_KAYNAK', 'İHALE', 'PAZARLIK', 'DİĞER'];

class FaturaModel {
  String id;
  String firmaAdi;
  String adres;
  String vergiDairesi;
  String vergiNo;
  String tarih;
  String irsaliyeNo;
  String melbesNo;
  String numuneNo;
  String numuneAciklamasi;
  List<Map<String, dynamic>> kalemler;
  bool isKdvMuaf;
  double matrah;
  double kdvOrani;
  double kdvTutari;
  double genelToplam;
  String parsedBy;
  String? iban;
  String? hesapAdi;

  // Yeni Dinamik Alanlar
  String? hizmetTipi;
  String? kursAdi;
  int? kurNo;
  String? odemeTipi;
  bool ytbOgrencisi;
  bool isVergiIstisnasi;
  String? urunTuru;
  String? tedarikYontemi;
  String? donem;
  String? aciklama;

  FaturaModel({
    required this.id,
    required this.firmaAdi,
    required this.adres,
    required this.vergiDairesi,
    required this.vergiNo,
    required this.tarih,
    required this.irsaliyeNo,
    required this.melbesNo,
    required this.numuneNo,
    required this.numuneAciklamasi,
    required this.kalemler,
    required this.isKdvMuaf,
    required this.matrah,
    required this.kdvOrani,
    required this.kdvTutari,
    required this.genelToplam,
    this.parsedBy = 'AI Parser',
    this.iban,
    this.hesapAdi,
    this.hizmetTipi,
    this.kursAdi,
    this.kurNo,
    this.odemeTipi,
    this.ytbOgrencisi = false,
    this.isVergiIstisnasi = false,
    this.urunTuru,
    this.tedarikYontemi,
    this.donem,
    this.aciklama,
  });

  bool get kaydaHazir =>
      firmaAdi.trim().isNotEmpty &&
      kalemler.isNotEmpty &&
      iban != null &&
      iban!.trim().isNotEmpty &&
      hesapAdi != null &&
      hesapAdi!.trim().isNotEmpty;

  List<String> eksikAlanlar() {
    final eksik = <String>[];
    if (firmaAdi.trim().isEmpty) eksik.add('Firma Adı');
    if (melbesNo.trim().isEmpty) eksik.add('MELBES No');
    if (numuneNo.trim().isEmpty) eksik.add('Numune No');
    if (tarih.trim().isEmpty) eksik.add('Tarih');
    if (iban == null || iban!.trim().isEmpty) eksik.add('IBAN');
    if (hesapAdi == null || hesapAdi!.trim().isEmpty) eksik.add('Hesap Adı');
    if (kalemler.isEmpty) eksik.add('En az 1 kalem');
    return eksik;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firmaAdi': firmaAdi,
      'adres': adres,
      'vergiDairesi': vergiDairesi,
      'vergiNo': vergiNo,
      'tarih': tarih,
      'irsaliyeNo': irsaliyeNo,
      'melbesNo': melbesNo,
      'numuneNo': numuneNo,
      'numuneAciklamasi': numuneAciklamasi,
      'kalemler': kalemler,
      'isKdvMuaf': isKdvMuaf,
      'matrah': matrah,
      'kdvOrani': kdvOrani,
      'kdvTutari': kdvTutari,
      'genelToplam': genelToplam,
      'parsedBy': parsedBy,
      'iban': iban,
      'hesapAdi': hesapAdi,
      'hizmetTipi': hizmetTipi,
      'kursAdi': kursAdi,
      'kurNo': kurNo,
      'odemeTipi': odemeTipi,
      'ytbOgrencisi': ytbOgrencisi,
      'isVergiIstisnasi': isVergiIstisnasi,
      'urunTuru': urunTuru,
      'tedarikYontemi': tedarikYontemi,
      'donem': donem,
      'aciklama': aciklama,
    };
  }

  factory FaturaModel.fromJson(Map<String, dynamic> json) {
    return FaturaModel(
      id: json['id']?.toString() ?? '',
      firmaAdi: json['firmaAdi']?.toString() ?? '',
      adres: json['adres']?.toString() ?? '',
      vergiDairesi: json['vergiDairesi']?.toString() ?? '',
      vergiNo: json['vergiNo']?.toString() ?? '',
      tarih: json['tarih']?.toString() ?? '',
      irsaliyeNo: json['irsaliyeNo']?.toString() ?? '',
      melbesNo: json['melbesNo']?.toString() ?? '',
      numuneNo: json['numuneNo']?.toString() ?? '',
      numuneAciklamasi: json['numuneAciklamasi']?.toString() ?? '',
      matrah: (json['matrah'] as num?)?.toDouble() ?? 0.0,
      kdvTutari: (json['kdvTutari'] as num?)?.toDouble() ?? 0.0,
      genelToplam: (json['genelToplam'] as num?)?.toDouble() ?? 0.0,
      isKdvMuaf: json['isKdvMuaf'] == true,
      kdvOrani: (json['kdvOrani'] as num?)?.toDouble() ?? 20,
      parsedBy: json['parsedBy']?.toString() ?? 'Bilinmiyor',
      iban: json['iban']?.toString(),
      hesapAdi: json['hesapAdi']?.toString(),
      hizmetTipi: json['hizmetTipi']?.toString(),
      kursAdi: json['kursAdi']?.toString(),
      kurNo: json['kurNo'] != null ? int.tryParse(json['kurNo'].toString()) : null,
      odemeTipi: json['odemeTipi']?.toString(),
      ytbOgrencisi: json['ytbOgrencisi'] == true,
      isVergiIstisnasi: json['isVergiIstisnasi'] == true,
      urunTuru: json['urunTuru']?.toString(),
      tedarikYontemi: json['tedarikYontemi']?.toString(),
      donem: json['donem']?.toString(),
      aciklama: json['aciklama']?.toString(),
      kalemler: List<Map<String, dynamic>>.from(json['kalemler'] ?? []),
    );
  }

  factory FaturaModel.bos({String id = '0'}) {
    return FaturaModel(
      id: id,
      firmaAdi: '',
      adres: '',
      vergiDairesi: '',
      vergiNo: '',
      tarih: '',
      irsaliyeNo: '',
      melbesNo: '',
      numuneNo: '',
      numuneAciklamasi: '',
      matrah: 0,
      kdvTutari: 0,
      genelToplam: 0,
      isKdvMuaf: false,
      kdvOrani: 20,
      parsedBy: 'Yeni Fatura',
      kalemler: [],
      ytbOgrencisi: false,
      isVergiIstisnasi: false,
    );
  }
}
