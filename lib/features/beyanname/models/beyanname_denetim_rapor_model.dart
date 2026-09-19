import 'beyanname_belge_model.dart';

/// Denetim ve mutabakat kontrol seviyesi (AppColors durum renkleriyle eşleşir)
enum DenetimSeviyesi {
  bilgi('Bilgi / Onay', 'Mevzuata ve mizan denkliğine tam uygun'),
  uyari('Dikkat / İnceleme', 'İzahat gerektirebilecek tutarsızlık veya sapma'),
  hata('Kritik Hata', 'GİB/Defterdarlık reddi veya ceza riski taşıyan aykırılık');

  final String etiket;
  final String aciklama;

  const DenetimSeviyesi(this.etiket, this.aciklama);
}

/// "Neyi Nereden Aldı, Nereye Yerleştirdi?" Şeffaf Takip Kaydı (Audit Trail)
class NeredenNereyeKaydi {
  final String birimAdi;
  final String kaynakBelge; // Örn: "DÖSİM - Aylık Mizan (s.2)"
  final String hesapKoduVeAdi; // Örn: "600.01 Yurt İçi Satışlar (Alacak Hareketi)"
  final double bulunanTutar;
  final String hedefAlan; // Örn: "600 Hasılat Masası -> Aylık Hasılat"
  final String? aciklama;
  final double guvenSkoru; // 0.0 - 1.0 (örn: 0.98)

  const NeredenNereyeKaydi({
    required this.birimAdi,
    required this.kaynakBelge,
    required this.hesapKoduVeAdi,
    required this.bulunanTutar,
    required this.hedefAlan,
    this.aciklama,
    this.guvenSkoru = 1.0,
  });

  Map<String, dynamic> toMap() => {
        'birimAdi': birimAdi,
        'kaynakBelge': kaynakBelge,
        'hesapKoduVeAdi': hesapKoduVeAdi,
        'bulunanTutar': bulunanTutar,
        'hedefAlan': hedefAlan,
        'aciklama': aciklama,
        'guvenSkoru': guvenSkoru,
      };

  factory NeredenNereyeKaydi.fromMap(Map<String, dynamic> map) {
    return NeredenNereyeKaydi(
      birimAdi: map['birimAdi'] as String? ?? '',
      kaynakBelge: map['kaynakBelge'] as String? ?? '',
      hesapKoduVeAdi: map['hesapKoduVeAdi'] as String? ?? '',
      bulunanTutar: (map['bulunanTutar'] as num?)?.toDouble() ?? 0.0,
      hedefAlan: map['hedefAlan'] as String? ?? '',
      aciklama: map['aciklama'] as String?,
      guvenSkoru: (map['guvenSkoru'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

/// Çapraz Kontrol, Denetim ve Hata/Tutarsızlık Kaydı
class MutabakatKontrolKaydi {
  final String id;
  final int senaryoNo; // 1-9
  final String birimAdi;
  final String baslik;
  final DenetimSeviyesi seviye;
  final double? beklenenDeger;
  final double? bulunanDeger;
  final double? fark;
  final String aciklama;
  final String? cozumOnerisi;

  const MutabakatKontrolKaydi({
    required this.id,
    required this.senaryoNo,
    required this.birimAdi,
    required this.baslik,
    required this.seviye,
    this.beklenenDeger,
    this.bulunanDeger,
    this.fark,
    required this.aciklama,
    this.cozumOnerisi,
  });

  bool get hatasiz => seviye == DenetimSeviyesi.bilgi;

  Map<String, dynamic> toMap() => {
        'id': id,
        'senaryoNo': senaryoNo,
        'birimAdi': birimAdi,
        'baslik': baslik,
        'seviye': seviye.name,
        'beklenenDeger': beklenenDeger,
        'bulunanDeger': bulunanDeger,
        'fark': fark,
        'aciklama': aciklama,
        'cozumOnerisi': cozumOnerisi,
      };

  factory MutabakatKontrolKaydi.fromMap(Map<String, dynamic> map) {
    return MutabakatKontrolKaydi(
      id: map['id'] as String? ?? '',
      senaryoNo: (map['senaryoNo'] as num?)?.toInt() ?? 0,
      birimAdi: map['birimAdi'] as String? ?? '',
      baslik: map['baslik'] as String? ?? '',
      seviye: DenetimSeviyesi.values.firstWhere(
        (e) => e.name == map['seviye'],
        orElse: () => DenetimSeviyesi.bilgi,
      ),
      beklenenDeger: (map['beklenenDeger'] as num?)?.toDouble(),
      bulunanDeger: (map['bulunanDeger'] as num?)?.toDouble(),
      fark: (map['fark'] as num?)?.toDouble(),
      aciklama: map['aciklama'] as String? ?? '',
      cozumOnerisi: map['cozumOnerisi'] as String?,
    );
  }
}

/// Tüm birimlerin analiz ve denetim sürecini kapsayan Konsolide Beyanname Ajan Raporu
class BeyannameAjanRaporu {
  final String id;
  final int yil;
  final int ay;
  final DateTime olusturulmaTarihi;
  final List<String> analizEdilenBirimler;
  final int toplamDosyaSayisi;

  /// Birim bazında çıkarılan ham ve yapısal mizan analiz sonuçları
  final Map<String, BirimMizanAnalizSonucu> birimSonuclari;

  /// Şeffaf denetim izi (Hangi belge -> Hangi hesap -> Hangi beyanname alanı)
  final List<NeredenNereyeKaydi> neredenNereyeListesi;

  /// 9 senaryolu çapraz kontrol ve mutabakat sonuçları
  final List<MutabakatKontrolKaydi> denetimKontrolleri;

  /// Kullanıcı bu raporu beyanname masalarına aktardı mı?
  final bool uygulandiMi;
  final DateTime? uygulanmaTarihi;

  const BeyannameAjanRaporu({
    required this.id,
    required this.yil,
    required this.ay,
    required this.olusturulmaTarihi,
    required this.analizEdilenBirimler,
    required this.toplamDosyaSayisi,
    required this.birimSonuclari,
    required this.neredenNereyeListesi,
    required this.denetimKontrolleri,
    this.uygulandiMi = false,
    this.uygulanmaTarihi,
  });

  int get kritikHataSayisi =>
      denetimKontrolleri.where((k) => k.seviye == DenetimSeviyesi.hata).length;

  int get uyariSayisi =>
      denetimKontrolleri.where((k) => k.seviye == DenetimSeviyesi.uyari).length;

  int get basariliKontrolSayisi =>
      denetimKontrolleri.where((k) => k.seviye == DenetimSeviyesi.bilgi).length;

  bool get kritikHataVarMi => kritikHataSayisi > 0;

  BeyannameAjanRaporu copyWith({
    bool? uygulandiMi,
    DateTime? uygulanmaTarihi,
  }) {
    return BeyannameAjanRaporu(
      id: id,
      yil: yil,
      ay: ay,
      olusturulmaTarihi: olusturulmaTarihi,
      analizEdilenBirimler: analizEdilenBirimler,
      toplamDosyaSayisi: toplamDosyaSayisi,
      birimSonuclari: birimSonuclari,
      neredenNereyeListesi: neredenNereyeListesi,
      denetimKontrolleri: denetimKontrolleri,
      uygulandiMi: uygulandiMi ?? this.uygulandiMi,
      uygulanmaTarihi: uygulanmaTarihi ?? this.uygulanmaTarihi,
    );
  }
}
