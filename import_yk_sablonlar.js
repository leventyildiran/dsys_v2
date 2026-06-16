/**
 * ornek/ klasöründeki YK kararlarını birim birim analiz eder.
 * Her birim için TEK Word dosyası oluşturur (kararlar/gündemler alt alta, tablolar birebir).
 *
 * Kullanım:
 *   node import_yk_sablonlar.js              # ornek/cikti_sablonlar/ oluştur
 *   node import_yk_sablonlar.js --upload     # Firebase'e yükle
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const AdmZip = require('adm-zip');

const ORNEK_DIR = path.join(__dirname, 'ornek');
const CIKTI_DIR = path.join(__dirname, 'ornek', 'cikti_sablonlar');
const SKIP_DIRS = new Set(['cikti_sablonlar', 'simulasyon_cikti']);
const BASE_KARAR = path.join(__dirname, 'assets', 'templates', 'karar_sablonu.docx');
const BASE_GUNDEM = path.join(__dirname, 'assets', 'templates', 'gundem_sablonu.docx');
const UPLOAD = process.argv.includes('--upload');

// ── OOXML yardımcıları ──────────────────────────────────────────

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
      if (depth === 0) return { xml: xml.slice(start, pos), end: pos };
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
    else { i++; continue; }
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

function isSignatureTable(block) {
  if (block.type !== 'w:tbl') return false;
  const t = paraText(block.xml).toLowerCase();
  return t.includes('sıra no') && t.includes('görevi') && t.includes('imzası');
}

function splitKararSections(blocks) {
  const starts = [];
  blocks.forEach((b, idx) => {
    if (b.type === 'w:p' && /^KARAR\s+20\d{2}\/\d+/i.test(paraText(b.xml))) starts.push(idx);
  });
  const sections = [];
  for (let s = 0; s < starts.length; s++) {
    const start = starts[s];
    let end = s + 1 < starts.length ? starts[s + 1] : blocks.length;
    for (let j = start; j < end; j++) {
      if (isSignatureTable(blocks[j])) { end = j; break; }
    }
    sections.push({ blocks: blocks.slice(start, end), plainText: blocks.slice(start, end).filter(b => b.type === 'w:p').map(b => paraText(b.xml)).join(' ') });
  }
  return sections;
}

function splitGundemSections(blocks) {
  const starts = [];
  blocks.forEach((b, idx) => {
    if (b.type === 'w:p' && /^G[üu]ndem\s+\d+/i.test(paraText(b.xml))) starts.push(idx);
  });
  const sections = [];
  for (let s = 0; s < starts.length; s++) {
    const start = starts[s];
    const end = s + 1 < starts.length ? starts[s + 1] : blocks.length;
    sections.push({ blocks: blocks.slice(start, end), plainText: blocks.slice(start, end).filter(b => b.type === 'w:p').map(b => paraText(b.xml)).join(' ') });
  }
  return sections;
}

function readDocxBlocks(filePath) {
  if (!fs.existsSync(filePath) || filePath.includes('~$')) return [];
  try {
    const z = new AdmZip(filePath);
    const xml = z.readAsText('word/document.xml');
    const bodyMatch = xml.match(/<w:body>([\s\S]*)<\/w:body>/);
    if (!bodyMatch) return [];
    return extractBodyBlocks(bodyMatch[1]);
  } catch (e) {
    console.warn('  OKUNAMADI:', filePath, e.message);
    return [];
  }
}

// ── Birim eşleştirme ────────────────────────────────────────────

const BIRIM_KEYWORDS = [
  { key: 'UBATAM', id: 'Bfo5nLXUlpf9J2rl7Fq8', ad: 'UBATAM', keywords: ['bilimsel analiz', 'ubatam', 'tek. uyg'] },
  { key: 'USEM', id: 'aLr1bwm2M1p14KjnCpSf', ad: 'USEM', keywords: ['sürekli eğitim', 'usem'] },
  { key: 'DTS', id: 'qI3NiqtBINqj6gvzDgj8', ad: 'DTS', keywords: ['deri', 'tekstil', 'seramik', 'dts'] },
  { key: 'TADAUM', id: 'tdQTX1gs6FFx2uXibw39', ad: 'TADAUM', keywords: ['tarımsal ve doğa', 'tadaum'] },
  { key: 'ADUM', id: null, ad: 'ADUM', keywords: ['ağız ve diş sağlığı', 'adum'] },
  { key: 'TÖMER', id: null, ad: 'TÖMER', keywords: ['türkçe öğretimi', 'tömer', 'tomer'] },
  { key: 'Diş Hekimliği', id: 'N4UzFEc1vmsTpka8XEeY', ad: 'Diş Hekimliği', keywords: ['diş hekimliği fakültesi', 'diş hek. fak', 'diş hek fak', 'diş hekimliği', 'ortodonti', 'protez'] },
  { key: 'DSİM', id: 'bqv1J5dy9ldJZrUNnIpF', ad: 'DSİM', keywords: ['döner sermaye işletme', 'dsim'] },
  { key: 'UZEM', id: '8m40pBxUY1Kp9xu9WY9V', ad: 'UZEM', keywords: ['uzaktan eğitim', 'uzem'] },
];

function detectBirim(text, folderPath = '') {
  const lower = (text + ' ' + folderPath).toLowerCase().replace(/['']/g, "'");
  let best = null;
  let bestScore = 0;
  for (const b of BIRIM_KEYWORDS) {
    let score = 0;
    for (const kw of b.keywords) {
      if (lower.includes(kw.toLowerCase())) score += kw.length;
    }
    // Klasör adından ek puan (DTS/, UBATAM/ vb.)
    if (folderPath.toLowerCase().includes(b.key.toLowerCase())) score += 20;
    if (score > bestScore) { bestScore = score; best = b; }
  }
  return bestScore >= 5 ? best : null;
}

function sectionHash(section) {
  return crypto.createHash('md5').update(section.blocks.map(b => b.xml).join('')).digest('hex');
}

/** Tarih, karar no, evrak no gibi değişkenleri silerek içerik parmak izi üretir. */
function normalizeForDedup(text) {
  return text
    .toLowerCase()
    .replace(/[''´`]/g, "'")
    .replace(/karar\s+20\d{2}\/\d+/gi, '')
    .replace(/g[üu]ndem\s+\d+/gi, '')
    .replace(/\d{2}[./]\d{2}[./]\d{4}/g, '')
    .replace(/e-?\d[\d-]*/gi, '')
    .replace(/[\d.,]+\s*(?:tl|₺)?/gi, 'NUM')
    .replace(/num+/g, 'NUM')
    .replace(/\s+/g, ' ')
    .trim();
}

function tableStructureFingerprint(blocks) {
  return blocks
    .filter(b => b.type === 'w:tbl')
    .map(b => {
      const rows = b.xml.split(/<w:tr[ >]/).length - 1;
      const cells = (b.xml.match(/<w:tc[ >]/g) || []).length;
      const headers = [...b.xml.matchAll(/<w:t[^>]*>([\s\S]*?)<\/w:t>/g)]
        .slice(0, 20)
        .map(m => normalizeForDedup(m[1].replace(/&amp;/g, '&')))
        .filter(Boolean)
        .join('|');
      return `r${rows}c${cells}:${headers}`;
    })
    .join(';;');
}

function contentFingerprint(section) {
  const body = normalizeForDedup(section.plainText);
  const tbl = tableStructureFingerprint(section.blocks);
  return crypto.createHash('md5').update(`${body}||${tbl}`).digest('hex');
}

function sectionQuality(section) {
  const tables = section.blocks.filter(b => b.type === 'w:tbl').length;
  const shd = section.blocks.reduce((n, b) => n + (b.xml.match(/w:shd/g) || []).length, 0);
  return tables * 10000 + shd * 10 + section.plainText.length;
}

/** Aynı içerikli bölümü tekrar eklemez; daha zengin olanı (tablo/renk) tutar. */
function addUniqueSection(map, section, stats) {
  const fp = contentFingerprint(section);
  stats.total++;
  const existing = map.get(fp);
  if (existing) {
    stats.duplicates++;
    if (sectionQuality(section) > sectionQuality(existing)) {
      map.set(fp, section);
    }
    return;
  }
  map.set(fp, section);
}

// ── DOCX oluştur ────────────────────────────────────────────────

const PAGE_BREAK = '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';

function buildCombinedDocx(baseTemplatePath, allSections) {
  const z = new AdmZip(baseTemplatePath);
  const originalXml = z.readAsText('word/document.xml');

  const sectPrMatch = originalXml.match(/<w:sectPr\b[^>]*>[\s\S]*?<\/w:sectPr>/);
  const sectPrXml = sectPrMatch ? sectPrMatch[0] : '';
  const documentOpenMatch = originalXml.match(/<w:document\b[^>]*>/);
  const documentOpenXml = documentOpenMatch ? documentOpenMatch[0] : '<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">';

  const bodyParts = [];
  allSections.forEach((section, idx) => {
    if (idx > 0) bodyParts.push(PAGE_BREAK);
    bodyParts.push(...section.blocks.map(b => b.xml));
  });
  if (sectPrXml) bodyParts.push(sectPrXml);

  const finalDocXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
${documentOpenXml}
  <w:body>
    ${bodyParts.join('\n    ')}
  </w:body>
</w:document>`;

  z.updateFile('word/document.xml', Buffer.from(finalDocXml, 'utf8'));
  return z.toBuffer();
}

// ── Dosya tarama ────────────────────────────────────────────────

function walkDocx(dir, results = []) {
  if (!fs.existsSync(dir)) return results;
  for (const entry of fs.readdirSync(dir)) {
    const full = path.join(dir, entry);
    if (entry.startsWith('~$')) continue;
    if (SKIP_DIRS.has(entry)) continue;
    if (fs.statSync(full).isDirectory()) {
      walkDocx(full, results);
    } else if (/\.docx$/i.test(entry) && !/_YK_Karar_Arsivi|_Gundem_Arsivi/i.test(entry)) {
      results.push(full);
    }
  }
  return results;
}

function classifyFile(filePath) {
  const name = path.basename(filePath).toLowerCase();
  const folder = path.dirname(filePath).toLowerCase();
  if (/gündem|gundem/.test(name) || folder.includes('gündem')) return 'gundem';
  if (/karar/.test(name) || folder.includes('karar')) return 'karar';
  return null;
}

// ── Ana işlem ───────────────────────────────────────────────────

async function main() {
  console.log('YK şablon import başlıyor...');
  if (!fs.existsSync(BASE_KARAR)) {
    console.error('Karar şablonu bulunamadı:', BASE_KARAR);
    process.exit(1);
  }

  const allDocx = walkDocx(ORNEK_DIR);
  console.log(`Toplam ${allDocx.length} docx dosyası taranıyor...`);

  const kararByBirim = {};
  const gundemByBirim = {};
  const dedupStats = { karar: { total: 0, duplicates: 0 }, gundem: { total: 0, duplicates: 0 } };

  for (const filePath of allDocx) {
    const type = classifyFile(filePath);
    if (!type) continue;

    const blocks = readDocxBlocks(filePath);
    if (blocks.length === 0) continue;

    const sections = type === 'karar' ? splitKararSections(blocks) : splitGundemSections(blocks);
    if (sections.length === 0) continue;

    const folderPath = path.dirname(filePath);
    for (const section of sections) {
      const birim = detectBirim(section.plainText, folderPath);
      if (!birim) continue;

      const store = type === 'karar' ? kararByBirim : gundemByBirim;
      const stats = dedupStats[type === 'karar' ? 'karar' : 'gundem'];
      if (!store[birim.key]) store[birim.key] = { birim, sections: new Map() };
      addUniqueSection(store[birim.key].sections, section, stats);
    }
  }

  console.log(`Tekilleştirme: karar ${dedupStats.karar.total} taranan → ${dedupStats.karar.duplicates} mükerrer atlandı`);
  console.log(`Tekilleştirme: gündem ${dedupStats.gundem.total} taranan → ${dedupStats.gundem.duplicates} mükerrer atlandı`);

  // Karar arşivi olan birimlerde gündem yoksa karar başlıklarından türet
  function gundemFromKararSection(kararSection, index) {
    const raw = kararSection.plainText.replace(/^KARAR\s+20\d{2}\/\d+/i, '').trim();
    const ozet = raw.substring(0, 150) || `Madde ${index + 1}`;
    const baslik = `Gündem ${String(index + 1).padStart(2, '0')}: ${ozet}`;
    const escaped = baslik.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    const pXml = `<w:p><w:r><w:rPr><w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman"/></w:rPr><w:t xml:space="preserve">${escaped}</w:t></w:r></w:p>`;
    return { blocks: [{ type: 'w:p', xml: pXml }], plainText: baslik };
  }

  for (const [key, kararData] of Object.entries(kararByBirim)) {
    if (gundemByBirim[key]) continue;
    const kararSections = [...kararData.sections.values()];
    if (kararSections.length === 0) continue;
    const gundemSections = new Map();
    kararSections.slice(0, 40).forEach((sec, i) => {
      addUniqueSection(gundemSections, gundemFromKararSection(sec, i), dedupStats.gundem);
    });
    gundemByBirim[key] = { birim: kararData.birim, sections: gundemSections };
    console.log(`  ↳ ${key}: gündem arşivi karar bölümlerinden türetildi (${gundemSections.size} madde)`);
  }

  fs.mkdirSync(CIKTI_DIR, { recursive: true });

  const uploaded = [];

  for (const [type, byBirim, baseTemplate] of [
    ['yk_karar', kararByBirim, BASE_KARAR],
    ['gundem', gundemByBirim, BASE_GUNDEM],
  ]) {
    for (const [key, data] of Object.entries(byBirim)) {
      const sections = [...data.sections.values()];
      if (sections.length === 0) continue;

      const fileName = `${key}_${type === 'yk_karar' ? 'YK_Karar_Arsivi' : 'Gundem_Arsivi'}.docx`;
      const outPath = path.join(CIKTI_DIR, fileName);
      const buffer = buildCombinedDocx(baseTemplate, sections);
      fs.writeFileSync(outPath, buffer);

      console.log(`✓ ${key}: ${sections.length} benzersiz bölüm → ${fileName} (${(buffer.length / 1024).toFixed(0)} KB)`);

      uploaded.push({
        fileName,
        filePath: outPath,
        tur: type,
        birimId: data.birim.id,
        birimAd: data.birim.ad,
        sablonAdi: `${type === 'yk_karar' ? 'YK Karar Arşivi' : 'Gündem Arşivi'} - ${data.birim.ad}`,
        sectionCount: sections.length,
      });
    }
  }

  console.log(`\n${uploaded.length} birim şablonu oluşturuldu → ${CIKTI_DIR}`);

  if (UPLOAD) {
    await uploadToFirebase(uploaded);
  } else {
    console.log('\nFirebase\'e yüklemek için: node import_yk_sablonlar.js --upload');
  }
}

async function uploadToFirebase(items) {
  const admin = require('firebase-admin');
  const { randomUUID } = require('crypto');
  const serviceAccount = require('./dsys-44b8e-firebase-adminsdk-fbsvc-6c70b81940.json');

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      storageBucket: 'dsys-44b8e.firebasestorage.app',
    });
  }

  const db = admin.firestore();
  const bucket = admin.storage().bucket();

  for (const item of items) {
    const existing = await db.collection('sistemSablonlari')
      .where('tur', '==', item.tur)
      .where('birimAd', '==', item.birimAd)
      .get();

    for (const doc of existing.docs) {
      await doc.ref.delete();
      console.log(`  Eski şablon silindi: ${doc.data().sablonAdi}`);
    }

    const storagePath = `templates/${Date.now()}_${item.fileName}`;
    const token = randomUUID();
    await bucket.upload(item.filePath, {
      destination: storagePath,
      metadata: {
        contentType: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        metadata: { firebaseStorageDownloadTokens: token },
      },
    });

    const encoded = encodeURIComponent(storagePath);
    const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encoded}?alt=media&token=${token}`;

    await db.collection('sistemSablonlari').add({
      sablonAdi: item.sablonAdi,
      dosyaUzantisi: '.docx',
      dosyaUrl: url,
      tur: item.tur,
      birimId: item.birimId || null,
      birimAd: item.birimAd,
      eklenmeTarihi: admin.firestore.FieldValue.serverTimestamp(),
      bolumSayisi: item.sectionCount,
    });

    console.log(`↑ Firebase: ${item.sablonAdi} (${item.sectionCount} bölüm)`);
  }

  console.log('\nTüm şablonlar Firebase\'e yüklendi.');
}

main().catch(err => { console.error(err); process.exit(1); });
