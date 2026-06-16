import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../../../core/models/sablon_model.dart';
import '../models/yk_karar_model.dart';
import 'docx_sablon_servisi.dart';
import 'pdf_kalite_servisi.dart';
import 'yk_tablo_kolon_haritasi.dart';

/// AI ve internet olmadan PDF + geçmiş karar + şablon ile eşleştirme.
class YkKararEslestirmeServisi {
  final DocxSablonServisi _docxSablon = DocxSablonServisi();

  /// PDF metnini geçmiş kararlar ve birim Word arşivi ile eşleştirip YK karar taslağı üretir.
  Future<KararAnalizSonucu> eslestirVeKararUret({
    required String pdfText,
    required String birimAd,
    required String birimId,
    required List<YkKararModel> gecmisKararlar,
    SablonModel? kararSablon,
  }) async {
    final tur = _turTespitEt(pdfText);
    final tablolar = tabloVerileriCikar(pdfText);
    final enIyiEslesme = _enIyiGecmisKarariBul(
      gecmisKararlar,
      birimId: birimId,
      birimAd: birimAd,
      tur: tur,
      tabloSatirSayisi: tablolar.length,
    );

    String kararMetni;
    String baslik;
    String? docxBodyXml;
    DocxEslesmeSonucu? docxEslesme;
    final uyarilar = <String>[];

    // Öncelik: geçmiş kararın OOXML'i → birim Word arşivinden bölüm → düz metin
    if (enIyiEslesme?.docxBodyXml != null && enIyiEslesme!.docxBodyXml!.isNotEmpty) {
      docxBodyXml = enIyiEslesme.docxBodyXml;
      kararMetni = _gecmisFormataUyarla(
        gecmisMetin: _kararMetniDuzMetin(enIyiEslesme),
        pdfText: pdfText,
        tablolar: tablolar.isNotEmpty ? tablolar : enIyiEslesme.tabloVerileri,
      );
      baslik = enIyiEslesme.baslik.isNotEmpty
          ? enIyiEslesme.baslik
          : _baslikCikar(pdfText, birimAd);
    } else if (kararSablon != null && _docxSablon.isDocxSablon(kararSablon)) {
      docxEslesme = await _docxSablon.enIyiBolumuBul(
        sablon: kararSablon,
        pdfText: pdfText,
        tur: tur,
        gundem: false,
      );
      if (docxEslesme != null) {
        docxBodyXml = docxEslesme.docxBodyXml;
        kararMetni = docxEslesme.plainText;
        baslik = docxEslesme.baslik;
        uyarilar.addAll(docxEslesme.tabloDoldurma?.uyarilar ?? []);
      } else {
        uyarilar.add('Word arşivinde güvenilir eşleşme bulunamadı (skor < ${DocxSablonServisi.minGuvenSkoru})');
        kararMetni = _pdfdenTemelKararMetni(pdfText, tablolar);
        baslik = _baslikCikar(pdfText, birimAd);
      }
    } else if (enIyiEslesme != null) {
      kararMetni = _gecmisFormataUyarla(
        gecmisMetin: _kararMetniDuzMetin(enIyiEslesme),
        pdfText: pdfText,
        tablolar: tablolar.isNotEmpty ? tablolar : enIyiEslesme.tabloVerileri,
      );
      baslik = enIyiEslesme.baslik.isNotEmpty
          ? enIyiEslesme.baslik
          : _baslikCikar(pdfText, birimAd);
    } else if (kararSablon != null) {
      kararMetni = _sablondanVePdfdenUret(kararSablon, pdfText, tablolar);
      baslik = _baslikCikar(pdfText, birimAd);
    } else {
      kararMetni = _pdfdenTemelKararMetni(pdfText, tablolar);
      baslik = _baslikCikar(pdfText, birimAd);
    }

    final karar = YkKararModel(
      id: '',
      toplantiId: '',
      toplantiNo: '',
      kararNo: '',
      baslik: baslik,
      kararMetni: kararMetni,
      birimAd: birimAd,
      birimId: birimId,
      iliskiliKayitId: enIyiEslesme?.id ?? '',
      kararTarihi: DateTime.now().toIso8601String().split('T')[0],
      tur: tur,
      durum: YkKararDurum.taslak,
      olusturmaTarihi: DateTime.now(),
      tabloVerileri: tablolar,
      sablonTuru: enIyiEslesme?.sablonTuru,
      docxBodyXml: docxBodyXml,
      eslesmeSkoru: docxEslesme?.guvenSkoru,
      analizKaynagi: KararAnalizKaynagi.otomatikEslestirme.name,
      analizUyarilari: uyarilar,
    );

    return KararAnalizSonucu(
      karar: karar,
      kaynak: KararAnalizKaynagi.otomatikEslestirme,
      uyarilar: uyarilar,
      eslesmeSkoru: docxEslesme?.guvenSkoru,
      tabloDoldurma: docxEslesme?.tabloDoldurma,
    );
  }

