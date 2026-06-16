/**
 * Tüm birim YK arşivlerini test eder ve ana karar birleştirmesini simüle eder.
 *
 * node test_tum_birimler.js
 *
 * Çıktı: ornek/simulasyon_cikti/tum_birimler_raporu.json
 *        ornek/simulasyon_cikti/Tum_Birimler_Toplanti_2026_06.docx
 */

const fs = require('fs');
const path = require('path');
const AdmZip = require('adm-zip');

const CIKTI = path.join(__dirname, 'ornek', 'cikti_sablonlar');
const SIM_OUT = path.join(__dirname, 'ornek', 'simulasyon_cikti');
const BASE_KARAR = path.join(__dirname, 'assets', 'templates', 'karar_sablonu.docx');
const MIN_GUVEN_SKORU = 12;

const BEKLENEN_BIRIMLER = [
  'UBATAM', 'USEM', 'DTS', 'TADAUM', 'ADUM', 'TÖMER', 'Diş Hekimliği',
];

// ── OOXML utils ─────────────────────────────────────────────────

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
  const m = xml.match(/<w:body>([\s\S]*)<\/w:body>/);
  if (!m) return [];
  return splitKararSections(extractBodyBlocks(m[1]));
}

function analyzeDocx(filePath) {
  if (!fs.existsSync(filePath)) return null;
  const z = new AdmZip(filePath);
  const xml = z.readAsText('word/document.xml');
  return {
    tblCount: (xml.match(/<w:tbl>/g) || []).length,
    shdCount: (xml.match(/w:shd/g) || []).length,
    trCount: (xml.match(/<w:tr[ >/]/g) || []).length,
    kararCount: (xml.match(/KARAR\s+20\d{2}\/\d+/gi) || []).length,
    sizeKB: (fs.statSync(filePath).size / 1024).toFixed(1),
  };
}

function detectTur(text) {
  const l = text.toLowerCase();
  if (l.includes('bütçe aktar') || l.includes('butce aktar')) return 'butce_aktarim';
  if (l.includes('danışman') || l.includes('danisman')) return 'danismanlik';
  if (l.includes('kurs ücret') || l.includes('katkı pay')) return 'kurs_ucreti';
  if (l.includes('diş hekim') || l.includes('ek ödeme')) return 'dis_hekimligi';
  if (l.includes('fiyat tarif')) return 'fiyat_tarifesi';
  return 'diger';
}

function onemliKelimeler(text) {
  return text.toLowerCase().split(/\s+/).filter(w => w.length > 5);
}

function bolumSkoru(section, pdfKelimeSet, pdfTabloSatir, pdfKolonSayisi, tur) {
  let score = 0;
  const secLower = section.plainText.toLowerCase();
  const secTur = detectTur(secLower);
  if (secTur === tur) score += 15;
  if (pdfTabloSatir > 0 && section.tableCount > 0) score += 10;
  const secKelimeler = new Set(onemliKelimeler(secLower));
  for (const w of pdfKelimeSet) { if (secKelimeler.has(w)) score += 2; }
  if (section.tableCount > 0) score += 5;
  return score;
}

function findBestSection(sections, pdfText) {
  const tur = detectTur(pdfText);
  const pdfKelimeSet = new Set(onemliKelimeler(pdfText.toLowerCase()));
  let best = sections[0], bestScore = -1;
  for (const s of sections) {
    const sc = bolumSkoru(s, pdfKelimeSet, 1, 4, tur);
    if (sc > bestScore) { bestScore = sc; best = s; }
  }
  return { section: best, score: bestScore, tur };
}

function buildPdfSim(birim, section) {
  const plain = section.plainText.toLowerCase();
  const tur = detectTur(plain);
  const parts = [
    `${birim} Müdürlüğü`,
    '07.06.2026 tarih E-999888 sayılı yazı',
  ];
  if (tur === 'butce_aktarim') parts.push('bütçe aktarımı talebi 2026 yılı ödenek aktarımı');
  else if (tur === 'danismanlik') parts.push('danışmanlık hizmeti ödemesi hakediş');
  else if (tur === 'kurs_ucreti') parts.push('kurs ücreti dağıtımı katkı payı');
  else if (tur === 'dis_hekimligi') parts.push('diş hekimliği ek ödeme puantaj');
  else parts.push('yürütme kurulu kararı talebi');
  parts.push(section.plainText.substring(0, 400));
  return parts.join('\n');
}

