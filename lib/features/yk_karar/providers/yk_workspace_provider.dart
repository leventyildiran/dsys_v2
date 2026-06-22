import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../core/services/sablon_service.dart';
import '../../../core/models/sablon_model.dart';
import '../../birim/services/birim_service.dart';
import '../../birim/models/birim_model.dart';
import '../models/yk_karar_model.dart';
import '../models/gundem_model.dart';
import '../services/gundem_parser_service.dart';
import '../services/yk_karar_service.dart';
import '../services/docx_sablon_servisi.dart';
import '../services/belge_uretim_servisi.dart';
import '../services/pdf_kalite_servisi.dart';
import '../services/docx_ooxml_util.dart';
import 'gundem_provider.dart';

enum ViewMode { karar, gundem }

class YkWorkspaceProvider extends ChangeNotifier {
  static const anaKararEditorId = '__yk_ana_karar__';

  final BirimService _birimService = BirimService();
  final GundemParserService _parserService = GundemParserService();
  final SablonService _sablonService = SablonService();
  final DocxSablonServisi _docxSablon = DocxSablonServisi();
  final YkKararService _kararService = YkKararService();

  List<BirimModel> birimler = [];
  List<SablonModel> sablonlar = [];
  bool isLoading = true;

  ViewMode viewMode = ViewMode.karar;

  final Map<String, Uint8List> uploadedPdfs = {};
  final Map<String, bool> isAnalyzingMap = {};
  final Map<String, YkKararModel> analyzedKararlar = {};
  final Map<String, List<String>> analizUyarilari = {};
  final Map<String, int?> eslesmeSkorlari = {};
  final Map<String, PdfKaliteSonucu?> pdfKaliteRaporlari = {};

  final Map<String, quill.QuillController> quillControllers = {};
  final Map<String, quill.QuillController> gundemQuillControllers = {};

  String? seciliBirimId;
  String? seciliKararId;
  List<YkKararModel> toplantiKararlari = [];
  String? yukluToplantiId;
  bool toplantiYukleniyor = false;
  final Map<String, String> kayitliKararIdleri = {};
  final Map<String, SablonModel> seciliKararSablonlari = {};
  final Map<String, SablonModel> seciliGundemSablonlari = {};
  
  bool sidebarDar = true;

  YkWorkspaceProvider() {
    _loadInitialData();
  }

  void toggleSidebar() {
    sidebarDar = !sidebarDar;
    notifyListeners();
  }

  void setViewMode(ViewMode mode) {
    viewMode = mode;
    notifyListeners();
  }

  Future<void> _loadInitialData() async {
    try {
      final birimStream = _birimService.stream(onlyActive: false);
      final birimList = await birimStream.first;
      final sablonList = await _sablonService.getAllSablonlar();
      final ykSablonlar = sablonList
          .where((s) =>
              (s.tur == 'yk_karar' || s.tur == 'gundem') &&
              (s.dosyaUzantisi == '.docx' || s.dosyaUzantisi == '.doc' || s.dosyaUzantisi == '.txt'))
          .toList();

      birimler = birimList;
      sablonlar = ykSablonlar;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      debugPrint('Veriler yüklenirken hata: $e');
    }
  }

  List<SablonModel> sablonlarForCurrentMode(String birimId) {
    final tur = viewMode == ViewMode.karar ? 'yk_karar' : 'gundem';
    final birimAd = birimler.where((b) => b.id == birimId).map((b) => b.ad).firstOrNull;
    bool birimEslesir(SablonModel s) => s.birimId == birimId || (birimAd != null && s.birimAd == birimAd);

    final birimeOzel = sablonlar.where((s) => s.tur == tur && birimEslesir(s)).toList();
    if (birimeOzel.isNotEmpty) return birimeOzel;

    return sablonlar.where((s) => s.tur == tur && s.birimId == null && s.birimAd == null).toList();
  }

  SablonModel? findPreferredSablon(String tur, String birimId) {
    int oncelik(SablonModel s) {
      if (s.dosyaUzantisi == '.docx' || s.dosyaUzantisi == '.doc') return 0;
      if (s.dosyaUzantisi == '.txt') return 1;
      return 2;
    }
    final birimAd = birimler.where((b) => b.id == birimId).map((b) => b.ad).firstOrNull;
    final exactMatches = sablonlar.where((s) => s.tur == tur && s.birimId == birimId).toList()..sort((a, b) => oncelik(a).compareTo(oncelik(b)));
    if (exactMatches.isNotEmpty) return exactMatches.first;
    if (birimAd != null) {
      final adMatches = sablonlar.where((s) => s.tur == tur && s.birimAd == birimAd).toList()..sort((a, b) => oncelik(a).compareTo(oncelik(b)));
      if (adMatches.isNotEmpty) return adMatches.first;
    }
    final commonMatches = sablonlar.where((s) => s.tur == tur && s.birimId == null && s.birimAd == null).toList()..sort((a, b) => oncelik(a).compareTo(oncelik(b)));
    if (commonMatches.isNotEmpty) return commonMatches.first;
    return null;
  }

