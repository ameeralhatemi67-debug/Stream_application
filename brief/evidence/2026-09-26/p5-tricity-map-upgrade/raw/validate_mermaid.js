// Parse and render every ```mermaid block in the given markdown files with
// the research pack's pinned Mermaid 11.12.0, offline. Usage:
//   node validate_mermaid.js <mermaid.min.js> <out.json> <file.md>...
const fs = require('fs');
const puppeteer = require('puppeteer-core');
const [, , mermaidJs, outJson, ...files] = process.argv;
(async () => {
  const browser = await puppeteer.launch({
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: 'new',
  });
  const page = await browser.newPage();
  await page.setRequestInterception(true);
  page.on('request', r => r.abort());
  await page.setContent('<!doctype html><html><body></body></html>');
  await page.addScriptTag({ content: fs.readFileSync(mermaidJs, 'utf8') });
  await page.evaluate(() => mermaid.initialize({ startOnLoad: false, securityLevel: 'strict' }));
  const results = [];
  for (const file of files) {
    const text = fs.readFileSync(file, 'utf8');
    const blocks = [...text.matchAll(/```mermaid\s*\r?\n([\s\S]*?)```/g)];
    for (let i = 0; i < blocks.length; i++) {
      try {
        const r = await page.evaluate(async (code, id) => {
          const parsed = await mermaid.parse(code);
          const rendered = await mermaid.render(id, code);
          return { type: parsed.diagramType, svgBytes: rendered.svg.length };
        }, blocks[i][1], 'd' + results.length);
        results.push({ file: file.split(/[\\/]/).pop(), index: i + 1, ok: true, ...r });
      } catch (e) {
        results.push({ file: file.split(/[\\/]/).pop(), index: i + 1, ok: false, error: String(e) });
      }
    }
  }
  await browser.close();
  fs.writeFileSync(outJson, JSON.stringify({ mermaid: '11.12.0', results }, null, 1));
  console.log(JSON.stringify(results));
  process.exit(results.every(r => r.ok) ? 0 : 1);
})();
