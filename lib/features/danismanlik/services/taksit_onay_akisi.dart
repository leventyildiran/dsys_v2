import '../models/danismanlik_model.dart';
import '../models/taksit_model.dart';

/// Taksit (Aylık Ödeme Havuzu) iş akışı durum geçişleri ve aksiyon etiketlerini yöneten strateji motoru.
abstract class IsAkisiMotoru {
  factory IsAkisiMotoru.forTur(DanismanlikTuru tur) {
    if (tur == DanismanlikTuru.egitimKuru) {
      return EgitimKurAkisi();
    }
    return StandartDanismanlikAkisi();
  }

  List<TaksitDurum> get onayHatti;
  TaksitDurum? sonrakiDurum(TaksitDurum mevcut);
  TaksitDurum? oncekiDurum(TaksitDurum mevcut);
  bool gecisUygunMu(TaksitDurum mevcut, TaksitDurum hedef);
  String ilerletEtiketi(TaksitDurum mevcut);
  int adimIndeksi(TaksitDurum durum);
}

class StandartDanismanlikAkisi implements IsAkisiMotoru {
  @override
  final List<TaksitDurum> onayHatti = const [
    TaksitDurum.taslak,
    TaksitDurum.faturaKesildi,
    TaksitDurum.paraGeldi,
    TaksitDurum.dagitimHesaplandi,
    TaksitDurum.ykOnaylandi,
    TaksitDurum.odendi,
  ];

  @override
  TaksitDurum? sonrakiDurum(TaksitDurum mevcut) {
    switch (mevcut) {
      case TaksitDurum.taslak:
        return TaksitDurum.faturaKesildi;
      case TaksitDurum.faturaKesildi:
        return TaksitDurum.paraGeldi;
      case TaksitDurum.paraGeldi:
        return TaksitDurum.dagitimHesaplandi;
      case TaksitDurum.dagitimHesaplandi:
        return TaksitDurum.ykOnaylandi;
      case TaksitDurum.ykOnaylandi:
        return TaksitDurum.odendi;
      case TaksitDurum.gecikti:
        return TaksitDurum.odendi;
      case TaksitDurum.odendi:
        return null;
    }
  }

  @override
  TaksitDurum? oncekiDurum(TaksitDurum mevcut) {
    switch (mevcut) {
      case TaksitDurum.faturaKesildi:
        return TaksitDurum.taslak;
      case TaksitDurum.paraGeldi:
        return TaksitDurum.faturaKesildi;
      case TaksitDurum.dagitimHesaplandi:
        return TaksitDurum.paraGeldi;
      case TaksitDurum.ykOnaylandi:
        return TaksitDurum.dagitimHesaplandi;
      case TaksitDurum.odendi:
        return TaksitDurum.ykOnaylandi;
      default:
        return null;
    }
  }

  @override
  bool gecisUygunMu(TaksitDurum mevcut, TaksitDurum hedef) {
    if (mevcut == hedef) return false;
    if (hedef == TaksitDurum.odendi) {
      return mevcut == TaksitDurum.ykOnaylandi || mevcut == TaksitDurum.gecikti;
    }
    return sonrakiDurum(mevcut) == hedef || oncekiDurum(mevcut) == hedef;
  }

  @override
  String ilerletEtiketi(TaksitDurum mevcut) {
    switch (mevcut) {
      case TaksitDurum.taslak:
        return 'Fatura Kesildi';
      case TaksitDurum.faturaKesildi:
        return 'Para Geldi / Dekont Ekle';
      case TaksitDurum.paraGeldi:
        return 'Dağıtım Hesapla';
      case TaksitDurum.dagitimHesaplandi:
        return 'YKK Onaylandı İşaretle';
      case TaksitDurum.ykOnaylandi:
        return 'Ödemeleri Gerçekleştir';
      case TaksitDurum.gecikti:
        return 'Ödendi İşaretle';
      case TaksitDurum.odendi:
        return '';
    }
  }

  @override
  int adimIndeksi(TaksitDurum durum) {
    if (durum == TaksitDurum.gecikti) {
      return onayHatti.indexOf(TaksitDurum.dagitimHesaplandi);
    }
    final i = onayHatti.indexOf(durum);
    return i < 0 ? 0 : i;
  }
}

class EgitimKurAkisi implements IsAkisiMotoru {
  @override
  final List<TaksitDurum> onayHatti = const [
    TaksitDurum.taslak,
    TaksitDurum.faturaKesildi, // Egitim'de "Dekont/Tahsilat Alındı"
    TaksitDurum.paraGeldi,     // Egitim'de "Bütçe Toplandı"
    TaksitDurum.dagitimHesaplandi,
    TaksitDurum.ykOnaylandi,
    TaksitDurum.odendi,
  ];

  @override
  TaksitDurum? sonrakiDurum(TaksitDurum mevcut) {
    switch (mevcut) {
      case TaksitDurum.taslak:
        return TaksitDurum.faturaKesildi;
      case TaksitDurum.faturaKesildi:
        return TaksitDurum.paraGeldi;
      case TaksitDurum.paraGeldi:
        return TaksitDurum.dagitimHesaplandi;
      case TaksitDurum.dagitimHesaplandi:
        return TaksitDurum.ykOnaylandi;
      case TaksitDurum.ykOnaylandi:
        return TaksitDurum.odendi;
      case TaksitDurum.gecikti:
        return TaksitDurum.odendi;
      case TaksitDurum.odendi:
        return null;
    }
  }

  @override
  TaksitDurum? oncekiDurum(TaksitDurum mevcut) {
    switch (mevcut) {
      case TaksitDurum.faturaKesildi:
        return TaksitDurum.taslak;
      case TaksitDurum.paraGeldi:
        return TaksitDurum.faturaKesildi;
      case TaksitDurum.dagitimHesaplandi:
        return TaksitDurum.paraGeldi;
      case TaksitDurum.ykOnaylandi:
        return TaksitDurum.dagitimHesaplandi;
      case TaksitDurum.odendi:
        return TaksitDurum.ykOnaylandi;
      default:
        return null;
    }
  }

  @override
  bool gecisUygunMu(TaksitDurum mevcut, TaksitDurum hedef) {
    if (mevcut == hedef) return false;
    if (hedef == TaksitDurum.odendi) {
      return mevcut == TaksitDurum.ykOnaylandi || mevcut == TaksitDurum.gecikti;
    }
    return sonrakiDurum(mevcut) == hedef || oncekiDurum(mevcut) == hedef;
  }

  @override
  String ilerletEtiketi(TaksitDurum mevcut) {
    switch (mevcut) {
      case TaksitDurum.taslak:
        return 'Tahsilat Alındı / Dekont Ekle';
      case TaksitDurum.faturaKesildi:
        return 'Bütçeyi Topla';
      case TaksitDurum.paraGeldi:
        return 'Dağıtımı Hesapla';
      case TaksitDurum.dagitimHesaplandi:
        return 'YKK Onaylandı İşaretle';
      case TaksitDurum.ykOnaylandi:
        return 'Ödemeleri Gerçekleştir';
      case TaksitDurum.gecikti:
        return 'Ödendi İşaretle';
      case TaksitDurum.odendi:
        return '';
    }
  }

  @override
  int adimIndeksi(TaksitDurum durum) {
    if (durum == TaksitDurum.gecikti) {
      return onayHatti.indexOf(TaksitDurum.dagitimHesaplandi);
    }
    final i = onayHatti.indexOf(durum);
    return i < 0 ? 0 : i;
  }
}
