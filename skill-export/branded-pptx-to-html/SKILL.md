---
name: branded-pptx-to-html
description: Rebuild PowerPoint PPTX decks into Prof. Evitts branded, editable HTML slide decks using the Refined Hybrid BUS course system. Use the PPTX as a source/base for content, sequence, and visual references, but default to rebuilding slides as clean editable HTML rather than literal conversion. Use for BUS123, BUS210, BUS311, or BUS331, especially when text, charts, formulas, Excel examples, and teaching visuals should remain readable and editable.
---

# Branded PPTX To HTML

## Intake

Start every conversion by asking only what is needed:

1. Course: BUS123, BUS210, BUS311, or BUS331.
2. PPTX path, if not already provided.
3. Destination folder in the repo, for example `INTRO/index.html` or `M04/index.html`.
4. Whether to convert all slides or a slide range.
5. Whether speaker notes are wanted. Default: no notes unless requested.
6. Conversion mode, only if the user cares about fidelity. Default: `fast rebuild`.

## Conversion Modes

Use `fast rebuild` by default unless the user explicitly asks for closer fidelity.

- `fast rebuild`: Use the PPTX for content, sequence, and visual intent. Rebuild clean branded slides efficiently. Do not chase pixel-level fidelity.
- `faithful rebuild`: Stay closer to the original slide-by-slide look while still fixing readability and brand issues.
- `literal audit`: Use only when the user needs exact comparison to the PPTX. This is token- and time-expensive.

If the user simply says "convert this PPTX," choose `fast rebuild`.

## Conversion Philosophy

Default to a **branded rebuild from PPTX content**, not a literal slide replica.

The PPTX is the source/base for:

- Slide order and topic flow.
- Extracted text, formulas, examples, prompts, and captions.
- Images that are already presentation-quality, such as photos, screenshots, logos, and complex visuals.
- Visual intent, such as timelines, charts, comparison layouts, or Excel examples.

Do not spend excessive effort preserving PowerPoint's internal object structure when it makes the HTML worse. PowerPoint often stores one visual slide as disconnected text boxes, grouped shapes, partial screenshots, and low-resolution images. In those cases, rebuild the idea in the branded HTML system.

Prefer editable HTML/SVG for:

- Titles, bullets, numbered statements, callouts, and captions.
- Charts and graphs where labels or axes matter.
- Timelines and process diagrams.
- Excel function dialogs, formula inputs, tables, calculator rows, and numerical outputs.
- Any screenshot where important numbers or labels are too small to read.

Keep local image assets for:

- Photos and artwork.
- Screenshots that are already readable at slide size.
- Complex diagrams that would take longer to recreate and are still legible.
- Original slide/reference images used only for review.

When the user says "convert this PPTX," interpret that as "use this PPTX as the base and create the best branded editable HTML version," unless they explicitly request a literal visual replica.

Use the course to set the accent color:

- BUS123: `--sage`
- BUS210: `--steel`
- BUS311: `--terra`
- BUS331: `--gold`

## Workflow

1. Read `references/refined-hybrid-brand.md`.
2. Inspect the repo for existing `deck-stage.js`, `image-slot.js`, and `tweaks-panel.jsx`.
3. If missing, copy them from a known BUS course repo when available, or create a compatible fallback only when necessary.
4. Run `scripts/extract_pptx_assets.py` to extract slide text, media, relationships, and optional JPG reference slides into the destination folder.
5. Generate a compact deck audit before building. Use a short table: `slide | likely title/topic | text count | image count | likely action`.
6. Batch-classify problem slides before editing: unreadable screenshots, charts with missing labels, dense slides to split, images to preserve, images to rebuild.
7. Build `index.html` as static HTML using `<deck-stage width="1920" height="1080" no-rail>`.
8. Rebuild each slide for teaching clarity using the extracted content as the source. Preserve editable text wherever practical. Keep only images that remain readable and useful as images.
9. Remove repeated institutional logos or template marks unless the user asks to keep them. Keep the title-slide logo by default.
10. Convert dense PPTX slides into branded, readable layouts rather than absolute-position replicas.
11. Keep all slide content at 24px or larger. Split or summarize dense slides when needed.
12. Run the rebuild review pass below before finalizing.
13. Run the image review pass below before finalizing.
14. Start a local server and give the user the URL. If browser verification is possible, check the first slide, an image-heavy slide, a screenshot/Excel slide, a recreated chart/formula slide, and a dense text slide.
15. Stop after a classroom-ready first pass. Report known interpretive rebuilds and slides worth human review, then wait for targeted feedback instead of continuing to polish every slide.

## Token-Efficient Build Rules

