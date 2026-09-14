# DSYS v2 — Sistem Yapısı ve Ajan Haritası

> **Bu dosyanın amacı:** Projeye yeni gelen bir ajanın (veya geliştiricinin) 5 dakika
> içinde "hangi modül nerede, hangi iş hangi dosyada, neyi bozmamalıyım" sorusunu
> cevaplayabilmesi. Kod yazmadan önce bu dosyayı, sonra ilgili modülün alt bölümünü oku.

İlgili zorunlu dokümanlar:
- Ürün/karar hazırlama mantığı + DOKUNULMAZ kurallar: [`AGENTS.md`](AGENTS.md:1)
- Beyanname Excel doğrulama raporu: [`BEYANNAME_DOGRULAMA_RAPORU.md`](BEYANNAME_DOGRULAMA_RAPORU.md:1)
- Çok-kurumlu (tenant) mimari önerisi + yol haritası: [`MERKEZI_MIMARI_ONERISI.md`](MERKEZI_MIMARI_ONERISI.md:1)
- Renk/tasarım sistemi: [`RENK_SISTEMI.md`](RENK_SISTEMI.md:1)

---

## 1. Üst Düzey Mimari (katmanlar)

```
main.dart
  └─ MultiProvider  (tüm Provider'lar burada bağlanır)
       └─ router/app_router.dart  (go_router + guards.dart ile yetki kapısı)
            └─ features/<modül>/screens/*      → UI
                 └─ features/<modül>/providers/* → durum (ChangeNotifier)
                      └─ features/<modül>/services/* → iş mantığı / hesap motoru
                           └─ core/services/*      → Firestore / Storage / AI / Şablon
                                └─ Firestore: universiteler/{universiteId}/...
```

