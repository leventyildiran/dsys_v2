const xlsx = require('xlsx');
const fs = require('fs');
const path = require('path');

const dir = 'e:\\antivaty\\dsys_v2\\fatura';
let output = '';

try {
  const files = fs.readdirSync(dir).filter(f => f.endsWith('.xlsx'));
  files.forEach(file => {
    const fullPath = path.join(dir, file);
    output += `\n\n=== FILE: ${file} ===\n`;
    try {
      const workbook = xlsx.readFile(fullPath);
      workbook.SheetNames.forEach(sheetName => {
        output += `\n--- SHEET: ${sheetName} ---\n`;
        const json = xlsx.utils.sheet_to_json(workbook.Sheets[sheetName], { header: 1 });
        json.forEach(row => {
          if (row.length > 0 && row.some(cell => cell !== undefined && cell !== null && cell !== '')) {
            output += row.join(' | ') + '\n';
          }
        });
      });
    } catch (e) {
      output += `Error reading file: ${e.message}\n`;
    }
  });
  fs.writeFileSync('e:\\antivaty\\dsys_v2\\fatura_dump2.txt', output);
  console.log('Dump 2 complete');
} catch (e) {
  console.log('Dir error: ' + e.message);
}