function buildAnaKararDocx(kararSections, toplantiNo) {
  const z = new AdmZip(BASE_KARAR);
  const originalXml = z.readAsText('word/document.xml');
  const sectPr = (originalXml.match(/<w:sectPr\b[^>]*>[\s\S]*?<\/w:sectPr>/) || [''])[0];
  const docOpen = (originalXml.match(/<w:document\b[^>]*>/) || ['<w:document>'])[0];
  const PAGE_BREAK = '<w:p><w:r><w:br w:type="page"/></w:r></w:p>';
  const bodyParts = [];
  bodyParts.push(`<w:p><w:r><w:t>TOPLANTI SAYISI: ${toplantiNo}</w:t></w:r></w:p>`);
  bodyParts.push(`<w:p><w:r><w:t>KARAR TARİHİ: 07.06.2026</w:t></w:r></w:p>`);
  bodyParts.push(`<w:p><w:r><w:t>Uşak Üniversitesi Döner Sermaye Yürütme Kurulu gündem maddeleri görüşülerek aşağıdaki kararlar alındı.</w:t></w:r></w:p>`);
  kararSections.forEach((sec, idx) => {
    if (idx > 0) bodyParts.push(PAGE_BREAK);
    bodyParts.push(...sec.blocks.map(b => b.xml));
  });
  bodyParts.push(`<w:p><w:r><w:t>Katılanların oy birliği ile karar verildi.</w:t></w:r></w:p>`);
  if (sectPr) bodyParts.push(sectPr);
  const finalXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n${docOpen}\n  <w:body>\n    ${bodyParts.join('\n    ')}\n  </w:body>\n</w:document>`;
  z.updateFile('word/document.xml', Buffer.from(finalXml, 'utf8'));
  return z.toBuffer();
}

// ── Birim testi ─────────────────────────────────────────────────

function testBirim(birimKey) {
  const kararPath = path.join(CIKTI, `${birimKey}_YK_Karar_Arsivi.docx`);
  const gundemPath = path.join(CIKTI, `${birimKey}_Gundem_Arsivi.docx`);
  const result = {
    birim: birimKey,
    gecerli: true,
    hatalar: [],
    uyarilar: [],
    kararArsivi: null,
    gundemArsivi: null,
    eslesme: null,
  };

  if (!fs.existsSync(kararPath)) {
    result.gecerli = false;
    result.hatalar.push(`Karar arşivi yok: ${birimKey}_YK_Karar_Arsivi.docx`);
    return result;
  }

  const kararInfo = analyzeDocx(kararPath);
  const sections = readSections(kararPath);

  result.kararArsivi = {
    ...kararInfo,
    bolumSayisi: sections.length,
    tabloluBolum: sections.filter(s => s.tableCount > 0).length,
  };

  if (sections.length === 0) {
    result.gecerli = false;
    result.hatalar.push('Arşivde KARAR bölümü bulunamadı');
  }

  if (kararInfo.tblCount === 0) {
    result.uyarilar.push('Arşivde tablo yok — tablolu karar türleri etkilenebilir');
  }

  if (kararInfo.shdCount === 0 && kararInfo.tblCount > 0) {
    result.uyarilar.push('Tablolarda w:shd (renk) bulunamadı');
  }

  // Gündem arşivi
  if (!fs.existsSync(gundemPath)) {
    result.gecerli = false;
    result.hatalar.push(`Gündem arşivi eksik: ${birimKey}_Gundem_Arsivi.docx`);
  } else {
    result.gundemArsivi = analyzeDocx(gundemPath);
  }

  // Eşleştirme: tablolu + türe göre en iyi bölüm
  if (sections.length > 0) {
    const tablolu = sections.filter(s => s.tableCount > 0);
    const testSection = tablolu[0] || sections[0];
    const pdfSim = buildPdfSim(birimKey, testSection);
    const match = findBestSection(sections, pdfSim);

    const shdInMatch = match.section.blocks
      .filter(b => b.type === 'w:tbl')
      .reduce((acc, t) => acc + (t.xml.match(/w:shd/g) || []).length, 0);

    result.eslesme = {
      baslik: match.section.baslik,
      skor: match.score,
      tur: match.tur,
      tabloSayisi: match.section.tableCount,
      renkliHucre: shdInMatch,
      guvenilir: match.score >= MIN_GUVEN_SKORU,
    };

    if (match.score < MIN_GUVEN_SKORU) {
      result.gecerli = false;
      result.hatalar.push(`Eşleşme skoru düşük: ${match.score} (min ${MIN_GUVEN_SKORU})`);
    }

    if (testSection.tableCount > 0 && match.section.tableCount === 0) {
      result.gecerli = false;
      result.hatalar.push('Tablolu PDF simülasyonu tablosuz bölüme eşleşti');
    }

    result._matchedSection = match.section;
  }

  return result;
}

// ── Main ────────────────────────────────────────────────────────

function main() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('  TÜM BİRİMLER YK REGRESSION TEST');
  console.log('═══════════════════════════════════════════════════════\n');

  if (!fs.existsSync(CIKTI)) {
    console.error('ornek/cikti_sablonlar yok. Önce: node import_yk_sablonlar.js');
    process.exit(1);
  }

  const mevcutArsivler = fs.readdirSync(CIKTI)
    .filter(f => f.endsWith('_YK_Karar_Arsivi.docx'))
    .map(f => f.replace('_YK_Karar_Arsivi.docx', ''));

  const rapor = {
    tarih: new Date().toISOString(),
    minGuvenSkoru: MIN_GUVEN_SKORU,
    birimler: [],
    ozet: {},
  };

  let gecerliSayisi = 0;
  let hataliSayisi = 0;
  const birlesenKararlar = [];

  for (const birim of BEKLENEN_BIRIMLER) {
    console.log(`\n── ${birim} ──`);
    const sonuc = testBirim(birim);
    rapor.birimler.push(sonuc);

    if (sonuc.gecerli) {
      gecerliSayisi++;
      console.log(`  ✓ GEÇERLİ`);
      if (sonuc._matchedSection) birlesenKararlar.push(sonuc._matchedSection);
    } else {
      hataliSayisi++;
      console.log(`  ✗ HATALI`);
      sonuc.hatalar.forEach(h => console.log(`    HATA: ${h}`));
    }

    if (sonuc.kararArsivi) {
      console.log(`  Karar: ${sonuc.kararArsivi.bolumSayisi} bölüm, ${sonuc.kararArsivi.tblCount} tablo, ${sonuc.kararArsivi.shdCount} renkli hücre`);
    }
    if (sonuc.eslesme) {
      console.log(`  Eşleşme: "${sonuc.eslesme.baslik}" skor=${sonuc.eslesme.skor} tablo=${sonuc.eslesme.tabloSayisi}`);
    }
    sonuc.uyarilar.forEach(u => console.log(`  ⚠ ${u}`));
  }

  // Eksik beklenen birimler
  for (const b of BEKLENEN_BIRIMLER) {
    if (!mevcutArsivler.includes(b)) {
      console.log(`\n── ${b} ──`);
      console.log(`  ✗ ARŞİV DOSYASI YOK`);
      hataliSayisi++;
    }
  }

  // Ana karar birleştirme — yalnızca geçerli birimler
  fs.mkdirSync(SIM_OUT, { recursive: true });
  if (birlesenKararlar.length > 0 && fs.existsSync(BASE_KARAR)) {
    const outPath = path.join(SIM_OUT, 'Tum_Birimler_Toplanti_2026_06.docx');
    fs.writeFileSync(outPath, buildAnaKararDocx(birlesenKararlar, '2026/06'));
    rapor.birlestirme = {
      dosya: outPath,
      birimSayisi: birlesenKararlar.length,
      boyutKB: (fs.statSync(outPath).size / 1024).toFixed(1),
    };
    console.log(`\n── BİRLEŞTİRME ──`);
    console.log(`  ✓ ${birlesenKararlar.length} birim → ${outPath}`);
  }

  rapor.ozet = {
    toplam: BEKLENEN_BIRIMLER.length,
    gecerli: gecerliSayisi,
    hatali: hataliSayisi,
    birlestirilen: birlesenKararlar.length,
  };

  const raporPath = path.join(SIM_OUT, 'tum_birimler_raporu.json');
  fs.writeFileSync(raporPath, JSON.stringify(rapor, null, 2));
  console.log(`\n── ÖZET ──`);
  console.log(`  Geçerli: ${gecerliSayisi}/${BEKLENEN_BIRIMLER.length}`);
  console.log(`  Hatalı: ${hataliSayisi}`);
  console.log(`  Rapor: ${raporPath}`);
  console.log('═══════════════════════════════════════════════════════\n');

  process.exit(hataliSayisi > 0 ? 1 : 0);
}

main();
