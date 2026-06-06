const xlsx = require('xlsx');
const file = 'E:/antivaty/dsys_v2/ornek/YÜRÜTME KURULU KARARLARI/YÜRÜTME KURULU KARARLARI/2024 YKK/19. TOPLANTI/GÜNDEMLER/BİRİMLERİN BÜTÇE TEKLİFLERİ/UBATAM/UBATAM_2025-26-27_GELİR.xlsx';
try {
  const wb = xlsx.readFile(file);
  for (const sheetName of wb.SheetNames) {
    console.log(`\n--- Sheet: ${sheetName} ---`);
    const sheet = wb.Sheets[sheetName];
    const data = xlsx.utils.sheet_to_json(sheet, {header: 1});
    for (let i = 0; i < Math.min(20, data.length); i++) {
      console.log(data[i]);
    }
  }
} catch(e) { console.error(e.message); }
