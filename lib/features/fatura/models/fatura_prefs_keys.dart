/// SharedPreferences ve Firestore anahtar sabitleri — tek kaynak.
/// Tüm fatura modülü bu dosyadaki anahtarları kullanır.
abstract final class FaturaPrefsKeys {
  // ── Kuyruk ──────────────────────────────────────────────
  static const kuyruk = 'fatura_pending_kuyruk_v1';
  static const kuyrukKayitGecikmesi = Duration(milliseconds: 500);

  // ── Kalibrasyon ─────────────────────────────────────────
  static const kalibrasyonSurum = 'fatura_matbu_kalibrasyon_surum';
  static const kalemSatirAraligi = 'fatura_kalem_satir_araligi';
  static const fontBoyutu = 'fatura_matbu_font_boyutu';
  static const globalOffsetDx = 'fatura_global_offset_dx';
  static const globalOffsetDy = 'fatura_global_offset_dy';
  static const matbuBaskiModu = 'fatura_matbu_baski_modu';
  static const kalibrasyonKayitGecikmesi = Duration(milliseconds: 400);

  // ── Arşiv ───────────────────────────────────────────────
  static String arsivUyarisiKapatildi(int yil) =>
      'fatura_arsiv_uyari_${yil}_kapatildi';

  // ── Firestore ───────────────────────────────────────────
  static const firestoreMatbuKalibrasyon = 'matbuKalibrasyon';

  // ── PDF ─────────────────────────────────────────────────
  static const int pdfSatirLimit = 10;
  static const double pdfA4Genislik = 595;
  static const double pdfA4Yukseklik = 842;
}
