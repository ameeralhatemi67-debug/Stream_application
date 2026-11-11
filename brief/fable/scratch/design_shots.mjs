// Renders pages of the Lantern and Arch prototype to PNG files.
// usage: DESIGN_HTML=<file> node design_shots.mjs <outDir> [pageIds|all] [widths] [langs] [themes] [state]
import { createRequire } from 'node:module';
import { mkdirSync } from 'node:fs';
const require = createRequire('C:/Users/User/AppData/Roaming/npm/node_modules/@playwright/cli/');
const { chromium } = require('playwright');
const out = process.argv[2];
const only = process.argv[3] && process.argv[3] !== 'all' ? process.argv[3].split(',') : null;
const widths = (process.argv[4] || '390,1280').split(',');
const langs = (process.argv[5] || 'ar').split(',');
const themes = (process.argv[6] || 'day').split(',');
const state = process.argv[7] || null;
mkdirSync(out, { recursive: true });
const browser = await chromium.launch({ executablePath: 'C:/Users/User/AppData/Local/ms-playwright/chromium_headless_shell-1248/chrome-headless-shell-win64/chrome-headless-shell.exe' });
const page = await browser.newPage({ viewport: { width: 1440, height: 950 }, deviceScaleFactor: 1 });
await page.goto('file:///' + process.env.DESIGN_HTML + '#web-discover');
await page.waitForFunction(() => window.WEB && window.WEB.pages);
await page.waitForTimeout(4000);
const ids = await page.evaluate(() => Object.keys(window.WEB.pages));
const set = (group, v) => page.evaluate(([g, v]) => document.querySelector(`[data-wl="${g}"] button[data-v="${v}"]`).click(), [group, v]);
for (const theme of themes) {
  await set('theme', theme);
  for (const lang of langs) {
    await set('lang', lang);
    for (const w of widths) {
      await set('width', w);
      for (const id of ids) {
        if (only && !only.includes(id)) continue;
        await page.setViewportSize({ width: 1440, height: 950 });
        await page.evaluate((id) => window.WEB.go(id), id);
        await page.waitForTimeout(900);
        if (state) { await page.evaluate((s) => window.WEB.setState(s), state); await page.waitForTimeout(700); }
        const meta = await page.evaluate(() => ({ imm: !!window.WEB.pages[window.WEB.page].immersive, h: document.querySelector('#w-site').offsetHeight }));
        if (!meta.imm) await page.setViewportSize({ width: 1440, height: Math.min(meta.h + 260, 14000) });
        await page.evaluate(() => document.querySelector('#wf').scrollIntoView({ block: 'start' }));
        await page.waitForTimeout(id === 'splash' ? 2600 : 1300);
        const box = await page.evaluate(() => { const r = document.querySelector('#w-site').getBoundingClientRect(); return { x: r.x, y: r.y, width: r.width, height: Math.min(r.height, innerHeight - r.y) }; });
        await page.screenshot({ path: `${out}/${id}${state ? '-' + state : ''}-${w}-${lang}-${theme}.png`, clip: box });
        console.log(id, w, lang, theme, meta.h);
      }
    }
  }
}
await browser.close();
