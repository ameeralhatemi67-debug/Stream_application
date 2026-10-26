// The newest published Android APK (public.app_releases, ADR-017), for the download page.
//   GET /api/app-release              -> its version, size, checksum, date and notes (JSON)
//   GET /api/app-release?download=1   -> 302 to the APK file itself (also served as /download/android)
// Reads Supabase with the public anon key from Vercel's environment; row-level security already
// limits guests to published releases. The link is only followed when it is HTTPS on the Supabase
// project or the site's own public origin, or the app's Play listing (the last APK release once
// the app is on Google Play), so a mistyped row cannot redirect elsewhere.

export function allowedHosts(env) {
  const hosts = new Set();
  for (const name of ['SUPABASE_URL', 'PUBLIC_APP_URL']) {
    try { if (env[name]) hosts.add(new URL(env[name]).host); } catch { /* ignore a malformed value */ }
  }
  return hosts;
}

export function isPlayListing(url) {
  return url.host === 'play.google.com' && url.pathname === '/store/apps/details' &&
    url.searchParams.get('id') === 'sa.hadayah.streamer_app';
}

export function publicRelease(row, hosts) {
  if (!row || typeof row !== 'object') return null;
  let url;
  try { url = new URL(row.download_url); } catch { return null; }
  if (url.protocol !== 'https:' || url.port !== '') return null;
  if (!hosts.has(url.host) && !isPlayListing(url)) return null;
  if (!Number.isInteger(row.version_code) || typeof row.version_name !== 'string') return null;
  return {
    versionCode: row.version_code,
    versionName: row.version_name,
    downloadUrl: url.toString(),
    onGooglePlay: isPlayListing(url),
    sha256: typeof row.sha256 === 'string' ? row.sha256 : null,
    sizeBytes: Number.isFinite(row.size_bytes) ? row.size_bytes : null,
    publishedAt: typeof row.published_at === 'string' ? row.published_at : null,
    notesEn: typeof row.notes_en === 'string' ? row.notes_en : '',
    notesAr: typeof row.notes_ar === 'string' ? row.notes_ar : '',
  };
}

export function createHandler({ fetchImpl = fetch, env = process.env } = {}) {
  return async (req, res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    const fail = (status, error) => {
      res.setHeader('Cache-Control', 'no-store');
      return res.status(status).json({ error });
    };
    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.setHeader('Allow', 'GET, HEAD');
      return fail(405, 'method_not_allowed');
    }
    const base = env.SUPABASE_URL?.trim();
    const key = env.SUPABASE_ANON_KEY?.trim();
    if (!base || !key) return fail(503, 'release_unavailable');
    const query = new URL('/rest/v1/app_releases', base);
    query.searchParams.set('select',
      'version_code,version_name,download_url,sha256,size_bytes,published_at,notes_en,notes_ar');
    query.searchParams.set('channel', 'eq.apk');
    query.searchParams.set('order', 'version_code.desc');
    query.searchParams.set('limit', '1');
    let release;
    try {
      const response = await fetchImpl(query, {
        method: 'GET', redirect: 'error', signal: AbortSignal.timeout(8000),
        headers: { apikey: key, Authorization: `Bearer ${key}`, Accept: 'application/json' },
      });
      if (!response.ok) return fail(502, 'release_unavailable');
      const rows = await response.json();
      if (!Array.isArray(rows)) return fail(502, 'release_unavailable');
      if (rows.length === 0) return fail(404, 'no_release');
      release = publicRelease(rows[0], allowedHosts(env));
    } catch {
      return fail(502, 'release_unavailable');
    }
    if (!release) return fail(502, 'release_unavailable');
    // A new release reaches the page and the short link within a minute.
    res.setHeader('Cache-Control', 'public, max-age=0, s-maxage=60, stale-while-revalidate=300');
    const download = new URL(req.url, 'https://localhost').searchParams.get('download');
    if (download === '1') {
      res.setHeader('Location', release.downloadUrl);
      return res.status(302).end();
    }
    return res.status(200).json(release);
  };
}

export default createHandler();
