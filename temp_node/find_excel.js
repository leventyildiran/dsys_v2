const xlsx = require('xlsx');
const fs = require('fs');
const path = require('path');

function getFiles(dir, files = []) {
  const fileList = fs.readdirSync(dir);
  for (const file of fileList) {
    const name = dir + '/' + file;
    if (fs.statSync(name).isDirectory()) {
      getFiles(name, files);
    } else if (name.toLowerCase().includes('.xls')) {
      files.push(name);
    }
  }
  return files;
}

const files = getFiles('E:/antivaty/dsys_v2/ornek');
for (const file of files) {
  try {
    const wb = xlsx.readFile(file);
    for (const sheetName of wb.SheetNames) {
      const sheet = wb.Sheets[sheetName];
      const data = xlsx.utils.sheet_to_json(sheet, {header: 1});
      for (const row of data) {
        if (row.some(cell => typeof cell === 'string' && cell.toLowerCase().includes('oksijen'))) {
          console.log(`FOUND in ${file} -> Sheet: ${sheetName}`);
          break;
        }
      }
    }
  } catch (e) {}
}
