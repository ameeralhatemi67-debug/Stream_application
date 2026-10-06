import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHandler, validateQuery } from '../api/youtube.mjs';

const channel = 'UCah56qawts736uNxZA3inLQ';
const request = `/api/youtube?resource=channels&part=snippet,contentDetails&forHandle=ahmedamercaller`;
function response() {
  return {
    headers: {}, code: null, body: null,
    setHeader(name, value) { this.headers[name] = value; },
    status(code) { this.code = code; return this; },
    json(body) { this.body = body; return this; },
  };
}
function req(url = request, method = 'GET', headers = {}) { return { url, method, headers }; }

test('only bounded public reads accepted; arbitrary URLs, keys, OAuth, duplicates and parts rejected', () => {
  for (const suffix of ['&key=stolen', '&access_token=token', '&url=https://evil.example', '&forHandle=other', '&mine=true', '&part=id']) {
    assert.equal(validateQuery(request + suffix), null);
  }
  for (const url of [
    '/?resource=delete&part=snippet',
    '/?resource=channels&part=snippet,contentDetails',
    `/?resource=channels&part=snippet,contentDetails&id=${channel}&forHandle=other`,
    '/?resource=videos&part=statistics&id=bad',
    '/?resource=videos&part=statistics&id=' + Array(51).fill('bl60n6uuvWE').join(','),
    `/?resource=search&part=snippet&channelId=${channel}&eventType=live&type=video&q=arbitrary`,
    '/?resource=playlistItems&part=snippet,contentDetails&playlistId=PLabcdefghijk&maxResults=500',
  ]) assert.equal(validateQuery(url), null, url);
});

test('channel, archive, playlist, statistics, watch and live read shapes accepted', () => {
  const urls = [request,
    `/?resource=channels&part=snippet,contentDetails&id=${channel}`,
    '/?resource=channels&part=snippet,contentDetails&forUsername=someuser',
    '/?resource=playlistItems&part=snippet,contentDetails&playlistId=UUah56qawts736uNxZA3inLQ&maxResults=25',
    `/?resource=playlists&part=snippet,contentDetails&channelId=${channel}&maxResults=10`,
    '/?resource=videos&part=statistics&id=bl60n6uuvWE,abcdefghijk',
    '/?resource=videos&part=snippet,statistics&id=bl60n6uuvWE,abcdefghijk',
    '/?resource=videos&part=liveStreamingDetails&id=bl60n6uuvWE',
    '/?resource=videos&part=snippet,liveStreamingDetails&id=bl60n6uuvWE',
    `/?resource=search&part=snippet&channelId=${channel}&eventType=live&type=video`,
  ];
  for (const url of urls) {
    const query = validateQuery(url);
    assert.ok(query, url);
    assert.equal(query.upstream.origin, 'https://www.googleapis.com');
    assert.equal(query.upstream.searchParams.has('key'), false);
  }
});

test('reject writes, cross-site browsers, invalid requests and missing settings before calling Google', async () => {
  let calls = 0;
  const handler = createHandler({ getKey: () => '', fetchImpl: async () => { calls++; } });
  for (const [input, code] of [[req(request, 'POST'), 405], [req(request, 'GET', { 'sec-fetch-site': 'cross-site' }), 403], [req('/?key=secret'), 400], [req(), 503]]) {
    const res = response(); await handler(input, res);
    assert.equal(res.code, code);
    assert.equal(res.headers['Cache-Control'], 'no-store');
  }
  assert.equal(calls, 0);
});

test('secret stays upstream; public items cached, headers and tokens never forwarded', async () => {
  const handler = createHandler({ getKey: () => 'server-test-key', fetchImpl: async (url, options) => {
    assert.equal(url.searchParams.has('key'), false);
    assert.deepEqual(options.headers, { 'X-Goog-Api-Key': 'server-test-key' });
    assert.equal(options.redirect, 'error');
    assert.ok(options.signal);
    return Response.json({ items: [{ id: channel }], upstreamMetadata: 'not returned' });
  } });
  const res = response(); await handler(req(request, 'GET', { authorization: 'Bearer user-token' }), res);
  assert.equal(res.code, 200);
  assert.deepEqual(res.body, { items: [{ id: channel }] });
  assert.match(res.headers['Cache-Control'], /s-maxage=300/);
  assert.equal(JSON.stringify(res).includes('server-test-key'), false);
});

test('quota errors, redirects, malformed replies and exceptions never leak upstream key URLs or get cached', async () => {
  for (const fetchImpl of [async () => new Response('secret-url', { status: 403 }),
    async () => { throw new Error('https://googleapis.com/?key=server-test-key'); },
    async () => Response.json({ error: 'server-test-key' }),
    async () => new Response('not json')]) {
    const res = response();
    await createHandler({ getKey: () => 'server-test-key', fetchImpl })(req(), res);
    assert.equal(res.code, 502);
    assert.deepEqual(res.body, { error: 'youtube_unavailable' });
    assert.equal(res.headers['Cache-Control'], 'no-store');
  }
});
