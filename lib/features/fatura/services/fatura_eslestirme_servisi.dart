import '../models/fatura_model.dart';
import 'fatura_offline_parser.dart';

class FaturaEslestirmeServisi {
  static const int _minEslesmeSkoru = 30;

  /// Ham metni geçmiş faturalarla kıyaslar. Eşleşme skoru yüksekse,
  /// geçmiş faturayı klonlayıp sadece değişken (Tutar/Tarih/İrsaliye) 
  /// verilerini Regex üzerinden günceller.
  static FaturaModel? eslestir({
    required String rawText,
    required List<FaturaModel> gecmisFaturalar,
  }) {
    if (gecmisFaturalar.isEmpty || rawText.trim().isEmpty) return null;
    
    final lowerText = rawText.toLowerCase();
    
    // Aynı puana sahip olanları ayırmak için tarihi en yeni olanı seçeceğiz.
    // O yüzden gecmisFaturaları tarihe göre (yeni -> eski) sıralayalım.
    final siraliGecmis = List<FaturaModel>.from(gecmisFaturalar)..sort((a, b) {
      return (b.tarih).compareTo(a.tarih); 
    });

    FaturaModel? enIyiFatura;
    int maxSkor = 0;

    final sabikaliKelimeler = ['a.ş', 'a.ş.', 'ltd', 'ltd.', 'şti', 'şti.', 'san', 'san.', 'tic', 'tic.', 've', 'şirketi', 'sanayi', 'ticaret'];

    for (final gecmis in siraliGecmis) {
      int skor = 0;

      // 1. Vergi / TC No eşleşmesi (Çok Güçlü - sadece geçerli uzunluktaysa)
      final vNo = gecmis.vergiNo.trim().toLowerCase();
      if (vNo.length >= 10 && lowerText.contains(vNo)) {
        skor += 50;
      }

      // 2. Firma Adı Eşleşmesi (Güçlü)
      final fAdi = gecmis.firmaAdi.trim().toLowerCase();
      if (fAdi.isNotEmpty && fAdi.length > 3) {
        if (lowerText.contains(fAdi)) {
          skor += 30;
        } else {
          // Kısmi eşleşme (Şirket türü kelimelerini filtrele)
          final kelimeler = fAdi.split(' ').where((k) {
            final temiz = k.replaceAll(RegExp(r'[^\w\s]'), '');
            return temiz.length > 3 && !sabikaliKelimeler.contains(temiz);
          }).toList();
          
          int eslesenKelime = 0;
          for (final k in kelimeler) {
            if (lowerText.contains(k)) eslesenKelime++;
          }
          
          if (kelimeler.isNotEmpty && eslesenKelime == kelimeler.length) {
            skor += 25; // Anlamlı tüm kelimeler eşleşti
          } else if (kelimeler.isNotEmpty && eslesenKelime > 0) {
            skor += (15 * (eslesenKelime / kelimeler.length)).toInt();
          }
        }
      }

      // 3. Birim / Kategori Eşleşmesi (Aynı firmaya kesilen farklı birim faturalarını ayırmak için)
      final birim = gecmis.tahminiBirim?.toLowerCase() ?? '';
      if (birim.isNotEmpty) {
        if (lowerText.contains(birim)) {
          skor += 15;
        }
        // Birime özgü anahtar kelime destekleri
        if (birim.contains('tömer') && lowerText.contains('kurs')) skor += 10;
        if (birim.contains('ubatam') && lowerText.contains('analiz')) skor += 10;
        if (birim.contains('tarımsal') && (lowerText.contains('süt') || lowerText.contains('yumurta'))) skor += 10;
      }

      // 4. IBAN Eşleşmesi
      final iban = gecmis.iban?.replaceAll(' ', '').toLowerCase() ?? '';
      if (iban.length > 15 && lowerText.replaceAll(' ', '').contains(iban)) {
        skor += 20;
      }

      // Sıralı olduğu için eşitlik durumunda ilk bulduğu (en yeni tarihli) kalır.
      if (skor > maxSkor) {
        maxSkor = skor;
        enIyiFatura = gecmis;
      }
    }

    if (maxSkor >= _minEslesmeSkoru && enIyiFatura != null) {
      return _faturayiKlonlaVeGuncelle(enIyiFatura, rawText);
    }

    return null; // Eşleşme yok veya skor yetersiz
  }

