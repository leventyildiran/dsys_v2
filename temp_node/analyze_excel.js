const XLSX = require('xlsx');
const path = require('path');

const file = 'e:\\antivaty\\dsys_v2\\ornek\\2026 YENİ İBANLARLA FATURA ŞABLONLARI\\2026 YENİ İBANLARLA FATURA ŞABLONLARI\\UBATAM\\Ubatam Fatura Şablon - SU ANALİZ.xls';

const wb = XLSX.readFile(file);
wb.SheetNames.forEach(name => {
  console.log('\n=== SHEET:', name, '===');
  const data = XLSX.utils.sheet_to_json(wb.Sheets[name], {header: 1});
  for (let i = 0; i < Math.min(20, data.length); i++) {
      console.log(`Row ${i+1}:`, data[i]);
  }
});
