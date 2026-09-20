# DESIGN PROMPT — run this first (about 6-10 % of a window), in its own session, before the main run

Purpose: get **three complete design schemes** to choose from. Each one shows colours, gradients, text, the logo/icon and several real-looking screens of the app, side by side in one preview page. You pick one by writing `DESIGN_CHOICE=A` (or B or C) in `brief/05_DECISIONS.md`; the main run then rebuilds the theme, typography, logo and icon from that choice (03 P4.1 and P8A.0). This replaces the old separate logo step. Works in Codex (Astra) or Claude Code. Needs nothing from you except the app names already in 05.

Your gradient taste is captured in `brief/assets/gradient_reference.png` (four soft diagonal two-colour gradients: pink to red, green to light green, lavender to periwinkle, amber to peach).

--- paste from here ---
Design three complete, clearly different design schemes for this app, then stop. Nobody will answer questions: decide and go.

**App.** "Hadayah Live" / "منصة هدايه" (names exactly as in `brief/05_DECISIONS.md`): live educational lectures in Saudi Arabia, Arabic-first (RTL) with English, phone-first, calm and trustworthy. The owner wants the whole app recoloured to a **clean white theme**. The current app is dark-only with a coral accent; for context Grep the tokens in `project/lib/core/theme/app_theme.dart` and read only the headings of `Core_files/Desgin.md`. Do not explore anything else.

**Budget.** Run `node brief/tools/budget_check.mjs --plan single --new-run` first and note `used_5h`. Stop and report if it shows STOP or UNKNOWN, or if `used_5h` rises more than 12 points above your start value. No subagents, no new plugins or MCP servers. Keep it cheap: build each screen ONCE as an HTML/CSS template driven by CSS custom properties, and let each scheme only change the variables (colours, gradients, fonts, radii, shadows, density) and its logo, so three schemes cost little more than one.

**What each scheme must show** (all in one `preview.html`, tabs or stacked, with an Arabic/English toggle that flips `dir`):
1. **Colours.** Named roles with hex: background, surface, surfaceAlt, border, textPrimary, textSecondary, textMuted, primary, onPrimary, accent, success, warning, danger, live. A contrast table computed by a small script (text on background at least 4.5:1, UI parts at least 3:1) printed in the page.
2. **Gradients**, following the rules below.
3. **Text.** An Arabic + Latin font pair under an open licence (OFL or similar) that supports both scripts well, with weights, a type scale (display, title, body, caption, numerals) and Arabic-friendly line heights. The app will bundle these fonts as assets, never download them at runtime (offline use). The preview may load them from Google Fonts.
4. **Icon and logo.** Original mark, no text inside it, at 48 / 96 / 192 px, in circle / squircle / rounded-square masks, plus a one-colour silhouette (it becomes the Android monochrome icon).
5. **Shape language and components.** Corner radii, elevation or borders, density, icon style; primary and secondary button, chip, input, card, live badge, bottom navigation, dialog.
6. **Screens** in 360x720 phone frames: welcome, feed (include a live card and a normal card), live room (video area, viewer count, chat), map (map area with markers and a bottom sheet), settings. Sample copy in Arabic and English lives only in the preview and is never copied into the app.

**How to make the three differ.** Use different hue families from the reference image, for example a green scheme, a lavender/periwinkle scheme and a coral-pink scheme, each with its own type pair, radii and logo idea. Amber is available as an accent or warning colour. Keep every scheme calm and educational, not playful or neon.

**Gradient rules (the owner wants gradients, used with intent, never spammed).**
- Two or three named gradient tokens per scheme (for example `brand`, `soft`, `live`), each with two stops (three at most) from one hue family (no more than about 40 degrees of hue shift), all at the same angle: from top-start to bottom-end, exactly like the reference (it mirrors in RTL).
- Use them only for: the primary button fill (one per screen), the logo/icon tile, the welcome hero, the live badge or live ring, and small accents such as progress or an empty-state illustration. Everything else stays flat white or neutral: app bars, navigation bars, list cards, dialogs, inputs, borders, body text backgrounds.
- At most two gradient surfaces visible on any one screen; print the count per screen in the preview.
- Text on a gradient needs at least 4.5:1 against BOTH stops (verify with the script), otherwise put the text on a flat colour. No gradient text, no animated gradients, disabled controls stay flat grey.
- The white background is the star: gradients are accents on top of it.

**Logo rules.** Original work: no resemblance to other apps' marks (YouTube, Twitch, Zoom and so on), no religious iconography or calligraphy (no mosque, Kaaba, Quran, Allah, crescent and star), no national emblem, flag or state symbol. Hand-written SVG, `viewBox="0 0 1024 1024"`, under 6 KB, groups `<g id="bg">` and `<g id="mark">`, everything in `mark` inside a circle of radius 300 around the centre (Android adaptive safe zone), the mark at most 3 flat colours, the tile may use the scheme's `brand` gradient.

**Files** (folder `brief/assets/design_options/`):
- `preview.html`
- `tokens_A.json`, `tokens_B.json`, `tokens_C.json`: machine-readable roles to hex, gradients (name, stops, begin, end), fonts (family, weights, file names to bundle, licence), type scale, radii, spacing, shadows, and the logo file name. The main run reads only the chosen file.
- `logo_A.svg`, `logo_B.svg`, `logo_C.svg`
- `NOTES.md`: per scheme three lines (idea, best for, risk), the font licences, and the contrast numbers.

**Check by looking.** Screenshot each scheme's welcome, feed and live screens in Arabic at 360 px wide with the browser you have (headless Chromium or Playwright if present), look at the images, fix clipping or weak contrast once. If nothing can render, say so and mark the schemes "not visually checked".

**Finish.** Stage only the files above by explicit path and commit locally (no push). Reply in at most 10 lines: one line per scheme, the path of `preview.html`, and "set `DESIGN_CHOICE=A|B|C` in brief/05_DECISIONS.md". Do not touch app code, icons or pubspec: the main run applies the choice.
--- end ---
