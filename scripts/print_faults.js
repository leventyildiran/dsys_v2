const fs = require('fs');
const faults = JSON.parse(fs.readFileSync('e:/antivaty/G-revde-Y-kselme/scripts/lisansustu_hatali_sorular_raporu.json', 'utf8'));

faults.forEach((f, i) => {
  console.log('\n==============================');
  console.log('HATA ' + (i + 1) + ' [Soru ID: ' + f.id + ']');
  console.log('Soru: ' + f.question);
  console.log('Seçenekler: ' + JSON.stringify(f.options, null, 2));
  console.log('Eski Cevap: ' + f.originalAnswer + ' -> DOĞRU CEVAP: ' + f.verifiedAnswer);
  console.log('Kaynaklar: ' + f.sources.join(', '));
  console.log('Gerekçe: ' + f.reason);
});
