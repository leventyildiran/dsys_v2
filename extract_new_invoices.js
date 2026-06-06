const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');

const TARGET_DIR = 'e:/antivaty/dsys_v2/ornek/FATURA KESİM/2026 YENİ İBANLARLA FATURA ŞABLONLARI';
const OUTPUT_FILE = 'e:/antivaty/dsys_v2/assets/data/yeni_veriler.json';

const result = {
  firmalar: [],
  hizmetler: []
};

function processDirectory(dirPath) {
  const files = fs.readdirSync(dirPath);
  for (const file of files) {
    const fullPath = path.join(dirPath, file);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      processDirectory(fullPath);
    } else if (file.endsWith('.xls') || file.endsWith('.xlsx')) {
      processExcel(fullPath, dirPath);
    }
  }
}

function processExcel(filePath, dirPath) {
  try {
    const wb = xlsx.readFile(filePath);
    const sheetName = wb.SheetNames[0];
    const sheet = wb.Sheets[sheetName];
    const rows = xlsx.utils.sheet_to_json(sheet, { header: 1 });
    
    if (rows.length < 20) return; // Skip if too small

    // Extract Firma
    let firmaText = '';
    for (let i = 0; i < 10; i++) {
      if (rows[i] && typeof rows[i][0] === 'string' && rows[i][0].trim() !== '') {
        firmaText = rows[i][0];
        break;
      }
    }
    if (!firmaText) return;
    
    const parts = firmaText.split('\n');
    const firmaAdi = parts[0] ? parts[0].trim() : '';
    const adres = parts.slice(1).join(' ').trim();

    if (firmaAdi) {
      result.firmalar.push({
        firmaAdi: firmaAdi,
        adres: adres,
        vergiDairesi: '',
        vergiNo: ''
      });
    }

    // Extract Hizmetler (starts from row 16 usually, but let's scan rows 10-50 for non-empty column 0 and a number in column 9)
    let birimAdi = path.basename(dirPath); // Folder name is Birim Adi
    
    for (let i = 10; i < Math.min(rows.length, 50); i++) {
      const row = rows[i];
      if (!row || !row[0]) continue;
      
      const text = row[0].toString().trim();
      // Skip if it's just a number or empty
      if (text === '' || !isNaN(text)) continue;

      let fiyat = 0;
      for (let j = row.length - 1; j >= 1; j--) {
        const val = parseFloat(row[j]);
        if (!isNaN(val) && val > 0) {
          fiyat = val;
          break;
        }
      }

      if (fiyat > 0) {
        result.hizmetler.push({
          birimAdi: birimAdi,
          hizmetAdi: text,
          fiyat: fiyat
        });
      }
    }
    console.log(`Processed: ${path.basename(filePath)}`);
  } catch (err) {
    console.error(`Error processing ${filePath}:`, err.message);
  }
}

processDirectory(TARGET_DIR);

fs.writeFileSync(OUTPUT_FILE, JSON.stringify(result, null, 2));
console.log(`\nExtraction complete. Found ${result.firmalar.length} firmalar and ${result.hizmetler.length} hizmetler.`);
