const xlsx = require('xlsx');
const fs = require('fs');
const path = require('path');

function getFiles(dir, files = []) {
  const fileList = fs.readdirSync(dir);
  for (const file of fileList) {
    const name = path.join(dir, file);
    if (fs.statSync(name).isDirectory()) {
      getFiles(name, files);
    } else if (name.toLowerCase().endsWith('.xls') || name.toLowerCase().endsWith('.xlsx')) {
      files.push(name);
    }
  }
  return files;
}

const baseDir = 'E:/antivaty/dsys_v2/ornek/2026 YENİ İBANLARLA FATURA ŞABLONLARI/2026 YENİ İBANLARLA FATURA ŞABLONLARI';
const files = getFiles(baseDir);

const allHizmetler = [];
const seen = new Set();

for (const file of files) {
  try {
    const wb = xlsx.readFile(file);
    
    // Which unit is this? Use the directory name
    const unitName = path.basename(path.dirname(file));
    let officialUnitName = unitName;
    if (unitName === 'UBATAM') officialUnitName = 'BİLİMSEL ANALİZ VE TEKNOLOJİK UYGULAMA VE ARAŞTIRMA MERKEZİ MÜDÜRLÜĞÜ';
    if (unitName === 'USEM') officialUnitName = 'SÜREKLİ EĞİTİM ARAŞTIRMA VE UYGULAMA MERKEZİ MÜDÜRLÜĞÜ';
    if (unitName === 'TÖMER') officialUnitName = 'TÜRKÇE ÖĞRETİMİ UYGULAMA VE ARAŞTIRMA MERKEZİ MÜDÜRLÜĞÜ';
    if (unitName === 'DTS') officialUnitName = 'DERİ TEKSTİL VE SERAMİK TASARIM UYGULAMA VE ARAŞTIRMA MERKEZİ MÜDÜRLÜĞÜ';
    if (unitName === 'DÖSİM') officialUnitName = 'DÖNER SERMAYE İŞLETMESİ MÜDÜRLÜĞÜ';
    if (unitName === 'TADAUM') officialUnitName = 'TARIMSAL ARAŞTIRMA VE UYGULAMA MERKEZİ MÜDÜRLÜĞÜ';

    if (wb.Sheets['VERİ GİRİŞ']) {
      const sheet = wb.Sheets['VERİ GİRİŞ'];
      const data = xlsx.utils.sheet_to_json(sheet, {header: 1});
      
      for (const row of data) {
        // Try to find the master list columns
        // It's usually after 3 empty items. Let's look for a string followed by a number
        let name = null;
        let price = null;
        
        // Scan the row for a string (name) and a number (price) towards the end
        for (let i = 5; i < row.length - 1; i++) {
           if (typeof row[i] === 'string' && row[i].length > 3 && typeof row[i+1] === 'number') {
             name = row[i].trim();
             price = row[i+1];
             break;
           }
        }
        
        if (name && price) {
          const key = `${officialUnitName}-${name}`;
          if (!seen.has(key)) {
            seen.add(key);
            allHizmetler.push({
              birimAdi: officialUnitName,
              hizmetAdi: name,
              fiyat: price
            });
          }
        }
      }
    }
  } catch(e) {}
}

fs.writeFileSync('E:/antivaty/dsys_v2/assets/data/hizmetler_tam.json', JSON.stringify(allHizmetler, null, 2));
console.log(`Extracted ${allHizmetler.length} items!`);
