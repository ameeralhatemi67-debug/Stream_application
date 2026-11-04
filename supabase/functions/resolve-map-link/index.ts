// Follows a shared Google Maps short link (maps.app.goo.gl/...) and returns the
// place it holds. The browser cannot follow it itself (CORS), so the admins'
// mosque form asks this function. Signed-in callers only (verify_jwt stays on);
// every hop must stay on a Google address over https, so it cannot be used to
// fetch anything else.

const MAX_HOPS = 6;

const headers = {
  'cache-control': 'no-store',
  'access-control-allow-origin': '*',
  'access-control-allow-headers': 'authorization,apikey,content-type,x-client-info',
  'access-control-allow-methods': 'POST,OPTIONS',
  'referrer-policy': 'no-referrer',
};

function allowed(u: URL): boolean {
  if (u.protocol !== 'https:' || u.username || u.password || u.port) return false;
  const h = u.hostname.toLowerCase();
  return h === 'goo.gl' || h === 'maps.app.goo.gl' || h === 'g.co' || h === 'share.google' ||
    /^(?:[a-z0-9-]+\.)*google\.(?:com|[a-z]{2}|com\.[a-z]{2})$/.test(h);
}

const num = '(-?\\d{1,3}(?:\\.\\d+)?)';
const patterns = [
  new RegExp(`!3d${num}!4d${num}`),
  new RegExp(`[?&;](?:q|query|ll|sll|center|destination|daddr|markers)=${num},\\s*${num}`),
  new RegExp(`@${num},${num}`),
];

function place(text: string): {lat: number; lng: number} | null {
  const t = text.replaceAll(/%2C/gi, ',').replaceAll(/%40/g, '@');
  for (const re of patterns) {
    const m = re.exec(t);
    if (!m) continue;
    const lat = Number(m[1]), lng = Number(m[2]);
    if (Math.abs(lat) <= 90 && Math.abs(lng) <= 180 && !(lat === 0 && lng === 0)) return {lat, lng};
  }
  return null;
}

async function follow(start: URL): Promise<{url: string; lat?: number; lng?: number}> {
  let current = start;
  for (let hop = 0; hop <= MAX_HOPS; hop++) {
    if (!allowed(current)) break;
    const found = place(current.toString());
    if (found) return {url: current.toString(), ...found};
    const res = await fetch(current, {
      redirect: 'manual',
      headers: {'user-agent': 'Mozilla/5.0 (compatible; HadayahMapLink/1.0)', 'accept-language': 'en'},
      signal: AbortSignal.timeout(6000),
    });
    const location = res.headers.get('location');
    if (res.status >= 300 && res.status < 400 && location) {
      await res.body?.cancel();
      current = new URL(location, current);
      continue;
    }
    // No coordinates in the address it ended at. The page itself is not read:
    // its map view can be Google's default (Zurich), and a wrong pin is worse
    // than none. The admin is asked to paste the long address instead.
    await res.body?.cancel();
    return {url: current.toString()};
  }
  return {url: current.toString()};
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, {headers});
  if (request.method !== 'POST') return new Response('Method not allowed', {status: 405, headers});
  try {
    const body = await request.json();
    const raw = typeof body?.url === 'string' ? body.url.trim() : '';
    if (raw.length === 0 || raw.length > 600) return Response.json({error: 'bad_url'}, {status: 400, headers});
    const start = new URL(raw);
    if (!allowed(start)) return Response.json({error: 'bad_url'}, {status: 400, headers});
    return Response.json(await follow(start), {headers});
  } catch {
    return Response.json({error: 'unreachable'}, {status: 502, headers});
  }
});
