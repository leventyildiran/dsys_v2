const mammoth = require("mammoth");
const path = require("path");
const fs = require("fs");

const dir = "e:\\antivaty\\dsys_v2\\ornek\\YÜRÜTME KURULU KARARLARI\\YÜRÜTME KURULU KARARLARI\\2024 YKK\\1. TOPLANTI";
const files = fs.readdirSync(dir);
const docxFile = files.find(f => f.includes('Yürütme') && f.endsWith('.docx'));

if (docxFile) {
  mammoth.extractRawText({path: path.join(dir, docxFile)})
      .then(function(result){
          const text = result.value;
          const lines = text.split('\n');
          console.log(lines.slice(Math.max(lines.length - 30, 0)).join('\n'));
      })
      .catch(console.error);
}
