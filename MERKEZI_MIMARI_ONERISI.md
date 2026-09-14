# Merkezî (Hub) Çok-Kurumlu Mimari Önerisi

> Amaç: DSYS'i ticarileştirip **başka kurumlara satılabilir** hale getirmek. Kullanıcının hedefi:
> "Merkezî kurum sistemi olmalı; fatura yönetimi, beyanname ve her şeyde **merkez** olmalı."
> Yani tek bir merkez tüm kurumları, birimleri, şablonları, vergi parametrelerini ve modül verilerini yönetir;
> hiçbir kuruma özel bilgi kod içine gömülü olmaz.

---

## 1. Mevcut Durum (kanıtlı tespit)

İyi haber: Projede **çok-kurumlu (multi-tenant) altyapının çekirdeği zaten mevcut**, ancak yarım uygulanmış.

**Zaten var olan doğru yapı**
- Tenant kökü: veriler `universiteler/{universiteId}/<koleksiyon>` altında tutuluyor → [`FirestoreService`](lib/core/services/firestore_service.dart:27).
- Oturum açan kullanıcının `universiteId`'si aktif tenant'ı belirliyor → [`user_provider.dart`](lib/features/auth/providers/user_provider.dart:56).
- Kullanıcı modeli kuruma bağlı → [`user_model.dart`](lib/features/auth/models/user_model.dart:39).
- Yürütme Kurulu modülü bu yapıyı doğru kullanıyor: `universiteler/{uniId}/toplantilar`, `universiteler/{uniId}/ykKararlari`.

**Tutarsızlıklar (tenant izolasyonu delik)**
- Beyanname modülü **kök koleksiyonu** kullanıyor, tenant'ı yok sayıyor → [`beyanname_provider.dart`](lib/features/beyanname/providers/beyanname_provider.dart:12) (`FirebaseFirestore.instance.collection('beyannameler')`).
- `usersCollection` kökte tanımlı, kurum altında değil → [`firestore_service.dart`](lib/core/services/firestore_service.dart:158).
- Bazı servisler tenant'lı `FirestoreService().collection(...)`, bazıları ham `FirebaseFirestore.instance` kullanıyor (karışık).

**Kuruma özel gömülü sabitler (de-hardcode edilmeli)**

| # | Sabit | Konum |
| :- | :--- | :--- |
| 1 | Birim listesi + Uşak Üniv. IBAN/VKN'leri (`varsayilanBirimler`) | [`birim_model.dart:93`](lib/features/birim/models/birim_model.dart:93) |
| 2 | Birim ad eşleştirme (`BirimAdlandirma.canonicalKey/tamAdGetir/kisaAdGetir`) | [`birim_model.dart:178`](lib/features/birim/models/birim_model.dart:178) |
| 3 | Vergi profili (DİŞ/TÖMER: KDV muafiyeti vb.) | [`birim_vergi_profili.dart:62`](lib/features/beyanname/models/birim_vergi_profili.dart:62) |
| 4 | Excel birim sırası `['dts','dosim','ubatam','usem','tadaum']` | [`beyanname_hesapla_screen.dart:1061`](lib/features/beyanname/screens/beyanname_hesapla_screen.dart:1061) |
| 5 | Sabit DİŞ satırları ("DİŞ SÖZLEŞMEYE DAİR" / "DİŞ DAMGA-KARAR PULU") | [`beyanname_hesapla_screen.dart:1589`](lib/features/beyanname/screens/beyanname_hesapla_screen.dart:1589) |
| 6 | Fatura birim kuralları (`tömer`, `ubatam`, `tarımsal`, `dösim` metin aramaları) | [`fatura_kuyruk_provider.dart:495`](lib/features/fatura/providers/fatura_kuyruk_provider.dart:495), [`fatura_eslestirme_servisi.dart:85`](lib/features/fatura/services/fatura_eslestirme_servisi.dart:85) |
| 7 | Danışmanlık şablon türleri (`usem`, `tomer`, `dosim`, `dts`, `58k`) | [`danismanlik_manuel_hesapla_screen.dart:41`](lib/features/danismanlik/screens/danismanlik_manuel_hesapla_screen.dart:41) |
| 8 | Vergi yılı sabitleri (binde 9,48 / asgari ücret istisnası) | [`beyanname_hesaplama_motoru.dart:142`](lib/features/beyanname/services/beyanname_hesaplama_motoru.dart:142) |

---

