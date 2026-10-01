// Firebase Cloud Messaging v1 helpers shared by server push jobs. The service
// account comes from function secrets; nothing here is logged or returned.

function base64url(value: Uint8Array | string): string {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export async function firebaseAccessToken(account: {
  client_email: string; private_key: string;
}): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64url(JSON.stringify({
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now, exp: now + 3600,
  }));
  const pem = account.private_key.replace(/-----[^-]+-----/g, '').replace(/\s/g, '');
  const key = await crypto.subtle.importKey('pkcs8',
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign']);
  const unsigned = `${header}.${claims}`;
  const signature = new Uint8Array(await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsigned)));
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${base64url(signature)}`,
    }),
  });
  if (!response.ok) throw new Error(`Firebase OAuth failed: ${response.status}`);
  const result = await response.json();
  return result.access_token as string;
}

export type SendResult = 'sent' | 'unregistered' | 'failed';

export async function sendFcm(projectId: string, accessToken: string,
  message: Record<string, unknown>): Promise<SendResult> {
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
    { method: 'POST', headers: {
      authorization: `Bearer ${accessToken}`,
      'content-type': 'application/json',
    }, body: JSON.stringify({ message }) });
  if (response.ok) return 'sent';
  const failure = await response.json().catch(() => ({}));
  const unregistered = Array.isArray(failure.error?.details) &&
    failure.error.details.some((detail: { errorCode?: string }) =>
      detail.errorCode === 'UNREGISTERED');
  return unregistered ? 'unregistered' : 'failed';
}
