import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/services/ai_extraction_service.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../../../core/models/sistem_ayarlari_model.dart';
import '../../birim/models/birim_model.dart';
import '../../birim/services/birim_service.dart';
import '../services/fatura_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/excel_web_parser.dart';

class FaturaModel {
  String id;
  String firmaAdi;
  String adres;
  String vergiDairesi;
  String vergiNo;
  String tarih;
  String irsaliyeNo;
  String melbesNo;
  String numuneNo;
  String numuneAciklamasi;
  List<Map<String, dynamic>> kalemler;
  bool isKdvMuaf;
  double matrah;
  double kdvOrani;
  double kdvTutari;
  double genelToplam;
  String parsedBy;
  String? iban;
  String? hesapAdi;

  FaturaModel({
    required this.id,
    required this.firmaAdi,
    required this.adres,
    required this.vergiDairesi,
    required this.vergiNo,
    required this.tarih,
    required this.irsaliyeNo,
    required this.melbesNo,
    required this.numuneNo,
    required this.numuneAciklamasi,
    required this.kalemler,
    required this.isKdvMuaf,
    required this.matrah,
    required this.kdvOrani,
    required this.kdvTutari,
    required this.genelToplam,
    this.parsedBy = 'AI Parser',
    this.iban,
    this.hesapAdi,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'firmaAdi': firmaAdi,
      'adres': adres,
      'vergiDairesi': vergiDairesi,
      'vergiNo': vergiNo,
      'tarih': tarih,
      'irsaliyeNo': irsaliyeNo,
      'melbesNo': melbesNo,
      'numuneNo': numuneNo,
      'numuneAciklamasi': numuneAciklamasi,
      'kalemler': kalemler,
      'isKdvMuaf': isKdvMuaf,
      'matrah': matrah,
      'kdvOrani': kdvOrani,
      'kdvTutari': kdvTutari,
      'genelToplam': genelToplam,
      'parsedBy': parsedBy,
      'iban': iban,
      'hesapAdi': hesapAdi,
    };
  }

  factory FaturaModel.fromJson(Map<String, dynamic> json) {
    return FaturaModel(
      id: json['id'] ?? '',
      firmaAdi: json['firmaAdi'] ?? '',
      adres: json['adres'] ?? '',
      vergiDairesi: json['vergiDairesi'] ?? '',
      vergiNo: json['vergiNo'] ?? '',
      tarih: json['tarih'] ?? '',
      irsaliyeNo: json['irsaliyeNo'] ?? '',
      melbesNo: json['melbesNo'] ?? '',
      numuneNo: json['numuneNo'] ?? '',
      numuneAciklamasi: json['numuneAciklamasi'] ?? '',
      matrah: json['matrah'] ?? 0.0,
      kdvTutari: json['kdvTutari'] ?? 0.0,
      genelToplam: json['genelToplam'] ?? 0.0,
      isKdvMuaf: json['isKdvMuaf'] ?? false,
      kdvOrani: json['kdvOrani'] ?? 20,
      parsedBy: json['parsedBy'] ?? 'Bilinmiyor',
      iban: json['iban'],
      hesapAdi: json['hesapAdi'],
      kalemler: List<Map<String, dynamic>>.from(json['kalemler'] ?? []),
    );
  }
}

class BatchFaturaProvider extends ChangeNotifier {
  List<FaturaModel> pendingInvoices = [];
  int currentIndex = 0;
  bool isNakliYekunAktif = false;
  int dialogUpdateCounter = 0;

  final BirimService _birimService = BirimService();
  Map<String, BirimModel> _birimlerCache = {};

  void notifyDialogReturn() {
    dialogUpdateCounter++;
    notifyListeners();
  }

  final AIExtractionService _aiService = AIExtractionService();
  SistemAyarlariModel? sistemAyarlari;

