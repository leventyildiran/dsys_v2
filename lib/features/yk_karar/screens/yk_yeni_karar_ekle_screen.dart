import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../core/theme/app_theme.dart';
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
import '../services/yk_karar_butunluk_servisi.dart';
import '../services/yk_karar_eslestirme_servisi.dart';
import '../providers/gundem_provider.dart';

class YkYeniKararEkleScreen extends StatefulWidget {
  const YkYeniKararEkleScreen({super.key});

  @override
  State<YkYeniKararEkleScreen> createState() => _YkYeniKararEkleScreenState();
}

enum _ViewMode { karar, gundem }

class _YkYeniKararEkleScreenState extends State<YkYeniKararEkleScreen> {
  static const _anaKararEditorId = '__yk_ana_karar__';
  final BirimService _birimService = BirimService();
  final GundemParserService _parserService = GundemParserService();
  final SablonService _sablonService = SablonService();
  final DocxSablonServisi _docxSablon = DocxSablonServisi();

  List<BirimModel> _birimler = [];
  List<SablonModel> _sablonlar = [];
  bool _isLoading = true;

  // KARAR / GÜNDEM toggle
  _ViewMode _viewMode = _ViewMode.karar;

  // Her birim için durumları takip edeceğimiz haritalar
  final Map<String, Uint8List> _uploadedPdfs = {};
  final Map<String, bool> _isAnalyzingMap = {};
  final Map<String, YkKararModel> _analyzedKararlar = {};
  final Map<String, List<String>> _analizUyarilari = {};
  final Map<String, int?> _eslesmeSkorlari = {};
  final Map<String, PdfKaliteSonucu?> _pdfKaliteRaporlari = {};

  // Her birim için Quill Controller tutmalıyız ki aralarında geçiş yapabilelim
  final Map<String, quill.QuillController> _quillControllers = {};

  // Gündem modu için ayrı Quill Controller
  final Map<String, quill.QuillController> _gundemQuillControllers = {};

  // Çalışma alanı için state
  String? _seciliBirimId;
  String? _seciliKararId;
  List<YkKararModel> _toplantiKararlari = [];
  String? _yukluToplantiId;
  bool _toplantiYukleniyor = false;
  final Map<String, String> _kayitliKararIdleri = {};
  final Map<String, SablonModel> _seciliKararSablonlari = {};
  final Map<String, SablonModel> _seciliGundemSablonlari = {};
  bool _sidebarDar = true;
  bool _tabloPanelAcik = false;

