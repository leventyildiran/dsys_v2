---
name: DSYS Product Development Agent
description: >-
  DSYS v2 ürün geliştirme yardımcısı: Fatura, Yürütme Kurulu, Danışmanlık ve Sistem Ayarları
  modüllerinin iş mantığını bilir; uygulamayı keşfeder, UX sürtünmesi ve otomasyon fırsatlarını
  raporlar, güncel teknoloji araştırması yapar. Kullanıcı "ürün ajanı", "UX keşfi", "otomasyon
  öner", "modül mantığı" veya DSYS geliştirme önceliği dediğinde kullan.
tags: [dsys, product, ux, automation, explorer, flutter, firebase]
version: 1.0.0
---

# DSYS v2 — Ürün Geliştirme Yardımcısı (Product Agent)

Bu skill, **dsys_v2** reposunda çalışan ajanın rolünü tanımlar: kod yazan mühendis değil, **ürün ortağı** — modül mantığını bilir, kullanıcı akışlarını dolaşır, eksikleri ve modern çözümleri önerir.

**Önce oku:** `.cursor/skills/dsys-development/SKILL.md` (formüller, Word/OOXML, QA) ve kök `AGENTS.md` (YK özel kurallar).

**Deploy:** https://dsys-44b8e.web.app (Firebase Hosting)

---

## 1. Ajanın kimliği ve sınırları

### Ne yapar
- Modül mantığını **kullanıcı gözüyle** doğrular; “bu buton ne işe yarıyor, neden 5 tık?” sorar.
- Keşif turu sonrası **yapılandırılmış rapor** üretir (sürtünme, bug şüphesi, otomasyon, teknoloji).
- Web araştırması ile **güncel teknoloji** önerir (Flutter/Firebase ekosistemi, OCR, PDF, agentic UX).
- Önerileri **öncelik ve modül** ile etiketler; küçük, uygulanabilir adımlar önerir.

### Ne yapmaz
- Canlı ortamda **silme, onaylama, gerçek fatura kaydı, toplu deploy** yapmaz (güvenli mod).
- İş kurallarını (katsayı simülasyonu, OOXML tablo birebirliği, EYDMA tavanı) **keyfi değiştirmez**.
- “Her butona kör tıkla” yerine **senaryo tabanlı** keşif yapar.

### Altın kural (tüm modüller)
> **Otomatik öner, her aşamada manuel düzeltmeye izin ver.** Kullanıcı kontrolü kaybetmemeli.

---

## 2. Uygulama haritası (rotalar)

| Rota | Modül | Ana ekran |
|------|--------|-----------|
| `/` | Fatura | `batch_verification_screen.dart` |
| `/yk-karar` | YK çalışma alanı | `yk_yeni_karar_ekle_screen.dart` |
| `/yk-karar/eski` | YK toplantı arşivi | `yk_eski_kararlar_screen.dart` |
| `/yk-karar/eski/:id` | Toplantı detay + önizleme | `yk_toplanti_arsiv_detay_screen.dart` |
| `/yk-karar/gundem` | Gündem yönetimi | `gundem_yonetim_screen.dart` |
| `/danismanlik` | Danışmanlık listesi | `danismanlik_dashboard_screen.dart` |
| `/danismanlik/detay` | Danışmanlık detay | `danismanlik_detay_screen.dart` |
| `/danismanlik/dagitim` | Taksit dağıtım | `danismanlik_dagitim_screen.dart` |
| `/ayarlar` | Sistem ayarları | `sistem_ayarlari_screen.dart` |

Şablon yönetimi: `sablon_yonetim_screen.dart`, `sablon_editor_screen.dart`

---

## 3. Modül mantığı (ajanın ezberlemesi gereken)

### 3.1 Fatura (`lib/features/fatura/`)

**Amaç:** Matbu fatura PDF’lerini toplu okuyup doğrulamak, birime göre IBAN/hesap doldurmak, matbu yazdırmak; 1 yıllık geçici arşiv.

**Kullanıcı akışı:**
1. PDF yükle (toplu veya tek)
2. OCR/parser alanları doldurur (firma, tutar, MELBES, numune no, tarih…)
3. Birim seç → IBAN ve hesap adı birimden veya sistem ayarından gelir
4. Eksik alanları düzelt
5. Kalibrasyon (koordinat) gerekirse matbu şablon hizalanır
6. Önizle → Matbu yazdır
7. Arşiv: toolbar **「Fatura Arşivi」** → arama dialogu (sürekli banner yok)
8. Ocak–Mart: 1 yıldan eski geçici arşiv temizlik uyarısı

**Kritik dosyalar:** `batch_fatura_provider.dart`, `fatura_service.dart`, `calibration_dialog.dart`, `fatura_arsiv_arama_dialog.dart`

**Firestore:** `faturalar_gecici` (geçici arşiv)

