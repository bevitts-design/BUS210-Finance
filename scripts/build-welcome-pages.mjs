import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = dirname(scriptDir);
const sourcePath = join(repoRoot, "BUS210Welcome_Canvas.html");
const outputDir = join(repoRoot, "deliverables", "fall-2026");

const section01 = await readFile(sourcePath, "utf8");

const requiredSection01Markers = [
  "BUS 210-01",
  "Monday &amp; Wednesday",
  "2:00&ndash;3:15 p.m.",
  "GSB 155",
  "bevitts@endicott.edu",
  "calendar.app.google/HEVjuM1QFke5C7Gi6",
  "McGraw Hill Connect access",
];

for (const marker of requiredSection01Markers) {
  if (!section01.includes(marker)) {
    throw new Error(`Section 01 source is missing required marker: ${marker}`);
  }
}

const section02 = section01
  .replace("BUS 210-01", "BUS 210-02")
  .replace("Monday &amp; Wednesday", "Monday, Wednesday &amp; Friday")
  .replace("2:00&ndash;3:15 p.m.", "9:00&ndash;9:50 a.m.")
  .replace("GSB 155", "GSB 357")
  .replaceAll("courses/58345/", "courses/58352/")
  .replaceAll("courses/58345", "courses/58352");

const requiredSection02Markers = [
  "BUS 210-02",
  "Monday, Wednesday &amp; Friday",
  "9:00&ndash;9:50 a.m.",
  "GSB 357",
  "bevitts@endicott.edu",
  "calendar.app.google/HEVjuM1QFke5C7Gi6",
  "McGraw Hill Connect access",
  "courses/58352/pages/course-materials",
  "courses/58352/pages/start-here",
];

for (const marker of requiredSection02Markers) {
  if (!section02.includes(marker)) {
    throw new Error(`Section 02 output is missing required marker: ${marker}`);
  }
}

if (section02.includes("courses/58345")) {
  throw new Error("Section 02 output still contains a Section 01 course URL.");
}

await mkdir(outputDir, { recursive: true });
await writeFile(join(outputDir, "BUS210_01_Welcome_Canvas.html"), section01);
await writeFile(join(outputDir, "BUS210_02_Welcome_Canvas.html"), section02);

console.log("Built Section 01 and Section 02 Canvas welcome-page fragments.");