  @override
  void dispose() {
    _temizleCalismaAlani();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gundem = context.read<GundemProvider>();
      await gundem.toplantilariYukle();
      await gundem.aktifToplantiyiYukle();
      if (!mounted) return;
      final toplanti = gundem.seciliToplanti;
      if (toplanti != null) {
        await _toplantiCalismasiniYukle(toplanti.id);
      }
    });
  }

  Future<void> _loadInitialData() async {
    try {
      // Birimleri ve Şablonları yükle
      final birimStream = _birimService.stream(onlyActive: false);
      final birimList = await birimStream.first;

      final sablonList = await _sablonService.getAllSablonlar();
      // YK karar/gündem: Word arşivi (.docx) + metin şablonları (.txt)
      final ykSablonlar = sablonList
          .where(
            (s) =>
                (s.tur == 'yk_karar' || s.tur == 'gundem') &&
                (s.dosyaUzantisi == '.docx' ||
                    s.dosyaUzantisi == '.doc' ||
                    s.dosyaUzantisi == '.txt'),
          )
          .toList();

      setState(() {
        _birimler = birimList;
        _sablonlar = ykSablonlar;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      debugPrint('Veriler yüklenirken hata: $e');
    }
  }

  String _kararSecimEtiketi(YkKararModel karar) {
    final no = karar.kararNo.trim().isNotEmpty ? karar.kararNo : '—';
    final baslik = karar.baslik.trim();
    if (baslik.isNotEmpty) {
      return '$no · ${karar.birimAd} · $baslik';
    }
    return '$no · ${karar.birimAd}';
  }

  Future<void> _anaKarariEditoreAc() async {
    final toplanti = context.read<GundemProvider>().seciliToplanti;
    if (toplanti == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Önce bir Yürütme Kurulu toplantısı seçin.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    var kararlar = _toplantiKararlari;
    if (kararlar.isEmpty) {
      kararlar = await YkKararService().kararGetByToplanti(toplanti.id);
      if (!mounted) return;
      if (kararlar.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Bu toplantıda henüz birim kararı yok. Önce birim şeridinden karar ekleyin.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    final metin = BelgeUretimServisi.anaKararBirlesikMetin(kararlar);
    _quillControllers[_anaKararEditorId]?.dispose();
    _quillControllers[_anaKararEditorId] = _quillFromMetin(metin);

    setState(() {
      _seciliBirimId = _anaKararEditorId;
      _seciliKararId = null;
      _viewMode = _ViewMode.karar;
    });
  }

  void _onBirimSekmesiSec(String birimId) {
    final mevcut = _toplantiKararlari.where((k) => k.birimId == birimId);
    if (mevcut.isNotEmpty) {
      _kararSec(mevcut.first);
      return;
    }
    _yeniKararTaslagiBaslat(birimId);
    final toplanti = context.read<GundemProvider>().seciliToplanti;
    if (toplanti != null) {
      for (final madde in toplanti.gundemMaddeleri) {
        if (madde.birimId == birimId) {
          _gundemMaddesiniEditoreYukle(birimId, madde.aciklama ?? '');
          break;
        }
      }
    }
  }

  void _yeniKararTaslagiBaslat(String birimId) {
    setState(() {
      _seciliKararId = null;
      _seciliBirimId = birimId;
      if (!_quillControllers.containsKey(birimId)) {
        _quillControllers[birimId] = quill.QuillController.basic();
      }
      if (!_gundemQuillControllers.containsKey(birimId)) {
        _gundemQuillControllers[birimId] = quill.QuillController.basic();
      }
      _autoLoadTemplatesForBirim(birimId);
    });
  }

  void _kararSec(YkKararModel karar) {
    setState(() {
      _seciliKararId = karar.id;
      _seciliBirimId = karar.birimId;
      if (!_quillControllers.containsKey(karar.birimId)) {
        _quillControllers[karar.birimId] = quill.QuillController.basic();
      }
      if (!_gundemQuillControllers.containsKey(karar.birimId)) {
        _gundemQuillControllers[karar.birimId] = quill.QuillController.basic();
      }
    });
    _karariEditoreYukle(karar.birimId, karar);
    final toplanti = context.read<GundemProvider>().seciliToplanti;
    if (toplanti != null) {
      for (final madde in toplanti.gundemMaddeleri) {
        if (madde.birimId == karar.birimId) {
          _gundemMaddesiniEditoreYukle(karar.birimId, madde.aciklama ?? '');
          break;
        }
      }
    }
  }

  void _temizleCalismaAlani() {
    for (final c in _quillControllers.values) {
      c.dispose();
    }
    for (final c in _gundemQuillControllers.values) {
      c.dispose();
    }
    _quillControllers.clear();
    _gundemQuillControllers.clear();
    _uploadedPdfs.clear();
    _analyzedKararlar.clear();
    _analizUyarilari.clear();
    _eslesmeSkorlari.clear();
    _pdfKaliteRaporlari.clear();
    _kayitliKararIdleri.clear();
    _seciliBirimId = null;
    _seciliKararId = null;
    _toplantiKararlari = [];
  }

  quill.QuillController _quillFromMetin(String metin) {
    return quill.QuillController(
      document: quill.Document()..insert(0, metin),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  quill.QuillController _quillFromKararMetni(String kararMetni) {
    try {
      final decoded = jsonDecode(kararMetni);
      if (decoded is List) {
        return quill.QuillController(
          document: quill.Document.fromJson(decoded),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } catch (_) {}
    return _quillFromMetin(
      BelgeUretimServisi.kararDuzMetin(
        YkKararModel(
          id: '',
          toplantiId: '',
          toplantiNo: '',
          kararNo: '',
          kararTarihi: '',
          birimId: '',
          birimAd: '',
          tur: YkKararTuru.diger,
          baslik: '',
          kararMetni: kararMetni,
        ),
      ),
    );
  }

  void _karariEditoreYukle(String birimId, YkKararModel karar) {
    _kayitliKararIdleri[birimId] = karar.id;
    _analyzedKararlar[birimId] = karar;
    _analizUyarilari[birimId] = karar.analizUyarilari;
    _eslesmeSkorlari[birimId] = karar.eslesmeSkoru;
    _quillControllers[birimId]?.dispose();
    _quillControllers[birimId] = _quillFromKararMetni(karar.kararMetni);
    _autoLoadTemplatesForBirim(birimId);
  }

  void _gundemMaddesiniEditoreYukle(String birimId, String metin) {
    if (metin.trim().isEmpty) return;
    _gundemQuillControllers[birimId]?.dispose();
    _gundemQuillControllers[birimId] = _quillFromMetin(metin);
  }

  Future<void> _toplantiCalismasiniYukle(String toplantiId) async {
    if (_toplantiYukleniyor) return;
    _toplantiYukleniyor = true;
    try {
      final kararlar = await YkKararService().kararGetByToplanti(toplantiId);
      if (!mounted) return;
      final toplanti = context.read<GundemProvider>().seciliToplanti;

      _temizleCalismaAlani();
      _toplantiKararlari = List<YkKararModel>.from(kararlar)
        ..sort((a, b) {
          final no = a.kararNo.compareTo(b.kararNo);
          if (no != 0) return no;
          return a.birimAd.compareTo(b.birimAd);
        });
      _yukluToplantiId = toplantiId;

      if (mounted) {
        setState(() {});
        if (kararlar.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${toplanti?.toplantiNo ?? 'Toplantı'}: ${kararlar.length} karar listelendi. Düzenlemek için karar seçin.',
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Toplantı çalışması yüklenemedi: $e');
    } finally {
      _toplantiYukleniyor = false;
    }
  }

  List<SablonModel> _sablonlarForCurrentMode(String birimId) {
    final tur = _viewMode == _ViewMode.karar ? 'yk_karar' : 'gundem';
    final birimAd = _birimler
        .where((b) => b.id == birimId)
        .map((b) => b.ad)
        .firstOrNull;

    bool birimEslesir(SablonModel s) =>
        s.birimId == birimId || (birimAd != null && s.birimAd == birimAd);

    // Birim Word arşivi varsa yalnızca onu göster (genel şablon karışıklığı önlenir).
    final birimeOzel = _sablonlar
        .where((s) => s.tur == tur && birimEslesir(s))
        .toList();
    if (birimeOzel.isNotEmpty) return birimeOzel;

    return _sablonlar
        .where((s) => s.tur == tur && s.birimId == null && s.birimAd == null)
        .toList();
  }

  /// PDF eşleştirmede kullanılan birim Word arşivi (.docx) — kullanıcıya gösterilmez.
  SablonModel? _findEslestirmeArsivi(String tur, String birimId) {
    final birimAd = _birimler
        .where((b) => b.id == birimId)
        .map((b) => b.ad)
        .firstOrNull;
    bool birimEslesir(SablonModel s) =>
        s.birimId == birimId || (birimAd != null && s.birimAd == birimAd);

    final docxArsiv = _sablonlar.where((s) {
      if (s.tur != tur) return false;
      if (s.dosyaUzantisi != '.docx' && s.dosyaUzantisi != '.doc') return false;
      return birimEslesir(s);
    }).toList();
    if (docxArsiv.isNotEmpty) return docxArsiv.first;
    return null;
  }

  SablonModel? _findPreferredSablon(String tur, String birimId) {
    int oncelik(SablonModel s) {
      if (s.dosyaUzantisi == '.docx' || s.dosyaUzantisi == '.doc') return 0;
      if (s.dosyaUzantisi == '.txt') return 1;
      return 2;
    }

    final birimAd = _birimler
        .where((b) => b.id == birimId)
        .map((b) => b.ad)
        .firstOrNull;

    final exactMatches =
        _sablonlar.where((s) => s.tur == tur && s.birimId == birimId).toList()
          ..sort((a, b) => oncelik(a).compareTo(oncelik(b)));
    if (exactMatches.isNotEmpty) return exactMatches.first;

    if (birimAd != null) {
      final adMatches =
          _sablonlar.where((s) => s.tur == tur && s.birimAd == birimAd).toList()
            ..sort((a, b) => oncelik(a).compareTo(oncelik(b)));
      if (adMatches.isNotEmpty) return adMatches.first;
    }

    final commonMatches =
        _sablonlar
            .where(
              (s) => s.tur == tur && s.birimId == null && s.birimAd == null,
            )
            .toList()
          ..sort((a, b) => oncelik(a).compareTo(oncelik(b)));
    if (commonMatches.isNotEmpty) return commonMatches.first;

    return null;
  }

  void _autoLoadTemplatesForBirim(String birimId) {
    final kararSablon =
        _findEslestirmeArsivi('yk_karar', birimId) ??
        _findPreferredSablon('yk_karar', birimId);
    final gundemSablon =
        _findEslestirmeArsivi('gundem', birimId) ??
        _findPreferredSablon('gundem', birimId);
    if (kararSablon != null) _seciliKararSablonlari[birimId] = kararSablon;
    if (gundemSablon != null) _seciliGundemSablonlari[birimId] = gundemSablon;

    if (_kayitliKararIdleri.containsKey(birimId)) return;

    if (_isControllerBlank(_quillControllers[birimId])) {
      if (kararSablon != null && kararSablon.dosyaUzantisi == '.txt') {
        _applySablonToEditor(kararSablon, birimId, _ViewMode.karar);
      } else {
        _setBosCalismaAlani(birimId, _ViewMode.karar);
      }
    }
    if (_isControllerBlank(_gundemQuillControllers[birimId])) {
      if (gundemSablon != null && gundemSablon.dosyaUzantisi == '.txt') {
        _applySablonToEditor(gundemSablon, birimId, _ViewMode.gundem);
      } else {
        _setBosCalismaAlani(birimId, _ViewMode.gundem);
      }
    }
  }

  void _setBosCalismaAlani(String birimId, _ViewMode mode) {
    final seciliToplanti = context.read<GundemProvider>().seciliToplanti;
    final toplanti = seciliToplanti != null
        ? 'Toplantı ${seciliToplanti.toplantiNo} (${seciliToplanti.toplantiTarihi})'
        : 'Henüz toplantı seçilmedi';
    final baslik = mode == _ViewMode.karar
        ? 'Bu toplantının YK kararı'
        : 'Bu toplantının gündem maddesi';

    final doc = quill.Document()
      ..insert(
        0,
        '$toplanti\n$baslik\n\n'
        '→ Üst yazı PDF\'sini yükleyin\n'
        '→ «Analiz Et» ile metin buraya dolsun\n'
        '→ Düzenleyip toplantı gündemine kaydedin',
      );
    final controller = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    if (mode == _ViewMode.karar) {
      _quillControllers[birimId] = controller;
    } else {
      _gundemQuillControllers[birimId] = controller;
    }
  }

  bool _isControllerBlank(quill.QuillController? controller) {
    if (controller == null) return true;
    return controller.document.toPlainText().trim().isEmpty;
  }

  void _applySablonToEditor(
    SablonModel sablon,
    String birimId,
    _ViewMode mode,
  ) {
    if (sablon.dosyaUzantisi == '.docx' || sablon.dosyaUzantisi == '.doc') {
      _setBosCalismaAlani(birimId, mode);
      return;
    }

    try {
      final decoded = jsonDecode(sablon.dosyaUrl);
      if (decoded is List) {
        final doc = quill.Document.fromJson(decoded);
        final controller = quill.QuillController(
          document: doc,
          selection: const TextSelection.collapsed(offset: 0),
        );
        if (mode == _ViewMode.karar) {
          _quillControllers[birimId] = controller;
        } else {
          _gundemQuillControllers[birimId] = controller;
        }
      }
    } catch (e) {
      debugPrint('Şablon yükleme hatası: $e');
    }
  }

  Future<void> _pickPdfForBirim(String birimId) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _uploadedPdfs[birimId] = result.files.single.bytes!;
      });
    }
  }

  Future<void> _analizEtBirim(String birimId) async {
    final pdfBytes = _uploadedPdfs[birimId];
    if (pdfBytes == null) return;

    if (_seciliKararSablonlari[birimId] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Karar şablonu bulunamadı. Lütfen Sistem Şablonları veya manuel seçimden YK karar şablonu seçin.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzingMap[birimId] = true;
    });

    try {
      final birim = _birimler.firstWhere((b) => b.id == birimId);
      final gecmisKararlar = await YkKararService().kararGetByBirim(
        birimId: birimId,
        birimAd: birim.ad,
      );

      final sonuc = await _parserService.analizEtVeKararUret(
        pdfBytes: pdfBytes,
        birimAd: birim.ad,
        birimId: birimId,
        birimeOzelSablonlar: _sablonlarForCurrentMode(birimId),
        gecmisKararlar: gecmisKararlar,
        kararSablon: _seciliKararSablonlari[birimId],
      );

      setState(() {
        _analyzedKararlar[birimId] = sonuc.karar;
        _analizUyarilari[birimId] = sonuc.uyarilar;
        _eslesmeSkorlari[birimId] = sonuc.eslesmeSkoru;
        _pdfKaliteRaporlari[birimId] = sonuc.pdfKalite;
        _applyAnalyzedKararToEditor(birimId, sonuc.karar);
        _isAnalyzingMap[birimId] = false;
      });
      await _olusturGundemTaslagi(birimId, sonuc.karar);
      await _persistKararTaslak(birimId, otomatik: true);
      await _persistGundemMadde(birimId, otomatik: true);

      if (mounted) {
        final kaynakMesaji = sonuc.kaynak == KararAnalizKaynagi.yapayZeka
            ? 'Yapay zeka ile analiz tamamlandı.'
            : 'İnternet/AI yok — otomatik eşleştirme ile taslak oluşturuldu.';
        final skorMesaji = sonuc.eslesmeSkoru != null
            ? ' Eşleşme skoru: ${sonuc.eslesmeSkoru}.'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${birim.ad}: $kaynakMesaji$skorMesaji'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        if (sonuc.uyarilar.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Uyarı: ${sonuc.uyarilar.first}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isAnalyzingMap[birimId] = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyAnalyzedKararToEditor(String birimId, YkKararModel karar) {
    final buffer = StringBuffer();

    if (karar.docxBodyXml != null && karar.docxBodyXml!.isNotEmpty) {
      final blocks = DocxOoxmlUtil.extractBodyBlocks(karar.docxBodyXml!);
      final metin = DocxOoxmlUtil.blocksToPlainText(blocks);
      buffer.writeln(metin.isNotEmpty ? metin : karar.kararMetni.trim());
    } else {
      final sablon = _seciliKararSablonlari[birimId];
      if (sablon != null && sablon.dosyaUzantisi == '.txt') {
        try {
          final decoded = jsonDecode(sablon.dosyaUrl);
          if (decoded is List) {
            buffer.writeln(
              quill.Document.fromJson(decoded).toPlainText().trim(),
            );
            buffer.writeln();
          }
        } catch (e) {
          debugPrint('Şablon editöre yüklenemedi: $e');
        }
      }
      buffer.writeln(karar.kararMetni.trim());
    }

    final doc = quill.Document()..insert(0, buffer.toString());
    _quillControllers[birimId] = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  /// Karar analizi sonrası gündem tabına taslak yükler (Word arşivi veya metin).
  Future<void> _olusturGundemTaslagi(String birimId, YkKararModel karar) async {
    final gundemSablon =
        _seciliGundemSablonlari[birimId] ??
        _findPreferredSablon('gundem', birimId);
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
      gundemMetni =
          'Gündem: ${karar.baslik}\n\n${karar.kararMetni.length > 500 ? karar.kararMetni.substring(0, 500) : karar.kararMetni}';
    }

    final doc = quill.Document()..insert(0, gundemMetni.trim());
    _gundemQuillControllers[birimId] = quill.QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    if (mounted) setState(() {});
  }

  void _showYeniToplantiDialog() {
    final toplantiNoController = TextEditingController();
    final tarihController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Yeni Yürütme Kurulu Kararı / Toplantısı',
          style: TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Lütfen ana toplantı bilgilerini giriniz. Ana word dosyası bu bilgilerle oluşturulacaktır.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: toplantiNoController,
              decoration: const InputDecoration(
                labelText: 'Toplantı No (Örn: 2026/05)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: tarihController,
              decoration: const InputDecoration(
                labelText: 'Tarih (gg.aa.yyyy)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              if (toplantiNoController.text.isEmpty ||
                  tarihController.text.isEmpty) {
                return;
              }

              final model = ToplantiModel(
                id: '',
                toplantiTarihi: tarihController.text,
                toplantiNo: toplantiNoController.text,
              );
              final provider = context.read<GundemProvider>();
              final id = await provider.toplantiOlustur(model);
              if (id != null) {
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  await provider.aktifToplantiSec(id);
                  if (mounted) {
                    await _toplantiCalismasiniYukle(id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Yeni toplantı oluşturuldu ve aktif olarak seçildi.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Oluştur ve Seç'),
          ),
        ],
      ),
    );
  }

  Future<void> _toplantiSecVeYukle(String toplantiId) async {
    final provider = context.read<GundemProvider>();
    await provider.aktifToplantiSec(toplantiId);
    if (!mounted) return;
    await _toplantiCalismasiniYukle(toplantiId);
  }

  Future<void> _toplantiKararlariniYenile() async {
    final toplanti = context.read<GundemProvider>().seciliToplanti;
    if (toplanti == null) return;
    try {
      final kararlar = await YkKararService().kararGetByToplanti(toplanti.id);
      if (!mounted) return;
      setState(() {
        _toplantiKararlari = List<YkKararModel>.from(kararlar)
          ..sort((a, b) {
            final no = a.kararNo.compareTo(b.kararNo);
            if (no != 0) return no;
            return a.birimAd.compareTo(b.birimAd);
          });
      });
    } catch (e) {
      debugPrint('Karar listesi yenilenemedi: $e');
    }
  }

  Future<void> _showYeniKararDialog() async {
    final toplanti = context.read<GundemProvider>().seciliToplanti;
    if (toplanti == null) {
      await _showToplantiSeciciDialog();
      return;
    }
    if (_birimler.isEmpty) return;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Karar Taslağı'),
        content: SizedBox(
          width: 520,
          height: 400,
          child: ListView.separated(
            itemCount: _birimler.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final birim = _birimler[index];
              return ListTile(
                leading: const Icon(Icons.apartment_outlined),
                title: Text(birim.ad),
                onTap: () {
                  Navigator.pop(ctx);
                  _yeniKararTaslagiBaslat(birim.id);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _showToplantiSeciciDialog() async {
    final provider = context.read<GundemProvider>();
    if (provider.toplantilar.isEmpty) {
      await provider.toplantilariYukle();
    }
    if (!mounted) return;

    final seciliId = provider.seciliToplanti?.id;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yürütme Kurulu Toplantısını Seç'),
        content: SizedBox(
          width: 560,
          height: 420,
          child: provider.toplantilar.isEmpty
              ? const Center(child: Text('Kayıtlı toplantı bulunamadı.'))
              : ListView.separated(
                  itemCount: provider.toplantilar.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final t = provider.toplantilar[index];
                    final secili = t.id == seciliId;
                    return ListTile(
                      selected: secili,
                      leading: Icon(
                        secili
                            ? Icons.check_circle
                            : Icons.calendar_month_outlined,
                        color: secili ? Colors.green : Colors.blueGrey,
                      ),
                      title: Text(
                        t.toplantiNo,
                        style: TextStyle(
                          fontWeight: secili
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        '${t.toplantiTarihi} • ${t.gundemMaddeleri.length} gündem',
                      ),
                      onTap: () async {
                        await _toplantiSecVeYukle(t.id);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _anaKarariOnizle(ToplantiModel toplanti) async {
    try {
      final kararlar = await YkKararService().kararGetByToplanti(toplanti.id);
      if (kararlar.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bu toplantıya henüz hiçbir birim kararı eklenmemiş. Lütfen önce karar ekleyin.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final rapor = YkKararButunlukServisi().kontrolEt(kararlar);
      if (!rapor.gecerli) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bütünlük hatası: ${rapor.hatalar.join(' ')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (rapor.uyarilar.isNotEmpty && mounted) {
        final devam = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Bütünlük Uyarıları'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rapor.ozet,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...rapor.uyarilar.map(
                    (u) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $u'),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Yine de Oluştur'),
              ),
            ],
          ),
        );
        if (devam != true) return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Ana Karar Word dosyası oluşturuluyor... Lütfen bekleyin.',
            ),
            backgroundColor: Colors.blue,
          ),
        );
      }
      await BelgeUretimServisi.topluKararWordIndir(
        kararlar,
        toplanti.toplantiNo,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Word dosyası oluşturulurken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _gundemMaddeleriniOlustur(ToplantiModel toplanti) async {
    try {
      final kararlar = await YkKararService().kararGetByToplanti(toplanti.id);
      if (kararlar.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Gündem oluşturulacak karar bulunamadı. Lütfen karar ekleyin.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gündem maddeleri oluşturuluyor... Lütfen bekleyin.'),
            backgroundColor: Colors.blue,
          ),
        );
      }

      final mevcutGundemler = toplanti.gundemMaddeleri;

      final gundemMaddeleri = kararlar.asMap().entries.map((entry) {
        final karar = entry.value;
        final mevcutMadde = _mevcutGundemMaddesiniBul(mevcutGundemler, karar);
        return GundemMaddesi(
          siraNo: entry.key + 1,
          baslik: mevcutMadde?.baslik.trim().isNotEmpty == true
              ? mevcutMadde!.baslik
              : karar.baslik,
          tur: mevcutMadde?.tur ?? GundemTuru.fromString(karar.tur.value),
          aciklama: mevcutMadde?.aciklama,
          birimId: karar.birimId,
          birimAd: karar.birimAd,
          iliskiliKayitId: karar.id,
        );
      }).toList();

      if (mounted) {
        await context.read<GundemProvider>().toplantiGundemTopluGuncelle(
          toplanti.id,
          gundemMaddeleri,
        );
      }

      final guncelToplanti = toplanti.copyWith(
        gundemMaddeleri: gundemMaddeleri,
      );
      await BelgeUretimServisi.toplantiGundemWordIndir(guncelToplanti);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gündem şablonu (Davet) başarıyla oluşturuldu ve indirildi!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gündem oluşturulurken hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  GundemMaddesi? _mevcutGundemMaddesiniBul(
    List<GundemMaddesi> maddeler,
    YkKararModel karar,
  ) {
    for (final madde in maddeler) {
      if (madde.iliskiliKayitId != null && madde.iliskiliKayitId == karar.id) {
        return madde;
      }
    }

    for (final madde in maddeler) {
      if (madde.birimId != null &&
          madde.birimId == karar.birimId &&
          karar.birimId.isNotEmpty) {
        return madde;
      }
    }

    for (final madde in maddeler) {
      final maddeBirim = madde.birimAd?.trim().toLowerCase();
      final kararBirim = karar.birimAd.trim().toLowerCase();
      if (maddeBirim != null &&
          maddeBirim.isNotEmpty &&
          kararBirim.isNotEmpty &&
          maddeBirim == kararBirim) {
        return madde;
      }
    }

    return null;
  }

  void _saveKarar(String birimId) => _persistKararTaslak(birimId);

  Future<bool> _persistKararTaslak(
    String birimId, {
    bool otomatik = false,
  }) async {
    final gundemProvider = context.read<GundemProvider>();
    final toplanti = gundemProvider.seciliToplanti;

    if (toplanti == null) {
      if (!otomatik && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lütfen üst menüden aktif bir toplantı seçin veya yeni oluşturun.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    final birim = _birimler.firstWhere((b) => b.id == birimId);
    final controller = _quillControllers[birimId];
    if (controller == null) return false;

    final deltaJson = jsonEncode(controller.document.toDelta().toJson());
    final existingKarar = _analyzedKararlar[birimId];
    final existingId = _kayitliKararIdleri[birimId];

    var docxBodyXml = existingKarar?.docxBodyXml;
    if (docxBodyXml != null && docxBodyXml.isNotEmpty) {
      final plainText = controller.document.toPlainText();
      docxBodyXml = DocxOoxmlUtil.mergeParagraphsIntoBodyXml(
        docxBodyXml,
        plainText,
      );
    }

    final baslik = existingKarar?.baslik ?? '${birim.ad} Kararı';
    final tur = existingKarar?.tur ?? YkKararTuru.diger;

    try {
      final ykKararService = YkKararService();
      final mevcutKararNo = existingKarar?.kararNo;
      final kararNo =
          mevcutKararNo != null &&
              mevcutKararNo.trim().isNotEmpty &&
              mevcutKararNo != 'taslak'
          ? mevcutKararNo
          : await ykKararService.sonrakiKararNoUret(toplanti.toplantiNo);

      final karar = YkKararModel(
        id: existingId ?? '',
        toplantiId: toplanti.id,
        toplantiNo: toplanti.toplantiNo,
        kararNo: kararNo,
        kararTarihi: toplanti.toplantiTarihi,
        birimId: birim.id,
        birimAd: birim.ad,
        tur: tur,
        baslik: baslik,
        kararMetni: deltaJson,
        durum: YkKararDurum.taslak,
        tabloVerileri: existingKarar?.tabloVerileri ?? [],
        docxBodyXml: docxBodyXml,
        eslesmeSkoru: existingKarar?.eslesmeSkoru ?? _eslesmeSkorlari[birimId],
        analizKaynagi: existingKarar?.analizKaynagi,
        analizUyarilari:
            _analizUyarilari[birimId] ??
            existingKarar?.analizUyarilari ??
            const [],
        olusturmaTarihi: existingKarar?.olusturmaTarihi,
      );

      late final String kayitliId;
      if (existingId != null && existingId.isNotEmpty) {
        await ykKararService.kararUpdate(existingId, karar.toMap());
        kayitliId = existingId;
        _analyzedKararlar[birimId] =
            YkKararModel.fromMap(existingId, karar.toMap());
      } else {
        kayitliId = await ykKararService.kararCreate(karar);
        _kayitliKararIdleri[birimId] = kayitliId;
        _analyzedKararlar[birimId] =
            YkKararModel.fromMap(kayitliId, karar.toMap());
      }
      _seciliKararId = kayitliId;
      await _toplantiKararlariniYenile();

      if (mounted) {
        setState(() {});
        if (!otomatik) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${birim.ad} kararı ${karar.kararNo} numarasıyla kaydedildi.',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${birim.ad}: taslak otomatik kaydedildi.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      return true;
    } catch (e) {
      if (mounted && !otomatik) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydetme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  void _saveGundem(String birimId) => _persistGundemMadde(birimId);

  Future<bool> _persistGundemMadde(
    String birimId, {
    bool otomatik = false,
  }) async {
    final gundemProvider = context.read<GundemProvider>();
    final toplanti = gundemProvider.seciliToplanti;

    if (toplanti == null) {
      if (!otomatik && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Lütfen üst menüden aktif bir toplantı seçin veya yeni oluşturun.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    final controller = _gundemQuillControllers[birimId];
    if (controller == null) return false;

    final birim = _birimler.firstWhere((b) => b.id == birimId);
    final plainText = controller.document.toPlainText().trim();

    if (plainText.isEmpty) {
      if (!otomatik && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gündem metni boş. Lütfen gündem maddesini yazın veya şablonu düzenleyin.',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return false;
    }

    final baslik = plainText
        .split('\n')
        .map((line) => line.trim())
        .firstWhere(
          (line) => line.isNotEmpty,
          orElse: () => '${birim.ad} Gündemi',
        );

    final mevcutMaddeler = List<GundemMaddesi>.from(toplanti.gundemMaddeleri);
    final existingIndex = mevcutMaddeler.indexWhere(
      (m) => m.birimId == birimId,
    );
    final kayitliKararId = _kayitliKararIdleri[birimId];
    final analizKararId = _analyzedKararlar[birimId]?.id;
    final iliskiliKayitId = kayitliKararId?.isNotEmpty == true
        ? kayitliKararId
        : analizKararId;
    final madde = GundemMaddesi(
      siraNo: existingIndex >= 0
          ? mevcutMaddeler[existingIndex].siraNo
          : mevcutMaddeler.length + 1,
      baslik: baslik,
      tur: GundemTuru.diger,
      aciklama: plainText,
      birimId: birim.id,
      birimAd: birim.ad,
      iliskiliKayitId: iliskiliKayitId,
    );

    if (existingIndex >= 0) {
      mevcutMaddeler[existingIndex] = madde;
    } else {
      mevcutMaddeler.add(madde);
    }

    try {
      await gundemProvider.toplantiGundemTopluGuncelle(
        toplanti.id,
        mevcutMaddeler,
      );
      await gundemProvider.toplantiYukle(toplanti.id, kaliciKaydet: false);
      if (mounted) {
        if (!otomatik) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${birim.ad} gündem maddesi kaydedildi.'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${birim.ad}: gündem taslağı otomatik kaydedildi.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
      return true;
    } catch (e) {
      if (mounted && !otomatik) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gündem kaydetme hatası: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  Widget _buildKompaktToplantiDropdown(GundemProvider gundem) {
    final toplantilar = gundem.toplantilar;
    final seciliToplanti = gundem.seciliToplanti;
    final toplantiValue = seciliToplanti != null &&
            toplantilar.any((t) => t.id == seciliToplanti.id)
        ? seciliToplanti.id
        : null;

    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white30),
        ),
        child: DropdownButton<String>(
          key: ValueKey('yk_toplanti_dropdown_$toplantiValue'),
          value: toplantiValue,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          dropdownColor: const Color(0xFF1E3A8A),
          style: const TextStyle(color: Colors.white, fontSize: 13),
          hint: Text(
            toplantilar.isEmpty ? 'Yükleniyor...' : 'Toplantı seçin',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          items: toplantilar
              .map(
                (t) => DropdownMenuItem(
                  value: t.id,
                  child: Text(
                    '${t.toplantiNo} · ${t.toplantiTarihi}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: toplantilar.isEmpty
              ? null
              : (id) {
                  if (id != null) _toplantiSecVeYukle(id);
                },
        ),
      ),
    );
  }

  Widget _buildYkUstCubukIslemlerMenu() {
    return PopupMenuButton<String>(
      key: const ValueKey('yk_ust_cubuk_islemler_menu'),
      tooltip: 'Yürütme Kurulu işlemleri',
      offset: const Offset(0, 40),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (value) {
        switch (value) {
          case 'toplanti':
            _showToplantiSeciciDialog();
          case 'yeni':
            _showYeniToplantiDialog();
          case 'arsiv':
            context.push('/yk-karar/eski');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white38),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text(
              'İşlemler',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.white70, size: 20),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'toplanti',
          child: _buildYkMenuOge(
            icon: Icons.event_available_outlined,
            iconColor: const Color(0xFF1E3A8A),
            baslik: 'Toplantı Seç ve Düzenle',
            aciklama: 'Aktif toplantıyı değiştir veya bilgilerini düzenle',
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'yeni',
          child: _buildYkMenuOge(
            icon: Icons.add_circle_outline,
            iconColor: Colors.green.shade700,
            baslik: 'Yeni Yürütme Kurulu Kararı Oluştur',
            aciklama: 'Yeni toplantı kaydı aç ve birim kararlarını hazırla',
          ),
        ),
        PopupMenuItem(
          value: 'arsiv',
          child: _buildYkMenuOge(
            icon: Icons.folder_copy_outlined,
            iconColor: Colors.blueGrey.shade700,
            baslik: 'Yürütme Kurulu Arşivi',
            aciklama: 'Geçmiş toplantı ve karar kayıtlarına git',
          ),
        ),
      ],
    );
  }

  Widget _buildYkMenuOge({
    required IconData icon,
    required Color iconColor,
    required String baslik,
    required String aciklama,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                baslik,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                aciklama,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildYkBosBaslangic() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gavel, size: 64, color: Color(0xFF1E3A8A)),
              const SizedBox(height: 20),
              const Text(
                'Yürütme Kurulu Merkezi',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Çalışmak istediğiniz toplantıyı seçin, yeni toplantı oluşturun '
                'veya eski kararlara bakın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blueGrey.shade600, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _showToplantiSeciciDialog,
                  icon: const Icon(Icons.event_available_outlined),
                  label: const Text('Toplantı Seç / Düzenle'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showYeniToplantiDialog,
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Yeni Yürütme Kurulu Oluştur'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/yk-karar/eski'),
                  icon: const Icon(Icons.history),
                  label: const Text('Eski Kararlar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBirimSekmeSeridi() {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        itemCount: _birimler.length,
        itemBuilder: (context, index) {
          final birim = _birimler[index];
          final isSelected = _seciliBirimId == birim.id;
          final hasKayit = _toplantiKararlari.any((k) => k.birimId == birim.id);
          final isUploaded = _uploadedPdfs.containsKey(birim.id);
          final statusColor = hasKayit
              ? Colors.green
              : (isUploaded ? Colors.orange : Colors.grey.shade400);

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _onBirimSekmesiSec(birim.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
                          )
                        : null,
                    color: isSelected ? null : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? Colors.white : statusColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        birim.ad.length > 28
                            ? '${birim.ad.substring(0, 28)}…'
                            : birim.ad,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkspaceOrPlaceholder(ToplantiModel? seciliToplanti) {
    if (seciliToplanti == null) {
      return _buildYkBosBaslangic();
    }
    if (_seciliBirimId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_rounded, size: 56, color: Colors.blue.shade300),
            const SizedBox(height: 16),
            Text(
              'Yürütme Kurulu ${seciliToplanti.toplantiNo}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Word editörü için üstteki birim şeridinden birim seçin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }
    return _buildWorkspace();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final gundemProvider = context.watch<GundemProvider>();
    final seciliToplanti = gundemProvider.seciliToplanti;

    if (!_isLoading &&
        seciliToplanti?.id != _yukluToplantiId &&
        !_toplantiYukleniyor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (seciliToplanti != null) {
          _toplantiCalismasiniYukle(seciliToplanti.id);
        } else if (_yukluToplantiId != null) {
          setState(() {
            _temizleCalismaAlani();
            _yukluToplantiId = null;
          });
        }
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ÜST BAR: AKTİF TOPLANTI VE SEÇİCİ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E3A8A),
                  Color(0xFF312E81),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                if (seciliToplanti != null) ...[
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.greenAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  _buildKompaktToplantiDropdown(gundemProvider),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _anaKarariEditoreAc,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Ana Karar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                        decorationColor: Colors.white54,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _showToplantiSeciciDialog,
                    icon: const Icon(Icons.list_alt, size: 16),
                    label: const Text('Liste', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orangeAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Toplantı seçilmedi',
                      style: TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                _buildYkUstCubukIslemlerMenu(),
              ],
            ),
          ),

          if (seciliToplanti != null && _birimler.isNotEmpty)
            _buildBirimSekmeSeridi(),

          if (_birimler.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Birim listesi yüklenemedi. Sistem Ayarlarından birim tanımlarını kontrol edin.',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadInitialData();
                    },
                    child: const Text('Yenile'),
                  ),
                ],
              ),
            ),

          // ANA ÇALIŞMA ALANI (Workspace)
          Expanded(
            child: _buildWorkspaceOrPlaceholder(seciliToplanti),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspace() {
    if (_seciliBirimId == _anaKararEditorId) {
      return _buildAnaKararWorkspace();
    }

    final birim = _birimler.firstWhere((b) => b.id == _seciliBirimId);
    final isUploaded = _uploadedPdfs.containsKey(birim.id);
    final isAnalyzing = _isAnalyzingMap[birim.id] ?? false;
    final hasAnalysis = _analyzedKararlar.containsKey(birim.id);

    final quillController = _quillControllers[birim.id]!;
    final kararSablon = _seciliKararSablonlari[birim.id];
    final gundemSablon = _seciliGundemSablonlari[birim.id];
    final kararSablonuVar = kararSablon != null;
    final gundemSablonuVar = gundemSablon != null;
    final uyarilar = _analizUyarilari[birim.id] ?? [];
    final eslesmeSkoru = _eslesmeSkorlari[birim.id];
    final pdfKalite = _pdfKaliteRaporlari[birim.id];

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarW = _sidebarDar ? 48.0 : 200.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: sidebarW,
              child: _buildSidebarPanel(
                birim: birim,
                isUploaded: isUploaded,
                isAnalyzing: isAnalyzing,
                hasAnalysis: hasAnalysis,
                kararSablon: kararSablon,
                gundemSablon: gundemSablon,
                kararSablonuVar: kararSablonuVar,
                gundemSablonuVar: gundemSablonuVar,
                uyarilar: uyarilar,
                eslesmeSkoru: eslesmeSkoru,
                pdfKalite: pdfKalite,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
                child: _buildEditorPanel(
                  birim: birim,
                  quillController: quillController,
                  kararSablon: kararSablon,
                  gundemSablon: gundemSablon,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAnaKararWorkspace() {
    final toplanti = context.read<GundemProvider>().seciliToplanti;
    final controller = _quillControllers[_anaKararEditorId]!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final sidebarW = _sidebarDar ? 48.0 : 200.0;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: sidebarW,
              child: _sidebarDar
                  ? _buildDarSidebarStrip(
                      onExpand: () => setState(() => _sidebarDar = false),
                      onWord: toplanti != null
                          ? () => _anaKarariOnizle(toplanti)
                          : null,
                    )
                  : Container(
                margin: const EdgeInsets.all(6),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Ana YK Kararı',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          onPressed: () => setState(() => _sidebarDar = true),
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Daralt',
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      toplanti != null
                          ? '${toplanti.toplantiNo} — ${_toplantiKararlari.length} birim'
                          : 'Birleşik görünüm',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey.shade700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (toplanti != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _anaKarariOnizle(toplanti),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text(
                            'Word',
                            style: TextStyle(fontSize: 12),
                          ),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 6, 8, 6),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        color: const Color(0xFFEFF6FF),
                        child: const Text(
                          'Ana Karar — tüm birim kararları',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      quill.QuillSimpleToolbar(
                        controller: controller,
                        config: const quill.QuillSimpleToolbarConfig(
                          showFontFamily: false,
                          showFontSize: true,
                          showSearchButton: false,
                          showCodeBlock: false,
                          showQuote: false,
                          showListCheck: false,
                          showSubscript: false,
                          showSuperscript: false,
                          showLink: false,
                        ),
                      ),
                      Expanded(
                        child: quill.QuillEditor.basic(
                          controller: controller,
                          config: const quill.QuillEditorConfig(
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDarSidebarStrip({
    required VoidCallback onExpand,
    VoidCallback? onWord,
    VoidCallback? onPdf,
    VoidCallback? onAnaliz,
    bool isAnalyzing = false,
    bool showAnaliz = false,
  }) {
    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: onExpand,
            tooltip: 'Paneli aç',
            visualDensity: VisualDensity.compact,
          ),
          if (onPdf != null)
            IconButton(
              icon: const Icon(Icons.upload_file, size: 18),
              onPressed: onPdf,
              tooltip: 'PDF',
              visualDensity: VisualDensity.compact,
            ),
          if (showAnaliz && onAnaliz != null)
            IconButton(
              icon: isAnalyzing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome, size: 18),
              onPressed: isAnalyzing ? null : onAnaliz,
              tooltip: 'Analiz Et',
              visualDensity: VisualDensity.compact,
            ),
          if (onWord != null)
            IconButton(
              icon: const Icon(Icons.download_rounded, size: 18),
              onPressed: onWord,
              tooltip: 'Word',
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  Widget _buildSidebarPanel({
    required BirimModel birim,
    required bool isUploaded,
    required bool isAnalyzing,
    required bool hasAnalysis,
    required SablonModel? kararSablon,
    required SablonModel? gundemSablon,
    required bool kararSablonuVar,
    required bool gundemSablonuVar,
    required List<String> uyarilar,
    required int? eslesmeSkoru,
    required PdfKaliteSonucu? pdfKalite,
  }) {
    if (_sidebarDar) {
      return _buildDarSidebarStrip(
        onExpand: () => setState(() => _sidebarDar = false),
        onPdf: () => _pickPdfForBirim(birim.id),
        onAnaliz: () => _analizEtBirim(birim.id),
        showAnaliz: isUploaded,
        isAnalyzing: isAnalyzing,
      );
    }

    return Container(
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(12),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    birim.ad,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left, size: 20),
                  onPressed: () => setState(() => _sidebarDar = true),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Daralt',
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              'Şablonlar',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            _buildSablonInfoRow(
              label: 'Karar',
              sablon: kararSablon,
              eksik: !kararSablonuVar,
            ),
            const SizedBox(height: 6),
            _buildSablonInfoRow(
              label: 'Gündem',
              sablon: gundemSablon,
              eksik: !gundemSablonuVar,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildStatusChip(
                  label: kararSablonuVar ? 'Karar ✓' : 'Karar ✗',
                  ok: kararSablonuVar,
                ),
                _buildStatusChip(
                  label: gundemSablonuVar ? 'Gündem ✓' : 'Gündem ✗',
                  ok: gundemSablonuVar,
                ),
                _buildStatusChip(
                  label: isUploaded ? 'PDF ✓' : 'PDF ✗',
                  ok: isUploaded,
                ),
                if (eslesmeSkoru != null)
                  _buildStatusChip(
                    label: 'Eşleşme $eslesmeSkoru',
                    ok: eslesmeSkoru >= 12,
                  ),
              ],
            ),
            if (uyarilar.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '⚠ ${uyarilar.first}',
                  style: TextStyle(fontSize: 10, color: Colors.orange.shade800),
                ),
              ),
            const Divider(height: 24),
            const Text(
              'Üst Yazı PDF',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pickPdfForBirim(birim.id),
                icon: Icon(
                  isUploaded ? Icons.edit_document : Icons.upload_file,
                  size: 18,
                ),
                label: Text(
                  isUploaded ? 'PDF Değiştir' : 'PDF Seç',
                  style: const TextStyle(fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
            if (isUploaded) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: ValueKey('yk_analiz_et_${birim.id}'),
                  onPressed: isAnalyzing
                      ? null
                      : () => _analizEtBirim(birim.id),
                  icon: isAnalyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(
                    hasAnalysis ? 'Yeniden Analiz' : 'Analiz Et',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              hasAnalysis
                  ? 'Analiz tamam'
                  : (isUploaded ? 'PDF yüklü' : 'PDF bekleniyor'),
              style: TextStyle(
                fontSize: 11,
                color: hasAnalysis
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKararTabloOnizleme(String birimId) {
    final karar = _analyzedKararlar[birimId];
    if (karar == null) return const SizedBox.shrink();

    List<List<String>> rows = [];
    if (karar.tabloVerileri.isNotEmpty) {
      final cols = karar.tabloVerileri.first.keys.toList();
      rows.add(cols);
      for (final row in karar.tabloVerileri) {
        rows.add(cols.map((c) => row[c]?.toString() ?? '').toList());
      }
    } else if (karar.docxBodyXml != null &&
        karar.docxBodyXml!.contains('<w:tbl')) {
      rows = DocxOoxmlUtil.extractDataTablesFromBodyXml(karar.docxBodyXml!);
    }

    if (rows.isEmpty) return const SizedBox.shrink();

    final colCount = rows.map((r) => r.length).fold(0, (a, b) => a > b ? a : b);
    if (colCount == 0) return const SizedBox.shrink();

    final headerRow = rows.first;
    final dataRows = rows.length > 1 ? rows.sublist(1) : const <List<String>>[];

    if (!_tabloPanelAcik) {
      return InkWell(
        onTap: () => setState(() => _tabloPanelAcik = true),
        child: Container(
          height: 30,
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
            color: const Color(0xFFF8FAFC),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Icons.table_chart_outlined,
                size: 14,
                color: Colors.grey.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'Cetvel tablosu (${dataRows.length} satır) — aç',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
              const Spacer(),
              Icon(Icons.expand_more, size: 18, color: Colors.grey.shade600),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 140,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
        color: const Color(0xFFF8FAFC),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 2),
            child: Row(
              children: [
                Icon(
                  Icons.table_chart_outlined,
                  size: 14,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Text(
                  'Cetvel (${dataRows.length} satır)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const Spacer(),
                if (karar.docxBodyXml != null &&
                    karar.docxBodyXml!.contains('<w:tbl'))
                  Text(
                    'Word\'da korunuyor',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.green.shade700,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.expand_less, size: 18),
                  onPressed: () => setState(() => _tabloPanelAcik = false),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Kapat',
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: DataTable(
                  headingRowHeight: 32,
                  dataRowMinHeight: 28,
                  dataRowMaxHeight: 40,
                  columnSpacing: 16,
                  headingRowColor: WidgetStateProperty.all(Colors.blue.shade50),
                  columns: List.generate(
                    colCount,
                    (i) => DataColumn(
                      label: Text(
                        i < headerRow.length ? headerRow[i] : 'Kolon ${i + 1}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  rows: dataRows.map((row) {
                    return DataRow(
                      cells: List.generate(
                        colCount,
                        (i) => DataCell(
                          Text(
                            i < row.length ? row[i] : '',
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSablonInfoRow({
    required String label,
    required SablonModel? sablon,
    required bool eksik,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: eksik ? Colors.red.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: eksik ? Colors.red.shade200 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            eksik ? 'Eksik — Ayarlar → Şablonlar' : sablon!.sablonAdi,
            style: TextStyle(
              fontSize: 10,
              color: eksik ? Colors.red.shade700 : Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildEditorPanel({
    required BirimModel birim,
    required quill.QuillController quillController,
    SablonModel? kararSablon,
    SablonModel? gundemSablon,
  }) {
    final controller = _viewMode == _ViewMode.karar
        ? quillController
        : (_gundemQuillControllers[birim.id] ?? quillController);
    final aktifSablon = _viewMode == _ViewMode.karar
        ? kararSablon
        : gundemSablon;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              children: [
                _buildEditorTab(
                  icon: Icons.gavel_rounded,
                  label: 'Karar',
                  isActive: _viewMode == _ViewMode.karar,
                  onTap: () => setState(() => _viewMode = _ViewMode.karar),
                ),
                _buildEditorTab(
                  icon: Icons.format_list_bulleted,
                  label: 'Gündem',
                  isActive: _viewMode == _ViewMode.gundem,
                  onTap: () => setState(() => _viewMode = _ViewMode.gundem),
                ),
                const Spacer(),
                if (aktifSablon != null)
                  Flexible(
                    child: Text(
                      aktifSablon.sablonAdi,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          quill.QuillSimpleToolbar(
            controller: controller,
            config: const quill.QuillSimpleToolbarConfig(
              showFontFamily: false,
              showFontSize: true,
              showSearchButton: false,
              showCodeBlock: false,
              showQuote: false,
              showListCheck: false,
              showSubscript: false,
              showSuperscript: false,
              showLink: false,
            ),
          ),
          Expanded(
            child: quill.QuillEditor.basic(
              controller: controller,
              config: const quill.QuillEditorConfig(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          if (_viewMode == _ViewMode.karar) _buildKararTabloOnizleme(birim.id),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              color: Colors.grey.shade50,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  key: ValueKey(
                    _viewMode == _ViewMode.karar
                        ? 'yk_karar_kaydet_${birim.id}'
                        : 'yk_gundem_kaydet_${birim.id}',
                  ),
                  onPressed: () => _viewMode == _ViewMode.karar
                      ? _saveKarar(birim.id)
                      : _saveGundem(birim.id),
                  icon: const Icon(Icons.save, size: 16),
                  label: Text(
                    _viewMode == _ViewMode.karar ? 'Kaydet' : 'Gündem Kaydet',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip({required String label, required bool ok}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ok ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ok ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: ok ? Colors.green.shade800 : Colors.grey.shade700,
        ),
      ),
    );
  }

  // ── EBYS tarzı editör tab butonu ──
  Widget _buildEditorTab({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF1E3A8A) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? const Color(0xFF1E3A8A) : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: 14,
                color: isActive
                    ? const Color(0xFF1E3A8A)
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
