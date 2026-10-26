import 'dart:typed_data';
import '../../../core/turkce_format.dart';

/// Birim için yüklenebilecek belge slot türleri.
/// Gelecekte muhtasar bordrosu veya fatura listesi eklenmesi için genişletilebilir.
enum BirimBelgeSlotTuru {
  aylikMizan('Aylık Mizan', 'Seçili ayın resmi mizanı (PDF/Excel)', true),
  yardimciMizan('Yardımcı Mizan', 'Muavin / Alt hesap mizanı (%10, %20 ve Gelir kırılımları)', false),
  yillikMizan('Yıllık Mizan', 'Ocak - Seçili ay kümülatif mizanı (PDF/Excel)', true),
  diger('Tevkifat Faturası (İsteğe Bağlı)', 'Varsa KDV 2 tevkifat faturası (yolluk/harcırah gerekmez)', false),
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

  // 391 Hesaplanan KDV (%1, %10 ve %20)
  final double hesaplananKdvMatrah1;
  final double hesaplananKdv1;
  final double hesaplananKdvMatrah10;
  final double hesaplananKdv10;
  final double hesaplananKdvMatrah20;
  final double hesaplananKdv20;

  // 191 İndirilecek KDV (%1, %10 ve %20)
  final double indirilecekKdvMatrah1;
  final double indirilecekKdv1;
  final double indirilecekKdvMatrah10;
  final double indirilecekKdv10;
  final double indirilecekKdvMatrah20;
  final double indirilecekKdv20;

  // 360.03.05 Damga Vergisi (Ödemelerden Kesilen)
  final double damgaVergisi360;
  final double damgaMatrah;

  // 360.03.02 & 360.03.03 İhale / Sözleşme & Karar Pulu Damga Vergileri (Diş Hekimliği vb.)
  final double ihaleSozlesmeDamga360;
  final double ihaleKararPuluDamga360;

  // 360.04 Mizan KDV 2 Tevkifatı (Sorumlu Sıfatıyla Ödenecek KDV)
  final double kdv2Tevkifat360;
  final String kdv2HesapDetayi;

  // 360 Muhtasar
  final double muhtasarGelir360;
  final double muhtasarDamga360;

  // 190 Devreden KDV (Mizan Borç Kalanı)
  final double devredenKdv190;

  // Diğer belgelerden veya mizandan varsa Tevkifatlı Faturalar
  final List<Map<String, dynamic>> tevkifatFaturalari;

  // Yardımcı Mizan (Muavin) Mutabakat Bilgileri
  final bool yardimciMizanKullanildi;
  final double yardimciMizan391Toplam;
  final double yardimciMizan191Toplam;
  final double yardimciMizan600Toplam;

  // Ham AI yanıtı veya log notları
  final String? aciklama;
  final Map<String, dynamic>? hamJson;

  const BirimMizanAnalizSonucu({
    required this.birimAdi,
    required this.analizTarihi,
    this.hasilat600Aylik = 0.0,
    this.hasilat600Kumulatif = 0.0,
    this.krediKarti123 = 0.0,
    this.hesaplananKdvMatrah1 = 0.0,
    this.hesaplananKdv1 = 0.0,
    this.hesaplananKdvMatrah10 = 0.0,
    this.hesaplananKdv10 = 0.0,
    this.hesaplananKdvMatrah20 = 0.0,
    this.hesaplananKdv20 = 0.0,
    this.indirilecekKdvMatrah1 = 0.0,
    this.indirilecekKdv1 = 0.0,
    this.indirilecekKdvMatrah10 = 0.0,
    this.indirilecekKdv10 = 0.0,
    this.indirilecekKdvMatrah20 = 0.0,
    this.indirilecekKdv20 = 0.0,
    this.damgaVergisi360 = 0.0,
    this.damgaMatrah = 0.0,
    this.ihaleSozlesmeDamga360 = 0.0,
    this.ihaleKararPuluDamga360 = 0.0,
    this.kdv2Tevkifat360 = 0.0,
    this.kdv2HesapDetayi = '',
    this.muhtasarGelir360 = 0.0,
    this.muhtasarDamga360 = 0.0,
    this.devredenKdv190 = 0.0,
    this.tevkifatFaturalari = const [],
    this.yardimciMizanKullanildi = false,
    this.yardimciMizan391Toplam = 0.0,
    this.yardimciMizan191Toplam = 0.0,
    this.yardimciMizan600Toplam = 0.0,
    this.aciklama,
    this.hamJson,
  });

