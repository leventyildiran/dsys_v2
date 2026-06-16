import '../models/taksit_model.dart';

/// Taksit onay hattı durum geçişleri ve aksiyon etiketleri.
class TaksitOnayAkisi {
  TaksitOnayAkisi._();

  static const onayHatti = [
    TaksitDurum.taslak,
    TaksitDurum.mudurOnayinda,
    TaksitDurum.merkezOnayinda,
    TaksitDurum.ykGundeminde,
    TaksitDurum.onaylandi,
    TaksitDurum.odendi,
  ];

  static TaksitDurum? sonrakiDurum(TaksitDurum mevcut) {
    switch (mevcut) {
      case TaksitDurum.taslak:
        return TaksitDurum.mudurOnayinda;
      case TaksitDurum.mudurOnayinda:
        return TaksitDurum.merkezOnayinda;
      case TaksitDurum.merkezOnayinda:
        return TaksitDurum.ykGundeminde;
      case TaksitDurum.ykGundeminde:
        return TaksitDurum.onaylandi;
      case TaksitDurum.onaylandi:
        return TaksitDurum.odendi;
      case TaksitDurum.gecikti:
        return TaksitDurum.odendi;
      case TaksitDurum.odendi:
        return null;
    }
  }

  static TaksitDurum? oncekiDurum(TaksitDurum mevcut) {
    switch (mevcut) {
      case TaksitDurum.mudurOnayinda:
        return TaksitDurum.taslak;
      case TaksitDurum.merkezOnayinda:
        return TaksitDurum.mudurOnayinda;
      case TaksitDurum.ykGundeminde:
        return TaksitDurum.merkezOnayinda;
      case TaksitDurum.onaylandi:
        return TaksitDurum.ykGundeminde;
      default:
        return null;
    }
  }

  static bool gecisUygunMu(TaksitDurum mevcut, TaksitDurum hedef) {
    if (mevcut == hedef) return false;
    if (hedef == TaksitDurum.odendi) {
      return mevcut == TaksitDurum.onaylandi || mevcut == TaksitDurum.gecikti;
    }
    return sonrakiDurum(mevcut) == hedef || oncekiDurum(mevcut) == hedef;
  }

  static String ilerletEtiketi(TaksitDurum mevcut) {
    switch (mevcut) {
      case TaksitDurum.taslak:
        return 'Müdür Onayına Sun';
      case TaksitDurum.mudurOnayinda:
        return 'Merkeze Gönder';
      case TaksitDurum.merkezOnayinda:
        return 'YK Gündemine Al';
      case TaksitDurum.ykGundeminde:
        return 'Onayla & Dağıt';
      case TaksitDurum.onaylandi:
        return 'Ödendi İşaretle';
      case TaksitDurum.gecikti:
        return 'Ödendi İşaretle';
      case TaksitDurum.odendi:
        return '';
    }
  }

  static int adimIndeksi(TaksitDurum durum) {
    if (durum == TaksitDurum.gecikti)
      return onayHatti.indexOf(TaksitDurum.ykGundeminde);
    final i = onayHatti.indexOf(durum);
    return i < 0 ? 0 : i;
  }
}
