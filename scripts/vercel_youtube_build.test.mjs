import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, chmodSync, rmSync, existsSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

// Exercise the real build script with fake tools, never network or credentials.
function build(key) {
  const root = mkdtempSync(join(tmpdir(), 'youtube-build-'));
  try {
    for (const path of ['scripts', 'project', 'bin']) mkdirSync(join(root, path));
    writeFileSync(join(root, 'scripts/build_vercel_web.sh'), readFileSync(new URL('./build_vercel_web.sh', import.meta.url), 'utf8').replaceAll('\r\n', '\n'));
    const tools = {
      flutter: '#!/usr/bin/env bash\nprintf "%s\\n" "$@" >> "$BUILD_ARGS"\nif [[ "$1" == "build" ]]; then mkdir -p build/web; echo stub > build/web/index.html; fi\n',
      git: '#!/usr/bin/env bash\necho test-revision\n',
      node: '#!/usr/bin/env bash\nexit 0\n',
    };
    for (const [name, source] of Object.entries(tools)) {
      writeFileSync(join(root, 'bin', name), source); chmodSync(join(root, 'bin', name), 0o755);
    }
    const bash = process.platform === 'win32' ? 'C:/Program Files/Git/bin/bash.exe' : 'bash';
    const result = spawnSync(bash, [join(root, 'scripts/build_vercel_web.sh')], {
      cwd: root, encoding: 'utf8', timeout: 15000,
      env: { ...process.env, PATH: join(root, 'bin') + (process.platform === 'win32' ? ';' : ':') + process.env.PATH,
        VERCEL_ENV: 'production', SUPABASE_URL: 'https://example.supabase.co', SUPABASE_ANON_KEY: 'test-anon',
        YOUTUBE_API_KEY: key, BUILD_ARGS: join(root, 'args') },
    });
    return { ...result, args: existsSync(join(root, 'args')) ? readFileSync(join(root, 'args'), 'utf8') : '' };
  } finally { rmSync(root, { recursive: true, force: true }); }
}

test('production without YouTube settings fails before building', () => {
  const result = build('');
  assert.equal(result.status, 1, result.stderr);
  assert.match(result.stderr, /without server-side YOUTUBE_API_KEY/);
  assert.equal(result.args, '');
});

test('configured production builds without putting server key into Flutter arguments or logs', () => {
  const key = 'server-only-test-value';
  const result = build(key);
  assert.equal(result.status, 0, result.stderr);
  assert.match(result.args, /build\nweb\n--release/);
  assert.match(result.args, /--dart-define=SUPABASE_URL=/);
  assert.equal(result.args.includes('YOUTUBE_API_KEY'), false);
  assert.equal((result.stdout + result.stderr + result.args).includes(key), false);
});
