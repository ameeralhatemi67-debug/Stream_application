import { createClient } from 'jsr:@supabase/supabase-js@2';
import { firebaseAccessToken, sendFcm } from '../_shared/fcm.ts';
import { orgEventText } from '../_shared/org_event_text.ts';

type Claim = {
  event_id: string;
  token: string;
  kind: string;
  recipient_profile_id: string;
  language_code: string;
  organization_id: string | null;
  session_id: string | null;
  invitation_id: string | null;
  payload: Record<string, unknown>;
};

const env = (name: string) => Deno.env.get(name) ?? '';

Deno.serve(async (request) => {
  // Dedicated scheduler key, never a user token. No secret in URL or logs.
  const key = env('ORG_EVENTS_DISPATCH_KEY');
  if (request.method !== 'POST' || !key || request.headers.get('authorization') !== `Bearer ${key}`) {
    return new Response('Unauthorized', { status: 401 });
  }
  const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'),
    { auth: { persistSession: false, autoRefreshToken: false } });
  const { data, error } = await db.rpc('claim_org_v1_event_pushes');
  if (error) return new Response('Event claim failed', { status: 503 });
  const claims = (data ?? []) as Claim[];
  if (claims.length === 0) return Response.json({ claimed: 0, sent: 0 });

  const accountJson = env('FIREBASE_SERVICE_ACCOUNT_JSON');
  const projectId = env('FIREBASE_PROJECT_ID');
  // Claims stay leased and are retried by a later run once delivery is configured.
  if (!accountJson || !projectId) return new Response('Firebase delivery unavailable', { status: 503 });
  let accessToken: string;
  try {
    accessToken = await firebaseAccessToken(JSON.parse(accountJson));
  } catch (_) {
    return new Response('Firebase authorization failed', { status: 503 });
  }

  let sent = 0;
  for (const claim of claims) {
    const text = orgEventText(claim, claim.language_code);
    const en = orgEventText(claim, 'en');
    const ar = orgEventText(claim, 'ar');
    const message = {
      token: claim.token,
      notification: text,
      android: { notification: { tag: `org-${claim.event_id}` } },
      data: {
        type: 'org_event',
        event_id: claim.event_id,
        kind: claim.kind,
        viewer_id: claim.recipient_profile_id,
        organization_id: claim.organization_id ?? '',
        session_id: claim.session_id ?? '',
        invitation_id: claim.invitation_id ?? '',
        title_en: en.title, body_en: en.body, title_ar: ar.title, body_ar: ar.body,
      },
    };
    try {
      const result = await sendFcm(projectId, accessToken, message);
      if (result === 'sent') {
        const { error: saved } = await db.rpc('org_v1_event_push_sent',
          { p_event_id: claim.event_id, p_token: claim.token });
        if (!saved) sent++;
      } else if (result === 'unregistered') {
        await db.from('schedule_push_devices').delete().eq('token', claim.token);
      }
    } catch (_) {
      // The lease expires after two minutes; the next run retries (at most five attempts).
    }
  }
  return Response.json({ claimed: claims.length, sent }, { headers: { 'cache-control': 'no-store' } });
});