  double get toplamHesaplananKdv => hesaplananKdv1 + hesaplananKdv10 + hesaplananKdv20;
  double get toplamHesaplananMatrah => hesaplananKdvMatrah1 + hesaplananKdvMatrah10 + hesaplananKdvMatrah20;
  double get toplamIndirilecekKdv => indirilecekKdv1 + indirilecekKdv10 + indirilecekKdv20;
  double get netKdv => toplamHesaplananKdv - toplamIndirilecekKdv;

  Map<String, dynamic> toMap() => {
        'birimAdi': birimAdi,
        'analizTarihi': analizTarihi.toIso8601String(),
        'hasilat600Aylik': hasilat600Aylik,
        'hasilat600Kumulatif': hasilat600Kumulatif,
        'krediKarti123': krediKarti123,
        'hesaplananKdvMatrah1': hesaplananKdvMatrah1,
        'hesaplananKdv1': hesaplananKdv1,
        'hesaplananKdvMatrah10': hesaplananKdvMatrah10,
        'hesaplananKdv10': hesaplananKdv10,
        'hesaplananKdvMatrah20': hesaplananKdvMatrah20,
        'hesaplananKdv20': hesaplananKdv20,
        'indirilecekKdvMatrah1': indirilecekKdvMatrah1,
        'indirilecekKdv1': indirilecekKdv1,
        'indirilecekKdvMatrah10': indirilecekKdvMatrah10,
        'indirilecekKdv10': indirilecekKdv10,
        'indirilecekKdvMatrah20': indirilecekKdvMatrah20,
        'indirilecekKdv20': indirilecekKdv20,
        'damgaVergisi360': damgaVergisi360,
        'damgaMatrah': damgaMatrah,
        'ihaleSozlesmeDamga360': ihaleSozlesmeDamga360,
        'ihaleKararPuluDamga360': ihaleKararPuluDamga360,
        'kdv2Tevkifat360': kdv2Tevkifat360,
        'kdv2HesapDetayi': kdv2HesapDetayi,
        'muhtasarGelir360': muhtasarGelir360,
        'muhtasarDamga360': muhtasarDamga360,
        'devredenKdv190': devredenKdv190,
        'tevkifatFaturalari': tevkifatFaturalari,
        'yardimciMizanKullanildi': yardimciMizanKullanildi,
        'yardimciMizan391Toplam': yardimciMizan391Toplam,
        'yardimciMizan191Toplam': yardimciMizan191Toplam,
        'yardimciMizan600Toplam': yardimciMizan600Toplam,
        'aciklama': aciklama,
      };

  static bool _parseBool(dynamic val) {
    if (val == null) return false;
    if (val is bool) return val;
    if (val is num) return val != 0;
    final s = val.toString().trim().toLowerCase();
    return s == 'true' || s == '1' || s == 'evet' || s == 'yes';
  }

