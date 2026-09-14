import 'package:flutter/material.dart';

/// ## DSYS Renk Sistemi (tek anlam = tek renk)
///
/// Bu dosya uygulamanın **tek renk kaynağıdır**. Ekranlarda `Colors.red`,
/// `Color(0xFF...)` gibi ham değerler YAZILMAZ; buradaki tokenlar kullanılır.
///
/// Tasarım ilkesi: *"Renk süs değildir, kullanıcıyı yönlendirir."*
/// Bir renk ekranda görünüyorsa bir sebebi vardır:
/// - **Nötr (structure):** sadece yerleşim/okunabilirlik → dikkat çekmez.
/// - **Marka (brand):** kimlik + birincil eylem ("yapılacak şey").
/// - **Durum (status):** işin ne durumda olduğu (başarılı / bekliyor / hata).
/// - **Eylem (action):** kullanıcının şimdi ne yapabileceği.
///
/// Kurallar için bkz. [`RENK_SISTEMI.md`](../../../RENK_SISTEMI.md:1).
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // 1) NÖTR — yapı ve metin. Anlam taşımaz, dikkat çekmez.
  // ---------------------------------------------------------------------------

  /// Uygulama arka planı (sayfa gövdesi).
  static const Color background = Color(0xFFF5F6FA);

  /// Kart, tablo, dialog yüzeyi.
  static const Color surface = Color(0xFFFFFFFF);

  /// Yüzey üstü hafif dolgu (tablo başlığı, seçili olmayan sekme, çip zemini).
  static const Color surfaceVariant = Color(0xFFEEF0F6);

  /// İnce kenarlık, ayırıcı çizgi, tablo ızgarası.
  static const Color border = Color(0xFFE2E5EE);

  /// Vurgulu kenarlık (odaklanmış input, seçili kart).
  static const Color borderStrong = Color(0xFFCBD1DF);

  /// Ana metin (başlık, tablo hücresi).
  static const Color textPrimary = Color(0xFF1E2430);

  /// İkincil metin (etiket, açıklama).
  static const Color textSecondary = Color(0xFF5A6478);

  /// Soluk metin (yer tutucu, devre dışı, meta bilgi).
  static const Color textMuted = Color(0xFF8A93A6);

  /// Koyu/marka zemin üzerinde metin.
  static const Color textOnDark = Color(0xFFFFFFFF);

  /// Koyu zemin üzerinde ikincil metin.
  static const Color textOnDarkMuted = Color(0xFFA9B0C3);

  /// Beyaz (kısayol; tercihen [surface] veya [textOnDark] kullanın).
  static const Color white = Color(0xFFFFFFFF);

  /// Şeffaf (kenarlık/gölge sıfırlama; ham `Colors.transparent` yerine).
  static const Color transparent = Color(0x00000000);

  // ---------------------------------------------------------------------------
  // 2) MARKA — kimlik + birincil eylem. Uygulamada TEK ana renk.
  // ---------------------------------------------------------------------------

  /// Birincil marka rengi; ana eylem butonları, aktif sekme, bağlantı.
  static const Color primary = Color(0xFF2C3E50);

  /// Birincil rengin basılı/hover (koyu) tonu.
  static const Color primaryDark = Color(0xFF243447);

  /// Birincil rengin açık tonu (seçili satır zemini, bilgi kutusu).
  static const Color primarySubtle = Color(0xFFE8EDF3);

  // ---------------------------------------------------------------------------
  // 3) DURUM — işin durumu. Her rengin TEK bir anlamı vardır.
  // ---------------------------------------------------------------------------

  /// **Başarılı / tamamlandı / onaylandı / eşleşti.**
  static const Color success = Color(0xFF1E8E5A);
  static const Color successSubtle = Color(0xFFE3F4EA);

  /// **Dikkat / onay bekliyor / eksik alan / süre yakın.**
  /// Hata DEĞİLDİR; "bakılması gereken" durumdur.
  static const Color warning = Color(0xFFB26A00);
  static const Color warningSubtle = Color(0xFFFDF1DF);

  /// **Hata / reddedildi / gecikmiş / tutarsız veri.**
  /// Yalnızca gerçek bir olumsuzlukta kullanılır.
  static const Color danger = Color(0xFFC0392B);
  static const Color dangerSubtle = Color(0xFFFBE7E4);

  /// **Bilgi / nötr bildirim / ipucu.** Olumlu ya da olumsuz değil.
  static const Color info = Color(0xFF1C6FB8);
  static const Color infoSubtle = Color(0xFFE4F0FA);

  /// **Devre dışı / pasif / bilgi yok.** Karar beklemeyen içerik.
  static const Color neutral = Color(0xFF6B7280);
  static const Color neutralSubtle = Color(0xFFEDEFF3);

  // ---------------------------------------------------------------------------
  // 4) EYLEM — kullanıcının şimdi ne yapabileceğini gösterir.
  // ---------------------------------------------------------------------------

  /// Birincil eylem ("Kaydet", "Onayla") → [primary].
  static const Color actionPrimary = primary;

  /// İkincil/ikincil derece eylem ("Vazgeç", "Geri") → nötr gri.
  static const Color actionSecondary = Color(0xFF5A6478);

  /// Yıkıcı eylem ("Sil", "Reddet") → [danger]. DİKKATLİ kullanılır.
  static const Color actionDestructive = danger;

  /// Onay eylemi ("Onayla", "Kabul Et") → [success].
  static const Color actionConfirm = success;

  // ---------------------------------------------------------------------------
  // 5) GEZİNME (sidebar) — koyu yan menü.
  // ---------------------------------------------------------------------------

  static const Color sidebar = Color(0xFF1E1E2C);
  static const Color sidebarActive = Color(0xFF2C3E50);
  static const Color sidebarText = textOnDarkMuted;
  static const Color sidebarTextActive = textOnDark;

  // ---------------------------------------------------------------------------
  // 6) YARDIMCILAR — anlam taşımayan, mekanik türevler.
  // ---------------------------------------------------------------------------

  /// Gölge rengi (kart/elevation).
  static const Color shadow = Color(0x1A1E2430);

  /// Devre dışı çizgi/ikon.
  static const Color disabled = Color(0xFFC3C9D6);

  /// Odak halkası (focus ring) — marka renginin saydam hali.
  static Color get focusRing => primary.withValues(alpha: 0.35);

  static const Color successBorder = Color(0xFFB7E0C7);
  static const Color warningBorder = Color(0xFFEFD3A3);
  static const Color dangerBorder = Color(0xFFF0B7B0);
  static const Color infoBorder = Color(0xFFB7D6F0);

  // ---------------------------------------------------------------------------
  // 7) BİLEŞEN TOKENLERİ — tablo/form gibi tekrar eden yapılar.
  //    Hepsi yukarıdaki anlamsal tokenların kısayoludur; YENİ renk tanımlamaz.
  //    Amaç: ekran kodunda "hangi renk?" değil, "hangi bileşen?" kararı verilmesi.
  // ---------------------------------------------------------------------------

  /// Tablo başlık satırı zemini (kolon adları; veri hücresi değil).
  static const Color tabloBaslikZemin = surfaceVariant;

  /// Tablo başlık metni.
  static const Color tabloBaslikMetin = textSecondary;

  /// Tablo dış çerçevesi.
  static const Color tabloKenarlik = borderStrong;

  /// Tablo iç ızgarası (satır/sütun çizgileri).
  static const Color tabloIzgara = border;

  /// Zebra desenli ikinci satır zemini.
  static const Color tabloSatirCift = surfaceVariant;

  /// Toplam / genel toplam satırı zemini (vurgu rengi değil, ton farkı).
  static const Color toplamSatirZemin = neutralSubtle;

  /// Toplam satırı metni.
  static const Color toplamSatirMetin = textPrimary;

  /// Hücre normal metni.
  static const Color hucreMetin = textPrimary;

  /// Veri girilmiş hücre zemini (dolu).
  static const Color hucreZeminDolu = successSubtle;

  /// Veri bekleyen/boş hücre zemini (uyarı; hata değil).
  static const Color hucreZeminBos = warningSubtle;

  /// Odaklanmış hücre zemini.
  static const Color hucreZeminOdak = surface;

  /// Dolu hücre kenarlığı.
  static const Color hucreKenarlikDolu = successBorder;

  /// Boş hücre kenarlığı.
  static const Color hucreKenarlikBos = warningBorder;

  /// Odaklanmış hücre kenarlığı.
  static const Color hucreKenarlikOdak = primary;

  /// Boş hücre yer tutucu metni ("buraya veri gir" sinyali).
  static const Color hucreIpucuMetin = warning;

  /// Bilgi/ipucu kutusu zemini.
  static const Color notZemin = infoSubtle;

  /// Bilgi/ipucu kutusu kenarlığı.
  static const Color notCerceve = infoBorder;

  /// Bilgi/ipucu metni.
  static const Color notMetin = info;
}
