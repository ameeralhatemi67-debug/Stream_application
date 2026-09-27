// Local audit harness. Never uses an owner browser profile or a hosted backend.
const { chromium } = require('C:/Users/User/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '../../../../');
const build = path.join(root, 'project/build/web');
const profile = process.env.PROBE_PROFILE || path.join(process.env.TEMP, 'hadayah-chrome-20260927');
const mime = {'.html':'text/html','.js':'text/javascript','.json':'application/json', '.wasm':'application/wasm', '.svg':'image/svg+xml', '.png':'image/png','.jpg':'image/jpeg'};
let networkMode = 'online';
const server = http.createServer((req, res) => {
  if (networkMode === 'hanging') return;
  if (networkMode === 'offline') { res.destroy(); return; }
  const name = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
  let file = path.resolve(build, '.' + name);
  if (!file.startsWith(build + path.sep) && file !== build) { res.writeHead(403).end(); return; }
  if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(build, 'index.html');
  res.setHeader('Content-Type', mime[path.extname(file)] || 'application/octet-stream');
  res.setHeader('Cache-Control', 'no-store');
  fs.createReadStream(file).pipe(res);
});
const network = [];
let context, page;
function observe(p) {
  p.on('response', r => network.push({url:r.url(), status:r.status(), fromSW:r.fromServiceWorker()}));
  p.on('requestfailed', r => network.push({url:r.url(), failed:r.failure()?.errorText}));
}
async function launch(offline = false) {
  context = await chromium.launchPersistentContext(profile, {
    executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe', headless:true,
    viewport:{width:412,height:860}, args:['--enable-unsafe-swiftshader','--use-angle=swiftshader',
      ...(offline ? ['--host-resolver-rules=MAP * ~NOTFOUND'] : [])],
  });
  page = context.pages()[0] || await context.newPage();
  observe(page);
}
(async () => {
  await new Promise(resolve => server.listen(56090,'127.0.0.1',resolve));
  await launch();
  await page.goto('http://127.0.0.1:56090');
  const control = http.createServer(async (req,res) => {
    let body=''; for await (const part of req) body+=part;
    const q = body ? JSON.parse(body) : {};
    try {
      let result;
      switch(q.op) {
        case 'open': page = await context.newPage(); observe(page); await page.goto('http://127.0.0.1:56090',{timeout:20000,waitUntil:'domcontentloaded'}); break;
        case 'select': page = context.pages()[q.index]; result = context.pages().length; break;
        case 'closePage': await page.close(); page = context.pages()[0]; break;
        case 'restartWorker': {const cdp=await context.newCDPSession(page); await cdp.send('ServiceWorker.enable'); await cdp.send('ServiceWorker.stopAllWorkers'); await cdp.detach(); break;}
        case 'state': result=await page.locator('body').ariaSnapshot(); break;
        case 'enable': await page.locator('flt-semantics-placeholder').dispatchEvent('click'); break;
        case 'click': await page.getByRole(q.role || 'button', {name:q.name,exact:q.exact !== false}).click({timeout:8000}); break;
        case 'eval': result=await page.evaluate(q.code); break;
        case 'shot': await page.screenshot({path:path.join(__dirname,q.name+'.png')}); break;
        case 'offline': networkMode=q.mode; await context.setOffline(q.mode==='offline'); break;
        case 'reload': await page.reload({timeout:20000,waitUntil:'domcontentloaded'}); break;
        case 'cold': await context.close(); networkMode=q.offline?'offline':'online'; await launch(q.offline); await page.goto('http://127.0.0.1:56090',{timeout:20000,waitUntil:'domcontentloaded'}); break;
        case 'network': fs.writeFileSync(path.join(__dirname,q.name+'.json'),JSON.stringify(network,null,2)); result=network.length; break;
        case 'close': await context.close(); server.closeAllConnections(); server.close(); control.close(); break;
        default: throw Error('unknown local probe operation');
      }
      res.end(JSON.stringify({ok:true,result}));
    } catch(error) {res.end(JSON.stringify({ok:false,error:error.message}));}
  });
  control.listen(56091,'127.0.0.1',()=>console.log('Isolated Chrome probe ready on loopback 56091'));
})();
