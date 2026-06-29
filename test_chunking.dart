import 'dart:convert';

void main() {
  final kalemlerHam = List.generate(12, (i) => {
    'cinsi': 'Item $i',
    'miktar': 1,
    'fiyat': 100,
  });

  final satirLimit = 10;
  int currentItemIndex = 0;
  final pages = [];

  double runningTotal = 0.0;
  bool nakliYekunAktif = true;

  while (currentItemIndex < kalemlerHam.length || pages.isEmpty) {
    int spaceLeft = satirLimit;
    final currentPageItems = [];

    if (pages.isNotEmpty && nakliYekunAktif) {
      currentPageItems.add({
        'cinsi': 'N A K L İ Y E K Ü N (TOP)',
        'isNakliYekun': true,
        'nakliTutar': runningTotal,
      });
      spaceLeft--;
    }

    int itemsRemaining = kalemlerHam.length - currentItemIndex;
    bool willHaveNextPage = false;
    if (nakliYekunAktif && itemsRemaining > spaceLeft) {
      willHaveNextPage = true;
    }

    int effectiveSpace = willHaveNextPage ? spaceLeft - 1 : spaceLeft;

    double pageRealTotal = 0.0;
    while (effectiveSpace > 0 && currentItemIndex < kalemlerHam.length) {
      final item = kalemlerHam[currentItemIndex];
      currentPageItems.add(item);
      pageRealTotal += double.parse(item['fiyat'].toString()) * double.parse(item['miktar'].toString());
      currentItemIndex++;
      effectiveSpace--;
      spaceLeft--;
    }

    runningTotal += pageRealTotal;

    if (willHaveNextPage) {
      currentPageItems.add({
        'cinsi': 'N A K L İ Y E K Ü N (BOTTOM)',
        'isNakliYekun': true,
        'nakliTutar': runningTotal,
      });
      spaceLeft--;
    }

    pages.add(currentPageItems);
  }

  // UI Chunking Logic
  currentItemIndex = 0;
  final pagesOfIndices = <List<int>>[];
  while (currentItemIndex < kalemlerHam.length || pagesOfIndices.isEmpty) {
    int spaceLeft = satirLimit;
    final currentPageIndices = <int>[];

    if (pagesOfIndices.isNotEmpty && nakliYekunAktif) {
      currentPageIndices.add(-1);
      spaceLeft--;
    }

    int itemsRemaining = kalemlerHam.length - currentItemIndex;
    bool willHaveNextPage = false;
    if (nakliYekunAktif && itemsRemaining > spaceLeft) {
      willHaveNextPage = true;
    }

    int effectiveSpace = willHaveNextPage ? spaceLeft - 1 : spaceLeft;

    while (effectiveSpace > 0 && currentItemIndex < kalemlerHam.length) {
      currentPageIndices.add(currentItemIndex);
      currentItemIndex++;
      effectiveSpace--;
      spaceLeft--;
    }

    if (willHaveNextPage) {
      currentPageIndices.add(-1);
      spaceLeft--;
    }

    pagesOfIndices.add(currentPageIndices);
  }

  print('--- PDF ONIZLEME PAGES ---');
  for (int i=0; i<pages.length; i++) {
    print('Page ${i+1}: ${pages[i].map((e) => e['cinsi']).toList()}');
  }

  print('\n--- UI PAGES OF INDICES ---');
  for (int i=0; i<pagesOfIndices.length; i++) {
    print('Page ${i+1}: ${pagesOfIndices[i]}');
  }
}
