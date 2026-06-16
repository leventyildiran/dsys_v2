import '../models/dagitim_model.dart';
import '../models/danismanlik_model.dart';

class DanismanlikHesaplamaServisi {
  /// Memur maaş katsayısı (Şimdilik sabit, normalde veritabanından çekilebilir)
  static const double memurMaasKatsayisi = 1.387871;

  /// Unvanlara göre Ek Gösterge haritası
  static final Map<String, int> ekGostergeler = {
    'Profesör': 300,
    'Doçent': 250,
    'Dr.Öğr.Üyesi': 200,
    'Öğr.Gör.Dr.': 160,
    'Öğr.Gör.': 160,
    'Arş.Gör.Dr.': 160,
    'Arş.Gör.': 160,
  };

  /// Unvanlara göre Unvan Katsayısı haritası
  static final Map<String, double> unvanKatsayilari = {
    'Profesör': 3.0,
    'Doçent': 2.5,
    'Dr.Öğr.Üyesi': 2.2,
    'Öğr.Gör.Dr.': 2.0,
    'Öğr.Gör.': 2.0,
    'Arş.Gör.Dr.': 2.0,
    'Arş.Gör.': 2.0,
  };

  /// Unvandan Ek Gösterge getirir
  static int getEkGosterge(String unvan) {
    return ekGostergeler[unvan] ?? 160;
  }

  /// Unvandan Unvan Katsayısı getirir
  static double getUnvanKatsayisi(String unvan) {
    return unvanKatsayilari[unvan] ?? 1.0;
  }

  /// KDV hariç toplam tutardan (matrah), kesintileri düşerek
  /// dağıtılacak maksimum akademik payı (%49) hesaplar.
  static double hesaplaDagitilacakMaksimumPay(double kdvHaricTutar) {
    return kdvHaricTutar * 0.49;
  }

  /// 1 Saatlik Tavan (Limit) Ek Ders Ücretini hesaplar
  static double hesaplaSaatlikTavanUcret(int ekGosterge, bool mesaiIci) {
    double bazUcret = ekGosterge * memurMaasKatsayisi;
    if (mesaiIci) {
      // Mesai içi %200
      return bazUcret * 2.0;
    } else {
      // Mesai dışı %320 (%60 artırımlı)
      return bazUcret * 3.2;
    }
  }

  /// Tablodaki personellerin hakedişlerini hesaplar ve güncel listeyi döndürür.
  static List<DagitimModel> hesaplaDagitimListesi(
    List<DagitimModel> personeller,
    double kdvHaricTutar,
  ) {
    if (personeller.isEmpty) return [];

    // 1. Dağıtılacak Maksimum Akademik Pay
    double maksPay = hesaplaDagitilacakMaksimumPay(kdvHaricTutar);

    // 2. Herkesin bireysel puanlarını güncelle ve Toplam Puanı bul
    double genelToplamPuan = 0.0;
    List<DagitimModel> guncelPersoneller = [];

    for (var p in personeller) {
      // Faaliyet Taban Puanı x Faaliyet Adeti = Toplam Puan
      double toplamPuan = p.faaliyetTabanPuani * p.faaliyetAdeti;
      // Toplam Puan x Unvan Katsayısı = Bireysel Puan
      double bireyselPuan = toplamPuan * p.unvanKatsayisi;
      genelToplamPuan += bireyselPuan;

      guncelPersoneller.add(
        DagitimModel(
          personelId: p.personelId,
          adSoyad: p.adSoyad,
          unvan: p.unvan,
          unvanKatsayisi: p.unvanKatsayisi,
          ekGosterge: p.ekGosterge,
          faaliyetTuru: p.faaliyetTuru,
          faaliyetAdeti: p.faaliyetAdeti,
          faaliyetTabanPuani: p.faaliyetTabanPuani,
          mesaiIci: p.mesaiIci,
          toplamPuan: toplamPuan,
          bireyselPuan: bireyselPuan,
          brutHakedis: 0, // Aşağıda hesaplanacak
        ),
      );
    }

    if (genelToplamPuan == 0) return guncelPersoneller;

    // 3. Dönem Ek Ödeme Katsayısı (Para / Puan)
    // Excel kuralı: Sağlama yaparken sonuç maks payı aşarsa aşağı yuvarlanır.
    double donemKatsayisi = maksPay / genelToplamPuan;

    // Sağlama kontrolü
    if ((donemKatsayisi * genelToplamPuan) > maksPay) {
      // Küsüratları tıraşla
      donemKatsayisi = (donemKatsayisi * 100).floorToDouble() / 100.0;
    }

    // 4. Brüt Hakedişleri hesapla ve Tavan kontrolü yap
    List<DagitimModel> sonListe = [];
    for (var p in guncelPersoneller) {
      double brutHakedis = p.bireyselPuan * donemKatsayisi;
      double saatlikBrutUcret = p.faaliyetAdeti > 0
          ? (brutHakedis / p.faaliyetAdeti)
          : 0.0;

      // Tavan Limit Kontrolü
      double tavanSaatlik = hesaplaSaatlikTavanUcret(p.ekGosterge, p.mesaiIci);
      double odenebilirHakedis = brutHakedis;
      double fazlalikHavuzTutari = 0.0;
      bool tavanKontrol = false;

      if (saatlikBrutUcret > tavanSaatlik) {
        tavanKontrol = true;
        odenebilirHakedis = tavanSaatlik * p.faaliyetAdeti;
        fazlalikHavuzTutari = brutHakedis - odenebilirHakedis;
      }

      sonListe.add(
        DagitimModel(
          personelId: p.personelId,
          adSoyad: p.adSoyad,
          unvan: p.unvan,
          unvanKatsayisi: p.unvanKatsayisi,
          ekGosterge: p.ekGosterge,
          faaliyetTuru: p.faaliyetTuru,
          faaliyetAdeti: p.faaliyetAdeti,
          faaliyetTabanPuani: p.faaliyetTabanPuani,
          mesaiIci: p.mesaiIci,
          toplamPuan: p.toplamPuan,
          bireyselPuan: p.bireyselPuan,
          brutHakedis: brutHakedis,
          tavanKontrol: tavanKontrol,
          tavanLimitTutari: tavanSaatlik * p.faaliyetAdeti,
          odenebilirHakedis: odenebilirHakedis,
          fazlalikHavuzTutari: fazlalikHavuzTutari,
        ),
      );
    }

    return sonListe;
  }
}