  /// PDF metninden yapısal tablo satırları çıkarır.
  static List<Map<String, dynamic>> tabloVerileriCikar(String pdfText) {
    final lines = pdfText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return [];

    final tableBlocks = <List<List<String>>>[];
    List<List<String>>? currentBlock;

    for (final line in lines) {
      final cells = _satirdanHucreler(line);
      if (cells.length >= 2) {
        currentBlock ??= [];
        currentBlock.add(cells);
      } else if (currentBlock != null && currentBlock.length >= 2) {
        tableBlocks.add(currentBlock);
        currentBlock = null;
      } else {
        currentBlock = null;
      }
    }
    if (currentBlock != null && currentBlock.length >= 2) {
      tableBlocks.add(currentBlock);
    }

    if (tableBlocks.isEmpty) return [];

    // En geniş tablo bloğunu al
    tableBlocks.sort((a, b) => b.length.compareTo(a.length));
    final block = tableBlocks.first;
    if (block.length < 2) return [];

    final header = block.first;
    final rows = <Map<String, dynamic>>[];

    for (var i = 1; i < block.length; i++) {
      final rowCells = block[i];
      if (_ayiriciSatirMi(rowCells.join(' '))) continue;

      final row = <String, dynamic>{};
      for (var c = 0; c < header.length; c++) {
        final key = _hucreBasligi(header[c], c);
        row[key] = c < rowCells.length ? rowCells[c] : '';
      }
      if (row.values.any((v) => v.toString().trim().isNotEmpty)) {
        rows.add(row);
      }
    }
    return rows;
  }

  static String tabloMarkdown(List<Map<String, dynamic>> tablolar) {
    if (tablolar.isEmpty) return '';
    final columns = tablolar.first.keys.toList();
    final buffer = StringBuffer();
    buffer.writeln('| ${columns.join(' | ')} |');
    buffer.writeln('| ${columns.map((_) => '---').join(' | ')} |');
    for (final row in tablolar) {
      buffer.writeln('| ${columns.map((c) => row[c]?.toString() ?? '').join(' | ')} |');
    }
    return buffer.toString();
  }

  static String _kararMetniDuzMetin(YkKararModel karar) {
    try {
      final decoded = jsonDecode(karar.kararMetni);
      if (decoded is List) {
        return quill.Document.fromJson(decoded).toPlainText();
      }
    } catch (_) {}
    return karar.kararMetni;
  }

  YkKararModel? _enIyiGecmisKarariBul(
    List<YkKararModel> gecmisKararlar, {
    required String birimId,
    required String birimAd,
    required YkKararTuru tur,
    required int tabloSatirSayisi,
  }) {
    if (gecmisKararlar.isEmpty) return null;

    YkKararModel? best;
    var bestScore = -1;

    for (final karar in gecmisKararlar) {
      var score = 0;
      if (birimId.isNotEmpty && karar.birimId == birimId) score += 20;
      if (_birimAdEslesir(karar.birimAd, birimAd)) score += 10;
      if (karar.tur == tur) score += 15;
      if (tabloSatirSayisi > 0 && karar.tabloVerileri.isNotEmpty) score += 8;
      if (karar.tabloVerileri.isNotEmpty && tabloSatirSayisi > 0) {
        final kolonFark = (karar.tabloVerileri.first.keys.length - tabloSatirSayisi).abs();
        if (kolonFark <= 2) score += 5;
      }
      if (karar.kararMetni.trim().isNotEmpty) score += 3;

      if (score > bestScore) {
        bestScore = score;
        best = karar;
      }
    }

    return bestScore >= 10 ? best : null;
  }

  bool _birimAdEslesir(String a, String b) {
    final na = a.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    final nb = b.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    return na.isNotEmpty && (na.contains(nb) || nb.contains(na));
  }