## 2. Önerilen Mimari: "Merkez Yapılandırma + Kurum İzolasyonu"

Üç katmanlı, **miras + override** modeli:

```
┌───────────────────────────────────────────────────────────────┐
│  PLATFORM / MERKEZ KATMANI  (root: platform/, universiteler)   │
│  • Süper admin konsolu    • Global şablon havuzu               │
│  • Global vergi parametreleri   • Kurum/lisans/marka yönetimi  │
└───────────────────────────────┬───────────────────────────────┘
                                │  global tanımları devralır / override eder
┌───────────────────────────────▼───────────────────────────────┐
│  KURUM (TENANT) KATMANI   universiteler/{uniId}/...            │
│  • birimler (+ IBAN/VKN + vergiProfili)   • kullanıcılar       │
│  • kuruma özel şablonlar   • kuruma özel vergi parametreleri   │
└───────────────────────────────┬───────────────────────────────┘
                                │  aynı merkezî konfigürasyonu okur
┌───────────────────────────────▼───────────────────────────────┐
│  MODÜL KATMANI                                                 │
│  Fatura • Beyanname • Danışmanlık • Yürütme Kurulu             │
│  (hiçbiri kuruma özel kod içermez; config'i tenant'tan okur)   │
└───────────────────────────────────────────────────────────────┘
```

**İlke:** Merkez "varsayılan/global" değeri tanımlar; kurum bu değeri ya **devralır** ya da **override** eder. Böylece yeni bir kurum açıldığında hiç kod değişmeden çalışır; yalnızca veri girilir.

---

## 3. Önerilen Firestore Şeması

```
platform/
  ayarlar/{docId}             # global markalama, lisans, varsayılanlar
  sablonlar/{sablonId}        # global Word şablon havuzu (yk_karar, gundem)
  vergiParametreleri/{yil}    # binde 9,48, asgari ücret istisnası, KDV oranları
  birimKatalogu/{katalogId}   # (opsiyonel) ortak birim şablonları

universiteler/{uniId}/        # KURUM (tenant)
  profil/{docId}              # kurum adı, logo, tema, VKN, muhasebe ayarları
  birimler/{birimId}          # ad, kisaAd, aliases[], tur, iban, vkn
                              #   + vergiProfili { kdvMuaf, kdv1BizHazirlariz,
                              #     muhtasarBizHazirlariz, damgaBizHazirlariz,
                              #     kdv2BizHazirlariz, notMetni }
  kullanicilar/{uid}          # kurum kullanıcıları / yetkiler
  sablonlar/{sablonId}        # kuruma özel şablon (yoksa platformdan devralır)
  vergiParametreleri/{yil}    # kurum override (yoksa platformdan devralır)
  beyannameler/{yil_ay}       # modül verisi
  faturalar/...               # modül verisi
  toplantilar/{id}            # Yürütme Kurulu
  ykKararlari/{id}            # Yürütme Kurulu
```

> Not: `birimler` koleksiyonu zaten `universiteler/{uniId}/birimler` altında okunuyor → [`BirimService`](lib/features/birim/services/birim_service.dart:10). Bu yapı korunup **zenginleştirilir** (aliases + vergiProfili eklenir, `varsayilanBirimler` sabiti kaldırılır).

---

## 4. Merkez Yönetim Konsolu (Süper Admin) Yetenekleri

1. **Kurum yönetimi:** kurum ekle / askıya al / lisans & kotayı ayarla.
2. **Global şablon & vergi parametresi yönetimi:** merkezde tanımla, istenirse kurumlara "push" et.
3. **Birim katalogu:** her kurum için birim + IBAN/VKN + **vergi profili** (KDV muaf mı, hangi beyannameyi biz hazırlarız, not metni) CRUD.
4. **Rol & yetki:** platform admin (merkez) / kurum admin / döner sermaye yöneticisi / birim sorumlusu / editör / üye. Birim sorumlusu yalnız kendi biriminin beyanname alanlarını doldurabilir (bkz. §4c).
5. **Markalama:** kurum logo, tema rengi, başlık (çok-kurum görünümü).
6. **Denetim/audit:** hangi merkez değişikliği hangi kurumu etkiledi.

---

## 4b. Esneklik İlkesi: Ekstra Kurum/Birim Ekleme (beyanname dahil)

Kullanıcının açık isteği: **"esnek olmalı; beyannamede isterse ekstra kurum ekleyebilmeli."** Bu, merkezî yapıya ters değildir; aksine esnekliğin ta kendisidir. İki seviyede esneklik sağlanır:

