import '../models/yk_karar_model.dart';

/// Ana YK Word birleştirmeden önce karar bütünlük kontrolü.
class YkKararButunlukServisi {
  ButunlukRaporu kontrolEt(List<YkKararModel> kararlar) {
    if (kararlar.isEmpty) {
      return const ButunlukRaporu(
        gecerli: false,
        hatalar: ['Birleştirilecek karar bulunamadı.'],
      );
    }

    final hatalar = <String>[];
    final uyarilar = <String>[];

    for (final karar in kararlar) {
      if (karar.birimAd.trim().isEmpty) {
        hatalar.add('Birim adı eksik karar kaydı var.');
      }

      if (karar.kararMetni.trim().isEmpty) {
        hatalar.add('${karar.birimAd}: Karar metni boş.');
      }

      if (karar.docxBodyXml == null || karar.docxBodyXml!.trim().isEmpty) {
        uyarilar.add(
          '${karar.birimAd}: Word OOXML yok — tablolar şablondan yeniden üretilebilir, '
          'birebir garanti verilmez.',
        );
      } else if (!karar.docxBodyXml!.contains('<w:tbl')) {
        uyarilar.add('${karar.birimAd}: OOXML içinde tablo bulunamadı.');
      }

      if (karar.eslesmeSkoru != null && karar.eslesmeSkoru! < 12) {
        uyarilar.add(
          '${karar.birimAd}: Eşleşme skoru düşük (${karar.eslesmeSkoru}) — '
          'ana karar tabloları indirmeden önce kontrol edilmeli.',
        );
      }

      if (karar.analizUyarilari.isNotEmpty) {
        uyarilar.add('${karar.birimAd}: ${karar.analizUyarilari.first}');
      }

      if (karar.tabloVerileri.isNotEmpty &&
          (karar.docxBodyXml == null || karar.docxBodyXml!.isEmpty)) {
        uyarilar.add(
          '${karar.birimAd}: PDF tablo verisi var ancak Word şablon eşleşmesi kaydedilmemiş.',
        );
      }
    }

    return ButunlukRaporu(
      gecerli: hatalar.isEmpty,
      hatalar: hatalar,
      uyarilar: uyarilar,
      kararSayisi: kararlar.length,
      ooxmlKararSayisi: kararlar
          .where((k) => k.docxBodyXml?.isNotEmpty == true)
          .length,
    );
  }
}

class ButunlukRaporu {
  const ButunlukRaporu({
    required this.gecerli,
    this.hatalar = const [],
    this.uyarilar = const [],
    this.kararSayisi = 0,
    this.ooxmlKararSayisi = 0,
  });

  final bool gecerli;
  final List<String> hatalar;
  final List<String> uyarilar;
  final int kararSayisi;
  final int ooxmlKararSayisi;

  String get ozet =>
      '$kararSayisi birim kararı — $ooxmlKararSayisi tanesi Word şablonlu (OOXML).';
}
