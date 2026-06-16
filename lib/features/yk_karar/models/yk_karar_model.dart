/// Yürütme Kurulu Karar Modeli (v2).
///
/// Tabloları yapısal veri (JSON/Object) olarak tutar, Markdown metin olarak DEĞİL.
/// Firestore yolu: `universiteler/{uniId}/ykKararlari/{kararId}`
class YkKararModel {
  const YkKararModel({
    required this.id,
    required this.toplantiId,
    required this.toplantiNo,
    required this.kararNo,
    required this.kararTarihi,
    required this.birimId,
    required this.birimAd,
    required this.tur,
    required this.baslik,
    required this.kararMetni,
    this.iliskiliKayitId = '',
    this.olusturmaTarihi,
    this.durum = YkKararDurum.taslak,
    this.tabloVerileri = const [],
    this.birimEvrakTarihi = '',
    this.birimEvrakSayisi = '',
    this.birimKurulTarihi = '',
    this.birimToplantiSayi = '',
    this.birimKararNo = '',
    this.sablonTuru,
    this.isExternal = false,
    this.pdfUrl,
    this.aiPdfUrl,
    this.wordUrl,
    this.docxBodyXml,
    this.eslesmeSkoru,
    this.analizKaynagi,
    this.analizUyarilari = const [],
  });

  final String id;
  final String toplantiId;
  final String toplantiNo;
  final String kararNo;
  final String kararTarihi;
  final String birimId;
  final String birimAd;
  final YkKararTuru tur;
  final String baslik;
  final String kararMetni;
  final String iliskiliKayitId;
  final DateTime? olusturmaTarihi;
  final String? pdfUrl;
  final String? aiPdfUrl;
  final String? wordUrl;

  /// Eşleştirmeden gelen OOXML gövde parçası — tablolar birebir korunur.
  final String? docxBodyXml;

  /// Word arşiv eşleşme skoru (audit).
  final int? eslesmeSkoru;

  /// yapay_zeka | otomatik_eslestirme
  final String? analizKaynagi;

  /// PDF kalite / tablo doldurma uyarıları.
  final List<String> analizUyarilari;

  final YkKararDurum durum;

  /// V2 YENİLİK: Tablolar artık yapısal veri olarak tutulur.
  /// Her bir Map, bir tablo satırını temsil eder.
  /// Örnek: [{"adiSoyadi": "Prof. Dr. X", "puani": 85, "katsayi": 1.5, "brutHakedis": 12750.0}]
  final List<Map<String, dynamic>> tabloVerileri;

  /// Birim bilgileri (AI'dan parse edilen veya kullanıcı tarafından girilen).
  final String birimEvrakTarihi;
  final String birimEvrakSayisi;
  final String birimKurulTarihi;
  final String birimToplantiSayi;
  final String birimKararNo;

  /// Hangi şablon kullanıldığını belirler (1-9 arası).
  final int? sablonTuru;

  /// Dış kaynaktan gelen kararları (geçmiş kararlar) ayırmak için.
  final bool isExternal;

