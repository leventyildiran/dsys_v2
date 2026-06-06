const fs = require('fs');
const path = require('path');
const XLSX = require('xlsx');

const rootDir = 'e:\\antivaty\\dsys_v2\\ornek\\2026 YENİ İBANLARLA FATURA ŞABLONLARI\\2026 YENİ İBANLARLA FATURA ŞABLONLARI';

let firmalarMap = {}; // Use vergiNo or name as key to avoid duplicates
let hizmetler = [];

function walkDir(dir, callback) {
  fs.readdirSync(dir).forEach(f => {
    let dirPath = path.join(dir, f);
    let isDirectory = fs.statSync(dirPath).isDirectory();
    isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
  });
}

function processFirmaAdres(rawString) {
  if (!rawString) return { adi: '', adres: '' };
  const parts = rawString.toString().split(/\n|\r/);
  if (parts.length > 1) {
    const adi = parts[0].trim();
    const adres = parts.slice(1).join(' ').trim();
    return { adi, adres };
  }
  // Try finding standard separators like ' Mah.', ' Cad.', ' Sok.'
  const addressMatch = rawString.match(/(.*?)(?:Mah\.|Cad\.|Sok\.|Cd\.|Sk\.|Organize Sanayi Bölgesi)(.*)/i);
  if (addressMatch && addressMatch.length >= 3) {
      // It's a bit tricky. We'll just put everything in 'adi' if we can't cleanly split,
      // but let's try a simple split if there's a big gap of spaces.
      const spaceSplit = rawString.split(/\s{4,}/);
      if (spaceSplit.length > 1) {
          return { adi: spaceSplit[0].trim(), adres: spaceSplit.slice(1).join(' ').trim() };
      }
      return { adi: rawString.trim(), adres: '' };
  }
  return { adi: rawString.trim(), adres: '' };
}

walkDir(rootDir, function(filePath) {
  if (filePath.endsWith('.xls') || filePath.endsWith('.xlsx')) {
    const birimAdi = path.basename(path.dirname(filePath));
    console.log(`Processing: ${path.basename(filePath)} for Birim: ${birimAdi}`);
    try {
      const workbook = XLSX.readFile(filePath);
      
      // Parse Firmalar
      let firmaSheetName = workbook.SheetNames.find(s => s === 'Firma Bilgileri' || s === 'HAVUZ');
      if (firmaSheetName) {
        const json = XLSX.utils.sheet_to_json(workbook.Sheets[firmaSheetName], { header: 1 });
        // Start from row 1 (index 1) to skip headers
        for (let i = 1; i < json.length; i++) {
          const row = json[i];
          if (!row || row.length < 3) continue;
          
          let rawAdres = row[1];
          let vergiDairesi = row[2] ? row[2].toString().trim() : '';
          let vergiNo = row[3] ? row[3].toString().trim() : '';
          
          if (!rawAdres && !vergiNo) continue;
          
          let parsed = processFirmaAdres(rawAdres);
          let key = vergiNo ? vergiNo : parsed.adi;
          
          if (!firmalarMap[key]) {
            firmalarMap[key] = {
              firmaAdi: parsed.adi,
              adres: parsed.adres,
              vergiDairesi: vergiDairesi,
              vergiNo: vergiNo
            };
          }
        }
      }

      // Parse Hizmetler (VERİ GİRİŞ)
      let veriGirisSheet = workbook.SheetNames.find(s => s === 'VERİ GİRİŞ');
      if (veriGirisSheet) {
        const json = XLSX.utils.sheet_to_json(workbook.Sheets[veriGirisSheet], { header: 1 });
        // Services are usually from row 5 onwards. In some files, they are in cols 1,2,3 and 6,7,8.
        for (let i = 4; i < json.length; i++) {
          const row = json[i];
          if (!row) continue;
          
          // First block (Cols 1, 2, 3 -> Cinsi, Miktar, Fiyat)
          let cinsi1 = row[1];
          let fiyat1 = row[3];
          if (cinsi1 && typeof fiyat1 === 'number' && fiyat1 > 0) {
            hizmetler.push({
              birimAdi: birimAdi,
              hizmetAdi: cinsi1.toString().trim(),
              fiyat: parseFloat(fiyat1)
            });
          }
          
          // Second block (Cols 6, 7 or 7, 8 -> Cinsi, Fiyat)
          // Some files have it at 6 (name), 7 (price) or 7 (name), 8 (price).
          let cinsi2 = row[6] || row[7];
          let fiyat2 = row[7] || row[8];
          if (typeof cinsi2 === 'string' && typeof fiyat2 === 'number' && fiyat2 > 0) {
             hizmetler.push({
              birimAdi: birimAdi,
              hizmetAdi: cinsi2.toString().trim(),
              fiyat: parseFloat(fiyat2)
            });
          }
        }
      }
      
    } catch (e) {
      console.error(`Error reading ${filePath}:`, e);
    }
  }
});

const firmalarArray = Object.values(firmalarMap);

// Create assets/data directory if not exists
const outputDir = path.join('e:', 'antivaty', 'dsys_v2', 'assets', 'data');
if (!fs.existsSync(outputDir)){
    fs.mkdirSync(outputDir, { recursive: true });
}

fs.writeFileSync(path.join(outputDir, 'firmalar.json'), JSON.stringify(firmalarArray, null, 2));
fs.writeFileSync(path.join(outputDir, 'hizmetler.json'), JSON.stringify(hizmetler, null, 2));

console.log(`Extracted ${firmalarArray.length} firmalar and ${hizmetler.length} hizmetler.`);
