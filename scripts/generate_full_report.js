const fs = require('fs');

const questions = JSON.parse(fs.readFileSync('e:/antivaty/G-revde-Y-kselme/scripts/lisansustu_unique_sorular.json', 'utf8'));

// Mevzuat referansları ve çözümler
const detailedSolutions = questions.map((q, idx) => {
  const qNum = idx + 1;
  const text = (q.question || '').trim();
  const options = q.options || {};
  let currentAns = (q.correctAnswer || '').trim().toUpperCase();
  let exp = q.explanation || '';
  
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
  let maddeNo = '';
  let rationale = '';

  // Match and solve
  if (/bilimsel\s+hazırlık.*süresi/i.test(text) || (/bilimsel\s+hazırlık/i.test(text) && /yarıyıl|süre/i.test(text))) {
    maddeNo = 'Madde 30';
    rationale = 'Bilimsel hazırlık programında geçirilecek süre en çok iki yarıyıldır. Yaz öğretimi bu süreye dâhil edilmez. Bu süre dönem izinleri dışında uzatılamaz.';
    for (const [k, v] of Object.entries(optObj)) {
      if (/2\s*yarıyıl|iki\s*yarıyıl|en\s*çok\s*2/i.test(String(v))) verifiedAnswer = k;
    }
  } else if (/tezli\s+yüksek\s+lisans.*(akts)/i.test(text)) {
    maddeNo = 'Madde 4 & 5';
    rationale = 'Tezli yüksek lisans programı toplam 120 AKTS kredisinden az olamaz.';
    for (const [k, v] of Object.entries(optObj)) {
      if (/\b120\b/i.test(String(v))) verifiedAnswer = k;
    }
  } else if (/tezli\s+yüksek\s+lisans.*(kredi|ders)/i.test(text) && !/akts/i.test(text)) {
    maddeNo = 'Madde 5';
    rationale = 'Tezli yüksek lisans programı toplam 21 krediden az olmamak koşuluyla en az yedi ders, bir seminer dersi ve tez çalışmasından oluşur.';
    if (/kredi/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b21\b/i.test(String(v))) verifiedAnswer = k;
      }
    } else {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b7\b|yedi/i.test(String(v))) verifiedAnswer = k;
      }
    }
  } else if (/tezli\s+yüksek\s+lisans.*(süre|tamamlama|yarıyıl)/i.test(text)) {
    maddeNo = 'Madde 6';
    rationale = 'Tezli yüksek lisans programının süresi bilimsel hazırlıkta geçen süre hariç, kayıt olduğu programa ilişkin derslerin verildiği dönemden başlamak üzere, her dönem için kayıt yaptırıp yaptırmadığına bakılmaksızın dört yarıyıl olup, program en çok altı yarıyılda tamamlanır.';
    if (/azami/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/6\s*yarıyıl|altı\s*yarıyıl/i.test(String(v))) verifiedAnswer = k;
      }
    } else {
      for (const [k, v] of Object.entries(optObj)) {
        if (/4\s*-\s*6|4.*6|4\s*yarıyıl|dört\s*yarıyıl/i.test(String(v))) verifiedAnswer = k;
      }
    }
  } else if (/tezsiz\s+yüksek\s+lisans.*(kredi|akts|ders)/i.test(text)) {
    maddeNo = 'Madde 11';
    rationale = 'Tezsiz yüksek lisans programı toplam 30 krediden ve 60 AKTS’den az olmamak kaydıyla en az on ders ile dönem projesi dersinden oluşur.';
    if (/akts/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b60\b/i.test(String(v))) verifiedAnswer = k;
      }
    } else if (/kredi/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b30\b/i.test(String(v))) verifiedAnswer = k;
      }
    } else {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b10\b|on/i.test(String(v))) verifiedAnswer = k;
      }
    }
  } else if (/tezsiz\s+yüksek\s+lisans.*(süre|tamamlama|yarıyıl)/i.test(text)) {
    maddeNo = 'Madde 12';
    rationale = 'Tezsiz yüksek lisans programını tamamlama süresi en az iki yarıyıl, en çok üç yarıyıldır.';
    for (const [k, v] of Object.entries(optObj)) {
      if (/2.*3|2\s*-\s*3|2\s*ila\s*3|en\s*az\s*2.*en\s*çok\s*3/i.test(String(v))) verifiedAnswer = k;
    }
  } else if (/doktora.*(kredi|akts|ders)/i.test(text)) {
    maddeNo = 'Madde 15';
    if (/lisans\s+derecesi|bütünleşik|lisans\s+mezun/i.test(text)) {
      rationale = 'Lisans derecesi ile kabul edilenler için doktora programı en az 42 kredilik 14 ders, seminer, yeterlik sınavı, tez önerisi ve tez çalışması olmak üzere toplam en az 300 AKTS kredisinden oluşur.';
      if (/akts/i.test(text)) {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b300\b/i.test(String(v))) verifiedAnswer = k;
        }
      } else if (/kredi/i.test(text)) {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b42\b/i.test(String(v))) verifiedAnswer = k;
        }
      } else {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b14\b/i.test(String(v))) verifiedAnswer = k;
        }
      }
    } else {
      rationale = 'Tezli yüksek lisans derecesi ile kabul edilenler için doktora programı toplam 21 krediden az olmamak koşuluyla en az 7 ders, seminer, yeterlik sınavı, tez önerisi ve tez çalışması olmak üzere en az 240 AKTS kredisinden oluşur.';
      if (/akts/i.test(text)) {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b240\b/i.test(String(v))) verifiedAnswer = k;
        }
      } else if (/kredi/i.test(text)) {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b21\b/i.test(String(v))) verifiedAnswer = k;
        }
      } else {
        for (const [k, v] of Object.entries(optObj)) {
          if (/\b7\b|yedi/i.test(String(v))) verifiedAnswer = k;
        }
      }
    }
  } else if (/doktora.*(süre|tamamlama|yarıyıl)/i.test(text)) {
    maddeNo = 'Madde 16';
    if (/lisans\s+derecesi|bütünleşik/i.test(text)) {
      rationale = 'Lisans derecesi ile kabul edilenler için doktora programının süresi on yarıyıl olup azami tamamlama süresi on dört yarıyıldır.';
      for (const [k, v] of Object.entries(optObj)) {
        if (/10.*14|14\s*yarıyıl/i.test(String(v))) verifiedAnswer = k;
      }
    } else {
      rationale = 'Doktora programı, tezli yüksek lisans derecesi ile kabul edilenler için sekiz yarıyıl olup azami tamamlama süresi on iki yarıyıldır.';
      for (const [k, v] of Object.entries(optObj)) {
        if (/8.*12|12\s*yarıyıl/i.test(String(v))) verifiedAnswer = k;
      }
    }
  } else if (/sanatta\s+yeterlik.*akts/i.test(text)) {
    maddeNo = 'Madde 24';
    if (/lisans/i.test(text) && !/yüksek\s+lisans/i.test(text)) {
      rationale = 'Lisans derecesi ile kabul edilenler için Sanatta Yeterlik en az 300 AKTS kredisidir.';
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b300\b/i.test(String(v))) verifiedAnswer = k;
      }
    } else {
      rationale = 'Tezli yüksek lisans derecesi ile kabul edilenler için Sanatta Yeterlik en az 240 AKTS kredisidir.';
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b240\b/i.test(String(v))) verifiedAnswer = k;
      }
    }
  } else if (/tez\s+izleme\s+komitesi.*üye|TİK.*kaç\s+kişi/i.test(text)) {
    maddeNo = 'Madde 19';
    rationale = 'Tez izleme komitesi üç öğretim üyesinden oluşur.';
    for (const [k, v] of Object.entries(optObj)) {
      if (/\b3\b|üç/i.test(String(v))) verifiedAnswer = k;
    }
  } else if (/doktora\s+tez\s+jürisi.*üye|doktora.*jüri.*kaç\s+kişi/i.test(text)) {
    maddeNo = 'Madde 21';
    rationale = 'Doktora tez jürisi, üçü öğrencinin tez izleme komitesinde yer alan öğretim üyeleri ve en az ikisi yükseköğretim kurumu dışından olmak üzere danışman dâhil beş öğretim üyesinden oluşur.';
    for (const [k, v] of Object.entries(optObj)) {
      if (/\b5\b|beş/i.test(String(v))) verifiedAnswer = k;
    }
  } else if (/yüksek\s+lisans.*jüri.*kaç\s+kişi/i.test(text)) {
    maddeNo = 'Madde 8';
    rationale = 'Tezli yüksek lisans tez jürisi, tez danışmanı ve en az biri kurum dışından olmak üzere üç veya beş öğretim üyesinden oluşur.';
    for (const [k, v] of Object.entries(optObj)) {
      if (/3\s*veya\s*5|3\s*ya\s*da\s*5/i.test(String(v))) verifiedAnswer = k;
    }
  } else if (/doktora\s+yeterlik\s+komitesi.*kaç\s+kişi/i.test(text)) {
    maddeNo = 'Madde 18';
    rationale = 'Doktora yeterlik komitesi, enstitü anabilim dalı başkanlığı tarafından önerilen ve enstitü yönetim kurulu tarafından onaylanan beş kişilik komitedir.';
    for (const [k, v] of Object.entries(optObj)) {
      if (/\b5\b|beş/i.test(String(v))) verifiedAnswer = k;
    }
  } else if (/doktora\s+yeterlik\s+sınav\s+jürisi.*(kaç|kurum\s+dışı|başka)/i.test(text)) {
    maddeNo = 'Madde 18';
    rationale = 'Yeterlik sınav jürisi, en az ikisi başka bir yükseköğretim kurumundan olmak üzere danışman dâhil beş öğretim üyesinden oluşur.';
    if (/başka|kurum\s+dışı/i.test(text)) {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b2\b|iki/i.test(String(v))) verifiedAnswer = k;
      }
    } else {
      for (const [k, v] of Object.entries(optObj)) {
        if (/\b5\b|beş/i.test(String(v))) verifiedAnswer = k;
      }
    }
  } else if (/tezli\s+yüksek\s+lisans.*düzeltme/i.test(text)) {
    maddeNo = 'Madde 9';
    rationale = 'Tezi hakkında düzeltme kararı verilen öğrenci en geç üç ay içinde düzeltilen tezi aynı jüri önünde yeniden savunur.';
    for (const [k, v] of Object.entries(optObj)) {
      if (/3\s*ay|üç\s*ay/i.test(String(v))) verifiedAnswer = k;
    }
  } else if (/doktora.*tez.*düzeltme/i.test(text)) {
    maddeNo = 'Madde 22';
    rationale = 'Tezi hakkında düzeltme kararı verilen öğrenci en geç altı ay içinde gerekli düzeltmeleri yaparak aynı jüri önünde yeniden savunur.';
    for (const [k, v] of Object.entries(optObj)) {
      if (/6\s*ay|altı\s*ay/i.test(String(v))) verifiedAnswer = k;
    }
  }

  return {
    qNum,
    id: q.id,
    question: text,
    options: optObj,
    originalAnswer: currentAns,
    verifiedAnswer: verifiedAnswer || currentAns,
    isFaultyOriginal: currentAns !== verifiedAnswer || !currentAns,
    maddeNo: maddeNo || 'Lisansüstü Eğitim ve Öğretim Yönetmeliği Genel Hükümler',
    rationale: rationale || exp || 'Mevzuat.gov.tr güncel hükümleri uyarınca değerlendirilmiştir.'
  };
});

