const xlsx = require('xlsx');
const path = 'e:/antivaty/dsys_v2/ornek/FATURA KESİM/2026 YENİ İBANLARLA FATURA ŞABLONLARI/DTS/DTS RATEKS FATURASI.xls';

try {
  const wb = xlsx.readFile(path);
  const sheet = wb.Sheets[wb.SheetNames[0]];
  const rows = xlsx.utils.sheet_to_json(sheet, { header: 1 });
  
  for (let i = 0; i < 30; i++) {
    console.log(`Row ${i}:`, rows[i]);
  }
} catch (err) {
  console.error(err);
}
