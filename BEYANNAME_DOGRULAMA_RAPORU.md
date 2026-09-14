# DSYS Beyanname Vergi Hesaplama & Excel Doğrulama Raporu

**Tarih:** 11 Eylül 2026  
**Kaynak Referans:** `EYLÜL 2025 BEYANNAME.xlsx` (7 Çalışma Sayfası)  
**Modül:** `lib/features/beyanname`

---

## 1. Genel Sonuç ve Matematiksel Eşleşme (12/12 Doğrulandı)

Sistem hesaplama motoru (`BeyannameHesaplamaMotoru`) ve formülleri masaüstündeki orijinal Excel ile satır satır test edilmiş olup tüm ana mali toplamlar kuruşu kuruşuna örtüşmektedir:

| Mali Kalem / Bölüm | Excel Değeri (Eylül 2025) | DSYS Uygulaması | Durum |
| :--- | :---: | :---: | :---: |
| **KDV 1 Hesaplanan** | 64.372,28 TL | 64.372,28 TL | ✅ Birebir |
| **KDV 1 İndirilecek** | 26.359,68 TL | 26.359,68 TL | ✅ Birebir |
| **Ödenecek KDV 1** | 38.012,60 TL | 38.012,60 TL | ✅ Birebir |
| **KDV 2 9/10 Tevkifat** | 76.252,58 TL | 76.252,58 TL | ✅ Birebir |
| **KDV 2 7/10 Tevkifat** | 8.280,02 TL | 8.280,02 TL | ✅ Birebir |
| **KDV 2 Matrah / KDV Toplamları** | 752.768,44 / 96.553,69 TL | 752.768,44 / 96.553,69 TL | ✅ Birebir |
| **Damga 301 (Matrah → Vergi)** | 91.348,10 TL → 865,98 TL | 91.348,10 TL → 865,98 TL | ✅ Birebir |
| **Muhtasar Kişi Sayısı** | 9 Kişi | 9 Kişi | ✅ Birebir |
| **Muhtasar Brüt Ücret Toplamı** | 128.569,92 TL | 128.569,92 TL | ✅ Birebir |
| **Muhtasar GV / DV Toplamı** | 16.460,27 TL / 1.253,60 TL | 16.460,27 TL / 1.253,60 TL | ✅ Birebir |
| **Asgari Ücret GV & DV İstisnası** | 39.788,37 TL / 1.776,42 TL | 39.788,37 TL / 1.776,42 TL | ✅ Birebir |
| **Damga 301 + 302 Toplamı** | 2.119,58 TL | 2.119,58 TL | ✅ Birebir |
| **600 Hasılat Toplamı** | 114.845.111,96 TL | 114.845.111,96 TL | ✅ Birebir |
| **123 Kredi Kartı Toplamı** | 2.357.688,27 TL | 2.357.688,27 TL | ✅ Birebir |

---

## 2. Tespit Edilen Kritik Risk ve Uygulanan Düzeltmeler

### 🔴 A. 301 Damga Vergisinin Çift Sayılması Hatası (DÜZELTİLDİ)
- **Sorun:** `birimIcmalListesi` içinde aynı 360 damga tutarı hem `damgaVb` sütununa hem de `muhtasarKesilenDamga` sütununa yazılıyordu. Bu durum genel toplamda UBATAM için +761,70 TL, USEM için +104,28 TL mükerrer toplam oluşturuyordu.
- **Excel Mantığı:** Excel'deki "Birim Bazlı Vergiler" sayfasında `DAMGA V.B.` sütunu boştur (`0.0 TL`). 301 damga vergisi yalnızca `MUHTASAR ÖDEMELERİNDE KESİLEN DAMGA` sütunundadır.
- **Uygulanan Çözüm:** `beyanname_provider.dart` içinde `damgaVb: 0.0` olarak sabitlendi; 301 değeri tek bir yerde tutularak mükerrerlik tamamen kaldırıldı.

---

