import { createHash } from 'node:crypto';
import { mkdir, readFile, readdir, rename, rm, writeFile } from 'node:fs/promises';
import { resolve, relative, join } from 'node:path';

// Run after flutter build web with the same HADAYAH_BUILD_ID dart define.
const [directory, buildId] = process.argv.slice(2);
if (!directory || !/^[a-zA-Z0-9._-]{8,160}$/.test(buildId ?? '')) {
  throw new Error('Usage: node tool/stamp_offline_build.mjs build/web BUILD_ID');
}
const root = resolve(directory);
const index = join(root, 'index.html');

// The compiled app (main.dart.js and its deferred parts) moves into a folder
// named after this build. Cloudflare in front of the site gives .js files a
// four-hour browser lifetime whatever the origin says, and these names never
// changed, so a browser kept running the previous build after a deploy
// (owner report 2026-11-12). The parts load relative to main.dart.js, so they
// move with it; flutter_bootstrap.js is told the new path.
const appDir = `app/${buildId}`;
const appRoot = join(root, 'app');
// Stamped before (a second run): the folder takes the new name.
const earlier = (await readdir(appRoot).catch(() => []))
  .filter((name) => name !== buildId);
await mkdir(join(root, appDir), { recursive: true });
for (const name of earlier) {
  for (const item of await readdir(join(appRoot, name))) {
    await rename(join(appRoot, name, item), join(root, appDir, item));
  }
  await rm(join(appRoot, name), { recursive: true });
}
for (const item of await readdir(root)) {
  if (/^main\.dart\.(js|mjs|wasm)/.test(item)) {
    await rename(join(root, item), join(root, appDir, item));
  }
}
const bootstrap = join(root, 'flutter_bootstrap.js');
const loader = await readFile(bootstrap, 'utf8');
const moved = loader.replace(/"mainJsPath":"(?:app\/[^/"]+\/)?main\.dart\.js"/g,
  `"mainJsPath":"${appDir}/main.dart.js"`);
if (!moved.includes(`"mainJsPath":"${appDir}/main.dart.js"`)) {
  throw new Error('flutter_bootstrap.js has no mainJsPath to move');
}
await writeFile(bootstrap, moved);
let html = await readFile(index, 'utf8');
html = html.replace(/<meta name="hadayah-build"[^>]*>\s*/g, '');
html = html.replace('<head>', `<head>\n  <meta name="hadayah-build" content="${buildId}">`);

// Start-up hints (2026-11-07 web speed diagnosis). Without them the browser
// finds these files one after another: the page, flutter_bootstrap.js, then
// main.dart.js, then FontManifest.json, then the fonts. Everything named here
// is what this build itself downloads before its first frame. Placed after
// <base>, so the relative paths resolve the way the app's own requests do.
const fontManifest = JSON.parse(
  await readFile(join(root, 'assets', 'FontManifest.json'), 'utf8'));
const hints = ['<!-- Start-up hints, added by tool/stamp_offline_build.mjs -->'];
const backend = process.env.SUPABASE_URL ? new URL(process.env.SUPABASE_URL).origin : null;
if (backend) hints.push(`<link rel="preconnect" href="${backend}" crossorigin>`);
hints.push(`<link rel="preload" href="${appDir}/main.dart.js" as="script">`);
hints.push('<link rel="preload" href="assets/FontManifest.json" as="fetch" crossorigin>');
for (const family of fontManifest) {
  for (const font of family.fonts) {
    hints.push(`<link rel="preload" href="assets/${font.asset}" as="fetch" crossorigin>`);
  }
}
html = html.replace(/\s*<!-- Start-up hints, added by[\s\S]*?<!-- End of start-up hints -->/g, '');
const base = html.match(/<base href="[^"]*">/);
if (!base) throw new Error('index.html has no <base href>; start-up hints need it first');
html = html.replace(base[0],
  `${base[0]}\n  ${hints.join('\n  ')}\n  <!-- End of start-up hints -->`);
await writeFile(index, html);
const files = {};
async function walk(dir) {
  for (const item of await readdir(dir, { withFileTypes: true })) {
    const path = join(dir, item.name);
    if (item.isDirectory()) await walk(path);
    else if (item.name !== 'offline-build.json' && !item.name.endsWith('.map')) {
      files[relative(root, path).replaceAll('\\', '/')] =
        createHash('sha256').update(await readFile(path)).digest('hex');
    }
  }
}
await walk(root);
await writeFile(join(root, 'offline-build.json'), JSON.stringify({ buildId, files }));
console.log(`Stamped ${buildId}: ${Object.keys(files).length} public build files`);
