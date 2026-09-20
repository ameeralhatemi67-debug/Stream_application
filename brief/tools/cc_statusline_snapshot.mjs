#!/usr/bin/env node
// Claude Code "statusLine" command. It receives Claude Code's status JSON on stdin,
// saves the parts we need to brief/.runtime/usage_snapshot.json (so the model can read
// the REAL 5-hour / weekly usage meter and the prompt-cache state with a Bash call),
// and prints a short status line. No dependencies. Never throws.
//
// Fields used (Claude Code statusline docs): rate_limits.five_hour.{used_percentage,resets_at},
// rate_limits.seven_day.*, prompt_cache.{warm,ttl,expires_at,hit_ratio,misses},
// context_window.used_percentage, cost.total_cost_usd, session_id.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const runtimeDir = path.join(here, '..', '.runtime');
const finalPath = path.join(runtimeDir, 'usage_snapshot.json');

let raw = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  let j = {};
  try {
    j = JSON.parse(raw || '{}');
  } catch {
    j = {};
  }
  const win = (w) =>
    w && typeof w === 'object'
      ? { used_percentage: Number(w.used_percentage), resets_at: Number(w.resets_at) }
      : null;
  const rl = j.rate_limits || {};
  const pc = j.prompt_cache || null;
  const snap = {
    written_at: Math.floor(Date.now() / 1000),
    session_id: j.session_id ?? null,
    model: j.model?.id ?? null,
    five_hour: win(rl.five_hour),
    seven_day: win(rl.seven_day),
    prompt_cache: pc
      ? {
          warm: pc.warm ?? null,
          ttl: pc.ttl ?? null,
          expires_at: pc.expires_at ?? null,
          hit_ratio: pc.hit_ratio ?? null,
          misses: pc.misses ?? null,
        }
      : null,
    context_used_pct: j.context_window?.used_percentage ?? null,
    cost_usd: j.cost?.total_cost_usd ?? null,
  };

  try {
    fs.mkdirSync(runtimeDir, { recursive: true });
    const tmp = finalPath + '.' + process.pid + '.tmp';
    fs.writeFileSync(tmp, JSON.stringify(snap));
    try {
      fs.renameSync(tmp, finalPath);
    } catch {
      fs.writeFileSync(finalPath, JSON.stringify(snap)); // Windows: target busy -> direct write
      try {
        fs.unlinkSync(tmp);
      } catch {
        /* ignore */
      }
    }
  } catch {
    /* status line must never fail */
  }

  const now = Math.floor(Date.now() / 1000);
  const parts = [];
  if (snap.five_hour) {
    const mins = Math.max(0, Math.round((snap.five_hour.resets_at - now) / 60));
    parts.push(`5h ${snap.five_hour.used_percentage.toFixed(0)}% (reset ${mins}m)`);
  } else {
    parts.push('5h n/a');
  }
  if (snap.seven_day) parts.push(`7d ${snap.seven_day.used_percentage.toFixed(0)}%`);
  if (snap.prompt_cache) {
    parts.push(`cache ${snap.prompt_cache.ttl ?? '?'} ${snap.prompt_cache.warm ? 'warm' : 'COLD'}`);
  }
  if (snap.context_used_pct != null) parts.push(`ctx ${Number(snap.context_used_pct).toFixed(0)}%`);
  process.stdout.write(parts.join(' | ') + '\n');
});
