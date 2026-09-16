enum BirimTuru {
  merkez('merkez', 'Merkez'),
  fakulte('fakulte', 'Fakülte'),
  enstitu('enstitu', 'Enstitü'),
  meslekYuksekokulu('meslek_yuksekokulu', 'Meslek Yüksekokulu');

  const BirimTuru(this.value, this.displayName);
  final String value;
  final String displayName;

  static BirimTuru fromString(String value) {
    return BirimTuru.values.firstWhere(
      (t) => t.value == value,
      orElse: () => BirimTuru.merkez,
    );
  }
}

class BirimModel {
  const BirimModel({
    required this.id,
    required this.ad,
    required this.kisaAd,
    required this.tur,
    this.mudurAd,
    this.iban,
    this.hesapAdi,
    this.vkn,
    this.aktif = true,
  });

  final String id;
  final String ad;
  final String kisaAd;
  final BirimTuru tur;
  final String? mudurAd;
  final String? iban;
  final String? hesapAdi;
  final String? vkn;
  final bool aktif;

  factory BirimModel.fromMap(String id, Map<String, dynamic> map) {
    return BirimModel(
      id: id,
      ad: map['ad'] as String? ?? '',
      kisaAd: map['kisaAd'] as String? ?? '',
      tur: BirimTuru.fromString(map['tur'] as String? ?? 'merkez'),
      mudurAd: map['mudurAd'] as String?,
      iban: map['iban'] as String?,
      hesapAdi: map['hesapAdi'] as String?,
      vkn: map['vkn'] as String?,
      aktif: map['aktif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ad': ad,
      'kisaAd': kisaAd,
      'tur': tur.value,
      'mudurAd': mudurAd,
      'iban': iban,
      'hesapAdi': hesapAdi,
      'vkn': vkn,
      'aktif': aktif,
    };
  }

  BirimModel copyWith({
    String? ad,
    String? kisaAd,
    BirimTuru? tur,
    String? mudurAd,
    String? iban,
    String? hesapAdi,
    String? vkn,
    bool? aktif,
  }) {
    return BirimModel(
      id: id,
      ad: ad ?? this.ad,
      kisaAd: kisaAd ?? this.kisaAd,
      tur: tur ?? this.tur,
      mudurAd: mudurAd ?? this.mudurAd,
      iban: iban ?? this.iban,
      hesapAdi: hesapAdi ?? this.hesapAdi,
      vkn: vkn ?? this.vkn,
      aktif: aktif ?? this.aktif,
    );
  }

  /// Resmi Uşak Üniversitesi Döner Sermaye Alt Hesap İBAN listesi (Varsayılan/Sistem Birimleri)
  static const List<BirimModel> varsayilanBirimler = [
    BirimModel(
      id: 'default_tomer',
      ad: 'Türkçe Öğretimi Uygulama ve Araştırma Merkezi (TÖMER)',
      kisaAd: 'TÖMER',
      tur: BirimTuru.merkez,
      hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Türkçe Öğrenimi DSİ',
      iban: 'TR040001001758672359525003',
      vkn: '8960466329',
      aktif: true,
    ),
    BirimModel(
      id: 'default_dis',
      ad: 'Ağız ve Diş Sağlığı Uygulama ve Araştırma Merkezi (Diş Hekimliği)',
      kisaAd: 'Diş Hekimliği',
      tur: BirimTuru.merkez,
      hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Ağız ve Diş Sağlığı DSİ',
      iban: 'TR880001001758890982805002',
      vkn: '8960475707',
      aktif: true,
    ),
    BirimModel(
      id: 'default_ubatam',
      ad: 'Bilimsel Analiz ve Teknolojik Uygulama ve Araştırma Merkezi (UBATAM)',
      kisaAd: 'UBATAM',
      tur: BirimTuru.merkez,
      hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Bilimsel Analiz ve Teknolojik DSİ',
      iban: 'TR290001001758672359025003',
      vkn: '8960466311',
      aktif: true,
    ),
    BirimModel(
      id: 'default_usem',
      ad: 'Sürekli Eğitim Uygulama ve Araştırma Merkezi (USEM)',
      kisaAd: 'USEM',
      tur: BirimTuru.merkez,
      hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Sürekli Eğitim DSİ',
      iban: 'TR500001001758672355695003',
      vkn: '8960466257',
      aktif: true,
    ),
    BirimModel(
      id: 'default_dts',
      ad: 'Deri, Tekstil ve Seramik Tasarım Uygulama ve Araştırma Merkezi (DTS)',
      kisaAd: 'DTS',
      tur: BirimTuru.merkez,
      hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Deri, Tekstil ve Seramik DSİ',
      iban: 'TR090001001758975714095007',
      vkn: '2931062663',
      aktif: true,
    ),
    BirimModel(
      id: 'default_tadaum',
      ad: 'Tarımsal ve Doğa Araştırmaları Uygulama ve Araştırma Merkezi (TADAUM)',
      kisaAd: 'TADAUM',
      tur: BirimTuru.merkez,
      hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Tarımsal ve Doğa Araştırmaları DSİ',
      iban: 'TR190001001758982110835002',
      vkn: '8240526649',
      aktif: true,
    ),
    BirimModel(
      id: 'default_dosim',
      ad: 'Döner Sermaye İşletme Müdürlüğü (DÖSİM)',
      kisaAd: 'DÖSİM',
      tur: BirimTuru.merkez,
      hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /DÖSİM',
      iban: 'TR850001001758517844115013',
      vkn: '8960453664',
      aktif: true,
    ),
  ];
}

/// Resmi birim adlarını standartlaştırma ve tekilleştirme (deduplication) yardımcısı
class BirimAdlandirma {
  /// Birim adını/kısaltmasını resmi tam adına dönüştürür ve tekilleştirir
  static String tamAdGetir(String? input) {
    if (input == null || input.trim().isEmpty) return '';
    final s = input.trim().toLowerCase();

    // 1. DÖSİM / DSİM / Döner Sermaye
    if (s.contains('dösim') || s.contains('dsim') || s.contains('döner sermaye')) {
      return 'Döner Sermaye İşletme Müdürlüğü (DÖSİM)';
    }

    // 2. Ağız ve Diş Sağlığı / Diş Hekimliği / ADUM
    if (s.contains('diş') || s.contains('dis') || s.contains('adum') || s.contains('ağız')) {
      return 'Ağız ve Diş Sağlığı Uygulama ve Araştırma Merkezi (Diş Hekimliği)';
    }

    // 3. UBATAM / Bilimsel Analiz
    if (s.contains('ubatam') || s.contains('bilimsel analiz')) {
      return 'Bilimsel Analiz ve Teknolojik Uygulama ve Araştırma Merkezi (UBATAM)';
    }

    // 4. USEM / Sürekli Eğitim
    if (s.contains('usem') || s.contains('sürekli eğitim')) {
      return 'Sürekli Eğitim Uygulama ve Araştırma Merkezi (USEM)';
    }

    // 5. DTS / Deri Tekstil
    if (s.contains('dts') || s.contains('deri') || s.contains('tekstil')) {
      return 'Deri, Tekstil ve Seramik Tasarım Uygulama ve Araştırma Merkezi (DTS)';
    }

    // 6. TÖMER / Türkçe Öğretimi
    if (s.contains('tömer') || s.contains('tomer') || s.contains('türkçe')) {
      return 'Türkçe Öğretimi Uygulama ve Araştırma Merkezi (TÖMER)';
    }

    // 7. TADAUM / Tarımsal
    if (s.contains('tadaum') || s.contains('tarımsal') || s.contains('tarimsal')) {
      return 'Tarımsal ve Doğa Araştırmaları Uygulama ve Araştırma Merkezi (TADAUM)';
    }

    // 8. UZEM / Uzaktan Eğitim
    if (s.contains('uzem') || s.contains('uzaktan')) {
      return 'Uzaktan Eğitim Uygulama ve Araştırma Merkezi (UZEM)';
    }

    return input.trim();
  }

