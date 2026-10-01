// Run against only the named disposable database, never the linked project.
// node brief/tools/organization_v1_db_check.mjs <docker.exe>
import {spawnSync} from 'node:child_process';
import {readFileSync,readdirSync,writeFileSync,mkdirSync} from 'node:fs';
import assert from 'node:assert/strict';
const docker=process.argv[2] || 'docker';
const container='supabase_db_P6_accept_disposable';
const database='org_v1_audit_20261001';
const out='brief/.runtime/organization-v1';
mkdirSync(out,{recursive:true});
if(process.argv.includes('--rebuild')) {
  const reset=spawnSync(docker,['exec',container,'sh','-c',
    'dropdb -U supabase_admin org_v1_audit_20261001 && createdb -U supabase_admin -O postgres org_v1_audit_20261001 && psql -X -v ON_ERROR_STOP=1 -U supabase_admin -d org_v1_audit_20261001 -f /tmp/org_v1_schema.sql > /tmp/org_v1_restore.log 2>&1'],
    {encoding:'utf8',windowsHide:true,timeout:60000});
  assert.equal(reset.status,0,reset.stderr);
}
function sql(input) {
  const result=spawnSync(docker,['exec','-i',container,'psql','-XAt','-v','ON_ERROR_STOP=1',
    '-U','supabase_admin','-d',database],{input,encoding:'utf8',windowsHide:true,timeout:60000,maxBuffer:8e6});
  if(result.error || result.status!==0) throw new Error(result.stderr || result.error?.message);
  return result.stdout;
}
assert.equal(sql('select current_database();').trim(),database);
sql('create extension if not exists pgtap with schema extensions;');
const installed=new Set(sql('select version from supabase_migrations.schema_migrations;').trim().split('\n'));
for(const file of readdirSync('supabase/migrations').filter(f=>f.endsWith('.sql')).sort()) {
  const version=file.split('_')[0];
  // Schema copy is at 20260923140000. Its migration table has no copied data.
  if(version<='20260923140000' || installed.has(version)) continue;
  sql(readFileSync('supabase/migrations/'+file,'utf8'));
  sql(`insert into supabase_migrations.schema_migrations(version) values('${version}');`);
  console.log('APPLIED '+file);
}
const output=sql(readFileSync('supabase/tests/organization_v1_memberships.test.sql','utf8'));
writeFileSync(out+'/membership-sql.txt',output);
console.log(output);
assert.doesNotMatch(output,/not ok|Looks like you failed|planned \d+ tests but ran/);
