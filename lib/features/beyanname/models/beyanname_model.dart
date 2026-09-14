import '../../birim/models/birim_model.dart';

/// Tevkifat Türleri: 9/10, 7/10, 5/10
enum TevkifatTuru {
  dokuzBoluOn('9/10', 9, 10),
  yediBoluOn('7/10', 7, 10),
  besBoluOn('5/10', 5, 10);

  final String etiket;
  final int pay;
  final int payda;

  const TevkifatTuru(this.etiket, this.pay, this.payda);

  double get oran => pay / payda;

  static TevkifatTuru fromString(String val) {
    if (val.contains('9/10') || val.contains('9 / 10') || val.contains('9/1O')) {
      return TevkifatTuru.dokuzBoluOn;
    }
    if (val.contains('7/10') || val.contains('7 / 10') || val.contains('7/1O')) {
      return TevkifatTuru.yediBoluOn;
    }
    return TevkifatTuru.besBoluOn;
  }
}

/// KDV 1 Satırı (Birim Bazlı Giriş)
class Kdv1BirimSatiri {
  final String birimId;
  final String birimAdi;
  final double hesaplananKdv10;
  final double hesaplananMatrah10;
  final double hesaplananKdv20;
  final double hesaplananMatrah20;

  final double indirilecekKdv10;
  final double indirilecekMatrah10;
  final double indirilecekKdv20;
  final double indirilecekMatrah20;

  const Kdv1BirimSatiri({
    required this.birimId,
    required this.birimAdi,
    this.hesaplananKdv10 = 0.0,
    this.hesaplananMatrah10 = 0.0,
    this.hesaplananKdv20 = 0.0,
    this.hesaplananMatrah20 = 0.0,
    this.indirilecekKdv10 = 0.0,
    this.indirilecekMatrah10 = 0.0,
    this.indirilecekKdv20 = 0.0,
    this.indirilecekMatrah20 = 0.0,
  });

  double get toplamHesaplananKdv => hesaplananKdv10 + hesaplananKdv20;
  double get toplamHesaplananMatrah => hesaplananMatrah10 + hesaplananMatrah20;

  double get toplamIndirilecekKdv => indirilecekKdv10 + indirilecekKdv20;
  double get toplamIndirilecekMatrah => indirilecekMatrah10 + indirilecekMatrah20;

  double get netOdenecekKdv => toplamHesaplananKdv - toplamIndirilecekKdv;

  Kdv1BirimSatiri copyWith({
    String? birimId,
    String? birimAdi,
    double? hesaplananKdv10,
    double? hesaplananMatrah10,
    double? hesaplananKdv20,
    double? hesaplananMatrah20,
    double? indirilecekKdv10,
    double? indirilecekMatrah10,
    double? indirilecekKdv20,
    double? indirilecekMatrah20,
  }) {
    return Kdv1BirimSatiri(
      birimId: birimId ?? this.birimId,
      birimAdi: birimAdi ?? this.birimAdi,
      hesaplananKdv10: hesaplananKdv10 ?? this.hesaplananKdv10,
      hesaplananMatrah10: hesaplananMatrah10 ?? this.hesaplananMatrah10,
      hesaplananKdv20: hesaplananKdv20 ?? this.hesaplananKdv20,
      hesaplananMatrah20: hesaplananMatrah20 ?? this.hesaplananMatrah20,
      indirilecekKdv10: indirilecekKdv10 ?? this.indirilecekKdv10,
      indirilecekMatrah10: indirilecekMatrah10 ?? this.indirilecekMatrah10,
      indirilecekKdv20: indirilecekKdv20 ?? this.indirilecekKdv20,
      indirilecekMatrah20: indirilecekMatrah20 ?? this.indirilecekMatrah20,
    );
  }

