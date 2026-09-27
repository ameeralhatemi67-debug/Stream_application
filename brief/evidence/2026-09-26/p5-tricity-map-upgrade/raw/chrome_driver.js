// Local-only Chrome driver for G0/acceptance evidence.
// Launches the installed Chrome with a dedicated profile and exposes a tiny
// command API on 127.0.0.1:<port>:  GET /cmd?op=...&...
// ops: goto(url) click(x,y) shot(path) offline(on) eval(js) reload
//      viewport(w,h,dpr) net(path: dump request log) key(k) type(text)
//      wheel(x,y,dy) drag(x1,y1,x2,y2) close relaunch
const http = require('http');
const fs = require('fs');
const puppeteer = require('puppeteer-core');

const [,, port, profileDir, logPath] = process.argv;
const CHROME = 'C:/Program Files/Google/Chrome/Application/chrome.exe';
let browser, page, requests = [], consoleLines = [];

async function launch() {
  browser = await puppeteer.launch({
    executablePath: CHROME,
    headless: 'new',
    userDataDir: profileDir,
    args: ['--no-first-run', '--no-default-browser-check',
           '--enable-unsafe-swiftshader', '--use-angle=swiftshader',
           '--lang=en-US',
           ...(process.env.CHROME_EXTRA ? process.env.CHROME_EXTRA.split('|') : [])],
    defaultViewport: { width: 412, height: 860, deviceScaleFactor: 2, isMobile: true, hasTouch: false },
  });
  page = (await browser.pages())[0] || await browser.newPage();
  attach(page);
}

function attach(p) {
  p.on('request', r => requests.push({ t: Date.now(), url: r.url(), method: r.method(), type: r.resourceType() }));
  p.on('requestfailed', r => requests.push({ t: Date.now(), url: r.url(), failed: r.failure()?.errorText }));
  p.on('response', r => requests.push({ t: Date.now(), url: r.url(), status: r.status(), fromSW: r.fromServiceWorker(), fromCache: r.fromCache() }));
  p.on('console', m => consoleLines.push(`${m.type()}: ${m.text()}`));
}

async function handle(q) {
  const op = q.get('op');
  switch (op) {
    case 'goto': await page.goto(q.get('url'), { waitUntil: 'load', timeout: 60000 }).catch(e => { throw e; }); return 'ok';
    case 'reload': await page.reload({ waitUntil: 'load', timeout: 60000 }); return 'ok';
    case 'click': await page.mouse.click(+q.get('x'), +q.get('y')); return 'ok';
    case 'dblclick': await page.mouse.click(+q.get('x'), +q.get('y'), { clickCount: 2 }); return 'ok';
    case 'wheel': await page.mouse.move(+q.get('x'), +q.get('y')); await page.mouse.wheel({ deltaY: +q.get('dy') }); return 'ok';
    case 'drag': {
      await page.mouse.move(+q.get('x1'), +q.get('y1')); await page.mouse.down();
      const steps = 12;
      for (let i = 1; i <= steps; i++) await page.mouse.move(+q.get('x1') + (q.get('x2') - q.get('x1')) * i / steps, +q.get('y1') + (q.get('y2') - q.get('y1')) * i / steps);
      await page.mouse.up(); return 'ok';
    }
    case 'key': await page.keyboard.press(q.get('k')); return 'ok';
    case 'type': await page.keyboard.type(q.get('text'), { delay: 30 }); return 'ok';
    case 'shot': await page.screenshot({ path: q.get('path') }); return 'ok';
    case 'offline': await page.setOfflineMode(q.get('on') === '1'); return 'offline=' + q.get('on');
    case 'eval': { const r = await page.evaluate(q.get('js')); return JSON.stringify(r); }
    case 'viewport': await page.setViewport({ width: +q.get('w'), height: +q.get('h'), deviceScaleFactor: +(q.get('dpr') || 2), isMobile: q.get('mobile') !== '0' }); return 'ok';
    case 'net': fs.writeFileSync(q.get('path'), JSON.stringify(requests, null, 1)); const n = requests.length; if (q.get('clear') === '1') requests = []; return 'requests=' + n;
    case 'console': { const out = consoleLines.join('\n'); if (q.get('clear') === '1') consoleLines = []; return out; }
    case 'close': await browser.close(); return 'closed';
    case 'relaunch': await launch(); return 'relaunched';
    case 'newpage': page = await browser.newPage(); attach(page); await page.setViewport({ width: 412, height: 860, deviceScaleFactor: 2, isMobile: true }); return 'ok';
    default: return 'unknown op';
  }
}

(async () => {
  await launch();
  http.createServer(async (req, res) => {
    const q = new URL(req.url, 'http://x').searchParams;
    try { res.end(String(await handle(q))); }
    catch (e) { res.statusCode = 500; res.end('ERR ' + e.message); }
  }).listen(+port, '127.0.0.1', () => fs.appendFileSync(logPath, 'driver ready\n'));
})();
