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
  assert.match(html, /data-course-access="available"/);
  assert.match(html, /href="https:\/\/example.com"/);
  assert.match(html, /Visible lesson/);
});

test("hidden lessons remain listed as accessible noninteractive locked cards", async () => {
  const map = validMap();
  map.lessons[0].visible = false;
  await validateCourseMap(map, { checkLocalLinks: false });
  const html = renderCourseMap(map);
  assert.match(html, /data-course-module="module-a"/);
  assert.match(html, /<article class="lesson-card lesson-card-unavailable"/);
  assert.match(html, /data-course-lesson="lesson-a"/);
  assert.match(html, /data-course-access="locked"/);
  assert.match(html, /aria-labelledby="lesson-lesson-a-title"/);
  assert.match(html, /aria-describedby="lesson-lesson-a-topic lesson-lesson-a-status"/);
  assert.match(html, /BUS210 · M01/);
  assert.match(html, /Visible lesson/);
  assert.match(html, /A safe topic/);
  assert.match(html, /Coming soon — access not yet available/);
  assert.doesNotMatch(html, /<a\b|href=|tabindex=/);
  assert.doesNotMatch(html, /https:\/\/example.com/);
});

test("visibility controls access while every lesson card remains present", async () => {
  const map = validMap();
  map.lessons.push({
    ...map.lessons[0],
    id: "lesson-b",
    title: "Locked lesson",
    visible: false,
    displayOrder: 20,
    links: [{ label: "Open locked lesson", url: "https://locked.example.com", style: "primary" }],
  });
  await validateCourseMap(map, { checkLocalLinks: false });
  const html = renderCourseMap(map);
  assert.equal([...html.matchAll(/data-course-lesson=/g)].length, 2);
  assert.match(html, /href="https:\/\/example.com"/);
  assert.doesNotMatch(html, /https:\/\/locked\.example\.com/);
});

test("an available lesson must be live with a functional link", async () => {
  const map = validMap();
  map.lessons[0].status = "comingSoon";
  map.lessons[0].links = [];
  await assert.rejects(
    () => validateCourseMap(map, { checkLocalLinks: false }),
    /available but its status is not live[\s\S]*available but has no functional lesson link/,
  );
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
