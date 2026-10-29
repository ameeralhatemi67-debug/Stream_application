import { createClient } from 'jsr:@supabase/supabase-js@2';
import { preacherEmail, type PreacherEmailData } from '../_shared/preacher_email_text.ts';

// An email the outbox hands over (claim_preacher_emails, 20261029103349).
// The claim leases it for five minutes; the result call settles it.
type Claim = { id: string; kind: string; to_email: string; data: PreacherEmailData };

const env = (name: string) => Deno.env.get(name) ?? '';

// Emails to preachers through Resend (https://resend.com/docs/api-reference/emails/send-email).
// Secrets: RESEND_API_KEY, EMAIL_FROM ("Hadayah <lessons@your-domain>", on a
// domain verified in Resend), optional EMAIL_REPLY_TO and PUBLIC_SITE_URL.
// Without the key or sender nothing is claimed: the emails wait queued.
Deno.serve(async (request) => {
  // A scheduler key, never a user token (same key as the other dispatchers).
  if (request.method !== 'POST') return new Response('Unauthorized', { status: 401 });
  const presented = (request.headers.get('authorization') ?? '').replace(/^Bearer /, '');
  if (!presented) return new Response('Unauthorized', { status: 401 });
  const db = createClient(env('SUPABASE_URL'), env('SUPABASE_SERVICE_ROLE_KEY'),
    { auth: { persistSession: false, autoRefreshToken: false } });
  const { data: authorized } = await db.rpc('verify_reminder_dispatch_key', { p_key: presented });
  if (authorized !== true) return new Response('Unauthorized', { status: 401 });

  const apiKey = env('RESEND_API_KEY');
  const from = env('EMAIL_FROM');
  if (!apiKey || !from) return new Response('Email sender not configured', { status: 503 });
  const site = env('PUBLIC_SITE_URL') || 'https://stream-application-ten.vercel.app';
  const replyTo = env('EMAIL_REPLY_TO');

  const { data, error } = await db.rpc('claim_preacher_emails', { p_limit: 25 });
  if (error) return new Response('Email claim failed', { status: 503 });
  const claims = (data ?? []) as Claim[];

  let sent = 0;
  for (const claim of claims) {
    let ok = false;
    let failure: string | null = null;
    let providerId: string | null = null;
    try {
      const email = preacherEmail({ ...claim.data, kind: claim.kind }, site);
      const response = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
          // A retried claim never sends the same email twice.
          'Idempotency-Key': `preacher-email/${claim.id}`,
        },
        body: JSON.stringify({
          from,
          to: [claim.to_email],
          subject: email.subject,
          html: email.html,
          text: email.text,
          ...(replyTo ? { reply_to: replyTo } : {}),
        }),
      });
      if (response.ok) {
        ok = true;
        providerId = String((await response.json().catch(() => ({})))?.id ?? '') || null;
      } else {
        // Status and Resend's short reason only: never the address or body.
        const body = await response.json().catch(() => ({})) as { name?: string; message?: string };
        failure = `${response.status} ${body.name ?? ''}`.trim();
      }
    } catch (e) {
      failure = e instanceof Error ? e.name : 'error';
    }
    const { error: saved } = await db.rpc('preacher_email_result',
      { p_id: claim.id, p_ok: ok, p_error: failure, p_provider_id: providerId });
    if (ok && !saved) sent++;
  }
  return Response.json({ claimed: claims.length, sent }, { headers: { 'cache-control': 'no-store' } });
});
