# Refined Hybrid BUS Brand

Use this reference when converting PPTX files into Prof. Evitts branded HTML decks.

## Tokens

```css
:root {
  --ink:#0E1116;
  --paper:#FAF8F3;
  --paper-2:#F2EEE5;
  --white:#FFFFFF;
  --text:#1A1F2C;
  --text-soft:#4A5567;
  --muted:#7A8290;
  --border:#E5E1D6;
  --sage:#4A7C5E;
  --gold:#B8843D;
  --terra:#9C4A2B;
  --steel:#355773;
  --gradient:linear-gradient(90deg, #B8843D 0%, #9C4A2B 50%, #4A7C5E 100%);
}
```

Set `--accent` to the course token.

## Course Accent

- BUS123: `--sage`
- BUS210: `--steel`
- BUS311: `--terra`
- BUS331: `--gold`

## Fonts

Load Google Fonts:

```html
<link href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=Geist:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap" rel="stylesheet">
```

- Display: Instrument Serif
- Body/UI: Geist
- Mono labels: JetBrains Mono

Do not use Cinzel, Cormorant Garamond, Inter, DM Mono, Roboto, Arial, Fraunces, or system-font stacks for slide content.

## Type Scale

Author at 1920x1080. Scale the stage, not font sizes.

```css
--type-display:112px;
--type-title:72px;
--type-subtitle:44px;
--type-lead:34px;
--type-body:28px;
--type-small:24px;
--type-eyebrow:24px;
--type-mono:24px;
--type-stat:220px;
```

Never set slide content below 24px.

## Layout

- Dark slides: title, section breaks, close.
- Cream slides: content.
- Gradient bar only on title, section, and close slides.
- Padding: left/right 128px, top 104px, bottom 96px.
- Use 8px radius cards, 1px borders, no text shadows.
- Prefer 1 to 3 visual chunks per slide.
- Use numbered statements instead of long bullet lists.
- Keep images real and relevant. Excel screenshots, charts, logos, and screenshots may remain image assets.

## Required Scaffold

Use:

```html
<deck-stage width="1920" height="1080" no-rail>
  <section class="slide dark" data-label="01 Title">...</section>
</deck-stage>
```

Include `deck-stage.js`, `image-slot.js`, and `tweaks-panel.jsx` with correct relative paths.

