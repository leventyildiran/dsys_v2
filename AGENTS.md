# Agent Instructions

## Ürün geliştirme ajanı

UX keşfi, otomasyon önerisi, modül mantığı ve teknoloji araştırması:
**`.cursor/skills/dsys-product-agent/SKILL.md`** (+ `exploration-checklist.md`)

Mühendislik, formül ve QA:
**`.cursor/skills/dsys-development/SKILL.md`**

---

Bu projede Yürütme Kurulu modülü üzerinde çalışan her ajan bu dosyadaki mantığı kaynak kabul etmelidir. Kullanıcının istediği sistem "tam dinamik, otomatik ama her aşamada manuel düzeltmeye açık" bir karar ve gündem hazırlama sistemidir. Kısa yoldan çalışan ama bu mantığı bozan değişiklikler yapılmamalıdır.

## Yürütme Kurulu Ana Mantığı

Kullanıcı yeni bir Yürütme Kurulu toplantısı oluşturduğunda sadece toplantı numarasını ve tarihini girer. Sistem bundan sonra birimleri, karar editörünü ve gündem editörünü aynı çalışma alanında açmalıdır.

Sağdaki editör Word mantığında çalışır ve iki ayrı belge modu vardır:

- Karar: Yürütme Kurulu ana karar metni.
- Gündem: Aynı toplantının gündem metni.

Bu iki mod ayrı içerik tutmalıdır. Karar tabında yazılan veya AI ile üretilen içerik gündem tabını ezmemeli; gündem tabında yapılan manuel düzeltme de karar metnini değiştirmemelidir.

## Otomatik ve Manuel Çalışma İlkesi

Sistem her işi otomatik önermeli, fakat kullanıcı her aşamada elle müdahale edebilmelidir.

- Birim seçildiğinde uygun karar ve gündem şablonları otomatik bulunmalıdır.
- Otomatik bulunan şablon kullanıcı tarafından değiştirilebilir olmalıdır.
- PDF yüklendiğinde AI karar taslağı üretmelidir.
- Kullanıcı AI taslağını editörde görebilmeli, düzeltebilmeli ve ancak onaylayınca ana karara eklemelidir.
- Gündem maddesi AI ile oluşturulmalı, editörde düzeltilebilir olmalı ve ayrı kaydedilmelidir.
- Manuel şablon seçimi, manuel metin düzenleme ve manuel kaydetme her zaman korunmalıdır.

## Şablon Mantığı (iki katman)

1. **Ana Word şablonu (Sistem Ayarları)** — Kullanıcının yüklediği ortak `yk_karar` ve `gundem` `.docx` dosyaları. Final Word çıktısının dış çerçevesi (üst bilgi, kenar boşlukları, imza alanı) bunlardan gelir. `BelgeUretimServisi._loadSablonBytes` önce Firestore `sistemSablonlari` içinde **birimId/birimAd boş (Tüm Birimler)** kayıtları kullanır.

2. **Birim Word arşivi (isteğe bağlı)** — `import_yk_sablonlar.js` ile üretilen `UBATAM_YK_Karar_Arsivi.docx` gibi dosyalar. PDF analizinde tablo birebir eşleştirme için kullanılır; ana şablonun yerine geçmez.

Sistem Ayarları'na Word yüklediyseniz `--upload` zorunlu değildir. Birim arşivi yalnızca tablo eşleştirme kalitesi için eklenir.

## AI Karar Üretim Mantığı

Analiz zinciri şu sırayla çalışmalıdır:

1. PDF metni yerel olarak okunur (internet gerekmez).
2. Birime ait geçmiş kararlar Firestore'dan çekilir.
3. AI anahtarı ve internet varsa: geçmiş karar + şablon + PDF birlikte AI'a verilir.
4. AI yoksa, internet yoksa veya AI hata verirse: `YkKararEslestirmeServisi` otomatik devreye girer.
5. Otomatik eşleştirme; geçmiş karar formatını, şablonu ve PDF tablosunu kullanarak taslak üretir.
6. Kullanıcı editörde her zaman manuel düzeltebilir.

AI sadece PDF metnini özetleyen bir araç değildir. AI, yeni gelen yönetim kurulu kararını geçmiş Yürütme Kurulu kararlarıyla eşleştirip aynı kurumsal dil ve biçime uyarlamalıdır.

Analiz sırasında AI'a şu bağlam verilmelidir:

- PDF'ten çıkarılan yeni yönetim kurulu kararı / üst yazı metni.
- Seçili birime ait geçmiş Yürütme Kurulu kararları.
- Seçili birime ait geçmiş gündem maddeleri veya toplantı gündemleri.
- Otomatik seçilen karar şablonu.
- Otomatik seçilen gündem şablonu.
- Toplantı no ve toplantı tarihi.
- Birim adı ve mümkünse birim kimliği.

AI çıktısı geçmiş kararların biçimini taklit etmelidir:

- Eski kararda tablo varsa yeni kararda da tablo yapısı korunmalıdır.
- Başlık, karar cümlesi, "oy birliği" dili, karar sırası ve resmi üslup geçmiş örneklere benzemelidir.
- PDF'teki tablo satırları ve sütunları kaydırılmamalı, atlanmamalı ve uydurulmamalıdır.
- AI emin olmadığı veriyi uydurmamalı; eksik alanı kullanıcıya görünür şekilde bırakmalıdır.

## Gündem Üretim Mantığı

