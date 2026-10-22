import '../models/fatura_matbu_config.dart';
import '../models/fatura_model.dart';
import '../models/fatura_parse_kaynaklari.dart';

/// İnternet/AI olmadan ham metni (Excel CSV dökümü veya yapıştırılan metin)
/// kural tabanlı olarak faturaya çeviren çevrimdışı ayrıştırıcı.
///
/// Birim fatura şablonlarındaki 3 sayfalı yapı esas alınmıştır:
/// - "VERİ GİRİŞ" sayfası: BİRİM/İBAN + FATURA TARİHİ/FİRMA/VERGİ + kalemler
/// - "FATURA" sayfası: görsel düzen (yedek)
/// - "Firma Bilgileri" / "HAVUZ": firma & birim listeleri
class FaturaOfflineParser {
  static const String kaynakEtiketi = FaturaParseKaynaklari.cevrimdisi;

  static final RegExp _ibanRegex = RegExp(
    r'TR\d{2}(?:[ ]?\d){22}',
    caseSensitive: false,
  );
  static final RegExp _melbesRegex = RegExp(
    r'melbes(?:\s*ba[şs]vuru)?\s*(?:no)?\s*[:.\-]?\s*([A-Z0-9\-/]+)',
    caseSensitive: false,
  );
  static final RegExp _numuneRegex = RegExp(
    r'numune\s*no\s*[:.\-]?\s*([A-Z0-9\-/]+)',
    caseSensitive: false,
  );
  static final RegExp _raporRegex = RegExp(
    r'rapor\s*no\s*[:.\-]?\s*([^|\n\r]+)',
    caseSensitive: false,
  );
  static final RegExp _irsaliyeTarihRegex = RegExp(
    r'irsaliye\s*tarih(?:i)?\s*[:.\-]?\s*(\d{1,2}[./]\d{1,2}[./]\d{2,4})',
    caseSensitive: false,
  );
  static final RegExp _tarihRegex = RegExp(
    r'\b(\d{1,2})[./](\d{1,2})[./](\d{2,4})\b',
  );
  
  static final RegExp _kursAdiRegex = RegExp(
    r'kurs\s*(?:ad[ıi])?\s*[:.\-]?\s*(.+)',
    caseSensitive: false,
  );
  static final RegExp _kurNoRegex = RegExp(
    r'(\d+)[.\s]*kur\b',
    caseSensitive: false,
  );
  static final RegExp _donemRegex = RegExp(
    r'\b(ocak|şubat|mart|nisan|mayıs|haziran|temmuz|ağustos|eylül|ekim|kasım|aralık)\s*\d{4}\b',
    caseSensitive: false,
  );

  /// Ham metinden bir veya daha fazla fatura çıkarır.
  static List<FaturaModel> parse(String rawText) {
    if (rawText.trim().isEmpty) return [];

    final sheets = _splitSheets(rawText);

    // 1) En güvenilir kaynak: VERİ GİRİŞ sayfası
    final veriGiris = _findSheet(sheets, ['veri giriş', 'veri giris']);
    if (veriGiris != null) {
      final fatura = _parseVeriGiris(veriGiris, rawText);
      if (fatura != null && fatura.kalemler.isNotEmpty) return [fatura];
    }

    // 2) FATURA sayfası (görsel düzen)
    final faturaSheet = _findSheet(sheets, ['fatura']);
    if (faturaSheet != null) {
      final fatura = _parseFaturaSheet(faturaSheet, rawText);
      if (fatura != null && fatura.kalemler.isNotEmpty) return [fatura];
    }

    // 3) e-Arşiv / e-Fatura GİB standart metin katmanı (ETTN / e-Arşiv açık etiketli)
    final eArsivSonuc = _parseEArsivMetni(rawText);
    if (eArsivSonuc != null && eArsivSonuc.kalemler.isNotEmpty) {
      return [eArsivSonuc];
    }

    // 4) Birim talep PDF formu (üst yazılı, MELBES/Numune bloklu veya tekil birim talep tablosu)
    final talepSonuc = _parseBirimTalepFormu(rawText);
    if (talepSonuc != null && talepSonuc.isNotEmpty) return talepSonuc;

    // 4.5) Tablo/Liste formatı (Yumurta Satış vb. - her satır ayrı fatura)
    final listeSonuc = _parseYumurtaListesi(rawText);
    if (listeSonuc != null && listeSonuc.isNotEmpty) return listeSonuc;

    // 5) Serbest metin / sayfa işareti olmayan döküm (fallback)
    final fatura = _parseFreeText(rawText);
    return fatura == null ? [] : [fatura];
  }

  // --------------------------------------------------------------------------
  // Sayfa ayırma
  // --------------------------------------------------------------------------

  static Map<String, List<List<String>>> _splitSheets(String text) {
    final result = <String, List<List<String>>>{};
    final sheetHeader = RegExp(
      r'^-+\s*SHEET:\s*(.+?)\s*-+$',
      caseSensitive: false,
    );

    String current = '__root__';
    result[current] = [];

    for (final rawLine in text.split('\n')) {
      final line = rawLine.replaceAll('\r', '');
      final m = sheetHeader.firstMatch(line.trim());
      if (m != null) {
        current = m.group(1)!.trim();
        result[current] = [];
        continue;
      }
      if (line.trim().isEmpty) continue;
      result[current]!.add(line.split('|').map((c) => c.trim()).toList());
    }
    return result;
  }

  static List<List<String>>? _findSheet(
    Map<String, List<List<String>>> sheets,
    List<String> aliases,
  ) {
    for (final entry in sheets.entries) {
      final name = entry.key.toLowerCase();
      if (aliases.any((a) => name == a || name.contains(a))) {
        if (entry.value.isNotEmpty) return entry.value;
      }
    }
    return null;
  }

  // --------------------------------------------------------------------------
  // VERİ GİRİŞ ayrıştırma
  // --------------------------------------------------------------------------

