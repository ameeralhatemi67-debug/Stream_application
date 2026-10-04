import assert from 'node:assert/strict';
import {pathToFileURL} from 'node:url';

// Uses only synthetic credentials and a local fetch stub; never contacts Auth.
const {createClient} = await import(process.argv[2]
  ? pathToFileURL(process.argv[2]).href : '@supabase/supabase-js');
const actor = {id:'00000000-0000-4000-8000-000000000001',aud:'authenticated',
  app_metadata:{},user_metadata:{},created_at:'2026-10-04T00:00:00Z'};
let calls = 0;
const forwarded = [];
function client(headers) {
  return createClient('https://test.invalid','synthetic-anon-key',{
    global:{headers,fetch:async (_url, options) => {
      calls++;
      const header = new Headers(options.headers).get('authorization');
      forwarded.push(header);
      if (header !== 'Bearer synthetic-session') return new Response(
        JSON.stringify({message:'Invalid JWT',code:'bad_jwt'}),{status:401,headers:{'content-type':'application/json'}});
      return new Response(JSON.stringify(actor),{headers:{'content-type':'application/json'}});
    }},auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},
  });
}
const original = await client({authorization:'Bearer synthetic-session'}).auth.getUser();
assert.equal(original.data.user,null);
assert.ok(original.error);
assert.notEqual(forwarded[0],'Bearer synthetic-session');
const repaired = await client({Authorization:'Bearer synthetic-session'}).auth.getUser('synthetic-session');
assert.equal(repaired.error,null);
assert.equal(repaired.data.user.id,actor.id);
assert.equal(calls,2);
assert.equal(forwarded[1],'Bearer synthetic-session');
console.log('PASS: lowercase forwarded header collides with SDK Authorization default and Auth rejects it; canonical header + explicit token verifies the session.');
