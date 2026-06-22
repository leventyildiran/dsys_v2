import '../../../core/turkce_format.dart';
import 'fatura_matbu_config.dart';
import 'fatura_model.dart';

/// Tek kalem satırı — PDF baskısıyla aynı biçimde.
class KalibrasyonKalemSatir {
  const KalibrasyonKalemSatir({
    required this.cinsi,
    required this.miktar,
    required this.fiyat,
    required this.tutar,
  });

  final String cinsi;
  final String miktar;
  final String fiyat;
  final String tutar;
}

/// Kalibrasyon tuvali: PDF ile birebir metin + çok satırlı kalemler.
class KalibrasyonBaskiOnizleme {
  const KalibrasyonBaskiOnizleme({
    required this.alanlar,
    required this.kalemler,
    required this.canliVeri,
    required this.baslik,
  });

  final Map<String, String> alanlar;
  final List<KalibrasyonKalemSatir> kalemler;
  final bool canliVeri;
  final String baslik;

  static const kalemAlanlari = {'cinsi', 'miktar', 'fiyat', 'tutar'};

  factory KalibrasyonBaskiOnizleme.fromFatura(
    FaturaModel invoice, {
    String? isletmeVkn,
    String? sistemHesapAdi,
    String? sistemIban,
    String Function(double)? yaziyla,
    bool canliVeri = true,
    String baslik = '',
    int sayfaNo = 1,
  }) {
    List<Map<String, dynamic>> kalemlerHam;
    if (!canliVeri) {
      kalemlerHam = FaturaMatbuConfig.matbuKalemleri(invoice.kalemler);
    } else {
      kalemlerHam = (invoice.kalemler.isNotEmpty)
          ? invoice.kalemler
          : <Map<String, dynamic>>[
              {
                'cinsi': invoice.numuneAciklamasi.trim().isNotEmpty
                    ? invoice.numuneAciklamasi
                    : 'Hizmet Bedeli',
                'miktar': 1,
                'fiyat': invoice.matrah,
              },
            ];
    }


    final satirLimit = (invoice.id == 'ornek') ? 10 : 8;
    
    final List<List<Map<String, dynamic>>> pages = [];
    final List<double> pageTotals = []; // Her sayfanın sonundaki gerçek toplam
    int currentItemIndex = 0;
    double runningTotal = 0.0;

    while (currentItemIndex < kalemlerHam.length || pages.isEmpty) {
      int spaceLeft = satirLimit;
      final List<Map<String, dynamic>> currentPageItems = [];
      
      if (pages.isNotEmpty && invoice.nakliYekunAktif) {
        currentPageItems.add({
          'cinsi': 'N A K L İ Y E K Ü N',
          'isNakliYekun': true,
          'nakliTutar': runningTotal,
        });
        spaceLeft--;
      }

      int itemsRemaining = kalemlerHam.length - currentItemIndex;
      bool willHaveNextPage = false;
      if (invoice.nakliYekunAktif && itemsRemaining > spaceLeft) {
          willHaveNextPage = true;
      }
      
      int effectiveSpace = willHaveNextPage ? spaceLeft - 1 : spaceLeft;

      double pageRealTotal = 0.0;
      while (effectiveSpace > 0 && currentItemIndex < kalemlerHam.length) {
        final item = kalemlerHam[currentItemIndex];
        currentPageItems.add(item);
        
        final fiyat = double.tryParse(item['fiyat'].toString()) ?? 0.0;
        final miktar = double.tryParse(item['miktar'].toString()) ?? 1.0;
        pageRealTotal += (fiyat * miktar);
        
        currentItemIndex++;
        effectiveSpace--;
        spaceLeft--;
      }
      
      runningTotal += pageRealTotal;
      
      if (willHaveNextPage) {
        currentPageItems.add({
          'cinsi': 'N A K L İ Y E K Ü N',
          'isNakliYekun': true,
          'nakliTutar': runningTotal,
        });
        spaceLeft--;
      }

      pages.add(currentPageItems);
      pageTotals.add(runningTotal);
    }

    final toplamSayfa = pages.length;
    final startIndex = (sayfaNo - 1).clamp(0, pages.length - 1);
    final aktifKalemlerHam = pages[startIndex];
    
    final kalemler = aktifKalemlerHam.map((item) {
      if (item['isNakliYekun'] == true) {
        return KalibrasyonKalemSatir(
          cinsi: item['cinsi'].toString(),
          miktar: '',
          fiyat: '',
          tutar: TurkceFormat.para(item['nakliTutar']),
        );
      }
      
      final fiyat = double.tryParse(item['fiyat'].toString()) ?? 0.0;
      final miktar = double.tryParse(item['miktar'].toString()) ?? 1.0;
      final miktarMetin = miktar == miktar.roundToDouble() ? miktar.toInt().toString() : TurkceFormat.ondalik(miktar);
      return KalibrasyonKalemSatir(
        cinsi: '${item['cinsi']}',
        miktar: miktarMetin,
        fiyat: TurkceFormat.para(fiyat),
        tutar: TurkceFormat.para(fiyat * miktar),
      );
    }).toList();
    
    final araToplam = pageTotals[startIndex];

    final numuneAciklamaAlt = invoice.numuneAciklamasi.trim();
    final numuneMelbesSatir = numuneAciklamaAlt.toLowerCase().contains('melbes') &&
        numuneAciklamaAlt.toLowerCase().contains('numune');
    final ustAciklamalar = [
      if (numuneAciklamaAlt.isNotEmpty && !numuneMelbesSatir) numuneAciklamaAlt,
      if (invoice.aciklama != null && invoice.aciklama!.trim().isNotEmpty)
        invoice.aciklama!.trim(),
      if (invoice.isKdvMuaf) "KDV'den Muaftır (İstisna)",
    ].join(' | ');

    final melbesYazi = FaturaMatbuConfig.formatMelbesMatbu(
      invoice.melbesNo,
      kurumOnEki: invoice.melbesKurumOnEki.trim().isNotEmpty ? invoice.melbesKurumOnEki : null,
    );
    final numuneYazi = FaturaMatbuConfig.formatNumuneNoMatbu(invoice.numuneNo);

    final hesapHam = (invoice.hesapAdi?.trim().isNotEmpty == true)
        ? invoice.hesapAdi!
        : (sistemHesapAdi ?? '');
    final hesapAdi = FaturaMatbuConfig.formatHesapAdiMatbu(
      hesapHam,
      fallbackVkn: isletmeVkn,
    );

    final iban = (invoice.iban?.trim().isNotEmpty == true)
        ? invoice.iban!
        : (sistemIban ?? '');

    final ilkSayfa = sayfaNo == 1;
    final sonSayfa = sayfaNo >= toplamSayfa;

    return KalibrasyonBaskiOnizleme(
      canliVeri: canliVeri,
      baslik: baslik,
      kalemler: kalemler,
      alanlar: {
        'firmaAdi': invoice.firmaAdi,
        'adres': invoice.adres,
        'vergiDairesi': invoice.vergiDairesi,
        'vkn': invoice.vergiNo,
        'tarih': invoice.tarih,
        'irsaliyeTarihi': invoice.irsaliyeTarihi,
        'irsaliyeNo': invoice.irsaliyeNo,
        'numuneAciklama': ustAciklamalar,
        'melbes': melbesYazi.isNotEmpty
            ? melbesYazi
            : invoice.melbesKurumOnEki.trim(),
        'numuneNo': numuneYazi,
        'matrah': (!canliVeri || sonSayfa) ? TurkceFormat.para(invoice.matrah) : (invoice.nakliYekunAktif ? TurkceFormat.para(araToplam) : ''),
        'kdv': (sonSayfa || !canliVeri) ? TurkceFormat.para(invoice.kdvTutari) : '',
        'kdvOrani': (sonSayfa || !canliVeri) ? (invoice.isKdvMuaf ? '' : '%${invoice.kdvOrani.toInt()}') : '',
        'genelToplam': (sonSayfa || !canliVeri) ? TurkceFormat.para(invoice.genelToplam) : '',
        'yaziylaTutar': (sonSayfa || !canliVeri) ? (yaziyla != null ? yaziyla(invoice.genelToplam) : '') : '',
        'hesapAdi': hesapAdi,
        'iban': iban,
        'ekstraNot_0': invoice.ekstraNotlar.isNotEmpty ? invoice.ekstraNotlar[0] : (canliVeri ? '' : FaturaMatbuConfig.ornekMetinler['ekstraNot_0']!),
        'ekstraNot_1': invoice.ekstraNotlar.length > 1 ? invoice.ekstraNotlar[1] : (canliVeri ? '' : FaturaMatbuConfig.ornekMetinler['ekstraNot_1']!),
        'ekstraNot_2': invoice.ekstraNotlar.length > 2 ? invoice.ekstraNotlar[2] : (canliVeri ? '' : FaturaMatbuConfig.ornekMetinler['ekstraNot_2']!),
        'ekstraNot_3': invoice.ekstraNotlar.length > 3 ? invoice.ekstraNotlar[3] : (canliVeri ? '' : FaturaMatbuConfig.ornekMetinler['ekstraNot_3']!),
        'ekstraNot_4': invoice.ekstraNotlar.length > 4 ? invoice.ekstraNotlar[4] : (canliVeri ? '' : FaturaMatbuConfig.ornekMetinler['ekstraNot_4']!),
      },
    );
  }

