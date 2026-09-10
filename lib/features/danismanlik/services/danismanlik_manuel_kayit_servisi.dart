import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/firestore_service.dart';
import 'danismanlik_excel_hesaplama.dart';
import 'danismanlik_manuel_pdf_servisi.dart';

/// Manuel hesaplama kayıt modeli
class ManuelHesaplamaKaydi {
  ManuelHesaplamaKaydi({
    this.id = '',
    required this.kayitAdi,
    required this.kurumAdi,
    required this.rektorlukAdi,
    required this.mudurlukAdi,
    required this.hizmetBasligi,
    required this.kdvOrani,
    required this.hazineOrani,
    required this.bapOrani,
    required this.aracGerecOrani,
    required this.memurMaasKatsayisi,
    required this.manuelKatsayiAktif,
    required this.manuelKatsayi,
    required this.satirlar,
    required this.personeller,
    required this.toplamTutar,
    required this.kdvHaricGelir,
    required this.dagitilabilirPay,
    this.sablonTuru = 'dts',
    DateTime? olusturmaTarihi,
    this.odemeTekSeferde = true,
    this.toplamTaksitSayisi = 3,
    this.aktifTaksitNo = 1,
    this.danismanlikDonemi = '',
    this.sozlesmeBaslangicTarihi,
  }) : olusturmaTarihi = olusturmaTarihi ?? DateTime.now();

  final String id;
  final String kayitAdi;
  final String kurumAdi;
  final String rektorlukAdi;
  final String mudurlukAdi;
  final String hizmetBasligi;
  final int kdvOrani;
  final int hazineOrani;
  final int bapOrani;
  final double aracGerecOrani;
  final double memurMaasKatsayisi;
  final bool manuelKatsayiAktif;
  final String manuelKatsayi;
  final List<ManuelListeSatiri> satirlar;
  final List<ExcelPersonelGirdi> personeller;
  final double toplamTutar;
  final double kdvHaricGelir;
  final double dagitilabilirPay;
  final String sablonTuru; // 'dts', '58k', 'usem', 'tomer', 'dosim'
  final DateTime olusturmaTarihi;
  final bool odemeTekSeferde;
  final int toplamTaksitSayisi;
  final int aktifTaksitNo;
  final String danismanlikDonemi;
  final DateTime? sozlesmeBaslangicTarihi;

  Map<String, dynamic> toMap() => {
    'kayitAdi': kayitAdi,
    'kurumAdi': kurumAdi,
    'rektorlukAdi': rektorlukAdi,
    'mudurlukAdi': mudurlukAdi,
    'hizmetBasligi': hizmetBasligi,
    'kdvOrani': kdvOrani,
    'hazineOrani': hazineOrani,
    'bapOrani': bapOrani,
    'aracGerecOrani': aracGerecOrani,
    'memurMaasKatsayisi': memurMaasKatsayisi,
    'manuelKatsayiAktif': manuelKatsayiAktif,
    'manuelKatsayi': manuelKatsayi,
    'satirlar': satirlar.map((s) => s.toMap()).toList(),
    'personeller': personeller.map((p) => p.toMap()).toList(),
    'toplamTutar': toplamTutar,
    'kdvHaricGelir': kdvHaricGelir,
    'dagitilabilirPay': dagitilabilirPay,
    'sablonTuru': sablonTuru,
    'olusturmaTarihi': Timestamp.fromDate(olusturmaTarihi),
    'odemeTekSeferde': odemeTekSeferde,
    'toplamTaksitSayisi': toplamTaksitSayisi,
    'aktifTaksitNo': aktifTaksitNo,
    'danismanlikDonemi': danismanlikDonemi,
    'sozlesmeBaslangicTarihi': sozlesmeBaslangicTarihi != null
        ? Timestamp.fromDate(sozlesmeBaslangicTarihi!)
        : null,
  };