  static FaturaModel? _parseVeriGiris(
    List<List<String>> rows,
    String fullText,
  ) {
    int firmaHeaderRow = -1;
    int kalemHeaderRow = -1;

    for (var i = 0; i < rows.length; i++) {
      final joined = rows[i].join(' ').toLowerCase();
      if (firmaHeaderRow == -1 &&
          joined.contains('fatura tarih') &&
          joined.contains('firma ad')) {
        firmaHeaderRow = i;
      }
      if (kalemHeaderRow == -1 && joined.contains('malin cins')) {
        kalemHeaderRow = i;
      }
    }

    String firmaAdi = '';
    String adres = '';
    String vergiDairesi = '';
    String vergiNo = '';
    String tarih = '';

    if (firmaHeaderRow != -1) {
      final header = rows[firmaHeaderRow];
      final tarihCol = _colIndex(header, ['fatura tarih']);
      final firmaCol = _colIndex(header, ['firma ad']);
      final vdCol = _colIndex(header, ['vergi d']);
      final vnCol = _colIndex(header, ['vergi no']);

      final valueRow = _firstNonEmptyAfter(rows, firmaHeaderRow, [
        tarihCol,
        firmaCol,
        vdCol,
        vnCol,
      ]);
      if (valueRow != null) {
        if (firmaCol >= 0) {
          final raw = _cell(valueRow, firmaCol);
          final parts = raw
              .split(RegExp(r'[\n]'))
              .map((e) => e.trim())
              .toList();
          firmaAdi = parts.isNotEmpty ? parts.first : raw;
          adres = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        }
        if (vdCol >= 0) vergiDairesi = _cleanVergiD(_cell(valueRow, vdCol));
        if (vnCol >= 0) vergiNo = _cell(valueRow, vnCol);
        if (tarihCol >= 0) tarih = _normalizeTarih(_cell(valueRow, tarihCol));
      }
    }

    final kalemler = <Map<String, dynamic>>[];
    double kdvOrani = 20;
    if (kalemHeaderRow != -1) {
      final header = rows[kalemHeaderRow];
      final cinsiCol = _colIndex(header, ['malin cins']);
      final miktarCol = _colIndex(header, ['miktar']);
      final fiyatCol = _colIndex(header, ['birim fiyat']);
      final tutarCol = _colIndex(header, ['tutar']);
      final kdvCol = _colIndex(header, ['kdv']);

      for (var i = kalemHeaderRow + 1; i < rows.length; i++) {
        final row = rows[i];
        final cinsi = cinsiCol >= 0 ? _cell(row, cinsiCol) : '';
        if (cinsi.isEmpty) continue;
        if (_atlanacakKalem(cinsi)) continue;

        final miktar = miktarCol >= 0 ? _parseNum(_cell(row, miktarCol)) : 0;
        final fiyat = fiyatCol >= 0 ? _parseNum(_cell(row, fiyatCol)) : 0;
        final tutar = tutarCol >= 0 ? _parseNum(_cell(row, tutarCol)) : 0;

        var birimFiyat = fiyat;
        var adet = miktar <= 0 ? 1.0 : miktar;
        if (birimFiyat <= 0 && tutar > 0) birimFiyat = tutar / adet;
        if (birimFiyat <= 0) continue;

        kalemler.add({
          'cinsi': cinsi,
          'miktar': adet == adet.roundToDouble() ? adet.toInt() : adet,
          'fiyat': birimFiyat,
        });

        if (kdvCol >= 0) {
          final k = _parseNum(_cell(row, kdvCol));
          if (k > 0) kdvOrani = k;
        }
      }
    }

    final ibanBilgi = _extractIbanHesap(rows, fullText);
    final muaf = fullText.toLowerCase().contains('muaf');

    if (firmaAdi.isEmpty && kalemler.isEmpty) return null;

    return _build(
      firmaAdi: firmaAdi,
      adres: adres,
      vergiDairesi: vergiDairesi,
      vergiNo: vergiNo,
      tarih: tarih,
      kalemler: kalemler,
      kdvOrani: kdvOrani,
      muaf: muaf,
      iban: ibanBilgi.$1,
      hesapAdi: ibanBilgi.$2,
      fullText: fullText,
    );
  }

  // --------------------------------------------------------------------------
  // FATURA sayfası ayrıştırma
  // --------------------------------------------------------------------------

  static FaturaModel? _parseFaturaSheet(
    List<List<String>> rows,
    String fullText,
  ) {
    String firmaAdi = '';
    String adres = '';
    final kalemler = <Map<String, dynamic>>[];

    for (final row in rows) {
      final ilk = _cell(row, 0);
      if (ilk.isEmpty) continue;

      if (firmaAdi.isEmpty &&
          !ilk.toLowerCase().contains('nakl') &&
          RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(ilk) &&
          !_atlanacakKalem(ilk)) {
        final parts = ilk.split(RegExp(r'[\n]')).map((e) => e.trim()).toList();
        firmaAdi = parts.first;
        adres = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        continue;
      }

      // Kalem satırı: cinsi + miktar + tutarlar
      final amount = row.map(_parseNum).where((v) => v > 0).toList();
      if (amount.isNotEmpty &&
          RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(ilk) &&
          !_atlanacakKalem(ilk)) {
        kalemler.add({'cinsi': ilk, 'miktar': 1, 'fiyat': amount.first});
      }
    }

    final ibanBilgi = _extractIbanHesap(rows, fullText);
    if (firmaAdi.isEmpty && kalemler.isEmpty) return null;

    return _build(
      firmaAdi: firmaAdi,
      adres: adres,
      vergiDairesi: '',
      vergiNo: '',
      tarih: _ilkTarih(fullText),
      kalemler: kalemler,
      kdvOrani: 20,
      muaf: fullText.toLowerCase().contains('muaf'),
      iban: ibanBilgi.$1,
      hesapAdi: ibanBilgi.$2,
      fullText: fullText,
    );
  }

  // --------------------------------------------------------------------------
  // Tablo / Satır Satır Liste Ayrıştırma (Örn: Yumurta Listesi)
  // --------------------------------------------------------------------------
  
  static List<FaturaModel>? _parseYumurtaListesi(String text) {
    // Listede çoklu satır olup olmadığını anlamak için basit bir kelime kontrolü
    if (!text.toLowerCase().contains('yumurta') && !text.toLowerCase().contains('liste')) {
      return null;
    }

    final lines = text.split('\n').map((l) => l.replaceAll('|', ' ').trim()).toList();
    
    // Satır regex'i: Başta olası sıra no, ortada isim (min 2 kelime), sonda tutar
    // Örn: "1 Ahmet Yılmaz 150,00" veya "Ahmet Yılmaz 150 TL"
    final satirRegex = RegExp(
      r'^(?:\d+[\s\.\-]+)?([a-zA-ZçğıöşüÇĞİÖŞÜ]+\s+[a-zA-ZçğıöşüÇĞİÖŞÜ\s]+?)[\s\t:]+([\d.,]+)\s*(?:TL|₺)?$',
      caseSensitive: false,
    );

    final faturalar = <FaturaModel>[];
    final tarih = _ilkTarih(text);
    
    final ibanMatch = _ibanRegex.firstMatch(text);
    final ibanStr = ibanMatch == null ? null : _normalizeIban(ibanMatch.group(0)!);

    // KDV oranını belirle: Eğer metinde %10 geçiyorsa 10, yoksa temel gıda (yumurta) için %1
    double kdvOrani = 1.0;
    if (text.contains('%10') || text.contains('10%') || text.contains('kdv 10') || text.contains('kdv %10')) {
      kdvOrani = 10.0;
    } else if (text.contains('%20') || text.contains('20%') || text.contains('kdv 20')) {
      kdvOrani = 20.0;
    }

    for (final line in lines) {
      if (line.isEmpty || _atlanacakKalem(line) || _isMetadataLine(line)) continue;
      
      final m = satirRegex.firstMatch(line);
      if (m != null) {
        final adSoyad = m.group(1)!.trim();
        final tutar = _parseNum(m.group(2)!);
        
        if (adSoyad.split(' ').length >= 2 && tutar > 0 && adSoyad.length > 5) {
          final fatura = _build(
            firmaAdi: adSoyad,
            adres: '',
            vergiDairesi: '',
            vergiNo: '',
            tarih: tarih,
            kalemler: [
              {
                'cinsi': 'Yumurta Satış Bedeli', // Varsayılan kalem açıklaması
                'miktar': 1,
                'fiyat': tutar,
              }
            ],
            kdvOrani: kdvOrani,
            kdvDahil: true,
            muaf: text.toLowerCase().contains('muaf'),
            iban: ibanStr,
            hesapAdi: null,
            fullText: line, // Sadece o satırı verelim
          );
          faturalar.add(fatura);
        }
      }
    }

    if (faturalar.isNotEmpty && faturalar.length >= 2) {
      return faturalar; // En az 2 kişi/satır bulduysa geçerli bir listedir.
    }
    
    return null;
  }

