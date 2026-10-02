import { createClient } from 'jsr:@supabase/supabase-js@2';

type Claim = {
  schedule_id: string;
  token: string;
  viewer_profile_id: string;
  occurrence_at: string;
  lead_minutes: number;
  title_en: string;
  title_ar: string;
  streamer_profile_id: string;
  language_code: string;
};

const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';

function base64url(value: Uint8Array | string): string {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

async function firebaseAccessToken(account: {
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

Deno.serve(async (request) => {
  if (!serviceKey || request.headers.get('authorization') !== `Bearer ${serviceKey}`) {
    return new Response('Unauthorized', { status: 401 });
  }
  if (!supabaseUrl) return new Response('Supabase URL unavailable', { status: 503 });
  const db = createClient(supabaseUrl, serviceKey);
  const { data, error } = await db.rpc('claim_due_schedule_reminders');
  if (error) return new Response('Reminder claim failed', { status: 503 });
  const claims = (data ?? []) as Claim[];
  if (claims.length === 0) return Response.json({ claimed: 0, sent: 0 });

  const accountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  const projectId = Deno.env.get('FIREBASE_PROJECT_ID');
  if (!accountJson || !projectId) {
    return new Response('Firebase delivery unavailable', { status: 503 });
  }
  let accessToken: string;
  try {
    accessToken = await firebaseAccessToken(JSON.parse(accountJson));
  } catch (_) {
    return new Response('Firebase authorization failed', { status: 503 });
  }

  let sent = 0;
  for (const claim of claims) {
    const ar = claim.language_code === 'ar';
    const title = (ar ? claim.title_ar : claim.title_en) ||
      (ar ? claim.title_en : claim.title_ar);
    const body = ar
      ? `بث مخطط له بعد ${claim.lead_minutes} دقيقة`
      : `Planned stream starts in ${claim.lead_minutes} minutes`;
    const payload = {
      message: {
        token: claim.token,
        notification: { title, body },
        android: { notification: {
          tag: `upcoming-${claim.schedule_id}-${claim.occurrence_at}`,
        } },
        data: {
          type: 'upcoming_reminder',
          schedule_id: claim.schedule_id,
          streamer_id: claim.streamer_profile_id,
          viewer_id: claim.viewer_profile_id,
          occurrence_at: claim.occurrence_at,
          title_en: claim.title_en || claim.title_ar,
          title_ar: claim.title_ar || claim.title_en,
          body_en: `Planned stream starts in ${claim.lead_minutes} minutes`,
          body_ar: `بث مخطط له بعد ${claim.lead_minutes} دقيقة`,
        },
      },
    };
    try {
      const response = await fetch(
        `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
        { method: 'POST', headers: {
          authorization: `Bearer ${accessToken}`,
          'content-type': 'application/json',
        }, body: JSON.stringify(payload) });
      if (response.ok) {
        const { error: savedError } = await db.from('schedule_reminder_deliveries')
          .update({ sent_at: new Date().toISOString() })
          .eq('schedule_id', claim.schedule_id).eq('token', claim.token)
          .eq('occurrence_at', claim.occurrence_at);
        if (!savedError) sent++;
      } else {
        const failure = await response.json().catch(() => ({}));
        const unregistered = Array.isArray(failure.error?.details) &&
          failure.error.details.some((detail: { errorCode?: string }) =>
            detail.errorCode === 'UNREGISTERED');
        if (unregistered) {
          await db.from('schedule_push_devices').delete().eq('token', claim.token);
        }
      }
    } catch (_) {
      // The claim lease expires after two minutes; the next run retries.
    }
  }
  return Response.json({ claimed: claims.length, sent });
});
