import { access, readFile } from "node:fs/promises";
import path from "node:path";

export const START_MARKER = "<!-- BUS210 COURSE MAP:START -->";
export const END_MARKER = "<!-- BUS210 COURSE MAP:END -->";

const ALLOWED_STATUSES = new Set(["live", "comingSoon"]);
const ALLOWED_LINK_STYLES = new Set(["primary", "reference"]);
const PRIVATE_PATH_PATTERN = /(^|[/_-])(instructor|answer[-_ ]?key|solutions?|grading|qti)([/_.-]|$)|\.zip$/i;

export async function readCourseMap(sourcePath) {
  let data;
  try {
    data = JSON.parse(await readFile(sourcePath, "utf8"));
  } catch (error) {
    throw new Error(`Could not parse ${sourcePath}: ${error.message}`);
  }
  return data;
}

export async function validateCourseMap(data, { repoRoot, checkLocalLinks = true } = {}) {
  const errors = [];
  const warnings = [];

  if (!data || typeof data !== "object" || Array.isArray(data)) {
    throw new Error("Course map root must be a JSON object.");
  }
  if (data.schemaVersion !== 1) errors.push("schemaVersion must be 1.");
  if (!data.course || typeof data.course !== "object") errors.push("course is required.");
  if (!Array.isArray(data.modules)) errors.push("modules must be an array.");
  if (!Array.isArray(data.lessons)) errors.push("lessons must be an array.");

  const moduleIds = new Set();
  const moduleOrders = new Set();
  for (const module of data.modules ?? []) {
    if (!isNonemptyString(module.id)) errors.push("Every module needs a non-empty id.");
    else if (moduleIds.has(module.id)) errors.push(`Duplicate module id: ${module.id}.`);
    else moduleIds.add(module.id);
    if (!isNonemptyString(module.badge)) errors.push(`${module.id ?? "A module"} needs a badge.`);
    if (!isNonemptyString(module.title)) errors.push(`${module.id ?? "A module"} needs a title.`);
    if (!Number.isFinite(module.displayOrder)) errors.push(`${module.id ?? "A module"} needs a numeric displayOrder.`);
    else if (moduleOrders.has(module.displayOrder)) errors.push(`Duplicate module displayOrder: ${module.displayOrder}.`);
    else moduleOrders.add(module.displayOrder);
  }

  const lessonIds = new Set();
  const lessonOrders = new Set();
  for (const lesson of data.lessons ?? []) {
    const label = lesson?.id ?? "A lesson";
    if (!isNonemptyString(lesson.id)) errors.push("Every lesson needs a non-empty id.");
    else if (lessonIds.has(lesson.id)) errors.push(`Duplicate lesson id: ${lesson.id}.`);
    else lessonIds.add(lesson.id);
    if (!moduleIds.has(lesson.moduleId)) errors.push(`${label} references unknown moduleId "${lesson.moduleId}".`);
    for (const key of ["code", "title", "topic"]) {
      if (!isNonemptyString(lesson[key])) errors.push(`${label} needs a non-empty ${key}.`);
    }
    if (typeof lesson.visible !== "boolean") errors.push(`${label}.visible must be true or false.`);
    if (!ALLOWED_STATUSES.has(lesson.status)) errors.push(`${label} has unsupported status "${lesson.status}".`);
    if (!Number.isFinite(lesson.displayOrder)) errors.push(`${label} needs a numeric displayOrder.`);
    else if (lessonOrders.has(lesson.displayOrder)) errors.push(`Duplicate lesson displayOrder: ${lesson.displayOrder}.`);
    else lessonOrders.add(lesson.displayOrder);
    if (!Array.isArray(lesson.links)) {
      errors.push(`${label}.links must be an array.`);
      continue;
    }
    if (lesson.status === "live" && lesson.links.length === 0) {
      errors.push(`${label} is live but has no links.`);
    }
    for (const link of lesson.links) {
      if (!isNonemptyString(link.label)) errors.push(`${label} has a link without a label.`);
      if (!isNonemptyString(link.url) || link.url === "#") errors.push(`${label} has a missing or placeholder link URL.`);
      if (!ALLOWED_LINK_STYLES.has(link.style)) errors.push(`${label} has unsupported link style "${link.style}".`);
      if (PRIVATE_PATH_PATTERN.test(link.url ?? "")) errors.push(`${label} links a private or non-public path: ${link.url}.`);
      if (/^https?:\/\//i.test(link.url ?? "")) continue;
      if (/^[a-z][a-z0-9+.-]*:/i.test(link.url ?? "")) {
        errors.push(`${label} uses an unsupported URL scheme: ${link.url}.`);
        continue;
      }
      if (checkLocalLinks && repoRoot && isNonemptyString(link.url)) {
        const target = path.resolve(repoRoot, link.url);
        const insideRepo = target === repoRoot || target.startsWith(`${repoRoot}${path.sep}`);
        if (!insideRepo) errors.push(`${label} link escapes the repository: ${link.url}.`);
        else {
          try {
            await access(target);
          } catch {
            warnings.push(`${label} local link is not available yet: ${link.url}.`);
          }
        }
      }
    }
  }

  if (errors.length) throw new Error(`Course map validation failed:\n- ${errors.join("\n- ")}`);
  return { warnings };
}

export function renderCourseMap(data) {
  const modules = [...data.modules].sort((a, b) => a.displayOrder - b.displayOrder);
  const lessons = [...data.lessons].sort((a, b) => a.displayOrder - b.displayOrder);
  const renderedModules = [];

  for (const module of modules) {
    const visibleLessons = lessons.filter((lesson) => lesson.moduleId === module.id && lesson.visible);
    if (visibleLessons.length === 0) continue;
    renderedModules.push(`    <!-- Generated module: ${escapeHtml(module.id)} -->
    <div class="module-block fade-section" data-course-module="${escapeHtml(module.id)}">
      <div class="module-header">
        <span class="module-badge">${escapeHtml(module.badge)}</span>
        <span class="module-title">${escapeHtml(module.title)}</span>
      </div>
      <div class="lessons-grid">
${visibleLessons.map(renderLesson).join("\n\n")}
      </div>
    </div>`);
  }

  return `${START_MARKER}\n${renderedModules.join("\n\n")}\n    ${END_MARKER}`;
}

export function replaceManagedCourseMap(indexHtml, rendered) {
  const start = indexHtml.indexOf(START_MARKER);
  const end = indexHtml.indexOf(END_MARKER);
  if (start < 0 || end < 0 || end < start) {
    throw new Error("index.html is missing the BUS210 course-map start/end markers.");
  }
  if (indexHtml.indexOf(START_MARKER, start + START_MARKER.length) >= 0 || indexHtml.indexOf(END_MARKER, end + END_MARKER.length) >= 0) {
    throw new Error("index.html contains duplicate BUS210 course-map markers.");
  }
  return `${indexHtml.slice(0, start)}${rendered}${indexHtml.slice(end + END_MARKER.length)}`;
}

export function getManagedCourseMap(indexHtml) {
  const start = indexHtml.indexOf(START_MARKER);
  const end = indexHtml.indexOf(END_MARKER);
  if (start < 0 || end < 0 || end < start) return null;
  return indexHtml.slice(start, end + END_MARKER.length);
}

function renderLesson(lesson) {
  if (lesson.status === "comingSoon") {
    return `        <div class="lesson-card disabled" data-course-lesson="${escapeHtml(lesson.id)}">
          <div class="lesson-code">${escapeHtml(lesson.code)}</div>
          <div class="lesson-title">${escapeHtml(lesson.title)}</div>
          <div class="lesson-topic">${escapeHtml(lesson.topic)}</div>
          <span class="coming-badge">Coming soon</span>
        </div>`;
  }

  if (lesson.links.length === 1) {
    const link = lesson.links[0];
    return `        <a class="lesson-card" data-course-lesson="${escapeHtml(lesson.id)}" href="${escapeHtml(link.url)}" target="_blank" rel="noopener noreferrer">
          <div class="lesson-code">${escapeHtml(lesson.code)}</div>
          <div class="lesson-title">${escapeHtml(lesson.title)}</div>
          <div class="lesson-topic">${escapeHtml(lesson.topic)}</div>
          <span class="lesson-cta">${escapeHtml(link.label)}
            ${arrowIcon()}
          </span>
        </a>`;
  }

  return `        <article class="lesson-card" data-course-lesson="${escapeHtml(lesson.id)}">
          <div class="lesson-code">${escapeHtml(lesson.code)}</div>
          <div class="lesson-title">${escapeHtml(lesson.title)}</div>
          <div class="lesson-topic">${escapeHtml(lesson.topic)}</div>
          <div class="lesson-actions">
${lesson.links.map((link) => renderActionLink(lesson, link)).join("\n")}
          </div>
        </article>`;
}

function renderActionLink(lesson, link) {
  const referenceClass = link.style === "reference" ? " lesson-cta-reference" : "";
  return `            <a class="lesson-cta${referenceClass}" href="${escapeHtml(link.url)}" target="_blank" rel="noopener noreferrer" aria-label="${escapeHtml(`${link.label} for ${lesson.title} in a new tab`)}">${escapeHtml(link.label)}
              ${arrowIcon()}
            </a>`;
}

function arrowIcon() {
  return '<svg width="12" height="12" viewBox="0 0 12 12" fill="none" aria-hidden="true"><path d="M2.5 6h7M6 2.5l3.5 3.5L6 9.5" stroke="currentColor" stroke-width="1.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';
}

function isNonemptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}
