const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');
const { initializeFirebaseAdmin } = require('./scripts/firebase_admin_init');

const admin = initializeFirebaseAdmin();
const db = admin.firestore();

const TARGET_DIR = 'e:/antivaty/dsys_v2/ornek/FATURA KESİM/2026 YENİ İBANLARLA FATURA ŞABLONLARI';

// Function to clean and normalize text for comparison
function normalizeBirimAdi(text) {
    if (!text) return '';
    let result = text.toLocaleLowerCase('tr-TR');
    result = result.replace(/[,.]/g, ''); // Remove commas and dots
    result = result.replace(/\s+/g, ''); // Remove spaces
    if (result.endsWith('müdürlüğü')) {
        result = result.substring(0, result.length - 9); // Remove "müdürlüğü"
    }
    return result.trim();
}

async function migrateIbans() {
  const birimlerSnapshot = await db.collection('birimler').get();
  const birimlerDb = birimlerSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));

  const subDirs = fs.readdirSync(TARGET_DIR, { withFileTypes: true });
  for (let dir of subDirs) {
    if (dir.isDirectory()) {
      const dirPath = path.join(TARGET_DIR, dir.name);
      const files = fs.readdirSync(dirPath);
      for (let file of files) {
        if (file.endsWith('.xls') || file.endsWith('.xlsx')) {
          console.log(`\nParsing: ${dir.name}/${file}`);
          const filePath = path.join(dirPath, file);
          const wb = xlsx.readFile(filePath);
          const sheet = wb.Sheets[wb.SheetNames[0]];
          const rows = xlsx.utils.sheet_to_json(sheet, { header: 1, defval: '' });

          // Extract Firma (Birim)
          let firmaText = '';
          for (let i = 0; i < 10; i++) {
            if (rows[i] && typeof rows[i][0] === 'string' && rows[i][0].trim() !== '') {
              firmaText = rows[i][0].trim();
              break;
            }
          }
          if (!firmaText) continue;

          // Find IBAN (starts with TR)
          let iban = '';
          let hesapAdi = '';
          
          // Let's search the last 15 rows for IBAN
          const startRow = Math.max(0, rows.length - 15);
          for (let i = startRow; i < rows.length; i++) {
            const row = rows[i];
            if (!row) continue;
            for(let j=0; j < row.length; j++) {
                if(typeof row[j] === 'string' && row[j].replace(/\s/g, '').includes('TR')) {
                    // This might be the IBAN row!
                    const match = row[j].match(/TR[0-9A-Z]{24}/);
                    if(match) {
                        iban = match[0];
                    }
                }
            }
          }
          
          // Hesap Adi is often in the row just above IBAN or in a specific cell.
          // In the example we saw, Hesap Adi is often next to the IBAN or near the bottom
          // Let's find "Banka :" or just use firmaText as the account name if we can't find anything specific
          // Actually, in the UBATAM example, it was in the same row as IBAN but earlier column, or just the line above
          for (let i = startRow; i < rows.length; i++) {
             const row = rows[i];
             if(!row) continue;
             if (row[0] && typeof row[0] === 'string' && row[0].includes('DSİ')) {
                 hesapAdi = row[0].replace(/\n/g, ' ').trim();
                 break;
             }
             if (row[0] && typeof row[0] === 'string' && row[0].includes('Döner Sermaye')) {
                 hesapAdi = row[0].replace(/\n/g, ' ').trim();
                 break;
             }
          }

          if(!hesapAdi) hesapAdi = firmaText; // Fallback

          if(iban) {
              console.log(`> Found IBAN: ${iban}`);
              console.log(`> Found Hesap Adi: ${hesapAdi}`);
              console.log(`> For Birim (from Excel): ${firmaText}`);
              
              const normalizedExcelName = normalizeBirimAdi(firmaText);
              
              // Find in DB
              const matchedBirim = birimlerDb.find(b => normalizeBirimAdi(b.ad) === normalizedExcelName);
              if (matchedBirim) {
                  console.log(`> MATCHED in DB: ${matchedBirim.ad}`);
                  await db.collection('birimler').doc(matchedBirim.id).update({
                      iban: iban,
                      hesapAdi: hesapAdi
                  });
                  console.log(`> UPDATED Firestore successfully.`);
              } else {
                  console.log(`> NO MATCH found in DB for: ${firmaText}`);
              }
          } else {
              console.log(`> No IBAN found in this file.`);
          }
        }
      }
    }
  }
}

migrateIbans().then(() => {
    console.log("Migration complete.");
    process.exit(0);
}).catch(console.error);
