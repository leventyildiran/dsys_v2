const { initializeFirebaseAdmin } = require('./firebase_admin_init');
const admin = initializeFirebaseAdmin();
const db = admin.firestore();

const CANONICAL_UNITS = {
  dosim: {
    ad: 'Döner Sermaye İşletme Müdürlüğü (DÖSİM)',
    kisaAd: 'DÖSİM',
    tur: 'merkez',
    hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /DÖSİM',
    iban: 'TR850001001758517844115013',
    vkn: '8960453664',
    aktif: true
  },
  dis: {
    ad: 'Ağız ve Diş Sağlığı Uygulama ve Araştırma Merkezi (Diş Hekimliği)',
    kisaAd: 'Diş Hekimliği',
    tur: 'merkez',
    hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Ağız ve Diş Sağlığı DSİ',
    iban: 'TR880001001758890982805002',
    vkn: '8960475707',
    aktif: true
  },
  ubatam: {
    ad: 'Bilimsel Analiz ve Teknolojik Uygulama ve Araştırma Merkezi (UBATAM)',
    kisaAd: 'UBATAM',
    tur: 'merkez',
    hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Bilimsel Analiz ve Teknolojik DSİ',
    iban: 'TR290001001758672359025003',
    vkn: '8960466311',
    aktif: true
  },
  usem: {
    ad: 'Sürekli Eğitim Uygulama ve Araştırma Merkezi (USEM)',
    kisaAd: 'USEM',
    tur: 'merkez',
    hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Sürekli Eğitim DSİ',
    iban: 'TR500001001758672355695003',
    vkn: '8960466257',
    aktif: true
  },
  dts: {
    ad: 'Deri, Tekstil ve Seramik Tasarım Uygulama ve Araştırma Merkezi (DTS)',
    kisaAd: 'DTS',
    tur: 'merkez',
    hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Deri, Tekstil ve Seramik DSİ',
    iban: 'TR090001001758975714095007',
    vkn: '2931062663',
    aktif: true
  },
  tomer: {
    ad: 'Türkçe Öğretimi Uygulama ve Araştırma Merkezi (TÖMER)',
    kisaAd: 'TÖMER',
    tur: 'merkez',
    hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Türkçe Öğrenimi DSİ',
    iban: 'TR040001001758672359525003',
    vkn: '8960466329',
    aktif: true
  },
  tadaum: {
    ad: 'Tarımsal ve Doğa Araştırmaları Uygulama ve Araştırma Merkezi (TADAUM)',
    kisaAd: 'TADAUM',
    tur: 'merkez',
    hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Tarımsal ve Doğa Araştırmaları DSİ',
    iban: 'TR190001001758982110835002',
    vkn: '8240526649',
    aktif: true
  },
  uzem: {
    ad: 'Uzaktan Eğitim Uygulama ve Araştırma Merkezi (UZEM)',
    kisaAd: 'UZEM',
    tur: 'merkez',
    hesapAdi: 'Kurum Tek İdare Tahsilat Alt Hesabı /Uzaktan Eğitim DSİ',
    iban: 'TR500001001758672355695003',
    vkn: '8960466257',
    aktif: true
  }
};

function getCanonicalKey(name) {
  if (!name) return '';
  const s = name.toLowerCase();
  if (s.includes('dösim') || s.includes('dsim') || s.includes('döner sermaye')) return 'dosim';
  if (s.includes('diş') || s.includes('dis') || s.includes('adum') || s.includes('ağız')) return 'dis';
  if (s.includes('ubatam') || s.includes('bilimsel')) return 'ubatam';
  if (s.includes('usem') || s.includes('sürekli')) return 'usem';
  if (s.includes('dts') || s.includes('deri') || s.includes('tekstil')) return 'dts';
  if (s.includes('tömer') || s.includes('tomer') || s.includes('türkçe')) return 'tomer';
  if (s.includes('tadaum') || s.includes('tarım') || s.includes('tarim')) return 'tadaum';
  if (s.includes('uzem') || s.includes('uzaktan')) return 'uzem';
  return s;
}

async function fix() {
  console.log('=== FIRESTORE BIRIMLER CANONICAL DEDUPLICATION ===');
  const snapshot = await db.collection('birimler').get();
  const seenKeys = new Map();

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const key = getCanonicalKey(data.ad || data.kisaAd);
    
    if (!CANONICAL_UNITS[key]) {
      console.log('Bilinmeyen birim korundu:', doc.id, '->', data.ad);
      continue;
    }

    const canonical = CANONICAL_UNITS[key];

    if (seenKeys.has(key)) {
      console.log('[DUPLICATE SILINIYOR]:', doc.id, '(' + (data.kisaAd || data.ad) + ') -> Ana doc:', seenKeys.get(key));
      await db.collection('birimler').doc(doc.id).delete();
    } else {
      seenKeys.set(key, doc.id);
      console.log('[GUNCELLENIYOR]:', doc.id, '(' + data.kisaAd + ') ->', canonical.kisaAd + ':', canonical.ad);
      await db.collection('birimler').doc(doc.id).set({
        ...data,
        ad: canonical.ad,
        kisaAd: canonical.kisaAd,
        tur: canonical.tur,
        hesapAdi: canonical.hesapAdi,
        iban: canonical.iban,
        vkn: canonical.vkn,
        aktif: true
      }, { merge: true });
    }
  }

  for (const [key, canonical] of Object.entries(CANONICAL_UNITS)) {
    if (!seenKeys.has(key)) {
      console.log('[EKSIK BIRIM EKLENIYOR] ->', canonical.kisaAd);
      await db.collection('birimler').add({
        ...canonical,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
  }

  console.log('=== DEDUPLICATION VE STANDARTLASTIRMA BASARIYLA TAMAMLANDI ===');
}

fix().then(() => process.exit(0)).catch(e => { console.error(e); process.exit(1); });
