import {createClient} from 'jsr:@supabase/supabase-js@2';
import {runBroadcast} from '../_shared/broadcast_control.ts';
import {ProviderError} from '../_shared/youtube_broadcast.ts';

const env=(name:string)=>Deno.env.get(name)??'';
Deno.serve(async request=>{
  // Dedicated scheduler key, never a user token. No secret in URL or logs.
  const key=env('BROADCAST_RECONCILE_KEY');
  if(request.method!=='POST'||!key||request.headers.get('authorization')!==`Bearer ${key}`) return new Response('Unauthorized',{status:401});
  const db=createClient(env('SUPABASE_URL'),env('SUPABASE_SERVICE_ROLE_KEY'),{auth:{persistSession:false,autoRefreshToken:false}});
  async function rpc(name:string,params:Record<string,unknown>) {
    const {data,error}=await db.rpc(name,params);if(error) throw new Error('Reconciliation persistence failed');return data;
  }
  const claims=await rpc('broadcast_reconcile_claim',{});
  let complete=0,pending=0;
  async function reconcile(claim:{id:string;token:string}) {
    try {await runBroadcast(claim.id,claim.token,rpc,{clientId:env('YOUTUBE_OAUTH_CLIENT_ID'),clientSecret:env('YOUTUBE_OAUTH_CLIENT_SECRET')});complete++;}
    catch(error) {
      pending++;
      await rpc('broadcast_provider_step',{p_id:claim.id,p_token:claim.token,p_step:'observe',
        p_error:error instanceof ProviderError?error.reason:'reconciliation_failed',
        p_ambiguous:error instanceof ProviderError?error.ambiguous:true}).catch(()=>{});
    }
  }
  for(let i=0;i<claims.length;i+=3) await Promise.all(claims.slice(i,i+3).map(reconcile));
  return Response.json({complete,pending},{headers:{'cache-control':'no-store'}});
});