  /// Tekilleştirme için ortak anahtar üretir
  static String canonicalKey(String? input) {
    if (input == null || input.trim().isEmpty) return '';
    final s = input.trim().toLowerCase();
    if (s.contains('dösim') || s.contains('dsim') || s.contains('döner sermaye')) return 'dosim';
    if (s.contains('diş') || s.contains('dis') || s.contains('adum') || s.contains('ağız')) return 'dis';
    if (s.contains('ubatam') || s.contains('bilimsel')) return 'ubatam';
    if (s.contains('usem') || s.contains('sürekli')) return 'usem';
    if (s.contains('dts') || s.contains('deri') || s.contains('tekstil')) return 'dts';
    if (s.contains('tömer') || s.contains('tomer') || s.contains('türkçe')) return 'tomer';
    if (s.contains('tadaum') || s.contains('tarım') || s.contains('tarim')) return 'tadaum';
    if (s.contains('uzem') || s.contains('uzaktan')) return 'uzem';
    return s;
  }

  /// Resmi kısa kodunu döner (yalnızca gerektiğinde)
  static String kisaAdGetir(String? input) {
    final key = canonicalKey(input);
    switch (key) {
      case 'dosim': return 'DÖSİM';
      case 'dis': return 'Diş Hekimliği';
      case 'ubatam': return 'UBATAM';
      case 'usem': return 'USEM';
      case 'dts': return 'DTS';
      case 'tomer': return 'TÖMER';
      case 'tadaum': return 'TADAUM';
      case 'uzem': return 'UZEM';
      default: return input?.trim() ?? '';
    }
  }
}
