/// Fatura kartında ve snackbar'da gösterilen okuma kaynağı etiketleri.
/// Kullanıcıya yönelik; "Tier" veya teknik terim içermez.
abstract final class FaturaParseKaynaklari {
  static const arsivSablonu = 'Arşiv şablonu';
  static const geminiMetin = 'Yapay zeka (Gemini)';
  static const geminiVision = 'Yapay zeka (Gemini Vision)';
  static const geminiOcrYedek = 'Yapay zeka (Gemini · OCR yedek)';
  static const deepSeekOcrYedek = 'Yapay zeka (DeepSeek · OCR yedek)';
  static const deepSeek = 'Yapay zeka (DeepSeek)';
  static const cevrimdisi = 'Çevrimdışı kural';
  static const excelToplu = 'Excel toplu aktarım';
  static const manuel = 'Manuel giriş';
  static const kopya = 'Kopya';
  static const kalibrasyon = 'Kalibrasyon testi';
  static const yeniFatura = 'Yeni fatura';

  /// Eski kayıtlardaki Tier etiketlerini kullanıcı dostu metne çevirir.
  static String normalize(String? raw) {
    final v = (raw ?? '').trim();
    if (v.isEmpty) return 'Bilinmiyor';
    final lower = v.toLowerCase();
    if (lower.contains('ocr yedek')) {
      if (lower.contains('deepseek')) return deepSeekOcrYedek;
      return geminiOcrYedek;
    }
    if (lower.contains('tier 1') && lower.contains('gemini')) {
      return geminiMetin;
    }
    if (lower.contains('tier 2') && lower.contains('deepseek')) {
      return deepSeek;
    }
    if (lower.contains('tier 3') || lower.contains('çevrimdışı (kural)')) {
      return cevrimdisi;
    }
    if (lower.contains('akıllı eşleştirme') || lower.contains('arşiv şablonu')) {
      return arsivSablonu;
    }
    if (v == 'AI Parser') return 'Yapay zeka';
    if (v == 'Yeni Fatura') return yeniFatura;
    if (v == 'Manuel Giriş') return manuel;
    if (v == 'Excel Toplu Aktarım') return excelToplu;
    if (v == 'Kalibrasyon Testi') return kalibrasyon;
    return v;
  }
}
