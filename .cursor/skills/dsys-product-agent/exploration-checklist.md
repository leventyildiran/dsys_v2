# DSYS Keşif Kontrol Listesi

Ürün ajanı her turda bu listeyi sırayla işler. Her madde için: ✅ / ⚠️ / ❌ ve kısa not.

**Ortam:** dsys_v2 — https://dsys-44b8e.web.app veya `flutter run -d chrome`  
**Güvenli mod:** Silme, gerçek onay, deploy yok.

---

## Giriş

- [ ] `/login` — e-posta/şifre ile giriş
- [ ] Yan menüde 4 modül görünüyor mu (Fatura, YK, Danışmanlık, Ayarlar)

---

## F1 — Fatura tam akış

- [ ] Ana sayfa `/` — matbu banner ve yükleme alanı
- [ ] PDF seç → parser alanları doldu mu
- [ ] Birim dropdown → IBAN / hesap adı güncellendi mi
- [ ] Eksik alan uyarıları anlaşılır mı
- [ ] Kalibrasyon dialogu — sürükleme akıcı mı
- [ ] PDF önizleme açılıyor mu
- [ ] Matbu yazdır (test ortamında iptal edilebilir)
- [ ] **Fatura Arşivi** butonu → arama dialogu (banner yok)
- [ ] Sayfadan çık → geri gel → kuyruk durumu (beklenen: session’a bağlı)

**Sürtünme notları:**

---

## F2 — Fatura arşiv

- [ ] Arşivde metin + yıl + tarih filtresi
- [ ] Sonuç satırına tıklama / detay

---

## Y1 — YK çalışma alanı

- [ ] `/yk-karar` — aktif toplantı görünüyor mu (yeniden girişte hatırlanıyor mu)
- [ ] Yeni toplantı oluştur (test no)
- [ ] Birim sekmesi seç
- [ ] PDF yükle → Analiz Et
- [ ] Karar sekmesi — metin + cetvel tablosu alt panel
- [ ] Gündem sekmesi — ayrı içerik
- [ ] Otomatik taslak kaydı mesajı
- [ ] Tarayıcıyı yenile / başka sayfaya git → geri gel — **karar geri yüklendi mi**
- [ ] Birim chip yeşil mi (kayıtlı)

**Sürtünme notları:**

---

## Y2 — YK arşiv ve önizleme

- [ ] Eski Kararlar → toplantı listesi (toplantı no)
- [ ] Toplantı detay → sol birim listesi
- [ ] Sağ panel: Metin & Tablo | PDF Önizleme
- [ ] Word / PDF indir (test)

---

## Y3 — YK toplu çıktı

- [ ] Gündemi Oluştur (en az 1 kayıtlı birim kararı gerekir)
- [ ] Ana Şablonu İndir — bütünlük uyarıları okunabilir mi

---

## D1 — Danışmanlık

- [ ] `/danismanlik` — liste yükleniyor
- [ ] Detay → taksit listesi
- [ ] Yeni taksit (taslak)
- [ ] Dağıtım hesapla — katsayı ve tablo mantığı ekranda anlaşılır mı
- [ ] (Opsiyonel) Onayla — sadece test verisi ile

---

## S1 — Sistem ayarları

- [ ] `/ayarlar` — IBAN, kurul üyeleri
- [ ] Şablon yönetimi — `yk_karar`, `gundem` genel şablon var mı
- [ ] Birim arşivi .docx kayıtları listeleniyor mu

---

## Entegrasyon kontrolleri

- [ ] Fatura birim listesi = Firestore birimler
- [ ] YK şablon eksikse analiz uyarısı
- [ ] Danışmanlık → YK karar metni köprüsü çalışıyor mu

---

## Tur sonu

- [ ] `exploration-checklist.md` tamamlandı
- [ ] `SKILL.md` §5 rapor şablonu dolduruldu
- [ ] P0/P1 maddeler geliştirme backlog’una yazıldı
