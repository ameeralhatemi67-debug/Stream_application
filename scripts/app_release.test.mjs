import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHandler, publicRelease, allowedHosts } from '../api/app-release.mjs';

const env = {
  SUPABASE_URL: 'https://project.supabase.co',
  SUPABASE_ANON_KEY: 'public-anon-test',
  PUBLIC_APP_URL: 'https://hadayah.example',
};
const row = {
  version_code: 3,
  version_name: '1.0.2',
  download_url: 'https://project.supabase.co/storage/v1/object/public/app-releases/hadayah-live-1.0.2.apk',
  sha256: 'a'.repeat(64),
  size_bytes: 41000000,
  published_at: '2026-10-26T08:00:00Z',
  notes_en: 'Faster maps',
  notes_ar: 'خرائط أسرع',
};
function response() {
  return {
    headers: {}, code: null, body: null, ended: false,
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.code = code; return this; },
    json(body) { this.body = body; return this; },
    end() { this.ended = true; return this; },
  };
}
const req = (url = '/api/app-release', method = 'GET') => ({ url, method, headers: {} });
function fetchReturning(rows, seen = []) {
  return async (url, init) => {
    seen.push({ url: new URL(url), init });
    return { ok: true, json: async () => rows };
  };
}

test('asks Supabase for the newest APK row with the public key', async () => {
  const seen = [];
  const res = response();
  await createHandler({ env, fetchImpl: fetchReturning([row], seen) })(req(), res);
  assert.equal(res.code, 200);
  assert.equal(res.body.versionName, '1.0.2');
  assert.equal(res.body.sizeBytes, 41000000);
  assert.equal(res.body.notesAr, 'خرائط أسرع');
  const { url, init } = seen[0];
  assert.equal(url.origin + url.pathname, 'https://project.supabase.co/rest/v1/app_releases');
  assert.equal(url.searchParams.get('channel'), 'eq.apk');
  assert.equal(url.searchParams.get('order'), 'version_code.desc');
  assert.equal(url.searchParams.get('limit'), '1');
  assert.equal(init.headers.apikey, 'public-anon-test');
  assert.equal(init.redirect, 'error');
  assert.match(res.headers['Cache-Control'], /s-maxage=60/);
});

test('download=1 redirects to the file', async () => {
  const res = response();
  await createHandler({ env, fetchImpl: fetchReturning([row]) })(req('/api/app-release?download=1'), res);
  assert.equal(res.code, 302);
  assert.equal(res.headers.Location, row.download_url);
  assert.ok(res.ended);
});

test('a link to another host, plain http or a port is never followed', () => {
  const hosts = allowedHosts(env);
  assert.ok(publicRelease(row, hosts));
  assert.ok(publicRelease({ ...row, download_url: 'https://hadayah.example/download/a.apk' }, hosts));
  const moved = publicRelease({ ...row, sha256: null, size_bytes: null,
    download_url: 'https://play.google.com/store/apps/details?id=sa.hadayah.streamer_app' }, hosts);
  assert.equal(moved.onGooglePlay, true, 'the last APK release may point at the Play listing');
  assert.equal(publicRelease(row, hosts).onGooglePlay, false);
  assert.equal(publicRelease({ ...row,
    download_url: 'https://play.google.com/store/apps/details?id=com.other.app' }, hosts), null);
  for (const bad of ['https://evil.example/a.apk', 'http://project.supabase.co/a.apk',
    'https://project.supabase.co:8443/a.apk', 'javascript:alert(1)', 'not a url']) {
    assert.equal(publicRelease({ ...row, download_url: bad }, hosts), null, bad);
  }
});

test('no release, an upstream error or missing settings answer without caching', async () => {
  let res = response();
  await createHandler({ env, fetchImpl: fetchReturning([]) })(req(), res);
  assert.equal(res.code, 404);
  assert.equal(res.headers['Cache-Control'], 'no-store');

  res = response();
  await createHandler({ env, fetchImpl: async () => ({ ok: false }) })(req(), res);
  assert.equal(res.code, 502);

  res = response();
  await createHandler({ env, fetchImpl: async () => { throw new Error('down'); } })(req(), res);
  assert.equal(res.code, 502);
  assert.equal(JSON.stringify(res.body).includes('down'), false);

  res = response();
  await createHandler({ env: {}, fetchImpl: fetchReturning([row]) })(req(), res);
  assert.equal(res.code, 503);

  res = response();
  await createHandler({ env, fetchImpl: fetchReturning([{ ...row, download_url: 'https://evil.example/a.apk' }]) })(
    req('/api/app-release?download=1'), res);
  assert.equal(res.code, 502);
  assert.equal(res.headers.Location, undefined);
});

test('only GET and HEAD', async () => {
  const res = response();
  await createHandler({ env, fetchImpl: fetchReturning([row]) })(req('/api/app-release', 'POST'), res);
  assert.equal(res.code, 405);
});