  Map<String, Offset> coordinates = {
    'firmaAdi': const Offset(45, 135),
    'adres': const Offset(45, 155),
    'vergiDairesi': const Offset(145, 275),
    'vkn': const Offset(145, 295),
    'tarih': const Offset(470, 270),
    'irsaliyeNo': const Offset(470, 295),
    'cinsi': const Offset(50, 360),
    'miktar': const Offset(320, 360),
    'fiyat': const Offset(380, 360),
    'tutar': const Offset(510, 360),
    'nakliYekunUstYazi': const Offset(270, 340),
    'nakliYekunUstTutar': const Offset(510, 340),
    'nakliYekunAltYazi': const Offset(270, 580),
    'nakliYekunAltTutar': const Offset(510, 580),
    'numuneAciklama': const Offset(50, 600),
    'melbes': const Offset(50, 620),
    'numuneNo': const Offset(50, 640),
    'matrah': const Offset(470, 675),
    'kdv': const Offset(470, 705),
    'genelToplam': const Offset(470, 735),
    'yaziylaTutar': const Offset(90, 785),
    'hesapAdi': const Offset(90, 805),
    'iban': const Offset(90, 825),
  };

  void updateCoordinate(String key, Offset newOffset) {
    coordinates[key] = newOffset;
    notifyListeners();
  }

