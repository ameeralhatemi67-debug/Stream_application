import {accessToken,forgetAccessToken,ingestionAddress,ProviderError,youtube} from './youtube_broadcast.ts';

type Rpc = (name:string,params:Record<string,unknown>) => Promise<any>;
type Api = typeof youtube;
type Context = {
  session:{id:string;owner_id:string;org_id:string|null;device_id:string;state:string;title_en:string;title_ar:string;
    description:string;scheduled_start_at:string;expected_end_at:string;ended_at:string|null;replay_status:string;stream_id:string|null;
    started_at:string|null;hide_replay:boolean;replay_taken_down:boolean;recording_delete_requested_at:string|null;
    recording_deleted_at:string|null},
  resource:{operation:string;step:string|null;needs_reconciliation:boolean;provider_stream_id:string|null;
    provider_broadcast_id:string|null;ingest_url:string|null;bound:boolean;feed_retired:boolean;broadcast_deleted:boolean;
    replay_privacy:'public'|'private'|null},
  channel_id:string;refresh_token:string;ingest_key:string|null;
};

// YouTube shows a finished live as a post-live recording at once but reports
// it 'processed' only hours later (about 12 h observed). A recording YouTube
// did not keep ("This live stream recording is not available") stays
// 'uploaded' for good, so after this long the replay counts as missing.
export const replayGiveUpMs = 48*3600000;

export type RunOptions = {
  /** Keeps work running after the response is sent (EdgeRuntime.waitUntil). */
  background?: (task:Promise<void>) => void;
  /** How long one 'start' call waits for YouTube before asking the caller to try again. */
  startBudgetMs?: number;
  pollMs?: number;
  sleep?: (ms:number) => Promise<void>;
};

