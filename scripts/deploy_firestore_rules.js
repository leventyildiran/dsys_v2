const { initializeFirebaseAdmin } = require('./firebase_admin_init');
const fs = require('fs');
const path = require('path');

async function deploy() {
  const admin = initializeFirebaseAdmin();
  const rulesPath = path.join(__dirname, '..', 'dsys', 'firestore.rules');
  const rulesContent = fs.readFileSync(rulesPath, 'utf8');
  console.log('Deploying firestore.rules to project dsys-44b8e...');
  const ruleset = await admin.securityRules().releaseFirestoreRulesetFromSource(rulesContent);
  console.log('✅ Firestore rules deployed successfully! Ruleset name:', ruleset.name);
}

deploy().catch((err) => {
  console.error('❌ Failed to deploy firestore rules:', err);
  process.exit(1);
});
