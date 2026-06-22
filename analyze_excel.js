const fs = require('fs');
const path = require('path');
const xlsx = require('xlsx');

const searchDirs = [
  path.join(__dirname, 'ornek', 'BELGELER'),
  path.join(__dirname, 'ornek', 'FATURA KESİM')
];

let allFiles = [];

function findExcelFiles(dir) {
  if (!fs.existsSync(dir)) return;
  const items = fs.readdirSync(dir);
  for (const item of items) {
    const fullPath = path.join(dir, item);
    const stat = fs.statSync(fullPath);
    if (stat.isDirectory()) {
      findExcelFiles(fullPath);
    } else if (fullPath.endsWith('.xls') || fullPath.endsWith('.xlsx')) {
      allFiles.push(fullPath);
    }
  }
}

searchDirs.forEach(d => findExcelFiles(d));

console.log(`Bulunan Excel dosyası sayısı: ${allFiles.length}`);

const summary = {};
const uniqueHeaders = new Set();
const specialValues = new Set();

allFiles.forEach(file => {
  try {
    const workbook = xlsx.readFile(file);
    const sheetNames = workbook.SheetNames;
    
    sheetNames.forEach(sheetName => {
      const sheet = workbook.Sheets[sheetName];
      const data = xlsx.utils.sheet_to_json(sheet, { header: 1, defval: null });
      
      // Sadece ilk 10 satıra bakalım, başlık ve meta verileri çıkarmak için
      const topRows = data.slice(0, 15);
      
      topRows.forEach(row => {
        row.forEach(cell => {
          if (typeof cell === 'string') {
            const val = cell.trim();
            if (val.length > 2 && val.length < 50) {
              uniqueHeaders.add(val);
              
              if (val.toLowerCase().includes('kdv') || 
                  val.toLowerCase().includes('stopaj') || 
                  val.toLowerCase().includes('tevkifat') || 
                  val.toLowerCase().includes('iban') || 
                  val.toLowerCase().includes('avans') || 
                  val.toLowerCase().includes('mahsup')) {
                specialValues.add(val);
              }
            }
          }
        });
      });
    });
  } catch (e) {
    console.error(`Okuma hatası: ${file}`, e.message);
  }
});

console.log('\n--- ÖZEL / KRİTİK ALANLAR (Gözden Kaçan Olabilir) ---');
Array.from(specialValues).forEach(v => console.log(`- ${v}`));

console.log('\n--- RASTGELE ÖRNEK BAŞLIKLAR ---');
const headersArr = Array.from(uniqueHeaders);
for(let i=0; i<Math.min(30, headersArr.length); i++) {
  console.log(headersArr[Math.floor(Math.random() * headersArr.length)]);
}