- Do not work slide-by-slide in a long inspect/fix loop unless the user asks for that level of fidelity.
- First classify the full deck, then rebuild predictable problem types in batches.
- Prefer a strong classroom-ready draft over pixel-perfect conversion.
- Never use low-value extracted images for instructional charts. If a chart has axis labels, data labels, legends, or numerical values, rebuild it as SVG/HTML immediately.
- Rebuild Excel dialogs, formula examples, timeline diagrams, and small calculator screenshots as editable HTML by default.
- Avoid repeatedly reading the full PPTX manifest. Create and use the compact audit table unless deeper detail is needed for a specific slide.
- After the first pass, ask for or wait for targeted slide feedback rather than proactively revising every slide.

## Rebuild Review Pass

Before final delivery, look for slides where the PPTX extraction produced fragile or low-value HTML:

1. Identify slides that are mostly screenshots but contain important instructional text, numbers, formulas, charts, axes, labels, or table values.
2. Recreate those instructional elements as editable HTML/SVG rather than relying on the screenshot.
3. Compare the rebuilt slide against the PPTX intent, not against pixel-perfect positioning.
4. Prefer one clear teaching idea per slide. If a PPTX slide is too dense, split it or summarize it into a readable branded layout.
5. Preserve source examples and numerical accuracy. If a formula, chart, or table is rebuilt, verify the numbers before finalizing.
6. Batch related fixes together before asking the user to review individual slides.
7. Tell the user which slides were interpretive rebuilds rather than literal conversions.

## Image Review Pass

Before final delivery, audit every slide that uses extracted PPTX images:

1. List image-bearing slides from the generated HTML and record each referenced asset.
2. Check each asset's pixel dimensions and aspect ratio using an available local tool such as `sips` on macOS or an image library already available in the workspace.
3. Classify each image by purpose:
   - Full-slide screenshot/reference: use a large 16:9 frame with `object-fit: contain`.
   - Photo or decorative hero: use `object-fit: cover` only when cropping is acceptable.
   - Excel, worksheet, calculator, chart, or UI screenshot: use `object-fit: contain`, never stretch, and place small/narrow crops in a centered fit panel with natural proportions.
   - Tiny screenshot with important numbers or labels: recreate the content as editable HTML text instead of relying on the image.
4. Add reusable CSS classes for image treatments instead of one-off inline sizing. Typical classes include `image-slide`, `fit-panel`, `media`, `compact`, `wide`, `strip`, and `screenshot`.
5. Do not leave important numerical values trapped in images if they are unreadable at presentation size. Rebuild Excel dialogs, formula inputs, calculator rows, tables, or labels as branded HTML.
6. Re-check local image/script references after edits and confirm no missing assets.
7. During browser verification, inspect at least one full-slide image, one small worksheet/screenshot image, and one recreated HTML version of formerly unreadable image text.

## First-Pass Delivery Report

Keep the delivery report concise. Include:

- Output path and preview URL.
- Slide count.
- Major interpretive rebuilds, grouped by type.
- Slides worth human review.
- Any verification that was run.

Do not continue polishing beyond the first classroom-ready pass unless the user gives targeted feedback or asks for deeper fidelity.

## Output Rules

- Use the Refined Hybrid brand exactly: colors, fonts, spacing, and component rules from the reference.
- Use static slide markup, not React loops.
- Use editable HTML text for headings, bullets, card text, numbered statements, and captions.
- Use editable HTML text for important formulas, table values, Excel inputs, function arguments, and numerical results whenever screenshot text would be too small to read.
- Use SVG or HTML/CSS for charts, timelines, diagrams, and formula walkthroughs when the PPTX image/text extraction separates labels from visuals or makes labels unreadable.
- Use local paths under the destination folder for extracted images.
- Keep the original PPTX/JPG reference images available only as hidden/reference assets if useful for review.
- Avoid reveal.js unless the user explicitly asks for reveal.js. The brand-standard scaffold is `deck-stage`.
- Do not create speaker notes unless requested.

## Common Deliverable Shape

```html
<deck-stage width="1920" height="1080" no-rail>
  <section class="slide dark" data-label="01 Title">...</section>
  <section class="slide cream" data-label="02 Agenda">...</section>
</deck-stage>

<div id="tweaks-root" style="position:fixed; bottom:0; right:0; z-index:10000;"></div>
<script src="../deck-stage.js"></script>
<script src="../image-slot.js"></script>
<script type="text/babel" src="../tweaks-panel.jsx"></script>
```

Adjust `../` paths based on the destination folder depth.

## Review Support

For first-pass conversions, include optional reference support when the user will review slide by slide:

- Copy JPG slide exports into `assets/reference/`.
- Add a hidden or toggleable reference overlay only if it does not distract from the branded deck.
- Tell the user which slides are more interpretive than literal because dense PPTX content was simplified.
