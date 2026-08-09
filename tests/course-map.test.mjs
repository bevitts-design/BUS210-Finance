import assert from "node:assert/strict";
import test from "node:test";
import {
  END_MARKER,
  START_MARKER,
  renderCourseMap,
  replaceManagedCourseMap,
  validateCourseMap,
} from "../scripts/lib/course-map.mjs";

const validMap = () => ({
  schemaVersion: 1,
  course: { code: "BUS210", title: "Finance" },
  modules: [{ id: "module-a", badge: "Module A", title: "First Module", displayOrder: 10 }],
  lessons: [{
    id: "lesson-a",
    moduleId: "module-a",
    code: "BUS210 · M01",
    title: "Visible lesson",
    topic: "A safe topic",
    status: "live",
    visible: true,
    displayOrder: 10,
    links: [{ label: "Open lesson", url: "https://example.com", style: "primary" }],
    futureField: { preserved: true },
  }],
  futureRootField: "allowed",
});

test("unknown fields are accepted and visible lessons render", async () => {
  const map = validMap();
  await validateCourseMap(map, { checkLocalLinks: false });
  const html = renderCourseMap(map);
  assert.match(html, /data-course-lesson="lesson-a"/);
  assert.match(html, /Visible lesson/);
});

test("hidden lessons and empty modules are omitted", async () => {
  const map = validMap();
  map.lessons[0].visible = false;
  await validateCourseMap(map, { checkLocalLinks: false });
  const html = renderCourseMap(map);
  assert.doesNotMatch(html, /lesson-a/);
  assert.doesNotMatch(html, /data-course-module/);
});

test("malformed visibility is rejected", async () => {
  const map = validMap();
  map.lessons[0].visible = "yes";
  await assert.rejects(() => validateCourseMap(map, { checkLocalLinks: false }), /visible must be true or false/);
});

test("managed replacement preserves surrounding homepage content", () => {
  const original = `before\n${START_MARKER}\nold\n${END_MARKER}\nafter`;
  const rendered = renderCourseMap(validMap());
  const replaced = replaceManagedCourseMap(original, rendered);
  assert.ok(replaced.startsWith("before\n"));
  assert.ok(replaced.endsWith("\nafter"));
  assert.match(replaced, /Visible lesson/);
});
