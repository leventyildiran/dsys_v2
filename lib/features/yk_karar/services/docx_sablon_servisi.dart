import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/models/sablon_model.dart';
import '../models/yk_karar_model.dart';
import 'docx_ooxml_util.dart';
import 'yk_karar_eslestirme_servisi.dart';
import 'yk_tablo_kolon_haritasi.dart';

/// Birim başına tek Word dosyasındaki bölümlerden skor tabanlı eşleştirme.
/// Tablo OOXML'i birebir korunur.
class DocxSablonServisi {
  final Map<String, List<DocxSection>> _cache = {};

  /// Bu skorun altında eşleşme "düşük güven" sayılır.
  static const int minGuvenSkoru = 12;

  bool isDocxSablon(SablonModel? sablon) =>
      sablon != null &&
      (sablon.dosyaUzantisi == '.docx' || sablon.dosyaUzantisi == '.doc');

  Future<List<DocxSection>> bolumleriYukle(SablonModel sablon, {required bool gundem}) async {
    final cacheKey = '${sablon.id}_${gundem ? 'g' : 'k'}';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey]!;

    final bytes = await _docxIndir(sablon);
    final documentXml = _documentXmlOku(bytes);
    final bodyInner = DocxOoxmlUtil.extractBodyInner(documentXml);
    if (bodyInner == null) return [];

    final blocks = DocxOoxmlUtil.extractBodyBlocks(bodyInner);
    final sections = gundem
        ? DocxOoxmlUtil.splitGundemSections(blocks)
        : DocxOoxmlUtil.splitKararSections(blocks);

