// node --experimental-transform-types brief/tools/broadcast_control_check.mjs
import assert from 'node:assert/strict';
import {runBroadcast} from '../../supabase/functions/_shared/broadcast_control.ts';
import {ProviderError} from '../../supabase/functions/_shared/youtube_broadcast.ts';
globalThis.fetch=async()=>Response.json({access_token:'fake-access'});
const id='99000000-0000-4000-8000-000000000010',channel='UCaaaaaaaaaaaaaaaaaaaaaa';
function harness(fault) {
 const counts={stream:0,broadcast:0,bind:0,end:0,delete:0};let encoder=false,providerStatus='ready';
 const c={session:{id,owner_id:'presenter',org_id:'org',state:'preparing',title_en:'Pilot',title_ar:'',description:'',
   scheduled_start_at:new Date().toISOString(),expected_end_at:new Date(Date.now()+3600000).toISOString(),stream_id:null},
 resource:{operation:'prepare',step:null,needs_reconciliation:false,provider_stream_id:null,provider_broadcast_id:null,
   ingest_url:null,bound:false,feed_retired:false,broadcast_deleted:false},channel_id:channel,refresh_token:'fake-refresh',ingest_key:null};
 let stream=null,broadcast=null;
 async function rpc(name,p) {
  if(name==='broadcast_operation_context') return structuredClone(c);
  assert.equal(name,'broadcast_provider_step');
  if(p.p_error){c.resource.needs_reconciliation=p.p_ambiguous;return;}
  const step=p.p_step,result=p.p_result;
  if(!result && !['finish','reconcile','observe'].includes(step)){
   assert.equal(c.resource.needs_reconciliation,false,'creation must be reconciled first');
   c.resource.step=step;c.resource.needs_reconciliation=true;return;
  }
  if(step==='stream_create'){c.resource.provider_stream_id=result.id;c.resource.ingest_url=result.url;c.ingest_key=result.key;}
  if(step==='broadcast_create'){c.resource.provider_broadcast_id=result.id;c.session.stream_id=result.id;}
  if(step==='bind')c.resource.bound=true;
  if(step==='feed_delete')c.resource.feed_retired=true;
  if(['observe','transition_live','transition_complete'].includes(step)&&result){
   if(result.status==='live'&&c.session.state==='preparing')c.session.state='live';
   if(result.status==='complete'){c.session.state='processing_replay';c.session.replay_status='processing';}
   if(result.replay){c.session.state='completed';c.session.replay_status=result.replay;}
  }
  if(step!=='finish')c.resource.needs_reconciliation=false;
 }
 async function api(token,resource,params,method='GET',body){
  assert.equal(token,'fake-access');
  if(resource==='liveStreams'&&method==='POST'){
   counts.stream++;assert.equal(body.contentDetails.isReusable,false);
   if(fault!=='unresolved')stream={id:'feed',snippet:{...body.snippet,channelId:channel},contentDetails:body.contentDetails,
     cdn:{ingestionInfo:{rtmpsIngestionAddress:'rtmps://a.rtmp.youtube.com/live2',streamName:'fake-ingest'}}};
   if(['stream','unresolved'].includes(fault)){fault=null;throw new ProviderError(503,'timeout',true);}
   return stream;
  }
  if(resource==='liveBroadcasts'&&method==='POST'){
   counts.broadcast++;assert.equal(body.contentDetails.enableAutoStart,false);assert.equal(body.status.privacyStatus,'public');
   broadcast={id:'abcdefghijk',snippet:{...body.snippet,channelId:channel},contentDetails:{},status:{lifeCycleStatus:providerStatus}};
   if(fault==='broadcast'){fault=null;throw new ProviderError(503,'timeout',true);}return broadcast;
  }
  if(resource==='liveBroadcasts/bind'){
   counts.bind++;broadcast.contentDetails.boundStreamId=params.streamId;return broadcast;
  }
  if(resource==='liveStreams'&&method==='GET')return {items:stream?[{...stream,status:{streamStatus:encoder?'active':'inactive'}}]:[]};
  if(resource==='liveBroadcasts'&&method==='GET')return {items:broadcast?[{...broadcast,status:{lifeCycleStatus:providerStatus}}]:[]};
  if(resource==='liveBroadcasts/transition'){
   if(params.broadcastStatus==='live'){providerStatus='liveStarting';return {status:{lifeCycleStatus:providerStatus}};}
   counts.end++;
   if(fault==='end'){fault=null;throw new ProviderError(500,'backendError',true);}
   providerStatus='complete';return {status:{lifeCycleStatus:'complete'}};
  }
  if(resource==='liveStreams'&&method==='DELETE'){
   assert.equal(providerStatus,'complete','bound feed is retired only after completion');counts.delete++;return {};
  }
  if(resource==='videos')return {items:[{status:{uploadStatus:'processed'}}]};
  throw new Error('Unexpected API operation '+resource+' '+method);
 }
 return {c,counts,run:()=>runBroadcast(id,'reservation',rpc,{clientId:'client',clientSecret:'secret'},api),
   sending:()=>{encoder=true;},live:()=>{providerStatus='live';},end:()=>{c.resource.operation='end';c.session.state='ending';}};
}
for(const fault of [null,'stream','broadcast']){
 const h=harness(fault);
 if(fault)await assert.rejects(h.run(),/timeout/);
 let response=await h.run();assert.equal(response.session.state,'preparing');assert.equal(response.ingest_key,'fake-ingest');
 await h.run();assert.deepEqual(h.counts,{stream:1,broadcast:1,bind:1,end:0,delete:0});
 h.c.resource.operation='start';await assert.rejects(h.run(),/waiting_for_encoder/);assert.equal(h.c.session.state,'preparing');
 h.sending();await h.run();assert.equal(h.c.session.state,'preparing');h.live();h.c.resource.operation='observe';await h.run();assert.equal(h.c.session.state,'live');
 h.end();response=await h.run();assert.equal(response.session.replay_status,'available');assert.equal(h.counts.delete,1);
 await h.run();assert.equal(h.counts.end,1);assert.equal(h.counts.delete,1);
}
const unresolved=harness('unresolved');await assert.rejects(unresolved.run(),/timeout/);
await assert.rejects(unresolved.run(),/feed_creation_unresolved/);assert.equal(unresolved.counts.stream,1);
console.log('Provider preparation, ambiguous writes, confirmation, independent completion and replay checks passed');