  Map<String, dynamic> toMap() => {
        'birimId': birimId,
        'birimAdi': birimAdi,
        'hesaplananKdv10': hesaplananKdv10,
        'hesaplananMatrah10': hesaplananMatrah10,
        'hesaplananKdv20': hesaplananKdv20,
        'hesaplananMatrah20': hesaplananMatrah20,
        'indirilecekKdv10': indirilecekKdv10,
        'indirilecekMatrah10': indirilecekMatrah10,
        'indirilecekKdv20': indirilecekKdv20,
        'indirilecekMatrah20': indirilecekMatrah20,
      };

  factory Kdv1BirimSatiri.fromMap(Map<String, dynamic> map) => Kdv1BirimSatiri(
        birimId: map['birimId'] as String? ?? '',
        birimAdi: map['birimAdi'] as String? ?? '',
        hesaplananKdv10: (map['hesaplananKdv10'] as num?)?.toDouble() ?? 0.0,
        hesaplananMatrah10: (map['hesaplananMatrah10'] as num?)?.toDouble() ?? 0.0,
        hesaplananKdv20: (map['hesaplananKdv20'] as num?)?.toDouble() ?? 0.0,
        hesaplananMatrah20: (map['hesaplananMatrah20'] as num?)?.toDouble() ?? 0.0,
        indirilecekKdv10: (map['indirilecekKdv10'] as num?)?.toDouble() ?? 0.0,
        indirilecekMatrah10: (map['indirilecekMatrah10'] as num?)?.toDouble() ?? 0.0,
        indirilecekKdv20: (map['indirilecekKdv20'] as num?)?.toDouble() ?? 0.0,
        indirilecekMatrah20: (map['indirilecekMatrah20'] as num?)?.toDouble() ?? 0.0,
      );
}

/// KDV 2 Tevkifatlı Firma / Kişi Kaydı
class TevkifatFirmaKaydi {
  final String id;
  final String firmaAdi;
  final String vergiTcNo;

  /// Eski kayıtlarla uyumluluk için korunur; [etiket] tek gerçek kaynaktır.
  final TevkifatTuru tevkifatTuru;

  /// Kurum tanımlı tevkifat etiketi (örn. '4/10'). Boşsa [tevkifatTuru]
  /// etiketi kullanılır — eski kayıtlar sorunsuz okunur.
  final String? tevkifatEtiketi;

  final int kdvOrani; // %1, %8, %10, %18, %20
  final double matrahTutari;
  final double kdvTutari;
  final double tevkifatTutari;
  final String? birimAdi;

  const TevkifatFirmaKaydi({
    required this.id,
    required this.firmaAdi,
    required this.vergiTcNo,
    required this.tevkifatTuru,
    this.tevkifatEtiketi,
    required this.kdvOrani,
    required this.matrahTutari,
    required this.kdvTutari,
    required this.tevkifatTutari,
    this.birimAdi,
  });

  /// Toplama/raporlamada kullanılan kanonik tevkifat etiketi.
  String get etiket =>
      (tevkifatEtiketi != null && tevkifatEtiketi!.isNotEmpty)
          ? tevkifatEtiketi!
          : tevkifatTuru.etiket;

  double get toplamTutar => matrahTutari + kdvTutari;

