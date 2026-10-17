import { createRemoteJWKSet, importPKCS8, jwtVerify, SignJWT } from 'jose';

export type AppleSecrets = {
  teamId: string; keyId: string; clientId: string; privateKey: string;
};

const issuer = 'https://appleid.apple.com';
const appleKeys = createRemoteJWKSet(new URL(issuer + '/auth/keys'), {
  timeoutDuration: 5000,
});

export async function appleClientSecret(secrets: AppleSecrets): Promise<string> {
  const key = await importPKCS8(secrets.privateKey.replace(/\\n/g, '\n'), 'ES256');
  return await new SignJWT({})
    .setProtectedHeader({ alg: 'ES256', kid: secrets.keyId })
    .setIssuer(secrets.teamId).setSubject(secrets.clientId)
    .setAudience(issuer).setIssuedAt().setExpirationTime('5m').sign(key);
}

export async function verifyAppleIdentity(
  token: string, clientId: string, nonce: string,
  keys = appleKeys,
): Promise<string> {
  const { payload } = await jwtVerify(token, keys, {
    algorithms: ['RS256'], issuer, audience: clientId,
    requiredClaims: ['sub', 'exp', 'iat', 'nonce'],
    maxTokenAge: '5m',
  });
  if (typeof payload.sub !== 'string' || !payload.sub || payload.nonce !== nonce) {
    throw new Error('Apple identity verification failed');
  }
  return payload.sub;
}