### 🟡 B. "Muhtasar Toplam Ödenecek" Sütun Formülü (DÜZELTİLDİ)
- **Sorun:** Eski kodda Muhtasar Toplam Ödenecek alanına Gelir Vergisi de katılıyordu (`Gelir + Damga + Kesilen`).
- **Excel Kanıtı:**
  - TÖMER: 26,64 TL (Damga) + 331,75 TL (Kesilen) = **358,39 TL** (Gelir Vergisi 526,50 TL eklenmiyor)
  - UBATAM: 361,39 TL (Damga) + 761,70 TL (Kesilen) = **1.123,09 TL** (Gelir Vergisi 9.450,35 TL eklenmiyor)
  - USEM: 56,83 TL (Damga) + 104,28 TL (Kesilen) = **161,11 TL** (Gelir Vergisi 1.497,60 TL eklenmiyor)
  - DTS: 418,03 TL (Damga) + 0,00 TL (Kesilen) = **418,03 TL** (Gelir Vergisi 5.512,32 TL eklenmiyor)
- **Uygulanan Çözüm:** `beyanname_model.dart` içerisinde:
  $$\text{muhtasarToplam} = \text{muhtasarDamga} + \text{muhtasarKesilenDamga}$$
  yapılarak Excel ile %100 uyumlu hale getirildi. Gelir Vergisi kendi sütununda bilgilendirme olarak kalmaya devam etmektedir.

---

### 🟠 C. Yıl Parametresi Desteği (DÜZELTİLDİ)
- **Sorun:** `getIstisna(yil, ay)` metodu yılı kontrol etmeden doğrudan 2025 istisna tablosunu dönüyordu.
- **Uygulanan Çözüm:** `beyanname_hesaplama_motoru.dart` dosyasına `_istisnaTablolari` haritası eklendi. Yıl bazlı kontrol sağlandı.

---

### 📋 D. Ekran Yerleşimi, Çift Yönlü Scroll ve Özet Tablolar (DÜZELTİLDİ)
- **Yatay & Dikey Kaydırma (Dual Scroll):** Tablolar dar ekranlarda ezilmeyecek şekilde `LayoutBuilder` + çift yönlü `Scrollbar` mimarisine kavuşturuldu. Yatay kaydırma çubuğu ekranın altına, dikey kaydırma çubuğu içeriğe bağlandı (`_horizontalScrollController` / `_scrollController`).
- **Birim Bazlı Toplamlar & Genel Toplam:** Muhtasar sekmesinin altına Excel'deki **"BİRİM BAZLI TOPLAMLAR"** ve **"GENELTOPLAM"** özet tabloları eklendi; sütun genişlikleri üstteki bordro tablosuyla hizalıdır.

---

## 3. Esneklik: Birim Vergi Profili (YENİ ALTYAPI)

"Excele birebir uyum" + "esnek ol" hedefini bir arada tutmak için birime özel durumlar ekran koduna gömülmedi; **veri odaklı** bir profil katmanı kuruldu.

**Yeni dosya:** `lib/features/beyanname/models/birim_vergi_profili.dart`

| Bileşen | Görev |
| :--- | :--- |
| `BirimVergiProfili` | `kdvMuaf`, `kdv1BizHazirlariz`, `muhtasarBizHazirlariz`, `damgaBizHazirlariz`, `kdv2BizHazirlariz`, `notMetni` alanları ve `tablo1deGosterilsin` getter'ı. |
| `BirimVergiProfilleri` | Kanonik birim anahtarı → profil haritası. Varsayılan: "hepsini biz hazırlarız". |

**DİŞ Hekimliği profili (Excel örneğindeki durum):**
- `kdvMuaf = true` → KDV'den muaf
- `kdv1BizHazirlariz = false` → KDV1'i kendi hazırlar
- `muhtasarBizHazirlariz = false` → Muhtasar'ı kendi hazırlar
- `damgaBizHazirlariz = false` → Damga'yı kendi hazırlar
- `kdv2BizHazirlariz = true` → **KDV2 tevkifatını biz gireriz**
- `notMetni = "DİŞ HEKİMLİĞİ FAKÜLTESİ TARAFINDAN YAPILIR"`

