const AdmZip = require('adm-zip');

function findTagOpen(xml, tag, fromIndex = 0) {
  const prefix = `<${tag}`;
  let idx = fromIndex;
  while (idx < xml.length) {
    idx = xml.indexOf(prefix, idx);
    if (idx === -1) return -1;
    const next = xml[idx + prefix.length];
    if (next === '>' || next === ' ' || next === '/') return idx;
    idx += prefix.length;
  }
  return -1;
}

function extractElement(xml, tag, fromIndex = 0) {
  const openTag = `<${tag}`;
  const closeTag = `</${tag}>`;
  const start = findTagOpen(xml, tag, fromIndex);
  if (start === -1) return null;

  let depth = 0;
  let pos = start;
  while (pos < xml.length) {
    const nextOpen = findTagOpen(xml, tag, pos);
    const nextClose = xml.indexOf(closeTag, pos);
    if (nextClose === -1) return null;
    if (nextOpen !== -1 && nextOpen < nextClose) {
      depth++;
      pos = nextOpen + openTag.length;
    } else {
      depth--;
      pos = nextClose + closeTag.length;
      if (depth === 0) {
        return { xml: xml.slice(start, pos), end: pos };
      }
    }
  }
  return null;
}

function extractBodyBlocks(bodyInner) {
  const blocks = [];
  let i = 0;
  while (i < bodyInner.length) {
    while (i < bodyInner.length && bodyInner[i] !== '<') i++;
    if (i >= bodyInner.length) break;
    if (bodyInner.slice(i).startsWith('<w:sectPr')) break;

    let tag = null;
    if (bodyInner.slice(i).match(/^<w:p[ >\/]/)) tag = 'w:p';
    else if (bodyInner.slice(i).match(/^<w:tbl[ >\/]/)) tag = 'w:tbl';
    else {
      i++;
      continue;
    }

    const el = extractElement(bodyInner, tag, i);
    if (!el) break;
    blocks.push({ type: tag, xml: el.xml });
    i = el.end;
  }
  return blocks;
}

function paraText(pXml) {
  return pXml
    .replace(/<w:tab\/>/g, '\t')
    .replace(/<w:br\/?>/g, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/\s+/g, ' ')
    .trim();
}

const p = 'E:/antivaty/dsys_v2/ornek/5Yürütme Kurulu Kararları.docx';
const z = new AdmZip(p);
const xml = z.readAsText('word/document.xml');
const bodyMatch = xml.match(/<w:body>([\s\S]*)<\/w:body>/);
console.log('body found', !!bodyMatch, 'len', bodyMatch ? bodyMatch[1].length : 0);
console.log('first tag at', bodyMatch ? bodyMatch[1].indexOf('<w:p') : -1);
const blocks = extractBodyBlocks(bodyMatch[1]);

console.log('blocks', blocks.length);
console.log('tables', blocks.filter((b) => b.type === 'w:tbl').length);

const kararIdx = [];
blocks.forEach((b, idx) => {
  if (b.type === 'w:p' && /^KARAR\s+20\d{2}\/\d+/i.test(paraText(b.xml))) {
    kararIdx.push(idx);
  }
});
console.log('karar sections', kararIdx.length);

for (let s = 0; s < Math.min(3, kararIdx.length); s++) {
  const start = kararIdx[s];
  const end = s + 1 < kararIdx.length ? kararIdx[s + 1] : blocks.length;
  const section = blocks.slice(start, end);
  const texts = section.filter((b) => b.type === 'w:p').map((b) => paraText(b.xml)).filter(Boolean);
  console.log('\n--- Section', s + 1, 'blocks', section.length, 'tables', section.filter((b) => b.type === 'w:tbl').length);
  console.log('First:', texts[0]);
  console.log('Second:', (texts[1] || '').substring(0, 100));
}
