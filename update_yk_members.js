const admin = require("firebase-admin");
const serviceAccount = require("./dsys-44b8e-firebase-adminsdk-fbsvc-6c70b81940.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

const uyeler = [
  { gorev: "Başkan", adSoyad: "Prof. Dr. Kenan TAŞ" },
  { gorev: "Üye", adSoyad: "Prof. Dr. Mehmet Ali GÜNGÖR" },
  { gorev: "Üye", adSoyad: "Doç. Dr. Mustafa TAYTAK" },
  { gorev: "Üye", adSoyad: "Doç. Dr. Erkan HALAY" },
  { gorev: "Üye (İşletme Müdürü)", adSoyad: "Ercan BİLGEÇ" }
];

async function run() {
  const docRef = db.collection('ayarlar').doc('sistem_genel');
  const doc = await docRef.get();
  
  if (doc.exists) {
    await docRef.update({
      kurulUyeleri: uyeler
    });
    console.log("Updated existing sistem_genel");
  } else {
    await docRef.set({
      kurulUyeleri: uyeler
    });
    console.log("Created new sistem_genel");
  }
  
  process.exit(0);
}

run().catch(console.error);
