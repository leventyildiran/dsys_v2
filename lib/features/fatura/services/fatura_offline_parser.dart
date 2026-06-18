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
  static final RegExp _irsaliyeTarihRegex = RegExp(
    r'irsaliye\s*tarih(?:i)?\s*[:.\-]?\s*(\d{1,2}[./]\d{1,2}[./]\d{2,4})',
    caseSensitive: false,
  );
  static final RegExp _tarihRegex = RegExp(
    r'\b(\d{1,2})[./](\d{1,2})[./](\d{2,4})\b',
  );
  static final RegExp _yaziylaRegex = RegExp(r'#\s*(.+?)\s*#');
  
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

    // 3) Serbest metin / sayfa işareti olmayan döküm
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
  // Serbest metin ayrıştırma
  // --------------------------------------------------------------------------

  static FaturaModel? _parseFreeText(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.replaceAll('|', ' ').trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (lines.isEmpty) return null;

    String firmaAdi = lines.first;
    final kalemler = <Map<String, dynamic>>[];
    final kalemRegex = RegExp(
      r'^(.+?)[\s|]+([\d.,]+)\s*(?:TL|₺)',
      caseSensitive: false,
    );

    for (final line in lines.skip(1)) {
      final m = kalemRegex.firstMatch(line);
      if (m != null) {
        final cinsi = m.group(1)!.trim();
        final tutar = _parseNum(m.group(2)!);
        if (cinsi.isNotEmpty && tutar > 0 && !_atlanacakKalem(cinsi)) {
          kalemler.add({'cinsi': cinsi, 'miktar': 1, 'fiyat': tutar});
        }
      }
    }

    if (kalemler.isEmpty) return null;

    final ibanMatch = _ibanRegex.firstMatch(text);
    return _build(
      firmaAdi: firmaAdi,
      adres: '',
      vergiDairesi: '',
      vergiNo: '',
      tarih: _ilkTarih(text),
      kalemler: kalemler,
      kdvOrani: 20,
      muaf: text.toLowerCase().contains('muaf'),
      iban: ibanMatch == null ? null : _normalizeIban(ibanMatch.group(0)!),
      hesapAdi: null,
      fullText: text,
    );
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
    final kdvTutari = muaf ? 0.0 : matrah * (kdvOrani / 100.0);

    final melbes = _melbesRegex.firstMatch(fullText)?.group(1)?.trim() ?? '';
    final numune = _numuneRegex.firstMatch(fullText)?.group(1)?.trim() ?? '';
    final irsaliyeTarihi = _irsaliyeTarihRegex.firstMatch(fullText)?.group(1)?.trim() ?? '';
    final melbesKurumOnEki = _melbesKurumOnEkiFromText(fullText);

    final yaziyla = _yaziylaRegex.firstMatch(fullText)?.group(1)?.trim() ?? '';
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
      numuneAciklamasi: aciklama.isNotEmpty ? aciklama : yaziyla,
      kalemler: kalemler,
      isKdvMuaf: muaf,
      matrah: matrah,
      kdvOrani: kdvOrani,
      kdvTutari: kdvTutari,
      genelToplam: matrah + kdvTutari,
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

  /// MELBES satırında "Melbes Başvuru" öncesindeki kurum/bakanlık adını ayıklar.
  static String _melbesKurumOnEkiFromText(String fullText) {
    for (final line in fullText.split('\n')) {
      final l = line.trim();
      if (!RegExp(r'melbes', caseSensitive: false).hasMatch(l)) continue;

      final basvuruMatch = RegExp(
        r'^(.*?)\s*melbes\s*ba[şs]vuru',
        caseSensitive: false,
      ).firstMatch(l);
      if (basvuruMatch != null) {
        final kurum = basvuruMatch.group(1)!.trim();
        if (kurum.isNotEmpty) return kurum;
      }

      final melbesMatch = RegExp(r'melbes', caseSensitive: false).firstMatch(l);
      if (melbesMatch != null && melbesMatch.start > 0) {
        final kurum = l.substring(0, melbesMatch.start).trim();
        if (kurum.isNotEmpty) return kurum;
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
}
