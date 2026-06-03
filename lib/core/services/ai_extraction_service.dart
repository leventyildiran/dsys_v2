import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/sistem_ayarlari_model.dart';
import 'sistem_ayarlari_service.dart';

class AIExtractionService {
  final SistemAyarlariService _ayarlarService = SistemAyarlariService();

  Future<List<Map<String, dynamic>>> extractBatchData(String rawBatchText) async {
    final ayarlar = await _ayarlarService.getAyarlar();
    
    // Prompt hazırlığı
    final prompt = _buildPrompt(rawBatchText);

    // 1. GEMINI DENEMESİ
    if (ayarlar.geminiApiKey.isNotEmpty) {
      try {
        print('Gemini API ile ayrıştırma deneniyor...');
        final model = GenerativeModel(
          model: 'gemini-1.5-flash',
          apiKey: ayarlar.geminiApiKey,
        );
        final response = await model.generateContent([Content.text(prompt)]);
        final text = response.text?.trim() ?? '';
        
        final parsed = _parseJson(text);
        if (parsed.isNotEmpty) {
          for (var p in parsed) {
            p['parsedBy'] = 'Tier 1 - Gemini (Başarılı)';
          }
          return parsed;
        }
      } catch (e) {
        print('Gemini hatası: $e');
      }
    }

    // 2. DEEPSEEK DENEMESİ (Fallback)
    if (ayarlar.deepseekApiKey.isNotEmpty && ayarlar.deepseekApiUrl.isNotEmpty) {
      try {
        print('DeepSeek API ile ayrıştırma deneniyor...');
        final url = ayarlar.deepseekApiUrl.endsWith('/') ? '\${ayarlar.deepseekApiUrl}chat/completions' : '\${ayarlar.deepseekApiUrl}/chat/completions';
        final modelName = ayarlar.deepseekModel.isEmpty ? 'deepseek-chat' : ayarlar.deepseekModel;
        
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer \${ayarlar.deepseekApiKey}',
          },
          body: jsonEncode({
            'model': modelName,
            'messages': [
              {'role': 'system', 'content': 'You are a precise invoice parsing AI that outputs strictly in JSON.'},
              {'role': 'user', 'content': prompt}
            ],
            'temperature': 0.1,
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          final content = decoded['choices']?[0]?['message']?['content'] ?? '';
          
          final parsed = _parseJson(content);
          if (parsed.isNotEmpty) {
            for (var p in parsed) {
              p['parsedBy'] = 'Tier 2 - DeepSeek Fallback (Başarılı)';
            }
            return parsed;
          }
        } else {
          print('DeepSeek API Hatası: \${response.statusCode} - \${response.body}');
        }
      } catch (e) {
        print('DeepSeek hatası: $e');
      }
    }

    // Tüm AI denemeleri başarısızsa boş dön
    throw Exception('Yapay zeka faturayı okuyamadı. Lütfen API anahtarlarını kontrol edin.');
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
    "vergiDairesi": "Vergi Dairesi (varsa)",
    "vergiNo": "Vergi veya TC No (varsa)",
    "melbesNo": "Melbes numarası (varsa)",
    "numuneNo": "Numune Numarası (varsa)",
    "numuneAciklamasi": "Varsa numune açıklaması",
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
2. Tarih veya diğer önemsiz verileri ekleme.
3. Faturada birden fazla müşteri verisi varsa liste içine birden fazla obje koy.
4. "kalemler" listesinde, "fiyat" kısmına virgülleri noktaya çevirerek bir Number koy (örn: 1540.50). 

Ham Fatura Metni:
$rawText
''';
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
      
      int startIndex = cleanText.indexOf('[');
      int endIndex = cleanText.lastIndexOf(']');
      
      if (startIndex != -1 && endIndex != -1 && endIndex >= startIndex) {
        cleanText = cleanText.substring(startIndex, endIndex + 1);
        final List<dynamic> decodedList = jsonDecode(cleanText);
        return List<Map<String, dynamic>>.from(decodedList);
      }
    } catch (e) {
      print('JSON Parse hatası: $e');
    }
    return [];
  }
}
