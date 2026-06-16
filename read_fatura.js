const xlsx = require('xlsx');
const fs = require('fs');

const files = [
  'e:\\antivaty\\dsys_v2\\fatura\\BİYOSİDAL FATURALARI 2026 GÜNCEL .xlsx',
  'e:\\antivaty\\dsys_v2\\fatura\\ÇEVRE FATURALARI 2026 GÜNCEL.xlsx',
  'e:\\antivaty\\dsys_v2\\fatura\\ISG FATURALARI 2026 GÜNCEL.xlsx'
];

let output = '';

files.forEach(file => {
  try {
    const workbook = xlsx.readFile(file);
    output += `\n\n=== FILE: ${file} ===\n`;
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
    output += `\nError reading ${file}: ${e.message}\n`;
  }
});

fs.writeFileSync('e:\\antivaty\\dsys_v2\\fatura_dump.txt', output);
console.log('Dump complete');
