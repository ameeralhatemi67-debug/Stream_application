// Save creates an immutable app + map generation. Never cache network/API responses.
const META = 'hadayah-offline-meta-v2';
const ACTIVE = '__hadayah_offline_active__.json';
const PUBLIC_CDNS = ['https://www.gstatic.com', 'https://fonts.gstatic.com'];
const NETWORK_TIMEOUT_MS = 4000;
// ponytail: retain recent reserved clients for five minutes because matchAll()
// omits a navigation until commit. Revisit this grace if startup can exceed it.
const PIN_GRACE_MS = 5 * 60 * 1000;
const absolute = (path) => new URL(path, self.registration.scope).href;
const pinPath = (id) => absolute(`__hadayah_client__/${encodeURIComponent(id)}`);
const locked = (action) => self.navigator.locks.request('hadayah-publish', action);
async function record(key) {
  const response = await (await caches.open(META)).match(key);
  return response ? response.json() : null;
}
async function pin(id, value) {
  if (id) await (await caches.open(META)).put(pinPath(id),
    new Response(JSON.stringify({ ...value, pinnedAt: Date.now() }),
      { headers: { 'content-type': 'application/json' } }));
}
async function boundedFetch(request) {
  const abort = new AbortController();
  const timer = setTimeout(() => abort.abort(), NETWORK_TIMEOUT_MS);
  try {
    const response = await fetch(request, { signal: abort.signal });
    const body = await response.arrayBuffer();
    return new Response(body, { status: response.status, statusText: response.statusText,
      headers: response.headers });
  } finally { clearTimeout(timer); }
}
async function storedResponse(generation, request, navigate) {
  if (!generation?.cacheName) return null;
  const cache = await caches.open(generation.cacheName);
  return (await cache.match(request, { ignoreSearch: true })) ||
    (navigate ? await cache.match(absolute('index.html')) : null);
}
self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));
// Save/reset and cleanup share a lock. Navigation only takes the short publication
// lock, so downloading an update never stalls other tabs.
async function prune() {
  await self.navigator.locks.request('hadayah-save', () => locked(async () => {
    const metadata = await caches.open(META);
    const clients = new Set((await self.clients.matchAll({ includeUncontrolled: true }))
      .map((client) => pinPath(client.id)));
    const keep = new Set([(await record(absolute(ACTIVE)))?.cacheName]);
    for (const request of await metadata.keys()) {
      if (!request.url.includes('/__hadayah_client__/')) continue;
      const page = await record(request);
      if (clients.has(request.url) || Date.now() - page?.pinnedAt < PIN_GRACE_MS) {
        keep.add(page?.cacheName);
      }
      else await metadata.delete(request);
    }
    for (const name of await caches.keys()) {
      if (name.startsWith('hadayah-offline-v2-') && !keep.has(name)) {
        await caches.delete(name);
      }
    }
  }));
}
self.addEventListener('message', (event) => {
  if (event.data === 'prune-offline') event.waitUntil(prune());
  // The first page predates this worker's claim, so no navigation fetch pinned
  // its build. Identify that page before it can prepare its first offline copy.
  if (event.data?.type === 'page-build' && event.source?.id &&
      /^[a-zA-Z0-9._-]+$/.test(event.data.buildId)) {
    event.waitUntil(locked(async () => {
      const current = await record(pinPath(event.source.id));
      if (current?.buildId === event.data.buildId) return;
      const active = await record(absolute(ACTIVE));
      await pin(event.source.id, { buildId: event.data.buildId,
        cacheName: active?.buildId === event.data.buildId ? active.cacheName : null });
    }).then(() => {
      event.ports?.[0]?.postMessage(true);
      return prune();
    }).catch(() => event.ports?.[0]?.postMessage(false)));
  }
});
self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (!self.navigator.locks) return;
  if (request.method !== 'GET' || request.cache === 'reload') return;
  const url = new URL(request.url);
  if (url.origin !== self.location.origin && !PUBLIC_CDNS.includes(url.origin)) return;
  // DDC loads hundreds of mutable modules concurrently. The offline timeout
  // can abort these and leave Dart libraries undefined; let Chrome load them.
  if (/\.dart\.lib\.js(?:\.map)?$|\/(?:dart_sdk|ddc_module_loader|main_module\.bootstrap|stack_trace_mapper)\.js$/.test(url.pathname)) return;
  const result = (async () => {
    if (request.mode === 'navigate') {
      try {
        const response = await boundedFetch(request);
        if (!response.ok) throw new Error('navigation unavailable');
        const html = await response.clone().text();
        const buildId = html.match(/<meta name="hadayah-build" content="([a-zA-Z0-9._-]+)">/)?.[1];
        await locked(async () => {
          const active = await record(absolute(ACTIVE));
          await pin(event.resultingClientId, { buildId,
            cacheName: buildId && active?.buildId === buildId ? active.cacheName : null });
        });
        return response;
      } catch (error) {
        return locked(async () => {
          const active = await record(absolute(ACTIVE));
          const stored = await storedResponse(active, request, true);
          if (!stored) throw error;
          await pin(event.resultingClientId, active);
          return stored;
        });
      }
    }
    // Durable client pins survive worker termination and concurrent tab updates.
    let page = event.clientId ? await record(pinPath(event.clientId)) : null;
    // Unstamped development pages have no immutable offline generation.
    if (!page?.buildId) return fetch(request);
    if (page?.buildId && !page.cacheName) {
      await locked(async () => {
        const active = await record(absolute(ACTIVE));
        if (active?.buildId === page.buildId) {
          page = active;
          await pin(event.clientId, page);
        }
      });
    }
    const stored = await storedResponse(page, request, false);
    if (stored) return stored;
    // An unprepared update must fail visibly rather than mix app builds.
    return boundedFetch(request);
  })();
  event.respondWith(result);
});
