import '../../../core/turkce_format.dart';
import '../models/beyanname_model.dart';
import '../models/beyanname_konfigurasyonu.dart';
import 'beyanname_hesaplama_motoru.dart';

/// Uyarı seviyesi. Renk, UI katmanında bu seviyeye göre verilir; böylece
/// "tek anlam = tek renk" kuralı korunur (bkz. `RENK_SISTEMI.md`).
enum UyariSeviye {
  /// Kesin hata: veri matematiksel olarak tutarsız.
  /// (örn. tevkifat tutarı KDV'den büyük, net ödenen brütten büyük)
  hata,

  /// Dikkat: büyük olasılıkla eksik ya da tutarsız giriş.
  /// (örn. matrah girilmiş ama KDV boş)
  dikkat,

  /// Bilgi: hata değil; kullanıcıyı yönlendiren nötr not.
  /// (örn. "bu dönem devreden KDV oluşuyor")
  bilgi,
}

/// Tek bir doğrulama uyarısı. Metin her zaman taşınır; çünkü anlam **asla**
/// yalnızca renge bırakılmaz (erişilebilirlik).
class BeyannameUyari {
  final UyariSeviye seviye;

  /// Kısa başlık: hangi birim/alan. (örn. "UBATAM • Hesaplanan %20")
  final String baslik;

  /// Kullanıcıya ne yapacağını anlatan açıklama.
  final String aciklama;

  const BeyannameUyari({
    required this.seviye,
    required this.baslik,
    required this.aciklama,
  });
}

/// Beyanname girişini kullanıcı hatasına karşı denetleyen **saf** yardımcı.
///
/// Amaç: "hata yapmayı engellemek". Kullanıcı bir değer girdiğinde sistem,
/// sonucun tutarlı olup olmadığını sessizce söyler. Hiçbir yan etkisi yoktur
/// (ağ / veritabanı / state kullanmaz), bu yüzden birim testle kolayca
/// doğrulanır ve ekrandan bağımsızdır.
///
/// Kapsam bilinçli olarak **kullanıcının gerçekten yapabileceği** hatalarla
/// sınırlıdır. Örneğin damga `matrah`ı ve 600 `kümülatif`i motor tarafından
/// türetildiği için (bkz. `beyanname_hesaplama_motoru.dart`) burada tekrar
/// denetlenmez; aksi halde ulaşılamayan "sahte" uyarılar üretilirdi.
class BeyannameDogrulama {
  BeyannameDogrulama._();

  /// Yuvarlama ve elle girişten doğan küçük farkları hata saymamak için
  /// kabul edilen en küçük mutlak sapma (TL).
  static const double _minTolerans = 0.5;

  /// Göreli tolerans (%0,5). Büyük matrahlarda yuvarlama payı tanır,
  /// buna karşın kaba oran hatalarını (örn. 100.000 matraha 20.000 KDV) yakalar.
  static const double _goreliTolerans = 0.005;

  /// Tüm giriş listelerini denetler ve bulunan uyarıları döner.
  ///
  /// [oncekiDonemdenDevredenKdv] yalnızca yönlendirici "bilgi" notu için
  /// kullanılır; hata üretmez.
  static List<BeyannameUyari> denetle({
    required List<Kdv1BirimSatiri> kdv1,
    required List<TevkifatFirmaKaydi> tevkifat,
    required List<MuhtasarSatiri> muhtasar,
    required List<Hasiat600BirimSatiri> hasiat600,
    double oncekiDonemdenDevredenKdv = 0.0,
    BeyannameKonfigurasyonu konfig = BeyannameKonfigurasyonu.varsayilan,
  }) {
    final uyarilar = <BeyannameUyari>[];

    _denetleKdv1(uyarilar, kdv1, konfig);
    _denetleKdv2(uyarilar, tevkifat);
    _denetleMuhtasar(uyarilar, muhtasar);
    _denetleHasiat600(uyarilar, hasiat600);
    _bilgiNotu(uyarilar, kdv1, oncekiDonemdenDevredenKdv);

    return uyarilar;
  }

  /// Bir seviyedeki uyarı sayısını döner (UI rozetleri için).
  static int sayi(List<BeyannameUyari> uyarilar, UyariSeviye seviye) =>
      uyarilar.where((u) => u.seviye == seviye).length;