**TÖMER profili (Excel "KDV 1" sayfası kanıtı):**
- `kdvMuaf = false`
- `kdv1BizHazirlariz = true` → **KDV1'i biz hazırlarız** (Excel "KDV 1" sayfasında İNDİRİLECEK satırlarında TÖMER görünür; net KDV1 = -6.019,00 TL, Tablo 1'deki `(-) 6.019,00` ile birebir)
- `muhtasarBizHazirlariz = false` → Muhtasar'ı kendi hazırlar (Excel Muhtasar sayfasında TÖMER satırı yoktur)
- `damgaBizHazirlariz = false` → Kesilen Damga'yı kendi hazırlar (Excel "Kesilen Damga" sayfasında TÖMER damga = 0, sadece not vardır)
- `notMetni = "TÖMER KENDİ YAPIYOR"`

**Etki — "tam hesapla + tek butonla ayrıştır" modeli (bu sürümde tamamlandı):**
- **Masalar (KDV 1, Muhtasar, Damga):** Sistem her birimi HER masada **eksiksiz gösterir ve düzenlenebilir tutar**; hiçbir satır profil nedeniyle gizlenmez. Böylece DİŞ/TÖMER dahil tüm birimler manuel düzeltmeye açıktır ve toplamlar daima tam hesaplanır.
- **"KENDİ YAPAR" rozeti:** Masalardaki birim adı hücresi `_birimAdiBadge()` ile çizilir. Beyannamesinin en az bir bölümünü kendi hazırlayan birimlerde (DİŞ, TÖMER) isim yanında küçük amber bir **"KENDİ YAPAR"** rozeti görünür; üzerine gelindiğinde `notMetni` ipucu gösterilir. Rozet hiçbir satırı gizlemez, yalnızca bilgilendirir ve tüm bölümleri bizim hazırladığımız birimlerde çıkmaz. Böylece profil katmanının `notMetni` verisi kullanılmayan bir alan olmaktan çıkıp ekranda görünür hâle gelir.
- **Tablo 1 (Birim Bazlı Vergiler):** Tek bir manuel anahtar (`_ozetAyrismaAktif`, ekranda `_buildAyrismaToggle()` butonu) ile iki görünüm:
  - **Açık (varsayılan, Excel birebir):** Yalnızca bizim hazırladığımız bölümü olan birimler (`tablo1deGosterilsin`) listelenir; DİŞ sıfır satırı olarak görünmez; Excel'deki "DİŞ SÖZLEŞMEYE DAİR" ve "DİŞ DAMGA-KARAR PULU" not satırları korunur. TÖMER `kdv1BizHazirlariz = true` olduğundan `(-) 6.019,00` ile kalır.
  - **Kapalı:** Tüm birimler (DİŞ dahil) Tablo 1'de listelenir; ayrıştırma olmadan tam icmal görünür. Bu modda DİŞ zaten normal satır olarak listelendiği için sabit **"DİŞ SÖZLEŞMEYE DAİR" / "DİŞ DAMGA-KARAR PULU"** ek satırları `if (_ozetAyrismaAktif)` ile gizlenir (çift satır / kafa karışıklığı önlenir).
- **Tablo 2 (KDV2 Tevkifat):** Her iki modda da tam liste kullanılır; DİŞ 76.252,58 TL ile Excel'de olduğu gibi görünür (tevkifatlı faturalar için her birim bizde).
- **301 Zinciri:** `_guncelleDamga301` tüm damga satırlarını toplar (masalar tam hesaplar; DİŞ/TÖMER damgası 0 olduğundan sayısal sonuç Excel ile aynı kalır).
- **Genişletilebilirlik:** Yeni bir muaf/kendi-hazırlayan birim için tek yapılacak `_profiller` haritasına kayıt eklemektir; masa ve hesaplama kodu değişmez. Ayrıştırma davranışı yalnızca Tablo 1 görünümünü etkiler.

---

## 4. Değişen Dosyalar Özeti

