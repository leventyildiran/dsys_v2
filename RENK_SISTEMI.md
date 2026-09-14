# DSYS Renk Sistemi

> **Amaç:** Renk, süs değil **yönlendirme** aracıdır. Bir kullanıcı ekrana baktığında
> "bu yeşil → tamam, bu sarı → bana bak, bu kırmızı → sorun var" diyebilmeli.
> Aynı anlam her yerde **aynı renk** olmalı; farklı anlamlar **farklı renk**.

Bu doküman zorunludur. Yeni ekran/kod yazan her ajan [`app_colors.dart`](lib/core/theme/app_colors.dart:1)
tokenlarını kullanır ve buradaki kurallara uyar.

---

## 1. Tek Kaynak İlkesi

- Tüm renkler [`lib/core/theme/app_colors.dart`](lib/core/theme/app_colors.dart:1) içinde tanımlıdır.
- Ekranlarda **`Colors.red`, `Color(0xFF...)`, `Colors.blueGrey` gibi ham renk YAZILMAZ.**
- Tema bağlantısı [`lib/core/theme/app_theme.dart`](lib/core/theme/app_theme.dart:1) içinde yapılır;
  buton/input/tablo/çip/snackbar gibi bileşenler rengi **otomatik** alır.

```dart
// ❌ YANLIŞ — anlam yok, tutarsız, tema dışı
color: Colors.green
color: const Color(0xFF1E8E5A)

// ✅ DOĞRU — anlam taşır, tek kaynaktan gelir
color: AppColors.success
color: AppColors.successSubtle
```

---

## 2. Renk Kataloğu (tek anlam = tek renk)

### 2.1 Nötr — yapı ve metin (anlam taşımaz)
| Token | Hex | Nerede kullanılır |
|---|---|---|
| `background` | `#F5F6FA` | Sayfa gövdesi arka planı |
| `surface` | `#FFFFFF` | Kart, dialog, tablo yüzeyi |
| `surfaceVariant` | `#EEF0F6` | Tablo başlığı, pasif sekme, çip zemini |
| `border` | `#E2E5EE` | İnce kenarlık, ayırıcı |
| `borderStrong` | `#CBD1DF` | Odaklanmış input, seçili kart kenarı |
| `textPrimary` | `#1E2430` | Başlık, tablo hücresi |
| `textSecondary` | `#5A6478` | Etiket, açıklama |
| `textMuted` | `#8A93A6` | Yer tutucu, devre dışı, meta |
| `disabled` | `#C3C9D6` | Devre dışı çizgi/ikon |

### 2.2 Marka — kimlik + birincil eylem (uygulamada TEK ana renk)
| Token | Hex | Nerede kullanılır |
|---|---|---|
| `primary` | `#2C3E50` | Ana eylem butonu, aktif sekme, bağlantı |
| `primaryDark` | `#243447` | Basılı/hover tonu |
| `primarySubtle` | `#E8EDF3` | Seçili satır zemini, bilgi kutusu |

### 2.3 Durum — işin durumu (her rengin TEK anlamı var)
| Token | Hex | TEK anlamı | Kullanılmaz |
|---|---|---|---|
| `success` | `#1E8E5A` | Onaylandı / tamamlandı / eşleşti | "genel güzel" süsü olarak |
| `warning` | `#B26A00` | Dikkat / onay bekliyor / eksik alan | Hata gibi göstermek için |
| `danger` | `#C0392B` | Hata / reddedildi / gecikmiş / tutarsız | Sadece "önemli" diye |
| `info` | `#1C6FB8` | Bilgi / nötr bildirim / ipucu | Olumlu/olumsuz anlam yüklemek |
| `neutral` | `#6B7280` | Pasif / devre dışı / bilgi yok | Vurgu amaçlı |

Her durum renginin bir de **`*Subtle`** dolgu tonu vardır (`successSubtle`, `warningSubtle`,
`dangerSubtle`, `infoSubtle`, `neutralSubtle`) — rozet/uyarı kutusu zemini için.
Kenarlık için `successBorder`, `warningBorder`, `dangerBorder`, `infoBorder`.

### 2.4 Eylem — kullanıcının şimdi ne yapabileceği
| Token | Değer | Kullanım |
|---|---|---|
| `actionPrimary` | `primary` | "Kaydet", "Analiz Et", "Oluştur" |
| `actionSecondary` | `#5A6478` | "Vazgeç", "Geri", ikincil işlem |
| `actionConfirm` | `success` | "Onayla", "Kabul Et" |
| `actionDestructive` | `danger` | "Sil", "Reddet", "İptal Et" |

### 2.5 Gezinme (sidebar)
`sidebar` `#1E1E2C` · `sidebarActive` `#2C3E50` · `sidebarText` `#A9B0C3` · `sidebarTextActive` `#FFFFFF`

---

## 3. Altın Kurallar

1. **Tek anlam = tek renk.** Yeşil her yerde "başarılı", kırmızı her yerde "sorun" demektir.
   Aynı anlam için ikinci bir renk açılmaz.
