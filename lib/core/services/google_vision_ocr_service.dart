import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Google Cloud Vision API ile taranmış PDF/görüntüden metin çıkarır.
/// Fatura modülünde Gemini Vision düştüğünde yedek OCR katmanıdır.
class GoogleVisionOcrService {
  static const int _minKabulMetinUzunlugu = 30;

  /// PDF içindeki gömülü JPEG sayfalarını OCR eder; metinleri birleştirir.
  Future<String> pdfdenMetinCikar({
    required Uint8List pdfBytes,
    required String apiKey,
    int maxSayfa = 8,
  }) async {
    if (apiKey.trim().isEmpty) return '';
    final gorseller = _pdfIciJpegleriCikar(pdfBytes, maxAdet: maxSayfa);
    if (gorseller.isEmpty) {
      debugPrint('[VisionOCR] PDF içinde JPEG bulunamadı.');
      return '';
    }

    final parcalar = <String>[];
    for (var i = 0; i < gorseller.length; i++) {
      final metin = await _gorseldenMetinCikar(
        gorselBytes: gorseller[i],
        apiKey: apiKey,
      );
      if (metin.trim().isNotEmpty) {
        parcalar.add(metin.trim());
      }
    }

    return parcalar.join('\n\n');
  }

  Future<String> _gorseldenMetinCikar({
    required Uint8List gorselBytes,
    required String apiKey,
  }) async {
    final uri = Uri.parse(
      'https://vision.googleapis.com/v1/images:annotate?key=${Uri.encodeComponent(apiKey.trim())}',
    );
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({
        'requests': [
          {
            'image': {'content': base64Encode(gorselBytes)},
            'features': [
              {'type': 'DOCUMENT_TEXT_DETECTION'},
            ],
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint(
        '[VisionOCR] API hatası ${response.statusCode}: ${response.body}',
      );
      return '';
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    final responses = decoded['responses'] as List<dynamic>?;
    if (responses == null || responses.isEmpty) return '';

    final fullText =
        responses.first['fullTextAnnotation']?['text']?.toString() ?? '';
    return fullText.trim().length >= _minKabulMetinUzunlugu ? fullText : '';
  }

  /// Taranmış PDF'lerde sayfa başına gömülü JPEG akışlarını bulur.
  @visibleForTesting
  static List<Uint8List> pdfIciJpegleriCikar(
    Uint8List pdfBytes, {
    int maxAdet = 8,
  }) =>
      _pdfIciJpegleriCikar(pdfBytes, maxAdet: maxAdet);

  static List<Uint8List> _pdfIciJpegleriCikar(
    Uint8List pdfBytes, {
    required int maxAdet,
  }) {
    final bulunan = <Uint8List>[];
    var i = 0;
    while (i < pdfBytes.length - 1 && bulunan.length < maxAdet) {
      if (pdfBytes[i] == 0xFF && pdfBytes[i + 1] == 0xD8) {
        var end = i + 2;
        while (end < pdfBytes.length - 1) {
          if (pdfBytes[end] == 0xFF && pdfBytes[end + 1] == 0xD9) {
            end += 2;
            final parca = pdfBytes.sublist(i, end);
            if (parca.length > 1024) {
              bulunan.add(Uint8List.fromList(parca));
            }
            i = end;
            break;
          }
          end++;
        }
        if (end >= pdfBytes.length - 1) break;
      } else {
        i++;
      }
    }
    return bulunan;
  }
}