  YkKararTuru _turTespitEt(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('danışmanlık') || lower.contains('danismanlik') || lower.contains('görevlendirme')) {
      return YkKararTuru.danismanlik;
    }
    if (lower.contains('bütçe aktar') || lower.contains('butce aktar')) {
      return YkKararTuru.butceAktarim;
    }
    if (lower.contains('diş hekim') || lower.contains('dis hekim') || lower.contains('ek ödeme')) {
      return YkKararTuru.disHekimligi;
    }
    if (lower.contains('kurs ücret') || lower.contains('kurs ucret')) {
      return YkKararTuru.kursUcreti;
    }
    if (lower.contains('fiyat tarif')) {
      return YkKararTuru.fiyatTarifesi;
    }
    if (lower.contains('mal sat') || lower.contains('ürün sat')) {
      return YkKararTuru.malSatis;
    }
    return YkKararTuru.diger;
  }

  String _gecmisFormataUyarla({
    required String gecmisMetin,
    required String pdfText,
    required List<Map<String, dynamic>> tablolar,
  }) {
    var metin = gecmisMetin;

    final eskiTarihler = _tarihleriBul(metin);
    final yeniTarihler = _tarihleriBul(pdfText);
    for (var i = 0; i < eskiTarihler.length && i < yeniTarihler.length; i++) {
      metin = metin.replaceFirst(eskiTarihler[i], yeniTarihler[i]);
    }

    final eskiTutarlar = _tutarlariBul(metin);
    final yeniTutarlar = _tutarlariBul(pdfText);
    for (var i = 0; i < eskiTutarlar.length && i < yeniTutarlar.length; i++) {
      metin = metin.replaceFirst(eskiTutarlar[i], yeniTutarlar[i]);
    }

    final eskiEvrak = _evrakNumaralariBul(metin);
    final yeniEvrak = _evrakNumaralariBul(pdfText);
    for (var i = 0; i < eskiEvrak.length && i < yeniEvrak.length; i++) {
      metin = metin.replaceFirst(eskiEvrak[i], yeniEvrak[i]);
    }

    if (tablolar.isNotEmpty) {
      metin = _tabloBolumunuGuncelle(metin, tablolar);
    }

    return metin.trim();
  }

  String _sablondanVePdfdenUret(
    SablonModel sablon,
    String pdfText,
    List<Map<String, dynamic>> tablolar,
  ) {
    final buffer = StringBuffer();
    try {
      final doc = quill.Document.fromJson(jsonDecode(sablon.dosyaUrl));
      buffer.writeln(doc.toPlainText().trim());
      buffer.writeln();
    } catch (e) {
      debugPrint('[Eslestirme] Şablon okunamadı: $e');
    }

    buffer.writeln(_pdfdenTemelKararMetni(pdfText, const []));
    if (tablolar.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(tabloMarkdown(tablolar));
    }
    return buffer.toString().trim();
  }

  String _pdfdenTemelKararMetni(String pdfText, List<Map<String, dynamic>> tablolar) {
    final lines = pdfText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty && !_ayiriciSatirMi(l))
        .toList();

    final paragraflar = <String>[];
    final buffer = StringBuffer();

    for (final line in lines) {
      final cells = _satirdanHucreler(line);
      if (cells.length >= 3) {
        if (buffer.isNotEmpty) {
          paragraflar.add(buffer.toString().trim());
          buffer.clear();
        }
        continue;
      }
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(line);
    }
    if (buffer.isNotEmpty) paragraflar.add(buffer.toString().trim());

    return paragraflar.take(5).join('\n\n');
  }

  String _tabloBolumunuGuncelle(String metin, List<Map<String, dynamic>> tablolar) {
    final markdown = tabloMarkdown(tablolar);
    final pipeIndex = metin.indexOf('|');
    if (pipeIndex != -1) {
      final before = metin.substring(0, pipeIndex).trimRight();
      return '$before\n\n$markdown';
    }
    return '$metin\n\n$markdown';
  }

  String _baslikCikar(String pdfText, String birimAd) {
    final lines = pdfText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    for (final line in lines) {
      if (line.length > 8 && line.length < 120 && !_ayiriciSatirMi(line)) {
        return line;
      }
    }
    return '$birimAd Kararı';
  }

  static List<String> _tarihleriBul(String text) =>
      RegExp(r'\d{2}[./]\d{2}[./]\d{4}').allMatches(text).map((m) => m.group(0)!).toList();

  static List<String> _tutarlariBul(String text) =>
      RegExp(r'[\d.,]+\s*(?:TL|₺)', caseSensitive: false)
          .allMatches(text)
          .map((m) => m.group(0)!.trim())
          .toList();

  static List<String> _evrakNumaralariBul(String text) =>
      RegExp(r'E-\d[\d-]+', caseSensitive: false)
          .allMatches(text)
          .map((m) => m.group(0)!)
          .toList();

  static List<String> _satirdanHucreler(String line) {
    if (line.contains('\t')) {
      return line.split('\t').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
    }
    if (line.contains('|')) {
      return line
          .split('|')
          .map((c) => c.trim())
          .where((c) => c.isNotEmpty && !RegExp(r'^[-:]+$').hasMatch(c))
          .toList();
    }
    final parts = line.split(RegExp(r'\s{2,}'));
    if (parts.length >= 2) {
      return parts.map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
    }
    return [];
  }

  static bool _ayiriciSatirMi(String line) =>
      RegExp(r'^[-─=_\s|]+$').hasMatch(line) || line.length < 3;

  static String _hucreBasligi(String raw, int index) {
    final cleaned = raw.trim();
    if (cleaned.isEmpty) return 'sutun_${index + 1}';
    return cleaned
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9ğüşıöçâîû ]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), '_');
  }
}

/// Analiz sonucu kaynağı: AI veya otomatik eşleştirme.
enum KararAnalizKaynagi { yapayZeka, otomatikEslestirme }

class KararAnalizSonucu {
  const KararAnalizSonucu({
    required this.karar,
    required this.kaynak,
    this.uyarilar = const [],
    this.pdfKalite,
    this.eslesmeSkoru,
    this.tabloDoldurma,
  });

  final YkKararModel karar;
  final KararAnalizKaynagi kaynak;
  final List<String> uyarilar;
  final PdfKaliteSonucu? pdfKalite;
  final int? eslesmeSkoru;
  final TabloDoldurmaSonucu? tabloDoldurma;
}