- **UI katmanı** yalnızca `context.watch/read<Provider>()` kullanır; doğrudan Firestore'a gitmez.
- **Provider katmanı** state tutar + servisleri çağırır.
- **Service katmanı** iş kuralı ve hesaplama içerir (test edilebilir, UI'dan bağımsız).
- **core/** katmanı tüm modüllerin paylaştığı altyapıdır (Firestore, AI, format, model).

---

## 2. Klasör Haritası (`lib/`)

```
lib/
├─ main.dart                     Uygulama girişi + MultiProvider kayıtları
├─ firebase_options.dart         Firebase yapılandırması
├─ core/                         Paylaşılan altyapı (modül-bağımsız)
│  ├─ hesaplama_motoru.dart      Ortak sayısal hesaplama yardımcıları
│  ├─ turkce_format.dart         Türkçe sayı/tarih biçimleme + sayıyı yazıya çevirme
│  ├─ karar_metni_servisi.dart   Karar metni yardımcıları
│  ├─ models/                    Ortak modeller (birim, firma, hizmet, şablon, ayar, rol, sayfalama)
│  ├─ services/                  Firestore, Storage, AI (Gemini), OCR (Vision), Şablon, Birim, Firma, Hizmet
│  ├─ widgets/                   Paylaşılan UI bileşenleri (durum rozeti, nötr etiket)
│  └─ theme/                     AppColors (token) + AppTheme (tema) — tasarım sistemi
├─ router/                       app_router.dart (rota tanımları) + guards.dart (yetki)
└─ features/                     Modüller
   ├─ auth/                      Giriş, kayıt, onay bekleyen kullanıcı
   ├─ dashboard/                 Ana ekran + sol menü + header
   ├─ admin/                     Yönetici paneli
   ├─ ayarlar/                   Sistem Ayarları + Şablon editörü/yönetimi
   ├─ birim/                     Birim yönetimi (IBAN/VKN/birim tanımı)
   ├─ fatura/                    Fatura matbu, toplu doğrulama, görsel giriş, PDF üretimi, arşiv
   ├─ beyanname/                 KDV1/Muhtasar/Damga/KDV2 beyanname masaları + icmal
   ├─ danismanlik/               Danışmanlık gelirleri, manuel hesaplama, taksit/dağıtım takibi
   ├─ personel/                  Personel + aylık hakediş
   └─ yk_karar/                  Yürütme Kurulu karar/gündem üretimi (Word/PDF)
```

---

## 3. Modüller ve Sorumlulukları

### 3.1 Auth — `features/auth/`
- Giriş: [`login_screen.dart`](lib/features/auth/screens/login_screen.dart:1)
- Kayıt/onay: [`signup_screen.dart`](lib/features/auth/screens/signup_screen.dart:1), [`pending_approval_screen.dart`](lib/features/auth/screens/pending_approval_screen.dart:1)
- Durum: [`auth_provider.dart`](lib/features/auth/providers/auth_provider.dart:1), [`user_provider.dart`](lib/features/auth/providers/user_provider.dart:1)
- Model: [`user_model.dart`](lib/features/auth/models/user_model.dart:1) → `universiteId`, `birimId`, `rol`, `aktif`
- **Önemli:** `user_provider` giriş sonrası `FirestoreService.activeUniversiteId` değerini kullanıcının `universiteId`'si ile set eder (tenant izolasyonu).

### 3.2 Fatura — `features/fatura/`
- Ekranlar: [`fatura_screen.dart`](lib/features/fatura/screens/fatura_screen.dart:1), [`batch_verification_screen.dart`](lib/features/fatura/screens/batch_verification_screen.dart:1), [`visual_entry_screen.dart`](lib/features/fatura/screens/visual_entry_screen.dart:1), [`fatura_arsiv_arama_dialog.dart`](lib/features/fatura/screens/fatura_arsiv_arama_dialog.dart:1)
- Provider: [`batch_fatura_provider.dart`](lib/features/fatura/providers/batch_fatura_provider.dart:1) (dış API) → [`fatura_kuyruk_provider.dart`](lib/features/fatura/providers/fatura_kuyruk_provider.dart:1) (kuyruk+kalıcılık) + [`fatura_matbu_provider.dart`](lib/features/fatura/providers/fatura_matbu_provider.dart:1) (matbu/koordinat)
- PDF: [`fatura_pdf_uretici.dart`](lib/features/fatura/services/fatura_pdf_uretici.dart:1)
- Excel okuma: [`excel_universal_parser.dart`](lib/features/fatura/services/excel_universal_parser.dart:1) (xlsx+html), [`excel_web_parser.dart`](lib/features/fatura/services/excel_web_parser.dart:1), [`fatura_offline_parser.dart`](lib/features/fatura/services/fatura_offline_parser.dart:1)
- Kalibrasyon: [`fatura_matbu_kalibrasyon_servisi.dart`](lib/features/fatura/services/fatura_matbu_kalibrasyon_servisi.dart:1)
- **DOKUNULMAZ:** `AGENTS.md` → "Fatura Matbu & Visual Entry Kalibrasyon Kuralları" (12 madde). Özellikle: Nakli Yekün hizalaması, çift sayım mantığı, manuel sayfalama (`sayfayiBol`), her sayfada görünen alanlar, KDV muafiyet gösterimi.

### 3.3 Beyanname — `features/beyanname/`
- Ekran: [`beyanname_hesapla_screen.dart`](lib/features/beyanname/screens/beyanname_hesapla_screen.dart:1) (masalar + icmal + Word/PDF)
- Provider: [`beyanname_provider.dart`](lib/features/beyanname/providers/beyanname_provider.dart:1)
- Hesap motoru: [`beyanname_hesaplama_motoru.dart`](lib/features/beyanname/services/beyanname_hesaplama_motoru.dart:1)
- Esneklik katmanı: [`birim_vergi_profili.dart`](lib/features/beyanname/models/birim_vergi_profili.dart:1)
- Masalar: **KDV1**, **Muhtasar**, **Damga**, **KDV2 (tevkifat)**; özet **Tablo 1** (masalar) + **Tablo 2** (KDV2).
- Ayrıştırma: `_ozetAyrismaAktif` → "Ayrıştırma Kapalı" modunda sabit DİŞ ek satırları gizlenir; masalar asla satır gizlemez, yalnızca "KENDİ YAPAR" rozeti gösterir.
- Birim hiyerarşisi/yetki (yol haritası): [`MERKEZI_MIMARI_ONERISI.md`](MERKEZI_MIMARI_ONERISI.md:1) §4c.

### 3.4 Danışmanlık — `features/danismanlik/`
- Ekranlar: dashboard, form, detay, takip, [`danismanlik_manuel_hesapla_screen.dart`](lib/features/danismanlik/screens/danismanlik_manuel_hesapla_screen.dart:1) (sekme: liste / dağıtım-maks-pay / katkı payı / özet-icmal)
- Provider'lar: [`danismanlik_provider.dart`](lib/features/danismanlik/providers/danismanlik_provider.dart:1), [`danismanlik_detay_provider.dart`](lib/features/danismanlik/providers/danismanlik_detay_provider.dart:1), [`taksit_takip_provider.dart`](lib/features/danismanlik/providers/taksit_takip_provider.dart:1)
- Hesaplama: [`danismanlik_excel_hesaplama.dart`](lib/features/danismanlik/services/danismanlik_excel_hesaplama.dart:1), [`danismanlik_hesaplama_servisi.dart`](lib/features/danismanlik/services/danismanlik_hesaplama_servisi.dart:1)
- Şablon türleri: `danismanlik_model.dart` → standart / 58/k sanayi işbirliği / eğitim-kurs
- Manuel kayıt/persist: [`danismanlik_manuel_kayit_servisi.dart`](lib/features/danismanlik/services/danismanlik_manuel_kayit_servisi.dart:1)

### 3.5 Yürütme Kurulu (YK) — `features/yk_karar/`
- Akış ve mantık `AGENTS.md`'de tanımlı (karar ≠ gündem, iki ayrı editör).
- Ekranlar: [`yk_yeni_karar_ekle_screen.dart`](lib/features/yk_karar/screens/yk_yeni_karar_ekle_screen.dart:1), [`yk_eski_kararlar_screen.dart`](lib/features/yk_karar/screens/yk_eski_kararlar_screen.dart:1), [`gundem_yonetim_screen.dart`](lib/features/yk_karar/screens/gundem_yonetim_screen.dart:1)
- Servisler: [`belge_uretim_servisi.dart`](lib/features/yk_karar/services/belge_uretim_servisi.dart:1) (Word/PDF), [`docx_sablon_servisi.dart`](lib/features/yk_karar/services/docx_sablon_servisi.dart:1), [`yk_karar_eslestirme_servisi.dart`](lib/features/yk_karar/services/yk_karar_eslestirme_servisi.dart:1), [`yk_karar_butunluk_servisi.dart`](lib/features/yk_karar/services/yk_karar_butunluk_servisi.dart:1), [`yk_tablo_kolon_haritasi.dart`](lib/features/yk_karar/services/yk_tablo_kolon_haritasi.dart:1)
- **Şablon iki katman:** Sistem Ayarları ortak şablon (`Birim Tüm`) = dış çerçeve; birim Word arşivi = tablo eşleştirme (isteğe bağlı).

### 3.6 Yardımcı modüller
- **Birim:** [`birim_service.dart`](lib/features/birim/services/birim_service.dart:1) → `universiteler/{uniId}/birimler`; `BirimModel.varsayilanBirimler` fallback.
- **Ayarlar:** [`sistem_ayarlari_screen.dart`](lib/features/ayarlar/screens/sistem_ayarlari_screen.dart:1) (AI anahtarı, IBAN, şablon yükleme), şablon editörü/yönetimi.
- **Personel:** `personel_service.dart` + `personel_hakedis_service.dart`.
- **Admin:** `admin_dashboard_screen.dart` + `admin_provider.dart`.

---

## 4. Veri Akışı ve Kalıcılık

| Katman | Teknoloji | Not |
| :--- | :--- | :--- |
| Uzak veri | Firestore `universiteler/{universiteId}/<koleksiyon>` | [`firestore_service.dart`](lib/core/services/firestore_service.dart:1) üzerinden; `activeUniversiteId` statik |
| Kullanıcılar | Firestore `users` (kök) | ⚠️ Tenant yol haritasında kurum altına taşınacak (Faz 0) |
| Beyanname | Firestore (`beyannameler`) | ⚠️ Şu an kök koleksiyon → Faz 0'da tenant'a taşınacak |
| Yerel taslak | SharedPreferences | Fatura kuyruğu (`FaturaPrefsKeys`), matbu koordinatları, beyanname/danışmanlık taslakları |
| Dosya | Firebase Storage (`storage_service.dart`) | Şablonlar, ekler |

- **Otomatik + manuel ilke:** Sistem her şeyi önermeli; kullanıcı her aşamada elle düzeltebilmelidir (bkz. `AGENTS.md`).
- **AI karar zinciri:** yerel PDF okuma → geçmiş kararlar → AI (varsa) → yoksa `YkKararEslestirmeServisi` (offline) → kullanıcı onayı.

---

## 5. Paylaşılan Servisler (core/services)

| Servis | Görev |
| :--- | :--- |
| [`firestore_service.dart`](lib/core/services/firestore_service.dart:1) | Tenant farkında Firestore erişimi (`collection(path)`) |
| [`storage_service.dart`](lib/core/services/storage_service.dart:1) | Firebase Storage yükleme/indirme |
| [`ai_extraction_service.dart`](lib/core/services/ai_extraction_service.dart:1) | Gemini ile metin/veri çıkarımı |
| [`google_vision_ocr_service.dart`](lib/core/services/google_vision_ocr_service.dart:1) | Görsel OCR |
| [`sablon_service.dart`](lib/core/services/sablon_service.dart:1) | Şablon CRUD |
| [`sistem_ayarlari_service.dart`](lib/core/services/sistem_ayarlari_service.dart:1) | Sistem ayarları (IBAN, AI anahtarı, şablon) |
| [`birim_service.dart`](lib/core/services/birim_service.dart:1) | Birim listesi (tenant + fallback) |

---

## 6. Değişmez Kurallar (özet — tamamı `AGENTS.md`)

1. Karar ve gündem **ayrı** içerik/controller/kayıt olmalı; birbirini ezmemeli.
2. Gündem kaydet, karar kaydet fonksiyonunu çağırmamalı.
3. Şablon havuzu ve manuel düzeltme hakkı asla kaldırılmamalı.
4. AI çıktısı kullanıcı onayı olmadan kalıcı karar sayılmaz.
5. Fatura matbu 12 DOKUNULMAZ madde (Nakli Yekün hizası, çift sayım, `sayfayiBol`, KDV muafiyet vb.).
6. **Satır limiti/otomatik sayfalama iptal edilmiştir**; sayfa yalnızca `sayfayiBol == true` ile bölünür.
7. Hiçbir dosya 2000 satıra ulaşmamalı; UI parçalanmalı, iş mantığı servise taşınmalı.

---

## 7. "Nereye Bakmalıyım?" İndeksi

| İhtiyaç | Dosya |
| :--- | :--- |
| Fatura PDF çıktı biçimi | [`fatura_pdf_uretici.dart`](lib/features/fatura/services/fatura_pdf_uretici.dart:1) |
| Fatura matbu alan konumları/ayarları | [`fatura_matbu_config.dart`](lib/features/fatura/models/fatura_matbu_config.dart:1) |
| Fatura görsel ekran hizalaması | [`visual_entry_screen.dart`](lib/features/fatura/screens/visual_entry_screen.dart:1) |
| Beyanname KDV/Muhtasar/Damga formülü | [`beyanname_hesaplama_motoru.dart`](lib/features/beyanname/services/beyanname_hesaplama_motoru.dart:1) |
| Birim vergi muafiyet/rol kuralları | [`birim_vergi_profili.dart`](lib/features/beyanname/models/birim_vergi_profili.dart:1) |
| Birim adı alias/canonical | [`birim_model.dart`](lib/features/birim/models/birim_model.dart:1) → `BirimAdlandirma` |
| YK Word/PDF üretimi | [`belge_uretim_servisi.dart`](lib/features/yk_karar/services/belge_uretim_servisi.dart:1) |
| Danışmanlık Excel hesabı | [`danismanlik_excel_hesaplama.dart`](lib/features/danismanlik/services/danismanlik_excel_hesaplama.dart:1) |
| Türkçe sayı/tarih biçimi | [`turkce_format.dart`](lib/core/turkce_format.dart:1) |
| Tenant/kurum erişimi | [`firestore_service.dart`](lib/core/services/firestore_service.dart:1) |
| Renk/tasarım tokenleri | [`app_colors.dart`](lib/core/theme/app_colors.dart:1) + [`app_theme.dart`](lib/core/theme/app_theme.dart:1) |
| Rotalar ve yetki | [`app_router.dart`](lib/router/app_router.dart:1), [`guards.dart`](lib/router/guards.dart:1) |

---

## 8. QA Komutları

```powershell
flutter analyze                      # statik analiz (0 issue hedefi)
flutter test                         # birim testleri
node test_tum_birimler.js            # YK birim regression
node verify_sablon_tablolari.js UBATAM
```

---

## 9. Çok-Kurumlu (Tenant) Yol Haritası — kısa

Faz 0 tenant izolasyonu → Faz 1 config repository → Faz 2 Merkez Konsolu + Yetki Matrisi →
Faz 2b Ortak Yönetim Modülü → Faz 3 modül sabitleri → Faz 4 markalama/lisans → Faz 5 migrasyon.
Ayrıntı: [`MERKEZI_MIMARI_ONERISI.md`](MERKEZI_MIMARI_ONERISI.md:1)
