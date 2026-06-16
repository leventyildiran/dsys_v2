/**
 * YK eşleştirme simülasyonu:
 * 1) Birim Word arşivinden bölüm bul
 * 2) OOXML birebir koru
 * 3) Ana toplantı karar Word'ü oluştur
 *
 * node simulate_yk_eslestirme.js [birim] [tur]
 * Örn: node simulate_yk_eslestirme.js UBATAM
 */

const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');

const CIKTI = path.join(__dirname, 'ornek', 'cikti_sablonlar');
const SIM_OUT = path.join(__dirname, 'ornek', 'simulasyon_cikti');
const BASE_KARAR = path.join(__dirname, 'assets', 'templates', 'karar_sablonu.docx');
const BIRIM = (process.argv[2] || 'UBATAM').toUpperCase();

// ── OOXML utils (import script ile aynı) ───────────────────────

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
  let depth = 0, pos = start;
  while (pos < xml.length) {
    const nextOpen = findTagOpen(xml, tag, pos);
    const nextClose = xml.indexOf(closeTag, pos);
    if (nextClose === -1) return null;
    if (nextOpen !== -1 && nextOpen < nextClose) { depth++; pos = nextOpen + openTag.length; }
    else { depth--; pos = nextClose + closeTag.length; if (depth === 0) return { xml: xml.slice(start, pos), end: pos }; }
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
  return pXml.replace(/<[^>]+>/g, '').replace(/&amp;/g, '&').replace(/\s+/g, ' ').trim();
}

function isSignatureTable(block) {
  if (block.type !== 'w:tbl') return false;
  const t = paraText(block.xml).toLowerCase();
  return t.includes('sıra no') && t.includes('görevi');
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
    for (let j = start; j < end; j++) { if (isSignatureTable(blocks[j])) { end = j; break; } }
    const secBlocks = blocks.slice(start, end);
    sections.push({
      baslik: paraText(secBlocks[0].xml),
      blocks: secBlocks,
      plainText: secBlocks.filter(b => b.type === 'w:p').map(b => paraText(b.xml)).join(' '),
      tableCount: secBlocks.filter(b => b.type === 'w:tbl').length,
    });
  }
  return sections;
}

function readSections(docxPath) {
  const z = new AdmZip(docxPath);
  const xml = z.readAsText('word/document.xml');
  const body = xml.match(/<w:body>([\s\S]*)<\/w:body>/)[1];
  return splitKararSections(extractBodyBlocks(body));
}

function detectTur(text) {
  const l = text.toLowerCase();
  if (l.includes('bütçe aktar') || l.includes('butce aktar')) return 'butce_aktarim';
  if (l.includes('danışman') || l.includes('danisman')) return 'danismanlik';
  if (l.includes('kurs ücret') || l.includes('katkı pay')) return 'kurs_ucreti';
  if (l.includes('diş hekim') || l.includes('ek ödeme')) return 'dis_hekimligi';
  return 'diger';
}

function scoreSection(section, pdfText, tur) {
  let score = 0;
  const secLower = section.plainText.toLowerCase();
  const pdfLower = pdfText.toLowerCase();
  if (detectTur(secLower) === tur) score += 15;
  if (section.tableCount > 0 && pdfLower.includes('tablo')) score += 10;
  const words = pdfLower.split(/\s+/).filter(w => w.length > 5);
  for (const w of words) { if (secLower.includes(w)) score += 2; }
  return score;
}

function findBestSection(sections, pdfText) {
  const tur = detectTur(pdfText);
  let best = sections[0], bestScore = -1;
  for (const s of sections) {
    const sc = scoreSection(s, pdfText, tur);
    if (sc > bestScore) { bestScore = sc; best = s; }
  }
  return { section: best, score: bestScore, tur };
}