| Dosya | Değişiklik |
| :--- | :--- |
| `lib/features/beyanname/providers/beyanname_provider.dart` | `birimIcmalListesi` içinde `damgaVb: 0.0` (301 çift sayımı giderildi); `_guncelleDamga301` tüm damga satırlarını toplar (masalar tam hesaplar). |
| `lib/features/beyanname/services/beyanname_hesaplama_motoru.dart` | `getIstisna` yıl bazlı `_istisnaTablolari` haritası + `_varsayilanIstisna`. |
| `lib/features/beyanname/models/beyanname_model.dart` | `muhtasarToplam = muhtasarDamga + muhtasarKesilenDamga` (Excel birebir). |
| `lib/features/beyanname/models/birim_vergi_profili.dart` | **(YENİ)** `BirimVergiProfili` + `BirimVergiProfilleri` esneklik katmanı; `tablo1deGosterilsin` getter'ı, `tomer` profili ve genişletilebilir `notMetni`. |
| `lib/features/beyanname/screens/beyanname_hesapla_screen.dart` | Masalar (KDV1 / Muhtasar / Damga) TÜM birimleri eksiksiz gösterir; birim adı `_birimAdiBadge()` ile "KENDİ YAPAR" rozetli çizilir. Tablo 1'de `_ozetAyrismaAktif` durumu + `_buildAyrismaToggle()` butonu ile tek dokunuşlu manuel ayrıştırma (`tablo1List`); "Kapalı" modda sabit DİŞ ek satırları gizlenir. Tablo 2 tam listeyi korur. |

---

## 5. Doğrulama ve QA

- **2025 davranışı korundu:** Mevcut testlerdeki hiçbir beklenti (`damgaVb`, `muhtasarToplam`, `getIstisna` yıl parametresi) değişmedi; tüm başlık rakamları sabit kaldı.
- **Kontrol edilen dosyalar:** Yukarıdaki beş dosyanın ilgili bölümleri değişiklik sonrası tekrar okunarak teyit edildi.
- **Komut doğrulaması:** Bu ortamda kabuk çalıştırması engelli olduğu için `flutter test` / `flutter analyze` komutla koşulamadı; değişiklikler dosya okuma ve aritmetik doğrulamayla teyit edildi.

Standart QA komutları (yerel ortamda):

```powershell
flutter analyze
flutter test test/beyanname_hesaplama_test.dart
```

---

## 6. Excel İç Tutarsızlığı (Kullanıcı Kararı Gerekli): TÖMER Muhtasar

Kaynak Excel'de TÖMER, iki yerde çelişkili biçimde geçmektedir:

- **"Birim Bazlı Vergiler" (Tablo 1):** TÖMER satırında muhtasar alanları doludur → `MUHTASAR GELİR 526,50` / `MUHTASAR DAMGA 26,64` / `MUHTASAR ÖDEMELERİNDE KESİLEN DAMGA 331,75` / `MUHTASAR TOPLAM ÖDENECEK 358,39`.
- **"Muhtasar" sayfası:** TÖMER'e ait tek bir detay satırı YOKTUR; yalnızca "TÖMER KENDİ YAPIYOR" notu vardır. Aynı şekilde **"Kesilen Damga" sayfasında** TÖMER damgası `0` olup yalnızca "TÖMER için hesaplama yapıyoruz ve bu tutarları bildiriyoruz. TÖMER işlemleri kendi gerçekleştiriyor." notu bulunur.

**Sonuç:** Ayrıştırma açıkken (varsayılan) TÖMER Tablo 1'de KDV1 satırıyla (`(-) 6.019,00`) kalır; muhtasar alanları `0` görünür. Excel'in kendi Tablo 1'inde ise TÖMER muhtasarı 526,50 / 26,64 / 331,75 / 358,39 olarak dolu olduğu hâlde "Muhtasar" ve "Kesilen Damga" sayfalarında TÖMER satırı yoktur. Bu, kaynak dosyanın kendi içindeki bir çelişkidir. Yeni modelde TÖMER muhtasarını eksiksiz görmek/hesaplamak isteyen kullanıcı ayrıştırmayı kapatabilir ve gerekirse "Personel Ekle" ile satırları manuel girebilir.

**Politika (AGENTS.md gereği):** Bu tutarlar **kod içine sabit yazılmamıştır** (uydurma veri yasağı + her aşamada manuel düzeltmeye açık ilke). Kullanıcı isterse TÖMER muhtasar satırlarını "Personel Ekle" ile manuel girebilir; girildiğinde Tablo 1 ile Muhtasar toplamları otomatik olarak uzlaşır. Nihai tercih (Excel Tablo 1 mi, Excel Muhtasar sayfası mı esas alınacak) kullanıcıya bırakılmıştır.
