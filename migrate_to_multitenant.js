const fs = require('fs');
const path = require('path');
const { initializeFirebaseAdmin } = require('./scripts/firebase_admin_init');

const admin = initializeFirebaseAdmin();

const db = admin.firestore();

const args = process.argv.slice(2);
const isDryRun = args.includes('--dry-run');
const includeTemp = args.includes('--include-temp');
const uniIdArg = args.find((a) => a.startsWith('--uni='));
const uniId = uniIdArg ? uniIdArg.split('=')[1] : 'usak';

const tenantRoot = db.collection('universiteler').doc(uniId);
const backupDir = path.join(__dirname, 'backups');
const currentYear = new Date().getFullYear();

function nowStamp() {
  return new Date().toISOString().replace(/[:.]/g, '-');
}

async function ensureBackupDir() {
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }
}

async function backupCollection(sourcePath) {
  const snap = await db.collection(sourcePath).get();
  const docs = snap.docs.map((d) => ({ id: d.id, data: d.data() }));
  return docs;
}

async function backupFaturaArchive() {
  const result = {};
  for (let year = currentYear - 6; year <= currentYear; year += 1) {
    const snap = await db
      .collection('faturalar_gecici')
      .doc(String(year))
      .collection('kayitlar')
      .get();
    if (!snap.empty) {
      result[String(year)] = snap.docs.map((d) => ({ id: d.id, data: d.data() }));
    }
  }
  return result;
}

async function writeBackup(payload) {
  await ensureBackupDir();
  const fileName = `multitenant-backup-${nowStamp()}.json`;
  const fullPath = path.join(backupDir, fileName);
  fs.writeFileSync(fullPath, JSON.stringify(payload, null, 2), 'utf8');
  return fullPath;
}

async function copyCollectionToTenant({ source, target }) {
  const snap = await db.collection(source).get();
  if (snap.empty) {
    return { source, target, count: 0 };
  }

  if (isDryRun) {
    return { source, target, count: snap.size };
  }

  let batch = db.batch();
  let opCount = 0;
  let copied = 0;

  for (const doc of snap.docs) {
    const targetRef = tenantRoot.collection(target).doc(doc.id);
    batch.set(targetRef, doc.data(), { merge: true });
    opCount += 1;
    copied += 1;

    if (opCount >= 400) {
      await batch.commit();
      batch = db.batch();
      opCount = 0;
    }
  }

  if (opCount > 0) {
    await batch.commit();
  }

  return { source, target, count: copied };
}

async function ensureTenantDoc() {
  const doc = await tenantRoot.get();
  if (isDryRun) {
    return { source: 'universiteler/usak', target: `universiteler/${uniId}`, count: doc.exists ? 0 : 1 };
  }

  await tenantRoot.set(
    {
      ad: 'Uşak Üniversitesi',
      aktif: true,
      migratedAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
  return { source: 'universiteler/usak', target: `universiteler/${uniId}`, count: doc.exists ? 0 : 1 };
}

async function copyFaturaArchiveToTenant() {
  let copied = 0;
  for (let year = currentYear - 6; year <= currentYear; year += 1) {
    const sourceRef = db
      .collection('faturalar_gecici')
      .doc(String(year))
      .collection('kayitlar');
    const snap = await sourceRef.get();
    if (snap.empty) continue;

    if (isDryRun) {
      copied += snap.size;
      continue;
    }

    let batch = db.batch();
    let opCount = 0;
    for (const doc of snap.docs) {
      const targetRef = tenantRoot
        .collection('faturalar_gecici')
        .doc(String(year))
        .collection('kayitlar')
        .doc(doc.id);
      batch.set(targetRef, doc.data(), { merge: true });
      opCount += 1;
      copied += 1;

      if (opCount >= 400) {
        await batch.commit();
        batch = db.batch();
        opCount = 0;
      }
    }

    if (opCount > 0) {
      await batch.commit();
    }
  }
  return { source: 'faturalar_gecici/*/kayitlar', target: 'faturalar_gecici/*/kayitlar', count: copied };
}

async function migrateAyarlar() {
  const legacyRef = db.collection('ayarlar').doc('sistem_genel');
  const legacyDoc = await legacyRef.get();
  if (!legacyDoc.exists || !legacyDoc.data()) {
    return { source: 'ayarlar/sistem_genel', target: 'sistemAyarlari/sistem_genel', count: 0 };
  }

  if (!isDryRun) {
    await tenantRoot.collection('sistemAyarlari').doc('sistem_genel').set(legacyDoc.data(), { merge: true });
  }

  return { source: 'ayarlar/sistem_genel', target: 'sistemAyarlari/sistem_genel', count: 1 };
}

async function main() {
  console.log(`Starting migration -> universiteler/${uniId} (dry-run=${isDryRun})`);
  console.log('Critical collections prioritized: firmalar, hizmetler, birimler, sistemSablonlari');

  const plan = [
    { source: 'firmalar', target: 'firmalar' },
    { source: 'hizmetler', target: 'hizmetler' },
    { source: 'birimler', target: 'birimler' },
    { source: 'sistemSablonlari', target: 'sistemSablonlari' },
  ];

  if (includeTemp) {
    plan.push({ source: 'danismanliklar', target: 'danismanliklar' });
    plan.push({ source: 'toplantilar', target: 'toplantilar' });
    plan.push({ source: 'ykKararlari', target: 'ykKararlari' });
  }

  const backupPayload = { uniId, includeTemp, createdAt: new Date().toISOString(), collections: {} };
  for (const item of plan) {
    backupPayload.collections[item.source] = await backupCollection(item.source);
  }
  backupPayload.collections['ayarlar/sistem_genel'] = await backupCollection('ayarlar');
  backupPayload.collections['faturalar_gecici/*/kayitlar'] = await backupFaturaArchive();
  const backupFile = await writeBackup(backupPayload);
  console.log(`Backup written: ${backupFile}`);

  const results = [];
  const tenantResult = await ensureTenantDoc();
  results.push(tenantResult);
  console.log(`${tenantResult.source} -> ${tenantResult.target}: ${tenantResult.count}`);

  for (const item of plan) {
    const r = await copyCollectionToTenant(item);
    results.push(r);
    console.log(`${r.source} -> ${r.target}: ${r.count}`);
  }

  const faturaResult = await copyFaturaArchiveToTenant();
  results.push(faturaResult);
  console.log(`${faturaResult.source} -> ${faturaResult.target}: ${faturaResult.count}`);

  const ayarlarResult = await migrateAyarlar();
  results.push(ayarlarResult);
  console.log(`${ayarlarResult.source} -> ${ayarlarResult.target}: ${ayarlarResult.count}`);

  console.log('Migration summary:');
  for (const r of results) {
    console.log(`- ${r.source} => ${r.target}: ${r.count}`);
  }
  console.log('Done.');
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
