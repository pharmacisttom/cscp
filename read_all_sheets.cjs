const xlsx = require('xlsx');

const workbook = xlsx.readFile('clinicpdh.xlsx');
console.log("Sheet Names:", workbook.SheetNames);

workbook.SheetNames.forEach(sheetName => {
  const worksheet = workbook.Sheets[sheetName];
  const data = xlsx.utils.sheet_to_json(worksheet, { header: 1 });
  if (data.length > 0) {
    console.log(`\nHeaders for ${sheetName}:`);
    console.log(data[0]);
  }
});