  /// Ham KDV oranı alanı (%10, 10, "10" vb.) ve Matrah/KDV tutarlarından
  /// kesin KDV oranını (1, 8, 10, 18, 20) çözümler.
  static int cozumleKdvOrani({
    dynamic hamKdvOrani,
    required double matrah,
    required double kdv,
  }) {
    // 1. Önce açıkça verilen kdvOrani değerini kontrol et
    int? acikOran;
    if (hamKdvOrani is num) {
      final v = hamKdvOrani.toInt();
      if (const [1, 8, 10, 18, 20].contains(v)) {
        acikOran = v;
      }
    } else if (hamKdvOrani != null) {
      final rakamStr = hamKdvOrani.toString().replaceAll(RegExp(r'[^\d]'), '');
      final v = int.tryParse(rakamStr);
      if (v != null && const [1, 8, 10, 18, 20].contains(v)) {
        acikOran = v;
      }
    }

    // 2. Matrah ve KDV tutarı biliniyorsa matematiksel oranı hesapla
    if (matrah > 0 && kdv > 0) {
      final yuzde = (kdv / matrah) * 100.0;
      if ((yuzde - 10.0).abs() <= 1.5) return 10;
      if ((yuzde - 20.0).abs() <= 1.8) return 20;
      if ((yuzde - 1.0).abs() <= 0.4) return 1;
      if ((yuzde - 8.0).abs() <= 1.0) return 8;
      if ((yuzde - 18.0).abs() <= 1.2) return 18;
    }

    return acikOran ?? 20;
  }

  /// Aynı faturada birden fazla tevkifat oranı (örn. 9/10, 7/10, 5/10) veya
  /// farklı KDV oranları (%10 ve %20) olduğunda bunların birbirini ezmesini önleyen
  /// akıllı mükerrerlik kontrolü.
  static bool tevkifatSatiriMukerrerMi(
    Map<String, dynamic> mevcut,
    Map<String, dynamic> yeni,
  ) {
    final mFNo = (mevcut['faturaNo'] ?? '').toString().trim();
    final yFNo = (yeni['faturaNo'] ?? '').toString().trim();
    final mOran = (mevcut['tevkifatOrani'] ?? '9/10').toString().trim();
    final yOran = (yeni['tevkifatOrani'] ?? '9/10').toString().trim();
    final mMtr = TurkceFormat.parseSayi(mevcut['matrahTutari']);
    final yMtr = TurkceFormat.parseSayi(yeni['matrahTutari']);
    final mKdv = TurkceFormat.parseSayi(mevcut['kdvTutari']);
    final yKdv = TurkceFormat.parseSayi(yeni['kdvTutari']);
    final mKdvOrani = cozumleKdvOrani(
      hamKdvOrani: mevcut['kdvOrani'],
      matrah: mMtr,
      kdv: mKdv,
    );
    final yKdvOrani = cozumleKdvOrani(
      hamKdvOrani: yeni['kdvOrani'],
      matrah: yMtr,
      kdv: yKdv,
    );

    // Eğer tevkifat oranı veya KDV oranı farklıysa kesinlikle mükerrer değildir (aynı faturanın farklı kırılımıdır)!
    if (mOran != yOran || mKdvOrani != yKdvOrani) {
      return false;
    }

    // Aynı fatura numarası varsa: Yalnızca hem tevkifat oranı hem KDV oranı hem de matrahı aynıysa mükerrerdir!
    if (mFNo.isNotEmpty && yFNo.isNotEmpty) {
      if (mFNo != yFNo) return false;
      return (mMtr - yMtr).abs() < 1.0;
    }

    final mVkn = (mevcut['vergiTcNo'] ?? '').toString().trim();
    final yVkn = (yeni['vergiTcNo'] ?? '').toString().trim();
    final ayniFirma = (mVkn.isNotEmpty && mVkn == yVkn) ||
        (mevcut['firmaAdi']?.toString().toLowerCase().trim() ==
            yeni['firmaAdi']?.toString().toLowerCase().trim());
    final ayniMatrah = (mMtr - yMtr).abs() < 1.0;
    return ayniFirma && ayniMatrah;
  }

