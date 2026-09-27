// Offline documentation check using existing pinned tools, no dependency install.
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const mermaid = 'C:/Users/User/Documents/Amir Ob/projects/Ideas/Current/Streamer_app/brief/research/p5-tricity-map-upgrade/evidence/upstream/mermaid-11.12.0.min.js';
(async () => {
  const browser = await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true});
  try {
    const page = await browser.newPage();
    await page.setContent('<html><body></body></html>');
    await page.addScriptTag({path:mermaid});
    const results = [];
    for (const file of fs.readdirSync(__dirname).filter(n => n.endsWith('.md'))) {
      const blocks = [...fs.readFileSync(path.join(__dirname,file),'utf8').matchAll(/```mermaid\s*\n([\s\S]*?)```/g)];
      for (const [i,block] of blocks.entries()) {
        const result = await page.evaluate(async ({text,id}) => {
          mermaid.initialize({startOnLoad:false,securityLevel:'strict'});
          await mermaid.parse(text);
          const {svg} = await mermaid.render(id,text);
          return {parsed:true,rendered:svg.includes('<svg'),svgBytes:svg.length};
        },{text:block[1],id:`diagram${results.length}`});
        results.push({file,block:i+1,...result});
      }
    }
    if (!results.length || results.some(r => !r.rendered)) throw Error('No valid diagrams');
    fs.writeFileSync(path.join(__dirname,'diagram-validation.json'),JSON.stringify({mermaidVersion:'11.12.0',results},null,2)+'\n');
    console.log(`PASS: ${results.length} Mermaid diagrams parsed and rendered offline`);
  } finally {await browser.close();}
})().catch(error => {console.error(error);process.exitCode=1;});
