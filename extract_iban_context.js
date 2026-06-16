const xlsx = require('xlsx');
const fs = require('fs');
const path = require('path');

const baseDir = 'e:\\antivaty\\dsys_v2\\ornek\\FATURA KESİM\\2026 YENİ İBANLARLA FATURA ŞABLONLARI';
const units = fs.readdirSync(baseDir).filter(f => fs.statSync(path.join(baseDir, f)).isDirectory());

let result = '';

units.forEach(unit => {
  const unitDir = path.join(baseDir, unit);
  const files = fs.readdirSync(unitDir).filter(f => f.endsWith('.xls') || f.endsWith('.xlsx'));
  
  files.forEach(file => {
    try {
      const workbook = xlsx.readFile(path.join(unitDir, file));
      workbook.SheetNames.forEach(sheet => {
        const json = xlsx.utils.sheet_to_json(workbook.Sheets[sheet], { header: 1 });
        json.forEach((row, rowIndex) => {
          row.forEach((cell, colIndex) => {
            if (typeof cell === 'string') {
              const str = cell.replace(/\s+/g, '');
              if (str.includes('TR') && str.length >= 26) {
                const match = str.match(/TR\d{24}/);
                if (match) {
                   // Let's grab this row and the previous 2 rows to see context
                   result += `\n[${unit}] - ${file}\n`;
                   for (let i = Math.max(0, rowIndex - 3); i <= rowIndex + 1; i++) {
                     if (json[i]) {
                       result += `R${i}: ${json[i].join(' | ')}\n`;
                     }
                   }
                }
              }
            }
          });
        });
      });
    } catch (e) {}
  });
});

fs.writeFileSync('e:\\antivaty\\dsys_v2\\iban_context.txt', result);
console.log('Context hazır');
