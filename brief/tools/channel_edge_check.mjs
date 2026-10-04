import assert from 'node:assert/strict';
import {readFile,mkdtemp,writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';

// Real handlers and SDK; synthetic account and fetch responses. No network.
const sdk = pathToFileURL(resolve(process.argv[2])).href;
const root = await mkdtemp(join(tmpdir(),'hadayah-edge-check-'));
const env = {SUPABASE_URL:'https://backend.invalid',SUPABASE_ANON_KEY:'test-anon',
  SUPABASE_SERVICE_ROLE_KEY:'test-service',YOUTUBE_OAUTH_CLIENT_ID:'test-client',
  YOUTUBE_OAUTH_CLIENT_SECRET:'test-secret',YOUTUBE_OAUTH_CALLBACK_URL:'https://backend.invalid/functions/v1/channel-authorization',
  PUBLIC_APP_ORIGIN:'https://app.invalid'};
let handler, rpcError;
const consumedStates = new Set();
globalThis.Deno = {env:{get:name=>env[name]},serve:fn=>{handler=fn;}};
globalThis.fetch = async (url,options) => {
  if (String(url) === 'https://oauth2.googleapis.com/token') {
    assert.equal(options.body.get('code_verifier'), 'synthetic-verifier');
    return Response.json({access_token:'synthetic-youtube',refresh_token:'synthetic-refresh',
      scope:'https://www.googleapis.com/auth/youtube.force-ssl'});
  }
  if (String(url).startsWith('https://www.googleapis.com/youtube/v3/channels')) {
    assert.equal(new Headers(options.headers).get('Authorization'),'Bearer synthetic-youtube');
    return Response.json({items:[{id:'UC0000000000000000000000',snippet:{title:'Synthetic channel'}}]});
  }
  const headers = new Headers(options.headers);
  const serverRpc = /channel_oauth_(consume|commit)$/.test(String(url));
  assert.equal(headers.get('Authorization'),serverRpc?'Bearer test-service':'Bearer synthetic-session');
  if(String(url).endsWith('/auth/v1/user')) return Response.json({
    id:'00000000-0000-4000-8000-000000000001',aud:'authenticated',app_metadata:{},user_metadata:{},created_at:'2026-10-04T00:00:00Z'});
  if(String(url).endsWith('/rest/v1/rpc/channel_oauth_consume')) {
    const state = JSON.parse(options.body).p_state;
    assert.match(state, /^synthetic-state(?:-test)?$/);
    if(consumedStates.has(state)) return Response.json({code:'42501',message:'Expired state'},{status:400});
    consumedStates.add(state);
    return Response.json({id:'synthetic-intent',verifier:'synthetic-verifier'});
  }
  if(String(url).includes('/rest/v1/rpc/')) return rpcError
    ? Response.json(rpcError,{status:400})
    : Response.json(String(url).endsWith('channel_oauth_begin')
      ? {state:'synthetic-state',challenge:'synthetic-challenge'} : {done:true});
  throw Error('Unexpected network route');
};
for(const name of ['youtube_broadcast','broadcast_control']) {
  let source=await readFile(`supabase/functions/_shared/${name}.ts`,'utf8');
  await writeFile(join(root,`${name}.ts`),source);
}
for(const name of ['channel-authorization','broadcast-control']) {
  let source=await readFile(`supabase/functions/${name}/index.ts`,'utf8');
  source=source.replace("'jsr:@supabase/supabase-js@2'",JSON.stringify(sdk))
    .replaceAll('../_shared/','./');
  await writeFile(join(root,`${name}.ts`),source);
  await import(pathToFileURL(join(root,`${name}.ts`)).href);
  const invoke=(authorized=true,returnPlatform='web')=>handler(new Request(`https://backend.invalid/${name}`,{
    method:'POST',headers:{'content-type':'application/json',...(authorized?{Authorization:'Bearer synthetic-session'}:{})},
    body:JSON.stringify(name==='channel-authorization'?{action:'connect',return_platform:returnPlatform}:
      {action:'prepare',session_id:'00000000-0000-4000-8000-000000000002',device_id:'test',sender_mode:'phone_direct'}),
  }));
  assert.equal((await invoke(false)).status,401);
  const success=await invoke();assert.equal(success.status,200);
  if(name==='channel-authorization') {
    const consent=new URL((await success.json()).authorization_url);
    assert.equal(consent.host,'accounts.google.com');
    assert.equal(consent.searchParams.get('code_challenge_method'),'S256');
    for(const platform of ['android','android_test','https://untrusted.invalid']) {
      const result = await (await invoke(true, platform)).json();
      assert.equal(new URL(result.authorization_url).searchParams.get('state'),
        platform.startsWith('android')?`synthetic-state.${platform}`:'synthetic-state');
    }
    const callback=state=>handler(new Request(`https://backend.invalid/${name}?state=${state}&code=synthetic-code`));
    const native = await callback('synthetic-state.android');
    assert.equal(native.status,303);
    assert.equal(native.headers.get('location'),'sa.hadayah.streamerapp://channel-connected/channel-connected?status=connected');
    const replay = await callback('synthetic-state.android');
    assert.equal(replay.headers.get('location'),'sa.hadayah.streamerapp://channel-connected/channel-connected?status=failed');
    const cancelled = await handler(new Request(`https://backend.invalid/${name}?state=synthetic-state-test.android_test&error=access_denied`));
    assert.equal(cancelled.headers.get('location'),'sa.hadayah.streamerapp.wave4v2://channel-connected/channel-connected?status=failed');
    for(const [code,expected] of [['42501',403],['55000',409],['42883',503]]) {
      rpcError={code,message:'internal detail',details:null,hint:null};
      assert.equal((await invoke()).status,expected);
    }
    rpcError=null;
  }
  console.log(`PASS: ${name} validates forwarded session, denies unsigned requests and completes its authorized preflight.`);
}
