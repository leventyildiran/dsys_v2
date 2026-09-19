import 'dart:typed_data';

/// Birim için yüklenebilecek belge slot türleri.
/// Gelecekte muhtasar bordrosu veya fatura listesi eklenmesi için genişletilebilir.
enum BirimBelgeSlotTuru {
  aylikMizan('Aylık Mizan', 'Seçili ayın resmi mizanı (PDF/Excel)', true),
  yillikMizan('Yıllık Mizan', 'Ocak - Seçili ay kümülatif mizanı (PDF/Excel)', true),
  diger('Diğer / Ekstra', 'KDV dökümü, fatura listesi, ek protokoller', false),
  muhtasarBordro('Muhtasar Bordro', 'Birim bordro icmali / personel listesi', false),
  faturaListesi('Fatura Listesi', 'Tevkifatlı ve istisna fatura listesi', false);

  final String baslik;
  final String aciklama;
  final bool zorunluMu;

  const BirimBelgeSlotTuru(this.baslik, this.aciklama, this.zorunluMu);
}

/// Yüklenen tekil bir belge kaydı
class BirimYuklenenBelge {
  final String id;
  final String birimAdi;
  final BirimBelgeSlotTuru slotTuru;
  final String dosyaAdi;
  final int dosyaBoyutu; // byte cinsinden
  final String dosyaUzantisi; // 'pdf', 'xlsx', 'xls', 'png', 'jpg' vb.
  final DateTime yuklenmeTarihi;
  final Uint8List? dosyaBytes;

  const BirimYuklenenBelge({
    required this.id,
    required this.birimAdi,
    required this.slotTuru,
    required this.dosyaAdi,
    required this.dosyaBoyutu,
    required this.dosyaUzantisi,
    required this.yuklenmeTarihi,
    this.dosyaBytes,
  });

  bool get isPdf => dosyaUzantisi.toLowerCase() == 'pdf';
  bool get isExcel =>
      dosyaUzantisi.toLowerCase() == 'xlsx' || dosyaUzantisi.toLowerCase() == 'xls';

  String get okunabilirBoyut {
    if (dosyaBoyutu < 1024) return '$dosyaBoyutu B';
    if (dosyaBoyutu < 1024 * 1024) {
      return '${(dosyaBoyutu / 1024).toStringAsFixed(1)} KB';
    }
    return '${(dosyaBoyutu / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'birimAdi': birimAdi,
        'slotTuru': slotTuru.name,
        'dosyaAdi': dosyaAdi,
        'dosyaBoyutu': dosyaBoyutu,
        'dosyaUzantisi': dosyaUzantisi,
        'yuklenmeTarihi': yuklenmeTarihi.toIso8601String(),
      };

  factory BirimYuklenenBelge.fromMap(Map<String, dynamic> map, {Uint8List? bytes}) {
    return BirimYuklenenBelge(
      id: map['id'] as String? ?? '',
      birimAdi: map['birimAdi'] as String? ?? '',
      slotTuru: BirimBelgeSlotTuru.values.firstWhere(
        (e) => e.name == map['slotTuru'],
        orElse: () => BirimBelgeSlotTuru.diger,
      ),
      dosyaAdi: map['dosyaAdi'] as String? ?? '',
      dosyaBoyutu: (map['dosyaBoyutu'] as num?)?.toInt() ?? 0,
      dosyaUzantisi: map['dosyaUzantisi'] as String? ?? '',
      yuklenmeTarihi: map['yuklenmeTarihi'] != null
          ? DateTime.parse(map['yuklenmeTarihi'] as String)
          : DateTime.now(),
      dosyaBytes: bytes,
    );
  }
}

/// Gemini AI tarafından mizan ve ek belgelerden çıkarılan yapısal analiz çıktısı
class BirimMizanAnalizSonucu {
  final String birimAdi;
  final DateTime analizTarihi;

  // 600 Hesabı & 123 Hesabı
  final double hasilat600Aylik;
  final double hasilat600Kumulatif;
  final double krediKarti123;

  // 391 Hesaplanan KDV (%10 ve %20)
  final double hesaplananKdvMatrah10;
  final double hesaplananKdv10;
  final double hesaplananKdvMatrah20;
  final double hesaplananKdv20;

  // 191 İndirilecek KDV (%10 ve %20)
  final double indirilecekKdvMatrah10;
  final double indirilecekKdv10;
  final double indirilecekKdvMatrah20;
  final double indirilecekKdv20;

  // 360.03.05 Damga Vergisi (Ödemelerden Kesilen)
  final double damgaVergisi360;
  final double damgaMatrah;

  // 360 Muhtasar
  final double muhtasarGelir360;
  final double muhtasarDamga360;

  // 190 Devreden KDV (Mizan Borç Kalanı)
  final double devredenKdv190;

  // Diğer belgelerden veya mizandan varsa Tevkifatlı Faturalar
  final List<Map<String, dynamic>> tevkifatFaturalari;

  // Ham AI yanıtı veya log notları
  final String? aciklama;
  final Map<String, dynamic>? hamJson;

