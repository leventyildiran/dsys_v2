const XLSX = require('xlsx');
const fs = require('fs');

const filePath = 'E:\\antivaty\\dsys_v2\\ornek\\BELGELER\\2025\\UBATAM\\Ubatam Fatura Şablon.xls';
const workbook = XLSX.readFile(filePath);

const sheetName = workbook.SheetNames[0];
const sheet = workbook.Sheets[sheetName];

const data = XLSX.utils.sheet_to_json(sheet, { header: 1, defval: '' });

console.log("--- UBATAM FATURA ŞABLON EXCEL İÇERİĞİ ---");
for (let i = 0; i < Math.min(data.length, 50); i++) {
    const row = data[i];
    if (row && row.some(cell => String(cell).trim() !== '')) {
        console.log(`Satır ${i + 1}:`, row.join(' | '));
    }
}