  factory KalibrasyonBaskiOnizleme.ornek({
    required String isletmeVkn,
    required String Function(double) yaziyla,
    int sayfaNo = 1,
  }) {
    final ornekFatura = FaturaModel(
      id: 'ornek',
      firmaAdi: FaturaMatbuConfig.ornekMetinler['firmaAdi']!,
      adres: FaturaMatbuConfig.ornekMetinler['adres']!,
      vergiDairesi: FaturaMatbuConfig.ornekMetinler['vergiDairesi']!,
      vergiNo: FaturaMatbuConfig.ornekMetinler['vkn']!,
      tarih: FaturaMatbuConfig.ornekMetinler['tarih']!,
      irsaliyeTarihi: FaturaMatbuConfig.ornekMetinler['irsaliyeTarihi']!,
      irsaliyeNo: FaturaMatbuConfig.ornekMetinler['irsaliyeNo']!,
      melbesNo: 'MEL-2026-0042',
      melbesKurumOnEki: FaturaMatbuConfig.varsayilanMelbesKurumOnEki,
      numuneNo: 'N-1087',
      numuneAciklamasi: FaturaMatbuConfig.ornekMetinler['numuneAciklama']!,
      kalemler: List.generate(12, (index) => {
        'cinsi': '${FaturaMatbuConfig.ornekMetinler['cinsi']} ${index + 1}',
        'miktar': 1,
        'fiyat': 150.0,
      }),
      matrah: 1800,
      kdvOrani: 20,
      kdvTutari: 360,
      genelToplam: 2160,
      isKdvMuaf: false,
      nakliYekunAktif: true,
      iban: FaturaMatbuConfig.ornekMetinler['iban'],
      hesapAdi: FaturaMatbuConfig.ornekMetinler['hesapAdi'],
    );
    return KalibrasyonBaskiOnizleme.fromFatura(
      ornekFatura,
      isletmeVkn: isletmeVkn,
      yaziyla: yaziyla,
      canliVeri: false,
      sayfaNo: sayfaNo,
      baslik: 'Örnek şablon (kuyrukta fatura yok)',
    );
  }
}