  // --------------------------------------------------------------------------
  // Serbest metin ayrıştırma
  // --------------------------------------------------------------------------

  static FaturaModel? _parseFreeText(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.replaceAll('|', ' ').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    final firmaAdi = _extractFirmaAdi(lines);
    final adres = _extractAdres(lines, firmaAdi);
    final kalemler = <Map<String, dynamic>>[];

    // Dip toplamları tara (Ödenecek Tutar, Genel Toplam, Mal Hizmet Toplam Tutarı, KDV vb.)
    final odenecekMatch = RegExp(
      r'(?:[öo]denecek\s*tutar|genel\s*toplam|toplam\s*tutar|fatura\s*toplam[ıi])\s*[:.\-]?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final matrahMatch = RegExp(
      r'(?:matrah|mal\s*hizmet\s*toplam(?:\s*tutar[ıi])?|vergi\s*matrah[ıi])\s*[:.\-]?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final kdvOranMatch = RegExp(
      r'(?:kdv\s*oran[ıi]|oran[ıi])\s*[:.\-]?\s*%?\s*(\d{1,2})',
      caseSensitive: false,
    ).firstMatch(text);

    final dipGenelToplam = odenecekMatch != null ? _parseNum(odenecekMatch.group(1)!) : 0.0;
    final dipMatrah = matrahMatch != null ? _parseNum(matrahMatch.group(1)!) : 0.0;
    final dipKdvOrani = kdvOranMatch != null ? (double.tryParse(kdvOranMatch.group(1)!) ?? 20.0) : 20.0;

    for (final line in lines) {
      final parsed = _parseKalemSatiri(line);
      if (parsed != null) {
        kalemler.add(parsed);
      }
    }

    // Kalem satırları tek tek tespit edilemediyse ama dip toplam bulunduysa faturayı kurtar
    if (kalemler.isEmpty && (dipGenelToplam > 0 || dipMatrah > 0)) {
      final tutar = dipMatrah > 0 ? dipMatrah : dipGenelToplam;
      kalemler.add({
        'cinsi': 'Fatura Bedeli',
        'miktar': 1,
        'birimFiyat': tutar,
        'fiyat': tutar,
        'tutar': tutar,
      });
    }

    if (kalemler.isEmpty) return null;

    final ibanMatch = _ibanRegex.firstMatch(text);
    final vergiNo = _extractVkn(text);
    final vdMatch = RegExp(
      r'(?:vergi\s*dairesi|v\.d\.)\s*[:.\-]?\s*([A-Za-zÇĞİÖŞÜçğıöşü\s]+?)(?:[\n,]|vkn|vergi|$)',
      caseSensitive: false,
    ).firstMatch(text);

    return _build(
      firmaAdi: firmaAdi,
      adres: adres,
      vergiDairesi: vdMatch?.group(1)?.trim() ?? '',
      vergiNo: vergiNo,
      tarih: _ilkTarih(text),
      kalemler: kalemler,
      kdvOrani: dipKdvOrani,
      muaf: text.toLowerCase().contains('muaf'),
      iban: ibanMatch == null ? null : _normalizeIban(ibanMatch.group(0)!),
      hesapAdi: null,
      fullText: text,
    );
  }

  static String _extractAdres(List<String> lines, String firmaAdi) {
    // 1. "Adres:", "Adres -", "Müşteri Adresi:" vb. ön ekli satırlar
    final prefixRegex = RegExp(
      r'^(?:m[üu][şs]teri\s*)?(?:fatura\s*)?(?:teslimat\s*)?adres[ıi]?\s*[:.\-]\s*',
      caseSensitive: false,
    );
    for (final line in lines) {
      final trimmed = line.trim();
      if (prefixRegex.hasMatch(trimmed)) {
        final res = trimmed.replaceFirst(prefixRegex, '').trim();
        if (res.length > 3 && res != firmaAdi) return res;
      }
    }

    // 2. Adres anahtar kelimeleri içeren satırlar
    final adresKeywords = [
      'mah.', 'mahallesi', 'mah ', 'cad.', 'caddesi', 'cad ',
      'sok.', 'sokak', 'sok ', 'sk.', 'sk ', 'bulvar', 'blv.',
      'apt.', 'sitesi', 'organize sanayi', 'osb', 'sanayi bölgesi',
      'küme evleri', 'mevkii', 'no:', 'kat:', 'daire:',
    ];

    for (final line in lines) {
      final l = line.toLowerCase().trim();
      if (line.trim() == firmaAdi.trim()) continue;
      // Salt fatura, tarih, tutar, vkn başlıklarını atla
      if (l.startsWith('fatura no') ||
          l.startsWith('tarih') ||
          l.startsWith('toplam') ||
          l.startsWith('matrah') ||
          l.startsWith('kdv') ||
          l.startsWith('vkn') ||
          l.startsWith('iban')) {
        continue;
      }
      for (final kw in adresKeywords) {
        if (l.contains(kw) && line.trim().length > 6) {
          final temiz = line.replaceAll(
            RegExp(r'^(?:m[üu][şs]teri\s*)?(?:fatura\s*)?adres[ıi]?\s*[:.\-]?\s*', caseSensitive: false),
            '',
          ).trim();
          return temiz.isNotEmpty ? temiz : line.trim();
        }
      }
    }

    // 3. Firma adından hemen sonraki satır (eğer metadata veya başlık değilse)
    if (firmaAdi.isNotEmpty) {
      final fIdx = lines.indexWhere(
        (line) => line.trim() == firmaAdi.trim() || line.contains(firmaAdi.trim()),
      );
      if (fIdx != -1 && fIdx + 1 < lines.length) {
        final nextLine = lines[fIdx + 1].trim();
        final lNext = nextLine.toLowerCase();
        final isOtherField = lNext.startsWith('tarih') ||
            lNext.startsWith('fatura no') ||
            lNext.startsWith('vkn') ||
            lNext.startsWith('tc') ||
            lNext.startsWith('vergi no') ||
            lNext.startsWith('vergi dairesi') ||
            lNext.startsWith('vd') ||
            lNext.startsWith('toplam');
        if (!isOtherField && nextLine.length > 8) {
          final temiz = nextLine.replaceAll(
            RegExp(r'^(?:adres[ıi]?)\s*[:.\-]?\s*', caseSensitive: false),
            '',
          ).trim();
          return temiz.isNotEmpty ? temiz : nextLine;
        }
      }
    }

    return '';
  }

