const xlsx = require('xlsx');
const fs = require('fs');
const path = require('path');

const root = path.join(__dirname, 'ornek', 'FATURA KESİM');

function walk(dir, acc = []) {
  if (!fs.existsSync(dir)) return acc;
  for (const name of fs.readdirSync(dir)) {
    const full = path.join(dir, name);
    const st = fs.statSync(full);
    if (st.isDirectory()) walk(full, acc);
    else if (/\.(xls|xlsx)$/i.test(name)) acc.push(full);
  }
  return acc;
}

function rel(p) {
  return path.relative(root, p).replace(/\\/g, '/');
}

function birimFromPath(p) {
  const parts = rel(p).split('/');
  return parts.find((x) => /USEM|TÖMER|TOMER|UBATAM|DTS|TADAUM/i.test(x)) || parts[0] || '?';
}

function summarizeSheet(rows, maxRows = 12) {
  const lines = [];
  for (let i = 0; i < Math.min(rows.length, maxRows); i++) {
    const row = rows[i];
    if (!row || !row.some((c) => c != null && String(c).trim() !== '')) continue;
    lines.push(`R${i}: ${row.map((c) => (c == null ? '' : String(c))).join(' | ')}`);
  }
  return lines.join('\n');
}

const files = walk(root);
let out = `Toplam ${files.length} Excel dosyası\n\n`;

const byBirim = {};
for (const f of files) {
  const b = birimFromPath(f);
  (byBirim[b] = byBirim[b] || []).push(f);
}

for (const [birim, list] of Object.entries(byBirim).sort()) {
  out += `\n${'='.repeat(60)}\nBİRİM: ${birim} (${list.length} dosya)\n${'='.repeat(60)}\n`;
  for (const file of list.slice(0, 5)) {
    out += `\n--- ${rel(file)} ---\n`;
    try {
      const wb = xlsx.readFile(file);
      for (const sheet of wb.SheetNames) {
        const rows = xlsx.utils.sheet_to_json(wb.Sheets[sheet], { header: 1 });
        out += `\n[SAYFA: ${sheet}] (${rows.length} satır)\n`;
        out += summarizeSheet(rows) + '\n';
      }
    } catch (e) {
      out += `HATA: ${e.message}\n`;
    }
  }
  if (list.length > 5) out += `\n... ve ${list.length - 5} dosya daha\n`;
}

const outPath = path.join(__dirname, 'fatura_birim_analiz.txt');
fs.writeFileSync(outPath, out, 'utf8');
console.log('Yazıldı:', outPath);