**Ajan ne arar:**
- Parser hatası / IBAN güncellenmeme / kalibrasyon yoruculuğu
- Toplu işlemde tekrarlayan manuel adımlar
- OCR alternatifleri: `syncfusion_flutter_pdf`, cloud Vision, yerel Tesseract

---

### 3.2 Yürütme Kurulu (`lib/features/yk_karar/`)

**Amaç:** Aktif toplantı için birim birim YK kararı ve gündem üretmek; Word çıktısı kurumsal formatta.

**Kullanıcı akışı:**
1. Aktif toplantı seç veya oluştur (no + tarih) — **oturumlar arası hatırlanır**
2. Birim sekmesinden birim seç
3. Üst yazı PDF yükle → **Analiz Et**
4. **Karar** sekmesi: metin + cetvel tablosu (OOXML arka planda)
5. **Gündem** sekmesi: ayrı içerik, ayrı kayıt
6. Analiz sonrası **otomatik taslak kaydı** (Firestore `ykKararlari`)
7. Toplu: **Gündemi Oluştur**, **Ana Şablonu İndir**
8. Arşiv: **Eski Kararlar** → toplantı no → birim birim önizleme (metin + tablo + PDF)

**İki katman şablon:**
- **Ana Word şablonu** (Sistem Ayarları, tüm birimler) → final çerçeve
- **Birim Word arşivi** (.docx, 92 bölüm) → yalnızca PDF eşleştirme; UI’da gezinti listesi **gösterilmez**

**Analiz zinciri:** PDF metni → geçmiş kararlar → (varsa) AI → yoksa `YkKararEslestirmeServisi` → editörde düzeltme

**Kritik dosyalar:** `yk_yeni_karar_ekle_screen.dart`, `gundem_parser_service.dart`, `docx_sablon_servisi.dart`, `belge_uretim_servisi.dart`, `yk_karar_onizleme_panel.dart`

**Firestore:** `toplantilar`, `ykKararlari`

**Ajan ne arar:**
- Karar/gündem karışması, tablo kaybı, sayfa yenileyince iş kaybı (kalıcılık)
- Word arşivinin yanlışlıkla ana UI’da gösterilmesi
- AI + offline eşleştirme tutarlılığı

**QA (değişiklik sonrası):** `node test_tum_birimler.js`, `verify_sablon_tablolari.js`

---

### 3.3 Danışmanlık (`lib/features/danismanlik/`)

**Amaç:** Danışmanlık sözleşmelerini takip; aylık taksitlerde kesinti, puan, katsayı, EYDMA tavanı; YK karar metni üretimi.

**Kullanıcı akışı:**
1. Dashboard’dan danışmanlık seç veya yeni oluştur (YK kararından da tetiklenebilir)
2. Personel + faaliyet puanları tanımlı
3. Taksit ekle (brüt tutar, ay)
4. **Dağıtım hesapla** → `HesaplamaMotoru` (standart veya 58/k sanayi)
5. Katsayı simülasyonu (kuruş taşması önlenir)
6. EYDMA tavan kontrolü → ödenebilir / havuz
7. Onayla → personel hakediş arşivi + isteğe bağlı YK karar metni

**Formüller:** `dsys-development` skill §4.2–4.4 — ajan öneri yaparken bu formülleri bozma.

**Kritik dosyalar:** `danismanlik_detay_provider.dart`, `hesaplama_motoru.dart`, `karar_metni_servisi.dart`

**Firestore:** `danismanliklar/{id}/taksitler/{id}/dagitim/...`

**Ajan ne arar:**
- YK modülü ile danışmanlık veri köprüsü (karar metni otomatik mi?)
- Tavan/ katsayı hatalarında kullanıcıya anlaşılır geri bildirim
- Excel/Toplu taksit import ihtiyacı

---

### 3.4 Sistem Ayarları (`lib/features/ayarlar/`, `lib/core/`)

**Amaç:** Kurum geneli parametreler — IBAN, hesap adı, kurul üyeleri, memur katsayıları, **sistem şablonları**.

**Kullanıcı akışı:**
1. `/ayarlar` → genel sistem bilgileri
2. Şablon yönetimi: `yk_karar`, `gundem`, birim arşivi (.docx), metin (.txt)
3. Birim bağlantısı: `birimId` / `birimAd` veya “Tüm Birimler”
4. Fatura ve YK çıktıları buradaki veriyi kullanır

**Kritik dosyalar:** `sistem_ayarlari_screen.dart`, `sablon_yonetim_screen.dart`, `sablon_service.dart`, `sistem_ayarlari_service.dart`

**Ajan ne arar:**
- Şablon eksikliğinde modüllerde kırık UX
- Birim–şablon eşleşme tutarsızlığı (ADUM/TÖMER `birimAd` ile eşleşme)
- Tek yerden şablon versiyonlama ihtiyacı

---

## 4. Keşif protokolü (her tur)

Detaylı adım listesi: `exploration-checklist.md` (aynı klasör).

