const { initializeFirebaseAdmin } = require("./scripts/firebase_admin_init");
const admin = initializeFirebaseAdmin();

const db = admin.firestore();

async function run() {
  const docRef = db.collection('ayarlar').doc('sistem_genel');
  const doc = await docRef.get();
  
  if (doc.exists) {
    let data = doc.data();
    let uyeler = data.kurulUyeleri || [];
    
    // Replace Kenan TAŞ with Selçuk SAMANLI
    for (let i = 0; i < uyeler.length; i++) {
      if (uyeler[i].adSoyad.includes('Kenan TAŞ')) {
        uyeler[i].adSoyad = "Prof. Dr. Selçuk SAMANLI";
        uyeler[i].gorev = "Başkan"; // Or Rektör Yardımcısı
      }
    }
    
    await docRef.update({
      kurulUyeleri: uyeler
    });
    console.log("Updated existing sistem_genel. Replaced Kenan TAŞ with Selçuk SAMANLI.");
  }
  process.exit(0);
}

run().catch(console.error);
