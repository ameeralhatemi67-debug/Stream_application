import assert from 'node:assert/strict';
import { test } from 'node:test';
import { appleRevocationHandler } from './handler.ts';
import type { Dependencies } from './handler.ts';

const identity = { identity_id: 'MOCK_IDENTITY', subject: 'MOCK_APPLE_SUBJECT',
  version: '2026-10-18T00:00:00Z' };
const nonce = 'a'.repeat(64);
function fixture(change: Partial<Dependencies> = {}) {
  const calls: string[] = [];
  const bodies: URLSearchParams[] = [];
  const deps: Dependencies = {
    secrets: { teamId: 'MOCK_TEAM', keyId: 'MOCK_KEY',
      clientId: 'sa.hadayah.streamerapp', privateKey: 'MOCK_PRIVATE_KEY' },
    appOrigin: 'https://app.invalid',
    authenticate: async token => token === 'MOCK_SESSION' ? 'MOCK_USER' : null,
    identities: async () => [identity],
    sign: async () => 'MOCK_CLIENT_SECRET',
    verify: async (_token, audience, expectedNonce) => {
      assert.equal(audience, 'sa.hadayah.streamerapp');
      assert.equal(expectedNonce, nonce);
      return identity.subject;
    },
    record: async (userId, value) => {
      assert.equal(userId, 'MOCK_USER');
      assert.deepEqual(value, identity);
      calls.push('record');
    },
    fetch: async (url, init) => {
      calls.push(String(url));
      assert.equal(init?.redirect, 'error');
      const body = new URLSearchParams(String(init?.body));
      bodies.push(body);
      assert.equal(body.get('client_secret'), 'MOCK_CLIENT_SECRET');
      assert.equal(body.get('client_id'), 'sa.hadayah.streamerapp');
      return String(url).endsWith('/token')
        ? Response.json({ refresh_token: 'MOCK_REFRESH', id_token: 'MOCK_ID_TOKEN' })
        : new Response(null, { status: 200 });
    },
    ...change,
  };
  const handler = appleRevocationHandler(deps);
  const request = (body: unknown = { authorization_code: 'MOCK_CODE', nonce },
    headers: Record<string, string> = { authorization: 'Bearer MOCK_SESSION' }) =>
    handler(new Request('https://edge.invalid/apple-account-revocation', {
      method: 'POST', headers, body: JSON.stringify(body),
    }));
  return { calls, bodies, request, handler, deps };
}

test('authenticated exchange verifies identity, revokes refresh token, then records proof', async () => {
  const f = fixture();
  const response = await f.request();
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'revoked' });
  assert.deepEqual(f.calls, ['https://appleid.apple.com/auth/token',
    'https://appleid.apple.com/auth/revoke', 'record']);
  assert.equal(f.bodies[0].get('grant_type'), 'authorization_code');
  assert.equal(f.bodies[0].get('code'), 'MOCK_CODE');
  assert.equal(f.bodies[1].get('token'), 'MOCK_REFRESH');
  assert.equal(f.bodies[1].get('token_type_hint'), 'refresh_token');
  assert.equal(response.headers.get('cache-control'), 'no-store');
});

test('missing/invalid bearer credentials never reach Apple or proof write', async () => {
  for (const headers of [{}, { authorization: 'Bearer WRONG_SESSION' }]) {
    const f = fixture();
    assert.equal((await f.request(undefined, headers)).status, 401);
    assert.deepEqual(f.calls, []);
  }
});

test('each missing owner secret fails closed without provider traffic', async () => {
  for (const key of ['teamId', 'keyId', 'clientId', 'privateKey']) {
    const f = fixture();
    f.deps.secrets[key as keyof typeof f.deps.secrets] = '';
    const response = await f.request();
    assert.equal(response.status, 503);
    assert.equal((await response.json()).error, 'apple_revocation_unavailable');
    assert.deepEqual(f.calls, []);
  }
});

test('invalid code/nonce and non-object bodies fail before exchange', async () => {
  for (const body of [null, [], {}, { authorization_code: '', nonce },
    { authorization_code: 'MOCK_CODE', nonce: 'bad' }]) {
    const f = fixture();
    assert.equal((await f.request(body)).status, 400);
    assert.deepEqual(f.calls, []);
  }
});

test('origin and HTTP method are constrained', async () => {
  const f = fixture();
  assert.equal((await f.request(undefined, {
    authorization: 'Bearer MOCK_SESSION', origin: 'https://other.invalid',
  })).status, 403);
  assert.equal((await f.handler(new Request('https://edge.invalid'))).status, 405);
  assert.deepEqual(f.calls, []);
});

test('no Apple identity cannot mint a revocation receipt', async () => {
  const f = fixture({ identities: async () => [] });
  assert.equal((await f.request()).status, 409);
  assert.deepEqual(f.calls, []);
});

test('invalid signing configuration fails closed', async () => {
  const f = fixture({ sign: async () => { throw new Error('MOCK_SECRET_DIAGNOSTIC'); } });
  const response = await f.request();
  assert.equal(response.status, 503);
  assert.doesNotMatch(await response.text(), /MOCK_SECRET/);
  assert.deepEqual(f.calls, []);
});

test('expired or refused authorization code cannot revoke or record', async () => {
  const f = fixture({ fetch: async () => Response.json({
    error: 'invalid_grant', error_description: 'MOCK_SENSITIVE_DIAGNOSTIC',
  }, { status: 400 }) });
  const response = await f.request();
  assert.equal(response.status, 409);
  assert.doesNotMatch(await response.text(), /MOCK_SENSITIVE/);
  assert.deepEqual(f.calls, []);
});

test('missing refresh or ID token fails closed', async () => {
  for (const tokens of [{ id_token: 'MOCK_ID' }, { refresh_token: 'MOCK_REFRESH' }]) {
    const f = fixture({ fetch: async () => Response.json(tokens) });
    assert.equal((await f.request()).status, 409);
    assert.deepEqual(f.calls, []);
  }
});

test('invalid JWT signature/claims prevent revocation and proof write', async () => {
  const f = fixture({ verify: async () => { throw new Error('bad signature'); } });
  assert.equal((await f.request()).status, 409);
  assert.deepEqual(f.calls, ['https://appleid.apple.com/auth/token']);
});

test('another Apple subject cannot revoke or satisfy this account deletion', async () => {
  const f = fixture({ verify: async () => 'OTHER_APPLE_SUBJECT' });
  assert.equal((await f.request()).status, 409);
  assert.deepEqual(f.calls, ['https://appleid.apple.com/auth/token']);
});

test('revocation failure never records proof', async () => {
  const f = fixture();
  f.deps.fetch = async url => String(url).endsWith('/token')
    ? Response.json({ refresh_token: 'MOCK_REFRESH', id_token: 'MOCK_ID' })
    : new Response(null, { status: 500 });
  assert.equal((await f.request()).status, 409);
  assert.deepEqual(f.calls, []);
});

test('transport failure is sanitized and cannot record proof', async () => {
  const f = fixture({ fetch: async () => { throw new Error('MOCK_PROVIDER_SECRET'); } });
  const response = await f.request();
  assert.equal(response.status, 409);
  assert.doesNotMatch(await response.text(), /MOCK_PROVIDER/);
  assert.deepEqual(f.calls, []);
});

test('stale identity or proof-write failure is not reported as success', async () => {
  const f = fixture({ record: async () => { throw new Error('identity changed'); } });
  assert.equal((await f.request()).status, 409);
  assert.deepEqual(f.calls, ['https://appleid.apple.com/auth/token',
    'https://appleid.apple.com/auth/revoke']);
});
