const XLSX = require('xlsx');
const filePath = 'e:\\antivaty\\dsys_v2\\ornek\\2026 YENİ İBANLARLA FATURA ŞABLONLARI\\2026 YENİ İBANLARLA FATURA ŞABLONLARI\\DÖSİM\\EMİNE KAYHAN PULTECH  FATURA ÖRNEĞİ -.xls';

try {
  const workbook = XLSX.readFile(filePath);
  console.log("SHEET NAMES:", workbook.SheetNames);
  for (const sheetName of workbook.SheetNames) {
    console.log(`\n--- SHEET: ${sheetName} ---`);
    const worksheet = workbook.Sheets[sheetName];
    const json = XLSX.utils.sheet_to_json(worksheet, { header: 1 });
    for (let i = 0; i < Math.min(10, json.length); i++) {
      console.log(`Row ${i + 1}:`, json[i]);
    }
  }
} catch (e) {
  console.error("Error reading file:", e);
}
