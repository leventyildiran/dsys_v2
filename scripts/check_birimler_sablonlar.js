const { initializeFirebaseAdmin } = require('./firebase_admin_init');
const admin = initializeFirebaseAdmin();
const db = admin.firestore();

async function main() {
  console.log('1. Güncelleme başlıyor...');
  await db.collection('birimler').doc('N4UzFEc1vmsTpka8XEeY').set({
    ad: 'Diş Hekimliği',
    kisaAd: 'Diş Hekimliği',
    aktif: true,
  }, { merge: true });
  console.log('✓ birimler/N4UzFEc1vmsTpka8XEeY -> ad: Diş Hekimliği, kisaAd: Diş Hekimliği yapıldı.');

  const sablonSnap = await db.collection('sistemSablonlari').get();
  for (const doc of sablonSnap.docs) {
    const data = doc.data();
    if (data.birimAd === 'ADUM') {
      if (data.tur === 'gundem') {
        await doc.ref.update({
          birimAd: 'Diş Hekimliği',
          sablonAdi: 'Gündem Arşivi - Diş Hekimliği',
          birimId: 'N4UzFEc1vmsTpka8XEeY',
        });
        console.log(`✓ ADUM Gündem şablonu 'Diş Hekimliği'ne dönüştürüldü: ${doc.id}`);
      } else {
        await doc.ref.delete();
        console.log(`✓ Fazlalık ADUM Karar şablonu silindi: ${doc.id}`);
      }
    }
  }
  console.log('İşlem başarıyla tamamlandı!');
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
