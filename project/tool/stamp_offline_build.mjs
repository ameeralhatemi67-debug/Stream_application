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
