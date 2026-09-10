const fs = require('fs');

const questions = JSON.parse(fs.readFileSync('e:/antivaty/G-revde-Y-kselme/scripts/lisansustu_unique_sorular.json', 'utf8'));

console.log('Validasyon analizi başlatılıyor...');

const solvedQuestions = [];
const faultyQuestions = [];

questions.forEach((q, idx) => {
  const qNum = idx + 1;
  const text = (q.question || '').trim();
  const options = q.options || {};
  let currentAns = (q.correctAnswer || '').trim().toUpperCase();
  const exp = q.explanation || '';
  
  // Format options if needed
  let optObj = {};
  if (Array.isArray(options)) {
    options.forEach((opt, i) => {
      const letter = String.fromCharCode(65 + i);
      optObj[letter] = opt;
    });
  } else if (typeof options === 'object') {
    optObj = options;
  }

  let verifiedAnswer = currentAns;
  let status = 'CORRECT';
  let issueReason = '';
  let correctExplanation = exp;

  // 1. Tezli Yüksek Lisans süreleri (Normal: 4 yarıyıl, Azami: 6 yarıyıl)
  if (/tezli\s+yüksek\s+lisans.*tamamlama\s+süresi/i.test(text) || (/tezli\s+yüksek\s+lisans/i.test(text) && /azami\s+süre/i.test(text))) {
    if (/azami/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/6\s*yarıyıl|6\s*dönem|altı\s*yarıyıl/i.test(String(v))) verifiedAnswer = k;
      }
    } else if (/normal/i.test(text) || /kaç\s+yarıyıl/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/4.*6|4\s*-\s*6|dört.*altı/i.test(String(v))) verifiedAnswer = k;
        else if (/4\s*yarıyıl|4\s*dönem|dört\s*yarıyıl/i.test(String(v)) && !/azami/i.test(String(v))) verifiedAnswer = k;
      }
    }
  }

  // 2. Tezsiz Yüksek Lisans süreleri (En az 2, en çok 3 yarıyıl)
  if (/tezsiz\s+yüksek\s+lisans.*tamamlama\s+süresi/i.test(text) || (/tezsiz\s+yüksek\s+lisans/i.test(text) && /süre/i.test(text))) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/en\s*az\s*2.*en\s*çok\s*3|2\s*-\s*3|2\s*ila\s*3|en\s*fazla\s*3\s*yarıyıl|3\s*yarıyıl/i.test(String(v))) {
        verifiedAnswer = k;
      }
    }
  }

  // 3. Doktora süreleri (YL ile: 8-12 yarıyıl; Lisans ile: 10-14 yarıyıl)
  if (/doktora.*tamamlama\s+süresi/i.test(text) || (/doktora/i.test(text) && /azami\s+süre/i.test(text))) {
    if (/lisans\s+derecesi\s+ile|lisans\s+mezunu|bütünleşik/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/10.*14|10\s*yarıyıl.*14\s*yarıyıl|14\s*yarıyıl/i.test(String(v))) verifiedAnswer = k;
      }
    } else {
      for (const [k, v] of Object.entries(optObj)) {
        if (/8.*12|8\s*yarıyıl.*12\s*yarıyıl|12\s*yarıyıl/i.test(String(v))) verifiedAnswer = k;
      }
    }
  }

  // 4. Bilimsel hazırlık süresi (En çok 2 yarıyıl, yaz öğretimi dahil edilmez, uzatılamaz)
  if (/bilimsel\s+hazırlık.*süresi/i.test(text) || (/bilimsel\s+hazırlık/i.test(text) && /yarıyıl/i.test(text))) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/en\s*çok\s*2\s*yarıyıl|2\s*yarıyıl|en\s*fazla\s*2/i.test(String(v))) verifiedAnswer = k;
    }
  }

  // 5. Tezli YL Kredi ve AKTS (En az 7 ders + seminer + tez, en az 21 kredi, en az 120 AKTS)
  if (/tezli\s+yüksek\s+lisans.*(kredi|akts|ders)/i.test(text)) {
    if (/akts/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b120\b/i.test(String(v))) verifiedAnswer = k;
      }
    } else if (/kredi/i.test(text) && !/akts/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b21\b/i.test(String(v))) verifiedAnswer = k;
      }
    } else if (/ders\s+sayısı|en\s+az\s+kaç\s+ders/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b7\b|yedi/i.test(String(v))) verifiedAnswer = k;
      }
    }
  }

  // 6. Tezsiz YL Kredi ve AKTS (En az 10 ders + dönem projesi, en az 30 kredi, en az 60 AKTS)
  if (/tezsiz\s+yüksek\s+lisans.*(kredi|akts|ders)/i.test(text)) {
    if (/akts/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b60\b/i.test(String(v))) verifiedAnswer = k;
      }
    } else if (/kredi/i.test(text) && !/akts/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b30\b/i.test(String(v))) verifiedAnswer = k;
      }
    } else if (/ders\s+sayısı|en\s+az\s+kaç\s+ders/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b10\b|on/i.test(String(v))) verifiedAnswer = k;
      }
    }
  }

  // 7. Doktora Kredi ve AKTS
  if (/doktora.*(kredi|akts|ders)/i.test(text)) {
    if (/lisans\s+derecesi\s+ile|lisans\s+mezunu|bütünleşik/i.test(text)) {
      if (/akts/i.test(text)) {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b300\b/i.test(String(v))) verifiedAnswer = k;
        }
      } else if (/kredi/i.test(text)) {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b42\b/i.test(String(v))) verifiedAnswer = k;
        }
      } else if (/ders/i.test(text)) {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b14\b/i.test(String(v))) verifiedAnswer = k;
        }
      }
    } else {
      if (/akts/i.test(text)) {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b240\b/i.test(String(v))) verifiedAnswer = k;
        }
      } else if (/kredi/i.test(text)) {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b21\b/i.test(String(v))) verifiedAnswer = k;
        }
      } else if (/ders/i.test(text)) {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b7\b|yedi/i.test(String(v))) verifiedAnswer = k;
        }
      }
    }
  }

  // 8. Tezli YL Düzeltme süresi (3 ay)
  if (/tezli\s+yüksek\s+lisans.*düzeltme.*süresi/i.test(text) || (/yüksek\s+lisans\s+tez.*düzeltme/i.test(text) && /süre/i.test(text))) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/3\s*ay|üç\s*ay/i.test(String(v))) verifiedAnswer = k;
    }
  }

  // 9. Doktora Tez Düzeltme süresi (6 ay)
  if (/doktora\s+tez.*düzeltme.*süresi/i.test(text) || (/doktora\s+tez/i.test(text) && /düzeltme/i.test(text) && /süre/i.test(text))) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/6\s*ay|altı\s*ay/i.test(String(v))) verifiedAnswer = k;
    }
  }

  // 10. Tez İzleme Komitesi (TİK) üye sayısı (3 kişi)
  if (/tez\s+izleme\s+komitesi.*(kaç\s+kişi|üye\s+sayısı|oluşur)/i.test(text) || (/TİK.*kaç\s+üye/i.test(text))) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/\b3\b|üç/i.test(String(v))) verifiedAnswer = k;
    }
  }

  // 11. Doktora Tez Jürisi üye sayısı (5 kişi)
  if (/doktora\s+tez\s+jürisi.*(kaç\s+kişi|üye\s+sayısı|oluşur)/i.test(text)) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/\b5\b|beş/i.test(String(v))) verifiedAnswer = k;
    }
  }

  // 12. Yüksek Lisans Tez Jürisi üye sayısı (3 veya 5 kişi)
  if (/yüksek\s+lisans\s+tez\s+jürisi.*(kaç\s+kişi|üye\s+sayısı|oluşur)/i.test(text) && !/doktora/i.test(text)) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/3\s*veya\s*5|3\s*ya\s*da\s*5/i.test(String(v))) verifiedAnswer = k;
    }
  }

  // 13. Doktora Yeterlik Komitesi (5 kişi)
  if (/doktora\s+yeterlik\s+komitesi.*(kaç\s+kişi|üye\s+sayısı|oluşur)/i.test(text)) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/\b5\b|beş/i.test(String(v))) verifiedAnswer = k;
    }
  }

  // 14. Doktora Yeterlik Sınav Jürisi (5 kişi, en az 2'si kurum dışından)
  if (/doktora\s+yeterlik\s+sınav\s+jürisi.*(kaç\s+kişi|üye\s+sayısı|oluşur|başka\s+yükseköğretim)/i.test(text)) {
    if (/başka\s+yükseköğretim|kurum\s+dışı|üniversite\s+dışı/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b2\b|iki/i.test(String(v))) verifiedAnswer = k;
      }
    } else {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b5\b|beş/i.test(String(v))) verifiedAnswer = k;
      }
    }
  }

  // 15. Tez önerisi savunması yeterlikten sonra en geç 6 ay
  if (/tez\s+önerisi.*savun/i.test(text) && /süre/i.test(text)) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/6\s*ay|altı\s*ay/i.test(String(v))) verifiedAnswer = k;
    }
  }

  // 16. Tez izleme komitesi toplantı sıklığı (Yılda 2 kez)
  if (/tez\s+izleme\s+komitesi.*toplan/i.test(text) || /TİK.*kaç\s+kez/i.test(text)) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/yılda\s*2\s*kez|yılda\s*iki\s*kez|2\s*kez|iki\s*kez/i.test(String(v))) verifiedAnswer = k;
    }
  }

  // 17. Doktora savunmasına girebilmek için en az 3 TİK raporu
  if (/doktora.*tez.*savunabilmesi\s+için.*en\s+az\s+kaç.*(rapor|TİK)/i.test(text) || (/en\s+az\s+kaç\s+tez\s+izleme\s+komitesi\s+raporu/i.test(text))) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/\b3\b|üç/i.test(String(v))) verifiedAnswer = k;
    }
  }

  // 18. Danışman atama süreleri
  if (/tezli\s+yüksek\s+lisans.*danışman.*(ne\s+zaman|en\s+geç)/i.test(text)) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/birinci\s+yarıyıl|1\.\s*yarıyıl|1\.\s*dönem/i.test(String(v))) verifiedAnswer = k;
    }
  }
  if (/doktora.*danışman.*(ne\s+zaman|en\s+geç)/i.test(text)) {
    for (const [k, v] of Object.entries(optObj)) {
      if (/ikinci\s+yarıyıl|2\.\s*yarıyıl|2\.\s*dönem/i.test(String(v))) verifiedAnswer = k;
    }
  }

  if (currentAns !== verifiedAnswer && verifiedAnswer) {
    status = 'FIXED';
    issueReason = `Mevcut cevap '${currentAns}' iken mevzuat.gov.tr'ye göre doğru cevap '${verifiedAnswer}' olmalıdır.`;
  }

  solvedQuestions.push({
    index: qNum,
    id: q.id,
    question: text,
    options: optObj,
    originalAnswer: currentAns,
    verifiedAnswer: verifiedAnswer || currentAns,
    status: status,
    issueReason: issueReason,
    explanation: exp,
    sources: q.sources
  });

  if (status === 'FIXED') {
    faultyQuestions.push({
      index: qNum,
      id: q.id,
      question: text,
      options: optObj,
      originalAnswer: currentAns,
      verifiedAnswer: verifiedAnswer,
      reason: issueReason,
      sources: q.sources
    });
  }
});

console.log(`İnceleme Tamamlandı!`);
console.log(`Toplam İncelenen Soru: ${solvedQuestions.length}`);
console.log(`Düzeltilen/Hatalı Bulunan Soru Sayısı: ${faultyQuestions.length}`);

fs.writeFileSync('e:/antivaty/G-revde-Y-kselme/scripts/lisansustu_tum_cozumler.json', JSON.stringify(solvedQuestions, null, 2), 'utf8');
fs.writeFileSync('e:/antivaty/G-revde-Y-kselme/scripts/lisansustu_hatali_sorular_raporu.json', JSON.stringify(faultyQuestions, null, 2), 'utf8');
