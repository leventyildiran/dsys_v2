const admin = require("firebase-admin");
const serviceAccount = require("./dsys-44b8e-firebase-adminsdk-fbsvc-6c70b81940.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function run() {
  const docRef = db.collection('ayarlar').doc('sistem_genel');
  const doc = await docRef.get();
  
  if (doc.exists) {
    let data = doc.data();
    let uyeler = data.kurulUyeleri || [];
    
    // Add Levent YILDIRAN if not exists
    const exists = uyeler.some(u => u.adSoyad === 'Levent YILDIRAN');
    if (!exists) {
      uyeler.push({
        gorev: "Raportör",
        adSoyad: "Levent YILDIRAN"
      });
      
      await docRef.update({
        kurulUyeleri: uyeler
      });
      console.log("Updated existing sistem_genel. Added Levent YILDIRAN.");
    } else {
      console.log("Levent YILDIRAN already exists.");
    }
  }
  process.exit(0);
}

run().catch(console.error);
