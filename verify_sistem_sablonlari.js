/**
 * Sistem Ayarları şablonlarının Firestore'da görünürlüğünü ve
 * uygulama seçim mantığıyla uyumunu doğrular.
 *
 * node verify_sistem_sablonlari.js
 */

const { initializeFirebaseAdmin } = require('./scripts/firebase_admin_init');
const admin = initializeFirebaseAdmin();

const db = admin.firestore();
const bucket = admin.storage().bucket();

function oncelikShell(s) {
  const ortak = !s.birimId && !s.birimAd;
  if (ortak) return 0;
  return 3;
}

function oncelikBirimEslestirme(s, birimId, birimAd) {
  if (s.birimId === birimId) return 0;
  if (birimAd && s.birimAd === birimAd) return 1;
  if (!s.birimId && !s.birimAd) return 2;
  return 3;
}

function isWord(s) {
  return s.dosyaUzantisi === '.docx' || s.dosyaUzantisi === '.doc';
}

function secShell(sablonlar, tur) {
  const aday = sablonlar
    .filter((s) => s.tur === tur && isWord(s))
    .sort((a, b) => {
      const p = oncelikShell(a) - oncelikShell(b);
      if (p !== 0) return p;
      return b.eklenmeTarihi - a.eklenmeTarihi;
    });
  return aday[0] || null;
}

function secBirim(sablonlar, tur, birimId, birimAd) {
  const aday = sablonlar
    .filter((s) => s.tur === tur && isWord(s))
    .sort((a, b) => {
      const p = oncelikBirimEslestirme(a, birimId, birimAd) - oncelikBirimEslestirme(b, birimId, birimAd);
      if (p !== 0) return p;
      return b.eklenmeTarihi - a.eklenmeTarihi;
    });
  return aday[0] || null;
}

async function storageErisilebilir(url) {
  if (!url || !url.startsWith('http')) return { ok: false, sebep: 'URL yok veya geçersiz' };
  try {
    const res = await fetch(url, { method: 'HEAD' });
    if (res.ok) return { ok: true, boyut: res.headers.get('content-length') };
    return { ok: false, sebep: `HTTP ${res.status}` };
  } catch (e) {
    return { ok: false, sebep: e.message };
  }
}

async function main() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('  SİSTEM ŞABLONLARI DOĞRULAMA (Firestore + Storage)');
  console.log('═══════════════════════════════════════════════════════\n');

  const snap = await db.collection('sistemSablonlari').get();
  if (snap.empty) {
    console.log('✗ sistemSablonlari koleksiyonu BOŞ — uygulama asset şablonuna düşer.');
    process.exit(1);
  }

  const sablonlar = snap.docs.map((d) => {
    const data = d.data();
    const ts = data.eklenmeTarihi;
    return {
      id: d.id,
      sablonAdi: data.sablonAdi || '',
      tur: data.tur || '',
      dosyaUzantisi: data.dosyaUzantisi || '',
      dosyaUrl: data.dosyaUrl || '',
      birimId: data.birimId || null,
      birimAd: data.birimAd || null,
      eklenmeTarihi: ts && ts.toDate ? ts.toDate().getTime() : 0,
    };
  });

  console.log(`Toplam kayıt: ${sablonlar.length}\n`);

  const ykKarar = sablonlar.filter((s) => s.tur === 'yk_karar');
  const gundem = sablonlar.filter((s) => s.tur === 'gundem');

  console.log('── Tüm YK Karar şablonları ──');
  for (const s of ykKarar.sort((a, b) => b.eklenmeTarihi - a.eklenmeTarihi)) {
    const ortak = !s.birimId && !s.birimAd ? 'ORTAK ✓' : `birim: ${s.birimAd || s.birimId}`;
    console.log(`  • ${s.sablonAdi} | ${s.dosyaUzantisi} | ${ortak}`);
  }

  console.log('\n── Tüm Gündem şablonları ──');
  for (const s of gundem.sort((a, b) => b.eklenmeTarihi - a.eklenmeTarihi)) {
    const ortak = !s.birimId && !s.birimAd ? 'ORTAK ✓' : `birim: ${s.birimAd || s.birimId}`;
    console.log(`  • ${s.sablonAdi} | ${s.dosyaUzantisi} | ${ortak}`);
  }

  console.log('\n── Uygulama seçim simülasyonu (BelgeUretimServisi) ──');
  const shellKarar = secShell(sablonlar, 'yk_karar');
  const shellGundem = secShell(sablonlar, 'gundem');

  if (shellKarar) {
    console.log(`  Ana YK Word çerçevesi → "${shellKarar.sablonAdi}" (${shellKarar.dosyaUzantisi})`);
  } else {
    console.log('  ✗ Ana YK Word çerçevesi → BULUNAMADI (assets fallback)');
  }

  if (shellGundem) {
    console.log(`  Ana Gündem Word çerçevesi → "${shellGundem.sablonAdi}" (${shellGundem.dosyaUzantisi})`);
  } else {
    console.log('  ✗ Ana Gündem Word çerçevesi → BULUNAMADI (assets fallback)');
  }

  console.log('\n── Birim PDF eşleştirme (yk_yeni_karar_ekle _findPreferredSablon) ──');
  const birimSnap = await db.collection('birimler').get();
  const birimler = birimSnap.docs.map((d) => ({ id: d.id, ad: d.data().kisaAd || d.data().ad || d.id }));

  for (const b of birimler) {
    const k = secBirim(sablonlar, 'yk_karar', b.id, b.ad);
    const g = secBirim(sablonlar, 'gundem', b.id, b.ad);
    const kStr = k ? `"${k.sablonAdi}"` : 'YOK ✗';
    const gStr = g ? `"${g.sablonAdi}"` : 'YOK ✗';
    console.log(`  ${b.ad}: karar=${kStr} | gündem=${gStr}`);
  }

  console.log('\n── Storage erişim testi (HEAD) ──');
  const testList = [shellKarar, shellGundem].filter(Boolean);
  for (const s of testList) {
    const erisim = await storageErisilebilir(s.dosyaUrl);
    if (erisim.ok) {
      console.log(`  ✓ ${s.sablonAdi} indirilebilir (${Math.round((erisim.boyut || 0) / 1024)} KB)`);
    } else {
      console.log(`  ✗ ${s.sablonAdi} — ${erisim.sebep}`);
    }
  }

  const hatalar = [];
  if (!shellKarar || !isWord(shellKarar)) {
    hatalar.push('Ortak YK Karar .docx şablonu seçilemedi');
  } else if (shellKarar.birimId || shellKarar.birimAd) {
    hatalar.push('YK Karar shell şablonu ortak değil — birim arşivi seçilmiş olabilir');
  }

  if (!shellGundem || !isWord(shellGundem)) {
    hatalar.push('Ortak Gündem .docx şablonu seçilemedi');
  } else if (shellGundem.birimId || shellGundem.birimAd) {
    hatalar.push('Gündem shell şablonu ortak değil');
  }

  console.log('\n── SONUÇ ──');
  if (hatalar.length === 0) {
    console.log('  ✓ Sistem şablonlarını görüyor ve Word çıktısı için kullanabilir.');
  } else {
    hatalar.forEach((h) => console.log(`  ✗ ${h}`));
  }
  console.log('═══════════════════════════════════════════════════════\n');

  process.exit(hatalar.length > 0 ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
