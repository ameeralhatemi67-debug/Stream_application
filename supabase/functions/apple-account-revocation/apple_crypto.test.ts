import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createRemoteJWKSet, customFetch, exportJWK, exportPKCS8,
  generateKeyPair, jwtVerify, SignJWT } from 'jose';
import { appleClientSecret, verifyAppleIdentity } from './apple_crypto.ts';

test('client secret uses ES256 with the documented issuer/audience/subject and short expiry', async () => {
  const pair = await generateKeyPair('ES256', { extractable: true });
  const pem = await exportPKCS8(pair.privateKey);
  const token = await appleClientSecret({
    teamId: 'MOCK_TEAM', keyId: 'MOCK_KEY', clientId: 'sa.hadayah.streamerapp',
    privateKey: pem.replace(/\n/g, '\\n'),
  });
  const { payload, protectedHeader } = await jwtVerify(token, pair.publicKey, {
    issuer: 'MOCK_TEAM', audience: 'https://appleid.apple.com',
    subject: 'sa.hadayah.streamerapp', algorithms: ['ES256'],
  });
  assert.equal(protectedHeader.kid, 'MOCK_KEY');
  assert.ok(payload.exp! - payload.iat! <= 300);
});

test('Apple JWT signature, issuer, audience, expiry, nonce and subject are checked with mocked JWKS HTTP', async () => {
  const pair = await generateKeyPair('RS256');
  const other = await generateKeyPair('RS256');
  const jwk = { ...await exportJWK(pair.publicKey), kid: 'MOCK_APPLE_KEY',
    alg: 'RS256', use: 'sig' };
  let requests = 0;
  const keys = createRemoteJWKSet(new URL('https://appleid.apple.com/auth/keys'), {
    [customFetch]: async url => {
      assert.equal(String(url), 'https://appleid.apple.com/auth/keys');
      requests++;
      return Response.json({ keys: [jwk] });
    },
  });
  const nonce = 'a'.repeat(64);
  const sign = async (claims: Record<string, unknown> = {}, wrongKey = false) =>
    new SignJWT({ nonce, ...claims }).setProtectedHeader({ alg: 'RS256', kid: jwk.kid })
      .setIssuer('https://appleid.apple.com').setAudience('sa.hadayah.streamerapp')
      .setSubject('MOCK_SUBJECT').setIssuedAt().setExpirationTime('5m')
      .sign(wrongKey ? other.privateKey : pair.privateKey);
  const valid = await sign();
  assert.equal(await verifyAppleIdentity(valid, 'sa.hadayah.streamerapp', nonce, keys),
    'MOCK_SUBJECT');
  await assert.rejects(verifyAppleIdentity(valid, 'wrong-audience', nonce, keys));
  await assert.rejects(verifyAppleIdentity(valid, 'sa.hadayah.streamerapp', 'wrong-nonce', keys));
  await assert.rejects(verifyAppleIdentity(await sign({}, true),
    'sa.hadayah.streamerapp', nonce, keys));
  const expired = await new SignJWT({ nonce }).setProtectedHeader({ alg: 'RS256', kid: jwk.kid })
    .setIssuer('https://appleid.apple.com').setAudience('sa.hadayah.streamerapp')
    .setSubject('MOCK_SUBJECT').setIssuedAt().setExpirationTime(1).sign(pair.privateKey);
  await assert.rejects(verifyAppleIdentity(expired, 'sa.hadayah.streamerapp', nonce, keys));
  const foreign = await new SignJWT({ nonce }).setProtectedHeader({ alg: 'RS256', kid: jwk.kid })
    .setIssuer('https://other.invalid').setAudience('sa.hadayah.streamerapp')
    .setSubject('MOCK_SUBJECT').setIssuedAt().setExpirationTime('5m').sign(pair.privateKey);
  await assert.rejects(verifyAppleIdentity(foreign, 'sa.hadayah.streamerapp', nonce, keys));
  assert.equal(requests, 1);
});
