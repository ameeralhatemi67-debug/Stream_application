import { appleClientSecret, verifyAppleIdentity } from './apple_crypto.ts';
import type { AppleSecrets } from './apple_crypto.ts';

export type AppleIdentity = { identity_id: string; subject: string; version: string };
export type Dependencies = {
  secrets: AppleSecrets;
  appOrigin: string;
  authenticate: (token: string) => Promise<string | null>;
  identities: (userId: string) => Promise<AppleIdentity[]>;
  record: (userId: string, identity: AppleIdentity) => Promise<void>;
  fetch?: typeof fetch;
  sign?: typeof appleClientSecret;
  verify?: typeof verifyAppleIdentity;
};

export function appleRevocationHandler(deps: Dependencies) {
  return async (request: Request): Promise<Response> => {
    const headers = {
      'cache-control': 'no-store', 'referrer-policy': 'no-referrer',
      'access-control-allow-origin': deps.appOrigin,
      'access-control-allow-headers': 'authorization,apikey,content-type,x-client-info',
      'access-control-allow-methods': 'POST,OPTIONS',
    };
    const reply = (status: number, error: string) =>
      Response.json({ error }, { status, headers });
    if (request.method === 'OPTIONS') return new Response(null, { headers });
    if (request.method !== 'POST') return reply(405, 'method_not_allowed');
    const origin = request.headers.get('origin');
    if (origin && (!deps.appOrigin || origin !== deps.appOrigin)) {
      return reply(403, 'origin_not_allowed');
    }
    const bearer = /^Bearer\s+([^\s]+)$/i.exec(
      request.headers.get('authorization') ?? '')?.[1];
    if (!bearer) return reply(401, 'sign_in_required');
    try {
      const userId = await deps.authenticate(bearer);
      if (!userId) return reply(401, 'sign_in_required');
      if (Object.values(deps.secrets).some(value => !value.trim())) {
        return reply(503, 'apple_revocation_unavailable');
      }
      if (Number(request.headers.get('content-length') ?? 0) > 16384) {
        return reply(400, 'invalid_request');
      }
      const text = await request.text();
      if (text.length > 16384) return reply(400, 'invalid_request');
      let body: Record<string, unknown>;
      try { body = JSON.parse(text); } catch { return reply(400, 'invalid_request'); }
      if (!body || typeof body !== 'object' ||
          typeof body.authorization_code !== 'string' ||
          !body.authorization_code.trim() || body.authorization_code.length > 4096 ||
          typeof body.nonce !== 'string' || !/^[a-f0-9]{64}$/.test(body.nonce)) {
        return reply(400, 'invalid_request');
      }
      const identities = await deps.identities(userId);
      if (identities.length === 0) return reply(409, 'apple_identity_mismatch');
      let secret: string;
      try { secret = await (deps.sign ?? appleClientSecret)(deps.secrets); }
      catch { return reply(503, 'apple_revocation_unavailable'); }
      const send = deps.fetch ?? fetch;
      const post = (url: string, values: Record<string, string>) => send(url, {
        method: 'POST', redirect: 'error', signal: AbortSignal.timeout(10000),
        headers: { 'content-type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams(values),
      });
      const exchange = await post('https://appleid.apple.com/auth/token', {
        client_id: deps.secrets.clientId, client_secret: secret,
        grant_type: 'authorization_code', code: body.authorization_code,
      });
      if (exchange.status !== 200) return reply(409, 'apple_revocation_failed');
      const tokens = await exchange.json();
      if (typeof tokens.refresh_token !== 'string' || !tokens.refresh_token ||
          typeof tokens.id_token !== 'string' || !tokens.id_token) {
        return reply(409, 'apple_revocation_failed');
      }
      const subject = await (deps.verify ?? verifyAppleIdentity)(
        tokens.id_token, deps.secrets.clientId, body.nonce);
      const identity = identities.find(value => value.subject === subject);
      if (!identity) return reply(409, 'apple_identity_mismatch');
      const revoked = await post('https://appleid.apple.com/auth/revoke', {
        client_id: deps.secrets.clientId, client_secret: secret,
        token: tokens.refresh_token, token_type_hint: 'refresh_token',
      });
      if (revoked.status !== 200) return reply(409, 'apple_revocation_failed');
      // The database re-checks the identity version; a concurrent sign-in invalidates proof.
      await deps.record(userId, identity);
      return Response.json({ status: 'revoked' }, { headers });
    } catch {
      // Provider errors can contain codes/tokens. Return no upstream diagnostics.
      return reply(409, 'apple_revocation_failed');
    }
  };
}