  static Map<String, dynamic>? _parseKalemSatiri(String rawLine) {
    var line = rawLine.trim();
    if (line.isEmpty || _atlanacakKalem(line) || _isMetadataLine(line)) return null;

    // Baştaki sıra numarasını temizle (örn. "1 - " veya "1. " veya "1 ")
    final siraMatch = RegExp(r'^\d+[\s\.\-]+').firstMatch(line);
    if (siraMatch != null && siraMatch.end < line.length) {
      line = line.substring(siraMatch.end).trim();
    }

    // 1. Çok kolonlu e-Fatura / Tablo formatı:
    // "Su ve Toprak Ağır Metal Analizi 1 Adet 2.500,00 %20 500,00 2.500,00 TL"
    // "Kompozit Dolgu Tedavisi 2 ADET 750,00 1.500,00"
    // "Diş Çekimi ve Pansuman 1 500,00 500,00"
    final multiColRegex = RegExp(
      r'^(.+?)\s+(\d+(?:[.,]\d+)?)\s*(?:ADET|Adet|adet|KG|Kg|kg|LT|Lt|lt|METRE|Metre|m|KUTU|Kutu|kutu|PAKET|Paket|paket|AY|Ay|GÜN|Gün|SAAT|Saat|HİZMET|Hizmet|SEANS|Seans|AD|Ad)?\s+([\d.,]+)(?:\s+.*?)?(?:\s+([\d.,]+))?\s*(?:TL|₺)?$',
      caseSensitive: false,
    );
    final mMulti = multiColRegex.firstMatch(line);
    if (mMulti != null) {
      final cinsi = mMulti.group(1)!.trim();
      if (cinsi.length >= 2 && !_atlanacakKalem(cinsi) && !_isMetadataLine(cinsi)) {
        final miktarNum = _parseNum(mMulti.group(2)!);
        final miktar = miktarNum <= 0 ? 1.0 : miktarNum;
        final sayi1 = _parseNum(mMulti.group(3)!);
        final sayi2 = mMulti.group(4) != null ? _parseNum(mMulti.group(4)!) : 0.0;

        double birimFiyat = sayi1;
        double tutar = sayi2 > 0 ? sayi2 : (birimFiyat * miktar);

        if (sayi2 > 0 && birimFiyat > 0) {
          if ((sayi1 * miktar - sayi2).abs() < 0.05) {
            birimFiyat = sayi1;
            tutar = sayi2;
          } else if ((sayi2 * miktar - sayi1).abs() < 0.05) {
            birimFiyat = sayi2;
            tutar = sayi1;
          }
        }

        if (birimFiyat > 0 || tutar > 0) {
          return {
            'cinsi': cinsi,
            'miktar': miktar == miktar.roundToDouble() ? miktar.toInt() : miktar,
            'birimFiyat': birimFiyat > 0 ? birimFiyat : (tutar / miktar),
            'fiyat': birimFiyat > 0 ? birimFiyat : (tutar / miktar),
            'tutar': tutar > 0 ? tutar : (birimFiyat * miktar),
          };
        }
      }
    }

    // 2. Basit format: <Açıklama> <Tutar> TL
    final basitRegex = RegExp(
      r'^([A-Za-zÇĞİÖŞÜçğıöşü0-9\s.,_\-\/()%]+?)[\s\t:]+([\d.,]+)\s*(?:TL|₺)?\s*$',
      caseSensitive: false,
    );
    final mBasit = basitRegex.firstMatch(line);
    if (mBasit != null) {
      var cinsi = mBasit.group(1)!.trim();
      cinsi = cinsi.replaceFirst(RegExp(r'^\d+[\s\.\-]+'), '').trim();
      final tutar = _parseNum(mBasit.group(2)!);
      if (cinsi.length >= 2 && tutar > 0 && !_atlanacakKalem(cinsi) && !_isMetadataLine(cinsi)) {
        return {
          'cinsi': cinsi,
          'miktar': 1,
          'birimFiyat': tutar,
          'fiyat': tutar,
          'tutar': tutar,
        };
      }
    }

    return null;
  }

  static bool _isMetadataLine(String s) {
    final l = s.toLowerCase().trim();
    if (l.isEmpty) return true;
    if (l == 'vkn' ||
        l == 'tc' ||
        l == 'tckn' ||
        l == 'no' ||
        l == 'vd' ||
        l == 'v.d.' ||
        l == 'tel' ||
        l == 'fax' ||
        l == 'mersis' ||
        l == 'ettn' ||
        l == 'sayfa' ||
        l == 'tarih' ||
        l == 'fatura' ||
        l == 'adres' ||
        l == 'toplam' ||
        l == 'matrah' ||
        l == 'kdv' ||
        l == 'mal hizmet' ||
        l == 'mal/hizmet') {
      return true;
    }
    return l.startsWith('fatura no') ||
        l.startsWith('fatura tarihi') ||
        l.startsWith('özelleştirme no') ||
        l.startsWith('ozellestirme no') ||
        l.startsWith('senaryo') ||
        l.startsWith('fatura tipi') ||
        l.startsWith('ettn') ||
        l.startsWith('sayfa no') ||
        l.startsWith('sayfa :') ||
        l.startsWith('sayfa:') ||
        l.startsWith('vergi') ||
        l.startsWith('v.d.') ||
        l.startsWith('vd:') ||
        l.startsWith('vkn') ||
        l.startsWith('tckn') ||
        l.startsWith('tc no') ||
        l.startsWith('tc kimlik') ||
        l.startsWith('sayın') ||
        l.startsWith('sayin') ||
        l.startsWith('müşteri') ||
        l.startsWith('musteri') ||
        l.startsWith('alici') ||
        l.startsWith('alıcı') ||
        l.startsWith('satıcı') ||
        l.startsWith('satici') ||
        l.startsWith('düzenleyen') ||
        l.startsWith('duzenleyen') ||
        l.startsWith('iban') ||
        l.startsWith('mersis') ||
        l.startsWith('ticaret sicil') ||
        l.startsWith('ödenecek tutar') ||
        l.startsWith('odenecek tutar') ||
        l.startsWith('genel toplam') ||
        l.startsWith('toplam tutar') ||
        l.startsWith('mal hizmet toplam') ||
        l.startsWith('kdv matrahı') ||
        l.startsWith('kdv matrahi') ||
        l.startsWith('kdv tutarı') ||
        l.startsWith('kdv tutari') ||
        l.startsWith('hesaplanan kdv') ||
        l.startsWith('ara toplam') ||
        l.startsWith('yalnız ') ||
        l.startsWith('yalniz ') ||
        l.startsWith('mal hizmet') ||
        l.startsWith('mal/hizmet') ||
        l.startsWith('sıra no') ||
        l.startsWith('sira no') ||
        l.startsWith('tarih:') ||
        l.startsWith('tarih :');
  }

  static String _extractFirmaAdi(List<String> lines) {
    final musteriRegex = RegExp(
      r'(?:say[ıi]n|m[üu][şs]teri|al[ıi]c[ıi]|firma(?:\s*ad[ıi]?)?)\s*[:.\-]?\s*(.+)',
      caseSensitive: false,
    );
    for (final line in lines) {
      final m = musteriRegex.firstMatch(line);
      if (m != null && m.group(1)!.trim().length > 3) {
        return m.group(1)!.trim();
      }
    }

    for (final line in lines) {
      final l = line.toLowerCase();
      if (l.contains('üniversite') ||
          l.contains('universite') ||
          l.contains('döner sermaye') ||
          l.contains('doner sermaye') ||
          l.contains('t.c.') ||
          l.contains('e-arşiv') ||
          l.contains('e-arsiv') ||
          l.contains('fatura') ||
          l.contains('irsaliye') ||
          l.contains('sayfa') ||
          l.contains('tarih') ||
          l.contains('melbes') ||
          l.contains('numune') ||
          line.length < 3) {
        continue;
      }
      return line;
    }
    return lines.first;
  }

  // --------------------------------------------------------------------------
  // Ortak yardımcılar
  // --------------------------------------------------------------------------

