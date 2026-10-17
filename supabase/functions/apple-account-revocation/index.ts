import { createClient } from '@supabase/supabase-js';
import { appleRevocationHandler } from './handler.ts';

const url = Deno.env.get('SUPABASE_URL') ?? '';
const anon = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const options = { auth: { persistSession: false, autoRefreshToken: false } };

Deno.serve(appleRevocationHandler({
  secrets: {
    teamId: Deno.env.get('APPLE_TEAM_ID') ?? '',
    keyId: Deno.env.get('APPLE_KEY_ID') ?? '',
    clientId: Deno.env.get('APPLE_CLIENT_ID') ?? '',
    privateKey: Deno.env.get('APPLE_PRIVATE_KEY') ?? '',
  },
  appOrigin: Deno.env.get('PUBLIC_APP_ORIGIN') ?? '',
  authenticate: async token => {
    if (!url || !anon || !service) return null;
    const client = createClient(url, anon, options);
    const { data, error } = await client.auth.getUser(token);
    return error ? null : data.user?.id ?? null;
  },
  identities: async userId => {
    const server = createClient(url, service, options);
    const { data, error } = await server.rpc('apple_deletion_identities',
      { p_user_id: userId });
    if (error || !Array.isArray(data)) throw new Error('Deletion unavailable');
    return data;
  },
  record: async (userId, identity) => {
    const server = createClient(url, service, options);
    const { error } = await server.rpc('record_apple_deletion_revocation', {
      p_user_id: userId, p_identity_id: identity.identity_id,
      p_subject: identity.subject, p_version: identity.version,
    });
    if (error) throw new Error('Deletion unavailable');
  },
}));
