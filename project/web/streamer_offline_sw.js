// Streamer offline shell + map service worker.
//
// The app fills one Cache Storage bucket (CACHE) only when the user chooses
// "Prepare offline map" (lib/features/map/services/map_pack_platform_web.dart).
// This worker never adds entries by itself. On every GET from this origin or
// the two public Flutter/Google font CDNs it tries the network first and, only
// when the network fails, answers from that bucket. Other origins (Supabase,
// YouTube, analytics) are never intercepted or cached, so no API, auth or
// personal response can be stored here.
const CACHE = 'streamer-offline-v1';
const PUBLIC_CDNS = ['https://www.gstatic.com', 'https://fonts.gstatic.com'];

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  const url = new URL(request.url);
  const sameOrigin = url.origin === self.location.origin;
  if (!sameOrigin && !PUBLIC_CDNS.includes(url.origin)) return;
  event.respondWith((async () => {
    try {
      return await fetch(request);
    } catch (networkError) {
      const cache = await caches.open(CACHE);
      let hit = await cache.match(request, { ignoreSearch: true });
      if (!hit && request.mode === 'navigate') {
        hit = await cache.match(new URL('index.html', self.registration.scope).href);
      }
      if (hit) return hit;
      throw networkError;
    }
  })());
});
