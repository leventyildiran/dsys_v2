const xlsx = require('xlsx');

const file = 'E:/antivaty/dsys_v2/ornek/2026 YENİ İBANLARLA FATURA ŞABLONLARI/2026 YENİ İBANLARLA FATURA ŞABLONLARI/UBATAM/Ubatam Fatura Şablon - SU ANALİZ.xls';
const wb = xlsx.readFile(file);
const sheet = wb.Sheets['VERİ GİRİŞ'];
const data = xlsx.utils.sheet_to_json(sheet, {header: 1});

console.log("Master List Items:");
for (let i = 0; i < data.length; i++) {
  const row = data[i];
  if (row.length > 5) {
    const idx = row[5];
    const name = row[6];
    const price = row[7];
    if (name && price) {
      console.log(`Index: ${idx}, Name: ${name}, Price: ${price}`);
    }
  }
}
