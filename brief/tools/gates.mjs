#!/usr/bin/env node
// Deterministic "definition of done" gates for the hardening run. Run from the repo root:
//   node brief/tools/gates.mjs            (table)      node brief/tools/gates.mjs --json      node brief/tools/gates.mjs --history (adds the slow git-history secret scan)
// Read-only. Prints current numbers so progress is measured, not claimed.
// Gate status: PASS (== target), FAIL (> target), INFO (report only).
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

const root = process.cwd();
const projectDir = path.join(root, 'project');
if (!fs.existsSync(path.join(projectDir, 'pubspec.yaml'))) {
  console.error('Run from the repo root (the folder that contains project/pubspec.yaml).');
  process.exit(2);
}
const asJson = process.argv.includes('--json');
const SKIP = new Set(['build', '.dart_tool', 'node_modules', '.git', '.gradle', 'graft', 'graphify-out', '.idea', '.serena']);

function* walk(dir) {
  let ents = [];
  try {
    ents = fs.readdirSync(dir, { withFileTypes: true });
  } catch {
    return;
  }
  for (const e of ents) {
    if (SKIP.has(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) yield* walk(p);
    else yield p;
  }
}
const rel = (p) => path.relative(root, p).split(path.sep).join('/');
const read = (p) => {
  try {
    return fs.readFileSync(p, 'utf8');
  } catch {
    return '';
  }
};

const libFiles = [...walk(path.join(projectDir, 'lib'))].filter((f) => f.endsWith('.dart') && !rel(f).includes('/spike_rtmp/'));
const i18nFiles = [...walk(path.join(projectDir, 'assets', 'i18n'))].filter((f) => f.endsWith('.json'));
const androidFiles = [...walk(path.join(projectDir, 'android'))].filter((f) => /\.(kt|kts|xml|gradle|properties)$/.test(f));
const webFiles = [...walk(path.join(projectDir, 'web'))].filter((f) => /\.(html|json)$/.test(f));

function countMatches(files, re) {
  let n = 0;
  const where = new Map();
  for (const f of files) {
    const m = read(f).match(re);
    if (m) {
      n += m.length;
      where.set(rel(f), m.length);
    }
  }
  return { n, top: [...where.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5) };
}

const allowFile = path.join(root, 'brief', 'emoji_allowlist.txt');
const emojiAllow = new Set(
  fs.existsSync(allowFile)
    ? read(allowFile).split(/\r?\n/).map((s) => s.trim()).filter((s) => s && !s.startsWith('#'))
    : [],
);
const emojiRe = /\p{Extended_Pictographic}|\p{Emoji_Presentation}/gu;

function flatten(o, prefix = '', out = []) {
  for (const [k, v] of Object.entries(o)) {
    const key = prefix ? `${prefix}.${k}` : k;
    if (v && typeof v === 'object' && !Array.isArray(v)) flatten(v, key, out);
    else out.push(key);
  }
  return out;
}

const gates = [];
const add = (id, title, value, target, detail = '') =>
  gates.push({ id, title, value, target, status: target === null ? 'INFO' : value < 0 ? 'N/A' : value <= target ? 'PASS' : 'FAIL', detail });

// G1 fixtures / placeholders / hard-coded identity
for (const [id, title, re] of [
  ['G1a', 'mockStreamers / MockVodArchivePool / sampleQuestions in lib', /mockStreamers|MockVodArchivePool|sampleQuestions|sampleVods|samplePlaylists/g],
  ['G1b', 'FeatureInProgressModal call sites', /FeatureInProgressModal\.show/g],
  ['G1c', "hard-coded dev identity ('prof_alghamdi_01', dev emails)", /prof_alghamdi_01|polkgvd2@|ameeralhatemi67@|amir\.alhatemi@/g],
  ['G1d', 'fake viewer-count literals (1240 / 18450)', /\b1240\b|\b18450\b/g],
  ['G1e', 'ghost/demo chat', /GhostChat|ghost_comments|ghostComments|demo_mode_banner/g],
]) {
  // the single identity/config file (lib/core/config/app_identity.dart) is allowed to hold the support email
  const r = countMatches(libFiles.filter((f) => !rel(f).endsWith('/app_identity.dart')).concat(i18nFiles), re);
  add(id, title, r.n, 0, r.top.map(([f, c]) => `${f}:${c}`).join(', '));
}

// G2 theme
{
  const r = countMatches(libFiles, /AppTheme\.dark[A-Za-z0-9]*|AppTheme\.[a-z][A-Za-z0-9]*Dark\b/g);
  add('G2a', 'dark-only theme tokens referenced (AppTheme.dark* / *Dark)', r.n, 0, r.top.map(([f, c]) => `${f}:${c}`).join(', '));
  const t = countMatches(libFiles, /ThemeMode\.dark/g);
  add('G2b', 'ThemeMode.dark', t.n, 0, t.top.map(([f, c]) => `${f}:${c}`).join(', '));
  const lit = countMatches(libFiles.filter((f) => !f.endsWith('app_theme.dart')), /Color\(0x[0-9A-Fa-f]{8}\)|Colors\.(white|black)\b/g);
  add('G2c', 'hard-coded color literals outside app_theme.dart (target 0 except allowlisted on-media overlays)', lit.n, null, lit.top.map(([f, c]) => `${f}:${c}`).join(', '));
  // gradients must come from named theme tokens (05 D-25): no gradient literal in screens/widgets
  const grad = countMatches(libFiles.filter((f) => !rel(f).includes('/core/theme/')), /\b(?:Linear|Radial|Sweep)Gradient\s*\(/g);
  add('G2d', 'gradient literals outside lib/core/theme/ (gradients only via AppGradients tokens)', grad.n, 0, grad.top.map(([f, c]) => `${f}:${c}`).join(', '));
}

// G3 emoji
{
  let n = 0;
  const where = new Map();
  for (const f of libFiles.concat(i18nFiles)) {
    if (emojiAllow.has(rel(f))) continue;
    const m = read(f).match(emojiRe);
    if (m) {
      n += m.length;
      where.set(rel(f), m.length);
    }
  }
  add('G3', 'emoji/pictograph occurrences in lib + i18n (excluding brief/emoji_allowlist.txt files)', n, 0,
    [...where.entries()].sort((a, b) => b[1] - a[1]).slice(0, 5).map(([f, c]) => `${f}:${c}`).join(', '));
}

// G4 app identity placeholders
{
  const r = countMatches(androidFiles.concat(webFiles, libFiles), /com\.example/g);
  add('G4a', "'com.example' package/scheme still present (android/web/lib)", r.n, 0, r.top.map(([f, c]) => `${f}:${c}`).join(', '));
  const l = countMatches(
    androidFiles.concat(webFiles),
    /android:label="streamer_app"|<title>streamer_app<|"(name|short_name)":\s*"streamer_app"|app-title" content="streamer_app"/g,
  );
  add('G4b', "app name still the working title 'streamer_app' (manifest label / web title / web manifest)", l.n, 0, l.top.map(([f, c]) => `${f}:${c}`).join(', '));
}

// G5 dead code / heavy deps
{
  const pub = read(path.join(projectDir, 'pubspec.yaml'));
  add('G5a', 'flutter_vlc_player still in pubspec', /flutter_vlc_player\s*:/.test(pub) ? 1 : 0, 0);
  add('G5b', 'lib/spike_rtmp exists', fs.existsSync(path.join(projectDir, 'lib', 'spike_rtmp')) ? 1 : 0, 0);
  add('G5c', 'assets/map/gadm41_SAU_2.svg (GADM licence) still bundled', pub.includes('gadm41_SAU_2') ? 1 : 0, 0);
}

// G6 hard-coded English UI strings (report only until P4)
{
  const r = countMatches(libFiles, /Text\(\s*'[A-Za-z][^'$]{3,}'/g);
  add('G6', "hard-coded English Text('...') literals (should move to i18n)", r.n, 0, r.top.map(([f, c]) => `${f}:${c}`).join(', '));
}

// G7 i18n key symmetry
{
  let diff = -1;
  try {
    const en = new Set(flatten(JSON.parse(read(path.join(projectDir, 'assets/i18n/en.json')))));
    const ar = new Set(flatten(JSON.parse(read(path.join(projectDir, 'assets/i18n/ar.json')))));
    diff = [...en].filter((k) => !ar.has(k)).length + [...ar].filter((k) => !en.has(k)).length;
  } catch {
    /* leave -1 */
  }
  add('G7', 'en/ar i18n key mismatches (-1 = unreadable JSON)', diff, 0);
}

// G8 release signing fail-closed
{
  const g = read(path.join(projectDir, 'android/app/build.gradle.kts'));
  const fallsBack = /signingConfigs\.getByName\("debug"\)/.test(g);
  add('G8', 'release build can silently fall back to the debug keystore', fallsBack ? 1 : 0, 0);
}

// G9 dev tooling reachable in release
{
  const admin = read(path.join(projectDir, 'lib/features/admin/presentation/admin_hub_screen.dart'));
  const gated = /kDebugMode[\s\S]{0,400}_buildTestingToolsTab|_buildTestingToolsTab[\s\S]{0,200}kDebugMode/.test(admin);
  add('G9', 'Admin "Testing tools" tab not gated by kDebugMode', gated ? 0 : 1, 0);
}

// ---------- G10 Row Level Security (static reading of supabase/migrations; NOT a substitute for DB probes, 06 section 2) ----------
const migDir = path.join(root, 'supabase', 'migrations');
const migFiles = fs.existsSync(migDir) ? fs.readdirSync(migDir).filter((f) => f.endsWith('.sql')).sort() : [];
const stripSql = (t) => t.replace(/\/\*[\s\S]*?\*\//g, ' ').replace(/--[^\n]*/g, ' ');
const migText = migFiles.map((f) => stripSql(read(path.join(migDir, f)))).join('\n;\n');
const ident = (x) => x.replace(/"/g, '').replace(/^public\./i, '').toLowerCase();
{
  const tables = new Set();
  for (const m of migText.matchAll(/create\s+table\s+(?:if\s+not\s+exists\s+)?((?:public\.)?"?[\w]+"?)\s*\(/gi)) tables.add(ident(m[1]));
  for (const m of migText.matchAll(/drop\s+table\s+(?:if\s+exists\s+)?((?:public\.)?"?[\w]+"?)/gi)) tables.delete(ident(m[1]));
  const rls = new Set();
  for (const m of migText.matchAll(/alter\s+table\s+(?:only\s+)?((?:public\.)?"?[\w]+"?)\s+enable\s+row\s+level\s+security/gi)) rls.add(ident(m[1]));
  const pol = new Map();
  for (const m of migText.matchAll(/create\s+policy\s+(?:"[^"]*"|[\w]+)\s+on\s+((?:public\.)?"?[\w]+"?)/gi)) pol.set(ident(m[1]), (pol.get(ident(m[1])) || 0) + 1);
  const noRls = [...tables].filter((t) => !rls.has(t));
  const noPol = [...tables].filter((t) => rls.has(t) && !pol.get(t));
  add('G10a', `public tables without ENABLE ROW LEVEL SECURITY in migrations (of ${tables.size})`, noRls.length, 0, noRls.slice(0, 8).join(', '));
  add('G10b', 'tables with RLS on but NO policy (deny-all; must be intentional and commented, e.g. stream_viewers)', noPol.length, null, noPol.slice(0, 8).join(', '));
  // permissive write policies, SECURITY DEFINER without search_path, grants to anon/public
  let open = 0;
  const openList = [];
  for (const m of migText.matchAll(/create\s+policy\s+(?:"([^"]*)"|([\w]+))\s+on\s+((?:public\.)?"?[\w.]+"?)([\s\S]*?);/gi)) {
    const body = m[4];
    const cmd = (body.match(/\bfor\s+(select|insert|update|delete|all)\b/i) || [, 'all'])[1].toLowerCase();
    if (cmd === 'select') continue;
    const u = /\busing\s*\(\s*true\s*\)/i.test(body);
    const w = /\bwith\s+check\s*\(\s*true\s*\)/i.test(body);
    if (u || w) {
      open++;
      openList.push(`${ident(m[3])}:${m[1] || m[2]}`);
    }
  }
  add('G10c', "write policies that are unconditionally 'true' (using/with check (true))", open, 0, openList.slice(0, 6).join(', '));
  let sd = 0;
  const sdList = [];
  for (const m of migText.matchAll(/create\s+(?:or\s+replace\s+)?function\s+([\w."]+)\s*\(([\s\S]*?)\bas\s+(?:\$[\w]*\$|')/gi)) {
    const head = m[0];
    if (/security\s+definer/i.test(head) && !/set\s+search_path/i.test(head)) {
      sd++;
      sdList.push(ident(m[1]));
    }
  }
  add('G10d', 'SECURITY DEFINER functions without SET search_path', sd, 0, [...new Set(sdList)].slice(0, 6).join(', '));
  const anonGrants = (migText.match(/grant\s+(?:all|insert|update|delete|execute)[^;]*\sto\s+(?:anon|public)\b/gi) || []).length;
  add('G10e', 'GRANT of write/execute privileges to anon/public in migrations (review each; only viewer_heartbeat/get_viewer_counts and public views are expected)', anonGrants, null);
}

// ---------- G11 secrets and the Supabase service-role key (prints counts and file names only, NEVER values) ----------
{
  const SCAN_EXT = /\.(dart|kt|kts|java|xml|gradle|properties|json|ya?ml|toml|md|sql|html|js|mjs|cjs|ts|sh|ps1|txt|env|cfg|ini)$/i;
  const files = [...walk(root)].filter((f) => {
    const r = rel(f);
    if (r.startsWith('brief/') || r.startsWith('node_modules/')) return false;
    const base = path.basename(f);
    return SCAN_EXT.test(base) || /^\.env/.test(base);
  });
  const jwtRe = /eyJ[A-Za-z0-9_-]{8,}\.(eyJ[A-Za-z0-9_-]{8,})\.[A-Za-z0-9_-]{8,}/g;
  const roleOf = (payloadB64) => {
    try {
      return JSON.parse(Buffer.from(payloadB64.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8')).role || '?';
    } catch {
      return '?';
    }
  };
  const svc = new Map();
  const other = new Map();
  const clientRef = new Map();
  for (const f of files) {
    let st;
    try { st = fs.statSync(f); } catch { continue; }
    if (st.size > 1_500_000) continue;
    const t = read(f);
    const r = rel(f);
    for (const m of t.matchAll(jwtRe)) {
      const role = roleOf(m[1]);
      const bucket = role === 'service_role' ? svc : role === 'anon' ? null : other;
      if (bucket) bucket.set(r, (bucket.get(r) || 0) + 1);
    }
    const bad = (t.match(/sb_secret_[A-Za-z0-9_-]{10,}|-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----|postgres(?:ql)?:\/\/[^:\s\/]+:[^@\s]+@/g) || []).length;
    if (bad) svc.set(r, (svc.get(r) || 0) + bad);
    if (/^project\/(lib|android|web)\//.test(r) && /service_role|SERVICE_ROLE|serviceRole|sb_secret_/.test(t)) clientRef.set(r, 1);
  }
  add('G11a', 'service-role JWTs / sb_secret keys / private keys / DB URLs with password found in the working tree', svc.size ? [...svc.values()].reduce((a, b) => a + b, 0) : 0, 0, [...svc.keys()].slice(0, 6).join(', '));
  add('G11b', 'client code (project/lib, android, web) that mentions the service role', clientRef.size, 0, [...clientRef.keys()].slice(0, 6).join(', '));
  add('G11c', 'JWT-shaped tokens with an unexpected role (not anon/service_role)', other.size, null, [...other.keys()].slice(0, 4).join(', '));
  let gitOk = true;
  const git = (args) => {
    try {
      return execFileSync('git', args, { cwd: root, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'], timeout: 60000, maxBuffer: 64 * 1024 * 1024 });
    } catch (e) {
      if (e && e.status === 1 && typeof e.stdout === 'string') return e.stdout;
      gitOk = false;
      return '';
    }
  };
  const mustIgnore = ['project/dart_define.local.json', 'project/android/key.properties', 'project/android/app/upload-keystore.jks', 'project/android/app/release.keystore', 'supabase/.env', '.env', 'project/.env'];
  let notIgnored = 0;
  const niList = [];
  for (const p of mustIgnore) {
    try {
      execFileSync('git', ['check-ignore', '-q', p], { cwd: root, stdio: 'ignore', timeout: 20000 });
    } catch (e) {
      if (e && e.status === 1) {
        notIgnored++;
        niList.push(p);
      } else gitOk = false;
    }
  }
  add('G11d', 'secret-bearing paths NOT covered by .gitignore (dart_define.local.json, key.properties, keystores, .env)', gitOk ? notIgnored : -1, 0, niList.join(', '));
  const tracked = git(['ls-files', '--', '*.jks', '*.keystore', '*key.properties', '*dart_define*.json', '.env', '*/.env', '.env.*']).split('\n').filter(Boolean).filter((x) => !/\.(example|sample|template)(\.|$)/i.test(path.basename(x)));
  add('G11e', 'secret-bearing files TRACKED by git (must be 0; if >0 the key is burned: rotate it)', gitOk ? tracked.length : -1, 0, tracked.slice(0, 4).join(', '));
  let dd = 0;
  for (const p of ['project/dart_define.local.json', 'dart_define.local.json']) {
    const f = path.join(root, p);
    if (!fs.existsSync(f)) continue;
    try {
      const j = JSON.parse(read(f));
      for (const [k, v] of Object.entries(j)) {
        if (/service|secret|private/i.test(k)) dd++;
        else if (typeof v === 'string') for (const m of v.matchAll(jwtRe)) if (roleOf(m[1]) === 'service_role') dd++;
      }
    } catch {
      /* unreadable: ignore */
    }
  }
  add('G11f', 'dart_define.local.json holds a service-role/secret-named entry (only the anon key belongs in the app)', dd, 0);
  if (process.argv.includes('--history')) {
    const hist = git(['log', '--all', '--oneline', '-G', 'eyJ[A-Za-z0-9_-]{20,}\\.eyJ[A-Za-z0-9_-]{20,}\\.', '--', ':!brief', ':!doc', ':!graft']).split('\n').filter(Boolean).length;
    add('G11g', 'commits in history that ever added a JWT-shaped token (inspect each with git show, never paste it; any service_role hit = rotate the key)', gitOk ? hist : -1, null);
  } else {
    add('G11g', 'history scan for JWT-shaped tokens skipped (slow, ~1 min): run `node brief/tools/gates.mjs --history` at P0 and P9', 0, null);
  }
}

if (asJson) {
  console.log(JSON.stringify(gates, null, 2));
} else {
  const pad = (s, n) => String(s).padEnd(n);
  console.log(`${pad('GATE', 5)} ${pad('STATUS', 6)} ${pad('NOW', 6)} ${pad('TARGET', 6)} TITLE  [top offenders]`);
  for (const g of gates) {
    console.log(`${pad(g.id, 5)} ${pad(g.status, 6)} ${pad(g.value, 6)} ${pad(g.target === null ? '-' : g.target, 6)} ${g.title}${g.detail ? '  [' + g.detail + ']' : ''}`);
  }
  const fails = gates.filter((g) => g.status === 'FAIL').length;
  console.log(`\n${fails} gate(s) failing.`);
}