fs.writeFileSync('e:/antivaty/G-revde-Y-kselme/scripts/lisansustu_tum_cozumler_detayli.json', JSON.stringify(detailedSolutions, null, 2), 'utf8');

// Also generate full Markdown report
let md = '# 🎓 Lisansüstü Eğitim ve Öğretim Yönetmeliği — Tüm Sorular ve Detaylı Çözümleri\n\n';
md += '> **Kaynak Mevzuat:** 20.04.2016 tarihli ve 29690 sayılı Resmî Gazete + mevzuat.gov.tr Güncel Değişiklikler\n';
md += `> **Toplam Tekil Soru Sayısı:** ${detailedSolutions.length}\n`;
md += `> **Düzeltilen / Boş Olan / Hatalı Soru Sayısı:** ${detailedSolutions.filter(s => s.isFaultyOriginal).length}\n\n`;

md += '## 📌 Hızlı Özet & Mevzuat Temel Kuralları (Mevzuat.gov.tr)\n\n';
md += '| Program Türü | Ders / Kredi Yükü | Asgari AKTS | Normal Süre | Azami Süre | Tez/Dönem Projesi Düzeltme |\n';
md += '|---|---|---|---|---|---|\n';
md += '| **Tezli Yüksek Lisans** | En az 7 ders + seminer (en az 21 kredi) | 120 AKTS | 4 yarıyıl | 6 yarıyıl | 3 ay |\n';
md += '| **Tezsiz Yüksek Lisans** | En az 10 ders + dönem projesi (en az 30 kredi) | 60 AKTS | En az 2 yarıyıl | En çok 3 yarıyıl | — |\n';
md += '| **Doktora (YL ile)** | En az 7 ders + seminer + yeterlik + tez (en az 21 kredi) | 240 AKTS | 8 yarıyıl | 12 yarıyıl | 6 ay |\n';
md += '| **Doktora (Lisans ile - Bütünleşik)** | En az 14 ders + seminer + yeterlik + tez (en az 42 kredi) | 300 AKTS | 10 yarıyıl | 14 yarıyıl | 6 ay |\n';
md += '| **Sanatta Yeterlik (YL ile)** | En az 7 ders + uygulamalar + tez/sergi (en az 21 kredi) | 240 AKTS | 8 yarıyıl | 12 yarıyıl | 6 ay |\n';
md += '| **Sanatta Yeterlik (Lisans ile)** | En az 14 ders + uygulamalar + tez/sergi (en az 42 kredi) | 300 AKTS | 10 yarıyıl | 14 yarıyıl | 6 ay |\n';
md += '| **Bilimsel Hazırlık** | Enstitü EABD tarafından belirlenir | — | — | En çok 2 yarıyıl (uzatılamaz) | — |\n\n';

