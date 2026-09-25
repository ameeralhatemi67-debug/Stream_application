// Executes the actual HTML exported by youtube_embed_page_test.dart.
// This checks our JS boundary, not real YouTube/network or Android playback.
import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
const html=fs.readFileSync(process.argv[2], 'utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
const messages=[], commands=[], listeners={};
let callbacks, interval, player;
const ctx={
  window: {FlutterYouTubeBridge:true, addEventListener:(name,fn)=>listeners[name]=fn},
  FlutterYouTubeBridge:{postMessage:json=>messages.push(JSON.parse(json))},
  setInterval:fn=>interval=fn,
  YT:{Player:function(id,options){
    assert.equal(id,'youtube-player'); callbacks=options.events;
    player=this; this.muted=false; this.state=-1;
    this.isMuted=()=>this.muted; this.getPlayerState=()=>this.state;
    this.mute=()=>{commands.push('mute');this.muted=true;};
    this.unMute=()=>{commands.push('unMute');this.muted=false;};
    this.playVideo=()=>commands.push('playVideo');
    this.pauseVideo=()=>commands.push('pauseVideo');
  }},
};
vm.createContext(ctx); vm.runInContext(script,ctx);
assert.equal(ctx.playerCommand('playVideo'),'none','refuse commands before SDK readiness');
assert.equal(listeners.message,undefined,'no raw cross-window message can spoof playback');
ctx.onYouTubeIframeAPIReady();
callbacks.onReady({target:{}});
assert.equal(ctx.playerCommand('playVideo'),'none','ignore readiness from a different player');
callbacks.onReady({target:player});
assert.deepEqual(commands,['mute','playVideo']);
assert.ok(messages.some(m=>m.type==='state'&&m.value===-1),'blocked autoplay remains unstarted');
assert.equal(ctx.playerCommand('pauseVideo'),'ok');
assert.equal(messages.filter(m=>m.type==='state').length,1,'command delivery never fabricates state');
callbacks.onStateChange({target:{},data:1});
assert.equal(messages.filter(m=>m.type==='state').length,1,'ignore another player');
callbacks.onStateChange({target:player,data:2});
assert.deepEqual(messages.at(-1),{type:'state',value:2});
player.muted=false; interval();
assert.deepEqual(messages.at(-1),{type:'muted',value:false},'built-in mute changes propagate');
assert.equal(ctx.playerCommand('loadVideoById'),'none','commands cannot replace identity');
callbacks.onError({target:player,data:150});
assert.deepEqual(messages.at(-1),{type:'error',code:150});
console.log('PASS: readiness, exact player identity, command delivery versus confirmation, mute, error and command allowlist');
