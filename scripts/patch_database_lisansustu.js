const fs = require('fs');

const detailedSolutions = JSON.parse(fs.readFileSync('e:/antivaty/G-revde-Y-kselme/scripts/lisansustu_tum_cozumler_detayli.json', 'utf8'));

// Build lookup map by question text or ID
const fixMapById = new Map();
const fixMapByText = new Map();

detailedSolutions.forEach(s => {
  if (s.id) fixMapById.set(s.id, s);
  if (s.question) fixMapByText.set(s.question.trim().replace(/\s+/g, ' '), s);
});

let totalUpdated = 0;

function updateQuestionsInObj(obj) {
  if (!obj) return;
  if (Array.isArray(obj)) {
    obj.forEach(item => updateQuestionsInObj(item));
    return;
  }
  if (typeof obj === 'object') {
    const qText = (obj.question || obj.soru || obj.text || obj.questionText || '').trim().replace(/\s+/g, ' ');
    const qId = obj.id || obj.questionId;
    
    let match = null;
    if (qId && fixMapById.has(qId)) match = fixMapById.get(qId);
    else if (qText && fixMapByText.has(qText)) match = fixMapByText.get(qText);
    
    if (match) {
      const oldAns = obj.correctAnswer || obj.dogruCevap || obj.answer || obj.correctOption;
      if (oldAns !== match.verifiedAnswer) {
        if (obj.correctAnswer !== undefined) obj.correctAnswer = match.verifiedAnswer;
        if (obj.dogruCevap !== undefined) obj.dogruCevap = match.verifiedAnswer;
        if (obj.answer !== undefined) obj.answer = match.verifiedAnswer;
        if (obj.correctOption !== undefined) obj.correctOption = match.verifiedAnswer;
        
        // Also update explanation if needed
        if (match.rationale && (!obj.explanation || obj.explanation.length < 10)) {
          obj.explanation = match.rationale;
        }
        totalUpdated++;
      }
    }
    
    for (const k of Object.keys(obj)) {
      if (typeof obj[k] === 'object') updateQuestionsInObj(obj[k]);
    }
  }
}

// 1. Update local_db.json
const localDbPath = 'e:/antivaty/G-revde-Y-kselme/scripts/local_db.json';
if (fs.existsSync(localDbPath)) {
  console.log('local_db.json güncelleniyor...');
  const db = JSON.parse(fs.readFileSync(localDbPath, 'utf8'));
  updateQuestionsInObj(db);
  fs.writeFileSync(localDbPath, JSON.stringify(db, null, 2), 'utf8');
  console.log('local_db.json güncellendi.');
}

// 2. Update deneme files
const denemeDir = 'e:/antivaty/G-revde-Y-kselme/scripts/denemeler';
if (fs.existsSync(denemeDir)) {
  const dirs = fs.readdirSync(denemeDir);
  for (const d of dirs) {
    const fullD = `${denemeDir}/${d}`;
    if (fs.statSync(fullD).isDirectory()) {
      fs.readdirSync(fullD).forEach(f => {
        if (f.endsWith('.json')) {
          const filePath = `${fullD}/${f}`;
          try {
            const data = JSON.parse(fs.readFileSync(filePath, 'utf8'));
            updateQuestionsInObj(data);
            fs.writeFileSync(filePath, JSON.stringify(data, null, 2), 'utf8');
          } catch (e) {}
        }
      });
    }
  }
}

console.log(`Veritabanındaki toplam düzeltilen/güncellenen soru kaydı sayısı: ${totalUpdated}`);