- **Kurum (tenant) seviyesinde:** Merkez konsolundan yeni bir kurum (`universiteler/{uniId}`) açılabilir; süper admin isterse bu yetkiyi kurum adminine de tanımlayabilir. Böylece platform, satılan her yeni kurumu kod değişmeden ağırlar.
- **Beyanname birimi seviyesinde (asıl istek):** Beyanname ekranından (veya merkez konsolundan) **yeni bir beyanname birimi/kurumu** eklenebilir. Eklenen birim için kullanıcı şunları manuel tanımlar:
  - ad + kısa ad + alias'lar,
  - **vergi profili** (KDV muaf mı? KDV1 / Muhtasar / Damga / KDV2'yi biz mi hazırlarız? not metni),
  - varsa IBAN / VKN.
- **Otomatik yayılım:** Eklenen birim masalarda (KDV1 / Muhtasar / Damga) ve Özet Tablo 1'de **otomatik görünür**; hesaplama motoru onu otomatik kapsar. **Kod değişmez.**
- **Merkez + yerel (miras + override):** Merkez "ortak birim katalogu" sunar; kurum isterse katalogdan seçer, isterse **kendi ekstra birimini** tanımlar. Merkez değeri devralınır, kurum değeri override eder.
- **Geri dönüşümlü:** Eklenen birim pasifleştirilebilir/silinebilir; mevcut beyanname verileri korunur.
- **Kullanıcı dostu:** Hiçbir ekstra birim için geliştirici müdahalesi gerekmez; tüm tanımlar UI'dan yapılır.

> Uygulama yolu: `BirimVergiProfili` esneklik katmanı, statik haritadan **UI'dan düzenlenebilir veri**ye (Firestore) taşınır. Böylece "tam dinamik, otomatik ama her aşamada manuel düzeltmeye açık" ilke (AGENTS.md) korunur. (bkz. Faz 1 & 2)

---

## 4c. Ortak Yönetim Modülü ve Yetkilendirme: Döner Sermaye → Bağlı Birimler

Kullanıcının açık isteği: **"döner sermayeye bağlı birimlere yetki verilerek beyannameleri doldurulabilmeli. örnek olarak ortak bir yönetim modülü olmalı."** Bu bölüm, merkezî mimarinin **hiyerarşi + yetki** ayağını tanımlar.

### 4c.1 Hiyerarşi (ağaç)

```
Platform / Merkez (Süper Admin)
└── Kurum (Tenant)         örn. Uşak Üniversitesi        → universiteler/{uniId}
    └── Döner Sermaye       örn. DSİM (merkez birim/kasa) → birimler/{dsimId}
        ├── Bağlı Birim A   örn. TÖMER                     → birimler/{tomerId}
        ├── Bağlı Birim B   örn. DİŞ                       → birimler/{disId}
        └── Bağlı Birim C   örn. UBATAM / USEM / TADAUM …  → birimler/{…Id}
```

- **Döner sermaye = merkez kasa/yönetici katmanı.** Bağlı birimlerin beyannamelerini **görür, düzenler, onaylar ve birleştirir**.
- **Bağlı birim = icra katmanı.** Kendi beyannamesini **doldurur**, fakat yalnız kendi `birimId`'si kapsamında; diğer birimleri göremez/değiştiremez.

### 4c.2 Yetki Modeli (izin kodları)

| İzin kodu | Ne yapar | Tipik rol |
| :--- | :--- | :--- |
| `beyanname.goruntule` | Beyannameyi ve tabloları okur | üye / denetçi |
| `beyanname.doldur` | Beyanname alanlarını (ad, KDV1/Muhtasar/Damga/KDV2, not) **girer/düzeltir** — yalnız kendi birimi | birim sorumlusu |
| `beyanname.onayla` | Doldurulan beyannameyi onaylar / kilitle | döner sermaye yöneticisi |
| `beyanname.birlestir` | Tüm birim beyannamelerini tek beyannameye toplar (icmal) | döner sermaye yöneticisi |
| `beyanname.tanımla` | Yeni birim + vergi profili tanımlar (ekstra birim esnekliği) | kurum / döner sermaye admini |
| `birim.yonet` | Birim CRUD (IBAN/VKN/profil) | kurum / döner sermaye admini |

> `beyanname.doldur` izni **verilerek** birim yetkilendirilir. İzin yoksa birim beyannamesi **salt-okunur** görünür (kullanıcı yine de görür, ama düzenleyemez).

### 4c.3 Ortak Yönetim Modülü (tek iskelet, role göre daralan kapsam)

Fatura, beyanname, danışmanlık ve YK kararı **tek bir "Ortak Yönetim Modülü" iskeletini** paylaşır; ekranlar modül + yetkiye göre aynı bileşenleri kullanır:

- **Ortak bileşenler:** birim seçici, dönem (ay/yıl) seçici, tablo/icmal görünümü, kaydet/onayla aksiyonları, audit izi.
- **Kapsam daralması (scope):** Modül, kullanıcının `universiteId` + `birimId` + izin kümesine göre veriyi ve yetenekleri otomatik süzer. **Aynı ekran**, döner sermaye yöneticisinde **tüm birimler**, birim sorumlusunda **tek birim** gösterir.
- **Tek kaynak, çok görünüm:** Kod tekrarı yok; yeni modül eklemek, ortak iskelete yeni bir "modül tanımı" eklemekten ibarettir.

### 4c.4 Veri İzolasyonu

- Beyanname kaydı `birimId` (ve `universiteId`) ile damgalanır → [`BeyannameProvider`](lib/features/beyanname/providers/beyanname_provider.dart:12) kök koleksiyon yerine `FirestoreService(tenant).collection('beyannameler')` kullanır.
- Firestore güvenlik kuralı: birim sorumlusu **yalnız** `birimId == kendi birimi` olan dokümanı yazar; döner sermaye yöneticisi kendi ağacındaki tüm birimleri okur/yazar.
- Böylece "veri saklama ilkeleri" (AGENTS.md) gereği birim beyannamesi başka birimin verisine karışmaz.

### 4c.5 Akış (doldur → gözden geçir → onayla)

1. Döner sermaye, bağlı birime **`beyanname.doldur` yetkisi verir** (Merkez Konsolu → Yetki Matrisi).
2. Birim sorumlusu **kendi** beyannamesini ortak modülden doldurur (manuel düzeltme her zaman açık; AI önerisi varsa onaydan sonra kalıcılaşır).
3. Döner sermaye yöneticisi tüm bağlı birimleri **tek ekranda** görür, düzeltir ve **onaylar/kilitler** (`beyanname.onayla`).
4. Onaylı birim beyannameleri **icmal/özet** tabloda birleştirilir (`beyanname.birlestir`) — mevcut "Birim Vergi İcmal" mantığı bunun ilk hali.
5. Her adım denetim izine yazılır (kim, hangi birim, ne zaman).

> Esneklik korunur: yetkilendirilmiş birim isterse **kendi eşik/alanlarını** manuel düzeltir; merkez yalnız varsayılanı ve onay kapısını yönetir. Hiçbir yetki sert kodlanmaz; tamamı Merkez Konsolu'ndan verilir/kaldırılır.

### 4c.6 Firestore Temsili (öneri)

```
universiteler/{uniId}/
  birimler/{birimId}
      ad, kisaAd, tur, iban, vkn,
      ustBirimId: "{dsimId}"        // hiyerarşi bağı (döner sermaye → bağlı birim)
      vergiProfili: { kdvMuaf, kdv1, muhtasar, damga, kdv2, notMetni }
  kullanicilar/{uid}
      rol: "birimSorumlusu" | "donerSermayeYoneticisi" | "kurumAdmin"
      birimId, yetkiler: ["beyanname.doldur", "beyanname.goruntule"]
  beyannameler/{donemId}
      birimId, donem: "2025-09", veriler {...}, durum: "taslak|onaylandi"
```

---

## 5. De-Hardcode Eşleme Tablosu (dosya → config)

| Sabit (şimdi kodda) | Taşınacağı yer | Kod tarafında yapılacak |
| :--- | :--- | :--- |
| `BirimModel.varsayilanBirimler` | `universiteler/{uniId}/birimler` | Sabit liste kaldırılır; `BirimService` DB'yi kaynak alır |
| `BirimAdlandirma.*` | `birimler[].aliases[]` + `kisaAd` | Alias tabanlı `canonicalKey` (DB'den); sabit `if/switch` kaldırılır |
| `BirimVergiProfilleri._profiller` | `birimler[].vergiProfili` | Static harita → `BirimVergiProfiliService` (cache'li repository) |
| Excel birim sırası | `profil/{doc}.birimSiralama[]` | Ekran config'ten sıralar |
| Sabit DİŞ satırları | `birimler[].ekTabloSatirlari[]` | Ekran config'ten üretir |
| Fatura birim kuralları | `birimler[].faturaKurallari` | Metin arama yerine config |
| Danışmanlık şablon türleri | `sablonlar/{tur}` | Sabit türler → config |
| Vergi yılı sabitleri | `vergiParametreleri/{yil}` | Kod sabiti → config (yıl bazlı) |

---

## 6. Fazlı Yol Haritası

- **Faz 0 — Tenant İzolasyonunu Tamamla (ön koşul):**
  Beyanname ve diğer modülleri `FirestoreService(tenant)` üzerinden çalıştır; `usersCollection`'ı kurum altına taşı; Firestore güvenlik kurallarını kurum bazlı yaz. Mevcut Uşak verisini `universiteler/usak` altına migrate et.
- **Faz 1 — Config Repository Katmanı:**
  Birim + alias + vergi profili verisini DB'den okuyan servisler; static haritalar kaldırılır; uygulama açılışında cache. **Kullanıcı UI'dan yeni birim + vergi profili ekleyip düzenleyebilir (ekstra birim esnekliği).**
- **Faz 2 — Merkez Yönetim Konsolu:**
  Süper admin UI: kurum/birim/profil/şablon/vergi parametresi CRUD + kurumlara dağıtım. **Kurumlara "ekstra birim/beyanname kurumu tanımlama" izni merkezden ayarlanır.** Ayrıca **Yetki Matrisi**: döner sermayeye bağlı birimlere `beyanname.doldur` izni verilir/kaldırılır (bkz. §4c).
- **Faz 2b — Ortak Yönetim Modülü İskeleti:**
  Fatura/beyanname/danışmanlık/YK için paylaşılan birim+ dönem seçici, tablo/icmal, kaydet/onayla ve audit bileşenleri; ekranlar yetkiye göre daralan **tek iskelet** üzerinden çalışır. Doldur → gözden geçir → onayla akışı ve `birimId` bazlı veri izolasyonu burada tamamlanır.
- **Faz 3 — Modül Sabitlerini Taşı:**
  Excel görünüm kuralları, sabit DİŞ satırları, fatura/danışmanlık kuralları config'e.
- **Faz 4 — Markalama, Lisans, Ölçek:**
  Kurum teması/logo, lisans kontrolü, merkez→kurum şablon push.
- **Faz 5 — Migrasyon & Çok-Kurum Testi:**
  İkinci bir kurumla uçtan uca smoke test; veri migrasyonu doğrulaması.

---

## 7. Karar Noktaları / Riskler

- **Override önceliği:** Kurum değeri mi, merkez değeri mi kazanır? (Öneri: kurum override > merkez default.)
- **Güvenlik kuralları:** Her kurumun kullanıcısı yalnızca kendi `universiteler/{uniId}` alt ağacını okur/yazar.
- **Veri migrasyonu:** Kökteki mevcut `beyannameler` / `users` verisinin `universiteler/usak` altına taşınması (geri dönüşü olmayan adım → önce yedek).
- **Geriye dönük uyum:** Uşak kurulumu bozulmadan migrasyon.
- **Admin yetkisi:** `platformAdmin` (merkez) ile `kurumAdmin` ayrımı `user_model.dart`'e rol alanı eklenmesini gerektirir.

---

## 8. Neden Bu Model?

- **Ticarileştirilebilir:** Yeni kurum = yeni `universiteler/{uniId}` dokümanı; kod değişmez.
- **Merkezî kontrol (kullanıcının istediği):** Tüm kurallar, şablonlar ve vergi parametreleri tek merkezden yönetilir.
- **Dinamik + manuel:** Config tabanlı olduğu için her aşamada elle düzeltilebilir (AGENTS.md ilkesiyle uyumlu).
- **Esnek (kullanıcının istediği):** Kurum isterse beyannamede **ekstra birim/kurum** tanımlayabilir; tanımlar UI'dan yapılır, kod değişmez.
- **Yetkilendirilebilir (kullanıcının istediği):** Döner sermaye, bağlı birimlere **yetki vererek** kendi beyannamelerini doldurtur; ortak yönetim modülü tüm modülleri tek iskelette toplar (§4c).
- **Mevcut yatırımı korur:** Tenant altyapısı zaten var; iş, onu tutarlı uygulamak ve sabitleri config'e taşımak.