  TevkifatFirmaKaydi copyWith({
    String? id,
    String? firmaAdi,
    String? vergiTcNo,
    TevkifatTuru? tevkifatTuru,
    String? tevkifatEtiketi,
    int? kdvOrani,
    double? matrahTutari,
    double? kdvTutari,
    double? tevkifatTutari,
    String? birimAdi,
  }) {
    return TevkifatFirmaKaydi(
      id: id ?? this.id,
      firmaAdi: firmaAdi ?? this.firmaAdi,
      vergiTcNo: vergiTcNo ?? this.vergiTcNo,
      tevkifatTuru: tevkifatTuru ?? this.tevkifatTuru,
      tevkifatEtiketi: tevkifatEtiketi ?? this.tevkifatEtiketi,
      kdvOrani: kdvOrani ?? this.kdvOrani,
      matrahTutari: matrahTutari ?? this.matrahTutari,
      kdvTutari: kdvTutari ?? this.kdvTutari,
      tevkifatTutari: tevkifatTutari ?? this.tevkifatTutari,
      birimAdi: birimAdi ?? this.birimAdi,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'firmaAdi': firmaAdi,
        'vergiTcNo': vergiTcNo,
        'tevkifatTuru': tevkifatTuru.etiket,
        'tevkifatEtiketi': etiket,
        'kdvOrani': kdvOrani,
        'matrahTutari': matrahTutari,
        'kdvTutari': kdvTutari,
        'tevkifatTutari': tevkifatTutari,
        'birimAdi': birimAdi,
      };

  factory TevkifatFirmaKaydi.fromMap(Map<String, dynamic> map) => TevkifatFirmaKaydi(
        id: map['id'] as String? ?? '',
        firmaAdi: map['firmaAdi'] as String? ?? '',
        vergiTcNo: map['vergiTcNo'] as String? ?? '',
        tevkifatTuru: TevkifatTuru.fromString(map['tevkifatTuru'] as String? ?? '9/10'),
        tevkifatEtiketi: map['tevkifatEtiketi'] as String?,
        kdvOrani: (map['kdvOrani'] as num?)?.toInt() ?? 20,
        matrahTutari: (map['matrahTutari'] as num?)?.toDouble() ?? 0.0,
        kdvTutari: (map['kdvTutari'] as num?)?.toDouble() ?? 0.0,
        tevkifatTutari: (map['tevkifatTutari'] as num?)?.toDouble() ?? 0.0,
        birimAdi: map['birimAdi'] as String?,
      );
}

/// Muhtasar Personel Satırı (Birim Bazında veya Kişi Bazında)
class MuhtasarSatiri {
  final String id;
  final String birimAdi;
  final String adSoyad;
  final int kisiSayisi;
  final double brutUcret;
  final double gelirVergisi;
  final double damgaVergisi;
  final double netOdenen;
  final double aylikGelirVergisiMatrahi;

  const MuhtasarSatiri({
    required this.id,
    required this.birimAdi,
    this.adSoyad = '',
    this.kisiSayisi = 1,
    this.brutUcret = 0.0,
    this.gelirVergisi = 0.0,
    this.damgaVergisi = 0.0,
    this.netOdenen = 0.0,
    this.aylikGelirVergisiMatrahi = 0.0,
  });

