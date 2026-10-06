// Public Data API reads only. No OAuth credentials, writes, arbitrary URLs or
// client-supplied keys/headers are accepted. The key stays in Vercel's env.
const channelId = /^UC[A-Za-z0-9_-]{22}$/;
const videoId = /^[A-Za-z0-9_-]{11}$/;
const playlistId = /^[A-Za-z0-9_-]{10,100}$/;
const handle = /^[\p{L}\p{M}\p{N}._\-·]{1,100}$/u;

export function validateQuery(rawUrl) {
  const input = new URL(rawUrl, 'https://localhost').searchParams;
  const q = Object.fromEntries(input);
  if ([...input.keys()].some(key => input.getAll(key).length !== 1)) return null;
  const allowed = ['resource', 'part'];
  let valid = false;
  switch (q.resource) {
    case 'channels': {
      allowed.push('id', 'forHandle', 'forUsername');
      const selectors = allowed.slice(2).filter(key => q[key] !== undefined);
      valid = q.part === 'snippet,contentDetails' && selectors.length === 1 &&
        (selectors[0] === 'id' ? channelId : handle).test(q[selectors[0]]);
      break;
    }
    case 'playlistItems':
      allowed.push('playlistId', 'maxResults');
      valid = q.part === 'snippet,contentDetails' && playlistId.test(q.playlistId ?? '');
      break;
    case 'playlists':
      allowed.push('channelId', 'maxResults');
      valid = q.part === 'snippet,contentDetails' && channelId.test(q.channelId ?? '');
      break;
    case 'videos': {
      allowed.push('id');
      const ids = (q.id ?? '').split(',');
      valid = ['statistics', 'liveStreamingDetails', 'snippet,liveStreamingDetails', 'snippet,statistics'].includes(q.part) &&
        ids.length <= 50 && ids.every(id => videoId.test(id));
      break;
    }
    case 'search':
      allowed.push('channelId', 'eventType', 'type');
      valid = q.part === 'snippet' && channelId.test(q.channelId ?? '') &&
        q.eventType === 'live' && q.type === 'video';
      break;
  }
  if (!valid || Object.keys(q).some(key => !allowed.includes(key))) return null;
  if (allowed.includes('maxResults') && !/^(?:[1-9]|[1-4][0-9]|50)$/.test(q.maxResults ?? '')) return null;
  const upstream = new URL(`https://www.googleapis.com/youtube/v3/${q.resource}`);
  for (const key of Object.keys(q).sort()) if (key !== 'resource') upstream.searchParams.set(key, q[key]);
  // Search costs considerably more quota. Only one live result is needed.
  if (q.resource === 'search') upstream.searchParams.set('maxResults', '1');
  return { upstream, ttl: q.resource === 'videos' || q.resource === 'search' ? 15 : 300 };
}

export function createHandler({ fetchImpl = fetch, getKey = () => process.env.YOUTUBE_API_KEY } = {}) {
  return async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    const fail = (status, error) => res.status(status).json({ error });
    if (req.method !== 'GET') {
      res.setHeader('Allow', 'GET');
      return fail(405, 'method_not_allowed');
    }
    // Do not offer a cross-site browser API. This is an additional browser
    // boundary, not authentication or a substitute for provider quota limits.
    if (req.headers['sec-fetch-site'] === 'cross-site') return fail(403, 'forbidden');
    const query = validateQuery(req.url);
    if (!query) return fail(400, 'invalid_query');
    const key = getKey()?.trim();
    if (!key) return fail(503, 'youtube_unavailable');
    try {
      const response = await fetchImpl(query.upstream, {
        method: 'GET', redirect: 'error', signal: AbortSignal.timeout(8000),
        headers: { 'X-Goog-Api-Key': key },
      });
      // Never expose upstream errors or exception text containing the key URL.
      if (!response.ok) return fail(502, 'youtube_unavailable');
      const data = await response.json();
      if (!Array.isArray(data.items)) return fail(502, 'youtube_unavailable');
      res.setHeader('Cache-Control', `public, max-age=0, s-maxage=${query.ttl}, stale-while-revalidate=30`);
      return res.status(200).json({ items: data.items });
    } catch {
      return fail(502, 'youtube_unavailable');
    }
  };
}

export default createHandler();
