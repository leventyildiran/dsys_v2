import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'sistem_ayarlari_service.dart';

class AIExtractionService {
  final SistemAyarlariService _ayarlarService = SistemAyarlariService();
  static const List<String> _geminiModelFallbacks = [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
    'gemini-3.5-flash-lite',
  ];

  /// Gemini API'ye model fallback zinciriyle istek gönderir.
  ///
  /// - Media (PDF) timeout: 120 saniye
  /// - Text-only timeout: 30 saniye
  /// - 503/UNAVAILABLE hatalarında aynı modeli 2s bekleyip 1 kez daha dener.
  Future<String?> _runGeminiWithFallback({
    required String apiKey,
    required List<Part> parts,
    String? preferredModel,
  }) async {
    final modelOrder = <String>[];
    String? cleanPreferred = preferredModel?.trim();
    if (cleanPreferred != null &&
        (cleanPreferred.isEmpty ||
            cleanPreferred == 'gemini-flash-latest' ||
            cleanPreferred == 'gemini-2.5-flash' ||
            cleanPreferred == 'gemini-2.0-flash' ||
            cleanPreferred == 'gemini-1.5-flash')) {
      cleanPreferred = 'gemini-3.6-flash'; // 2026 standard
    }

    if (cleanPreferred != null && cleanPreferred.isNotEmpty) {
      modelOrder.add(cleanPreferred);
    }
    for (final m in _geminiModelFallbacks) {
      if (!modelOrder.contains(m)) modelOrder.add(m);
    }

    final hasMedia = parts.any((p) => p is DataPart);
    final modelTimeout = Duration(seconds: hasMedia ? 120 : 30);

    Object? sonHata;
    for (final modelName in modelOrder) {
      // Her model için en fazla 2 deneme (ilk + 503 retry)
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          debugPrint(
            'Gemini API ($modelName) deneme ${attempt + 1}/2 '
            '(timeout: ${modelTimeout.inSeconds}s)...',
          );
          final model = GenerativeModel(model: modelName, apiKey: apiKey);
          final response = await model
              .generateContent([Content.multi(parts)])
              .timeout(modelTimeout);
          final text = response.text?.trim() ?? '';
          if (text.isNotEmpty) return text;
          break; // Boş döndüyse retry anlamsız, sonraki modele geç
        } catch (e) {
          sonHata = e;
          final err = e.toString();
          final is503 = err.contains('503') ||
              err.contains('UNAVAILABLE') ||
              err.contains('high demand') ||
              err.contains('overloaded');
          if (is503 && attempt == 0) {
            debugPrint(
              '$modelName 503/aşırı yoğunluk — 2 saniye bekleyip tekrar deneniyor...',
            );
            await Future.delayed(const Duration(seconds: 2));
            continue; // Aynı modeli bir kez daha dene
          }
          debugPrint('$modelName hatası: $e');
          break; // 503 değilse veya 2. denemeyse sonraki modele geç
        }
      }
      await Future.delayed(const Duration(milliseconds: 150));
    }
    if (sonHata != null) {
      throw Exception(sonHata.toString());
    }
    return null;
  }

  /// Fatura PDF/metin verisini Gemini Vision ile doğrudan ayrıştırır.
  Future<List<Map<String, dynamic>>> extractBatchData(
    String rawBatchText, {
    Uint8List? pdfBytes,
  }) async {
    final ayarlar = await _ayarlarService.getAyarlar();
    final prompt = _buildPrompt(rawBatchText);

    Object? geminiHata;
    if (ayarlar.geminiApiKey.isNotEmpty) {
      try {
        final contentParts = <Part>[];
        if (pdfBytes != null && pdfBytes.isNotEmpty) {
          contentParts.add(DataPart('application/pdf', pdfBytes));
        }
        contentParts.add(TextPart(prompt));
        final text = await _runGeminiWithFallback(
          apiKey: ayarlar.geminiApiKey,
          preferredModel: ayarlar.geminiModel,
          parts: contentParts,
        );
        final parsed = _parseJson(text ?? '');
        if (parsed.isNotEmpty) {
          for (var p in parsed) {
            p['parsedBy'] = 'Sistem okuma';
          }
          return parsed;
        }
        geminiHata = 'Belge anlaşılamadı, veri formatı hatalı.';
      } catch (e) {
        geminiHata = e;
        debugPrint('Ayrıştırma hatası: $e');
      }
    }

    if (geminiHata != null) {
      final hataMesaji = geminiHata.toString();
      if (hataMesaji.contains('not found') || hataMesaji.contains('404')) {
        throw Exception(
          'Okuma servisi API anahtarı bu modellere erişemiyor. '
          'Sistem Ayarları üzerinden kontrol edin.',
        );
      }
      throw Exception(
        'Fatura okunamadı. Lütfen tekrar deneyin.\n$hataMesaji',
      );
    }

    throw Exception(
      'Sistem faturayı okuyamadı. Sistem Ayarlarından bağlantıyı kontrol edin.',
    );
  }

  String _buildPrompt(String rawText) {
    return '''
Aşağıdaki metin ham bir analiz faturası / makbuzu dökümüdür.
Lütfen bu metinden faturadaki kalemleri ve temel bilgileri çıkart.

Benden beklenen JSON formatı SADECE aşağıdaki gibi bir LİSTE (Array) olmalıdır:
[
  {
    "id": "Rastgele benzersiz bir ID (1, 2, 3 gibi)",
    "firmaAdi": "Müşterinin / Firmanın tam adı",
    "vergiDairesi": "Vergi Dairesi",
    "vergiNo": "Vergi veya TC No",
    "tarih": "Fatura veya İşlem Tarihi (DD.MM.YYYY vb. formatta)",
    "irsaliyeTarihi": "İrsaliye Tarihi (DD.MM.YYYY vb. formatta)",
    "irsaliyeNo": "İrsaliye Numarası",
    "melbesNo": "Melbes numarası (yalnızca numara, kurum adı hariç)",
    "melbesKurumOnEki": "MELBES satırındaki kurum/bakanlık adı (Melbes kelimesinden önceki kısım)",
    "numuneNo": "Numune Numarası",
    "numuneAciklamasi": "Varsa numune açıklaması",
    "tahminiBirim": "Belgeden anlaşılan Şube/Birim adı (TÖMER, UBATAM, TARIMSAL, SATIN ALMA vb.)",
    "hizmetTipi": "Aşağıdaki kurallara göre: EĞİTİM|DANIŞMANLIK|SATIŞ|ANALİZ|TEKSTİL_TASARIM|DİĞER",
    "kursAdi": "kurs/program adı (TÖMER/USEM ise)",
    "kurNo": (Sayısal, varsa),
    "odemeTipi": "KUR_FATURA|STS_FATURA|KATKI_PAYI|AVANS|DİĞER",
    "ytbOgrencisi": (true/false, kursiyer YTB'liyse),
    "urunTuru": "YUMURTA|BAL|TAVUK|DİĞER (tarımsal ise)",
    "tedarikYontemi": "TEK_KAYNAK|İHALE|PAZARLIK|DİĞER (satın alma ise)",
    "donem": "Ocak 2025 gibi dönem bilgisi",
    "aciklama": "serbest genel açıklama",
    "matrah": KDV Hariç toplam tutar (Sayısal),
    "kdvTutari": KDV tutarı (Sayısal, eğer 0 ise kdvMuaf demektir),
    "genelToplam": KDV dahil toplam tutar (Sayısal),
    "isKdvMuaf": (KDV 0 ise true, değilse false),
    "kalemler": [
      {
        "cinsi": "Kalem Adı",
        "miktar": Adet (sayısal),
        "fiyat": Birim fiyat veya o kalemin satır tutarı (sayısal)
      }
    ]
  }
]

ÖNEMLİ KURALLAR:
1. SADECE JSON ÇIKTISI VER. Yorum yapma, açıklamalar ekleme, markdown tickleri (```json) ekleme veya başa/sona yazı koyma!
2. Faturadaki HER BİR HİZMET VEYA ÜRÜN KALEMİNİ eksiksiz olarak 'kalemler' dizisine ayrı bir obje olarak ekle. Hiçbir kalemi atlama veya birleştirme. Faturada ne kadar kalem varsa hepsi dizide olmalı!
3. Faturada birden fazla müşteri verisi varsa liste içine birden fazla obje koy.
4. "kalemler" listesinde, "fiyat" kısmına virgülleri noktaya çevirerek bir Number koy (örn: 1540.50). 
5. DİKKAT: Eğer bir alana dair veri (örneğin Melbes No, Numune No, İrsaliye No) belgede YOKSA, KESİNLİKLE uydurma yapma ve o alanı boş string ("") olarak bırak. Sadece metinde net olarak geçen değerleri kullan.
6. Kurum/bakanlık adını (ör. "Çevre, Şehircilik ve İklim Değişikliği Bakanlığı") kalemler dizisine EKLEME. Bu bilgi yalnızca "melbesKurumOnEki" alanına yazılmalı; kalemler yalnızca gerçek analiz/hizmet satırlarını içermeli.
7. "hizmetTipi" alanını aşağıdaki mantığa göre belirle:
   - Metinde "Analiz", "Test", "Ölçüm", "Numune", "Deney" geçiyorsa: ANALİZ
   - Metinde "Eğitim", "Kurs", "Ders", "TÖMER", "Sertifika", "Kayıt" geçiyorsa: EĞİTİM
   - Metinde "Yumurta", "Tavuk", "Bal", "Süt", "Satış", "İhale" geçiyorsa: SATIŞ
   - Metinde "Danışmanlık", "Proje", "Rapor" geçiyorsa: DANIŞMANLIK
   - Metinde "Tasarım", "Tekstil", "Kumaş", "Deri" geçiyorsa: TEKSTİL_TASARIM
   - Hiçbiri değilse: DİĞER

Ham Fatura Metni:
$rawText
''';
  }

  /// Uzun Excel listeleri (örn: 200 kişilik kursiyer listesi) için sadece başlık haritası çıkarır
  Future<Map<String, dynamic>> extractExcelMapping(
    String excelCsvPreview,
  ) async {
    final ayarlar = await _ayarlarService.getAyarlar();

    final prompt = '''
Aşağıda bir Excel dosyasının ilk 15 satırının CSV dökümü bulunuyor.
Bu dosya bir müşteri/kursiyer listesi olabilir. Lütfen satırlara bakarak, hangi sütunun hangi faturasal veriye denk geldiğini bul.
Sütun endeksleri 0'dan başlar (Yani ilk sütun 0'dır).

Çıktın SADECE JSON olacak ve şu formatta olacak:
{
  "isBatchList": true,
  "startRowIndex": 1, // Verilerin gerçekte başladığı satır (başlıkları atlayarak)
  "mapping": {
    "firmaAdi": 0,    // Müşteri Adı / Firma Adının olduğu sütun numarası
    "tcVkn": 1,       // TC Kimlik / VKN'nin olduğu sütun numarası (yoksa -1)
    "matrah": 4,      // KDV hariç tutarın (veya ödenen toplam tutarın) olduğu sütun numarası
    "kdvOrani": 6,    // KDV oranının (%10 vb.) olduğu sütun numarası (yoksa -1)
    "miktar": 4,      // Ürün miktarı/adet sütun numarası (yoksa -1)
    "fiyat": 3,       // Birim fiyatın olduğu sütun numarası (yoksa -1)
    "cinsi": -1       // Ürün veya hizmet adının (örn: Yumurta) olduğu sütun numarası (yoksa -1)
  }
}

Eğer bu dosya bir toplu müşteri listesi değil de, düz bir fatura şablonuysa "isBatchList": false döndür. SADECE JSON döndür.

CSV Önizleme:
$excelCsvPreview
''';

    if (ayarlar.geminiApiKey.isNotEmpty) {
      try {
        final text = await _runGeminiWithFallback(
          apiKey: ayarlar.geminiApiKey,
          preferredModel: ayarlar.geminiModel,
          parts: [TextPart(prompt)],
        );
        final parsed = _parseJsonStrict(text ?? '');
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (e) {
        debugPrint('Mapping hatası: $e');
      }
    }

    // Fallback or not found
    return {"isBatchList": false};
  }

  dynamic _parseJsonStrict(String text) {
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
    try {
      return jsonDecode(cleanText);
    } catch (e) {
      return {};
    }
  }

  List<Map<String, dynamic>> _parseJson(String text) {
    try {
      String cleanText = text.trim();

      // Bazen LLM ```json ... ``` etiketleri ekler, onları temizle.
      if (cleanText.startsWith('```json')) {
        cleanText = cleanText.substring(7);
      } else if (cleanText.startsWith('```')) {
        cleanText = cleanText.substring(3);
      }

      if (cleanText.endsWith('```')) {
        cleanText = cleanText.substring(0, cleanText.length - 3);
      }

      cleanText = cleanText.trim();

      // 1. Durum: JSON Listesi [...]
      int startIndex = cleanText.indexOf('[');
      int endIndex = cleanText.lastIndexOf(']');

      if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
        final listStr = cleanText.substring(startIndex, endIndex + 1);
        final List<dynamic> decodedList = jsonDecode(listStr);
        return List<Map<String, dynamic>>.from(decodedList);
      }

      // 2. Durum: Tekil JSON Objesi {...}
      int objStart = cleanText.indexOf('{');
      int objEnd = cleanText.lastIndexOf('}');
      if (objStart != -1 && objEnd != -1 && objEnd >= objStart) {
        final objStr = cleanText.substring(objStart, objEnd + 1);
        final dynamic decodedObj = jsonDecode(objStr);
        if (decodedObj is Map<String, dynamic>) {
          return [decodedObj];
        }
      }
    } catch (e) {
      debugPrint('JSON Parse hatası: $e');
    }
    return [];
  }

  /// Yürütme Kurulu Kararı (YKK) metninden akademik personel ve faaliyet verilerini çeker
  Future<List<Map<String, dynamic>>> extractDanismanlikData(
    String rawKararText,
  ) async {
    final ayarlar = await _ayarlarService.getAyarlar();
    final prompt = _buildDanismanlikPrompt(rawKararText);

    if (ayarlar.geminiApiKey.isNotEmpty) {
      try {
        final text = await _runGeminiWithFallback(
          apiKey: ayarlar.geminiApiKey,
          preferredModel: ayarlar.geminiModel,
          parts: [TextPart(prompt)],
        );
        final parsed = _parseJson(text ?? '');
        if (parsed.isNotEmpty) {
          return parsed;
        }
      } catch (e) {
        debugPrint('Gemini danışmanlık hatası: $e');
      }
    }

    throw Exception(
      'Sistem kararı okuyamadı. Lütfen API anahtarını veya kararın metnini kontrol edin.',
    );
  }

  String _buildDanismanlikPrompt(String rawText) {
    return '''
Aşağıdaki metin bir Üniversite Yönetim/Yürütme Kurulu Kararı (YKK) metnidir.
Bu metin, genellikle bir 'Danışmanlık' veya 'Döner Sermaye Projesi' kapsamında akademisyenlerin hangi faaliyetleri kaç adet veya saat yaptığını gösterir.

Lütfen bu metinden akademisyenlerin listesini ve yaptıkları faaliyetleri çıkart.
Aynı kişinin birden fazla faaliyeti varsa, JSON içerisinde aynı kişinin ismini kullanarak farklı bir obje (satır) olarak ekle.

Benden beklenen JSON formatı SADECE aşağıdaki gibi bir LİSTE (Array) olmalıdır:
[
  {
    "adSoyad": "Öğretim elemanının unvanı ve adı soyadı (Örn: Öğr. Gör. Dr. Neslihan ÖPÖZ VURAL)",
    "unvan": "Kısa Unvan (Örn: Profesör, Doçent, Dr.Öğr.Üyesi, Öğr.Gör.Dr., Öğr.Gör., Arş.Gör.Dr., Arş.Gör.)",
    "faaliyetTuru": "Yapılan İşin Adı (Örn: Eğitim, Tasarım, 3 Boyutlu Görsel Hazırlama, Teknik Uygulama)",
    "faaliyetAdeti": Miktar (Saat veya Adet değeri, sayısal, örn: 15),
    "faaliyetTabanPuani": Metinde geçiyorsa o faaliyetin taban puanı (sayısal, örn: 20. Eğer metinde yazmıyorsa 0 ver),
    "mesaiIci": true veya false (Metinde 'mesai dışı' veya '%60 artırımlı' geçmiyorsa varsayılan olarak true ver)
  }
]

ÖNEMLİ KURALLAR:
1. SADECE JSON ÇIKTISI VER. Yorum yapma.
2. Unvan kısmını tam metinden süzüp standart kısa hallerinden birini (Profesör, Doçent, Dr.Öğr.Üyesi, Öğr.Gör.Dr., Öğr.Gör., Arş.Gör.Dr., Arş.Gör.) eşleştir.
3. Fiyat, para birimi, oran gibi verileri değil sadece FAALİYET ADETİ/SAATİ ve PUANI bilgilerini çek.

Ham Karar Metni:
$rawText
''';
  }
}
