/**
 * Uşak Üniversitesi Personel Rehberi (rehber.usak.edu.tr)
 * Kamuya açık Akademik ve İdari personel verilerini sayfa sayfa tarar,
 * parse eder ve assets/data/usak_personeller.json dosyasına kaydeder.
 *
 * Kullanım:
 *   node scripts/import_usak_rehber.js             # Verileri çekip JSON'a kaydeder
 *   node scripts/import_usak_rehber.js --upload    # JSON'a kaydeder ve Firestore /personel'e yükler
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

const UPLOAD = process.argv.includes('--upload');
const OUTPUT_FILE = path.join(__dirname, '..', 'assets', 'data', 'usak_personeller.json');

function decodeEntities(encodedString) {
  if (!encodedString) return '';
  return encodedString
    .replace(/&#([0-9]+);/g, (match, dec) => String.fromCharCode(dec))
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .trim();
}

function fetchPage(tip, page) {
  return new Promise((resolve, reject) => {
    const url = `https://rehber.usak.edu.tr/Home/SearchResults?tip=${encodeURIComponent(tip)}&page=${page}`;
    const req = https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    });
    req.on('error', reject);
    req.setTimeout(25000, () => {
      req.destroy();
      reject(new Error(`Timeout fetching page ${page} for ${tip}`));
    });
  });
}

function parsePersoneller(html, tip) {
  const personeller = [];
  const cardSplits = html.split('<div class="col-12 col-xl-6 px-2">');
  
  for (let i = 1; i < cardSplits.length; i++) {
    const cardHtml = cardSplits[i];
    
    // Unvan & Ad Soyad & ID
    const nameMatch = cardHtml.match(/<h5[^>]*>[\s\S]*?<span[^>]*class="[^"]*fw-normal[^"]*"[^>]*>([\s\S]*?)<\/span>[\s\S]*?<a[^>]*href="\/Home\/Detail\/([0-9]+)"[^>]*>([\s\S]*?)<\/a>/i);
    if (!nameMatch) continue;
    
    const unvan = decodeEntities(nameMatch[1]);
    const rehberId = nameMatch[2];
    let adSoyad = decodeEntities(nameMatch[3]);
    
    // Ad soyad çift boşluk temizliği
    adSoyad = adSoyad.replace(/\s+/g, ' ').trim();
    
    // E-posta
    const emailMatch = cardHtml.match(/<a[^>]*href="mailto:([^"]+)"/i);
    const eposta = emailMatch ? emailMatch[1].trim() : '';
    
    // Birimler
    const birimler = [];
    const birimRegex = /<div class="fw-bold text-navy text-wrap lh-sm"[^>]*>[\s\S]*?<i[^>]*><\/i>([\s\S]*?)<\/div>/gi;
    let bm;
    while ((bm = birimRegex.exec(cardHtml)) !== null) {
      const bAd = decodeEntities(bm[1]).trim();
      if (bAd && !birimler.includes(bAd)) birimler.push(bAd);
    }
    
    // Dahili telefon
    const telMatch = cardHtml.match(/Dahili:\s*<\/i>\s*(?:<a[^>]*>)?([0-9\s\-,]+)/i);
    const dahili = telMatch ? telMatch[1].trim() : '';
    
    // Unvan katsayısı tahmini
    let katsayi = 1.0;
    const uUpper = unvan.toUpperCase();
    if (uUpper.includes('PROF')) katsayi = 1.25;
    else if (uUpper.includes('DOÇ') || uUpper.includes('DOC')) katsayi = 1.15;
    else if (uUpper.includes('DOKTOR') || uUpper.includes('DR.')) katsayi = 1.10;
    else if (uUpper.includes('ÖĞRETİM GÖREVLİSİ') || uUpper.includes('OGRETIM')) katsayi = 1.05;
    else if (uUpper.includes('ARAŞTIRMA GÖREVLİSİ') || uUpper.includes('ARASTIRMA')) katsayi = 1.0;

    const anaBirim = birimler.length > 0 ? birimler[0] : '';

    personeller.push({
      id: `rehber_${rehberId}`,
      adSoyad,
      unvan,
      unvanKatsayisi: katsayi,
      birimId: '',
      birimAdi: anaBirim,
      tumBirimler: birimler.join(' / '),
      eposta,
      telefon: dahili,
      personelTuru: tip,
      kaynak: 'rehber',
      rehberId,
      aktif: true,
    });
  }

  return personeller;
}

async function scrapeTip(tip) {
  const allPersonel = [];
  let page = 1;
  let emptyStreak = 0;

  console.log(`\n▶ ${tip} Personel Rehberi taranıyor...`);

  while (true) {
    try {
      process.stdout.write(`  Sayfa ${page}... `);
      const html = await fetchPage(tip, page);
      const items = parsePersoneller(html, tip);

      if (items.length === 0) {
        console.log(`0 kayıt (Son sayfa)`);
        emptyStreak++;
        if (emptyStreak >= 2) break; // Üst üste 2 boş sayfa geldiyse dur
      } else {
        emptyStreak = 0;
        allPersonel.push(...items);
        console.log(`+${items.length} kişi (Toplam: ${allPersonel.length})`);
      }

      page++;
      // Sunucuya aşırı yük bindirmemek için 200ms bekleme
      await new Promise(r => setTimeout(r, 200));
    } catch (e) {
      console.log(`Hata: ${e.message}, tekrar deneniyor...`);
      await new Promise(r => setTimeout(r, 1000));
      emptyStreak++;
      if (emptyStreak >= 4) break;
    }
  }

  console.log(`✓ ${tip} Personel: ${allPersonel.length} kişi çekildi.`);
  return allPersonel;
}

async function uploadToFirestore(personeller) {
  console.log('\n▶ Firestore /personel koleksiyonuna aktarılıyor...');
  const admin = require('firebase-admin');
  const { initializeFirebaseAdmin } = require('./firebase_admin_init');

  initializeFirebaseAdmin();
  const db = admin.firestore();

  // 500'lük batch gruplarına böl
  const BATCH_SIZE = 450;
  let successCount = 0;

  for (let i = 0; i < personeller.length; i += BATCH_SIZE) {
    const chunk = personeller.slice(i, i + BATCH_SIZE);
    const batch = db.batch();

    for (const p of chunk) {
      const docRef = db.collection('personel').doc(p.id);
      batch.set(docRef, {
        id: p.id,
        adSoyad: p.adSoyad,
        unvan: p.unvan,
        unvanKatsayisi: p.unvanKatsayisi,
        birimId: p.birimId || '',
        birimAdi: p.birimAdi || '',
        tumBirimler: p.tumBirimler || '',
        eposta: p.eposta || '',
        telefon: p.telefon || '',
        personelTuru: p.personelTuru,
        kaynak: p.kaynak,
        rehberId: p.rehberId,
        aktif: p.aktif,
        guncellenmeTarihi: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }

    await batch.commit();
    successCount += chunk.length;
    console.log(`  ↑ Batch yüklendi: ${successCount} / ${personeller.length}`);
  }

  console.log(`✓ Firestore yükleme tamamlandı! Toplam: ${successCount} personel.`);
}

async function main() {
  console.log('=====================================================');
  console.log('UŞAK ÜNİVERSİTESİ PERSONEL REHBERİ AKTARIM MOTORU');
  console.log('=====================================================');

  const akademik = await scrapeTip('Akademik');
  const idari = await scrapeTip('İdari');

  const combined = [...akademik, ...idari];

  // ID'ye göre tekilleştir
  const uniqueMap = new Map();
  for (const p of combined) {
    uniqueMap.set(p.id, p);
  }
  const uniqueList = Array.from(uniqueMap.values());

  console.log(`\nToplam Benzersiz Personel: ${uniqueList.length}`);

  // JSON dosyasına yaz
  const jsonDir = path.dirname(OUTPUT_FILE);
  if (!fs.existsSync(jsonDir)) {
    fs.mkdirSync(jsonDir, { recursive: true });
  }
  fs.writeFileSync(OUTPUT_FILE, JSON.stringify(uniqueList, null, 2), 'utf-8');
  console.log(`✓ JSON dosyası oluşturuldu: ${OUTPUT_FILE}`);

  if (UPLOAD) {
    await uploadToFirestore(uniqueList);
  } else {
    console.log('\nFirestore\'a yüklemek için:');
    console.log('  node scripts/import_usak_rehber.js --upload');
  }

  console.log('\nTamamlandı.');
}

main().catch(err => {
  console.error('Kritik Hata:', err);
  process.exit(1);
});
