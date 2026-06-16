const mammoth = require("mammoth");
const path = require("path");

const docxPath = path.join("e:\\antivaty\\dsys_v2\\ornek\\YÜRÜTME KURULU KARARLARI\\YÜRÜTME KURULU KARARLARI\\YÜRÜTME KURULU ÜYE TELEFON.docx");

mammoth.extractRawText({path: docxPath})
    .then(function(result){
        console.log(result.value); // The raw text
    })
    .catch(console.error);