export async function runBroadcast(id:string,reservation:string,rpc:Rpc,
  credentials:{clientId:string;clientSecret:string},api:Api=youtube,options:RunOptions={}):Promise<Record<string,unknown>> {
  const params={p_id:id,p_token:reservation};
  const context=():Promise<Context>=>rpc('broadcast_operation_context',params);
  let c=await context();
  const refresh=c.refresh_token;
  const access=await accessToken(credentials,refresh);
  const call=async(resource:string,query:Record<string,string>,method='GET',body?:unknown)=>{
    try {return await api(access,resource,query,method,body);}
    catch(error) {
      // A revoked or expired grant: the next operation asks Google again.
      if(error instanceof ProviderError && error.status===401) forgetAccessToken(credentials,refresh);
      throw error;
    }
  };
  const poll=options.pollMs??1000;
  const sleep=options.sleep??((ms:number)=>new Promise<void>(resolve=>setTimeout(resolve,ms)));
  const startDeadline=Date.now()+(options.startBudgetMs??15000);
  const result=(step:string,value:unknown)=>rpc('broadcast_provider_step',{...params,p_step:step,p_result:value});
  async function write(step:string,resource:string,query:Record<string,string>,method:string,body:unknown,project:(data:any)=>unknown,
    request?:()=>Promise<any>) {
    c=await context(); // Fresh permission and destination fence before every privileged write.
    await rpc('broadcast_provider_step',{...params,p_step:step});
    try {
      const response=await (request?request():call(resource,query,method,body));
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
  const title=()=>Array.from(c.session.title_en||c.session.title_ar).slice(0,100).join('');
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
  // Ultra-low latency keeps the phone-to-viewer delay to a few seconds. A
  // channel YouTube refuses it for still goes live, with low latency.
  async function insertBroadcast() {
    const body=(latencyPreference:string)=>({
      snippet:{title:title(),description:`${c.session.description}\n${marker}`,
        scheduledStartTime:c.session.scheduled_start_at,scheduledEndTime:c.session.expected_end_at},
      status:{privacyStatus:'public',selfDeclaredMadeForKids:false},contentDetails:{enableAutoStart:false,enableAutoStop:false,
        enableDvr:true,recordFromStart:true,latencyPreference,monitorStream:{enableMonitorStream:false}},
    });
    const query={part:'id,snippet,status,contentDetails'};
    try {return await call('liveBroadcasts',query,'POST',body('ultraLow'));}
    catch(error) {
      if(!(error instanceof ProviderError) || error.status!==400 || !/latency/i.test(error.reason)) throw error;
      return await call('liveBroadcasts',query,'POST',body('low'));
    }
  }
  // The studio prepares a broadcast as soon as it opens, before the presenter
  // has chosen a title. Best effort: going live never waits on the title.
  async function retitle(item:any) {
    const wanted=title();
    if(!wanted || item.snippet?.title===wanted || !['created','ready'].includes(item.status?.lifeCycleStatus)) return;
    const scheduled=Date.parse(item.snippet?.scheduledStartTime??'');
    const start=Math.max(Number.isNaN(scheduled)?0:scheduled,Date.now()+60000);
    const end=Date.parse(c.session.expected_end_at);
    try {
      await call('liveBroadcasts',{part:'id,snippet'},'PUT',{id:c.resource.provider_broadcast_id,snippet:{title:wanted,
        description:`${c.session.description}\n${marker}`,scheduledStartTime:new Date(start).toISOString(),
        ...(end>start?{scheduledEndTime:new Date(end).toISOString()}:{})}});
    } catch(error) {
      console.error(JSON.stringify({session:id,reason:error instanceof ProviderError?`title_${error.reason}`:'title_update_failed'}));
    }
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
    } else if(c.resource.step==='recording_privacy') {
      // settle() reads the video again and writes only what still differs.
      await result('reconcile',{});
    } else if(c.resource.step==='recording_delete') {
      const left=await call('videos',{part:'id',id:c.session.stream_id!});
      await result((left.items as any[])?.length?'reconcile':'recording_delete',{});
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
    if(!c.resource.provider_broadcast_id) await write('broadcast_create','liveBroadcasts',{},'POST',undefined,broadcast,insertBroadcast);
    if(!c.resource.bound) await write('bind','liveBroadcasts/bind',{part:'id,contentDetails',id:c.resource.provider_broadcast_id!,streamId:c.resource.provider_stream_id!},'POST',undefined,data=>{
      if(data.contentDetails?.boundStreamId!==c.resource.provider_stream_id) throw new ProviderError(409,'binding_unconfirmed',true);
      return {};
    });
  }
  let provider:any=null;
  // After the live YouTube's broadcast is complete; only the feed and the
  // replay are left, and an owner-deleted broadcast must not block them.
  const over=['processing_replay','completed','cancelled'].includes(c.session.state);
  if(c.resource.provider_broadcast_id && !c.resource.broadcast_deleted && !over) {
    provider=(await call('liveBroadcasts',{part:'id,snippet,status,contentDetails',id:c.resource.provider_broadcast_id})).items;
    provider=provider?.[0];
    if(!provider || provider.snippet?.channelId!==c.channel_id) throw new ProviderError(404,'broadcast_missing');
    await result('observe',{status:provider.status.lifeCycleStatus});c=await context();
  }
  // Observing a live broadcast (the every-minute reconcile job, or a client's observe call): is
  // YouTube still receiving video? A dead phone or a laptop that lost its connection cannot report
  // this itself. broadcast_observe_feed() marks
  // the session interrupted (viewers see "be right back"); sweep_stale_live_flags() ends it when
  // the feed has not returned within the grace window.
  if(c.resource.operation==='observe' && c.session.state==='live' && provider?.status?.lifeCycleStatus==='live'
    && c.resource.provider_stream_id) {
    const feed=((await call('liveStreams',{part:'id,status',id:c.resource.provider_stream_id})).items as any[])?.[0];
    const active=feed?.status?.streamStatus==='active' && feed?.status?.healthStatus?.status!=='noData';
    await rpc('broadcast_observe_feed',{...params,p_active:active});
  }
  if(c.resource.operation==='start' && provider && !['live','liveStarting','complete','revoked'].includes(provider.status.lifeCycleStatus)) {
    const titled=retitle(provider);
    try {
      // Wait here, checking every second, until YouTube receives the encoder,
      // instead of making the phone call back every few seconds.
      for(;;) {
        const sending=(await call('liveStreams',{part:'id,status',id:c.resource.provider_stream_id!})).items as any[];
        if(sending?.[0]?.status?.streamStatus==='active') break;
        if(Date.now()+poll>startDeadline) throw new ProviderError(409,'waiting_for_encoder');
        await sleep(poll);
      }
    } finally {await titled;}
    await write('transition_live','liveBroadcasts/transition',{part:'id,status',id:c.resource.provider_broadcast_id!,broadcastStatus:'live'},'POST',undefined,
      data=>({status:data.status.lifeCycleStatus}));
  }
  // YouTube answers a transition with liveStarting and goes live a few seconds
  // later. Waiting for it here confirms the live in this one call.
  if(c.resource.operation==='start' && c.session.state==='preparing' && provider && !c.resource.broadcast_deleted) {
    while(Date.now()+poll<=startDeadline) {
      await sleep(poll);
      const status=((await call('liveBroadcasts',{part:'id,status',id:c.resource.provider_broadcast_id!})).items as any[])?.[0]?.status?.lifeCycleStatus;
      if(status==='liveStarting') continue;
      if(typeof status==='string') {await result('observe',{status});c=await context();}
      break;
    }
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
  // After the live the recording follows the owner: deleted when asked, and
  // private on YouTube while hidden in the app (public again when shown).
  async function recording() {
    const video=c.session.stream_id;
    if(!['processing_replay','completed'].includes(c.session.state) || !c.session.started_at || !video
      || c.resource.broadcast_deleted || c.session.recording_deleted_at) return;
    if(c.session.recording_delete_requested_at) {
      await write('recording_delete','videos',{id:video},'DELETE',undefined,()=>({}),
        ()=>call('videos',{id:video},'DELETE').catch(error=>{
          if(error instanceof ProviderError && error.status===404) return {};
          throw error;
        }));
      return;
    }
    const wanted=c.session.hide_replay||c.session.replay_taken_down?'private':'public';
    if((c.resource.replay_privacy??'public')===wanted) return;
    const item=((await call('videos',{part:'id,status',id:video})).items as any[])?.[0];
    if(!item || item.status?.privacyStatus===wanted) {
      // Gone from YouTube, or already as wanted: nothing to write.
      await result('recording_privacy',{privacy:wanted});c=await context();
      return;
    }
    // A status update erases the status fields it is not sent, so the current
    // ones go back unchanged with the new privacy.
    const {embeddable,license,publicStatsViewable}=item.status;
    const body={id:video,status:{privacyStatus:wanted,embeddable,license,publicStatsViewable}};
    await write('recording_privacy','videos',{part:'status'},'PUT',body,data=>{
      if(data.refused) return {refused:wanted};
      if(data.status?.privacyStatus!==wanted) throw new ProviderError(409,'privacy_unconfirmed',true);
      return {privacy:wanted};
    },()=>call('videos',{part:'status'},'PUT',body).catch(error=>{
      // YouTube will not change this video. Each attempt costs 50 quota units,
      // so it is tried again only every few hours (the claim's rule).
      if(error instanceof ProviderError && !error.ambiguous && [400,403].includes(error.status)) return {refused:true};
      throw error;
    }));
  }
  async function settle() {
    await recording();
    if(['processing_replay','completed','cancelled'].includes(c.session.state) && c.resource.provider_stream_id && !c.resource.feed_retired) {
      // A feed already gone from YouTube is retired, not deleted again on every check.
      await write('feed_delete','liveStreams',{id:c.resource.provider_stream_id},'DELETE',undefined,()=>({}),
        ()=>call('liveStreams',{id:c.resource.provider_stream_id!},'DELETE').catch(error=>{
          if(error instanceof ProviderError && error.status===404) return {};
          throw error;
        }));
    }
    if(c.session.state==='processing_replay' && c.session.stream_id) {
      if(c.resource.broadcast_deleted) {await result('observe',{replay:'missing'});c=await context();}
      else {
      const video=((await call('videos',{part:'id,status,processingDetails',id:c.session.stream_id})).items as any[])?.[0];
      const upload=video?.status?.uploadStatus,processing=video?.processingDetails?.processingStatus;
      const overdue=Date.now()-Date.parse(c.session.ended_at??c.session.expected_end_at)>replayGiveUpMs;
      if(upload==='processed'||processing==='succeeded') await result('observe',{replay:'available'});
      else if(['failed','rejected','deleted'].includes(upload)||processing==='failed'||overdue
        ||(!video && Date.now()-Date.parse(c.session.expected_end_at)>24*3600000)) await result('observe',{replay:'missing'});
      }
    } else if(c.session.state==='processing_replay' && !c.session.stream_id) {
      await result('observe',{replay:'missing'});
    }
    c=await context();
    await rpc('broadcast_provider_step',{...params,p_step:'finish'});
  }
  // YouTube has ended the broadcast and viewers already see it ended. Retiring
  // the feed and checking the replay finish after the presenter is answered.
  if(c.resource.operation==='end' && options.background) {
    const response={session:c.session,termination_pending:c.session.state==='ending'};
    options.background(settle());
    return response;
  }
  await settle();
  // Only the preparing presenter receives ingest credentials. Never persist them on the client.
  return {session:c.session,...(c.resource.operation==='prepare'?{ingest_url:c.resource.ingest_url,ingest_key:c.ingest_key}:{}),
    termination_pending:c.session.state==='ending'};
}
