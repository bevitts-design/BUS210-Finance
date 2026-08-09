import { readFile, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  readCourseMap,
  renderCourseMap,
  replaceManagedCourseMap,
  validateCourseMap,
} from "./lib/course-map.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.dirname(scriptDir);
const args = parseArgs(process.argv.slice(2));
const sourcePath = path.resolve(repoRoot, args.source ?? "course-map.json");
const outputPath = path.resolve(repoRoot, args.output ?? "index.html");

const data = await readCourseMap(sourcePath);
const { warnings } = await validateCourseMap(data, { repoRoot });
const indexHtml = await readFile(outputPath, "utf8");
const nextHtml = replaceManagedCourseMap(indexHtml, renderCourseMap(data));

if (nextHtml !== indexHtml) {
  await writeFile(outputPath, nextHtml, "utf8");
  console.log(`Built ${path.relative(repoRoot, outputPath)} from ${path.relative(repoRoot, sourcePath)}.`);
} else {
  console.log(`${path.relative(repoRoot, outputPath)} is already current.`);
}
for (const warning of warnings) console.warn(`Warning: ${warning}`);

function parseArgs(values) {
  const result = {};
  for (let index = 0; index < values.length; index += 1) {
    const key = values[index];
    if (key !== "--source" && key !== "--output") throw new Error(`Unknown argument: ${key}`);
    const value = values[index + 1];
    if (!value) throw new Error(`${key} requires a value.`);
    result[key.slice(2)] = value;
    index += 1;
  }
  return result;
}
