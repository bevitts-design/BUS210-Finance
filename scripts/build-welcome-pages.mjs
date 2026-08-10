import { mkdir, readFile, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = dirname(scriptDir);
const sourcePath = join(repoRoot, "BUS210Welcome_Canvas.html");
const outputDir = join(repoRoot, "deliverables", "fall-2026");
const checkOnly = process.argv.slice(2).includes("--check");

for (const argument of process.argv.slice(2)) {
  if (argument !== "--check") throw new Error(`Unknown argument: ${argument}`);
}

const section01 = await readFile(sourcePath, "utf8");

const requiredSection01Markers = [
  "BUS 210-01",
  "Monday &amp; Wednesday",
  "2:00&ndash;3:15 p.m.",
  "GSB 155",
  "bevitts@endicott.edu",
  "calendar.app.google/HEVjuM1QFke5C7Gi6",
  "McGraw Hill Connect access",
  "Explore the Course Hub",
  '>Course Hub</a>',
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
  .replaceAll("courses/58345", "courses/58352")
  .replaceAll("7763182", "7763186");

const requiredSection02Markers = [
  "BUS 210-02",
  "Monday, Wednesday &amp; Friday",
  "9:00&ndash;9:50 a.m.",
  "GSB 357",
  "bevitts@endicott.edu",
  "calendar.app.google/HEVjuM1QFke5C7Gi6",
  "McGraw Hill Connect access",
  "courses/58352/files/7763186/preview",
  "courses/58352/pages/course-materials",
  "courses/58352/pages/start-here",
  "Explore the Course Hub",
  '>Course Hub</a>',
];

for (const marker of requiredSection02Markers) {
  if (!section02.includes(marker)) {
    throw new Error(`Section 02 output is missing required marker: ${marker}`);
  }
}

if (section02.includes("courses/58345")) {
  throw new Error("Section 02 output still contains a Section 01 course URL.");
}

const removedResourceMarkers = [
  "<!-- Student support -->",
  "Endicott student support",
  "Helpful resources are one click away",
  "Canvas Student FAQ",
  "Canvas Student Orientation",
];

const removedWelcomeImageMarkers = [
  "files/7701558/preview",
  'alt="Welcome to BUS 210 Finance"',
];

for (const [label, html] of [["Section 01", section01], ["Section 02", section02]]) {
  for (const marker of removedWelcomeImageMarkers) {
    if (html.includes(marker)) {
      throw new Error(`${label} still contains the removed welcome image: ${marker}`);
    }
  }
  for (const marker of removedResourceMarkers) {
    if (html.includes(marker)) {
      throw new Error(`${label} still contains removed student-resources content: ${marker}`);
    }
  }
  if (html.includes("Complete the Start Here activities")) {
    throw new Error(`${label} still contains the old Prepare for Class label.`);
  }
}

const section01Output = join(outputDir, "BUS210_01_Welcome_Canvas.html");
const section02Output = join(outputDir, "BUS210_02_Welcome_Canvas.html");

if (checkOnly) {
  const [actualSection01, actualSection02] = await Promise.all([
    readFile(section01Output, "utf8"),
    readFile(section02Output, "utf8"),
  ]);
  if (actualSection01 !== section01) throw new Error("BUS210-01 welcome output is stale. Run scripts/build-welcome-pages.mjs.");
  if (actualSection02 !== section02) throw new Error("BUS210-02 welcome output is stale. Run scripts/build-welcome-pages.mjs.");
  console.log("Validated Section 01 and Section 02 Canvas welcome-page fragments against the maintained source.");
} else {
  await mkdir(outputDir, { recursive: true });
  await writeFile(section01Output, section01);
  await writeFile(section02Output, section02);
  console.log("Built Section 01 and Section 02 Canvas welcome-page fragments.");
}
