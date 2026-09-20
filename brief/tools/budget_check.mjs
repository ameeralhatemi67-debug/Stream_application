#!/usr/bin/env node
// Budget meter for the hardening run. Reads brief/.runtime/usage_snapshot.json (written by
// cc_statusline_snapshot.mjs) and prints ONE line telling you what to do.
//
//   node brief/tools/budget_check.mjs [--plan single|split] [--nap SECONDS] [--source auto|claude|codex] [--probe] [--new-run] [--json]
//
// Two harnesses are supported (auto-detected, freshest signal wins):
//   claude : Claude Code status line -> brief/.runtime/usage_snapshot.json (cc_statusline_snapshot.mjs).
//   codex  : Codex CLI/Desktop (GPT-6 Astra) -> newest ~/.codex/sessions/**/rollout-*.jsonl (or $CODEX_HOME),
//            reading the `rate_limits` object Codex logs with every model response
//            (primary = 5-hour window, secondary = weekly). Best-effort parser: if the shape is not
//            recognised the answer is UNKNOWN (fail closed). Verify once with --probe before a real run.
//            Codex has no documented prompt-cache TTL in its logs: 30 min is ASSUMED. SPLIT works there too
//            (window 1 cap 70, window 2 cap 60) but WITHOUT naps: at the window-1 stop the owner starts a FRESH
//            session in the next window; the window counter lives in brief/.runtime/budget_state.json and survives sessions.
//   --plan bonus [--extra N] [--bonus-start] : owner-approved extra spend INSIDE the current window only (default N=40,
//            max 40). --bonus-start (first call of the session) records the used% now; cap = min(94, start + N),
//            soft = cap - 6; STOP when the window resets or fewer than 4 minutes remain (never cross the reset:
//            the fresh window belongs to the split plan's window 2). Does not touch the split window counter.
//   --new-run : forget earlier windows (use ONLY at Step 0 of a brand-new budget, never mid-run).
//
// Plans (caps are ABSOLUTE account-wide 5-hour used_percentage, so they already include
// anything else the user spent in the same window):
//   single : window 1 cap 80, soft 74. If the window rolls over -> STOP (no second window).
//   split  : window 1 cap 70, soft 64; window 2 cap 60, soft 54. A third window -> STOP.
// Weekly guard: seven_day >= 90 -> STOP.
// --nap N (max 540): sleep N seconds first, then measure. One nap = one Bash call = one
// API request, which is what keeps the 1-hour prompt cache warm while waiting for a reset.
//
// Status values: OK | SOFT | STOP | UNKNOWN. Always exits 0 (read the status text).
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const runtimeDir = path.join(here, '..', '.runtime');
const snapPath = path.join(runtimeDir, 'usage_snapshot.json');
const statePath = path.join(runtimeDir, 'budget_state.json');

const argv = process.argv.slice(2);
const arg = (name, dflt) => {
  const i = argv.indexOf(name);
  return i >= 0 && argv[i + 1] !== undefined && !argv[i + 1].startsWith('--') ? argv[i + 1] : dflt;
};
const source = (arg('--source', process.env.BUDGET_SOURCE || 'auto') || 'auto').toLowerCase();
const probe = argv.includes('--probe');
const newRun = argv.includes('--new-run');
const bonusStart = argv.includes('--bonus-start');
const bonusExtra = Math.min(40, Math.max(1, Number(arg('--extra', '40')) || 40));
let plan = (arg('--plan', process.env.BUDGET_PLAN || 'single') || 'single').toLowerCase();
const asJson = argv.includes('--json');
const nap = Math.min(540, Math.max(0, Number(arg('--nap', '0')) || 0));

let CAPS = plan === 'split' ? [70, 60] : plan === 'bonus' ? [94, 94] : [80];
const SOFT_MARGIN = 6;
const WEEKLY_STOP = 90;
const STALE_SNAPSHOT_S = 900;