2. **Renk yalnızca bilgi taşıyorsa kullanılır.** Sırf "renkli olsun" diye renk yok.
3. **Bir ekranda en fazla bir vurgu rengi** (primary) + gerekiyorsa durum renkleri.
   Gökkuşağı yasak.
4. **Rozet/etiket (birim, rol, durum) nötr renkle yapılır**; yalnızca durum bilgisi varsa
   `success/warning/danger/info` kullanılır. Birimleri renkle ayırt etme (metinle ayırt et).
5. **Eylem rengi = buton işlevi.** Yıkıcı işlem asla marka renginde olmaz → `danger`.
6. **Metin okunabilirliği önce gelir.** Renkli zemin üstünde daima uygun kontrast
   (`textOnDark` beyaz zemin metni değil).
7. **Yeni renk gerekirse** önce "hangi anlam?" sorusuna cevap ver; ancak gerçekten yeni bir
   anlam varsa [`app_colors.dart`](lib/core/theme/app_colors.dart:1) içine ekle, ekranda değil.

---

## 4. Yaygın Örnekler

```dart
// Durum rozeti
Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  decoration: BoxDecoration(
    color: AppColors.successSubtle,
    border: Border.all(color: AppColors.successBorder),
    borderRadius: BorderRadius.circular(6),
  ),
  child: const Text('Onaylandı',
      style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
)

// Uyarı kutusu
Container(
  decoration: BoxDecoration(
    color: AppColors.warningSubtle,
    border: Border.all(color: AppColors.warningBorder),
    borderRadius: BorderRadius.circular(8),
  ),
  child: const Text('Eksik alanlar var', style: TextStyle(color: AppColors.warning)),
)

// Butonlar
FilledButton(onPressed: _kaydet, child: const Text('Kaydet')),      // primary (tema)
OutlinedButton(onPressed: _geri, child: const Text('Vazgeç')),      // nötr (tema)
TextButton(onPressed: _sil, child: const Text('Sil',
    style: TextStyle(color: AppColors.actionDestructive))),         // danger

// Tablo başlığı / ikincil metin
Text('Toplam', style: Theme.of(context).textTheme.labelMedium),     // textSecondary
```

---

## 5. Mevcut Durum ve Geçiş Planı (migration)

- Halihazırda ekranlarda **300'den fazla ham renk** (`Colors.*`, `Color(0x...)`) dağınık durumda.
  Bu, kullanıcının şikayet ettiği "çok fazla renk / karışıklık" sorununun kaynağıdır.
- **Kural:** Yeni yazılan/değiştirilen her kod bu tokenları kullanır (ham renk eklemez).
- **Geçiş:** Ekranlar tek tek elden geçirilir; her ekranda ham renkler tokenlara çevrilir
  (modül bazlı: önce beyanname, sonra fatura, sonra danışmanlık, yk_karar …).
- Geçiş yapılan modülde `grep` ile doğrula: ekranda `Colors.` / `Color(0x` kalmamalı
  (üretilen PDF/Word içerikleri hariç — onlar belge çıktısıdır, tema dışıdır).

---

## 6. Beyanname Renk Kurgusu (Referans Ekran)

Beyanname modülü, sistemin **referans** renk kurgusudur. Burada "renk yönlendirir,
rahatsız etmez, hata yaptırmaz" ilkesi uygulanmıştır. Diğer modüller aynı dili izler.

### 6.1 Ekranın tek vurgusu
Ekranda **tek vurgu rengi** vardır: `primary`. Bölüm başlıkları (`_buildSheetTitle`)
bu rengi kullanır. Sekiz farklı Excel rengi (mavi/yeşil/amber/mor …) kaldırılmıştır;
hiçbir masanın başlığı "kendi rengini" taşımaz.

### 6.2 Nerede hangi anlam → hangi renk
| Ekrandaki durum | Anlam | Token |
|---|---|---|
| Net ödenecek KDV (devri yok) | tahsil edilecek / tamam | `success` (+ `successSubtle`/`successBorder` çip) |
| Sonraki döneme devreden KDV | taşınan bakiye → dikkat, hata değil | `warning` (+ `warningSubtle`/`warningBorder` çip) |
| Negatif KDV / tutarsız satır | gerçek olumsuzluk | `danger` |
| Devreden KDV şeridindeki bilgi ikonu | nötr bilgi | `info` |
| Bilgi/ipucu kutusu (600 masası, kılavuz) | nötr açıklama | `infoSubtle`/`infoBorder`/`info`, `textMuted` |
| Tablo başlık satırı | yapı (veri değil) | `tabloBaslikZemin`/`tabloBaslikMetin` |
| Toplam / genel toplam satırı | yapısal toplam (süs değil) | `toplamSatirZemin`/`toplamSatirMetin` (nötr ton) |
| Zebra ikinci satır | okunabilirlik | `tabloSatirCift` |
| DİŞ/TÖMER özel birim satırı | "özel ele alınır" → dikkat | `warningSubtle` |
| "KENDİ YAPAR" rozeti | bilgilendirme | `warningSubtle`/`warningBorder`/`warning` |
| KPI özet kartları (Vergi Arama) | nötr bilgi | `surface`/`border`/`textPrimary` |
| KPI "FİLTRE TOPLAMI" kartı | tek özet → vurgu | `primarySubtle`/`primary` |
| Yıkıcı işlem (satır sil) | geri dönüşsüz | `actionDestructive`/`danger` |
| Birincil işlem (Kaydet, Ekle) | yapılacak şey | `actionPrimary`/`primary` |

