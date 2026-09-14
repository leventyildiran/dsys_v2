# Beyanname Esneklik Planı — Kurum Bazlı Yapılandırma

> Durum: Faz 0 uygulanıyor
> Kapsam: `lib/features/beyanname/`
> İlke: "Tam dinamik, otomatik ama her aşamada manuel düzeltmeye açık."
> Dokunulmazlar: `AGENTS.md` Yürütme Kurulu mantığı, `RENK_SISTEMI.md` (yalnız `AppColors`), karar/gündem ayrımı.

---

## 1. Amaç

Uygulama ticarileşiyor ve çok-kurumlu ("merkez") bir mimariye geçiyor. Bugün beyanname modülü
tek bir kurumun (ve yalnızca iki birimin: DİŞ, TÖMER) sabit varsayımlarına göre kodlanmış.
Hedef: **her kurumun kendi KDV oranlarını, tevkifat türlerini, damga oranını, birim
profillerini ve görünecek bloklarını** kod değiştirmeden tanımlayabilmesi.

---

## 2. Mevcut Darboğazlar (kod kanıtlı)

| # | Darboğaz | Konum |
|---|---|---|
| 1 | Birim profilleri sabit `const Map` (yalnız `'dis'`, `'tomer'`) | [`BirimVergiProfilleri._profiller`](lib/features/beyanname/models/birim_vergi_profili.dart:62), [`getir()`](lib/features/beyanname/models/birim_vergi_profili.dart:86) |
| 2 | Damga oranı binde `9.48` gömülü | [`matrahFromDamga()`](lib/features/beyanname/services/beyanname_hesaplama_motoru.dart:321), [`damgaFromMatrah()`](lib/features/beyanname/services/beyanname_hesaplama_motoru.dart:327) |
| 3 | Tevkifat türleri 3 sabit değer | [`TevkifatTuru`](lib/features/beyanname/models/beyanname_model.dart:2) |
| 4 | KDV2 oran kovaları sabit `8/10/18/20` | [`hesaplaKdv2`](lib/features/beyanname/services/beyanname_hesaplama_motoru.dart:219) |
| 5 | Asgari ücret istisna tablosu yalnız 2025 | [`_istisnaTablolari`](lib/features/beyanname/services/beyanname_hesaplama_motoru.dart:138) |
| 6 | KDV oran doğrulaması `0.10`/`0.20` sabit | [`beyanname_dogrulama.dart`](lib/features/beyanname/services/beyanname_dogrulama.dart:91) |
| 7 | Birime özel ekran dalları (DİŞ/TÖMER) | [`beyanname_hesapla_screen.dart`](lib/features/beyanname/screens/beyanname_hesapla_screen.dart:718), [:1448](lib/features/beyanname/screens/beyanname_hesapla_screen.dart:1448), [:1549](lib/features/beyanname/screens/beyanname_hesapla_screen.dart:1549) |
| 8 | İcmal tevkifat toplamı 3 türü elle toplar | [`beyanname_provider.dart`](lib/features/beyanname/providers/beyanname_provider.dart:202) |
| 9 | Birim kaynağı `BirimModel.varsayilanBirimler` (+ örnek veri) | [`beyanname_provider.dart`](lib/features/beyanname/providers/beyanname_provider.dart:398), [:769](lib/features/beyanname/providers/beyanname_provider.dart:769) |

---

## 3. Hedef Mimari

### 3.1 Yeni model: `BeyannameKonfigurasyonu`

`lib/features/beyanname/models/beyanname_konfigurasyonu.dart`

- `KdvOranTanimi { int oran; String? etiket }` — KDV oran seti (örn. `[10, 20]`). Gelecekte `[1, 8, 10, 20]`.
- `TevkifatTanimi { String etiket; int pay; int payda }` — serbest tevkifat listesi.
- `BeyannameBloklari { kdv1, kdv2, muhtasar, damga301, damga302, hasiat600, krediKarti123 }` — hangi tablo görünsün.
- `damgaBinde: double` (varsayılan `9.48`) — damga oranı tek kaynaktan.
- `birimProfilleri: Map<String, BirimVergiProfili>` — profil haritası config'e taşınır.
- `toMap()/fromMap()` — Firestore serileştirmesi (Faz 1).

**Kritik:** `BeyannameKonfigurasyonu.varsayilan` değerleri bugünkü sabitlerle **birebir aynıdır**.
Bu sayede Faz 0 sonunda davranış hiç değişmez; yalnız "tek kaynak" oluşur.

### 3.2 Yeni servis (Faz 1): `BeyannameKonfigurasyonServisi`

- Firestore'dan kurum bazlı konfigürasyonu yükler; kayıt yoksa `varsayilan` döner.
- Ayarlar ekranı: "Beyanname Yapılandırması" (oranlar, tevkifat listesi, birim profilleri toggles).

---

## 4. Kademeler (düşük riskli, geri dönüşsüz olmayan)

### Faz 0 — Altyapı çıkarımı (davranış birebir aynı)
1. `BeyannameKonfigurasyonu` modelini oluştur; varsayılanlar bugünkü sabitler.
2. `BirimVergiProfilleri` haritasını config'e referansla (davranış aynı).
3. Motor damga oranını config varsayılanından al (opsiyonel `binde` parametresi).
4. Doğrulama KDV oranlarını config'den al.
5. **Parite testi:** config varsayılanı ile bugünkü sonuçlar aynı.

### Faz 1 — Kurum bazlı kalıcılık + UI
6. `BeyannameKonfigurasyonServisi` (Firestore load/save).
7. Ayarlar → "Beyanname Yapılandırması" ekranı (yalnız `AppColors`).

### Faz 2 — Birim/branş dinamikleştirme
8. DİŞ/TÖMER ekran dallarını profil-güdümlü yap.
9. `TevkifatTuru` enum'unu `TevkifatTanimi` listesine genişlet (geriye dönük uyumlu).

### Faz 3 — Veri tabloları
10. Yıllık asgari ücret istisna tablolarını config'e taşı / yeni yıl ekle.
11. `BirimModel.varsayilanBirimler` yerine kurum `birimler` koleksiyonundan besleme.

---

## 5. Dokunulmazlar (her fazda korunur)

- Renk: yalnız `AppColors.<token>`; ham `Color(0x..)`/`Colors.*` yasak.
- Yürütme Kurulu karar/gündem ayrımı ve şablon havuzu.
- Kullanıcının manuel düzeltme hakkı; AI/otomatik çıktı geri dönüşsüz eklenmez.
- Dosya başına ~2000 satır sınırı: iş mantığı servis/modelde ayrışır.

---

## 6. Dosya Etkisi (Faz 0)

| Dosya | Değişiklik |
|---|---|
| `models/beyanname_konfigurasyonu.dart` | **YENİ** |
| `models/birim_vergi_profili.dart` | Ekleme: `tumProfiller`, `varsayilanProfil` getter |
| `services/beyanname_hesaplama_motoru.dart` | Damga oranı opsiyonel `binde` + config varsayılanı |
| `services/beyanname_dogrulama.dart` | KDV oranları config'den |
| `test/beyanname_konfigurasyon_test.dart` | **YENİ** — parite testi |

---

## 7. QA

```powershell
node test_tum_birimler.js
flutter test test/beyanname_konfigurasyon_test.dart
flutter test test/beyanname_dogrulama_test.dart
```

> Not: Bu ortamda `execute_command` kapalı olduğu için doğrulama grep + imza çapraz kontrolü
> + yazılan birim testleriyle yapılır.
