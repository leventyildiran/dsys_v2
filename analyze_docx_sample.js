const fs = require('fs');
const AdmZip = require('adm-zip');

const p = 'E:/antivaty/dsys_v2/ornek/5Yürütme Kurulu Kararları.docx';
const z = new AdmZip(p);
const xml = z.readAsText('word/document.xml');

const tbl = (xml.match(/<w:tbl>/g) || []).length;
const shd = (xml.match(/w:shd/g) || []).length;
console.log('tables', tbl, 'shd', shd, 'len', xml.length);

function paraText(pXml) {
  return pXml
    .replace(/<w:tab\/>/g, '\t')
    .replace(/<w:br\/>/g, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .trim();
}

// Split body into block elements (p or tbl)
const bodyMatch = xml.match(/<w:body>([\s\S]*)<\/w:body>/);
if (!bodyMatch) {
  console.log('no body');
  process.exit(1);
}
const body = bodyMatch[1];

const blocks = [];
const re = /<(w:p|w:tbl)\b[\s\S]*?<\/\1>/g;
let m;
while ((m = re.exec(body)) !== null) {
  blocks.push({ type: m[1], xml: m[0], text: m[1] === 'w:p' ? paraText(m[0]) : '[TABLE]' });
}

console.log('blocks', blocks.length);
let kararCount = 0;
for (const b of blocks) {
  if (/^KARAR\s+20\d{2}\/\d+/i.test(b.text)) {
    kararCount++;
    if (kararCount <= 8) console.log('KARAR:', b.text.substring(0, 100));
  }
}
console.log('total karar markers', kararCount);

// Show birim-like lines
const birimLines = blocks
  .filter((b) => b.type === 'w:p' && /Müdürlüğü|Fakültesi|Merkezi|Enstitüsü|Bölümü/i.test(b.text))
  .slice(0, 10)
  .map((b) => b.text.substring(0, 120));
console.log('birim samples:', birimLines);
