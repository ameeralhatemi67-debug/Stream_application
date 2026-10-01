import {createClient} from 'jsr:@supabase/supabase-js@2';
import {googleToken,ownedChannel,publishingScope,requirePublishingScope,youtube} from '../_shared/youtube_broadcast.ts';

const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? '';
const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const anonKey = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const clientId = Deno.env.get('YOUTUBE_OAUTH_CLIENT_ID') ?? '';
const clientSecret = Deno.env.get('YOUTUBE_OAUTH_CLIENT_SECRET') ?? '';
const callbackUrl = Deno.env.get('YOUTUBE_OAUTH_CALLBACK_URL') ?? '';
const appOrigin = Deno.env.get('PUBLIC_APP_ORIGIN') ?? '';

// The web app routes in the URL fragment (Flutter's default hash strategy).
// Fixed deployment origin, never a caller-supplied return URL.
function appReturn(status: 'connected'|'failed'): string {
  const destination = new URL('/',appOrigin);
  destination.hash = `/channel-connected?status=${status}`;
  return destination.toString();
}
function headers(): HeadersInit {
  return {'cache-control':'no-store','access-control-allow-origin':appOrigin,
    'access-control-allow-headers':'authorization,apikey,content-type,x-client-info',
    'access-control-allow-methods':'POST,OPTIONS','referrer-policy':'no-referrer'};
}
async function rpc(db: ReturnType<typeof createClient>, name:string, params:Record<string,unknown>) {
  const {data,error} = await db.rpc(name,params);
  if (error) throw new Error(error.code === '42501' ? 'Operation not authorized' : 'Channel operation unavailable');
  return data;
}
Deno.serve(async request => {
  if (request.method==='OPTIONS') return new Response(null,{headers:headers()});
  if (!supabaseUrl || !serviceKey || !anonKey || !clientId || !clientSecret || !callbackUrl || !appOrigin) {
    return Response.json({error:'Channel authorization is not configured'},{status:503,headers:headers()});
  }
  const url = new URL(request.url);
  const server = createClient(supabaseUrl,serviceKey,{auth:{persistSession:false,autoRefreshToken:false}});
  try {
    if (request.method==='GET' && url.searchParams.has('state')) {
      const state = url.searchParams.get('state')!;
      if (state.length>200) throw new Error('Invalid consent state');
      const intent = await rpc(server,'channel_oauth_consume',{p_state:state});
      if (url.searchParams.has('error') || !url.searchParams.get('code')) throw new Error('YouTube consent was not completed');
      const token = await googleToken(new URLSearchParams({grant_type:'authorization_code',
        client_id:clientId,client_secret:clientSecret,redirect_uri:callbackUrl,
        code:url.searchParams.get('code')!,code_verifier:intent.verifier}));
      requirePublishingScope(token.scope);
      if (typeof token.refresh_token!=='string' || typeof token.access_token!=='string') {
        throw new Error('Offline consent is required; reconnect the channel');
      }
      const channel = ownedChannel(await youtube(token.access_token,'channels',{part:'id,snippet',mine:'true'}));
      await rpc(server,'channel_oauth_commit',{p_request_id:intent.id,p_channel_id:channel.id,
        p_title:channel.title,p_refresh_token:token.refresh_token});
      return new Response(null,{status:303,headers:{...headers(),location:appReturn('connected')}});
    }
    if (request.method!=='POST') return new Response('Method not allowed',{status:405,headers:headers()});
    if (request.headers.get('origin') && request.headers.get('origin')!==appOrigin) {
      return new Response('Origin not allowed',{status:403,headers:headers()});
    }
    const authorization = request.headers.get('authorization') ?? '';
    const user = createClient(supabaseUrl,anonKey,{global:{headers:{authorization}},auth:{persistSession:false}});
    const {data:{user:actor},error} = await user.auth.getUser();
    if (error || !actor) return new Response('Unauthorized',{status:401,headers:headers()});
    const body = await request.json();
    if (body.action==='disconnect') {
      await rpc(user,'channel_disconnect',{p_connection_id:body.connection_id});
      return Response.json({status:'disconnected'},{headers:headers()});
    }
    if (body.action!=='connect') return new Response('Unknown action',{status:400,headers:headers()});
    const intent = await rpc(user,'channel_oauth_begin',{p_org_id:body.organization_id ?? null});
    const consent = new URL('https://accounts.google.com/o/oauth2/v2/auth');
    consent.search = new URLSearchParams({client_id:clientId,redirect_uri:callbackUrl,
      response_type:'code',scope:publishingScope,state:intent.state,access_type:'offline',
      prompt:'consent select_account',code_challenge:intent.challenge,code_challenge_method:'S256'}).toString();
    return Response.json({authorization_url:consent.toString()},{headers:headers()});
  } catch (error) {
    // No OAuth code, token, request body or credential is logged or returned.
    // A browser returning from Google gets the app back, not a JSON error page.
    if (request.method==='GET' && url.searchParams.has('state')) {
      return new Response(null,{status:303,headers:{...headers(),location:appReturn('failed')}});
    }
    return Response.json({error:error instanceof Error ? error.message : 'Channel operation failed'},
      {status:409,headers:headers()});
  }
});
