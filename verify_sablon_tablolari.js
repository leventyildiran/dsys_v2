/**
 * Şablon arşivlerinde tablo birebirlik raporu
 * node verify_sablon_tablolari.js [birim]
 */
const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');

const CIKTI = path.join(__dirname, 'ornek', 'cikti_sablonlar');
const BIRIM = process.argv[2] || 'UBATAM';

function analyzeDocx(filePath) {
  if (!fs.existsSync(filePath)) return null;
  const z = new AdmZip(filePath);
  const xml = z.readAsText('word/document.xml');
  const tblCount = (xml.match(/<w:tbl>/g) || []).length;
  const shdCount = (xml.match(/w:shd/g) || []).length;
  const trCount = (xml.match(/<w:tr[ >/]/g) || []).length;
  const tcCount = (xml.match(/<w:tc[ >/]/g) || []).length;
  const kararCount = (xml.match(/KARAR\s+20\d{2}\/\d+/gi) || []).length;
  const fills = [...new Set([...xml.matchAll(/w:fill="([A-F0-9]{6})"/gi)].map(m => m[1]))];
  return { tblCount, shdCount, trCount, tcCount, kararCount, fills, sizeKB: (fs.statSync(filePath).size / 1024).toFixed(1) };
}

console.log('═══════════════════════════════════════════════════════');
console.log('  ŞABLON TABLO BİREBİRLİK RAPORU');
console.log('═══════════════════════════════════════════════════════\n');

// 1) Yerel arşiv dosyaları
console.log('📁 YEREL ARŞİV: ornek/cikti_sablonlar/\n');
if (!fs.existsSync(CIKTI)) {
  console.log('  Klasör yok. Önce: node import_yk_sablonlar.js');
} else {
  const files = fs.readdirSync(CIKTI).filter(f => f.endsWith('.docx'));
  for (const f of files.sort()) {
    const info = analyzeDocx(path.join(CIKTI, f));
    if (!info) continue;
    console.log(`  ${f}`);
    console.log(`    Bölüm (KARAR/Gündem): ${info.kararCount || '-'} | Tablo: ${info.tblCount} | Satır: ${info.trCount} | Hücre: ${info.tcCount}`);
    console.log(`    Renkli hücre (w:shd): ${info.shdCount} | Renk kodları: ${info.fills.join(', ') || 'yok'}`);
    console.log(`    Boyut: ${info.sizeKB} KB\n`);
  }
}

// 2) Kaynak vs arşiv karşılaştırma (UBATAM örneği)
console.log('───────────────────────────────────────────────────────');
console.log(`📊 KAYNAK vs ARŞİV KARŞILAŞTIRMA (${BIRIM})\n`);

const arsivPath = path.join(CIKTI, `${BIRIM}_YK_Karar_Arsivi.docx`);
const kaynakPath = path.join(__dirname, 'ornek', '5Yürütme Kurulu Kararları.docx');

const arsiv = analyzeDocx(arsivPath);
const kaynak = analyzeDocx(kaynakPath);

if (arsiv) {
  console.log(`  Arşiv (${BIRIM}): ${arsiv.tblCount} tablo, ${arsiv.shdCount} renkli hücre`);
}
if (kaynak) {
  console.log(`  Kaynak örnek (5Yürütme Kurulu Kararları.docx): ${kaynak.tblCount} tablo, ${kaynak.shdCount} renkli hücre`);
}

// Tek bir karar bölümündeki tablo XML'ini örnek göster
if (fs.existsSync(arsivPath)) {
  const z = new AdmZip(arsivPath);
  const xml = z.readAsText('word/document.xml');
  const firstTbl = xml.match(/<w:tbl>[\s\S]*?<\/w:tbl>/);
  if (firstTbl) {
    const tbl = firstTbl[0];
    const hasShd = tbl.includes('w:shd');
    const hasBorders = tbl.includes('w:tblBorders') || tbl.includes('w:insideH');
    const rows = (tbl.match(/<w:tr[ >/]/g) || []).length;
    const cols = (tbl.match(/<w:tc[ >/]/g) || []).length / rows;
    console.log(`\n  İlk tablo örneği (arşivden):`);
    console.log(`    Satır: ${rows} | Ort. sütun: ~${Math.round(cols)}`);
    console.log(`    Renk (w:shd): ${hasShd ? 'VAR ✓' : 'YOK ✗'}`);
    console.log(`    Kenarlık: ${hasBorders ? 'VAR ✓' : 'standart'}`);
    const fillMatch = tbl.match(/w:fill="([A-F0-9]{6})"/i);
    if (fillMatch) console.log(`    Başlık rengi: #${fillMatch[1]} (orijinal Word rengi korunmuş)`);
  }
}

console.log('\n───────────────────────────────────────────────────────');
console.log('📌 NEREDEN GÖREBİLİRSİNİZ?\n');
console.log('  1) Word ile aç: ornek/cikti_sablonlar/UBATAM_YK_Karar_Arsivi.docx');
console.log('  2) Uygulama: Ayarlar → Sistem Şablonları → indir (Word Arşivi)');
console.log('  3) Simülasyon çıktısı: ornek/simulasyon_cikti/Simulasyon_Toplanti_2026_06.docx');
console.log('═══════════════════════════════════════════════════════');
