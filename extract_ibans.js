const xlsx = require('xlsx');
const fs = require('fs');
const path = require('path');

const baseDir = 'e:\\antivaty\\dsys_v2\\ornek\\FATURA KESİM\\2026 YENİ İBANLARLA FATURA ŞABLONLARI';
const units = fs.readdirSync(baseDir).filter(f => fs.statSync(path.join(baseDir, f)).isDirectory());

let result = 'BİRİMLERİN GÜNCEL 2026 IBANLARI VE FATURA ÖZELLİKLERİ\n======================================================\n\n';

units.forEach(unit => {
  result += `\n[BİRİM]: ${unit}\n`;
  const unitDir = path.join(baseDir, unit);
  const files = fs.readdirSync(unitDir).filter(f => f.endsWith('.xls') || f.endsWith('.xlsx'));
  
  let unitIbans = new Set();
  let features = new Set();

  files.forEach(file => {
    features.add(file);
    try {
      const workbook = xlsx.readFile(path.join(unitDir, file));
      workbook.SheetNames.forEach(sheet => {
        const json = xlsx.utils.sheet_to_json(workbook.Sheets[sheet], { header: 1 });
        json.forEach(row => {
          row.forEach(cell => {
            if (typeof cell === 'string') {
              const str = cell.replace(/\s+/g, '');
              if (str.includes('TR') && str.length >= 26) {
                const match = str.match(/TR\d{24}/);
                if (match) unitIbans.add(match[0]);
              }
            }
          });
        });
      });
    } catch (e) {
      // ignore
    }
  });

  result += `Güncel IBAN(lar):\n`;
  unitIbans.forEach(iban => {
    result += `- ${iban}\n`;
  });
  if (unitIbans.size === 0) result += `- IBAN Bulunamadı\n`;

  result += `\nFatura Tipleri / Örnek Dosyalar:\n`;
  features.forEach(f => {
    result += `- ${f}\n`;
  });
  result += '------------------------------------------------------\n';
});

fs.writeFileSync('e:\\antivaty\\dsys_v2\\iban_raporu.txt', result);
console.log('Rapor hazır');