  // ---------------------------------------------------------------- KDV 1 --
  static void _denetleKdv1(
    List<BeyannameUyari> out,
    List<Kdv1BirimSatiri> rows,
    BeyannameKonfigurasyonu konfig,
  ) {
    // Oranlar kurum yapılandırmasından gelir; tanımsızsa %10/%20'ye düşer.
    final oran10 = konfig.oranKesri(10);
    final oran20 = konfig.oranKesri(20);
    final et10 = konfig.kdvOranlari
        .firstWhere((o) => o.oran == 10,
            orElse: () => const KdvOranTanimi(oran: 10))
        .gorunenEtiket;
    final et20 = konfig.kdvOranlari
        .firstWhere((o) => o.oran == 20,
            orElse: () => const KdvOranTanimi(oran: 20))
        .gorunenEtiket;

    for (final s in rows) {
      final ad = _ad(s.birimAdi);
      _oranKontrol(out, ad, 'Hesaplanan $et10', s.hesaplananMatrah10,
          s.hesaplananKdv10, oran10);
      _oranKontrol(out, ad, 'Hesaplanan $et20', s.hesaplananMatrah20,
          s.hesaplananKdv20, oran20);
      _oranKontrol(out, ad, 'İndirilecek $et10', s.indirilecekMatrah10,
          s.indirilecekKdv10, oran10);
      _oranKontrol(out, ad, 'İndirilecek $et20', s.indirilecekMatrah20,
          s.indirilecekKdv20, oran20);
    }
  }

  /// Matrah ile KDV tutarının belirtilen orana uyup uymadığını denetler.
  static void _oranKontrol(
    List<BeyannameUyari> out,
    String birim,
    String alan,
    double matrah,
    double kdv,
    double oran,
  ) {
    if (matrah <= 0 && kdv <= 0) return;

    if (matrah > 0 && kdv <= 0) {
      out.add(BeyannameUyari(
        seviye: UyariSeviye.dikkat,
        baslik: '$birim • $alan',
        aciklama:
            'Matrah girilmiş ancak KDV tutarı boş. Beklenen KDV: ${_tl(BeyannameHesaplamaMotoru.round(matrah * oran))}',
      ));
      return;
    }
    if (matrah <= 0 && kdv > 0) {
      out.add(BeyannameUyari(
        seviye: UyariSeviye.dikkat,
        baslik: '$birim • $alan',
        aciklama: 'KDV tutarı girilmiş ancak matrah boş.',
      ));
      return;
    }

    final beklenen = BeyannameHesaplamaMotoru.round(matrah * oran);
    if ((kdv - beklenen).abs() > _tolerans(matrah)) {
      out.add(BeyannameUyari(
        seviye: UyariSeviye.hata,
        baslik: '$birim • $alan',
        aciklama:
            'Girilen KDV ${_tl(kdv)} ile matrahın oranı uyuşmuyor. Beklenen: ${_tl(beklenen)}',
      ));
    }
  }

  // ---------------------------------------------------------------- KDV 2 --
  static void _denetleKdv2(List<BeyannameUyari> out, List<TevkifatFirmaKaydi> rows) {
    for (final k in rows) {
      if (k.matrahTutari <= 0 && k.kdvTutari <= 0 && k.tevkifatTutari <= 0) continue;
      final ad = _ad(k.firmaAdi);

      // Tevkifat, KDV'nin bir parçasıdır; KDV'yi aşamaz.
      if (k.tevkifatTutari - k.kdvTutari > 0.01) {
        out.add(BeyannameUyari(
          seviye: UyariSeviye.hata,
          baslik: '$ad • Tevkifat',
          aciklama:
              'Tevkifat tutarı (${_tl(k.tevkifatTutari)}) KDV tutarını (${_tl(k.kdvTutari)}) aşamaz.',
        ));
      }

      // KDV tutarı, matrah × oran ile uyuşmalı.
      if (k.matrahTutari > 0) {
        final beklenenKdv = BeyannameHesaplamaMotoru.round(k.matrahTutari * k.kdvOrani / 100);
        if ((k.kdvTutari - beklenenKdv).abs() > _tolerans(k.matrahTutari)) {
          out.add(BeyannameUyari(
            seviye: UyariSeviye.hata,
            baslik: '$ad • KDV',
            aciklama:
                'Matraha göre KDV %${k.kdvOrani} olmalı: ${_tl(beklenenKdv)}. Girilen: ${_tl(k.kdvTutari)}',
          ));
        }
      }

      // Tevkifat tutarı, KDV tutarının tevkifat oranı kadarı olmalı.
      if (k.kdvTutari > 0) {
        final beklenenTevkifat =
            BeyannameHesaplamaMotoru.round(k.kdvTutari * k.tevkifatTuru.oran);
        if ((k.tevkifatTutari - beklenenTevkifat).abs() > _tolerans(k.kdvTutari)) {
          out.add(BeyannameUyari(
            seviye: UyariSeviye.dikkat,
            baslik: '$ad • Tevkifat',
            aciklama:
                '${k.tevkifatTuru.etiket} oranına göre tevkifat ${_tl(beklenenTevkifat)} olmalı. Girilen: ${_tl(k.tevkifatTutari)}',
          ));
        }
      }
    }
  }

