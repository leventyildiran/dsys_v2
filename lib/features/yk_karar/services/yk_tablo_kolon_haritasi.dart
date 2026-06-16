import '../models/yk_karar_model.dart';

/// Karar türüne göre tablo kolon eşleştirme sözlüğü.
/// PDF/şablon başlıkları bu anahtar kelimelerle eşleştirilir — tahmin yok.
class YkTabloKolonHaritasi {
  static const Map<YkKararTuru, List<List<String>>> _turBasliklari = {
    YkKararTuru.butceAktarim: [
      ['kaynak', 'kaynak kod', 'aktarılan'],
      ['hedef', 'hedef kod', 'aktarım yapılan'],
      ['tutar', 'miktar', 'ödenek', 'tl', '₺'],
      ['açıklama', 'aciklama', 'gerekçe'],
    ],
    YkKararTuru.danismanlik: [
      ['adı soyadı', 'adi soyadi', 'unvan', 'danışman'],
      ['faaliyet', 'hizmet', 'tür'],
      ['adet', 'saat', 'gün', 'miktar'],
      ['tutar', 'hakediş', 'ücret', 'tl'],
    ],
    YkKararTuru.kursUcreti: [
      ['adı soyadı', 'adi soyadi', 'personel'],
      ['puan', 'puanı'],
      ['katsayı', 'katsayi'],
      ['brüt', 'brut', 'hakediş', 'tutar'],
    ],
    YkKararTuru.disHekimligi: [
      ['adı soyadı', 'adi soyadi', 'hekim'],
      ['puan'],
      ['katsayı', 'katsayi'],
      ['brüt', 'brut', 'ek ödeme', 'tutar'],
    ],
    YkKararTuru.fiyatTarifesi: [
      ['hizmet', 'kalem', 'açıklama'],
      ['birim', 'adet'],
      ['fiyat', 'tarife', 'tutar', 'tl'],
    ],
  };

  /// Şablon başlık hücresini PDF satır anahtarına eşler; eşleşmezse null.
  static String? kolonAnahtariBul({
    required YkKararTuru tur,
    required String sablonBaslik,
    required List<String> pdfAnahtarlari,
    required int kolonIndex,
  }) {
    final baslik = _normalize(sablonBaslik);
    if (baslik.isEmpty) {
      return kolonIndex < pdfAnahtarlari.length ? pdfAnahtarlari[kolonIndex] : null;
    }

    // 1) Tür sözlüğünden eşleştir
    final sozluk = _turBasliklari[tur];
    if (sozluk != null && kolonIndex < sozluk.length) {
      for (final alias in sozluk[kolonIndex]) {
        if (baslik.contains(alias)) {
          return _pdfAnahtariBul(pdfAnahtarlari, alias) ??
              (kolonIndex < pdfAnahtarlari.length ? pdfAnahtarlari[kolonIndex] : null);
        }
      }
    }

    // 2) Doğrudan başlık ↔ PDF anahtar benzerliği
    for (final key in pdfAnahtarlari) {
      final nk = _normalize(key);
      if (baslik == nk || baslik.contains(nk) || nk.contains(baslik)) return key;
    }

    // 3) Pozisyon (son çare — kurumsal modda loglanır)
    return kolonIndex < pdfAnahtarlari.length ? pdfAnahtarlari[kolonIndex] : null;
  }

  static String? _pdfAnahtariBul(List<String> keys, String alias) {
    for (final k in keys) {
      if (_normalize(k).contains(alias)) return k;
    }
    return null;
  }

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9ğüşıöçâîû ]'), '').trim();
}

class TabloDoldurmaSonucu {
  const TabloDoldurmaSonucu({
    required this.bodyXml,
    required this.doldurulanHucre,
    required this.atlananHucre,
    required this.eslesmeyenSatir,
    this.uyarilar = const [],
  });

  final String bodyXml;
  final int doldurulanHucre;
  final int atlananHucre;
  final int eslesmeyenSatir;
  final List<String> uyarilar;

  bool get basarili => uyarilar.isEmpty && eslesmeyenSatir == 0;
}
