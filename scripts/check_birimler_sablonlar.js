const { initializeFirebaseAdmin } = require('./firebase_admin_init');
const admin = initializeFirebaseAdmin();
const db = admin.firestore();

async function main() {
  console.log('=== BİRİMLER (Firestore: birimler) ===');
  const birimlerSnap = await db.collection('birimler').get();
  const birimler = [];
  birimlerSnap.forEach((d) => {
    const data = d.data();
    birimler.push({ id: d.id, kisaAd: data.kisaAd, ad: data.ad, aktif: data.aktif });
  });
  console.table(birimler);

  console.log('\n=== ŞABLON ID EŞLEŞTİRME VE GÜNCELLEME ===');
  const sablonSnap = await db.collection('sistemSablonlari').get();
  for (const doc of sablonSnap.docs) {
    const data = doc.data();
    if (data.birimAd === 'TÖMER' && (!data.birimId || data.birimId === '-')) {
      await doc.ref.update({ birimId: 'DQpBzkSDoCG2Qn1Ucjai' });
      console.log(`✓ TÖMER şablonu birimId güncellendi: ${doc.id}`);
    }
    if (data.birimAd === 'ADUM' && (!data.birimId || data.birimId === '-')) {
      await doc.ref.update({ birimId: 'N4UzFEc1vmsTpka8XEeY' });
      console.log(`✓ ADUM şablonu birimId güncellendi (Diş Hek.): ${doc.id}`);
    }
  }

  console.log('\n=== GÜNCEL SİSTEM ŞABLONLARI ===');
  const updatedSablonSnap = await db.collection('sistemSablonlari').get();
  const sablonlar = [];
  updatedSablonSnap.forEach((d) => {
    const data = d.data();
    sablonlar.push({
      id: d.id,
      sablonAdi: data.sablonAdi,
      tur: data.tur,
      birimId: data.birimId || '-',
      birimAd: data.birimAd || '(Tüm Birimler)',
      bolumSayisi: data.bolumSayisi || 1,
    });
  });
  console.table(sablonlar);

  console.log('\n=== EŞLEŞME ÖZETİ ===');
  for (const b of birimler) {
    const matchSablon = sablonlar.filter(
      (s) => s.birimId === b.id || (s.birimAd && s.birimAd.toLowerCase() === (b.kisaAd || '').toLowerCase())
    );
    console.log(`Birim: [${b.kisaAd}] (${b.ad}) -> Eşleşen Şablon: ${matchSablon.length} adet`);
    matchSablon.forEach((s) => console.log(`   ↳ [${s.tur}] ${s.sablonAdi} (birimId: ${s.birimId})`));
  }

  process.exit(0);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
