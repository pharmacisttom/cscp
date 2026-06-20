import * as xlsx from 'xlsx'

const workbook = xlsx.readFile('clinicpdh.xlsx');
const sheetName = workbook.SheetNames[0];
const worksheet = workbook.Sheets[sheetName];

const data = xlsx.utils.sheet_to_json(worksheet, { header: 1 });
console.log("Headers:");
console.log(data[0]);

console.log("\nFirst Data Row:");
if (data.length > 1) {
  console.log(data[1]);
}