  factory BirimMizanAnalizSonucu.fromMap(Map<String, dynamic> map) {
    return BirimMizanAnalizSonucu(
      birimAdi: map['birimAdi'] as String? ?? '',
      analizTarihi: map['analizTarihi'] != null
          ? DateTime.tryParse(map['analizTarihi'] as String) ?? DateTime.now()
          : DateTime.now(),
      hasilat600Aylik: TurkceFormat.parseSayi(map['hasilat600Aylik']),
      hasilat600Kumulatif: TurkceFormat.parseSayi(map['hasilat600Kumulatif']),
      krediKarti123: TurkceFormat.parseSayi(map['krediKarti123']),
      hesaplananKdvMatrah1: TurkceFormat.parseSayi(map['hesaplananKdvMatrah1']),
      hesaplananKdv1: TurkceFormat.parseSayi(map['hesaplananKdv1']),
      hesaplananKdvMatrah10: TurkceFormat.parseSayi(map['hesaplananKdvMatrah10']),
      hesaplananKdv10: TurkceFormat.parseSayi(map['hesaplananKdv10']),
      hesaplananKdvMatrah20: TurkceFormat.parseSayi(map['hesaplananKdvMatrah20']),
      hesaplananKdv20: TurkceFormat.parseSayi(map['hesaplananKdv20']),
      indirilecekKdvMatrah1: TurkceFormat.parseSayi(map['indirilecekKdvMatrah1']),
      indirilecekKdv1: TurkceFormat.parseSayi(map['indirilecekKdv1']),
      indirilecekKdvMatrah10: TurkceFormat.parseSayi(map['indirilecekKdvMatrah10']),
      indirilecekKdv10: TurkceFormat.parseSayi(map['indirilecekKdv10']),
      indirilecekKdvMatrah20: TurkceFormat.parseSayi(map['indirilecekKdvMatrah20']),
      indirilecekKdv20: TurkceFormat.parseSayi(map['indirilecekKdv20']),
      damgaVergisi360: TurkceFormat.parseSayi(map['damgaVergisi360']),
      damgaMatrah: TurkceFormat.parseSayi(map['damgaMatrah']),
      ihaleSozlesmeDamga360: TurkceFormat.parseSayi(map['ihaleSozlesmeDamga360']),
      ihaleKararPuluDamga360: TurkceFormat.parseSayi(map['ihaleKararPuluDamga360']),
      kdv2Tevkifat360: TurkceFormat.parseSayi(map['kdv2Tevkifat360']),
      kdv2HesapDetayi: map['kdv2HesapDetayi']?.toString() ?? '',
      muhtasarGelir360: TurkceFormat.parseSayi(map['muhtasarGelir360']),
      muhtasarDamga360: TurkceFormat.parseSayi(map['muhtasarDamga360']),
      devredenKdv190: TurkceFormat.parseSayi(map['devredenKdv190']),
      tevkifatFaturalari: (map['tevkifatFaturalari'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) {
                final m = Map<String, dynamic>.from(e);
                final mtr = TurkceFormat.parseSayi(m['matrahTutari']);
                final kdv = TurkceFormat.parseSayi(m['kdvTutari']);
                m['matrahTutari'] = mtr;
                m['kdvTutari'] = kdv;
                m['tevkifatTutari'] = TurkceFormat.parseSayi(m['tevkifatTutari']);
                m['firmaAdi'] = m['firmaAdi']?.toString() ?? 'Firma';
                m['vergiTcNo'] = m['vergiTcNo']?.toString().trim() ?? '';
                m['tevkifatOrani'] = m['tevkifatOrani']?.toString() ?? '9/10';
                m['kdvOrani'] = cozumleKdvOrani(
                  hamKdvOrani: m['kdvOrani'],
                  matrah: mtr,
                  kdv: kdv,
                );
                return m;
              })
              .toList() ??
          const [],
      yardimciMizanKullanildi: _parseBool(map['yardimciMizanKullanildi']),
      yardimciMizan391Toplam: TurkceFormat.parseSayi(map['yardimciMizan391Toplam']),
      yardimciMizan191Toplam: TurkceFormat.parseSayi(map['yardimciMizan191Toplam']),
      yardimciMizan600Toplam: TurkceFormat.parseSayi(map['yardimciMizan600Toplam']),
      aciklama: map['aciklama'] as String?,
      hamJson: map,
    );
  }
}
