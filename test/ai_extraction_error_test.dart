import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

// --- SİMÜLASYON FONKSİYONLARI ---

/// 1. PDF Çökme (Crash) Simülasyonu
/// Hatalı/Bozuk bir PDF byte dizisi verildiğinde kütüphanenin çökmesini
/// engelleyip engellemediğimizi (try-catch) test eder.
String simulatePdfParsing(List<int> bytes) {
  try {
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText().trim();
    document.dispose();
    return text;
  } catch (e) {
    return 'HATA_YAKALANDI'; 
  }
}

/// 2. Gemini Fallback (Yedekleme) ve Hata Fırlatma Simülasyonu
/// Tüm modeller başarısız olduğunda sistemin hatayı yutup yutmadığını test eder.
Future<String> simulateGeminiFallback(bool hasValidKey, bool isScannedPdf) async {
  final denemeModelleri = ['gemini-1.5-flash', 'gemini-1.5-pro', 'gemini-1.5-flash-8b'];
  int deneme = 0;
  Object? sonHata;

  while (deneme < denemeModelleri.length) {
    final modelName = denemeModelleri[deneme];
    try {
      if (!hasValidKey) {
        throw Exception('Geçersiz API Anahtarı ($modelName)');
      }
      return 'BASARILI';
    } catch (e) {
      sonHata = e;
    }
    deneme++;
  }

  // Fallback bitti, hata kontrolü
  if (sonHata != null && isScannedPdf) {
    throw Exception('Gemini Vision Hatası: $sonHata');
  }
  
  return 'DEEPSEEK_FALLBACK';
}

void main() {
  group('Hata Simülasyonları ve Güvenlik Ağları (Safety Nets)', () {
    
    test('1. Bozuk PDF yüklendiğinde uygulama çökmemeli (Try-Catch Testi)', () {
      // Tamamen anlamsız/bozuk byte dizisi (PDF formatında değil)
      final badBytes = [1, 2, 3, 4, 5, 6, 7];
      
      final result = simulatePdfParsing(badBytes);
      
      // Çökmeden HATA_YAKALANDI dönmeli
      expect(result, 'HATA_YAKALANDI');
    });

    test('2. Gemini API yanıt vermezse Fallback zinciri çalışmalı', () async {
      // isScannedPdf = false (Normal Metin), API Key bozuk = true
      final result = await simulateGeminiFallback(false, false);
      
      // Normal metinse Gemini çökerse DeepSeek'e (çevrimdışı) devretmeli
      expect(result, 'DEEPSEEK_FALLBACK');
    });

    test('3. Taranmış (Görsel) PDF yüklenip Gemini çökerse, hatayı UI\'a fırlatmalı', () async {
      // isScannedPdf = true (Görsel PDF), API Key bozuk = true
      
      expect(
        () async => await simulateGeminiFallback(false, true),
        throwsA(predicate((e) => e.toString().contains('Gemini Vision Hatası: Exception: Geçersiz API Anahtarı'))),
      );
    });

  });
}
