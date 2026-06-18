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
    required String isletmeVkn,
    String? sistemHesapAdi,
    String? sistemIban,
    required String Function(double) yaziyla,
    bool canliVeri = true,
    String baslik = '',
  }) {
    var kalemlerHam = FaturaMatbuConfig.matbuKalemleri(invoice.kalemler);
    if (kalemlerHam.isEmpty) {
      kalemlerHam = [
        {
          'cinsi': invoice.numuneAciklamasi.isNotEmpty
              ? invoice.numuneAciklamasi
              : 'Hizmet Bedeli',
          'miktar': 1,
          'fiyat': invoice.matrah,
        },
      ];
    }

    final kalemler = kalemlerHam.map((item) {
      final fiyat = double.tryParse(item['fiyat'].toString()) ?? 0.0;
      final miktar = double.tryParse(item['miktar'].toString()) ?? 1.0;
      final miktarMetin = miktar == miktar.roundToDouble()
          ? miktar.toInt().toString()
          : TurkceFormat.ondalik(miktar);
      return KalibrasyonKalemSatir(
        cinsi: '${item['cinsi']}',
        miktar: miktarMetin,
        fiyat: TurkceFormat.para(fiyat),
        tutar: TurkceFormat.para(fiyat * miktar),
      );
    }).toList();

    const satirLimit = 10;
    final toplamSayfa = (kalemlerHam.length / satirLimit).ceil().clamp(1, 9999);
    final tekSayfa = toplamSayfa == 1;
    final sayfaToplami = kalemlerHam.fold<double>(0, (acc, item) {
      final fiyat = double.tryParse(item['fiyat'].toString()) ?? 0.0;
      final miktar = double.tryParse(item['miktar'].toString()) ?? 1.0;
      return acc + (fiyat * miktar);
    });

    final numuneAciklamaAlt = invoice.numuneAciklamasi.trim();
    final numuneMelbesSatir = numuneAciklamaAlt.toLowerCase().contains('melbes') &&
        numuneAciklamaAlt.toLowerCase().contains('numune');
    final ustAciklamalar = [
      if (numuneAciklamaAlt.isNotEmpty && !numuneMelbesSatir) numuneAciklamaAlt,
      if (invoice.aciklama != null && invoice.aciklama!.trim().isNotEmpty)
        invoice.aciklama!.trim(),
      if (invoice.isKdvMuaf) "KDV'den Muaftır (İstisna)",
    ].join(' | ');

    final melbesSatir = FaturaMatbuConfig.formatMelbesNumuneSatir(
      melbes: invoice.melbesNo,
      numune: invoice.numuneNo,
      kurumOnEki: invoice.melbesKurumOnEki.trim().isNotEmpty
          ? invoice.melbesKurumOnEki
          : null,
    );

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
        'nakliYekunUstYazi': invoice.nakliYekunAktif && !tekSayfa
            ? 'Nakli Yekün (Önceki Sayfa)'
            : '',
        'nakliYekunUstTutar': invoice.nakliYekunAktif && !tekSayfa
            ? TurkceFormat.para(0)
            : '',
        'nakliYekunAltYazi':
            invoice.nakliYekunAktif ? 'Nakli Yekün (Devreden)' : '',
        'nakliYekunAltTutar':
            invoice.nakliYekunAktif ? TurkceFormat.para(sayfaToplami) : '',
        'numuneAciklama': ustAciklamalar,
        'melbes': melbesSatir.isNotEmpty
            ? melbesSatir
            : invoice.melbesKurumOnEki.trim(),
        'matrah': TurkceFormat.para(invoice.matrah),
        'kdv': TurkceFormat.para(invoice.kdvTutari),
        'genelToplam': TurkceFormat.para(invoice.genelToplam),
        'yaziylaTutar': yaziyla(invoice.genelToplam),
        'hesapAdi': hesapAdi,
        'iban': iban,
      },
    );
  }

  factory KalibrasyonBaskiOnizleme.ornek({
    required String isletmeVkn,
    required String Function(double) yaziyla,
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
      kalemler: [
        {
          'cinsi': FaturaMatbuConfig.ornekMetinler['cinsi'],
          'miktar': 1,
          'fiyat': 1500.0,
        },
      ],
      matrah: 1500,
      kdvOrani: 20,
      kdvTutari: 300,
      genelToplam: 1800,
      isKdvMuaf: false,
      nakliYekunAktif: false,
      iban: FaturaMatbuConfig.ornekMetinler['iban'],
      hesapAdi: FaturaMatbuConfig.ornekMetinler['hesapAdi'],
    );
    return KalibrasyonBaskiOnizleme.fromFatura(
      ornekFatura,
      isletmeVkn: isletmeVkn,
      yaziyla: yaziyla,
      canliVeri: false,
      baslik: 'Örnek şablon (kuyrukta fatura yok)',
    );
  }
}