  static FaturaModel _build({
    required String firmaAdi,
    required String adres,
    required String vergiDairesi,
    required String vergiNo,
    required String tarih,
    required List<Map<String, dynamic>> kalemler,
    required double kdvOrani,
    required bool muaf,
    bool kdvDahil = false,
    required String? iban,
    required String? hesapAdi,
    required String fullText,
  }) {
    double matrah = 0;
    for (final k in kalemler) {
      final m = _parseNum(k['miktar'].toString());
      final f = _parseNum(k['fiyat'].toString());
      matrah += (m <= 0 ? 1 : m) * f;
    }

    double genelToplam = 0;
    double kdvTutari = 0;
    if (kdvDahil) {
      genelToplam = matrah;
      if (muaf || kdvOrani <= 0) {
        matrah = genelToplam;
        kdvTutari = 0.0;
        for (final k in kalemler) {
          final m = _parseNum(k['miktar'].toString());
          final safeM = m <= 0 ? 1.0 : m;
          final f = _parseNum(k['fiyat'].toString());
          k['kdvDahilFiyat'] = f;
          k['birimFiyat'] = f;
          k['tutar'] = double.parse((safeM * f).toStringAsFixed(2));
        }
      } else {
        double yeniMatrah = 0.0;
        for (final k in kalemler) {
          final m = _parseNum(k['miktar'].toString());
          final safeM = m <= 0 ? 1.0 : m;
          final brut = _parseNum(k['fiyat'].toString());
          k['kdvDahilFiyat'] = brut;
          final net = double.parse((brut / (1 + (kdvOrani / 100.0))).toStringAsFixed(2));
          k['fiyat'] = net;
          k['birimFiyat'] = net;
          final tutar = double.parse((safeM * net).toStringAsFixed(2));
          k['tutar'] = tutar;
          yeniMatrah += tutar;
        }
        matrah = double.parse(yeniMatrah.toStringAsFixed(2));
        kdvTutari = double.parse((genelToplam - matrah).toStringAsFixed(2));
      }
    } else {
      kdvTutari = muaf ? 0.0 : matrah * (kdvOrani / 100.0);
      genelToplam = matrah + kdvTutari;
    }

    var melbes = _melbesRegex.firstMatch(fullText)?.group(1)?.trim() ?? '';
    var numune = _numuneRegex.firstMatch(fullText)?.group(1)?.trim() ?? '';
    if (numune.isEmpty) {
      final raporMatch = _raporRegex.firstMatch(fullText)?.group(1)?.trim() ?? '';
      if (raporMatch.isNotEmpty) {
        numune = raporMatch.toLowerCase().contains('rapor')
            ? raporMatch
            : 'Rapor No: $raporMatch';
      }
    }
    if (melbes.isNotEmpty && !melbes.toLowerCase().contains('melbes')) {
      melbes = 'Melbes No: $melbes';
    }
    if (numune.isNotEmpty &&
        !numune.toLowerCase().contains('numune') &&
        !numune.toLowerCase().contains('rapor')) {
      numune = 'Numune No: $numune';
    }

    final irsaliyeTarihi = _irsaliyeTarihRegex.firstMatch(fullText)?.group(1)?.trim() ?? '';
    var melbesKurumOnEki = _melbesKurumOnEkiFromText(fullText);
    if (melbesKurumOnEki.isEmpty && melbes.isNotEmpty) {
      melbesKurumOnEki = FaturaMatbuConfig.varsayilanMelbesKurumOnEki;
    }
    final aciklama = _numuneAciklama(fullText);

    final kursAdi = _kursAdiRegex.firstMatch(fullText)?.group(1)?.trim();
    final kurNoStr = _kurNoRegex.firstMatch(fullText)?.group(1)?.trim();
    final donem = _donemRegex.firstMatch(fullText)?.group(0)?.trim();

    return FaturaModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      firmaAdi: firmaAdi.trim(),
      adres: adres.trim(),
      vergiDairesi: vergiDairesi.trim(),
      vergiNo: vergiNo.trim(),
      tarih: tarih.trim(),
      irsaliyeTarihi: irsaliyeTarihi.isNotEmpty
          ? _normalizeTarih(irsaliyeTarihi)
          : '',
      irsaliyeNo: '',
      melbesNo: melbes,
      numuneNo: numune,
      melbesKurumOnEki: melbesKurumOnEki,
      numuneAciklamasi: aciklama,
      kalemler: kalemler,
      isKdvMuaf: muaf,
      kdvDahil: kdvDahil,
      matrah: matrah,
      kdvOrani: kdvOrani,
      kdvTutari: kdvTutari,
      genelToplam: genelToplam,
      iban: iban,
      hesapAdi: hesapAdi != null
          ? FaturaMatbuConfig.formatHesapAdiMatbu(
              hesapAdi,
              fallbackVkn: FaturaMatbuConfig.varsayilanIsletmeVkn,
            )
          : null,
      parsedBy: kaynakEtiketi,
      kursAdi: kursAdi,
      kurNo: kurNoStr != null ? int.tryParse(kurNoStr) : null,
      donem: donem,
    );
  }

  /// Metinden kurum/bakanlık adını (ör. Çevre ve Şehircilik Bakanlığı) ayıklar.
  static String _melbesKurumOnEkiFromText(String fullText) {
    // 1) Doğrudan bilinen bakanlık isimlerini ara (en güvenilir)
    final bilinenBakanliklar = [
      RegExp(r'(?:T\.?C\.?\s*)?Çevre[,\s]+Şehircilik\s+ve\s+İklim\s+Değişikliği\s+Bakanlığı', caseSensitive: false),
      RegExp(r'(?:T\.?C\.?\s*)?Çevre\s+ve\s+Şehircilik\s+Bakanlığı', caseSensitive: false),
      RegExp(r'(?:T\.?C\.?\s*)?Tarım\s+ve\s+Orman\s+Bakanlığı', caseSensitive: false),
      RegExp(r'(?:T\.?C\.?\s*)?Sağlık\s+Bakanlığı', caseSensitive: false),
      RegExp(r'(?:T\.?C\.?\s*)?Sanayi\s+ve\s+Teknoloji\s+Bakanlığı', caseSensitive: false),
    ];
    for (final reg in bilinenBakanliklar) {
      final m = reg.firstMatch(fullText);
      if (m != null) {
        return m.group(0)!.trim();
      }
    }

    // 2) MELBES satırında "Melbes" öncesindeki kurum/bakanlık adını ayıkla
    for (final line in fullText.split('\n')) {
      final l = line.trim();
      if (!RegExp(r'melbes', caseSensitive: false).hasMatch(l)) continue;

      final basvuruMatch = RegExp(
        r'^(.*?)\s*melbes\s*(?:ba[şs]vuru)?',
        caseSensitive: false,
      ).firstMatch(l);
      if (basvuruMatch != null) {
        final kurum = basvuruMatch.group(1)!.trim();
        final temizKurum = kurum.replaceAll(RegExp(r'^[\|\s\-,]+|[\|\s\-,]+$'), '').trim();
        if (temizKurum.isNotEmpty && temizKurum.length > 3) return temizKurum;
      }

      final melbesMatch = RegExp(r'melbes', caseSensitive: false).firstMatch(l);
      if (melbesMatch != null && melbesMatch.start > 0) {
        final kurum = l.substring(0, melbesMatch.start).trim();
        final temizKurum = kurum.replaceAll(RegExp(r'^[\|\s\-,]+|[\|\s\-,]+$'), '').trim();
        if (temizKurum.isNotEmpty && temizKurum.length > 3) return temizKurum;
      }
    }
    return '';
  }

  static (String?, String?) _extractIbanHesap(
    List<List<String>> rows,
    String fullText,
  ) {
    for (final row in rows) {
      for (var c = 0; c < row.length; c++) {
        if (_ibanRegex.hasMatch(row[c])) {
          final iban = _normalizeIban(_ibanRegex.firstMatch(row[c])!.group(0)!);
          String? hesap;
          for (var k = c - 1; k >= 0; k--) {
            if (row[k].trim().isNotEmpty &&
                RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(row[k]) &&
                !row[k].toLowerCase().contains('iban') &&
                !row[k].toLowerCase().contains('birim')) {
              hesap = row[k].trim();
              break;
            }
          }
          return (iban, hesap);
        }
      }
    }
    final m = _ibanRegex.firstMatch(fullText);
    return (m == null ? null : _normalizeIban(m.group(0)!), null);
  }

  static int _colIndex(List<String> header, List<String> aliases) {
    for (var i = 0; i < header.length; i++) {
      final h = header[i].toLowerCase();
      if (aliases.any((a) => h.contains(a))) return i;
    }
    return -1;
  }

  static List<String>? _firstNonEmptyAfter(
    List<List<String>> rows,
    int headerRow,
    List<int> cols,
  ) {
    for (var i = headerRow + 1; i < rows.length && i <= headerRow + 3; i++) {
      final row = rows[i];
      final dolu = cols.any((c) => c >= 0 && _cell(row, c).isNotEmpty);
      if (dolu) return row;
    }
    return null;
  }

  static String _cell(List<String> row, int index) {
    if (index < 0 || index >= row.length) return '';
    return row[index].trim();
  }

  static bool _atlanacakKalem(String cinsi) {
    final c = cinsi.toLowerCase().replaceAll(' ', '');
    if (c.isEmpty) return true;
    if (c == '0') return true;
    if (c.contains('akrediteparametre')) return true;
    if (c.contains('üçüncüsatir') || c.contains('ucuncusatir')) return true;
    if (c.startsWith('*')) return true;
    if (c.contains('melbes')) return true;
    return false;
  }

  static String _cleanVergiD(String s) {
    final t = s.trim();
    if (t == '0' || t == '0.0') return '';
    return t;
  }

  static String _ilkTarih(String text) {
    final m = _tarihRegex.firstMatch(text);
    return m == null ? '' : _normalizeTarih(m.group(0)!);
  }

  static String _normalizeTarih(String s) {
    final m = _tarihRegex.firstMatch(s.trim());
    if (m == null) return s.trim();
    var gun = m.group(1)!;
    var ay = m.group(2)!;
    var yil = m.group(3)!;
    // Excel kaynaklı M/D/YY formatını GG.AA.YYYY'ye çevir
    if (yil.length == 2) yil = '20$yil';
    // Eğer gün > 12 ise zaten gün/ay doğru; değilse Excel ay/gün sırası olabilir.
    final g = int.tryParse(gun) ?? 0;
    final a = int.tryParse(ay) ?? 0;
    if (g <= 12 && a <= 12) {
      // M/D/YY varsayımı (Excel) -> ay=gun, gun=ay
      final tmp = gun;
      gun = ay;
      ay = tmp;
    }
    return '${gun.padLeft(2, '0')}.${ay.padLeft(2, '0')}.$yil';
  }

  static String _normalizeIban(String s) {
    final temiz = s.replaceAll(RegExp(r'\s'), '').toUpperCase();
    final buf = StringBuffer();
    for (var i = 0; i < temiz.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(temiz[i]);
    }
    return buf.toString();
  }

  static String _numuneAciklama(String text) {
    for (final line in text.split('\n')) {
      final l = line.replaceAll('|', ' ').trim();
      if (l.toLowerCase().contains('melbes') &&
          l.toLowerCase().contains('numune')) {
        return l;
      }
    }
    return '';
  }

  /// Türkçe ve ABD biçimli sayıları güvenli şekilde double'a çevirir.
  /// Örnekler: "16,445.00", "1.234,56", "218.18", "16445", "29,090.91 TL"
  static double _parseNum(String input) {
    var s = input.replaceAll(RegExp(r'[^0-9,.\-]'), '').trim();
    if (s.isEmpty) return 0;

    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');

    if (lastComma >= 0 && lastDot >= 0) {
      if (lastComma > lastDot) {
        s = s.replaceAll('.', '').replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else if (lastComma >= 0) {
      final after = s.length - lastComma - 1;
      s = after == 2 ? s.replaceAll(',', '.') : s.replaceAll(',', '');
    } else if (lastDot >= 0) {
      final after = s.length - lastDot - 1;
      if (after == 3 && s.indexOf('.') == lastDot) {
        s = s.replaceAll('.', '');
      }
    }
    return double.tryParse(s) ?? 0;
  }

  // --------------------------------------------------------------------------
  // Birim Talep PDF Formu (eski dsys/ motorundan taşındı)
  // --------------------------------------------------------------------------

  /// Birim talep PDF'leri üst yazı + tablo yapısındadır.
  /// Üst yazıyı atlar, MELBES/Numune bloklarını veya tekil birim talep tablosunu bulur.
  static List<FaturaModel>? _parseBirimTalepFormu(String text) {
    final lower = text.toLowerCase();

    // Talep formu ipuçları: Resmi fatura talep yazısı, melbes, numune no veya fatura düzenlenmesi talebi
    final hasTalepIpucu = RegExp(
      r'(fatura\s*talep|faturan[ıi]n\s*d[üu]zenlenmesi|fatura\s*d[üu]zenlenmesi|melbes|numune\s*no)',
      caseSensitive: false,
    ).hasMatch(text);

    // e-Arşiv / e-Fatura veya ETTN içeren belgeler birim talep formu değildir
    if (lower.contains('e-arşiv') || lower.contains('e-arsiv') || lower.contains('ettn')) {
      return null;
    }

    if (!hasTalepIpucu) return null;

    // Üst yazıyı atla
    final temizMetin = _ustYaziyiAtla(text);

    // MELBES bloklarına ayır (varsa çoklu fatura, yoksa tekil fatura)
    final melbesRegex = RegExp(
      r'melbes\s*ba[şsŞS]vuru\s*no\s*[:\-]?\s*([a-zA-Z0-9\-/]+)',
      caseSensitive: false,
      unicode: true,
    );
    final melbesMatches = melbesRegex.allMatches(temizMetin).toList();

    final bloklar = <String>[];
    if (melbesMatches.isEmpty) {
      bloklar.add(temizMetin);
    } else {
      for (var i = 0; i < melbesMatches.length; i++) {
        final start = melbesMatches[i].start;
        final end = (i + 1 < melbesMatches.length)
            ? melbesMatches[i + 1].start
            : temizMetin.length;
        bloklar.add(temizMetin.substring(start, end));
      }
    }

    final sonuclar = <FaturaModel>[];
    for (final blok in bloklar) {
      final numuneNo =
          RegExp(r'numune\s*no\s*[:\-]?\s*([a-zA-Z0-9\-/]+)', caseSensitive: false)
              .firstMatch(blok)
              ?.group(1)
              ?.trim() ?? '';

      final firma = _extractFirmaFromBlock(blok);
      final kalemler = _extractKalemlerFromBlock(blok);

      final toplamMatch = RegExp(
        r'(?:toplam\s*fiyat|toplam\s*tutar|genel\s*toplam|ödenecek\s*tutar)[^\d]*([\d\.]+,\d{2})',
        caseSensitive: false,
      ).firstMatch(blok);
      final toplam = toplamMatch != null
          ? _parseNum(toplamMatch.group(1)!)
          : kalemler.fold<double>(0, (acc, k) => acc + (_parseNum(k['fiyat'].toString()) * _parseNum(k['miktar'].toString())));

      // Asgari geçerlilik: firma adı olmalı VEYA (kalemler / toplam tutar olmalı)
      if (firma.isEmpty && kalemler.isEmpty && toplam <= 0) continue;

      final defaultCinsi = numuneNo.isNotEmpty
          ? 'Numune analizi'
          : (firma.isNotEmpty ? 'Hizmet Bedeli' : 'Fatura Bedeli');

      final blokSatirlari = blok.split('\n');
      final adres = _extractAdres(blokSatirlari, firma);
      final vdMatch = RegExp(
        r'(?:vergi\s*dairesi|v\.d\.|vd)\s*[:\-]?\s*([a-zA-ZçğıöşüÇĞİÖŞÜ\s]+)',
        caseSensitive: false,
      ).firstMatch(blok);
      final vergiDairesi = vdMatch?.group(1)?.split(RegExp(r'[\n\r,]')).first.trim() ?? '';
      final vknMatch = RegExp(
        r'(?:vergi\s*no|vkn|tc(?:\s*no)?)\s*[:\-]?\s*(\d{10,11})',
        caseSensitive: false,
      ).firstMatch(blok);
      final vergiNo = vknMatch?.group(1)?.trim() ?? '';

      final fatura = _build(
        firmaAdi: firma,
        adres: adres,
        vergiDairesi: vergiDairesi,
        vergiNo: vergiNo,
        tarih: _ilkTarih(blok),
        kalemler: kalemler.isEmpty
            ? [{'cinsi': defaultCinsi, 'miktar': 1, 'fiyat': toplam}]
            : kalemler,
        kdvOrani: 20,
        muaf: lower.contains('muaf'),
        iban: _ibanRegex.firstMatch(blok) != null
            ? _normalizeIban(_ibanRegex.firstMatch(blok)!.group(0)!)
            : null,
        hesapAdi: null,
        fullText: blok,
      );
      fatura.parsedBy = 'Birim Talep Formu';
      sonuclar.add(fatura);
    }

    return sonuclar.isEmpty ? null : sonuclar;
  }

  /// Üst yazı / sunum bölümünü atlayıp veri tablosuna yaklaşır.
  static String _ustYaziyiAtla(String metin) {
    final satirlar = metin.split('\n');
    if (satirlar.isEmpty) return metin;

    final veriBaslangicRegex = RegExp(
      r'(numune\s*no|melbes|başvuru\s*no|basvuru\s*no|firma|unvan|hizmet|analiz|tahlil|kalem|miktar|birim\s*fiyat|toplam|kdv)',
      caseSensitive: false,
    );

    var baslangic = -1;
    for (var i = 0; i < satirlar.length; i++) {
      if (veriBaslangicRegex.hasMatch(satirlar[i])) {
        baslangic = i;
        break;
      }
    }

    if (baslangic <= 0) return metin;
    final from = baslangic > 2 ? baslangic - 2 : 0;
    return satirlar.sublist(from).join('\n').trim();
  }

  /// Bir bloktan firma unvanını çıkarır (A.Ş., Ltd. Şti. vb. ipuçlarıyla).
  static String _extractFirmaFromBlock(String blok) {
    final satirlar = blok
        .split('\n')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // 1. Öncelik: "Firma:", "Firma Adı:", "Sayın:" gibi açık etiketler
    final musteriRegex = RegExp(
      r'^(?:say[ıi]n|m[üu][şsŞS]teri|firma(?:\s*ad[ıi]?)?)\s*[:\-.]?\s*(.+)$',
      caseSensitive: false,
      unicode: true,
    );
    for (final satir in satirlar) {
      final m = musteriRegex.firstMatch(satir);
      if (m != null && m.group(1)!.trim().length > 3) {
        return m.group(1)!.trim();
      }
    }

    // 2. Öncelik: Kurumsal şirket unvanı içeren satırlar (A.Ş., Ltd. Şti.)
    final firmaRegex = RegExp(
      r'(ltd\.?\s*[şsŞS]ti\.?|a\.?\s*[şsŞS]\.?|anonim|san\.?|tic\.?|limited)',
      caseSensitive: false,
      unicode: true,
    );

    for (var i = 0; i < satirlar.length; i++) {
      if (firmaRegex.hasMatch(satirlar[i])) {
        final next = (i + 1 < satirlar.length && satirlar[i + 1].length < 80 && !satirlar[i + 1].contains(':'))
            ? ' ${satirlar[i + 1]}'
            : '';
        return '${satirlar[i]}$next'.trim();
      }
    }

    return '';
  }

  /// Bir bloktan kalem satırlarını çıkarır: "Açıklama  Adet  Fiyat" formatı.
  static List<Map<String, dynamic>> _extractKalemlerFromBlock(String blok) {
    final satirlar = blok.split('\n');
    final kalemler = <Map<String, dynamic>>[];
    final kalemRegex = RegExp(
      r'^(.*?)\s+\*?\s*(\d+)\s+(?:\p{Sc}|TL|₺|EUR|\$)?\s*([\d\.]+,\d{2})\s*(?:TL|₺|EUR|\$)?\s*$',
      caseSensitive: false,
      unicode: true,
    );

    for (final hamSatir in satirlar) {
      final satir = hamSatir.trim();
      if (satir.isEmpty) continue;
      final match = kalemRegex.firstMatch(satir);
      if (match == null) continue;

      final aciklama = (match.group(1) ?? '').trim();
      final adet = int.tryParse((match.group(2) ?? '1').trim()) ?? 1;
      final fiyatStr = (match.group(3) ?? '').trim();
      final birimFiyat = _parseNum(fiyatStr);
      if (aciklama.isEmpty || birimFiyat <= 0) continue;
      kalemler.add({
        'cinsi': aciklama,
        'miktar': adet,
        'fiyat': birimFiyat * adet,
      });
    }

    return kalemler;
  }

  // --------------------------------------------------------------------------
  // e-Arşiv / e-Fatura GİB Standart Metin Katmanı
  // --------------------------------------------------------------------------

  /// GİB e-Arşiv PDF'lerinin metin katmanında standart etiketler bulunur.
  /// Bu parser bu etiketleri tanır ve yapısal veri çıkarır.
  static FaturaModel? _parseEArsivMetni(String text) {
    final lower = text.toLowerCase();

    // e-Arşiv / e-Fatura ipuçları
    final isEArsiv = lower.contains('e-arşiv') ||
        lower.contains('e-arsiv') ||
        lower.contains('e-fatura') ||
        lower.contains('efatura') ||
        (lower.contains('fatura') && lower.contains('ettn'));

    if (!isEArsiv) return null;

    // Standart GİB etiketlerinden veri çek
    final odenecek = RegExp(
      r'(?:[öo]denecek\s*tutar|toplam\s*tutar|genel\s*toplam)\s*[:\-]?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final matrahMatch = RegExp(
      r'(?:mal\s*hizmet\s*toplam\s*tutar[ıi]?|matrah|vergiye\s*tabi\s*tutar)\s*[:\-]?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(text);
    final kdvMatch = RegExp(
      r'(?:hesaplanan\s*kdv|toplam\s*kdv|kdv\s*tutar[ıi]|kdv)\s*(?:\([^)]*\))?\s*[:\-]?\s*([\d.,]+)',
      caseSensitive: false,
    ).firstMatch(text);

    final genelToplam = odenecek != null ? _parseNum(odenecek.group(1)!) : 0.0;
    final matrah = matrahMatch != null ? _parseNum(matrahMatch.group(1)!) : 0.0;
    final kdvTutari = kdvMatch != null ? _parseNum(kdvMatch.group(1)!) : 0.0;

    if (genelToplam <= 0 && matrah <= 0) return null;

    // Müşteri bilgileri
    final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    final firmaAdi = _extractFirmaAdi(lines);
    final adres = _extractAdres(lines, firmaAdi);

    final vergiNo = _extractVkn(text);
    final vdMatch = RegExp(
      r'(?:vergi\s*dairesi|v\.d\.)\s*[:\.\-]?\s*([A-Za-zÇĞİÖŞÜçğıöşü\s]+?)(?:[\n,]|vkn|vergi|$)',
      caseSensitive: false,
    ).firstMatch(text);

    // KDV oranını hesapla
    double kdvOrani = 20.0;
    if (matrah > 0 && kdvTutari > 0) {
      kdvOrani = (kdvTutari / matrah * 100).roundToDouble();
    } else {
      final oranMatch = RegExp(r'%\s*(\d{1,2})|kdv\s*oran[ıi]\s*[:.\-]?\s*%?\s*(\d{1,2})', caseSensitive: false).firstMatch(text);
      if (oranMatch != null) {
        kdvOrani = double.tryParse(oranMatch.group(1) ?? oranMatch.group(2) ?? '') ?? 20.0;
      }
    }

    final effectiveMatrah = matrah > 0
        ? matrah
        : (genelToplam > 0 ? genelToplam / (1 + kdvOrani / 100) : 0.0);

    final kalemler = _extractEArsivKalemleri(text, effectiveMatrah);

    return _build(
      firmaAdi: firmaAdi,
      adres: adres,
      vergiDairesi: vdMatch?.group(1)?.trim() ?? '',
      vergiNo: vergiNo,
      tarih: _ilkTarih(text),
      kalemler: kalemler,
      kdvOrani: kdvOrani,
      muaf: lower.contains('muaf'),
      iban: _ibanRegex.firstMatch(text) != null
          ? _normalizeIban(_ibanRegex.firstMatch(text)!.group(0)!)
          : null,
      hesapAdi: null,
      fullText: text,
    );
  }

  static List<Map<String, dynamic>> _extractEArsivKalemleri(String text, double fallbackTutar) {
    final lines = text.split('\n');
    final kalemler = <Map<String, dynamic>>[];

    for (final rawLine in lines) {
      final parsed = _parseKalemSatiri(rawLine);
      if (parsed != null) {
        kalemler.add(parsed);
      }
    }

    if (kalemler.isNotEmpty) return kalemler;

    if (fallbackTutar > 0) {
      return [
        {
          'cinsi': 'Fatura Bedeli',
          'miktar': 1,
          'birimFiyat': fallbackTutar,
          'fiyat': fallbackTutar,
          'tutar': fallbackTutar,
        }
      ];
    }

    return [];
  }

  // --------------------------------------------------------------------------
  // VKN / TCKN Akıllı Çıkarıcı & Algoritmik Doğrulama
  // --------------------------------------------------------------------------

  /// Metinden VKN veya TCKN tespit eder:
  /// 1. 'vergi no', 'vkn', 't.c. kimlik', 'satıcı vkn' gibi etiketlerin yanındaki sayıları alır
  /// 2. Boşluklu yazılmış olabilecek VKN'leri temizler (örn: '619 126 8620' -> '6191268620')
  /// 3. Doğrulanmış VKN (MOD 10) veya TCKN kontrolü yapar
  static String _extractVkn(String text) {
    // 1. Etiketli arama (boşluklu sayılar dahil)
    final labelRegex = RegExp(
      r'(?:vergi\s*(?:kimlik\s*)?no(?:su)?|vkn|t\.c\.?\s*(?:kimlik\s*)?(?:no)?|sat[ıi]c[ıi]\s*vkn|y[üu]klenici\s*vkn|d[üu]zenleyen\s*vkn)\s*[:.\-]?\s*([0-9\s]{10,15})\b',
      caseSensitive: false,
    );
    final match = labelRegex.firstMatch(text);
    if (match != null) {
      final clean = match.group(1)!.replaceAll(RegExp(r'\s+'), '');
      if (clean.length == 10 || clean.length == 11) {
        return clean;
      }
    }

    // 2. Etiketsiz 10 haneli adaylar arasında MOD 10 VKN sağlayan ilk sayıyı bul
    final tenDigitMatches = RegExp(r'\b\d{10}\b').allMatches(text);
    for (final m in tenDigitMatches) {
      final candidate = m.group(0)!;
      if (_isValidVkn(candidate)) {
        return candidate;
      }
    }

    // 3. Etiketsiz 11 haneli TCKN adayları
    final elevenDigitMatches = RegExp(r'\b[1-9]\d{10}\b').allMatches(text);
    for (final m in elevenDigitMatches) {
      final candidate = m.group(0)!;
      if (_isValidTckn(candidate)) {
        return candidate;
      }
    }

    // 4. Standart yedek regex
    final fallback = RegExp(
      r'(?:vergi\s*no|vkn|t\.c\.?\s*kimlik|tc\s*no)\s*[:.\-]?\s*(\d{10,11})\b',
      caseSensitive: false,
    ).firstMatch(text);
    return fallback?.group(1)?.trim() ?? '';
  }

  /// Resmi GİB Vergi Kimlik Numarası (VKN) MOD 10 algoritması
  static bool _isValidVkn(String vkn) {
    if (vkn.length != 10 || !RegExp(r'^\d{10}$').hasMatch(vkn)) return false;
    if (vkn.split('').toSet().length == 1) return false;
    int sum = 0;
    for (int i = 0; i < 9; i++) {
      int c = int.parse(vkn[i]);
      int v1 = (c + 10 - (i + 1)) % 10;
      if (v1 == 9) {
        sum += 9;
      } else if (v1 != 0) {
        int v2 = (v1 * (1 << (9 - i))) % 9;
        if (v2 == 0) v2 = 9;
        sum += v2;
      }
    }
    int lastDigit = (10 - (sum % 10)) % 10;
    return lastDigit == int.parse(vkn[9]);
  }

  /// T.C. Kimlik Numarası (TCKN) algoritması
  static bool _isValidTckn(String tckn) {
    if (tckn.length != 11 || !RegExp(r'^[1-9]\d{10}$').hasMatch(tckn)) return false;
    List<int> digits = tckn.split('').map(int.parse).toList();
    int tekToplam = digits[0] + digits[2] + digits[4] + digits[6] + digits[8];
    int ciftToplam = digits[1] + digits[3] + digits[5] + digits[7];
    int d10 = ((tekToplam * 7) - ciftToplam) % 10;
    if (d10 < 0) d10 += 10;
    if (d10 != digits[9]) return false;
    int sum10 = 0;
    for (int i = 0; i < 10; i++) {
      sum10 += digits[i];
    }
    return (sum10 % 10) == digits[10];
  }
}
