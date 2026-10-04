import {createClient} from 'jsr:@supabase/supabase-js@2';
import {runBroadcast} from '../_shared/broadcast_control.ts';
import {ProviderError} from '../_shared/youtube_broadcast.ts';

const env=(name:string)=>Deno.env.get(name)??'';
const url=env('SUPABASE_URL'),anon=env('SUPABASE_ANON_KEY'),service=env('SUPABASE_SERVICE_ROLE_KEY');
const credentials={clientId:env('YOUTUBE_OAUTH_CLIENT_ID'),clientSecret:env('YOUTUBE_OAUTH_CLIENT_SECRET')};
const origin=env('PUBLIC_APP_ORIGIN');
const headers={'access-control-allow-origin':origin,'access-control-allow-headers':'authorization,apikey,content-type,x-client-info',
  'access-control-allow-methods':'POST,OPTIONS','cache-control':'no-store'};
async function rpc(db:ReturnType<typeof createClient>,name:string,params:Record<string,unknown>) {
  const {data,error}=await db.rpc(name,params);
  if(error) throw new ProviderError(error.code==='42501'?403:409,'session_operation_unavailable');
  return data;
}
Deno.serve(async request=>{
  if(request.method==='OPTIONS') return new Response(null,{headers});
  if(request.method!=='POST') return new Response('Method not allowed',{status:405,headers});
  if(!url||!anon||!service||!credentials.clientId||!credentials.clientSecret||!origin) return Response.json({error:'broadcast_setup_required'},{status:503,headers});
  if(request.headers.get('origin')&&request.headers.get('origin')!==origin) return new Response('Origin denied',{status:403,headers});
  const server=createClient(url,service,{auth:{persistSession:false,autoRefreshToken:false}});
  const serverRpc=(name:string,params:Record<string,unknown>)=>rpc(server,name,params);
  let id:string|undefined,reservation:string|undefined;
  try {
    const authorization=request.headers.get('authorization')??'';
    const token=/^Bearer\s+(.+)$/i.exec(authorization)?.[1];
    if(!token) return new Response('Unauthorized',{status:401,headers});
    const user=createClient(url,anon,{global:{headers:{Authorization:authorization}},auth:{persistSession:false,autoRefreshToken:false}});
    const {data:{user:actor},error}=await user.auth.getUser(token);
    if(error||!actor) return new Response('Unauthorized',{status:401,headers});
    const body=await request.json();
    if(!['prepare','start','end','observe'].includes(body.action)||typeof body.session_id!=='string'
      ||!/^[0-9a-f-]{36}$/i.test(body.session_id)||typeof body.device_id!=='string'||body.device_id.length>128
      ||!['phone_direct','obs_laptop'].includes(body.sender_mode)) return new Response('Invalid session operation',{status:400,headers});
    id=body.session_id;
    const claim=await rpc(user,'broadcast_reserve_confirmed',{p_id:id,p_device:body.device_id,p_sender:body.sender_mode,p_operation:body.action,
      p_connection_id:body.connection_id??null,p_channel_revision:body.channel_revision??null});
    if(claim.done) return Response.json({done:true},{headers});
    reservation=claim.token;
    return Response.json(await runBroadcast(id!,reservation!,serverRpc,credentials),{headers});
  } catch(error) {
    if(id&&reservation) await serverRpc('broadcast_provider_step',{p_id:id,p_token:reservation,p_step:'observe',
      p_error:error instanceof ProviderError?error.reason:'operation_failed',p_ambiguous:error instanceof ProviderError?error.ambiguous:true}).catch(()=>{});
    return Response.json({error:error instanceof ProviderError?error.reason:'operation_failed'},
      {status:error instanceof ProviderError?error.status:409,headers});
  }
});