  // ------------------------------------------------------------- Muhtasar --
  static void _denetleMuhtasar(List<BeyannameUyari> out, List<MuhtasarSatiri> rows) {
    for (final m in rows) {
      if (m.brutUcret <= 0 && m.gelirVergisi <= 0 && m.netOdenen <= 0) continue;
      final ad = _ad(m.adSoyad.trim().isEmpty ? m.birimAdi : m.adSoyad);

      if (m.brutUcret > 0 && m.gelirVergisi <= 0) {
        out.add(BeyannameUyari(
          seviye: UyariSeviye.dikkat,
          baslik: '$ad • Gelir Vergisi',
          aciklama: 'Brüt ücret girilmiş ancak gelir vergisi boş bırakılmış.',
        ));
      }
      if (m.brutUcret > 0 && m.netOdenen - m.brutUcret > 0.01) {
        out.add(BeyannameUyari(
          seviye: UyariSeviye.hata,
          baslik: '$ad • Net Ödenen',
          aciklama:
              'Net ödenen (${_tl(m.netOdenen)}) brüt ücretten (${_tl(m.brutUcret)}) büyük olamaz.',
        ));
      }
    }
  }

  // ----------------------------------------------------------- 600 Hasılat --
  static void _denetleHasiat600(
    List<BeyannameUyari> out,
    List<Hasiat600BirimSatiri> rows,
  ) {
    for (final h in rows) {
      if (h.oncekiAylarHasilat600 == 0 &&
          h.aylikHasilat600 == 0 &&
          h.kumulatifHasilat600 == 0) {
        continue;
      }
      final ad = _ad(h.birimAdi);

      if (h.oncekiAylarHasilat600 < 0 || h.aylikHasilat600 < 0) {
        out.add(BeyannameUyari(
          seviye: UyariSeviye.hata,
          baslik: '$ad • 600 Hasılat',
          aciklama: 'Hasılat tutarları negatif olamaz.',
        ));
      }
      if (h.kumulatifHasilat600 + 0.01 < h.aylikHasilat600) {
        out.add(BeyannameUyari(
          seviye: UyariSeviye.hata,
          baslik: '$ad • 600 Kümülatif',
          aciklama:
              'Kümülatif hasılat (${_tl(h.kumulatifHasilat600)}) aylık hasılattan (${_tl(h.aylikHasilat600)}) küçük olamaz.',
        ));
      }
    }
  }

  // ------------------------------------------------------------ Bilgi notu --
  /// Hata değil; kullanıcıya dönemin sonucunu önceden haber verir.
  static void _bilgiNotu(
    List<BeyannameUyari> out,
    List<Kdv1BirimSatiri> kdv1,
    double oncekiDonemdenDevredenKdv,
  ) {
    final sonuc = BeyannameHesaplamaMotoru.hesaplaKdv1(
      kdv1,
      oncekiDonemdenDevredenKdv: oncekiDonemdenDevredenKdv,
    );
    if (sonuc.sonrakiDonemeDevredenKdv > 0) {
      out.add(BeyannameUyari(
        seviye: UyariSeviye.bilgi,
        baslik: 'Devreden KDV',
        aciklama:
            'Bu dönem ödenecek KDV yok; ${_tl(sonuc.sonrakiDonemeDevredenKdv)} sonraki döneme devrediyor.',
      ));
    }
  }

  // -------------------------------------------------------------- Yardımcı --
  static double _tolerans(double taban) {
    final rel = taban * _goreliTolerans;
    return rel > _minTolerans ? rel : _minTolerans;
  }

  static String _ad(String? deger) {
    final t = (deger ?? '').trim();
    return t.isEmpty ? 'Tanımsız birim' : t;
  }

  static String _tl(double v) => TurkceFormat.para(v);
}