  /// Geçmiş faturanın sabit bilgilerini (Müşteri, KDV durumu, Birim vs.) kopyalar,
  /// dinamik verileri (Miktar, Tarih, No vb.) OfflineParser kullanarak yeni metinden çıkarır.
  static FaturaModel _faturayiKlonlaVeGuncelle(FaturaModel sablon, String rawText) {
    // 1. Yeni metinden tarih, tutar ve olası kalemleri Regex/OfflineParser ile bul
    final parserSonuclari = FaturaOfflineParser.parse(rawText);
    FaturaModel? parsedFatura;
    if (parserSonuclari.isNotEmpty) {
      parsedFatura = parserSonuclari.first;
    }

    // 2. Kalemleri ayarla: OfflineParser bulduysa onu kullan, yoksa boş kalem bırak
    List<Map<String, dynamic>> yeniKalemler = [];
    if (parsedFatura != null && parsedFatura.kalemler.isNotEmpty) {
      yeniKalemler = parsedFatura.kalemler;
    } else {
      // Eğer parser bulamadıysa, sablondaki kalemlerin miktarını 1, fiyatını 0 yapıp başlıklarını koruyalım
      yeniKalemler = sablon.kalemler.map((k) {
        return {
          'cinsi': k['cinsi'] ?? 'Kalem',
          'miktar': 1,
          'fiyat': 0.0,
        };
      }).toList();
      if (yeniKalemler.isEmpty) {
        yeniKalemler.add({'cinsi': 'Yeni Kalem', 'miktar': 1, 'fiyat': 0.0});
      }
    }

    // 3. Modeli klonla
    return FaturaModel(
      id: '', // Yeni id
      firmaAdi: sablon.firmaAdi,
      adres: sablon.adres,
      vergiDairesi: sablon.vergiDairesi,
      vergiNo: sablon.vergiNo,
      tarih: parsedFatura?.tarih ?? sablon.tarih, // Yeni tarih
      irsaliyeNo: parsedFatura?.irsaliyeNo ?? '', // Yeni metinden
      melbesNo: parsedFatura?.melbesNo ?? '', // Yeni metinden
      melbesKurumOnEki: parsedFatura?.melbesKurumOnEki ?? '',
      numuneNo: parsedFatura?.numuneNo ?? '', // Yeni metinden
      numuneAciklamasi: parsedFatura?.numuneAciklamasi ?? '',
      iban: sablon.iban,
      hesapAdi: sablon.hesapAdi,
      kdvOrani: sablon.kdvOrani,
      kdvTutari: parsedFatura?.kdvTutari ?? 0.0,
      matrah: parsedFatura?.matrah ?? 0.0,
      genelToplam: parsedFatura?.genelToplam ?? 0.0,
      isKdvMuaf: sablon.isKdvMuaf, // Eski muafiyet aynen kalır
      parsedBy: 'Tier 1 - Akıllı Eşleştirme',
      kalemler: yeniKalemler,
      hizmetTipi: sablon.hizmetTipi,
      kurNo: sablon.kurNo, // Belki değişebilir ama varsayılan kalsın
      odemeTipi: sablon.odemeTipi,
      ytbOgrencisi: sablon.ytbOgrencisi,
      urunTuru: sablon.urunTuru,
      tedarikYontemi: sablon.tedarikYontemi,
      donem: sablon.donem,
      aciklama: sablon.aciklama,
      tahminiBirim: sablon.tahminiBirim, // Hangi birime aitti?
    );
  }
}
