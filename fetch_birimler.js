const { initializeFirebaseAdmin } = require("./scripts/firebase_admin_init");
const admin = initializeFirebaseAdmin();

const db = admin.firestore();

async function run() {
  const snapshot = await db.collection('birimler').get();
  snapshot.forEach(doc => {
    console.log(doc.id, '=>', doc.data().kisaAd, '|', doc.data().hesapAdi, '|', doc.data().iban);
  });
  process.exit(0);
}

run().catch(console.error);
