import '../../../core/turkce_format.dart';

/// Çok sayfalı matbu fatura kalem dağılımı — önizleme ve PDF ortak kaynak.
class MatbuSayfaSonuc {
  const MatbuSayfaSonuc({
    required this.sayfalar,
    required this.sayfaToplamlari,
  });

  final List<List<Map<String, dynamic>>> sayfalar;
  final List<double> sayfaToplamlari;
}

class FaturaMatbuSayfalama {
  FaturaMatbuSayfalama._();

  static const nakliCinsi = 'N A K L İ Y E K Ü N';

  static MatbuSayfaSonuc sayfala({
    required List<Map<String, dynamic>> kalemler,
    required bool nakliYekunAktif,
    required int satirLimit,
  }) {
    final sayfalar = <List<Map<String, dynamic>>>[];
    final sayfaToplamlari = <double>[];
    var currentItemIndex = 0;
    var runningTotal = 0.0;

    while (currentItemIndex < kalemler.length || sayfalar.isEmpty) {
      var spaceLeft = satirLimit;
      final currentPageItems = <Map<String, dynamic>>[];

      if (sayfalar.isNotEmpty && nakliYekunAktif) {
        spaceLeft--;
      }

      final itemsRemaining = kalemler.length - currentItemIndex;
      var willHaveNextPage = false;
      if (nakliYekunAktif && itemsRemaining > spaceLeft) {
        willHaveNextPage = true;
      }

      var effectiveSpace = willHaveNextPage ? spaceLeft - 1 : spaceLeft;
      var pageRealTotal = 0.0;

      while (effectiveSpace > 0 && currentItemIndex < kalemler.length) {
        final item = kalemler[currentItemIndex];
        currentPageItems.add(item);

        final fiyat = TurkceFormat.parseSayi(item['fiyat'], fallback: 0.0);
        final miktar = TurkceFormat.parseSayi(item['miktar'], fallback: 1.0);
        pageRealTotal += fiyat * miktar;

        currentItemIndex++;
        effectiveSpace--;
        spaceLeft--;
        
        if (item['sayfayiBol'] == true && currentItemIndex < kalemler.length) {
          willHaveNextPage = true;
          break; // Kullanıcı bu kalemde sayfayı bölmek istedi
        }
      }

      runningTotal += pageRealTotal;

      if (willHaveNextPage) {
        // Alt nakli yekün aktif
      }

      sayfalar.add(currentPageItems);
      sayfaToplamlari.add(runningTotal);
    }

    return MatbuSayfaSonuc(
      sayfalar: sayfalar,
      sayfaToplamlari: sayfaToplamlari,
    );
  }
}