  MuhtasarSatiri copyWith({
    String? id,
    String? birimAdi,
    String? adSoyad,
    int? kisiSayisi,
    double? brutUcret,
    double? gelirVergisi,
    double? damgaVergisi,
    double? netOdenen,
    double? aylikGelirVergisiMatrahi,
  }) {
    return MuhtasarSatiri(
      id: id ?? this.id,
      birimAdi: birimAdi ?? this.birimAdi,
      adSoyad: adSoyad ?? this.adSoyad,
      kisiSayisi: kisiSayisi ?? this.kisiSayisi,
      brutUcret: brutUcret ?? this.brutUcret,
      gelirVergisi: gelirVergisi ?? this.gelirVergisi,
      damgaVergisi: damgaVergisi ?? this.damgaVergisi,
      netOdenen: netOdenen ?? this.netOdenen,
      aylikGelirVergisiMatrahi: aylikGelirVergisiMatrahi ?? this.aylikGelirVergisiMatrahi,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'birimAdi': birimAdi,
        'adSoyad': adSoyad,
        'kisiSayisi': kisiSayisi,
        'brutUcret': brutUcret,
        'gelirVergisi': gelirVergisi,
        'damgaVergisi': damgaVergisi,
        'netOdenen': netOdenen,
        'aylikGelirVergisiMatrahi': aylikGelirVergisiMatrahi,
      };

  factory MuhtasarSatiri.fromMap(Map<String, dynamic> map) => MuhtasarSatiri(
        id: map['id'] as String? ?? '',
        birimAdi: map['birimAdi'] as String? ?? '',
        adSoyad: map['adSoyad'] as String? ?? '',
        kisiSayisi: (map['kisiSayisi'] as num?)?.toInt() ?? 1,
        brutUcret: (map['brutUcret'] as num?)?.toDouble() ?? 0.0,
        gelirVergisi: (map['gelirVergisi'] as num?)?.toDouble() ?? 0.0,
        damgaVergisi: (map['damgaVergisi'] as num?)?.toDouble() ?? 0.0,
        netOdenen: (map['netOdenen'] as num?)?.toDouble() ?? 0.0,
        aylikGelirVergisiMatrahi: (map['aylikGelirVergisiMatrahi'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Damga Vergisi Satırı (Mizan 360.03.05 - Binde 9,48)
class DamgaVergisiBirimSatiri {
  final String birimAdi;
  final double damgaVergisi; // Mizan alacak kalanı
  final double matrah; // Damga / 0.00948

  const DamgaVergisiBirimSatiri({
    required this.birimAdi,
    required this.damgaVergisi,
    required this.matrah,
  });

  DamgaVergisiBirimSatiri copyWith({
    String? birimAdi,
    double? damgaVergisi,
    double? matrah,
  }) {
    return DamgaVergisiBirimSatiri(
      birimAdi: birimAdi ?? this.birimAdi,
      damgaVergisi: damgaVergisi ?? this.damgaVergisi,
      matrah: matrah ?? this.matrah,
    );
  }

  Map<String, dynamic> toMap() => {
        'birimAdi': birimAdi,
        'damgaVergisi': damgaVergisi,
        'matrah': matrah,
      };

  factory DamgaVergisiBirimSatiri.fromMap(Map<String, dynamic> map) =>
      DamgaVergisiBirimSatiri(
        birimAdi: map['birimAdi'] as String? ?? '',
        damgaVergisi: (map['damgaVergisi'] as num?)?.toDouble() ?? 0.0,
        matrah: (map['matrah'] as num?)?.toDouble() ?? 0.0,
      );
}

/// 600 Hesabı ve Kredi Kartı (123) Birim Satırı
class Hasiat600BirimSatiri {
  final String birimAdi;
  final double oncekiAylarHasilat600; // Ocak 1'den önceki aya kadar toplam
  final double aylikHasilat600; // Sadece bu ayın 600 hesabı
  final double kumulatifHasilat600; // Ocak 1'den bu yana kümülatif 600 hesabı
  final double krediKarti123; // 123 hesabı

  const Hasiat600BirimSatiri({
    required this.birimAdi,
    this.oncekiAylarHasilat600 = 0.0,
    this.aylikHasilat600 = 0.0,
    this.kumulatifHasilat600 = 0.0,
    this.krediKarti123 = 0.0,
  });

  Hasiat600BirimSatiri copyWith({
    String? birimAdi,
    double? oncekiAylarHasilat600,
    double? aylikHasilat600,
    double? kumulatifHasilat600,
    double? krediKarti123,
  }) {
    return Hasiat600BirimSatiri(
      birimAdi: birimAdi ?? this.birimAdi,
      oncekiAylarHasilat600: oncekiAylarHasilat600 ?? this.oncekiAylarHasilat600,
      aylikHasilat600: aylikHasilat600 ?? this.aylikHasilat600,
      kumulatifHasilat600: kumulatifHasilat600 ?? this.kumulatifHasilat600,
      krediKarti123: krediKarti123 ?? this.krediKarti123,
    );
  }

  Map<String, dynamic> toMap() => {
        'birimAdi': birimAdi,
        'oncekiAylarHasilat600': oncekiAylarHasilat600,
        'aylikHasilat600': aylikHasilat600,
        'kumulatifHasilat600': kumulatifHasilat600,
        'krediKarti123': krediKarti123,
      };

  factory Hasiat600BirimSatiri.fromMap(Map<String, dynamic> map) =>
      Hasiat600BirimSatiri(
        birimAdi: map['birimAdi'] as String? ?? '',
        oncekiAylarHasilat600:
            (map['oncekiAylarHasilat600'] as num?)?.toDouble() ?? 0.0,
        aylikHasilat600: (map['aylikHasilat600'] as num?)?.toDouble() ?? 0.0,
        kumulatifHasilat600:
            (map['kumulatifHasilat600'] as num?)?.toDouble() ?? 0.0,
        krediKarti123: (map['krediKarti123'] as num?)?.toDouble() ?? 0.0,
      );
}

/// Birim Bazlı Vergiler İcmali
class BirimVergiIcmalSatiri {
  final String birimAdi;
  final double kdv1Tutari;
  final double damgaVb;
  final double muhtasarGelir;
  final double muhtasarDamga;
  final double muhtasarKesilenDamga;

  /// Tevkifat etiketi ('9/10', '7/10', '5/10' veya kurum tanımlı serbest
  /// türler) -> tutar. Tek kaynaktır; eski sabit alanlar bu haritadan türetilir.
  final Map<String, double> kdv2TevkifatTutar;

  const BirimVergiIcmalSatiri({
    required this.birimAdi,
    this.kdv1Tutari = 0.0,
    this.damgaVb = 0.0,
    this.muhtasarGelir = 0.0,
    this.muhtasarDamga = 0.0,
    this.muhtasarKesilenDamga = 0.0,
    this.kdv2TevkifatTutar = const {},
  });

  /// Belirtilen tevkifat etiketine ait tutar.
  double kdv2Tutar(String etiket) => kdv2TevkifatTutar[etiket] ?? 0.0;

  // Geriye dönük uyum: bilinen üç tür için kısayol getter'lar.
  double get kdv2DokuzBoluOn => kdv2Tutar('9/10');
  double get kdv2YediBoluOn => kdv2Tutar('7/10');
  double get kdv2BesBoluOn => kdv2Tutar('5/10');

  /// Excel "Birim Bazlı Vergiler" sayfasındaki "MUHTASAR TOPLAM ÖDENECEK"
  /// formülü: MUHTASAR DAMGA + MUHTASAR ÖDEMELERİNDE KESİLEN DAMGA.
  /// MUHTASAR GELİR ayrı kolonda raporlanır, bu toplama dahil edilmez
  /// (örn. TÖMER: 26,64 + 331,75 = 358,39; DÖSİM: 0 + 417,35 = 417,35).
  double get muhtasarToplam => muhtasarDamga + muhtasarKesilenDamga;
  double get kdv2Toplam =>
      kdv2TevkifatTutar.values.fold(0.0, (s, v) => s + v);
  double get genelToplamOdenecek =>
      kdv1Tutari + damgaVb + muhtasarToplam + kdv2Toplam;

  /// Birimin merkezi kısa adı (ör: DÖSİM, UBATAM, DTS, USEM, Diş Hekimliği...)
  String get kisaAd => BirimAdlandirma.kisaAdGetir(birimAdi);

  /// Birimin resmi tam adı
  String get tamAd => BirimAdlandirma.tamAdGetir(birimAdi);
}

/// Aylık Konsolide Beyanname Paketi (Kaydedilebilir Belge)
class BeyannameDonemModel {
  final String id;
  final int yil;
  final int ay; // 1-12
  final String baslik;
  final DateTime guncellenmeTarihi;

  final double oncekiAydanDevredenKdv;
  final List<Kdv1BirimSatiri> kdv1Satirlari;
  final List<TevkifatFirmaKaydi> tevkifatKayitlari;
  final List<MuhtasarSatiri> muhtasarSatirlari;
  final List<DamgaVergisiBirimSatiri> damgaSatirlari;
  final List<Hasiat600BirimSatiri> hasiat600Satirlari;

  const BeyannameDonemModel({
    required this.id,
    required this.yil,
    required this.ay,
    required this.baslik,
    required this.guncellenmeTarihi,
    this.oncekiAydanDevredenKdv = 0.0,
    this.kdv1Satirlari = const [],
    this.tevkifatKayitlari = const [],
    this.muhtasarSatirlari = const [],
    this.damgaSatirlari = const [],
    this.hasiat600Satirlari = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'yil': yil,
        'ay': ay,
        'baslik': baslik,
        'guncellenmeTarihi': guncellenmeTarihi.toIso8601String(),
        'oncekiAydanDevredenKdv': oncekiAydanDevredenKdv,
        'kdv1Satirlari': kdv1Satirlari.map((e) => e.toMap()).toList(),
        'tevkifatKayitlari': tevkifatKayitlari.map((e) => e.toMap()).toList(),
        'muhtasarSatirlari': muhtasarSatirlari.map((e) => e.toMap()).toList(),
        'damgaSatirlari': damgaSatirlari.map((e) => e.toMap()).toList(),
        'hasiat600Satirlari': hasiat600Satirlari.map((e) => e.toMap()).toList(),
      };

  factory BeyannameDonemModel.fromMap(Map<String, dynamic> map) =>
      BeyannameDonemModel(
        id: map['id'] as String? ?? '',
        yil: (map['yil'] as num?)?.toInt() ?? DateTime.now().year,
        ay: (map['ay'] as num?)?.toInt() ?? DateTime.now().month,
        baslik: map['baslik'] as String? ?? '',
        guncellenmeTarihi: map['guncellenmeTarihi'] != null
            ? DateTime.parse(map['guncellenmeTarihi'] as String)
            : DateTime.now(),
        oncekiAydanDevredenKdv:
            (map['oncekiAydanDevredenKdv'] as num?)?.toDouble() ?? 0.0,
        kdv1Satirlari: (map['kdv1Satirlari'] as List<dynamic>?)
                ?.map((e) => Kdv1BirimSatiri.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        tevkifatKayitlari: (map['tevkifatKayitlari'] as List<dynamic>?)
                ?.map((e) => TevkifatFirmaKaydi.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        muhtasarSatirlari: (map['muhtasarSatirlari'] as List<dynamic>?)
                ?.map((e) => MuhtasarSatiri.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
        damgaSatirlari: (map['damgaSatirlari'] as List<dynamic>?)
                ?.map((e) => DamgaVergisiBirimSatiri.fromMap(
                    e as Map<String, dynamic>))
                .toList() ??
            const [],
        hasiat600Satirlari: (map['hasiat600Satirlari'] as List<dynamic>?)
                ?.map((e) =>
                    Hasiat600BirimSatiri.fromMap(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

/// Geriye Dönük Birim Vergi Arama / Geçmiş İnceleme Kaydı
class BirimGecmisVergiKaydi {
  final int yil;
  final int ay;
  final String donemBaslik;
  final String birimAdi;
  final double kdv1NetOdenecek;
  final double kdv2Tevkifat;
  final double muhtasarGelirVergisi;
  final double muhtasarDamgaVergisi;
  final double damgaVergisi360;
  final double hasilat600Aylik;
  final double krediKarti123;

  const BirimGecmisVergiKaydi({
    required this.yil,
    required this.ay,
    required this.donemBaslik,
    required this.birimAdi,
    required this.kdv1NetOdenecek,
    required this.kdv2Tevkifat,
    required this.muhtasarGelirVergisi,
    required this.muhtasarDamgaVergisi,
    required this.damgaVergisi360,
    required this.hasilat600Aylik,
    required this.krediKarti123,
  });

  double get toplamOdenecekVergi =>
      kdv1NetOdenecek +
      kdv2Tevkifat +
      muhtasarGelirVergisi +
      muhtasarDamgaVergisi +
      damgaVergisi360;
}
