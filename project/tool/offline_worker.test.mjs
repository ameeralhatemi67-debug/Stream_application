import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const origin = 'https://hadayah.test';
const metaName = 'hadayah-offline-meta-v2';
const source = await readFile(new URL('../web/streamer_offline_sw.js', import.meta.url), 'utf8');
const buckets = new Map();
const key = (r) => typeof r === 'string' ? r : r.url;
const storage = { async keys() { return [...buckets.keys()]; },
  async delete(name) { return buckets.delete(name); }, async open(name) {
  if (!buckets.has(name)) buckets.set(name, new Map());
  const data = buckets.get(name);
  return {
    async keys() { return [...data.keys()].map((url) => ({ url })); },
    async delete(r) { return data.delete(key(r)); },
    async put(r, response) { data.set(key(r), response.clone()); },
    async match(r, options = {}) {
      const target = key(r);
      const entry = [...data.entries()].find(([url]) => options.ignoreSearch
        ? url.split('?')[0] === target.split('?')[0] : url === target);
      return entry?.[1].clone();
    },
  };
} };
const html = (id) => `<meta name="hadayah-build" content="${id}">`;
async function publish(id) {
  const generation = { buildId: id, cacheName: `hadayah-offline-v2-${id}` };
  const cache = await storage.open(generation.cacheName);
  await cache.put(`${origin}/index.html`, new Response(html(id)));
  await cache.put(`${origin}/main.dart.js`, new Response(`code-${id}`));
  await cache.put('https://fonts.gstatic.com/notosansarabic/font.woff2', new Response(`arabic-${id}`));
  await (await storage.open(metaName)).put(`${origin}/__hadayah_offline_active__.json`, new Response(JSON.stringify(generation)));
}
let networkBuild = 'build-old';
let networkMode = 'online';
let networkCalls = 0;
const liveClients = new Set();
const pending = [];
const queues = new Map();
let pruneWorker, registerPage;
let now = Date.now();
const locks = { async request(name, callback) {
  const previous = queues.get(name) || Promise.resolve();
  const next = previous.then(callback);
  queues.set(name, next.catch(() => {}));
  return next;
} };
function worker() {
  const handlers = {};
  vm.runInNewContext(source, {
    caches: storage, URL, Response, AbortController, Date: { now: () => now },
    setTimeout: (fn) => setTimeout(fn, 10), clearTimeout,
    self: { location: { origin }, registration: { scope: `${origin}/` },
      navigator: { locks },
      clients: { claim() {}, async matchAll() { return [...liveClients].map((id) => ({id})); } }, skipWaiting() {},
      addEventListener: (name, callback) => { handlers[name] = callback; } },
    fetch: async (request, { signal } = {}) => {
      networkCalls++;
      if (networkMode === 'offline') throw new Error('offline');
      if (networkMode === 'hanging') return new Promise((_, reject) =>
        signal.addEventListener('abort', () => reject(new Error('aborted'))));
      if (networkMode === 'slow') await new Promise((resolve, reject) => {
        const timer = setTimeout(resolve, 30);
        signal?.addEventListener('abort', () => {
          clearTimeout(timer); reject(new Error('aborted'));
        });
      });
      return new Response(request.mode === 'navigate'
        ? networkBuild ? html(networkBuild) : '<html>Flutter debug</html>'
        : `code-${networkBuild}`);
    },
  });
  registerPage = (id, buildId) => {
    liveClients.add(id);
    let acknowledged = false;
    handlers.message({ data: {type: 'page-build', buildId}, source: {id},
      ports: [{postMessage(value) { acknowledged = value; }}],
      waitUntil(promise) { pending.push(promise); } });
    return Promise.all(pending).then(() => assert.ok(acknowledged));
  };
  pruneWorker = () => handlers.message({ data: 'prune-offline', waitUntil(promise) { pending.push(promise); } });
  return (url, clientId, navigate = false, cache = 'default') => {
    let result;
    liveClients.add(clientId);
    handlers.fetch({ request: { url, method: 'GET', cache, mode: navigate ? 'navigate' : 'cors' },
      clientId, resultingClientId: navigate ? clientId : '',
      waitUntil(promise) { pending.push(promise); },
      respondWith(promise) { result = promise; } });
    return result;
  };
}
await publish('build-old');
let fetchPage = worker();
networkMode = 'offline';
await registerPage('first-claimed-tab', 'build-old');
assert.equal(await (await fetchPage(`${origin}/main.dart.js`, 'first-claimed-tab')).text(), 'code-build-old');
liveClients.delete('first-claimed-tab');
assert.equal(await (await fetchPage(`${origin}/`, 'old-tab', true)).text(), html('build-old'));
fetchPage = worker(); // worker termination destroys all global state
networkMode = 'hanging';
const before = networkCalls;
assert.equal(await (await fetchPage('https://fonts.gstatic.com/notosansarabic/font.woff2', 'old-tab')).text(), 'arabic-build-old');
assert.equal(networkCalls, before, 'pinned files never wait for a hanging network');
networkMode = 'online'; networkBuild = 'build-new';
await fetchPage(`${origin}/`, 'new-tab', true);
networkMode = 'offline';
await assert.rejects(fetchPage(`${origin}/main.dart.js`, 'new-tab'), /offline/);
await publish('build-new');
assert.equal(await (await fetchPage(`${origin}/main.dart.js`, 'new-tab')).text(), 'code-build-new');
assert.equal(await (await fetchPage(`${origin}/main.dart.js`, 'old-tab')).text(), 'code-build-old');
fetchPage = worker();
assert.equal(await (await fetchPage(`${origin}/main.dart.js`, 'old-tab')).text(), 'code-build-old');
networkMode = 'hanging';
assert.equal(await (await fetchPage(`${origin}/`, 'cold-tab', true)).text(), html('build-new'));
assert.equal(fetchPage(`${origin}/main.dart.js`, 'new-tab', false, 'reload'), undefined);
assert.equal(fetchPage('https://private-backend.test/rest/v1/profiles', 'new-tab'), undefined);
await Promise.all(pending);
pruneWorker();
await Promise.all(pending);
assert.ok(buckets.has('hadayah-offline-v2-build-old'), 'open old tab retains its generation');
// An in-flight navigation can be absent from matchAll while another tab prunes.
networkMode = 'online'; networkBuild = 'build-new';
await fetchPage(`${origin}/`, 'reserved-tab', true);
await publish('build-next');
liveClients.delete('reserved-tab');
pruneWorker(); await Promise.all(pending);
networkMode = 'offline';
assert.equal(await (await fetchPage(`${origin}/main.dart.js`, 'reserved-tab')).text(), 'code-build-new');
liveClients.delete('reserved-tab');
liveClients.delete('old-tab');
now += 5 * 60 * 1000 + 1;
await fetchPage(`${origin}/`, 'cold-tab', true);
pruneWorker();
await Promise.all(pending);
assert.ok(!buckets.has('hadayah-offline-v2-build-old'), 'closed old tab is reclaimed after the reserved-client grace');
for (const path of ['packages/streamer_app/features/auth/presentation/welcome_screen.dart.lib.js',
  'packages/streamer_app/core/widgets/floating_stream_mini_player.dart.lib.js',
  'dart_sdk.js', 'ddc_module_loader.js', 'main_module.bootstrap.js', 'stack_trace_mapper.js']) {
  assert.equal(fetchPage(`${origin}/${path}`, 'debug-tab'), undefined,
    'debug modules bypass both offline caching and its timeout');
}
networkMode = 'online'; networkBuild = null;
await fetchPage(`${origin}/`, 'unstamped-debug-tab', true);
networkMode = 'slow';
assert.equal(await (await fetchPage(`${origin}/main.dart.js`, 'unstamped-debug-tab')).text(),
  'code-null', 'unstamped debug entrypoint survives a response slower than the offline timeout');
// WEB-01: the timeout bounds time-to-headers only; bodies stream through untouched.
assert.ok(!source.slice(source.indexOf('async function boundedFetch'),
    source.indexOf('async function storedResponse')).includes('arrayBuffer'),
  'boundedFetch must not buffer (and so cannot time out) large response bodies');
console.log('PASS: initial claimed page, reserved-client concurrent prune, bounded orphan cleanup, cold start, durable worker restart, hanging network, app-only update, concurrent tabs, preparation bypass, backend exclusion, DDC bypass, slow unstamped startup');
