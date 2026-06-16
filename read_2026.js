const mammoth = require("mammoth");
const path = require("path");

const docxPath = path.join("e:\\antivaty\\dsys_v2\\ornek\\YÜRÜTME KURULU KARARLARI\\YÜRÜTME KURULU KARARLARI\\2026 YKK\\7. TOPLANTI\\Yürütme Kurulu Kararları.docx");

mammoth.extractRawText({path: docxPath})
    .then(function(result){
        const text = result.value;
        const lines = text.split('\n').filter(l => l.trim() !== '');
        console.log("=== 2026 YKK 7. TOPLANTI KARARLARI ===\n");
        // Print first 50 lines to get a sense of it
        console.log(lines.slice(0, 50).join('\n'));
    })
    .catch(console.error);
