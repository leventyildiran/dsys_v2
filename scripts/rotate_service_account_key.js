/**
 * Sızmış Firebase Admin SDK anahtarını döndürür:
 * 1) Yeni anahtar üretir
 * 2) GitHub Actions secret günceller (gh CLI)
 * 3) Eski anahtarı IAM'den siler
 * 4) Eski yerel JSON dosyasını kaldırır
 *
 * Kullanım: node scripts/rotate_service_account_key.js
 */
const fs = require('fs');
const path = require('path');
const https = require('https');
const { spawnSync } = require('child_process');
const { loadServiceAccount, resolveServiceAccountPath, PROJECT_ID } = require('./firebase_admin_init');

const REPO = 'leventyildiran/dsys_v2';

async function getAccessToken(serviceAccount) {
  try {
    const { JWT } = require('google-auth-library');
    const client = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ['https://www.googleapis.com/auth/cloud-platform'],
    });
    const { access_token: token } = await client.authorize();
    if (!token) throw new Error('GCP access token alınamadı.');
    return token;
  } catch (err) {
    const msg = String(err.message || err);
    if (!msg.includes('invalid_grant') && !msg.includes('Invalid JWT')) throw err;
    console.warn('Mevcut service account anahtarı Google tarafından iptal edilmiş.');
    return getTokenFromGcloud();
  }
}

function getTokenFromGcloud() {
  const r = spawnSync('gcloud', ['auth', 'print-access-token'], {
    encoding: 'utf8',
    shell: true,
  });
  const token = (r.stdout || '').trim();
  if (r.status === 0 && token) return token;
  throw new Error(
    'Otomatik anahtar döndürme yapılamadı.\n' +
      '1) https://console.firebase.google.com/project/dsys-44b8e/settings/serviceaccounts/adminsdk\n' +
      '   → "Generate new private key" ile yeni JSON indirin\n' +
      '2) Eski dsys-44b8e-firebase-adminsdk-*.json dosyasını silin, yenisini proje köküne koyun\n' +
      '3) GOOGLE_APPLICATION_CREDENTIALS ortam değişkenini kaldırın veya yeni dosyayı gösterin\n' +
      '4) .\\scripts\\setup_firebase_github_secret.ps1 çalıştırın\n' +
      '5) npm run security:purge-git && git push origin --force --all',
  );
}

function apiRequest({ method, url, token, body }) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(url);
    const payload = body ? JSON.stringify(body) : null;
    const req = https.request(
      {
        hostname: parsed.hostname,
        path: parsed.pathname + parsed.search,
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          ...(payload
            ? {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(payload),
              }
            : {}),
        },
      },
      (res) => {
        let data = '';
        res.on('data', (chunk) => (data += chunk));
        res.on('end', () => {
          if (res.statusCode >= 200 && res.statusCode < 300) {
            resolve(data ? JSON.parse(data) : {});
            return;
          }
          reject(new Error(`IAM ${method} ${res.statusCode}: ${data}`));
        });
      },
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function createKey(token, clientEmail) {
  const resource = `projects/${PROJECT_ID}/serviceAccounts/${encodeURIComponent(clientEmail)}`;
  return apiRequest({
    method: 'POST',
    url: `https://iam.googleapis.com/v1/${resource}/keys`,
    token,
    body: {},
  });
}

async function deleteKey(token, clientEmail, keyId) {
  const resource = `projects/${PROJECT_ID}/serviceAccounts/${encodeURIComponent(clientEmail)}/keys/${keyId}`;
  return apiRequest({
    method: 'DELETE',
    url: `https://iam.googleapis.com/v1/${resource}`,
    token,
  });
}

function updateGithubSecret(jsonString) {
  const r = spawnSync(
    'gh',
    ['secret', 'set', 'FIREBASE_SERVICE_ACCOUNT', '--repo', REPO],
    { input: jsonString, encoding: 'utf8' },
  );
  if (r.status !== 0) {
    throw new Error(r.stderr || r.stdout || 'gh secret set başarısız');
  }
}

async function main() {
  const oldPath = resolveServiceAccountPath();
  const oldAccount = loadServiceAccount();
  const oldKeyId = oldAccount.private_key_id;
  const clientEmail = oldAccount.client_email;

  console.log('Mevcut anahtar:', path.basename(oldPath));
  console.log('Service account:', clientEmail);

  const token = await getAccessToken(oldAccount);
  console.log('Yeni anahtar oluşturuluyor...');
  const created = await createKey(token, clientEmail);

  const newJson = Buffer.from(created.privateKeyData, 'base64').toString('utf8');
  const newAccount = JSON.parse(newJson);
  const newKeyId = newAccount.private_key_id;
  const newFileName = `${PROJECT_ID}-firebase-adminsdk-fbsvc-${newKeyId.slice(0, 10)}.json`;
  const newPath = path.join(path.dirname(oldPath), newFileName);

  fs.writeFileSync(newPath, JSON.stringify(newAccount, null, 2), 'utf8');
  console.log('Yeni anahtar kaydedildi:', newFileName);

  console.log('GitHub secret güncelleniyor...');
  updateGithubSecret(JSON.stringify(newAccount));
  console.log('FIREBASE_SERVICE_ACCOUNT secret güncellendi.');

  const newToken = await getAccessToken(newAccount);
  console.log('Eski anahtar siliniyor:', oldKeyId);
  await deleteKey(newToken, clientEmail, oldKeyId);

  if (path.resolve(oldPath) !== path.resolve(newPath) && fs.existsSync(oldPath)) {
    fs.unlinkSync(oldPath);
    console.log('Eski yerel dosya silindi.');
  }

  console.log('');
  console.log('Tamamlandı. Sonraki adımlar:');
  console.log('1) node scripts/purge_leaked_credentials_from_git.js');
  console.log('2) GCP e-postasındaki politika ihlali bağlantısından onay/inceleme gönderin');
  console.log('3) API Keys: https://console.cloud.google.com/apis/credentials?project=dsys-44b8e');
  console.log('   Web API anahtarlarını yalnızca dsys-44b8e.web.app ve firebaseapp.com ile kısıtlayın');
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
