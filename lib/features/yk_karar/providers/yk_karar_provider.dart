import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../../core/services/sistem_ayarlari_service.dart';
import '../models/toplanti_model.dart';
import 'dart:typed_data';
import '../models/yk_karar_model.dart';
import '../services/yk_karar_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// YK Karar Merkezi ana state yöneticisi.
///
/// Toplantı listesi, aktif toplantı, kararlar ve AI parse işlemlerini yönetir.
class YkKararProvider extends ChangeNotifier {
  final YkKararService _service = YkKararService();
  final SistemAyarlariService _ayarlarService = SistemAyarlariService();

  // ═══════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════

  List<ToplantiModel> _toplantilar = [];
  List<ToplantiModel> get toplantilar => _toplantilar;

  ToplantiModel? _aktifToplanti;
  ToplantiModel? get aktifToplanti => _aktifToplanti;

  List<YkKararModel> _kararlar = [];
  List<YkKararModel> get kararlar => _kararlar;

  List<YkKararModel> _tumKararlar = [];
  List<YkKararModel> get tumKararlar => _tumKararlar;

  int _aktifKararIndex = 0;
  int get aktifKararIndex => _aktifKararIndex;

  YkKararModel? get aktifKarar =>
      _kararlar.isNotEmpty && _aktifKararIndex < _kararlar.length
          ? _kararlar[_aktifKararIndex]
          : null;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isParsing = false;
  bool get isParsing => _isParsing;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ═══════════════════════════════════════════════════════════
  // TOPLANTI İŞLEMLERİ
  // ═══════════════════════════════════════════════════════════