  Future<String?> analizEtBirim(String birimId) async {
    final pdfBytes = uploadedPdfs[birimId];
    if (pdfBytes == null) return 'Lütfen önce PDF yükleyin.';

    isAnalyzingMap[birimId] = true;
    notifyListeners();

    try {
      final birim = birimler.firstWhere((b) => b.id == birimId);
      final gecmisKararlar = await _kararService.kararGetByBirim(birimId: birimId, birimAd: birim.ad);

      final sonuc = await _parserService.analizEtVeKararUret(
        pdfBytes: pdfBytes,
        birimAd: birim.ad,
        birimId: birimId,
        birimeOzelSablonlar: sablonlarForCurrentMode(birimId),
        gecmisKararlar: gecmisKararlar,
        kararSablon: seciliKararSablonlari[birimId] ?? findPreferredSablon('yk_karar', birimId),
      );

      analyzedKararlar[birimId] = sonuc.karar;
      analizUyarilari[birimId] = sonuc.uyarilar;
      eslesmeSkorlari[birimId] = sonuc.eslesmeSkoru;
      pdfKaliteRaporlari[birimId] = sonuc.pdfKalite;
      
      _applyAnalyzedKararToEditor(birimId, sonuc.karar);
      await _olusturGundemTaslagi(birimId, sonuc.karar);

      isAnalyzingMap[birimId] = false;
      notifyListeners();
      return null; 
    } catch (e) {
      isAnalyzingMap[birimId] = false;
      notifyListeners();
      return e.toString();
    }
  }

  void _applyAnalyzedKararToEditor(String birimId, YkKararModel karar) {
    final buffer = StringBuffer();
    if (karar.docxBodyXml != null && karar.docxBodyXml!.isNotEmpty) {
      final blocks = DocxOoxmlUtil.extractBodyBlocks(karar.docxBodyXml!);
      final metin = DocxOoxmlUtil.blocksToPlainText(blocks);
      buffer.writeln(metin.isNotEmpty ? metin : karar.kararMetni.trim());
    } else {
      buffer.writeln(karar.kararMetni.trim());
    }
    quillControllers[birimId] = quillFromMetin(buffer.toString());
  }

  Future<void> _olusturGundemTaslagi(String birimId, YkKararModel karar) async {
    final gundemSablon = seciliGundemSablonlari[birimId] ?? findPreferredSablon('gundem', birimId);
    if (gundemSablon == null) return;

    String gundemMetni;
    if (_docxSablon.isDocxSablon(gundemSablon)) {
      final eslesme = await _docxSablon.enIyiBolumuBul(
        sablon: gundemSablon,
        pdfText: karar.kararMetni,
        tur: karar.tur,
        gundem: true,
      );
      gundemMetni = eslesme?.plainText ?? 'Gündem: ${karar.baslik}';
    } else {
      gundemMetni = 'Gündem: ${karar.baslik}\n\n${karar.kararMetni.length > 500 ? karar.kararMetni.substring(0, 500) : karar.kararMetni}';
    }
    gundemQuillControllers[birimId] = quillFromMetin(gundemMetni.trim());
  }

  Future<bool> persistKararTaslak(String birimId, ToplantiModel toplanti) async {
    final birim = birimler.firstWhere((b) => b.id == birimId);
    final controller = quillControllers[birimId];
    if (controller == null) return false;

    final deltaJson = jsonEncode(controller.document.toDelta().toJson());
    final existingKarar = analyzedKararlar[birimId];
    final existingId = kayitliKararIdleri[birimId];

    var docxBodyXml = existingKarar?.docxBodyXml;
    if (docxBodyXml != null && docxBodyXml.isNotEmpty) {
      docxBodyXml = DocxOoxmlUtil.mergeParagraphsIntoBodyXml(docxBodyXml, controller.document.toPlainText());
    }

    final kararNo = existingKarar?.kararNo ?? await _kararService.sonrakiKararNoUret(toplanti.toplantiNo);

    final karar = YkKararModel(
      id: existingId ?? '',
      toplantiId: toplanti.id,
      toplantiNo: toplanti.toplantiNo,
      kararNo: kararNo,
      kararTarihi: toplanti.toplantiTarihi,
      birimId: birim.id,
      birimAd: birim.ad,
      tur: existingKarar?.tur ?? YkKararTuru.diger,
      baslik: existingKarar?.baslik ?? '${birim.ad} Kararı',
      kararMetni: deltaJson,
      durum: YkKararDurum.taslak,
      docxBodyXml: docxBodyXml,
    );

    try {
      final isNew = existingId == null;
      if (isNew) {
        final newId = await _kararService.kararCreate(karar);
        kayitliKararIdleri[birimId] = newId;
      } else {
        await _kararService.kararUpdate(karar.id, karar.toMap());
      }
      return true;
    } catch (e) {
      debugPrint('Karar kaydetme hatası: $e');
      return false;
    }
  }

  quill.QuillController quillFromMetin(String metin) {
    return quill.QuillController(
      document: quill.Document()..insert(0, metin),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  void temizleCalismaAlani() {
    for (final c in quillControllers.values) c.dispose();
    for (final c in gundemQuillControllers.values) c.dispose();
    quillControllers.clear();
    gundemQuillControllers.clear();
    uploadedPdfs.clear();
    analyzedKararlar.clear();
    kayitliKararIdleri.clear();
    seciliBirimId = null;
    notifyListeners();
  }
}
