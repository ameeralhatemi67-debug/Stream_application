import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
const script = path.resolve('brief/tools/budget_check.mjs');
function check(used, minutes = 10080, age = 0, plan = 'weekly') {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'budget-test-'));
  try {
    fs.mkdirSync(path.join(dir, 'sessions'));
    fs.writeFileSync(path.join(dir, 'sessions', 'rollout-test.jsonl'), JSON.stringify({
      timestamp: new Date(Date.now() - age * 1000).toISOString(),
      rate_limits: { primary: { usedPercent: used, windowDurationMins: minutes,
        resetsAt: Math.floor(Date.now() / 1000) + 3600 } }
    }));
    return JSON.parse(execFileSync(process.execPath, [script, '--source', 'codex', '--plan', plan, '--cap', '5', '--json'],
      { env: { ...process.env, CODEX_HOME: dir }, encoding: 'utf8' }));
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
}
test('weekly thresholds and one-percent value are interpreted as percentages', () => {
  assert.equal(check(1).weekly, 1);
  assert.equal(check(1).status, 'OK');
  assert.equal(check(4).status, 'SOFT');
  assert.equal(check(5).status, 'STOP');
});
test('stale, negative and missing weekly readings fail closed', () => {
  assert.equal(check(1, 10080, 1000).status, 'UNKNOWN');
  assert.equal(check(-1).status, 'UNKNOWN');
  assert.equal(check(1, 300).status, 'UNKNOWN');
});
