const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'dsys-44b8e';
const STORAGE_BUCKET = 'dsys-44b8e.firebasestorage.app';

function resolveServiceAccountPath() {
  const fromEnv = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (fromEnv && fs.existsSync(fromEnv)) return fromEnv;

  const repoRoot = path.join(__dirname, '..');
  const files = fs
    .readdirSync(repoRoot)
    .filter((f) => f.includes('firebase-adminsdk') && f.endsWith('.json'));
  if (files.length === 0) {
    throw new Error(
      'Firebase service account bulunamadı. GOOGLE_APPLICATION_CREDENTIALS ayarlayın ' +
        'veya *firebase-adminsdk*.json dosyasını proje köküne koyun (asla commit etmeyin).',
    );
  }
  return path.join(repoRoot, files.sort().reverse()[0]);
}

function loadServiceAccount() {
  return JSON.parse(fs.readFileSync(resolveServiceAccountPath(), 'utf8'));
}

function initializeFirebaseAdmin(options = {}) {
  if (admin.apps.length) return admin;

  const serviceAccount = loadServiceAccount();
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: PROJECT_ID,
    storageBucket: options.storageBucket ?? STORAGE_BUCKET,
    ...options,
  });
  return admin;
}

module.exports = {
  PROJECT_ID,
  STORAGE_BUCKET,
  resolveServiceAccountPath,
  loadServiceAccount,
  initializeFirebaseAdmin,
};
