// KDV oranı dropdown seçenekleri
import 'fatura_parse_kaynaklari.dart';
const fKdvOranlari = [0.0, 1.0, 10.0, 20.0];

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
  String irsaliyeTarihi;
  String irsaliyeNo;
  String melbesNo;
  String numuneNo;
  /// Matbu MELBES satırı ön eki (ör. bakanlık/kurum adı). Manuel düzenlenebilir.
  String melbesKurumOnEki;
  String numuneAciklamasi;
  List<Map<String, dynamic>> kalemler;
  bool isKdvMuaf;
  bool nakliYekunAktif;
  double matrah;
  double kdvOrani;
  double kdvTutari;
  double genelToplam;
  String parsedBy;
  /// Akıllı eşleştirmeden gelen güven skoru (yalnızca arşiv klonunda).
  int? eslesmeSkoru;
  String? iban;
  String? hesapAdi;

  // Yeni Dinamik Alanlar
  String? hizmetTipi;
  String? kursAdi;
  int? kurNo;
  String? odemeTipi;
  bool ytbOgrencisi;
  String? urunTuru;
  String? tedarikYontemi;
  String? donem;
  String? aciklama;
  String? tahminiBirim;

  FaturaModel({
    required this.id,
    required this.firmaAdi,
    required this.adres,
    required this.vergiDairesi,
    required this.vergiNo,
    required this.tarih,
    this.irsaliyeTarihi = '',
    required this.irsaliyeNo,
    required this.melbesNo,
    required this.numuneNo,
    this.melbesKurumOnEki = '',
    required this.numuneAciklamasi,
    required this.kalemler,
    required this.isKdvMuaf,
    this.nakliYekunAktif = false,
    required this.matrah,
    required this.kdvOrani,
    required this.kdvTutari,
    required this.genelToplam,
    this.parsedBy = 'AI Parser',
    this.eslesmeSkoru,
    this.iban,
    this.hesapAdi,
    this.hizmetTipi,
    this.kursAdi,
    this.kurNo,
    this.odemeTipi,
    this.ytbOgrencisi = false,
    this.urunTuru,
    this.tedarikYontemi,
    this.donem,
    this.aciklama,
    this.tahminiBirim,
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
      'irsaliyeTarihi': irsaliyeTarihi,
      'irsaliyeNo': irsaliyeNo,
      'melbesNo': melbesNo,
      'numuneNo': numuneNo,
      'melbesKurumOnEki': melbesKurumOnEki,
      'numuneAciklamasi': numuneAciklamasi,
      'kalemler': kalemler,
      'isKdvMuaf': isKdvMuaf,
      'nakliYekunAktif': nakliYekunAktif,
      'matrah': matrah,
      'kdvOrani': kdvOrani,
      'kdvTutari': kdvTutari,
      'genelToplam': genelToplam,
      'parsedBy': parsedBy,
      'eslesmeSkoru': eslesmeSkoru,
      'iban': iban,
      'hesapAdi': hesapAdi,
      'hizmetTipi': hizmetTipi,
      'kursAdi': kursAdi,
      'kurNo': kurNo,
      'odemeTipi': odemeTipi,
      'ytbOgrencisi': ytbOgrencisi,
      'urunTuru': urunTuru,
      'tedarikYontemi': tedarikYontemi,
      'donem': donem,
      'aciklama': aciklama,
    };
  }

  /// AI/parser çıktısını izinli seçenek listesine eşler.
  /// Tam eşleşme yoksa büyük/küçük harf duyarsız dener; bulamazsa null döner
  /// (Dropdown'un geçersiz değerle çökmesini engeller).
  static String? _normalizeSecenek(dynamic raw, List<String> izinli) {
    if (raw == null) return null;
    final deger = raw.toString().trim();
    if (deger.isEmpty) return null;
    if (izinli.contains(deger)) return deger;
    final lower = deger.toLowerCase();
    for (final e in izinli) {
      if (e.toLowerCase() == lower) return e;
    }
    return null;
  }

  static double _normalizeKdvOrani(dynamic raw) {
    final v = (raw as num?)?.toDouble() ?? 20.0;
    if (fKdvOranlari.contains(v)) return v;
    if (v <= 0) return 0;
    if (v <= 5) return 1;
    if (v <= 15) return 10;
    return 20;
  }

  factory FaturaModel.fromJson(Map<String, dynamic> json) {
    return FaturaModel(
      id: json['id']?.toString() ?? '',
      firmaAdi: json['firmaAdi']?.toString() ?? '',
      adres: json['adres']?.toString() ?? '',
      vergiDairesi: json['vergiDairesi']?.toString() ?? '',
      vergiNo: json['vergiNo']?.toString() ?? '',
      tarih: json['tarih']?.toString() ?? '',
      irsaliyeTarihi: json['irsaliyeTarihi']?.toString() ?? '',
      irsaliyeNo: json['irsaliyeNo']?.toString() ?? '',
      melbesNo: json['melbesNo']?.toString() ?? '',
      numuneNo: json['numuneNo']?.toString() ?? '',
      melbesKurumOnEki: json['melbesKurumOnEki']?.toString() ?? '',
      numuneAciklamasi: json['numuneAciklamasi']?.toString() ?? '',
      matrah: (json['matrah'] as num?)?.toDouble() ?? 0.0,
      kdvTutari: (json['kdvTutari'] as num?)?.toDouble() ?? 0.0,
      genelToplam: (json['genelToplam'] as num?)?.toDouble() ?? 0.0,
      isKdvMuaf: json['isKdvMuaf'] == true,
      nakliYekunAktif: json['nakliYekunAktif'] == true,
      kdvOrani: _normalizeKdvOrani(json['kdvOrani']),
      parsedBy: FaturaParseKaynaklari.normalize(json['parsedBy']?.toString()),
      eslesmeSkoru: json['eslesmeSkoru'] != null
          ? int.tryParse(json['eslesmeSkoru'].toString())
          : null,
      iban: json['iban']?.toString(),
      hesapAdi: json['hesapAdi']?.toString(),
      hizmetTipi: _normalizeSecenek(json['hizmetTipi'], fHizmetTipleri),
      kursAdi: json['kursAdi']?.toString(),
      kurNo: json['kurNo'] != null ? int.tryParse(json['kurNo'].toString()) : null,
      odemeTipi: _normalizeSecenek(json['odemeTipi'], fOdemeTipleri),
      ytbOgrencisi: json['ytbOgrencisi'] == true,
      urunTuru: _normalizeSecenek(json['urunTuru'], fUrunTurleri),
      tedarikYontemi: _normalizeSecenek(json['tedarikYontemi'], fTedarikYontemleri),
      donem: json['donem']?.toString(),
      aciklama: json['aciklama']?.toString(),
      tahminiBirim: json['tahminiBirim']?.toString(),
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
      irsaliyeTarihi: '',
      irsaliyeNo: '',
      melbesNo: '',
      numuneNo: '',
      melbesKurumOnEki: '',
      numuneAciklamasi: '',
      matrah: 0,
      kdvTutari: 0,
      genelToplam: 0,
      isKdvMuaf: false,
      nakliYekunAktif: false,
      kdvOrani: 20,
      parsedBy: FaturaParseKaynaklari.yeniFatura,
      kalemler: [],
      ytbOgrencisi: false,
    );
  }
}
