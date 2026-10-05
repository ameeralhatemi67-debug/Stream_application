import {googleToken,ingestionAddress,ProviderError,youtube} from './youtube_broadcast.ts';

type Rpc = (name:string,params:Record<string,unknown>) => Promise<any>;
type Api = typeof youtube;
type Context = {
  session:{id:string;owner_id:string;org_id:string|null;device_id:string;state:string;title_en:string;title_ar:string;
    description:string;scheduled_start_at:string;expected_end_at:string;replay_status:string;stream_id:string|null},
  resource:{operation:string;step:string|null;needs_reconciliation:boolean;provider_stream_id:string|null;
    provider_broadcast_id:string|null;ingest_url:string|null;bound:boolean;feed_retired:boolean;broadcast_deleted:boolean},
  channel_id:string;refresh_token:string;ingest_key:string|null;
};

export async function runBroadcast(id:string,reservation:string,rpc:Rpc,
  credentials:{clientId:string;clientSecret:string},api:Api=youtube):Promise<Record<string,unknown>> {
  const params={p_id:id,p_token:reservation};
  const context=():Promise<Context>=>rpc('broadcast_operation_context',params);
  let c=await context();
  const token=await googleToken(new URLSearchParams({grant_type:'refresh_token',client_id:credentials.clientId,
    client_secret:credentials.clientSecret,refresh_token:c.refresh_token}));
  if(typeof token.access_token!=='string') throw new ProviderError(401,'owner_reconnection_required');
  const access=token.access_token;
  const call=(resource:string,query:Record<string,string>,method='GET',body?:unknown)=>api(access,resource,query,method,body);
  const result=(step:string,value:unknown)=>rpc('broadcast_provider_step',{...params,p_step:step,p_result:value});
  async function write(step:string,resource:string,query:Record<string,string>,method:string,body:unknown,project:(data:any)=>unknown) {
    c=await context(); // Fresh permission and destination fence before every privileged write.
    await rpc('broadcast_provider_step',{...params,p_step:step});
    try {
      const response=await call(resource,query,method,body);
      let projected:unknown;
      // The provider write already succeeded: a rejected result must be reconciled, not repeated.
      try {projected=project(response);}
      catch(error) {throw error instanceof ProviderError?new ProviderError(error.status,error.reason,true):error;}
      await result(step,projected);
    }
    catch(error) {
      // A failed persistence after a successful provider write is also ambiguous.
      await rpc('broadcast_provider_step',{...params,p_step:step,
        p_error:error instanceof ProviderError?error.reason:'result_persistence_failed',
        p_ambiguous:!(error instanceof ProviderError)||error.ambiguous}).catch(()=>{});
      throw error;
    }
    c=await context();
  }
  const marker=`Hadayah session ${id}`;
  function feed(data:any) {
    if(data.snippet?.channelId!==c.channel_id || data.contentDetails?.isReusable!==false) throw new ProviderError(409,'feed_identity_mismatch',true);
    if(typeof data.id!=='string'||typeof data.cdn?.ingestionInfo?.streamName!=='string'||!data.cdn.ingestionInfo.streamName) throw new ProviderError(409,'feed_result_invalid',true);
    return {id:data.id,url:ingestionAddress(data.cdn?.ingestionInfo?.rtmpsIngestionAddress),key:data.cdn?.ingestionInfo?.streamName};
  }
  function broadcast(data:any) {
    if(data.snippet?.channelId!==c.channel_id) throw new ProviderError(409,'broadcast_identity_mismatch',true);
    return {id:data.id};
  }
  async function find(resource:string) {
    let page=''; const matches:any[]=[];
    for(let i=0;i<20;i++) {
      const response=await call(resource,{part:resource==='liveStreams'?'id,snippet,contentDetails,cdn,status':'id,snippet,contentDetails,status',mine:'true',maxResults:'50',...(page?{pageToken:page}:{})});
      matches.push(...(response.items as any[]??[]).filter(item=>resource==='liveStreams'
        ?item.snippet?.title===marker:item.snippet?.description?.endsWith(marker)));
      page=response.nextPageToken as string??'';
      if(!page) return matches;
    }
    throw new ProviderError(409,'reconciliation_page_limit',true);
  }
  if(c.resource.needs_reconciliation) {
    if(c.resource.step==='stream_create' && !c.resource.provider_stream_id) {
      const matches=await find('liveStreams');
      if(matches.length!==1) throw new ProviderError(409,'feed_creation_unresolved',true);
      await result('stream_create',feed(matches[0]));
    } else if(c.resource.step==='broadcast_create' && !c.resource.provider_broadcast_id) {
      const matches=await find('liveBroadcasts');
      if(matches.length!==1) throw new ProviderError(409,'broadcast_creation_unresolved',true);
      await result('broadcast_create',broadcast(matches[0]));
    } else if(c.resource.provider_broadcast_id) {
      const observed=await call('liveBroadcasts',{part:'id,status,contentDetails,snippet',id:c.resource.provider_broadcast_id});
      const item=(observed.items as any[])?.[0];
      if(!item && c.resource.step==='transition_complete') await result('transition_complete',{status:'complete',deleted:true});
      else if(!item || item.snippet?.channelId!==c.channel_id) throw new ProviderError(409,'broadcast_reconciliation_unresolved',true);
      else if(c.resource.step==='bind') {
        if(item.contentDetails?.boundStreamId===c.resource.provider_stream_id) await result('bind',{});
        else if(!item.contentDetails?.boundStreamId) await result('reconcile',{});
        else throw new ProviderError(409,'binding_destination_mismatch',true);
      }
      else if(c.resource.step==='transition_live'||c.resource.step==='transition_complete') await result('observe',{status:item.status.lifeCycleStatus});
      else if(c.resource.step==='feed_delete') {
        const stream=await call('liveStreams',{part:'id',id:c.resource.provider_stream_id!});
        if((stream.items as any[])?.length===0) await result('feed_delete',{});
        else await result('reconcile',{}); // Known existing feed; retry deletion only after completion.
      } else throw new ProviderError(409,'provider_write_unresolved',true);
    } else throw new ProviderError(409,'provider_write_unresolved',true);
    c=await context();
  }
  if(c.resource.operation==='prepare') {
    if(!c.resource.provider_stream_id) await write('stream_create','liveStreams',{part:'id,snippet,cdn,contentDetails'},'POST',{
      snippet:{title:marker,description:marker},cdn:{frameRate:'variable',resolution:'variable',ingestionType:'rtmp'},contentDetails:{isReusable:false},
    },feed);
    if(!c.resource.provider_broadcast_id) await write('broadcast_create','liveBroadcasts',{part:'id,snippet,status,contentDetails'},'POST',{
      snippet:{title:Array.from(c.session.title_en||c.session.title_ar).slice(0,100).join(''),description:`${c.session.description}\n${marker}`,
        scheduledStartTime:c.session.scheduled_start_at,scheduledEndTime:c.session.expected_end_at},
      status:{privacyStatus:'public',selfDeclaredMadeForKids:false},contentDetails:{enableAutoStart:false,enableAutoStop:false,
        enableDvr:true,recordFromStart:true,monitorStream:{enableMonitorStream:false}},
    },broadcast);
    if(!c.resource.bound) await write('bind','liveBroadcasts/bind',{part:'id,contentDetails',id:c.resource.provider_broadcast_id!,streamId:c.resource.provider_stream_id!},'POST',undefined,data=>{
      if(data.contentDetails?.boundStreamId!==c.resource.provider_stream_id) throw new ProviderError(409,'binding_unconfirmed',true);
      return {};
    });
  }
  let provider:any=null;
  if(c.resource.provider_broadcast_id && !c.resource.broadcast_deleted) {
    provider=(await call('liveBroadcasts',{part:'id,snippet,status,contentDetails',id:c.resource.provider_broadcast_id})).items;
    provider=provider?.[0];
    if(!provider || provider.snippet?.channelId!==c.channel_id) throw new ProviderError(404,'broadcast_missing');
    await result('observe',{status:provider.status.lifeCycleStatus});c=await context();
  }
  if(c.resource.operation==='start' && provider && !['live','liveStarting','complete','revoked'].includes(provider.status.lifeCycleStatus)) {
    const sending=(await call('liveStreams',{part:'id,status',id:c.resource.provider_stream_id!})).items as any[];
    if(sending?.[0]?.status?.streamStatus!=='active') throw new ProviderError(409,'waiting_for_encoder');
    await write('transition_live','liveBroadcasts/transition',{part:'id,status',id:c.resource.provider_broadcast_id!,broadcastStatus:'live'},'POST',undefined,
      data=>({status:data.status.lifeCycleStatus}));
  }
  if(c.resource.operation==='end' && provider && !['complete','revoked'].includes(provider.status.lifeCycleStatus)) {
    // Upcoming/preparing broadcasts cannot transition to complete. Delete the never-live broadcast instead.
    if(['created','ready'].includes(provider.status.lifeCycleStatus)) {
      await write('transition_complete','liveBroadcasts',{id:c.resource.provider_broadcast_id!},'DELETE',undefined,()=>({status:'complete',deleted:true}));
    } else await write('transition_complete','liveBroadcasts/transition',{part:'id,status',id:c.resource.provider_broadcast_id!,broadcastStatus:'complete'},'POST',undefined,
      data=>({status:data.status.lifeCycleStatus}));
  }
  if(c.resource.operation==='end' && !c.resource.provider_broadcast_id) {
    await result('observe',{status:'complete'});c=await context();
  }
  if(['processing_replay','completed','cancelled'].includes(c.session.state) && c.resource.provider_stream_id && !c.resource.feed_retired) {
    await write('feed_delete','liveStreams',{id:c.resource.provider_stream_id},'DELETE',undefined,()=>({}));
  }
  if(c.session.state==='processing_replay' && c.session.stream_id) {
    if(c.resource.broadcast_deleted) {await result('observe',{replay:'missing'});c=await context();}
    else {
    const video=(await call('videos',{part:'id,status,processingDetails',id:c.session.stream_id})).items as any[];
    const replay=video?.[0]?.status?.uploadStatus;
    if(replay==='processed') await result('observe',{replay:'available'});
    else if(['failed','rejected','deleted'].includes(replay)||(!video?.length && Date.now()-Date.parse(c.session.expected_end_at)>24*3600000)) await result('observe',{replay:'missing'});
    }
  } else if(c.session.state==='processing_replay' && !c.session.stream_id) {
    await result('observe',{replay:'missing'});
  }
  c=await context();
  await rpc('broadcast_provider_step',{...params,p_step:'finish'});
  // Only the preparing presenter receives ingest credentials. Never persist them on the client.
  return {session:c.session,...(c.resource.operation==='prepare'?{ingest_url:c.resource.ingest_url,ingest_key:c.ingest_key}:{}),
    termination_pending:c.session.state==='ending'};
}
