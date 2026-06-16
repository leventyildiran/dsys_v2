const AdmZip = require('adm-zip');

const p = 'E:/antivaty/dsys_v2/ornek/YÜRÜTME KURULU KARARLARI/YÜRÜTME KURULU KARARLARI/2026 YKK/5. TOPLANTI/Toplantı Gündem Maddeleri.docx';
const z = new AdmZip(p);
const xml = z.readAsText('word/document.xml');

function pt(x) {
  return x.replace(/<[^>]+>/g, '').replace(/&amp;/g, '&').trim();
}

const bodyMatch = xml.match(/<w:body>([\s\S]*)<\/w:body>/);
const body = bodyMatch ? bodyMatch[1] : '';
const paras = body.split(/<w:p[ >]/).slice(1, 40).map(pt).filter(Boolean);
paras.forEach((t, i) => console.log(i + 1, t.substring(0, 150)));