  /// Tüm toplantıları yükler.
  Future<void> loadToplantilar() async {
    _isLoading = true;
    notifyListeners();
    try {
      _toplantilar = await _service.toplantiGetAll();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Toplantılar yüklenemedi: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toplantı seçer ve kararlarını yükler.
  Future<void> selectToplanti(ToplantiModel toplanti) async {
    _aktifToplanti = toplanti;
    _aktifKararIndex = 0;
    notifyListeners();
    await loadKararlar(toplanti.id);
  }

  /// Yeni toplantı oluşturur.
  Future<void> createToplanti({
    required String toplantiTarihi,
    required String toplantiNo,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final model = ToplantiModel(
        id: '',
        toplantiTarihi: toplantiTarihi,
        toplantiNo: toplantiNo,
      );
      await _service.toplantiCreate(model);
      await loadToplantilar();
    } catch (e) {
      _errorMessage = 'Toplantı oluşturulamadı: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toplantı durumunu günceller.
  Future<void> updateToplantiDurum(String toplantiId, ToplantiDurum durum) async {
    await _service.toplantiUpdate(toplantiId, {'durum': durum.value});
    await loadToplantilar();
    if (_aktifToplanti?.id == toplantiId) {
      _aktifToplanti = _toplantilar.firstWhere((t) => t.id == toplantiId);
      notifyListeners();
    }
  }

  /// Toplantı siler.
  Future<void> deleteToplanti(String toplantiId) async {
    await _service.toplantiDelete(toplantiId);
    if (_aktifToplanti?.id == toplantiId) {
      _aktifToplanti = null;
      _kararlar = [];
    }
    await loadToplantilar();
  }

  // ═══════════════════════════════════════════════════════════
  // KARAR İŞLEMLERİ
  // ═══════════════════════════════════════════════════════════

  /// Aktif toplantının kararlarını yükler.
  Future<void> loadKararlar(String toplantiId) async {
    _isLoading = true;
    notifyListeners();
    try {
      _kararlar = await _service.kararGetByToplanti(toplantiId);
      _aktifKararIndex = 0;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Kararlar yüklenemedi: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tüm kararları (Arşiv için) yükler.
  Future<void> loadTumKararlar() async {
    _isLoading = true;
    notifyListeners();
    try {
      _tumKararlar = await _service.kararGetAll();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Arşiv yüklenemedi: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Karar indeksini değiştirir.
  void selectKarar(int index) {
    if (index >= 0 && index < _kararlar.length) {
      _aktifKararIndex = index;
      notifyListeners();
    }
  }

  /// Karar alanını günceller.
  void updateKararField(String field, dynamic value) {
    if (aktifKarar == null) return;
    final karar = aktifKarar!;

    YkKararModel updated;
    switch (field) {
      case 'baslik':
        updated = karar.copyWith(baslik: value as String);
        break;
      case 'kararMetni':
        updated = karar.copyWith(kararMetni: value as String);
        break;
      case 'birimAd':
        updated = karar.copyWith(birimAd: value as String);
        break;
      case 'birimEvrakTarihi':
        updated = karar.copyWith(birimEvrakTarihi: value as String);
        break;
      case 'birimEvrakSayisi':
        updated = karar.copyWith(birimEvrakSayisi: value as String);
        break;
      case 'birimKurulTarihi':
        updated = karar.copyWith(birimKurulTarihi: value as String);
        break;
      case 'birimToplantiSayi':
        updated = karar.copyWith(birimToplantiSayi: value as String);
        break;
      case 'birimKararNo':
        updated = karar.copyWith(birimKararNo: value as String);
        break;
      case 'tur':
        updated = karar.copyWith(tur: value as YkKararTuru);
        break;
      default:
        return;
    }

    _kararlar[_aktifKararIndex] = updated;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // TABLO VERİLERİ (YAPISAL VERİ)
  // ═══════════════════════════════════════════════════════════

  /// Tabloya yeni satır ekler.
  void addTabloSatiri(Map<String, dynamic> row) {
    if (aktifKarar == null) return;
    final yeniTablo = List<Map<String, dynamic>>.from(aktifKarar!.tabloVerileri);
    yeniTablo.add(row);
    _kararlar[_aktifKararIndex] = aktifKarar!.copyWith(tabloVerileri: yeniTablo);
    notifyListeners();
  }

  /// Tablo satırını günceller.
  void updateTabloSatiri(int rowIndex, String field, dynamic value) {
    if (aktifKarar == null) return;
    final yeniTablo = List<Map<String, dynamic>>.from(
      aktifKarar!.tabloVerileri.map((r) => Map<String, dynamic>.from(r)),
    );
    if (rowIndex >= 0 && rowIndex < yeniTablo.length) {
      yeniTablo[rowIndex][field] = value;
      _kararlar[_aktifKararIndex] = aktifKarar!.copyWith(tabloVerileri: yeniTablo);
      notifyListeners();
    }
  }

  /// Tablo satırını siler.
  void removeTabloSatiri(int rowIndex) {
    if (aktifKarar == null) return;
    final yeniTablo = List<Map<String, dynamic>>.from(aktifKarar!.tabloVerileri);
    if (rowIndex >= 0 && rowIndex < yeniTablo.length) {
      yeniTablo.removeAt(rowIndex);
      _kararlar[_aktifKararIndex] = aktifKarar!.copyWith(tabloVerileri: yeniTablo);
      notifyListeners();
    }
  }

  /// Tablo verilerini topluca günceller.
  void setTabloVerileri(List<Map<String, dynamic>> veriler) {
    if (aktifKarar == null) return;
    _kararlar[_aktifKararIndex] = aktifKarar!.copyWith(tabloVerileri: veriler);
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // KAYDETME
  // ═══════════════════════════════════════════════════════════

  /// Aktif kararı Firestore'a kaydeder.
  Future<void> saveKarar() async {
    if (aktifKarar == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      if (aktifKarar!.id.isEmpty) {
        await _service.kararCreate(aktifKarar!);
      } else {
        await _service.kararUpdate(aktifKarar!.id, aktifKarar!.toMap());
      }
      if (_aktifToplanti != null) {
        await loadKararlar(_aktifToplanti!.id);
      }
    } catch (e) {
      _errorMessage = 'Karar kaydedilemedi: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tüm kararları Firestore'a kaydeder.
  Future<void> saveAllKararlar() async {
    _isLoading = true;
    notifyListeners();
    try {
      for (final karar in _kararlar) {
        if (karar.id.isEmpty) {
          await _service.kararCreate(karar);
        } else {
          await _service.kararUpdate(karar.id, karar.toMap());
        }
      }
      if (_aktifToplanti != null) {
        await loadKararlar(_aktifToplanti!.id);
      }
    } catch (e) {
      _errorMessage = 'Kararlar kaydedilemedi: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Kararı siler.
  Future<void> deleteKarar(String kararId) async {
    await _service.kararDelete(kararId);
    if (_aktifToplanti != null) {
      await loadKararlar(_aktifToplanti!.id);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // AI PARSE (YAPISAL JSON ÇIKTI)
  // ═══════════════════════════════════════════════════════════

  /// PDF dosyasından metin çıkarıp AI ile parse eder.
  Future<void> parsePdfWithAI(Uint8List pdfBytes) async {
    _isParsing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final document = PdfDocument(inputBytes: pdfBytes);
      final extractor = PdfTextExtractor(document);
      final rawText = extractor.extractText();
      document.dispose();
      
      final text = _sanitizeExtractedText(rawText);
      
      if (text.trim().isEmpty) {
        throw Exception('PDF\'ten metin çıkarılamadı veya dosya boş.');
      }
      
      // Çıkarılan metni normal parseWithAI'ye gönder
      await parseWithAI(text);
    } catch (e) {
      _errorMessage = 'PDF okuma hatası: $e';
      _isParsing = false;
      notifyListeners();
      throw Exception(_errorMessage);
    }
  }

  /// Dışarıdan gelen kararı yükler ve parse eder (Genel Arşiv için).
  Future<void> uploadExternalKarar(
    Uint8List pdfBytes,
    String fileName, {
    required String birimId,
    required String birimAd,
  }) async {
    _isParsing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final document = PdfDocument(inputBytes: pdfBytes);
      final extractor = PdfTextExtractor(document);
      final rawText = extractor.extractText();
      document.dispose();
      
      final text = _sanitizeExtractedText(rawText);
      
      if (text.trim().isEmpty) {
        throw Exception('PDF\'ten metin çıkarılamadı veya dosya boş.');
      }
      
      // Dış kaynak için özel bir "Toplantı No" ve tarih kullanalım.
      final tarih = DateTime.now().toLocal().toString().split(' ')[0].replaceAll('-', '.');
      
      // Parse işlemi için geçici bir toplantı bilgisi kullanarak AI'a gönderiyoruz
      // Normal parseWithAI mevcut _aktifToplanti'ye ihtiyaç duyar, bu yüzden kendi parse metodumuzu çağıracağız.
      await _parseAndSaveExternal(text, fileName, tarih, birimId: birimId, birimAd: birimAd);
      
    } catch (e) {
      _errorMessage = 'Dış Karar yükleme hatası: $e';
      _isParsing = false;
      notifyListeners();
      throw Exception(_errorMessage);
    }
  }

  /// Sadece dış kararlar için parse ve kaydetme metodu.
  Future<void> _parseAndSaveExternal(
    String rawText,
    String fileName,
    String tarih, {
    required String birimId,
    required String birimAd,
  }) async {
    try {
      final ayarlar = await _ayarlarService.getAyarlar();
      final prompt = _buildKararParsePrompt(rawText, 'Dış-Kaynak', tarih);

      List<Map<String, dynamic>> parsedKararlar = [];

      if (ayarlar.geminiApiKey.isNotEmpty) {
        try {
          final model = GenerativeModel(
            model: 'gemini-2.0-flash',
            apiKey: ayarlar.geminiApiKey,
          );
          final response = await model.generateContent([Content.text(prompt)]);
          final text = response.text?.trim() ?? '';
          parsedKararlar = _parseJson(text);
        } catch (e) {
          debugPrint('Gemini hatası: $e');
        }
      }

      if (parsedKararlar.isEmpty && ayarlar.deepseekApiKey.isNotEmpty) {
        // Deepseek fallback...
        // ... (Bu örnekte hızlıca sadece gemini veya boş dönme ele alınabilir)
      }

      if (parsedKararlar.isEmpty) {
        // AI parse edemediyse manuel olarak sadece bir taslak oluştur.
        parsedKararlar.add({
           'baslik': fileName,
           'kararMetni': rawText,
           'birimAd': birimAd,
           'tur': 'diger',
        });
      }

      for (final parsed in parsedKararlar) {
        final karar = YkKararModel(
          id: '',
          toplantiId: 'external',
          toplantiNo: 'Dış-Kaynak',
          kararNo: 'DS-${DateTime.now().millisecondsSinceEpoch}',
          kararTarihi: tarih,
          birimId: birimId,
          birimAd: parsed['birimAd'] ?? birimAd,
          tur: YkKararTuru.fromString(parsed['tur'] ?? 'diger'),
          baslik: parsed['baslik'] ?? fileName,
          kararMetni: parsed['kararMetni'] ?? rawText,
          isExternal: true,
          tabloVerileri: (parsed['tabloVerileri'] as List<dynamic>? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
          birimEvrakTarihi: parsed['birimEvrakTarihi'] ?? '',
          birimEvrakSayisi: parsed['birimEvrakSayisi'] ?? '',
          birimKurulTarihi: parsed['birimKurulTarihi'] ?? '',
          birimToplantiSayi: parsed['birimToplantiSayi'] ?? '',
          birimKararNo: parsed['birimKararNo'] ?? '',
          sablonTuru: parsed['sablonTuru'] as int?,
        );

        await _service.kararCreate(karar);
      }

      await loadTumKararlar(); // Arşivi yenile
      _errorMessage = null;
    } catch (e) {
      throw Exception('Parse ve Kaydetme hatası: $e');
    }
  }

  /// Ham metni AI ile parse edip yapısal kararlar ve tablolar oluşturur.
  Future<void> parseWithAI(String rawText) async {
    if (_aktifToplanti == null) {
      _errorMessage = 'Lütfen önce bir toplantı seçin.';
      notifyListeners();
      throw Exception(_errorMessage);
    }

    _isParsing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final ayarlar = await _ayarlarService.getAyarlar();
      final toplantiNo = _aktifToplanti!.toplantiNo;
      final toplantiTarihi = _aktifToplanti!.toplantiTarihi;
      final prompt = _buildKararParsePrompt(rawText, toplantiNo, toplantiTarihi);

      List<Map<String, dynamic>> parsedKararlar = [];

      // 1. GEMINI DENEMESİ
      if (ayarlar.geminiApiKey.isNotEmpty) {
        try {
          final model = GenerativeModel(
            model: 'gemini-2.0-flash',
            apiKey: ayarlar.geminiApiKey,
          );
          final response = await model.generateContent([Content.text(prompt)]);
          final text = response.text?.trim() ?? '';
          parsedKararlar = _parseJson(text);
        } catch (e) {
          debugPrint('Gemini hatası: $e');
        }
      }

      // 2. DEEPSEEK YEDEK
      if (parsedKararlar.isEmpty && ayarlar.deepseekApiKey.isNotEmpty) {
        try {
          final apiUrl = ayarlar.deepseekApiUrl.isEmpty ? 'https://api.deepseek.com/' : ayarlar.deepseekApiUrl;
          final url = apiUrl.endsWith('/')
              ? '${apiUrl}chat/completions'
              : '${apiUrl}/chat/completions';
          final modelName = ayarlar.deepseekModel.isEmpty
              ? 'deepseek-chat'
              : ayarlar.deepseekModel;

          final response = await http.post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'Authorization': 'Bearer ${ayarlar.deepseekApiKey}',
            },
            body: jsonEncode({
              'model': modelName,
              'messages': [
                {
                  'role': 'system',
                  'content':
                      'You are a precise YK Karar (Board Decision) parsing AI that outputs strictly in JSON.',
                },
                {'role': 'user', 'content': prompt}
              ],
              'temperature': 0.1,
            }),
          );

          if (response.statusCode >= 200 && response.statusCode < 300) {
            final decoded = jsonDecode(utf8.decode(response.bodyBytes));
            final content =
                decoded['choices']?[0]?['message']?['content'] ?? '';
            parsedKararlar = _parseJson(content);
          }
        } catch (e) {
          debugPrint('DeepSeek hatası: $e');
        }
      }

      if (parsedKararlar.isEmpty) {
        throw Exception(
            'Yapay zeka belgeyi okuyamadı. Lütfen API anahtarlarını kontrol edin.');
      }

      // Parse edilen verileri YkKararModel listesine dönüştür
      final yeniKararlar = <YkKararModel>[];
      int siraNo = _kararlar.length;

      for (final parsed in parsedKararlar) {
        siraNo++;
        final kararNo = '$toplantiNo-${siraNo.toString().padLeft(2, '0')}';
        final tabloData = parsed['tabloVerileri'] as List<dynamic>? ?? [];

        yeniKararlar.add(YkKararModel(
          id: '',
          toplantiId: _aktifToplanti!.id,
          toplantiNo: toplantiNo,
          kararNo: kararNo,
          kararTarihi: toplantiTarihi,
          birimId: '',
          birimAd: parsed['birimAd'] ?? '',
          tur: YkKararTuru.fromString(parsed['tur'] ?? 'diger'),
          baslik: parsed['baslik'] ?? '',
          kararMetni: parsed['kararMetni'] ?? '',
          tabloVerileri: tabloData
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList(),
          birimEvrakTarihi: parsed['birimEvrakTarihi'] ?? '',
          birimEvrakSayisi: parsed['birimEvrakSayisi'] ?? '',
          birimKurulTarihi: parsed['birimKurulTarihi'] ?? '',
          birimToplantiSayi: parsed['birimToplantiSayi'] ?? '',
          birimKararNo: parsed['birimKararNo'] ?? '',
          sablonTuru: parsed['sablonTuru'] as int?,
        ));
      }

      _kararlar.addAll(yeniKararlar);
      _aktifKararIndex = _kararlar.length - yeniKararlar.length;
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
      throw Exception(_errorMessage);
    } finally {
      _isParsing = false;
      notifyListeners();
    }
  }

  /// AI'a gönderilecek prompt (YAPISAL JSON çıktısı ister, Markdown tablo ASLA).
  String _buildKararParsePrompt(
      String rawText, String toplantiNo, String toplantiTarihi) {
    return '''
Aşağıdaki metin bir üniversite biriminden gelen üst yazı / karar belgesidir.
Bu metni analiz et ve içindeki tüm kararları tek tek JSON nesneleri olarak çıkar.

ÇOK ÖNEMLİ KURALLAR:
1. SADECE JSON ÇIKTISI VER. Yorum yapma, açıklama ekleme, markdown (```json) ekleme!
2. ASLA Markdown tablo (pipe | ile tablo) OLUŞTURMA!
3. DİKKAT: Metin içinde kişilerin, tutarların, puanların veya bütçe kalemlerinin olduğu alt alta listelenmiş veriler veya bir 'Faaliyet Cetveli', 'Dağıtım Tablosu' varsa, bunları KESİNLİKLE "tabloVerileri" alanına JSON dizisi olarak koy. Tabloyu atlama!
4. Matematiksel hesaplamaları YAPMA, sadece metindeki sayıları aynen aktar.
5. "kararMetni" alanına tablodaki verileri KOYMA, sadece düz kararı yaz. Tablo verileri SADECE "tabloVerileri" içinde olmalı.

Her karar için şu yapıyı kullan:
[
  {
    "sablonTuru": 1-9 arası hangi şablona uyduğu (1=Danışmanlık Dağıtım, 2=Danışmanlık Görevlendirme, 3=Sanayi İşbirliği, 4=Bütçe Aktarım, 5=Kurs Ücreti, 6=Diş Hekimliği Ek Ödeme, 7=Fiyat Tarifesi, 8=Bütçe Onay, 9=Mal Satış),
    "tur": "danismanlik|danismanlik_gorevlendirme|sanayi_isbirligi|butce_aktarim|kurs_ucreti|dis_hekimligi|fiyat_tarifesi|butce_onay|mal_satis|diger",
    "baslik": "Kararın kısa başlığı",
    "kararMetni": "Şablona göre doldurulmuş TAM karar metni (düz metin, tablo yok)",
    "birimAd": "Talebi gönderen birim adı",
    "birimEvrakTarihi": "Birim evrak tarihi",
    "birimEvrakSayisi": "Birim evrak sayısı",
    "birimKurulTarihi": "Birim kurul tarihi",
    "birimToplantiSayi": "Birim toplantı sayısı",
    "birimKararNo": "Birim karar numarası",
    "tabloVerileri": [
      {
        "adiSoyadi": "Prof. Dr. Ahmet Yılmaz",
        "puani": 85,
        "katsayi": 1.5,
        "brutHakedis": 12750.00
      }
    ]
  }
]

TABLO VERİLERİ İÇİN ALAN İSİMLERİ (Şablona göre değişir):
- Şablon 1,5 (Faaliyet Cetveli): adiSoyadi, unvan, puani, katsayi, brutHakedis
- Şablon 4 (Bütçe Aktarım): kalemAdi, mevcutButce, artirilacak, eksiltilecek, yeniButce
- Şablon 6 (Diş Hekimliği): adiSoyadi, gorev, katkiPayi, mesaiDisi, toplam

YK Toplantı Tarihi: $toplantiTarihi
YK Toplantı No: $toplantiNo

Analiz Edilecek Metin:
$rawText
''';
  }

  /// JSON parse helper.
  List<Map<String, dynamic>> _parseJson(String text) {
    try {
      String cleanText = text.trim();
      if (cleanText.startsWith('```json')) {
        cleanText = cleanText.substring(7);
      } else if (cleanText.startsWith('```')) {
        cleanText = cleanText.substring(3);
      }
      if (cleanText.endsWith('```')) {
        cleanText = cleanText.substring(0, cleanText.length - 3);
      }
      cleanText = cleanText.trim();

      final startIndex = cleanText.indexOf('[');
      final endIndex = cleanText.lastIndexOf(']');

      if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
        cleanText = cleanText.substring(startIndex, endIndex + 1);
        final List<dynamic> decodedList = jsonDecode(cleanText);
        return List<Map<String, dynamic>>.from(decodedList);
      }
    } catch (e) {
      debugPrint('JSON Parse hatası: $e');
    }
    return [];
  }

  /// PDF'ten çıkarılan bozuk karakterleri temizler
  String _sanitizeExtractedText(String text) {
    final lines = text.split('\n');
    final cleanLines = <String>[];
    for (var line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      
      final replacementCount = trimmed.codeUnits.where((char) => char == 0xFFFD || char == 65533).length;
      final totalLength = trimmed.length;
      if (totalLength > 0 && (replacementCount / totalLength) > 0.3) continue;
      
      var cleanLine = trimmed.replaceAll('\uFFFD', '').trim();
      if (cleanLine.isEmpty || RegExp(r'^[-_+|=*#\s]+$').hasMatch(cleanLine)) continue;
      
      cleanLines.add(cleanLine);
    }
    return cleanLines.join('\n').trim();
  }

  /// Manuel yeni karar ekler (boş şablon).
  void addManuelKarar() {
    if (_aktifToplanti == null) return;
    final toplantiNo = _aktifToplanti!.toplantiNo;
    final siraNo = _kararlar.length + 1;
    final kararNo = '$toplantiNo-${siraNo.toString().padLeft(2, '0')}';

    final yeniKarar = YkKararModel(
      id: '',
      toplantiId: _aktifToplanti!.id,
      toplantiNo: toplantiNo,
      kararNo: kararNo,
      kararTarihi: _aktifToplanti!.toplantiTarihi,
      birimId: '',
      birimAd: '',
      tur: YkKararTuru.diger,
      baslik: '',
      kararMetni: '',
    );

    _kararlar.add(yeniKarar);
    _aktifKararIndex = _kararlar.length - 1;
    notifyListeners();
  }
}