    _cache[cacheKey] = sections;
    return sections;
  }

  /// Tüm bölümleri PDF'e göre skorlar (yüksekten düşüğe).
  Future<List<SkorluBolum>> bolumleriSkorla({
    required SablonModel sablon,
    required String pdfText,
    required YkKararTuru tur,
    bool gundem = false,
  }) async {
    final sections = await bolumleriYukle(sablon, gundem: gundem);
    if (sections.isEmpty) return [];

    final tablolar = YkKararEslestirmeServisi.tabloVerileriCikar(pdfText);
    final pdfLower = pdfText.toLowerCase();
    final pdfKelimeSet = _onemliKelimeler(pdfLower).toSet();
    final pdfKolonSayisi = tablolar.isNotEmpty ? tablolar.first.keys.length : 0;

    final skorlular = <SkorluBolum>[];
    for (final section in sections) {
      final skor = _bolumSkoru(
        section: section,
        tur: tur,
        pdfKelimeSet: pdfKelimeSet,
        pdfTabloSatir: tablolar.length,
        pdfKolonSayisi: pdfKolonSayisi,
      );
      skorlular.add(SkorluBolum(
        section: section,
        skor: skor,
        tur: _bolumTurunuTespit(section.plainText),
      ));
    }

    skorlular.sort((a, b) => b.skor.compareTo(a.skor));
    return skorlular;
  }

  /// PDF metnine en uygun bölümü bulur.
  Future<DocxEslesmeSonucu?> enIyiBolumuBul({
    required SablonModel sablon,
    required String pdfText,
    required YkKararTuru tur,
    bool gundem = false,
  }) async {
    final skorlular = await bolumleriSkorla(
      sablon: sablon,
      pdfText: pdfText,
      tur: tur,
      gundem: gundem,
    );
    if (skorlular.isEmpty) return null;

    final enIyi = skorlular.first;
    if (enIyi.skor < minGuvenSkoru) {
      debugPrint('[DocxSablon] Düşük güven skoru (${enIyi.skor}), eşleşme atlanıyor');
      return null;
    }

    var bodyXml = enIyi.section.bodyXml;
    final tablolar = YkKararEslestirmeServisi.tabloVerileriCikar(pdfText);
    final tabloSonuc = DocxOoxmlUtil.adaptSectionFromPdfWithReport(
      bodyXml,
      pdfText,
      tablolar,
      tur: tur,
    );
    bodyXml = tabloSonuc.bodyXml;

    return DocxEslesmeSonucu(
      baslik: enIyi.section.baslik,
      plainText: DocxOoxmlUtil.bodyXmlToDisplayText(bodyXml),
      docxBodyXml: bodyXml,
      tabloSayisi: enIyi.section.tableCount,
      guvenSkoru: enIyi.skor,
      tur: enIyi.tur,
      tabloDoldurma: tabloSonuc,
    );
  }

  /// AI prompt'u için: 1 ana şablon + en fazla 1 yardımcı (aynı tür, yüksek skor).
  Future<List<SkorluBolum>> aiIcinOrnekleriSec({
    required SablonModel sablon,
    required String pdfText,
    required YkKararTuru tur,
    bool gundem = false,
  }) async {
    final skorlular = await bolumleriSkorla(
      sablon: sablon,
      pdfText: pdfText,
      tur: tur,
      gundem: gundem,
    );
    if (skorlular.isEmpty) return [];

    final ana = skorlular.first;
    if (ana.skor < minGuvenSkoru) return [];

    final secilen = <SkorluBolum>[ana];

    // Yardımcı: aynı tür, skoru ana şablonun en az %70'i, en fazla 1 adet
    for (final aday in skorlular.skip(1)) {
      if (secilen.length >= 2) break;
      if (aday.section.baslik == ana.section.baslik) continue;
      if (aday.skor < (ana.skor * 0.7).round()) break;
      if (aday.tur != ana.tur) continue;
      secilen.add(aday);
    }

    return secilen;
  }

  int _bolumSkoru({
    required DocxSection section,
    required YkKararTuru tur,
    required Set<String> pdfKelimeSet,
    required int pdfTabloSatir,
    required int pdfKolonSayisi,
  }) {
    var score = 0;
    final sectionLower = section.plainText.toLowerCase();
    final bolumTur = _bolumTurunuTespit(section.plainText);

    // Karar türü eşleşmesi (en kritik sinyal)
    if (bolumTur == tur) score += 25;
    else if (_turEslesir(tur, sectionLower)) score += 12;

    // Tablo varlığı
    if (pdfTabloSatir > 0 && section.tableCount > 0) score += 10;

    // Tablo satır sayısı yakınlığı
    if (pdfTabloSatir > 0 && section.tableCount > 0) {
      final tabloSatirlari = _tabloSatirSayisi(section);
      final satirFark = (pdfTabloSatir - tabloSatirlari).abs();
      if (satirFark == 0) score += 15;
      else if (satirFark <= 2) score += 10;
      else if (satirFark <= 5) score += 5;
    }

    // Tablo kolon sayısı yakınlığı
    if (pdfKolonSayisi > 0 && section.tableCount > 0) {
      final kolonSayisi = _tabloKolonSayisi(section);
      final kolonFark = (pdfKolonSayisi - kolonSayisi).abs();
      if (kolonFark == 0) score += 12;
      else if (kolonFark <= 1) score += 6;
    }

    // Anahtar kelime kesişimi
    final bolumKelimeler = _onemliKelimeler(sectionLower).toSet();
    final kesisim = pdfKelimeSet.intersection(bolumKelimeler).length;
    score += (kesisim * 3).clamp(0, 24);

    return score;
  }

  int _tabloSatirSayisi(DocxSection section) {
    var toplam = 0;
    for (final block in section.blocks.where((b) => b.type == 'w:tbl')) {
      toplam += RegExp(r'<w:tr[ >/]').allMatches(block.xml).length;
    }
    return toplam > 0 ? toplam - section.tableCount : 0; // başlık satırını çıkar
  }

  int _tabloKolonSayisi(DocxSection section) {
    for (final block in section.blocks.where((b) => b.type == 'w:tbl')) {
      final firstRow = RegExp(r'<w:tr\b[^>]*>[\s\S]*?</w:tr>').firstMatch(block.xml);
      if (firstRow != null) {
        return RegExp(r'<w:tc[ >/]').allMatches(firstRow.group(0)!).length;
      }
    }
    return 0;
  }

  YkKararTuru _bolumTurunuTespit(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('danışman') || lower.contains('danisman') || lower.contains('görevlendirme')) {
      return YkKararTuru.danismanlik;
    }
    if (lower.contains('bütçe aktar') || lower.contains('butce aktar') || lower.contains('ödenek aktar')) {
      return YkKararTuru.butceAktarim;
    }
    if (lower.contains('diş hekim') || lower.contains('dis hekim') || lower.contains('ek ödeme')) {
      return YkKararTuru.disHekimligi;
    }
    if (lower.contains('kurs ücret') ||
        lower.contains('kurs ucret') ||
        lower.contains('katkı pay') ||
        lower.contains('katki pay') ||
        lower.contains('faaliyet cetvel') ||
        lower.contains('gelir getirici')) {
      return YkKararTuru.kursUcreti;
    }
    if (lower.contains('fiyat tarif')) return YkKararTuru.fiyatTarifesi;
    if (lower.contains('mal sat') || lower.contains('ürün sat')) return YkKararTuru.malSatis;
    if (lower.contains('2547') || lower.contains('sanayi işbirli')) return YkKararTuru.sanayiIsbirligi;
    return YkKararTuru.diger;
  }

  Future<Uint8List> _docxIndir(SablonModel sablon) async {
    if (sablon.dosyaUrl.startsWith('http')) {
      final response = await http.get(Uri.parse(sablon.dosyaUrl));
      if (response.statusCode != 200) {
        throw Exception('Şablon indirilemedi: ${response.statusCode}');
      }
      return response.bodyBytes;
    }
    throw Exception('Geçersiz şablon URL');
  }

  String _documentXmlOku(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final docFile = archive.files.firstWhere(
      (f) => f.name == 'word/document.xml',
      orElse: () => throw Exception('word/document.xml bulunamadı'),
    );
    return utf8.decode(docFile.content as List<int>, allowMalformed: true);
  }

  bool _turEslesir(YkKararTuru tur, String sectionLower) {
    switch (tur) {
      case YkKararTuru.danismanlik:
        return sectionLower.contains('danışman') || sectionLower.contains('danisman');
      case YkKararTuru.butceAktarim:
        return sectionLower.contains('bütçe aktar') || sectionLower.contains('butce aktar');
      case YkKararTuru.disHekimligi:
        return sectionLower.contains('diş hekim') || sectionLower.contains('ek ödeme');
      case YkKararTuru.kursUcreti:
        return sectionLower.contains('kurs ücret') ||
            sectionLower.contains('katkı pay') ||
            sectionLower.contains('faaliyet cetvel') ||
            sectionLower.contains('gelir getirici');
      case YkKararTuru.fiyatTarifesi:
        return sectionLower.contains('fiyat tarif');
      case YkKararTuru.malSatis:
        return sectionLower.contains('mal sat') || sectionLower.contains('ürün sat');
      default:
        return false;
    }
  }

  List<String> _onemliKelimeler(String text) {
    const stop = {'üniversite', 'müdürlüğü', 'müdürlüğünün', 'yazısı', 'yazısına', 'istinaden', 'karar', 'verilmiştir'};
    return text
        .replaceAll(RegExp(r'[^\wğüşıöçâîû\s]', caseSensitive: false), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 4 && !stop.contains(w))
        .toList();
  }
}

class SkorluBolum {
  const SkorluBolum({
    required this.section,
    required this.skor,
    required this.tur,
  });

  final DocxSection section;
  final int skor;
  final YkKararTuru tur;
}

class DocxEslesmeSonucu {
  const DocxEslesmeSonucu({
    required this.baslik,
    required this.plainText,
    required this.docxBodyXml,
    required this.tabloSayisi,
    required this.guvenSkoru,
    required this.tur,
    this.tabloDoldurma,
  });

  final String baslik;
  final String plainText;
  final String docxBodyXml;
  final int tabloSayisi;
  final int guvenSkoru;
  final YkKararTuru tur;
  final TabloDoldurmaSonucu? tabloDoldurma;

  bool get yuksekGuven => guvenSkoru >= DocxSablonServisi.minGuvenSkoru + 15;
}