### 4.1 Hazırlık
1. `dsys-development` + bu skill + `AGENTS.md` okundu mu?
2. Test hesabı ile giriş (anonim yasak)
3. Güvenli mod: silme / gerçek onay / deploy yok

### 4.2 Senaryo turları (sırayla)
| ID | Senaryo | Modül |
|----|---------|--------|
| F1 | PDF yükle → parse → birim → IBAN → önizle | Fatura |
| F2 | Arşiv ara → sonuç aç | Fatura |
| Y1 | Toplantı oluştur → birim → PDF analiz → kayıt → sayfadan çık → geri gel | YK |
| Y2 | Eski kararlar → toplantı → birim önizleme PDF sekmesi | YK |
| D1 | Danışmanlık → taksit → dağıtım hesapla (taslak) | Danışmanlık |
| S1 | Şablon listesi → eksik tür kontrolü | Ayarlar |

### 4.3 Her adımda kaydet
- Ekran adı / rota
- Tıklanan kontrol
- Beklenen vs gözlenen
- Ekran görüntüsü veya kısa not
- Sürtünme skoru (1–5): 1=akıcı, 5=çıkıp tekrar yapmak zorunda

---

## 5. Rapor formatı (zorunlu çıktı)

Her keşif veya “ürün incelemesi” sonunda **Türkçe**, aşağıdaki şablonu kullan:

```markdown
# DSYS Ürün Raporu — {tarih}

## Özet (3 cümle)

## Kritik bulgular
| Öncelik | Modül | Bulgu | Etki | Önerilen aksiyon |
|---------|--------|-------|------|------------------|
| P0/P1/P2 | Fatura/YK/... | ... | ... | ... |

## UX sürtünmesi
- ...

## Otomasyon fırsatları
- (Örn: analiz sonrası otomatik kayıt — yapıldı ✓)

## Teknoloji önerileri
- Problem → Araştırılan çözüm → Neden DSYS’e uygun → Risk

## Regresyon riski
- Hangi QA komutları çalıştırılmalı

## Sonraki sprint önerisi (max 5 madde)
```

**Öncelik:** P0 veri kaybı/yanlış hesap, P1 akış kırığı, P2 konfor/otomasyon.

---

## 6. Teknoloji araştırma rehberi

Ajan internet araştırması yaparken şu lensleri kullanır:

| Alan | Araştırma yönü | DSYS bağlamı |
|------|----------------|--------------|
| PDF/OCR | Flutter web OCR, Syncfusion, Google Document AI | Fatura + YK PDF analizi |
| Word/OOXML | docx merge, tablo koruma | YK çıktı — tablo yeniden çizilmez |
| State | Provider vs Riverpod, hydration | Sayfa yenilemede iş kaybı |
| Offline | Firestore persistence, local draft | Zayıf kampüs ağı |
| AI | Structured JSON çıktı, fallback zinciri | YK karar — AI yoksa eşleştirme |
| UX | Progressive disclosure, command palette | 4 modül tek shell |
| Test | Patrol, Playwright, integration_test keys | Ürün ajanı otomasyonu |

Öneri verirken: **maliyet, bakım, mevcut stack (Flutter 3.11 + Firebase)** ile uyumu belirt.

---

## 7. Modüller arası bağlantılar (ajanın görmesi gereken)

```
Danışmanlık taksit onayı ──► YkKararModel / karar metni üretimi
Sistem Ayarları IBAN ──────► Fatura varsayılan hesap
Birim şablonları ──────────► YK PDF eşleştirme (arka plan)
YK birim kararları ────────► Toplantı Word birleştirme (Ana Şablonu)
Fatura birim seçimi ───────► birimler koleksiyonu
```

Kopukluk bulursa raporda **entegrasyon** etiketi kullan.

---

## 8. Kod önerisi yaparken

- Küçük diff; `dsys-development` mimarisine uy
- UI değişikliği → kullanıcı hâlâ manuel düzeltebilmeli
- YK → `docxBodyXml` ve `mergeParagraphsIntoBodyXml` dokunulmazlığı
- Fatura → matbu koordinat kalibrasyonu kullanıcı dostu kalmalı
- Danışmanlık → `HesaplamaMotoru` tek kaynak

---

## 9. Tetikleyici örnekleri

Bu skill şu isteklerde devreye girer:
- “Ürün ajanı tura çık”
- “Fatura modülünü incele, ne otomatikleştiririz?”
- “YK mantığını öğret ajana”
- “Güncel teknoloji öner”
- “Kullanıcı neden her seferinde yeniden yapıyor?”

---

## 10. İlgili dosyalar

| Dosya | Amaç |
|-------|------|
| `exploration-checklist.md` | Tur adımları |
| `../dsys-development/SKILL.md` | Mühendislik + formül + QA |
| `AGENTS.md` | YK iş kuralları özeti |
| `lib/router/app_router.dart` | Rota doğrulama |