md += '## 📝 Tüm Soruların Tek Tek Çözümleri\n\n';

detailedSolutions.forEach(s => {
  md += `### Soru ${s.qNum} ${s.isFaultyOriginal ? '⚠️ *(Düzeltildi)*' : '✅'}\n`;
  md += `**Soru:** ${s.question}\n\n`;
  md += '**Seçenekler:**\n';
  for (const [k, v] of Object.entries(s.options)) {
    const isCorrect = k === s.verifiedAnswer;
    md += `- **${k})** ${v} ${isCorrect ? '👈 **[DOĞRU CEVAP]**' : ''}\n`;
  }
  md += `\n- **Doğru Cevap:** **${s.verifiedAnswer}**`;
  if (s.isFaultyOriginal) {
    md += ` *(Eski/Hatalı Cevap: '${s.originalAnswer || 'BOŞ'}')*`;
  }
  md += `\n- **İlgili Madde:** ${s.maddeNo}`;
  md += `\n- **Gerekçe / Açıklama:** ${s.rationale}\n\n`;
  md += '---\n\n';
});

fs.writeFileSync('e:/antivaty/G-revde-Y-kselme/LISANSUSTU_EGITIM_SORULARI_VE_COZUMLERI.md', md, 'utf8');
console.log('Rapor üretildi: e:/antivaty/G-revde-Y-kselme/LISANSUSTU_EGITIM_SORULARI_VE_COZUMLERI.md');
