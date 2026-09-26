// Streamer offline shell + map service worker.
//
// The app fills one Cache Storage bucket (CACHE) only when the user chooses
// "Prepare offline map" (lib/features/map/services/map_pack_platform_web.dart).
// This worker never adds entries by itself. On every GET from this origin or
// the two public Flutter/Google font CDNs it tries the network first and
// answers from that bucket only when the network fails or, for a request
// that has a stored copy, takes longer than NETWORK_TIMEOUT_MS (a connected
// network without internet). Other origins (Supabase, YouTube, analytics)
// are never intercepted or cached, so no API, auth or personal response can
// be stored here.
const CACHE = 'streamer-offline-v1';
const PUBLIC_CDNS = ['https://www.gstatic.com', 'https://fonts.gstatic.com'];
const NETWORK_TIMEOUT_MS = 4000;

// Pages whose start came from the stored copy keep using it for every file,
// so one page never mixes files from two different app builds.
const offlinePages = new Set();

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
    const network = fetch(request);
    if (!stored) return network;
    network.catch(() => {}); // a late failure after the timeout is expected
    try {
      return await withTimeout(network, NETWORK_TIMEOUT_MS);
    } catch (networkError) {
      if (request.mode === 'navigate' && event.resultingClientId) {
        offlinePages.add(event.resultingClientId);
      }
      return stored;
    }
  })());
});
