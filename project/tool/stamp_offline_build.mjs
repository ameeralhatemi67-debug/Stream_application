import { createHash } from 'node:crypto';
import { readFile, writeFile, readdir } from 'node:fs/promises';
import { resolve, relative, join } from 'node:path';

// Run after flutter build web with the same HADAYAH_BUILD_ID dart define.
const [directory, buildId] = process.argv.slice(2);
if (!directory || !/^[a-zA-Z0-9._-]{8,160}$/.test(buildId ?? '')) {
  throw new Error('Usage: node tool/stamp_offline_build.mjs build/web BUILD_ID');
}
const root = resolve(directory);
const index = join(root, 'index.html');
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
hints.push('<link rel="preload" href="main.dart.js" as="script">');
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
