const admin = require("firebase-admin");
const serviceAccount = require("./dsys-44b8e-firebase-adminsdk-fbsvc-6c70b81940.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function run() {
  const snapshot = await db.collection('birimler').get();
  snapshot.forEach(doc => {
    console.log(doc.id, '=>', doc.data().kisaAd, '|', doc.data().hesapAdi, '|', doc.data().iban);
  });
  process.exit(0);
}

run().catch(console.error);