Gündem, karar başlığının basit kopyası değildir. Sistem eski gündemleri ve eski karar-gündem ilişkisini inceleyerek yeni yönetim kurulu kararından uygun gündem maddesi üretmelidir.

Beklenen akış:

1. Kullanıcı birim kararını PDF olarak yükler.
2. AI karar taslağını üretir.
3. Kullanıcı kararı editörde inceler ve kaydeder.
4. Sistem aynı karar için gündem maddesi taslağı üretir veya kullanıcı "Gündem Oluştur" dediğinde üretir.
5. Kullanıcı gündem tabına geçip gündemi düzenleyebilir.
6. Gündem ayrı kaydedilir ve toplantı gündem belgesine eklenir.

## Veri Saklama İlkeleri

Karar metni, gündem metni ve tablo verisi birbirine karıştırılmamalıdır.

- Karar metni: Kullanıcının onayladığı YK karar içeriği.
- Gündem metni/maddesi: Toplantı gündemi için ayrı içerik.
- Tablo verileri: Mümkünse yapısal veri olarak saklanmalı, Word üretiminde gerçek tabloya dönüştürülmelidir.
- AI önizleme taslağı: Kullanıcı onaylamadan kalıcı karar sayılmamalıdır.
- Geçmiş kararlar: Yeni analizlerde örnek bağlam olarak kullanılabilmelidir.

Birime göre geçmiş öğrenme için kayıtlar mümkün olduğunca `birimId` ve `birimAd` ile saklanmalıdır. Sadece `birimAd` ile eşleşme yedek yöntem olmalıdır.

## Değişiklik Yaparken Dikkat Edilecekler

- Karar ve gündem tablarını tek controller veya tek kayıt alanına düşürmeyin.
- Gündem kaydet butonu karar kaydetme fonksiyonunu çağırmamalıdır.
- Şablon havuzu devre dışı bırakılmamalıdır.
- Kullanıcının manuel düzeltme hakkı kaldırılmamalıdır.
- AI çıktısı doğrudan geri dönüşsüz şekilde ana karara eklenmemelidir.
- Eski karar/gündem bağlamı olmadan "birebir eski format" hedefi tamamlanmış sayılmamalıdır.
- Word çıktısında tablo ve resmi biçim korunmalıdır.

## Öncelikli Sorun Listesi (güncel durum)

Tamamlanan:
- Otomatik şablon seçimi + manuel override (`_autoLoadTemplatesForBirim`, `_findPreferredSablon`)
- Karar/gündem ayrı Quill controller ve ayrı kayıt (`_saveKarar` / `_saveGundem`)
- PDF kalite kapısı, tablo kolon haritası, OOXML birebir Word çıktısı
- Tüm birim regression testi: `node test_tum_birimler.js`
- Birleştirme öncesi bütünlük kontrolü (`YkKararButunlukServisi`)
- Dış karar yüklemede birim seçimi zorunlu
- Karar analizi sonrası gündem taslağı otomatik önerisi
- Agent skill: `.cursor/skills/dsys-development/SKILL.md`

Devam eden / manuel adım:
- ADUM ve TÖMER Firestore `birimler` koleksiyonunda yok — şablonlar `birimAd` ile eşleşir
- DSİM/UZEM için kaynak Word arşivi `ornek/` klasöründe yok — birim arşivi üretilemez (ana şablon yeterli)
- Birim arşivi (tablo birebir eşleştirme): isteğe bağlı `node import_yk_sablonlar.js --upload` — ana şablonun yerine geçmez

## QA Komutları

```powershell
node import_yk_sablonlar.js
node test_tum_birimler.js
node verify_sablon_tablolari.js UBATAM
```

## Fatura Matbu & Visual Entry Kalibrasyon Kuralları (DOKUNULMAZLAR)

Gelecekteki ajanlar ve düzenlemeler için kesin kurallar:
1. **Nakli Yekün Görsel Hizalaması:** `visual_entry_screen.dart` dosyasındaki Nakli Yekün sanal satırı, *asla* BoxConstraints ile sıkıştırılamaz. Normal kalemler nasıl `width: maxWidth` ile oluşturuluyorsa, Nakli Yekün `Container`ı da `width: maxWidth` ile oluşturulmalıdır. Aksi halde hizalama merkezden değil soldan başlar ve "1" rakamı normal kalemlerle aynı hizaya gelmez.
2. **Sürükle-Bırak (Hit Testing) Sınırları:** A4 kağıdının dışına (siyah/gri arka plan boşluğuna) sürüklenen öğelerin tıklanabilmesi için, `Stack` ve parent `Container`ın genişlik ve yükseklikleri (`FaturaMatbuConfig.a4Genislik + 600` gibi) taşmaya izin verecek şekilde devasa olmalıdır. `_konum` fonksiyonuna eklenen `+ 300` ve `+ 200` offset değerleri silinmemelidir.
3. **Nakli Yekün Ara Toplam (Çift Sayım) Mantığı:** Nakli Yekün, sayfalar arası hesaplamada `pageRealTotal` olarak gerçek kalemlerin toplamı üzerinden kümülatif (`runningTotal`) yürütülmelidir. Kesinlikle `sayfaToplami` veya `oncekiSayfaToplam` diyerek `pages` dizisindeki öğeler toplanmamalıdır; aksi takdirde Nakli Yekün sahte kalemi listeye dahil edildiği için toplam fiyatlar çift sayılır (double-counting). Toplamlar doğrudan `pageTotals` (her sayfanın sonundaki gerçek toplam dizisi) üzerinden çekilmelidir.