function buildAnaKararDocx(kararSections, toplantiNo) {
  const z = new AdmZip(BASE_KARAR);
  const originalXml = z.readAsText('word/document.xml');
  const sectPr = (originalXml.match(/<w:sectPr\b[^>]*>[\s\S]*?<\/w:sectPr>/) || [''])[0];
  const docOpen = (originalXml.match(/<w:document\b[^>]*>/) || ['<w:document>'])[0];

  const PAGE_BREAK = '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
  const bodyParts = [];

  // Toplantı başlığı
  bodyParts.push(`<w:p><w:r><w:t>TOPLANTI SAYISI: ${toplantiNo}</w:t></w:r></w:p>`);
  bodyParts.push(`<w:p><w:r><w:t>KARAR TARİHİ: 07.06.2026</w:t></w:r></w:p>`);
  bodyParts.push(`<w:p><w:r><w:t>Uşak Üniversitesi Döner Sermaye Yürütme Kurulu ... gündem maddeleri görüşülerek aşağıdaki kararlar alındı.</w:t></w:r></w:p>`);

  kararSections.forEach((sec, idx) => {
    if (idx > 0) bodyParts.push(PAGE_BREAK);
    bodyParts.push(...sec.blocks.map(b => b.xml));
  });

  // İmza tablosu (kısaltılmış)
  bodyParts.push(`<w:p><w:r><w:t>Katılanların oy birliği ile karar verildi.</w:t></w:r></w:p>`);
  if (sectPr) bodyParts.push(sectPr);

  const finalXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
${docOpen}
  <w:body>
    ${bodyParts.join('\n    ')}
  </w:body>
</w:document>`;

  z.updateFile('word/document.xml', Buffer.from(finalXml, 'utf8'));
  return z.toBuffer();
}

// ── Simülasyon senaryosu ───────────────────────────────────────

function main() {
  console.log('═══════════════════════════════════════════════════');
  console.log('  YK EŞLEŞTİRME SİMÜLASYONU');
  console.log('═══════════════════════════════════════════════════\n');

  const arsivPath = path.join(CIKTI, `${BIRIM}_YK_Karar_Arsivi.docx`);
  if (!fs.existsSync(arsivPath)) {
    console.error(`Arşiv bulunamadı: ${arsivPath}`);
    process.exit(1);
  }

  const sections = readSections(arsivPath);
  console.log(`📁 Birim arşivi: ${BIRIM}_YK_Karar_Arsivi.docx`);
  console.log(`   Toplam bölüm: ${sections.length}`);
  console.log(`   Tablolu bölüm: ${sections.filter(s => s.tableCount > 0).length}\n`);

  // ── Senaryo 1: UBATAM bütçe aktarım PDF'i simüle et ──────────
  const tabloluSection = sections.find(s => s.tableCount > 0 && s.plainText.toLowerCase().includes('bütçe'));
  const ornekSection = tabloluSection || sections.find(s => s.tableCount > 0) || sections[0];

  const simulatedPdfText = `
    ${BIRIM} Müdürlüğü
    07.06.2026 tarih E-999888 sayılı yazı
    bütçe aktarımı talebi
    2026 yılı ödenek aktarımı
    tablo verileri ekte
    ${ornekSection.plainText.substring(0, 300)}
  `;

  console.log('── ADIM 1: Birim PDF yüklendi (simüle) ──');
  console.log(`   Birim: ${BIRIM}`);
  console.log(`   PDF metin uzunluğu: ${simulatedPdfText.length} karakter`);
  console.log(`   Tespit edilen tür: ${detectTur(simulatedPdfText)}\n`);

  console.log('── ADIM 2: Word arşivinde bölüm aranıyor ──');
  const { section, score, tur } = findBestSection(sections, simulatedPdfText);
  console.log(`   ✓ Eşleşen bölüm: ${section.baslik}`);
  console.log(`   Skor: ${score} | Tablo sayısı: ${section.tableCount}`);
  console.log(`   OOXML blok sayısı: ${section.blocks.length} (tablolara dokunulmadı)\n`);

  // Tablo renk kontrolü
  const shdCount = section.blocks.filter(b => b.type === 'w:tbl').reduce((acc, t) => {
    return acc + (t.xml.match(/w:shd/g) || []).length;
  }, 0);
  console.log('── ADIM 3: Tablo birebir kontrolü ──');
  console.log(`   w:shd (renk) hücre sayısı: ${shdCount}`);
  console.log(`   Tablo XML uzunluğu: ${section.blocks.filter(b => b.type === 'w:tbl').map(b => b.xml.length).join(' + ') || '0'} byte\n`);

  // ── Senaryo 2: 3 birimden karar birleştir ────────────────────
  console.log('── ADIM 4: Ana toplantı kararı oluşturuluyor ──');
  const birimler = ['UBATAM', 'USEM', 'DTS'].filter(b => fs.existsSync(path.join(CIKTI, `${b}_YK_Karar_Arsivi.docx`)));
  const eslesenKararlar = [];

  for (const b of birimler) {
    const secs = readSections(path.join(CIKTI, `${b}_YK_Karar_Arsivi.docx`));
    const pdfSim = `${b} müdürlüğü bütçe aktarım talebi 07.06.2026 E-123456`;
    const match = findBestSection(secs, pdfSim);
    eslesenKararlar.push(match.section);
    console.log(`   ${b}: ${match.section.baslik} (skor ${match.score}, ${match.section.tableCount} tablo)`);
  }

  fs.mkdirSync(SIM_OUT, { recursive: true });
  const outPath = path.join(SIM_OUT, `Simulasyon_Toplanti_2026_06.docx`);
  fs.writeFileSync(outPath, buildAnaKararDocx(eslesenKararlar, '2026/06'));

  const outSize = (fs.statSync(outPath).size / 1024).toFixed(1);
  console.log(`\n── ADIM 5: Çıktı ──`);
  console.log(`   ✓ Ana karar Word: ${outPath}`);
  console.log(`   Boyut: ${outSize} KB | ${eslesenKararlar.length} birim kararı birleştirildi`);
  console.log('\n═══════════════════════════════════════════════════');
  console.log('  SİMÜLASYON TAMAMLANDI');
  console.log('═══════════════════════════════════════════════════');
}

main();
