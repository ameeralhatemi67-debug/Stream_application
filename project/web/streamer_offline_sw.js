// Streamer offline shell + map service worker.
//
// The app fills one Cache Storage bucket (CACHE) only when the user chooses
// "Prepare offline map" (lib/features/map/services/map_pack_platform_web.dart).
// This worker never adds entries by itself. On every GET from this origin or
// the two public Flutter/Google font CDNs it tries the network first and
// answers from that bucket only when the network fails or, for a page load
// that has a stored copy, takes longer than NETWORK_TIMEOUT_MS (a connected
// network without internet). A page that started from the stored copy takes
// every file from it; a page that started from the network waits for the
// network for its files, so one page never mixes two app builds. Other origins (Supabase, YouTube, analytics)
// are never intercepted or cached, so no API, auth or personal response can
// be stored here.
const CACHE = 'streamer-offline-v1';
const PUBLIC_CDNS = ['https://www.gstatic.com', 'https://fonts.gstatic.com'];
const NETWORK_TIMEOUT_MS = 4000;

// Pages whose start came from the stored copy keep using it for every file,
// so one page never mixes files from two different app builds. Closed pages
// are dropped at the next page load.
const offlinePages = new Set();

async function forgetClosedPages() {
  const open = new Set((await self.clients.matchAll({ type: 'window' })).map((c) => c.id));
  for (const id of offlinePages) {
    if (!open.has(id)) offlinePages.delete(id);
  }
}

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

function withTimeout(promise, ms) {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('network timeout')), ms);
    promise.then(
      (value) => { clearTimeout(timer); resolve(value); },
      (error) => { clearTimeout(timer); reject(error); },
    );
  });
}

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  const sameOrigin = url.origin === self.location.origin;
  if (!sameOrigin && !PUBLIC_CDNS.includes(url.origin)) return;
  // The app's own preparation downloads use `cache: 'reload'`: they must
  // come from the network, never from the old offline copy.
  if (request.cache === 'reload') return;
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    let stored = await cache.match(request, { ignoreSearch: true });
    if (!stored && request.mode === 'navigate') {
      stored = await cache.match(new URL('index.html', self.registration.scope).href);
    }
    if (stored && offlinePages.has(event.clientId)) return stored;
    const navigate = request.mode === 'navigate';
    if (navigate) event.waitUntil(forgetClosedPages().catch(() => {}));
    const network = fetch(request);
    if (!stored) return network;
    network.catch(() => {}); // a late failure after the timeout is expected
    try {
      // Only a page load gives up on a slow network; a file for a page that
      // came from the network waits for it (or its failure).
      return await (navigate ? withTimeout(network, NETWORK_TIMEOUT_MS) : network);
    } catch (networkError) {
      if (navigate && event.resultingClientId) {
        offlinePages.add(event.resultingClientId);
      }
      return stored;
    }
  })());
});
