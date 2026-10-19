export const publishingScope = 'https://www.googleapis.com/auth/youtube.force-ssl';
export const googleTokenUrl = 'https://oauth2.googleapis.com/token';
export const youtubeApi = 'https://www.googleapis.com/youtube/v3/';

export class ProviderError extends Error {
  constructor(readonly status: number, readonly reason: string, readonly ambiguous = false) {
    super(`YouTube operation failed (${status}: ${reason})`);
  }
}

export async function googleToken(params: URLSearchParams): Promise<Record<string, unknown>> {
  const response = await fetch(googleTokenUrl, {
    method: 'POST', headers: {'content-type':'application/x-www-form-urlencoded'}, body: params,
    signal: AbortSignal.timeout(20000),
  });
  if (!response.ok) throw new ProviderError(response.status, 'oauth_failed');
  return await response.json();
}

// Access tokens live about an hour. A warm function instance reuses one per
// grant instead of asking Google again on every studio and go-live call.
const accessTokens = new Map<string, {token: string; expires: number}>();

export async function accessToken(credentials: {clientId: string; clientSecret: string},
  refresh: string): Promise<string> {
  const key = `${credentials.clientId}\u0000${refresh}`;
  const cached = accessTokens.get(key);
  if (cached && cached.expires > Date.now()) return cached.token;
  const token = await googleToken(new URLSearchParams({grant_type:'refresh_token',client_id:credentials.clientId,
    client_secret:credentials.clientSecret,refresh_token:refresh}));
  if (typeof token.access_token !== 'string') throw new ProviderError(401,'owner_reconnection_required');
  const lifetime = typeof token.expires_in === 'number' ? token.expires_in : 0;
  if (lifetime > 300) {
    if (accessTokens.size > 500) accessTokens.clear();
    accessTokens.set(key,{token:token.access_token,expires:Date.now()+(lifetime-120)*1000});
  }
  return token.access_token;
}

export function forgetAccessToken(credentials: {clientId: string}, refresh: string): void {
  accessTokens.delete(`${credentials.clientId}\u0000${refresh}`);
}

export async function youtube(token: string, resource: string, params: Record<string, string>,
  method = 'GET', body?: unknown): Promise<Record<string, unknown>> {
  const url = new URL(resource, youtubeApi);
  for (const [key,value] of Object.entries(params)) url.searchParams.set(key,value);
  let response: Response;
  try {
    response = await fetch(url, {method, signal:AbortSignal.timeout(20000),
      headers:{authorization:`Bearer ${token}`,'content-type':'application/json'},
      body:body === undefined ? undefined : JSON.stringify(body)});
  } catch (_) {
    // A timed-out write may have succeeded. Its reservation must be reconciled.
    throw new ProviderError(503,'provider_unreachable',method !== 'GET');
  }
  if (!response.ok) {
    const result = await response.json().catch(() => ({}));
    const reason = result.error?.errors?.[0]?.reason ?? 'provider_failed';
    throw new ProviderError(response.status,String(reason),method !== 'GET' && response.status>=500);
  }
  return response.status === 204 ? {} : await response.json();
}

export function ownedChannel(response: Record<string, unknown>): {id:string; title:string} {
  const channels = response.items as Array<{id:string; snippet:{title:string}}> | undefined;
  if (!channels || channels.length !== 1 || !/^UC[A-Za-z0-9_-]{22}$/.test(channels[0].id)) {
    throw new ProviderError(409,'select_one_owned_channel');
  }
  return {id:channels[0].id,title:channels[0].snippet.title};
}

export function requirePublishingScope(value: unknown): void {
  if (typeof value !== 'string' || !value.split(' ').includes(publishingScope)) {
    throw new ProviderError(403,'publishing_scope_missing');
  }
}

export function ingestionAddress(value: unknown): string {
  if (typeof value !== 'string') throw new ProviderError(409,'secure_ingestion_unavailable');
  const url = new URL(value);
  // Preserve the provider hostname for TLS/SNI; never fall back to unencrypted RTMP.
  // YouTube returns rtmps://a.rtmps.youtube.com/live2 for secure ingestion.
  if (url.protocol !== 'rtmps:' || url.username || url.password ||
    !/^(?:[a-z0-9-]+\.)*rtmps?\.youtube\.com$/.test(url.hostname) ||
    (url.port && url.port !== '443')) throw new ProviderError(409,'secure_ingestion_unavailable');
  return value;
}
