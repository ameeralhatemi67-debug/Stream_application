// Pure provider boundary checks; no live API, account or credential required.
import assert from 'node:assert/strict';
import {ownedChannel,requirePublishingScope,ingestionAddress,publishingScope} from '../../supabase/functions/_shared/youtube_broadcast.ts';
assert.throws(()=>ownedChannel({items:[]}));
assert.throws(()=>ownedChannel({items:[{id:'forged',snippet:{title:'x'}}]}));
assert.deepEqual(ownedChannel({items:[{id:'UC'+'a'.repeat(22),snippet:{title:'Verified channel'}}]}),
  {id:'UC'+'a'.repeat(22),title:'Verified channel'});
assert.throws(()=>requirePublishingScope('https://www.googleapis.com/auth/youtube.readonly'));
requirePublishingScope(publishingScope);
// The address YouTube actually returns (also OBS's built-in YouTube - RTMPS server).
assert.equal(ingestionAddress('rtmps://a.rtmps.youtube.com/live2'),'rtmps://a.rtmps.youtube.com/live2');
assert.equal(ingestionAddress('rtmps://a.rtmps.youtube.com:443/live2'),'rtmps://a.rtmps.youtube.com:443/live2');
assert.equal(ingestionAddress('rtmps://a.rtmp.youtube.com/live2'),'rtmps://a.rtmp.youtube.com/live2');
for(const address of ['rtmp://a.rtmp.youtube.com/live2','rtmps://youtube.com.evil.invalid/live2','rtmps://a.rtmps.youtube.com.evil.invalid/live2',
  'rtmps://a.rtmp.youtube.com:123/live2','rtmps://user:key@a.rtmp.youtube.com/live2']) {
  assert.throws(()=>ingestionAddress(address));
}
console.log('Provider ownership, scope and RTMPS boundary checks passed');