function readJson(p, fallback) {
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch {
    return fallback;
  }
}
function writeJson(p, v) {
  try {
    fs.mkdirSync(runtimeDir, { recursive: true });
    fs.writeFileSync(p, JSON.stringify(v, null, 2));
  } catch {
    /* ignore */
  }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function emit(o) {
  if (asJson) {
    console.log(JSON.stringify(o));
    return;
  }
  const kv = Object.entries(o)
    .filter(([, v]) => v !== null && v !== undefined && v !== '')
    .map(([k, v]) => `${k}=${v}`)
    .join(' ');
  console.log('BUDGET ' + kv);
}


// ---------------- Codex reader (best-effort, tolerant) ----------------
function walkJsonl(dir, out, depth = 0) {
  let ents = [];
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch { return; }
  for (const e of ents) {
    const p = path.join(dir, e.name);
    if (e.isDirectory() && depth < 5) walkJsonl(p, out, depth + 1);
    else if (e.isFile() && /^rollout-.*\.jsonl$/i.test(e.name)) {
      try { out.push({ p, m: fs.statSync(p).mtimeMs }); } catch { /* ignore */ }
    }
  }
}
const toEpoch = (v) => {
  if (typeof v === 'number' && Number.isFinite(v)) return v > 1e12 ? Math.floor(v / 1000) : Math.floor(v);
  if (typeof v === 'string') {
    if (/^\d+(\.\d+)?$/.test(v)) return toEpoch(Number(v));
    const t = Date.parse(v);
    if (Number.isFinite(t)) return Math.floor(t / 1000);
  }
  return null;
};
// Normalise one window object into { used, resets_at, minutes } (any of several plausible shapes).
function normWindow(w, evTs) {
  if (!w || typeof w !== 'object') return null;
  let used = null;
  for (const k of ['used_percent', 'used_percentage', 'percent_used', 'usedPercent']) if (Number.isFinite(Number(w[k])) && w[k] !== null) { used = Number(w[k]); break; }
  if (used === null) for (const k of ['remaining_percent', 'remaining_percentage', 'percent_remaining']) if (Number.isFinite(Number(w[k])) && w[k] !== null) { used = 100 - Number(w[k]); break; }
  if (used === null) return null;
  if (used <= 1 && used > 0 && w.used_percent === undefined && w.remaining_percent === undefined) used *= 100; // fraction form
  let minutes = null;
  if (Number.isFinite(Number(w.window_minutes))) minutes = Number(w.window_minutes);
  else if (Number.isFinite(Number(w.limit_window_seconds))) minutes = Number(w.limit_window_seconds) / 60;
  else if (Number.isFinite(Number(w.window_seconds))) minutes = Number(w.window_seconds) / 60;
  let resets = null;
  for (const k of ['resets_at', 'reset_at', 'resetsAt']) if (w[k] !== undefined && w[k] !== null) { resets = toEpoch(w[k]); if (resets) break; }
  if (!resets) for (const k of ['resets_in_seconds', 'reset_after_seconds', 'resets_in']) if (Number.isFinite(Number(w[k])) && w[k] !== null && evTs) { resets = Math.floor(evTs + Number(w[k])); break; }
  return { used, resets_at: resets, minutes };
}
function findRateLimits(obj, depth = 0) {
  if (!obj || typeof obj !== 'object' || depth > 6) return null;
  if (obj.rate_limits && typeof obj.rate_limits === 'object') return obj.rate_limits;
  for (const v of Object.values(obj)) {
    const r = findRateLimits(v, depth + 1);
    if (r) return r;
  }
  return null;
}
function readCodexSnapshot(now) {
  const home = process.env.CODEX_HOME || path.join(os.homedir(), '.codex');
  const files = [];
  walkJsonl(path.join(home, 'sessions'), files);
  if (!files.length) return { none: 'no_codex_sessions', home_exists: fs.existsSync(home) };
  files.sort((a, b) => b.m - a.m);
  for (const f of files.slice(0, 6)) {
    let text = '';
    try {
      const fd = fs.openSync(f.p, 'r');
      const size = fs.fstatSync(fd).size;
      const len = Math.min(size, 1024 * 1024);
      const buf = Buffer.alloc(len);
      fs.readSync(fd, buf, 0, len, size - len);
      fs.closeSync(fd);
      text = buf.toString('utf8');
    } catch { continue; }
    const lines = text.split('\n');
    for (let i = lines.length - 1; i >= 0; i--) {
      const ln = lines[i];
      if (!ln.includes('rate_limit')) continue;
      let j;
      try { j = JSON.parse(ln); } catch { continue; }
      const rl = findRateLimits(j);
      if (!rl) continue;
      const evTs = toEpoch(j.timestamp) || Math.floor(f.m / 1000);
      let entries = Object.entries(rl).map(([k, v]) => [k, normWindow(v, evTs)]).filter(([, w]) => w);
      if (!entries.length) continue;
      const near = (w, lo, hi) => w.minutes !== null && w.minutes >= lo && w.minutes <= hi;
      let five = entries.find(([, w]) => near(w, 240, 360));
      let week = entries.find(([, w]) => near(w, 9000, 11000));
      if (!five) five = entries.find(([k]) => /primary/i.test(k));
      if (!week) week = entries.find(([k]) => /secondary/i.test(k));
      if (!five || !five[1].resets_at) continue;
      return {
        harness: 'codex',
        written_at: evTs,
        five_hour: { used_percentage: five[1].used, resets_at: five[1].resets_at },
        seven_day: week ? { used_percentage: week[1].used, resets_at: week[1].resets_at } : null,
        prompt_cache: { ttl: '30m(assumed)', warm: now - evTs < 1800, expires_at: evTs + 1800 },
        _probe: { file: path.basename(f.p), keys: entries.map(([k, w]) => `${k}:used=${w.used.toFixed(1)},min=${w.minutes},resets_in_min=${w.resets_at ? Math.round((w.resets_at - now) / 60) : '?'}`) },
      };
    }
  }
  return { none: 'no_rate_limits_in_recent_codex_logs' };
}
function readClaudeSnapshot() {
  const snap = readJson(snapPath, null);
  return snap ? { ...snap, harness: 'claude' } : null;
}

(async () => {
  if (nap > 0) await sleep(nap * 1000);
  const now = Math.floor(Date.now() / 1000);
  let snap = null;
  let codexNote = null;
  const cl = source === 'codex' ? null : readClaudeSnapshot();
  const cx = source === 'claude' ? null : readCodexSnapshot(now);
  if (cx && cx.none) codexNote = cx.none;
  const cxOk = cx && !cx.none ? cx : null;
  if (cl && cxOk) snap = (now - (cl.written_at || 0)) <= (now - cxOk.written_at) ? cl : cxOk;
  else snap = cl || cxOk;

  if (probe) {
    console.log(JSON.stringify({
      source_requested: source,
      claude_snapshot: cl ? { age_s: now - (cl.written_at || 0), five_hour_ok: !!(cl.five_hour && Number.isFinite(cl.five_hour.used_percentage)) } : null,
      codex: cxOk ? { age_s: now - cxOk.written_at, ...cxOk._probe } : { problem: codexNote },
      chosen: snap ? snap.harness : null,
    }, null, 1));
    return;
  }

  if (!snap) {
    emit({
      status: 'UNKNOWN',
      reason: 'no_snapshot',
      codex_note: codexNote || '',
      action: 'STOP_NEW_WORK: no usage meter. Claude Code: restart from the repo root with `claude --permission-mode acceptEdits --settings brief/claude_settings.json` (brief/04 section A). Codex: send one message first, then run `node brief/tools/budget_check.mjs --probe` and see brief/04 section G.',
    });
    return;
  }
  const age = now - (snap.written_at || 0);
  const fh = snap.five_hour;
  if (!fh || !Number.isFinite(fh.used_percentage) || !Number.isFinite(fh.resets_at)) {
    emit({
      status: 'UNKNOWN',
      reason: 'no_rate_limits_in_snapshot',
      snapshot_age_s: age,
      action: 'Do one cheap tool call (e.g. `date`), then re-run once. If still UNKNOWN (API-key billing or no Pro/Max plan) treat as STOP for new work.',
    });
    return;
  }

  // --- window tracking (detect roll-over between windows) ---
  const state = newRun ? { plan, windows: [] } : readJson(statePath, { plan, windows: [] });
  if (plan !== 'bonus') state.plan = plan;
  const wins = state.windows;
  const last = wins[wins.length - 1];
  if (!last || Math.abs(last.resets_at - fh.resets_at) > 1800) {
    wins.push({ resets_at: fh.resets_at, first_seen_at: now, first_seen_used: fh.used_percentage });
  }
  const cur = wins[wins.length - 1];
  const windowIndex = wins.length; // 1 = window the run started in
  let bonusInfo = null;
  if (plan === 'bonus') {
    if (bonusStart || !state.bonus) {
      state.bonus = { start_used: fh.used_percentage, extra: bonusExtra, window_resets_at: fh.resets_at, started_at: now };
    }
    bonusInfo = state.bonus;
  }
  writeJson(statePath, state);

  let cap = CAPS[Math.min(windowIndex, CAPS.length) - 1];
  if (bonusInfo) cap = Math.min(94, Math.round(bonusInfo.start_used + bonusInfo.extra));
  const soft = cap - SOFT_MARGIN;
  const used = fh.used_percentage;
  const resetsInMin = Math.round((fh.resets_at - now) / 60);
  const weekly = snap.seven_day ? snap.seven_day.used_percentage : null;
  const pc = snap.prompt_cache;
  const cacheExpiresIn = pc && pc.expires_at ? pc.expires_at - now : null;

  const bonusWindowOver = bonusInfo && Math.abs(bonusInfo.window_resets_at - fh.resets_at) > 1800;
  let status = 'OK';
  let action = 'continue';
  let reason = '';
  if (bonusWindowOver) {
    status = 'STOP';
    reason = 'bonus_window_over';
    action = 'The window the bonus belonged to has reset. Start nothing. SAFE_STOP, make sure the RESUME block is current, and tell the owner. The fresh window is split-plan window 2 (cap 60) for a fresh session with brief/RESUME_PROMPT.md.';
  } else if (bonusInfo && resetsInMin <= 3) {
    status = 'STOP';
    reason = `reset_imminent(${resetsInMin}min)`;
    action = 'SAFE_STOP now (finish nothing new; keep the tree committed and clean), update the RESUME block, then stop. Never run into the window reset.';
  } else if (fh.resets_at < now - 60) {
    status = 'UNKNOWN';
    reason = 'window_reset_passed_no_new_reading';
    action = 'The last reading belongs to a window that already reset. Do one cheap tool call (a nap counts), re-run once; if it is still the same, treat as STOP for new work.';
  } else if (windowIndex > CAPS.length) {
    status = 'STOP';
    reason = plan === 'split' ? 'third_window' : 'window_rolled_under_single_plan';
    action = 'SAFE_STOP now (see protocol section E). Do not start new work in the new window.';
  } else if (weekly !== null && weekly >= WEEKLY_STOP) {
    status = 'STOP';
    reason = 'weekly_limit_guard';
    action = 'SAFE_STOP now.';
  } else if (used >= cap) {
    status = 'STOP';
    reason = `used>=cap(${cap})`;
    action = bonusInfo ? 'SAFE_STOP the current step, update the RESUME block, then stop. The remaining points of this window are not yours to spend.' : plan === 'split' && windowIndex === 1
      ? (snap.harness === 'codex'
        ? 'SAFE_STOP the current step, write the RESUME block in brief/LEDGER.md, then STOP. Do NOT wait or nap (Codex): the owner starts a fresh session in the next window with brief/RESUME_PROMPT.md (window 2, cap 60).'
        : 'SAFE_STOP the current step, then follow protocol section D (wait for reset with naps, or leave the RESUME block in brief/LEDGER.md).')
      : 'SAFE_STOP now.';
  } else if (used >= soft || (bonusInfo && resetsInMin <= 6)) {
    status = 'SOFT';
    reason = used >= soft ? `used>=soft(${soft})` : `reset_close(${resetsInMin}min)`;
    action = 'Finish only the current step, checkpoint (tests+analyze+commit+ledger), do NOT start a new phase/step.'
      + (plan === 'split' && windowIndex === 1 && snap.harness === 'codex' ? ' Then write the RESUME block and STOP (Codex: no naps; the owner resumes in the next window, cap 60).' : '');
  } else if (age > STALE_SNAPSHOT_S) {
    status = 'UNKNOWN';
    reason = 'stale_snapshot';
    action = 'Snapshot older than 15 min. Do one cheap tool call and re-run; if still stale treat as STOP for new work.';
  }

  emit({
    status,
    harness: snap.harness,
    plan,
    window: windowIndex,
    used_5h: used.toFixed(1),
    cap,
    soft,
    headroom: (cap - used).toFixed(1),
    started_window_at_used: Number(cur.first_seen_used).toFixed(1),
    ...(bonusInfo ? { bonus_start_used: Number(bonusInfo.start_used).toFixed(1), bonus_spent: (used - bonusInfo.start_used).toFixed(1) } : {}),
    resets_in_min: resetsInMin,
    weekly: weekly === null ? '' : Number(weekly).toFixed(1),
    cache_ttl: pc ? pc.ttl : '',
    cache_warm: pc ? pc.warm : '',
    cache_expires_in_s: cacheExpiresIn === null ? '' : cacheExpiresIn,
    snapshot_age_s: age,
    reason,
    action,
  });
})();
