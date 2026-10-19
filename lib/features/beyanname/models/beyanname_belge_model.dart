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
    this.yardimciMizanKullanildi = false,
    this.yardimciMizan391Toplam = 0.0,
    this.yardimciMizan191Toplam = 0.0,
    this.yardimciMizan600Toplam = 0.0,
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

  factory BirimMizanAnalizSonucu.fromMap(Map<String, dynamic> map) {
    return BirimMizanAnalizSonucu(
      birimAdi: map['birimAdi'] as String? ?? '',
      analizTarihi: map['analizTarihi'] != null
          ? DateTime.tryParse(map['analizTarihi'] as String) ?? DateTime.now()
          : DateTime.now(),
      hasilat600Aylik: TurkceFormat.parseSayi(map['hasilat600Aylik']),
      hasilat600Kumulatif: TurkceFormat.parseSayi(map['hasilat600Kumulatif']),
      krediKarti123: TurkceFormat.parseSayi(map['krediKarti123']),
      hesaplananKdvMatrah10: TurkceFormat.parseSayi(map['hesaplananKdvMatrah10']),
      hesaplananKdv10: TurkceFormat.parseSayi(map['hesaplananKdv10']),
      hesaplananKdvMatrah20: TurkceFormat.parseSayi(map['hesaplananKdvMatrah20']),
      hesaplananKdv20: TurkceFormat.parseSayi(map['hesaplananKdv20']),
      indirilecekKdvMatrah10: TurkceFormat.parseSayi(map['indirilecekKdvMatrah10']),
      indirilecekKdv10: TurkceFormat.parseSayi(map['indirilecekKdv10']),
      indirilecekKdvMatrah20: TurkceFormat.parseSayi(map['indirilecekKdvMatrah20']),
      indirilecekKdv20: TurkceFormat.parseSayi(map['indirilecekKdv20']),
      damgaVergisi360: TurkceFormat.parseSayi(map['damgaVergisi360']),
      damgaMatrah: TurkceFormat.parseSayi(map['damgaMatrah']),
      muhtasarGelir360: TurkceFormat.parseSayi(map['muhtasarGelir360']),
      muhtasarDamga360: TurkceFormat.parseSayi(map['muhtasarDamga360']),
      devredenKdv190: TurkceFormat.parseSayi(map['devredenKdv190']),
      tevkifatFaturalari: (map['tevkifatFaturalari'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) {
                final m = Map<String, dynamic>.from(e);
                m['matrahTutari'] = TurkceFormat.parseSayi(m['matrahTutari']);
                m['kdvTutari'] = TurkceFormat.parseSayi(m['kdvTutari']);
                m['tevkifatTutari'] = TurkceFormat.parseSayi(m['tevkifatTutari']);
                m['firmaAdi'] = m['firmaAdi']?.toString() ?? 'Firma';
                m['vergiTcNo'] = m['vergiTcNo']?.toString().trim() ?? '';
                m['tevkifatOrani'] = m['tevkifatOrani']?.toString() ?? '9/10';
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
