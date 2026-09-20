#!/usr/bin/env node
// Scans a BUILT artifact (.aab / .apk / .zip / an unpacked folder) for leaked Supabase secrets.
//   node brief/tools/scan_build_secrets.mjs path/to/app-release.aab
// Prints counts and inner file names only, NEVER the secret values. Exit code 1 when a service-role key,
// sb_secret key, private key or DB URL with password is found. Anon keys are expected (they ship in every client).
// Note: --dart-define values are compiled into libapp.so as plain strings, so this catches a wrong key in dart_define.local.json.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const target = process.argv[2];
if (!target || !fs.existsSync(target)) {
  console.error('usage: node brief/tools/scan_build_secrets.mjs <file.aab|file.apk|folder>');
  process.exit(2);
}
let dir = target;
let tmp = null;
if (fs.statSync(target).isFile()) {
  tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'scan-'));
  const attempts = [
    ['tar', ['-xf', target, '-C', tmp]], // bsdtar (Windows 10+, macOS) reads zip
    ['unzip', ['-q', '-o', target, '-d', tmp]],
  ];
  let ok = false;
  for (const [cmd, args] of attempts) {
    try {
      execFileSync(cmd, args, { stdio: 'ignore', timeout: 120000 });
      if (fs.readdirSync(tmp).length) { ok = true; break; }
    } catch { /* try next */ }
  }
  if (!ok) {
    console.error('could not unpack the artifact (need bsdtar or unzip on PATH)');
    process.exit(2);
  }
  dir = tmp;
}

const jwtRe = /eyJ[A-Za-z0-9_-]{8,}\.(eyJ[A-Za-z0-9_-]{8,})\.[A-Za-z0-9_-]{8,}/g;
const roleOf = (b64) => {
  try { return JSON.parse(Buffer.from(b64.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8')).role || '?'; } catch { return '?'; }
};
const hits = { service_role_jwt: new Map(), other_secret: new Map() };
let anon = 0;
let scanned = 0;
(function walk(d) {
  for (const e of fs.readdirSync(d, { withFileTypes: true })) {
    const p = path.join(d, e.name);
    if (e.isDirectory()) { walk(p); continue; }
    let buf;
    try { if (fs.statSync(p).size > 200 * 1024 * 1024) continue; buf = fs.readFileSync(p); } catch { continue; }
    scanned++;
    const t = buf.toString('latin1'); // binary-safe; JWTs and keys are ASCII
    const rel = path.relative(dir, p).split(path.sep).join('/');
    for (const m of t.matchAll(jwtRe)) {
      const role = roleOf(m[1]);
      if (role === 'service_role') hits.service_role_jwt.set(rel, (hits.service_role_jwt.get(rel) || 0) + 1);
      else if (role === 'anon') anon++;
    }
    const other = (t.match(/sb_secret_[A-Za-z0-9_-]{10,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|postgres(?:ql)?:\/\/[^:\s\/]+:[^@\s]+@/g) || []).length;
    if (other) hits.other_secret.set(rel, other);
  }
})(dir);
if (tmp) fs.rmSync(tmp, { recursive: true, force: true });

const svc = [...hits.service_role_jwt.values()].reduce((a, b) => a + b, 0);
const oth = [...hits.other_secret.values()].reduce((a, b) => a + b, 0);
console.log(`SCAN files=${scanned} anon_keys_found=${anon} service_role_jwts=${svc} other_secrets=${oth}`);
for (const [k, m] of [...hits.service_role_jwt, ...hits.other_secret]) console.log(`  LEAK in ${k} (x${m})`);
console.log(svc + oth === 0 ? 'RESULT: clean (no service-role key or private secret in the build)' : 'RESULT: LEAK. Do not publish. Rotate the key in the Supabase dashboard, rebuild, re-scan.');
process.exit(svc + oth === 0 ? 0 : 1);