  Future<void> saveCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    for (final entry in coordinates.entries) {
      await prefs.setDouble('${entry.key}_dx', entry.value.dx);
      await prefs.setDouble('${entry.key}_dy', entry.value.dy);
    }
  }

  Future<void> _loadCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    coordinates.forEach((key, value) {
      final dx = prefs.getDouble('${key}_dx');
      final dy = prefs.getDouble('${key}_dy');
      if (dx != null && dy != null) {
        coordinates[key] = Offset(dx, dy);
      }
    });
    notifyListeners();
  }

  Future<void> resetCoordinates() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in coordinates.keys) {
      await prefs.remove('coord_${key}_dx');
      await prefs.remove('coord_${key}_dy');
    }
    coordinates = {
      'firmaAdi': const Offset(45, 135),
      'vergiDairesi': const Offset(145, 275),
      'vkn': const Offset(145, 295),
      'tarih': const Offset(470, 270),
      'irsaliyeNo': const Offset(470, 295),
      'cinsi': const Offset(50, 360),
      'miktar': const Offset(320, 360),
      'fiyat': const Offset(380, 360),
      'tutar': const Offset(510, 360),
      'nakliYekunUstYazi': const Offset(270, 340),
      'nakliYekunUstTutar': const Offset(510, 340),
      'nakliYekunAltYazi': const Offset(270, 580),
      'nakliYekunAltTutar': const Offset(510, 580),
      'numuneAciklama': const Offset(50, 600),
      'melbes': const Offset(50, 620),
      'numuneNo': const Offset(50, 640),
      'matrah': const Offset(470, 675),
      'kdv': const Offset(470, 705),
      'genelToplam': const Offset(470, 735),
      'yaziylaTutar': const Offset(90, 785),
      'hesapAdi': const Offset(90, 805),
      'iban': const Offset(90, 825),
    };
    notifyListeners();
  }

  Future<void> _loadSistemAyarlari() async {
    final service = SistemAyarlariService();
    sistemAyarlari = await service.getAyarlar();
    notifyListeners();
  }

  void toggleKdvMuaf(int index, bool value) {
    if (index < 0 || index >= pendingInvoices.length) return;
    final currentInvoice = pendingInvoices[index];
    currentInvoice.isKdvMuaf = value;
    if (value) {
      currentInvoice.kdvTutari = 0.0;
      currentInvoice.genelToplam = currentInvoice.matrah;
    } else {
      currentInvoice.kdvTutari = currentInvoice.matrah * (currentInvoice.kdvOrani / 100.0);
      currentInvoice.genelToplam = currentInvoice.matrah + currentInvoice.kdvTutari;
    }
    notifyListeners();
  }

  void toggleNakliYekunGlobal(bool value) {
    isNakliYekunAktif = value;
    notifyListeners();
  }

  BatchFaturaProvider() {
    _initializeEmpty();
    _fetchBirimler();
    _loadSistemAyarlari();
    _loadCoordinates();
  }

  void _initializeEmpty() {
    pendingInvoices = [
      FaturaModel(id: '0', firmaAdi: '', adres: '', vergiDairesi: '', vergiNo: '', tarih: '', irsaliyeNo: '', melbesNo: '', numuneNo: '', numuneAciklamasi: '', matrah: 0.0, kdvTutari: 0.0, genelToplam: 0.0, isKdvMuaf: false, kdvOrani: 20, parsedBy: 'Yeni Fatura', kalemler: [])
    ];
    currentIndex = 0;
  }

  Map<String, BirimModel> get birimlerCache => _birimlerCache;

  void applyBirimToInvoice(int invoiceIndex, String birimAdi) {
    if (!_birimlerCache.containsKey(birimAdi)) return;
    final birim = _birimlerCache[birimAdi]!;
    final invoice = pendingInvoices[invoiceIndex];
    invoice.iban = birim.iban;
    invoice.hesapAdi = birim.hesapAdi;
    notifyListeners();
  }

  Future<void> _fetchBirimler() async {
    try {
      final birimler = await _birimService.getAll(onlyActive: true);
      _birimlerCache = {for (var b in birimler) b.ad: b};
      notifyListeners();
    } catch (e) {
      print('Birimler çekilirken hata: $e');
    }
  }

  void _updateIbanForInvoice(FaturaModel invoice) {
    if (invoice.kalemler.isNotEmpty) {
      final birimAdi = invoice.kalemler.first['birimAdi'] as String?;
      if (birimAdi != null && _birimlerCache.containsKey(birimAdi)) {
        final birim = _birimlerCache[birimAdi]!;
        if (birim.iban != null && birim.iban!.isNotEmpty) {
          invoice.iban = birim.iban;
        }
        if (birim.hesapAdi != null && birim.hesapAdi!.isNotEmpty) {
          invoice.hesapAdi = birim.hesapAdi;
        }
      }
    }
  }

  Future<void> loadBatch(String text) async {
    final extractedData = await _aiService.extractBatchData(text);
    pendingInvoices = extractedData.map((e) {
      final inv = FaturaModel.fromJson(e);
      _updateIbanForInvoice(inv);
      return inv;
    }).toList();
    if (pendingInvoices.isEmpty) _initializeEmpty();
    currentIndex = 0;
    notifyListeners();
  }

  Future<void> loadExcelFile(Uint8List bytes, String fileName) async {
    try {
      // 1. Convert Excel to CSV using Web parser
      final csvText = await ExcelWebParser.extractTextFromExcel(bytes);
      if (csvText.isEmpty) throw Exception('Excel dosyası boş veya okunamadı.');

      // 2. Take a preview (first 15 lines) for the AI
      final lines = csvText.split('\n');
      final previewLines = lines.take(15).join('\n');

      // 3. Ask AI for mapping
      final mappingResult = await _aiService.extractExcelMapping(previewLines);

      if (mappingResult['isBatchList'] == true) {
        // Toplu liste senaryosu (örn. 200 öğrenci)
        final mapData = mappingResult['mapping'] as Map<String, dynamic>;
        final startRow = (mappingResult['startRowIndex'] as int?) ?? 1;

        final newInvoices = <FaturaModel>[];
        
        final firmaIdx = mapData['firmaAdi'] as int?;
        final tcIdx = mapData['tcVkn'] as int?;
        final matrahIdx = mapData['matrah'] as int?;

        for (int i = startRow; i < lines.length; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          
          final cells = line.split(' | ');
          String firma = '';
          String tc = '';
          double matrah = 0.0;

          if (firmaIdx != null && firmaIdx >= 0 && firmaIdx < cells.length) {
            firma = cells[firmaIdx].trim();
          }
          if (tcIdx != null && tcIdx >= 0 && tcIdx < cells.length) {
            tc = cells[tcIdx].trim();
          }
          if (matrahIdx != null && matrahIdx >= 0 && matrahIdx < cells.length) {
            matrah = double.tryParse(cells[matrahIdx].replaceAll(RegExp(r'[^0-9,\.]'), '').replaceAll(',', '.')) ?? 0.0;
          }

          if (firma.isNotEmpty && matrah > 0) {
            final inv = FaturaModel(
              id: DateTime.now().millisecondsSinceEpoch.toString() + i.toString(),
              firmaAdi: firma,
              adres: '',
              vergiDairesi: '',
              vergiNo: tc,
              tarih: '',
              irsaliyeNo: '',
              melbesNo: '',
              numuneNo: '',
              numuneAciklamasi: '',
              kalemler: [
                {'cinsi': 'Hizmet Bedeli', 'miktar': 1, 'fiyat': matrah}
              ],
              matrah: matrah,
              kdvOrani: 20.0, // varsayılan KDV %20
              isKdvMuaf: false,
              kdvTutari: 0.0,
              genelToplam: 0.0,
              parsedBy: 'Excel Toplu Aktarım',
            );
            _recalculateTotals(inv);
            newInvoices.add(inv);
          }
        }

        if (newInvoices.isNotEmpty) {
          pendingInvoices = newInvoices;
          currentIndex = 0;
          notifyListeners();
        } else {
          throw Exception('Eşleşen satır bulunamadı veya veriler okunamadı.');
        }

      } else {
        // Normal fatura (tekil form)
        // Send full CSV text to AI's standard parser
        await loadBatch(csvText);
      }
    } catch (e) {
      debugPrint('[loadExcelFile] Hata: $e');
      rethrow;
    }
  }

  void _recalculateTotals(FaturaModel invoice) {
    double matrah = 0;
    for (var kalem in invoice.kalemler) {
      double miktar = double.tryParse(kalem['miktar'].toString()) ?? 0.0;
      double fiyat = double.tryParse(kalem['fiyat'].toString()) ?? 0.0;
      matrah += miktar * fiyat;
    }
    invoice.matrah = matrah;
    if (invoice.isKdvMuaf) {
      invoice.kdvTutari = 0.0;
      invoice.genelToplam = matrah;
    } else {
      invoice.kdvTutari = matrah * (invoice.kdvOrani / 100.0);
      invoice.genelToplam = matrah + invoice.kdvTutari;
    }
  }

  void addKalem(int index) {
    if (index < 0 || index >= pendingInvoices.length) return;
    final currentInvoice = pendingInvoices[index];
    currentInvoice.kalemler.add({
      'cinsi': 'Yeni Kalem',
      'miktar': 1,
      'fiyat': 0.0,
    });
    _recalculateTotals(currentInvoice);
    notifyListeners();
  }

  void updateKalem(int invoiceIndex, int kalemIndex, String key, dynamic value) {
    if (invoiceIndex < 0 || invoiceIndex >= pendingInvoices.length) return;
    final currentInvoice = pendingInvoices[invoiceIndex];
    if (kalemIndex >= 0 && kalemIndex < currentInvoice.kalemler.length) {
      currentInvoice.kalemler[kalemIndex][key] = value;
      if (key == 'birimAdi') {
        _updateIbanForInvoice(currentInvoice);
      }
      if (key == 'miktar' || key == 'fiyat') {
        _recalculateTotals(currentInvoice);
      }
      notifyListeners();
    }
  }

  void removeKalem(int invoiceIndex, int kalemIndex) {
    if (invoiceIndex < 0 || invoiceIndex >= pendingInvoices.length) return;
    final currentInvoice = pendingInvoices[invoiceIndex];
    if (kalemIndex >= 0 && kalemIndex < currentInvoice.kalemler.length) {
      currentInvoice.kalemler.removeAt(kalemIndex);
      _recalculateTotals(currentInvoice);
      notifyListeners();
    }
  }

  final FaturaService _faturaService = FaturaService();

  Future<void> approveInvoice(int index) async {
    if (index >= 0 && index < pendingInvoices.length) {
      final invoice = pendingInvoices[index];
      // Validation: ensure IBAN and Hesap Adı are provided
      if (invoice.iban == null || invoice.iban!.trim().isEmpty ||
          invoice.hesapAdi == null || invoice.hesapAdi!.trim().isEmpty) {
        throw Exception('IBAN ve Hesap Adı boş olamaz');
      }
      try {
        await _faturaService.saveFatura(invoice);
        pendingInvoices.removeAt(index);
        if (pendingInvoices.isEmpty) {
          _initializeEmpty();
        }
        notifyListeners();
      } catch (e) {
        throw Exception('Kayıt başarısız: $e');
      }
    }
  }

  void removeInvoice(int index) {
    if (index >= 0 && index < pendingInvoices.length) {
      pendingInvoices.removeAt(index);
      if (pendingInvoices.isEmpty) {
        _initializeEmpty();
      }
      notifyListeners();
    }
  }

  Future<void> approveAll() async {
    for (var fatura in pendingInvoices) {
      if (fatura.kalemler.isNotEmpty) { // Boş olmayan faturaları kaydet
        await _faturaService.saveFatura(fatura);
      }
    }
    pendingInvoices.clear();
    _initializeEmpty();
    notifyListeners();
  }

  void updateField(int index, String field, dynamic value) {
    if (index < 0 || index >= pendingInvoices.length) return;
    
    final currentInvoice = pendingInvoices[index];
    switch (field) {
      case 'firmaAdi': currentInvoice.firmaAdi = value; break;
      case 'adres': currentInvoice.adres = value; break;
      case 'vergiDairesi': currentInvoice.vergiDairesi = value; break;
      case 'vergiNo': currentInvoice.vergiNo = value; break;
      case 'tarih': currentInvoice.tarih = value; break;
      case 'irsaliyeNo': currentInvoice.irsaliyeNo = value; break;
      case 'melbesNo': currentInvoice.melbesNo = value; break;
      case 'numuneNo': currentInvoice.numuneNo = value; break;
      case 'numuneAciklamasi': currentInvoice.numuneAciklamasi = value; break;
      case 'matrah': 
        currentInvoice.matrah = double.tryParse(value.toString()) ?? currentInvoice.matrah; 
        if (!currentInvoice.isKdvMuaf) {
          currentInvoice.kdvTutari = currentInvoice.matrah * (currentInvoice.kdvOrani / 100.0);
          currentInvoice.genelToplam = currentInvoice.matrah + currentInvoice.kdvTutari;
        } else {
          currentInvoice.kdvTutari = 0.0;
          currentInvoice.genelToplam = currentInvoice.matrah;
        }
        break;
      case 'kdvOrani':
        currentInvoice.kdvOrani = double.tryParse(value.toString()) ?? currentInvoice.kdvOrani;
        _recalculateTotals(currentInvoice);
        break;
      case 'kdvTutari': 
        if (!currentInvoice.isKdvMuaf) {
          currentInvoice.kdvTutari = double.tryParse(value.toString()) ?? currentInvoice.kdvTutari; 
        }
        break;
      case 'genelToplam': currentInvoice.genelToplam = double.tryParse(value.toString()) ?? currentInvoice.genelToplam; break;
      case 'iban':
        currentInvoice.iban = value?.toString();
        break;
      case 'hesapAdi':
        currentInvoice.hesapAdi = value?.toString();
        break;
    }
    notifyListeners();
  }

  Future<Uint8List> generatePdf(FaturaModel invoice) async {
    try {
      final font = await PdfGoogleFonts.robotoRegular();
      final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font));

      final double kalemSatirAraligi = 18.0;
      const double standartFontSize = 10.0;
      const int satirLimit = 10; // Nakli yekün'ün daha erken devreye girmesi için limit düşürüldü

      final bgImage = await rootBundle.load('assets/images/fatura_sablon.jpeg');

      if (invoice.kalemler.isEmpty) {
        invoice.kalemler.add({
          'cinsi': invoice.numuneAciklamasi.isNotEmpty ? invoice.numuneAciklamasi : 'Hizmet Bedeli',
          'miktar': 1,
          'fiyat': invoice.matrah,
        });
      }

      final int toplamSayfa = (invoice.kalemler.length / satirLimit).ceil().clamp(1, 9999);
      var oncekiSayfaToplam = 0.0;

      for (var sayfaIndex = 0; sayfaIndex < toplamSayfa; sayfaIndex++) {
        final baslangic = sayfaIndex * satirLimit;
        final bitis = (baslangic + satirLimit > invoice.kalemler.length) ? invoice.kalemler.length : baslangic + satirLimit;
        final sayfaSatirlari = invoice.kalemler.sublist(baslangic, bitis);
        
        final devreden = oncekiSayfaToplam;
        final sayfaToplami = sayfaSatirlari.fold<double>(0, (acc, item) {
          final fiyat = double.tryParse(item['fiyat'].toString()) ?? 0.0;
          final miktar = int.tryParse(item['miktar'].toString()) ?? 1;
          return acc + (fiyat * miktar);
        });
        final araToplam = devreden + sayfaToplami;
        final sonSayfa = sayfaIndex == toplamSayfa - 1;
        final ilkSayfa = sayfaIndex == 0;

        pdf.addPage(
          pw.Page(
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              margin: pw.EdgeInsets.zero,
              buildBackground: (context) {
                return pw.FullPage(
                  ignoreMargins: true,
                  child: pw.Image(
                    pw.MemoryImage(bgImage.buffer.asUint8List()),
                    fit: pw.BoxFit.fill,
                  ),
                );
              },
            ),
            build: (context) {
              return pw.Stack(
                children: [
                  if (ilkSayfa) ...[
                    pw.Positioned(
                      top: coordinates['firmaAdi']!.dy, left: coordinates['firmaAdi']!.dx,
                      child: pw.SizedBox(
                        width: 270,
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            if (invoice.firmaAdi.isNotEmpty)
                              pw.Text(invoice.firmaAdi, style: pw.TextStyle(fontSize: standartFontSize, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 4),
                            if (invoice.adres.isNotEmpty)
                              pw.Text(invoice.adres, style: const pw.TextStyle(fontSize: standartFontSize)),
                          ],
                        ),
                      ),
                    ),
                    if (invoice.vergiDairesi.isNotEmpty)
                      pw.Positioned(
                        top: coordinates['vergiDairesi']!.dy, left: coordinates['vergiDairesi']!.dx,
                        child: pw.Text(invoice.vergiDairesi, style: const pw.TextStyle(fontSize: standartFontSize)),
                      ),
                    if (invoice.vergiNo.isNotEmpty)
                      pw.Positioned(
                        top: coordinates['vkn']!.dy, left: coordinates['vkn']!.dx,
                        child: pw.Text(invoice.vergiNo, style: const pw.TextStyle(fontSize: standartFontSize)),
                      ),
                  ],
                  pw.Positioned(
                    top: coordinates['tarih']!.dy, left: coordinates['tarih']!.dx,
                    child: pw.Text(invoice.tarih.isEmpty ? '03.06.2026' : invoice.tarih, style: const pw.TextStyle(fontSize: standartFontSize)),
                  ),
                  pw.Positioned(
                    top: coordinates['irsaliyeNo']!.dy, left: coordinates['irsaliyeNo']!.dx,
                    child: pw.Text(invoice.irsaliyeNo.isEmpty ? '-' : invoice.irsaliyeNo, style: const pw.TextStyle(fontSize: standartFontSize)),
                  ),
                  if (isNakliYekunAktif && devreden > 0) ...[
                    pw.Positioned(
                      top: coordinates['nakliYekunUstYazi']!.dy, left: coordinates['nakliYekunUstYazi']!.dx,
                      child: pw.Text('Nakli Yekün (Önceki Sayfa)', style: pw.TextStyle(fontSize: standartFontSize, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Positioned(
                      top: coordinates['nakliYekunUstTutar']!.dy, left: coordinates['nakliYekunUstTutar']!.dx,
                      child: pw.Text(devreden.toStringAsFixed(2), style: pw.TextStyle(fontSize: standartFontSize, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                  ...sayfaSatirlari.asMap().entries.expand((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final currentTop = coordinates['cinsi']!.dy + (index * kalemSatirAraligi);
                    final fiyat = double.tryParse(item['fiyat'].toString()) ?? 0.0;
                    final miktar = int.tryParse(item['miktar'].toString()) ?? 1;
                    return [
                      pw.Positioned(top: currentTop, left: coordinates['cinsi']!.dx, child: pw.Text('${item['cinsi']}', style: const pw.TextStyle(fontSize: standartFontSize))),
                      pw.Positioned(top: currentTop, left: coordinates['miktar']!.dx, child: pw.Text('$miktar', style: const pw.TextStyle(fontSize: standartFontSize))),
                      pw.Positioned(top: currentTop, left: coordinates['fiyat']!.dx, child: pw.Text(fiyat.toStringAsFixed(2), style: const pw.TextStyle(fontSize: standartFontSize))),
                      pw.Positioned(top: currentTop, left: coordinates['tutar']!.dx, child: pw.Text((fiyat * miktar).toStringAsFixed(2), style: const pw.TextStyle(fontSize: standartFontSize))),
                    ];
                  }).toList(),
                  if (isNakliYekunAktif && !sonSayfa) ...[
                    pw.Positioned(
                      top: coordinates['nakliYekunAltYazi']!.dy, left: coordinates['nakliYekunAltYazi']!.dx,
                      child: pw.Text('Nakli Yekün (Devreden)', style: pw.TextStyle(fontSize: standartFontSize, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Positioned(
                      top: coordinates['nakliYekunAltTutar']!.dy, left: coordinates['nakliYekunAltTutar']!.dx,
                      child: pw.Text(araToplam.toStringAsFixed(2), style: pw.TextStyle(fontSize: standartFontSize, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                  if (sonSayfa) ...[
                    if (invoice.numuneAciklamasi.isNotEmpty)
                      pw.Positioned(
                        top: coordinates['numuneAciklama']!.dy, left: coordinates['numuneAciklama']!.dx,
                        child: pw.Text(invoice.numuneAciklamasi, style: const pw.TextStyle(fontSize: standartFontSize)),
                      ),
                    pw.Positioned(
                      top: coordinates['melbes']!.dy, left: coordinates['melbes']!.dx,
                      child: pw.Text(invoice.melbesNo, style: const pw.TextStyle(fontSize: standartFontSize)),
                    ),
                    pw.Positioned(
                      top: coordinates['numuneNo']!.dy, left: coordinates['numuneNo']!.dx,
                      child: pw.Text(invoice.numuneNo, style: const pw.TextStyle(fontSize: standartFontSize)),
                    ),
                    pw.Positioned(
                      top: coordinates['matrah']!.dy, left: coordinates['matrah']!.dx,
                      child: pw.Text(invoice.matrah.toStringAsFixed(2), style: const pw.TextStyle(fontSize: standartFontSize)),
                    ),
                    pw.Positioned(
                      top: coordinates['kdv']!.dy, left: coordinates['kdv']!.dx,
                      child: pw.Text(invoice.kdvTutari.toStringAsFixed(2), style: const pw.TextStyle(fontSize: standartFontSize)),
                    ),
                    pw.Positioned(
                      top: coordinates['genelToplam']!.dy, left: coordinates['genelToplam']!.dx,
                      child: pw.Text(invoice.genelToplam.toStringAsFixed(2), style: pw.TextStyle(fontSize: standartFontSize, fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Positioned(
                      top: coordinates['yaziylaTutar']!.dy, left: coordinates['yaziylaTutar']!.dx,
                      child: pw.Text(_sayiyiYaziyaCevir(invoice.genelToplam), style: const pw.TextStyle(fontSize: standartFontSize)),
                    ),
                    if (invoice.hesapAdi != null && invoice.hesapAdi!.isNotEmpty)
                      pw.Positioned(
                        top: coordinates['hesapAdi']!.dy, left: coordinates['hesapAdi']!.dx,
                        child: pw.Text(invoice.hesapAdi!, style: const pw.TextStyle(fontSize: standartFontSize)),
                      )
                    else if (sistemAyarlari != null && sistemAyarlari!.hesapAdi.isNotEmpty)
                      pw.Positioned(
                        top: coordinates['hesapAdi']!.dy, left: coordinates['hesapAdi']!.dx,
                        child: pw.Text(sistemAyarlari!.hesapAdi, style: const pw.TextStyle(fontSize: standartFontSize)),
                      ),
                    
                    if (invoice.iban != null && invoice.iban!.isNotEmpty)
                      pw.Positioned(
                        top: coordinates['iban']!.dy, left: coordinates['iban']!.dx,
                        child: pw.Text(invoice.iban!, style: const pw.TextStyle(fontSize: standartFontSize)),
                      )
                    else if (sistemAyarlari != null && sistemAyarlari!.iban.isNotEmpty)
                      pw.Positioned(
                        top: coordinates['iban']!.dy, left: coordinates['iban']!.dx,
                        child: pw.Text(sistemAyarlari!.iban, style: const pw.TextStyle(fontSize: standartFontSize)),
                      ),
                  ],
                  if (toplamSayfa > 1)
                    pw.Positioned(
                      top: 20, right: 20,
                      child: pw.Text('Sayfa ${sayfaIndex + 1}/$toplamSayfa', style: const pw.TextStyle(fontSize: standartFontSize)),
                    ),
                ],
              );
            },
          ),
        );
        oncekiSayfaToplam = araToplam;
      }

      return await pdf.save();
    } catch (e) {
      debugPrint('PDF Oluşturma Hatası: $e');
      final errDoc = pw.Document();
      errDoc.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Text('PDF Coktu Hata Nedeni: $e'),
          ),
        ),
      );
      return await errDoc.save();
    }
  }

  String _sayiyiYaziyaCevir(double tutar) {
    if (tutar == 0) return 'SIFIR TÜRK LİRASI SIFIR KURUŞTUR.';
    
    final parts = tutar.toStringAsFixed(2).split('.');
    final int lira = int.parse(parts[0]);
    final int kurus = int.parse(parts[1]);
    
    String liraYazi = lira == 0 ? 'SIFIR' : _convertNumberToWords(lira);
    String kurusYazi = kurus == 0 ? 'SIFIR' : _convertNumberToWords(kurus);
    
    return '$liraYazi TÜRK LİRASI $kurusYazi KURUŞTUR.';
  }

  String _convertNumberToWords(int number) {
    final birler = ['', 'BİR', 'İKİ', 'ÜÇ', 'DÖRT', 'BEŞ', 'ALTI', 'YEDİ', 'SEKİZ', 'DOKUZ'];
    final onlar = ['', 'ON', 'YİRMİ', 'OTUZ', 'KIRK', 'ELLİ', 'ALTMIŞ', 'YETMİŞ', 'SEKSEN', 'DOKSAN'];
    final binler = ['', 'BİN', 'MİLYON', 'MİLYAR'];

    if (number == 0) return 'SIFIR';

    String result = '';
    int groupIndex = 0;

    while (number > 0) {
      int group = number % 1000;
      if (group > 0) {
        String groupText = '';
        int yuzler = group ~/ 100;
        int onlarBasamagi = (group % 100) ~/ 10;
        int birlerBasamagi = group % 10;

        if (yuzler > 0) {
          if (yuzler == 1) {
            groupText += 'YÜZ ';
          } else {
            groupText += '${birler[yuzler]} YÜZ ';
          }
        }
        if (onlarBasamagi > 0) {
          groupText += '${onlar[onlarBasamagi]} ';
        }
        if (birlerBasamagi > 0) {
          // 'BİR BİN' denmemesi için kontrol (binler grubunda ve sadece 1 ise)
          if (groupIndex == 1 && group == 1) {
            // Bir şey ekleme, sadece BİN eklenecek
          } else {
            groupText += '${birler[birlerBasamagi]} ';
          }
        }

        groupText += '${binler[groupIndex]} ';
        result = groupText + result;
      }
      number = number ~/ 1000;
      groupIndex++;
    }

    return result.trim().replaceAll('  ', ' ');
  }
}