### 6.3 Hücre renkleri (yönlendirme + hata önleme)
`EditableCell` renkleri kullanıcıyı **yönlendirir**, cezalandırmaz:

- **Boş hücre:** `hucreZeminBos` (amber) + `hucreKenarlikBos` + `hucreIpucuMetin`
  yer tutucu → "buraya veri gir" sinyali.
- **Dolu hücre:** `hucreZeminDolu` (yeşil) + `hucreKenarlikDolu` + `success` metin
  → "burayı tamamladın".
- **Odaklı hücre:** `hucreZeminOdak` + `hucreKenarlikOdak` (`primary`) → "şu an buradasın".

Renk **tek başına** anlam taşımaz; her durumda kalınlık, kenarlık ve yer tutucu metni
eşlik eder (renk körlüğü erişilebilirliği).

### 6.4 Kaldırılanlar (tekrar eklenmemeli)
- Excel'den gelen fıstık yeşili / açık mavi / sarı bölüm barları → nötr tablo başlığı.
- Her masaya özel `accentColor` parametresi → kaldırıldı; başlık daima `primary`.
- Ham `Colors.white` / `Color(0x...)` → `surface` ve anlamsal tokenlar.
- Gökkuşağı KPI kartları → tek vurgu + nötr yüzey.

Doğrulama (beyanname modülü): `grep` ile `Colors.` / `Color(0x` **0 sonuç** vermelidir.

### 6.5 Kılavuz şeridi (yönlendirme) — `BeyannameGuideStrip`
Ekranın üstündeki kılavuz şeridi artık ayrı bir bileşendir:
[`lib/features/beyanname/widgets/beyanname_guide_strip.dart`](lib/features/beyanname/widgets/beyanname_guide_strip.dart:1).

- **Yönlendirir:** "Girilen: N hücre" (`success`) ve "Boş / Bekleyen: N hücre" (`warning`)
  rozetleri kullanıcıya nerede kaldığını söyler.
- **Odaklar:** Tek vurgu (`primary`) korunur; şerit sakin `surface` zeminlidir ve yatay
  kaydırılır (dar ekranda rozet kırpılmaz, taşma/overflow olmaz).
- Her rozet **ikon + metin** birlikte taşır; anlam yalnızca renge bırakılmaz.

### 6.6 Giriş denetimi (hata önleme) — `BeyannameDogrulama`
Kullanıcının beyannameyi hatalı doldurmasını engellemek için **saf** (yan etkisiz) bir
denetim motoru vardır:
[`lib/features/beyanname/services/beyanname_dogrulama.dart`](lib/features/beyanname/services/beyanname_dogrulama.dart:1).

| Seviye | Anlam | Renk tokeni |
|---|---|---|
| `hata` | matematiksel tutarsızlık, düzeltilmeli | `danger` |
| `dikkat` | büyük olasılıkla eksik giriş, gözden geçir | `warning` |
| `bilgi` | hata değil; dönem sonucunu önceden söyler | `info` |

Denetim, **yalnızca kullanıcının gerçekten yapabileceği** hatalara odaklanır
(örn. tevkifat > KDV, net ödenen > brüt, KDV ≠ matrah × oran). Motor tarafından
türetilen alanlar (damga `matrah`ı, 600 `kümülatif`i) yanlış alarm üretmemek için
denetlenmez. Kılavuz şeridi, bulunan sorunları tek rozette özetler
("Dikkat: N hata, M uyarı") ve tıklanınca seviyeye göre gruplu bir iletişim kutusu açar.
Böylece renk **rahatsız etmeden yönlendirir** ve hata yapılmasını engeller.

Birim testi: [`test/beyanname_dogrulama_test.dart`](test/beyanname_dogrulama_test.dart:1).

---

## 7. İlgili Dosyalar

- Tokenlar: [`lib/core/theme/app_colors.dart`](lib/core/theme/app_colors.dart:1)
- Tema: [`lib/core/theme/app_theme.dart`](lib/core/theme/app_theme.dart:1)
- Hazır bileşenler: [`lib/core/widgets/durum_rozeti.dart`](lib/core/widgets/durum_rozeti.dart:1) (`DurumRozeti`, `NotrEtiket`)
- Sistem haritası: [`SISTEM_YAPISI.md`](SISTEM_YAPISI.md:1)
- Zorunlu kurallar: [`AGENTS.md`](AGENTS.md:1)
