// Independent PostgreSQL connections; only an explicitly named local audit container.
// Run: node brief/tools/broadcast_session_concurrency.mjs <docker executable>
import { spawn } from 'node:child_process';
import assert from 'node:assert/strict';

const docker = process.argv[2] || 'docker';
const container = 'supabase_db_P6S_astra_20260926';
class Connection {
  constructor(name) {
    this.pending = null;
    this.buffer = '';
    this.serial = 0;
    this.proc = spawn(docker, ['exec', '-i', container, 'psql', '-XqAt',
      '-v', 'ON_ERROR_STOP=1', '-U', 'postgres', '-d', 'postgres'],
    { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    this.proc.stdout.on('data', chunk => {
      this.buffer += chunk;
      const p = this.pending;
      if (p && this.buffer.includes(p.marker + '\n')) {
        const output = this.buffer.slice(0, this.buffer.indexOf(p.marker)).trim();
        this.buffer = this.buffer.slice(this.buffer.indexOf(p.marker) + p.marker.length + 1);
        this.pending = null;
        clearTimeout(p.timer);
        p.resolve(output);
      }
    });
    this.proc.stderr.on('data', chunk => process.stderr.write(`${name}: ${chunk}`));
    this.proc.on('error', error => this.pending?.reject(error));
    this.proc.on('exit', code => {
      if (this.pending) {
        clearTimeout(this.pending.timer);
        this.pending.reject(new Error(`${name} exited ${code}`));
      }
    });
  }
  query(sql) {
    assert.equal(this.pending, null, 'one statement at a time per connection');
    return new Promise((resolve, reject) => {
      const marker = `__audit_${++this.serial}__`;
      const timer = setTimeout(() => {
        reject(new Error('Database probe timed out after 15s'));
        this.proc.kill();
      }, 15000);
      this.pending = { marker, resolve, reject, timer };
      this.proc.stdin.write(`${sql};\nselect '${marker}';\n`);
    });
  }
  close() { this.proc.stdin.end('rollback;\n\\q\n'); }
}
const owner = '69000000-0000-4000-8000-000000000002';
const claim = `set role authenticated; set request.jwt.claims = '{"sub":"${owner}","role":"authenticated"}'`;
const admin = new Connection('observer');
const starter = new Connection('starter');
const ender = new Connection('ender');
let failures = 0;
try {
  await admin.query(`insert into auth.users(id,email) values ('${owner}','race@example.invalid');
    insert into public.profiles(id,email,is_streamer,is_verified)
      values ('${owner}','race@example.invalid',true,true);
    insert into public.device_sessions(user_id,device_id,is_primary_broadcaster,last_active_at)
      values ('${owner}','race-device',true,now())`);
  await starter.query(claim);
  await ender.query(claim);
  const pid = await ender.query('select pg_backend_pid()');
  for (const sameWatch of [false, true]) {
    const oldId = await starter.query(`select public.start_broadcast_session('liveVideo','RACEOLD0001','race-device',null,'phone_direct')`);
    // Start owns the common lock. End can read the old row on the vulnerable
    // implementation, but must now wait. Observe the actual lock wait rather
    // than hoping a sleep picked the right schedule.
    await starter.query('begin; select pg_advisory_xact_lock(20260920,12)');
    const pendingEnd = ender.query(`select public.end_broadcast_session('${oldId}','race-device')`);
    let blocked = false;
    for (let n = 0; n < 100; n++) {
      const state = await admin.query(`select wait_event_type || ':' || wait_event from pg_stat_activity where pid=${Number(pid)}`);
      if (state === 'Lock:advisory') { blocked = true; break; }
      await new Promise(resolve => setTimeout(resolve, 20));
    }
    assert.ok(blocked, 'End must be observed waiting on the common advisory lock');
    const newWatch = sameWatch ? 'RACEOLD0001' : 'RACENEW0001';
    if (sameWatch) await starter.query(`select public.end_broadcast_session('${oldId}','race-device')`);
    const newId = await starter.query(`select public.start_broadcast_session('liveVideo','${newWatch}','race-device',null,'phone_direct')`);
    assert.notEqual(newId, oldId);
    await starter.query('commit');
    await pendingEnd;
    const state = JSON.parse(await admin.query(`select json_build_object('live',p.is_currently_live,'watch',p.active_stream_id,'state',b.state)
      from public.profiles p join public.broadcast_sessions b on b.id='${newId}' where p.id='${owner}'`));
    const passed = state.live && state.watch === newWatch && state.state === 'live';
    console.log(JSON.stringify({test: sameWatch ? 'same-watch-replacement' : 'different-watch-replacement', endObservedWaiting: blocked, passed, result: state}));
    if (!passed) failures++;
    await starter.query(`select public.end_broadcast_session('${newId}','race-device')`);
  }
} finally {
  await starter.query('rollback').catch(() => {});
  await admin.query(`delete from auth.users where id='${owner}'`).catch(() => {});
  starter.close(); ender.close(); admin.close();
}
assert.equal(failures, 0, 'A stale concurrent End terminated a newer broadcast');