  factory ManuelHesaplamaKaydi.fromMap(String id, Map<String, dynamic> map) {
    DateTime tarih = DateTime.now();
    if (map['olusturmaTarihi'] is Timestamp) {
      tarih = (map['olusturmaTarihi'] as Timestamp).toDate();
    } else if (map['olusturmaTarihi'] is String) {
      tarih = DateTime.tryParse(map['olusturmaTarihi'] as String) ?? DateTime.now();
    }

    final satirlarList = (map['satirlar'] as List<dynamic>?)
            ?.map((e) => ManuelListeSatiri.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    final personellerList = (map['personeller'] as List<dynamic>?)
            ?.map((e) => ExcelPersonelGirdi.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList() ??
        [];

    DateTime? sozlesmeBaslangic;
    if (map['sozlesmeBaslangicTarihi'] is Timestamp) {
      sozlesmeBaslangic = (map['sozlesmeBaslangicTarihi'] as Timestamp).toDate();
    } else if (map['sozlesmeBaslangicTarihi'] is String) {
      sozlesmeBaslangic = DateTime.tryParse(map['sozlesmeBaslangicTarihi'] as String);
    }

    return ManuelHesaplamaKaydi(
      id: id,
      kayitAdi: map['kayitAdi'] as String? ?? 'İsimsiz Hesaplama',
      kurumAdi: map['kurumAdi'] as String? ?? '',
      rektorlukAdi: map['rektorlukAdi'] as String? ?? '',
      mudurlukAdi: map['mudurlukAdi'] as String? ?? '',
      hizmetBasligi: map['hizmetBasligi'] as String? ?? '',
      kdvOrani: (map['kdvOrani'] as num?)?.toInt() ?? 20,
      hazineOrani: (map['hazineOrani'] as num?)?.toInt() ?? 1,
      bapOrani: (map['bapOrani'] as num?)?.toInt() ?? 5,
      aracGerecOrani: (map['aracGerecOrani'] as num?)?.toDouble() ?? 0.45,
      memurMaasKatsayisi: (map['memurMaasKatsayisi'] as num?)?.toDouble() ?? 1.387871,
      manuelKatsayiAktif: map['manuelKatsayiAktif'] as bool? ?? false,
      manuelKatsayi: map['manuelKatsayi'] as String? ?? '',
      satirlar: satirlarList,
      personeller: personellerList,
      toplamTutar: (map['toplamTutar'] as num?)?.toDouble() ?? 0.0,
      kdvHaricGelir: (map['kdvHaricGelir'] as num?)?.toDouble() ?? 0.0,
      dagitilabilirPay: (map['dagitilabilirPay'] as num?)?.toDouble() ?? 0.0,
      sablonTuru: map['sablonTuru'] as String? ?? 'dts',
      olusturmaTarihi: tarih,
      odemeTekSeferde: map['odemeTekSeferde'] as bool? ?? true,
      toplamTaksitSayisi: (map['toplamTaksitSayisi'] as num?)?.toInt() ?? 3,
      aktifTaksitNo: (map['aktifTaksitNo'] as num?)?.toInt() ?? 1,
      danismanlikDonemi: map['danismanlikDonemi'] as String? ?? '',
      sozlesmeBaslangicTarihi: sozlesmeBaslangic,
    );
  }
}

/// Manuel hesaplama kayıtlarını Firestore'da saklayan ve getiren servis.
class DanismanlikManuelKayitServisi {
  DanismanlikManuelKayitServisi({FirestoreService? firestoreService})
      : _service = firestoreService ?? FirestoreService();

  final FirestoreService _service;
  static const _collection = 'danismanlik_manuel_hesaplamalar';

  CollectionReference<Map<String, dynamic>> get _ref => _service.collection(_collection);

  /// Yeni hesaplama kaydet veya güncelle
  Future<String> kaydet(ManuelHesaplamaKaydi kayit) async {
    try {
      if (kayit.id.isNotEmpty) {
        await _ref.doc(kayit.id).set(kayit.toMap(), SetOptions(merge: true));
        return kayit.id;
      } else {
        final doc = await _ref.add(kayit.toMap());
        return doc.id;
      }
    } catch (e) {
      throw Exception('Hesaplama kaydedilirken hata oluştu: $e');
    }
  }

  /// Tüm kayıtlı hesaplamaları listele
  Future<List<ManuelHesaplamaKaydi>> listele() async {
    try {
      final snap = await _ref.orderBy('olusturmaTarihi', descending: true).get();
      return snap.docs.map((d) => ManuelHesaplamaKaydi.fromMap(d.id, d.data())).toList();
    } catch (e) {
      // Hata durumunda boş liste dön
      return [];
    }
  }

  /// Kaydı sil
  Future<void> sil(String id) async {
    try {
      await _ref.doc(id).delete();
    } catch (e) {
      throw Exception('Hesaplama silinirken hata: $e');
    }
  }
}