  factory YkKararModel.fromMap(String id, Map<String, dynamic> map) {
    final tabloData = map['tabloVerileri'] as List<dynamic>? ?? [];
    return YkKararModel(
      id: id,
      toplantiId: map['toplantiId'] ?? '',
      toplantiNo: map['toplantiNo'] ?? '',
      kararNo: map['kararNo'] ?? '',
      kararTarihi: map['kararTarihi'] ?? '',
      birimId: map['birimId'] ?? '',
      birimAd: map['birimAd'] ?? '',
      tur: YkKararTuru.fromString(map['tur'] ?? 'diger'),
      baslik: map['baslik'] ?? '',
      kararMetni: map['kararMetni'] ?? '',
      iliskiliKayitId: map['iliskiliKayitId'] ?? '',
      olusturmaTarihi: map['olusturmaTarihi'] != null
          ? DateTime.tryParse(map['olusturmaTarihi'])
          : null,
      durum: YkKararDurum.fromString(map['durum'] ?? 'taslak'),
      tabloVerileri: tabloData
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(),
      birimEvrakTarihi: map['birimEvrakTarihi'] ?? '',
      birimEvrakSayisi: map['birimEvrakSayisi'] ?? '',
      birimKurulTarihi: map['birimKurulTarihi'] ?? '',
      birimToplantiSayi: map['birimToplantiSayi'] ?? '',
      birimKararNo: map['birimKararNo'] ?? '',
      sablonTuru: map['sablonTuru'] as int?,
      isExternal: map['isExternal'] ?? false,
      pdfUrl: map['pdfUrl'],
      aiPdfUrl: map['aiPdfUrl'],
      wordUrl: map['wordUrl'],
      docxBodyXml: map['docxBodyXml'],
      eslesmeSkoru: map['eslesmeSkoru'] as int?,
      analizKaynagi: map['analizKaynagi'] as String?,
      analizUyarilari: List<String>.from(map['analizUyarilari'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'toplantiId': toplantiId,
      'toplantiNo': toplantiNo,
      'kararNo': kararNo,
      'kararTarihi': kararTarihi,
      'birimId': birimId,
      'birimAd': birimAd,
      'tur': tur.value,
      'baslik': baslik,
      'kararMetni': kararMetni,
      'iliskiliKayitId': iliskiliKayitId,
      'olusturmaTarihi': olusturmaTarihi?.toIso8601String(),
      'durum': durum.value,
      'tabloVerileri': tabloVerileri,
      'birimEvrakTarihi': birimEvrakTarihi,
      'birimEvrakSayisi': birimEvrakSayisi,
      'birimKurulTarihi': birimKurulTarihi,
      'birimToplantiSayi': birimToplantiSayi,
      'birimKararNo': birimKararNo,
      'sablonTuru': sablonTuru,
      'isExternal': isExternal,
      'pdfUrl': pdfUrl,
      'aiPdfUrl': aiPdfUrl,
      'wordUrl': wordUrl,
      'docxBodyXml': docxBodyXml,
      'eslesmeSkoru': eslesmeSkoru,
      'analizKaynagi': analizKaynagi,
      'analizUyarilari': analizUyarilari,
    };
  }

  YkKararModel copyWith({
    String? toplantiId,
    String? toplantiNo,
    String? kararNo,
    String? kararTarihi,
    String? birimId,
    String? birimAd,
    YkKararTuru? tur,
    String? baslik,
    String? kararMetni,
    String? iliskiliKayitId,
    DateTime? olusturmaTarihi,
    YkKararDurum? durum,
    List<Map<String, dynamic>>? tabloVerileri,
    String? birimEvrakTarihi,
    String? birimEvrakSayisi,
    String? birimKurulTarihi,
    String? birimToplantiSayi,
    String? birimKararNo,
    int? sablonTuru,
    bool? isExternal,
    String? docxBodyXml,
    int? eslesmeSkoru,
    String? analizKaynagi,
    List<String>? analizUyarilari,
  }) {
    return YkKararModel(
      id: id,
      toplantiId: toplantiId ?? this.toplantiId,
      toplantiNo: toplantiNo ?? this.toplantiNo,
      kararNo: kararNo ?? this.kararNo,
      kararTarihi: kararTarihi ?? this.kararTarihi,
      birimId: birimId ?? this.birimId,
      birimAd: birimAd ?? this.birimAd,
      tur: tur ?? this.tur,
      baslik: baslik ?? this.baslik,
      kararMetni: kararMetni ?? this.kararMetni,
      iliskiliKayitId: iliskiliKayitId ?? this.iliskiliKayitId,
      olusturmaTarihi: olusturmaTarihi ?? this.olusturmaTarihi,
      durum: durum ?? this.durum,
      tabloVerileri: tabloVerileri ?? this.tabloVerileri,
      birimEvrakTarihi: birimEvrakTarihi ?? this.birimEvrakTarihi,
      birimEvrakSayisi: birimEvrakSayisi ?? this.birimEvrakSayisi,
      birimKurulTarihi: birimKurulTarihi ?? this.birimKurulTarihi,
      birimToplantiSayi: birimToplantiSayi ?? this.birimToplantiSayi,
      birimKararNo: birimKararNo ?? this.birimKararNo,
      sablonTuru: sablonTuru ?? this.sablonTuru,
      isExternal: isExternal ?? this.isExternal,
      pdfUrl: pdfUrl,
      aiPdfUrl: aiPdfUrl,
      wordUrl: wordUrl,
      docxBodyXml: docxBodyXml ?? this.docxBodyXml,
      eslesmeSkoru: eslesmeSkoru ?? this.eslesmeSkoru,
      analizKaynagi: analizKaynagi ?? this.analizKaynagi,
      analizUyarilari: analizUyarilari ?? this.analizUyarilari,
    );
  }

  /// Tablo verilerinden toplamları hesaplar.
  /// Bu, fatura sistemindeki _recalculateTotals mantığının YK versiyonudur.
  double tabloToplami(String field) {
    double toplam = 0;
    for (final row in tabloVerileri) {
      final value = row[field];
      if (value is num) {
        toplam += value.toDouble();
      } else if (value is String) {
        toplam += double.tryParse(value.replaceAll(',', '.')) ?? 0;
      }
    }
    return toplam;
  }
}

/// Yürütme Kurulu Karar Türleri.
enum YkKararTuru {
  danismanlik('danismanlik', 'Danışmanlık Ödemesi'),
  danismanlikGorevlendirme('danismanlik_gorevlendirme', 'Danışmanlık Görevlendirme'),
  sanayiIsbirligi('sanayi_isbirligi', '2547/58(k) Sanayi İşbirliği'),
  butceAktarim('butce_aktarim', 'Bütçe Aktarımı'),
  kursUcreti('kurs_ucreti', 'Kurs Ücreti Dağıtım'),
  disHekimligi('dis_hekimligi', 'Diş Hekimliği Ek Ödeme'),
  fiyatTarifesi('fiyat_tarifesi', 'Fiyat Tarifesi Belirleme'),
  butceOnay('butce_onay', 'Bütçe/Kesin Hesap Onayı'),
  malSatis('mal_satis', 'Mal/Ürün Satış'),
  diger('diger', 'Diğer Kararlar');

  const YkKararTuru(this.value, this.displayName);
  final String value;
  final String displayName;

  static YkKararTuru fromString(String value) {
    return YkKararTuru.values.firstWhere(
      (e) => e.value == value,
      orElse: () => YkKararTuru.diger,
    );
  }
}

/// Yürütme Kurulu Karar Durumları.
enum YkKararDurum {
  taslak('taslak', 'Taslak'),
  onaylandi('onaylandi', 'Onaylandı');

  const YkKararDurum(this.value, this.displayName);
  final String value;
  final String displayName;

  static YkKararDurum fromString(String value) {
    return YkKararDurum.values.firstWhere(
      (e) => e.value == value,
      orElse: () => YkKararDurum.taslak,
    );
  }
}
