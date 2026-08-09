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
const renderedLessonCount = [...actualManagedHtml.matchAll(/data-course-lesson=/g)].length;
if (renderedLessonCount !== data.lessons.length) {
  throw new Error(`${path.relative(repoRoot, indexPath)} renders ${renderedLessonCount} lesson cards; expected ${data.lessons.length}.`);
}

for (const lesson of data.lessons) {
  const markup = getLessonMarkup(actualManagedHtml, lesson.id);
  if (!markup) throw new Error(`Lesson ${lesson.id} is missing from ${path.relative(repoRoot, indexPath)}.`);

  const shouldBeAvailable = lesson.visible && lesson.status === "live";
  if (shouldBeAvailable) {
    if (!markup.includes('data-course-access="available"')) {
      throw new Error(`Available lesson ${lesson.id} is missing its available-access marker.`);
    }
    for (const link of lesson.links) {
      if (!markup.includes(`href="${escapeHtml(link.url)}"`)) {
        throw new Error(`Available lesson ${lesson.id} is missing its functional link: ${link.url}.`);
      }
    }
  } else {
    const requiredLockedMarkers = [
      "<article",
      'class="lesson-card lesson-card-unavailable"',
      'data-course-access="locked"',
      "aria-labelledby=",
      "aria-describedby=",
      "Coming soon — access not yet available",
    ];
    for (const marker of requiredLockedMarkers) {
      if (!markup.includes(marker)) throw new Error(`Locked lesson ${lesson.id} is missing accessibility/status markup: ${marker}.`);
    }
    if (/<a\b|\bhref=|\btabindex=/i.test(markup)) {
      throw new Error(`Locked lesson ${lesson.id} exposes an interactive link or keyboard target.`);
    }
  }
}

console.log(`Validated all ${data.lessons.length} lesson cards: ${visibleLessons.length} available, ${hiddenLessons.length} locked.`);
for (const warning of warnings) console.warn(`Warning: ${warning}`);

function getLessonMarkup(html, lessonId) {
  const id = escapeRegExp(lessonId);
  return html.match(new RegExp(`<(?<tag>a|article)\\b[^>]*data-course-lesson="${id}"[^>]*>[\\s\\S]*?<\\/\\k<tag>>`))?.[0] ?? null;
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

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
