const fs = require('fs');
const path = require('path');
const mammoth = require('mammoth');

async function extractDocx(filePath) {
    try {
        const result = await mammoth.extractRawText({path: filePath});
        const text = result.value;
        console.log("=== EXTRACTED TEXT FROM: " + path.basename(filePath) + " ===");
        console.log(text.substring(0, 1000) + "...\n");
    } catch(e) {
        console.error("Error reading " + filePath + ": " + e);
    }
}

async function run() {
    await extractDocx("e:/antivaty/dsys_v2/ornek/1Yürütme Kurulu Kararları.docx");
    await extractDocx("e:/antivaty/dsys_v2/ornek/Toplantı Gündem Maddeleri.docx");
}

run();
