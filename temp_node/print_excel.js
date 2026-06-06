const xlsx = require('xlsx');

const file = 'E:/antivaty/dsys_v2/ornek/2026 YENİ İBANLARLA FATURA ŞABLONLARI/2026 YENİ İBANLARLA FATURA ŞABLONLARI/UBATAM/Ubatam Fatura Şablon - SU ANALİZ.xls';
const wb = xlsx.readFile(file);
for (const sheetName of wb.SheetNames) {
  console.log(`\n--- Sheet: ${sheetName} ---`);
  const sheet = wb.Sheets[sheetName];
  const data = xlsx.utils.sheet_to_json(sheet, {header: 1});
  for (let i = 0; i < Math.min(20, data.length); i++) {
    console.log(data[i]);
  }
}