  const BirimMizanAnalizSonucu({
    required this.birimAdi,
    required this.analizTarihi,
    this.hasilat600Aylik = 0.0,
    this.hasilat600Kumulatif = 0.0,
    this.krediKarti123 = 0.0,
    this.hesaplananKdvMatrah10 = 0.0,
    this.hesaplananKdv10 = 0.0,
    this.hesaplananKdvMatrah20 = 0.0,
    this.hesaplananKdv20 = 0.0,
    this.indirilecekKdvMatrah10 = 0.0,
    this.indirilecekKdv10 = 0.0,
    this.indirilecekKdvMatrah20 = 0.0,
    this.indirilecekKdv20 = 0.0,
    this.damgaVergisi360 = 0.0,
    this.damgaMatrah = 0.0,
    this.muhtasarGelir360 = 0.0,
    this.muhtasarDamga360 = 0.0,
    this.devredenKdv190 = 0.0,
    this.tevkifatFaturalari = const [],
    this.aciklama,
    this.hamJson,
  });

  double get toplamHesaplananKdv => hesaplananKdv10 + hesaplananKdv20;
  double get toplamHesaplananMatrah => hesaplananKdvMatrah10 + hesaplananKdvMatrah20;
  double get toplamIndirilecekKdv => indirilecekKdv10 + indirilecekKdv20;
  double get netKdv => toplamHesaplananKdv - toplamIndirilecekKdv;

  Map<String, dynamic> toMap() => {
        'birimAdi': birimAdi,
        'analizTarihi': analizTarihi.toIso8601String(),
        'hasilat600Aylik': hasilat600Aylik,
        'hasilat600Kumulatif': hasilat600Kumulatif,
        'krediKarti123': krediKarti123,
        'hesaplananKdvMatrah10': hesaplananKdvMatrah10,
        'hesaplananKdv10': hesaplananKdv10,
        'hesaplananKdvMatrah20': hesaplananKdvMatrah20,
        'hesaplananKdv20': hesaplananKdv20,
        'indirilecekKdvMatrah10': indirilecekKdvMatrah10,
        'indirilecekKdv10': indirilecekKdv10,
        'indirilecekKdvMatrah20': indirilecekKdvMatrah20,
        'indirilecekKdv20': indirilecekKdv20,
        'damgaVergisi360': damgaVergisi360,
        'damgaMatrah': damgaMatrah,
        'muhtasarGelir360': muhtasarGelir360,
        'muhtasarDamga360': muhtasarDamga360,
        'devredenKdv190': devredenKdv190,
        'tevkifatFaturalari': tevkifatFaturalari,
        'aciklama': aciklama,
      };

  factory BirimMizanAnalizSonucu.fromMap(Map<String, dynamic> map) {
    return BirimMizanAnalizSonucu(
      birimAdi: map['birimAdi'] as String? ?? '',
      analizTarihi: map['analizTarihi'] != null
          ? DateTime.parse(map['analizTarihi'] as String)
          : DateTime.now(),
      hasilat600Aylik: (map['hasilat600Aylik'] as num?)?.toDouble() ?? 0.0,
      hasilat600Kumulatif: (map['hasilat600Kumulatif'] as num?)?.toDouble() ?? 0.0,
      krediKarti123: (map['krediKarti123'] as num?)?.toDouble() ?? 0.0,
      hesaplananKdvMatrah10: (map['hesaplananKdvMatrah10'] as num?)?.toDouble() ?? 0.0,
      hesaplananKdv10: (map['hesaplananKdv10'] as num?)?.toDouble() ?? 0.0,
      hesaplananKdvMatrah20: (map['hesaplananKdvMatrah20'] as num?)?.toDouble() ?? 0.0,
      hesaplananKdv20: (map['hesaplananKdv20'] as num?)?.toDouble() ?? 0.0,
      indirilecekKdvMatrah10: (map['indirilecekKdvMatrah10'] as num?)?.toDouble() ?? 0.0,
      indirilecekKdv10: (map['indirilecekKdv10'] as num?)?.toDouble() ?? 0.0,
      indirilecekKdvMatrah20: (map['indirilecekKdvMatrah20'] as num?)?.toDouble() ?? 0.0,
      indirilecekKdv20: (map['indirilecekKdv20'] as num?)?.toDouble() ?? 0.0,
      damgaVergisi360: (map['damgaVergisi360'] as num?)?.toDouble() ?? 0.0,
      damgaMatrah: (map['damgaMatrah'] as num?)?.toDouble() ?? 0.0,
      muhtasarGelir360: (map['muhtasarGelir360'] as num?)?.toDouble() ?? 0.0,
      muhtasarDamga360: (map['muhtasarDamga360'] as num?)?.toDouble() ?? 0.0,
      devredenKdv190: (map['devredenKdv190'] as num?)?.toDouble() ?? 0.0,
      tevkifatFaturalari: (map['tevkifatFaturalari'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          const [],
      aciklama: map['aciklama'] as String?,
      hamJson: map,
    );
  }
}
