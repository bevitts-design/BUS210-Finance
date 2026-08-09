import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import {
  getManagedCourseMap,
  readCourseMap,
  renderCourseMap,
  validateCourseMap,
} from "./lib/course-map.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.dirname(scriptDir);
const args = parseArgs(process.argv.slice(2));
const sourcePath = path.resolve(repoRoot, args.source ?? "course-map.json");
const indexPath = path.resolve(repoRoot, args.index ?? "index.html");
const data = await readCourseMap(sourcePath);
const { warnings } = await validateCourseMap(data, { repoRoot });
const indexHtml = await readFile(indexPath, "utf8");
const actualManagedHtml = getManagedCourseMap(indexHtml);
const expectedManagedHtml = renderCourseMap(data);

if (actualManagedHtml === null) throw new Error(`${indexPath} is missing the managed course-map markers.`);
if (actualManagedHtml !== expectedManagedHtml) {
  throw new Error(`${path.relative(repoRoot, indexPath)} is stale. Run scripts/build-index.mjs.`);
}

const visibleLessons = data.lessons.filter((lesson) => lesson.visible);
const hiddenLessons = data.lessons.filter((lesson) => !lesson.visible);
for (const lesson of visibleLessons) {
  if (!actualManagedHtml.includes(`data-course-lesson="${lesson.id}"`)) {
    throw new Error(`Visible lesson ${lesson.id} is missing from ${path.relative(repoRoot, indexPath)}.`);
  }
}
for (const lesson of hiddenLessons) {
  if (actualManagedHtml.includes(`data-course-lesson="${lesson.id}"`)) {
    throw new Error(`Hidden lesson ${lesson.id} is present in ${path.relative(repoRoot, indexPath)}.`);
  }
}

console.log(`Validated ${data.lessons.length} lessons: ${visibleLessons.length} visible, ${hiddenLessons.length} hidden.`);
for (const warning of warnings) console.warn(`Warning: ${warning}`);

function parseArgs(values) {
  const result = {};
  for (let index = 0; index < values.length; index += 1) {
    const key = values[index];
    if (key !== "--source" && key !== "--index") throw new Error(`Unknown argument: ${key}`);
    const value = values[index + 1];
    if (!value) throw new Error(`${key} requires a value.`);
    result[key.slice(2)] = value;
    index += 1;
  }
  return result;
}
