// Start-up hints added by stamp_offline_build.mjs (2026-11-07 web speed fix).
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('./stamp_offline_build.mjs', import.meta.url));
const source = await readFile(new URL('../web/index.html', import.meta.url), 'utf8');
const dir = await mkdtemp(join(tmpdir(), 'stamp-'));
try {
  await mkdir(join(dir, 'assets'));
  await writeFile(join(dir, 'main.dart.js'), 'main');
  await writeFile(join(dir, 'main.dart.js_1.part.js'), 'part');
  await writeFile(join(dir, 'flutter_bootstrap.js'),
    '_flutter.buildConfig = {"builds":[{"compileTarget":"dart2js","mainJsPath":"main.dart.js"},{}]};');
  await writeFile(join(dir, 'index.html'), source.replace('$FLUTTER_BASE_HREF', '/'));
  await writeFile(join(dir, 'assets', 'FontManifest.json'), JSON.stringify([
    { family: 'MaterialIcons', fonts: [{ asset: 'fonts/MaterialIcons-Regular.otf' }] },
    { family: 'IBM Plex Sans Arabic', fonts: [
      { asset: 'assets/fonts/IBMPlexSansArabic-400.ttf' },
      { weight: 700, asset: 'assets/fonts/IBMPlexSansArabic-700.ttf' }] },
  ]));
  const run = (id) => execFileSync(process.execPath, [script, dir, id],
    { env: { ...process.env, SUPABASE_URL: 'https://backend.example.co' } });
  run('stamp-test-1');
  run('stamp-test-2'); // a second stamp must not stack a second set of hints
  const html = await readFile(join(dir, 'index.html'), 'utf8');
  assert.equal(html.match(/Start-up hints, added by/g).length, 1, 'hints are added once');
  assert.ok(html.indexOf('<base href="/">') < html.indexOf('Start-up hints, added by'),
    'hints follow <base>, so relative paths resolve like the app\'s requests');
  // The compiled app lives in a folder named after the build, so a deploy is
  // a new address that no browser has cached (2026-11-12).
  const loader = await readFile(join(dir, 'flutter_bootstrap.js'), 'utf8');
  assert.ok(loader.includes('"mainJsPath":"app/stamp-test-2/main.dart.js"'), 'the loader points at the build folder');
  assert.equal(await readFile(join(dir, 'app', 'stamp-test-2', 'main.dart.js'), 'utf8'), 'main');
  assert.equal(await readFile(join(dir, 'app', 'stamp-test-2', 'main.dart.js_1.part.js'), 'utf8'), 'part');
  await assert.rejects(readFile(join(dir, 'main.dart.js')), 'nothing is left at the old address');
  await assert.rejects(readFile(join(dir, 'app', 'stamp-test-1', 'main.dart.js')), 'a restamp renames the folder');
  for (const href of ['app/stamp-test-2/main.dart.js', 'assets/FontManifest.json', 'assets/fonts/MaterialIcons-Regular.otf',
    'assets/assets/fonts/IBMPlexSansArabic-400.ttf', 'assets/assets/fonts/IBMPlexSansArabic-700.ttf']) {
    assert.ok(html.includes(`href="${href}"`), `preloads ${href}`);
  }
  assert.ok(html.includes('<link rel="preconnect" href="https://backend.example.co" crossorigin>'),
    'opens the backend connection early');
  assert.ok(html.includes('content="stamp-test-2"'), 'the newest build id wins');
  const manifest = JSON.parse(await readFile(join(dir, 'offline-build.json'), 'utf8'));
  assert.ok(manifest.files['index.html'], 'the stamped page is part of the offline manifest');
  assert.ok(manifest.files['app/stamp-test-2/main.dart.js'], 'the moved app is in the offline manifest');
  console.log('PASS: start-up hints follow <base>, once per page, fonts from FontManifest, backend preconnect');
} finally {
  await rm(dir, { recursive: true, force: true });
}
