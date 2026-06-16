const admin = require("firebase-admin");
const serviceAccount = require("./dsys-44b8e-firebase-adminsdk-fbsvc-6c70b81940.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 2026 IBANs and Account Names extracted from Excel files
const updates = {
  "DTS": {
    iban: "TR090001001758975714095007",
    hesapAdi: "DERİ, TEKSTİL VE SERAMİK TASARIM DSİ (VKN: 2931062663)"
  },
  "UBATAM": {
    iban: "TR290001001758672359025003",
    hesapAdi: "Uşak Ü. Bilimsel Analiz ve Tek. Uyg. ve Arş. Mer. Müdürlüğü D.S.İ"
  },
  "USEM": {
    iban: "TR500001001758672355695003",
    hesapAdi: "Uşak Üniversitesi Sürekli Eğitim Araştırma ve Uygulama Merkezi Müdürlüğü"
  },
  "TADAUM": {
    iban: "TR190001001758982110835002",
    hesapAdi: "Uşak Ü. Tarımsal ve Doğa Araştl.Uygu.ve Araşt.Merk.Müdürlüğü D.S.İ."
  },
  "DSİM": { // Match DB kisaAd
    iban: "TR740001001758975714095001",
    hesapAdi: "Uşak Ü. Döner Sermaye İşletme Müdürlüğü"
  }
};

async function run() {
  const snapshot = await db.collection('birimler').get();
  
  for (const doc of snapshot.docs) {
    const kisaAd = doc.data().kisaAd;
    if (updates[kisaAd]) {
      console.log(`Updating ${kisaAd}...`);
      await db.collection('birimler').doc(doc.id).update({
        iban: updates[kisaAd].iban,
        hesapAdi: updates[kisaAd].hesapAdi
      });
      console.log(`Success: ${kisaAd}`);
    }
  }
  console.log("All updates complete.");
  process.exit(0);
}

run().catch(console.error);
