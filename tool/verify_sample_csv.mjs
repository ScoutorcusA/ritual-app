import fs from "node:fs/promises";

const artifactToolPath = process.env.RITUAL_ARTIFACT_TOOL_PATH;
if (!artifactToolPath) {
  throw new Error("RITUAL_ARTIFACT_TOOL_PATH is required");
}
const { Workbook } = await import(artifactToolPath);

const inputPath = "output/csv/ritual-sample-journal.csv";
const outputPath = "tmp/csv_qa/ritual-sample-journal.png";
const csvText = await fs.readFile(inputPath, "utf8");
const workbook = await Workbook.fromCSV(csvText, { sheetName: "Journal" });
const sheet = workbook.worksheets.getItem("Journal");
const used = sheet.getUsedRange();
used.format.autofitColumns();
used.format.autofitRows();
sheet.getRange("A1:L1").format = {
  fill: "#63705A",
  font: { bold: true, color: "#FFFFFF" },
  wrapText: true,
};
sheet.getRange("A1:L6").format.wrapText = true;
sheet.getRange("A1:L6").format.rowHeight = 32;
const inspection = await workbook.inspect({
  kind: "table",
  range: "Journal!A1:L6",
  include: "values",
  tableMaxRows: 8,
  tableMaxCols: 12,
});
const preview = await workbook.render({
  sheetName: "Journal",
  range: "A1:L6",
  scale: 1,
  format: "png",
});
await fs.mkdir("tmp/csv_qa", { recursive: true });
await fs.writeFile(outputPath, new Uint8Array(await preview.arrayBuffer()));
console.log(inspection.ndjson);
