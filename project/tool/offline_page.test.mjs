import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';
const html = await readFile(new URL('../web/index.html', import.meta.url), 'utf8');
const script = [...html.matchAll(/<script>([\s\S]*?)<\/script>/g)].at(-1)[1];
async function handshake(upgrade, acknowledge) {
  const handlers = {}, timers = new Set();
  let load, sent = 0;
  const old = { postMessage() { sent++; } };
  const modern = { postMessage(data, ports) {
    sent++; assert.equal(data.buildId, 'test-build');
    if (acknowledge) ports[0].postMessage(true);
  } };
  const registration = { active: upgrade ? old : modern };
  const serviceWorker = { controller: registration.active, ready: Promise.resolve(registration),
    async register() { return registration; },
    addEventListener(name, callback) { handlers[name] = callback; },
    removeEventListener(name) { delete handlers[name]; } };
  const window = { addEventListener(name, callback) { if (name === 'load') load = callback; } };
  class Channel { constructor() {
    this.port1 = { close() {}, onmessage: null };
    this.port2 = { postMessage: data => this.port1.onmessage?.({data}) };
  } }
  vm.runInNewContext(script, {window, navigator:{serviceWorker},
    document:{querySelector:()=>({content:'test-build'})}, MessageChannel:Channel,
    setTimeout(fn) {timers.add(fn); return fn;}, clearTimeout(fn) {timers.delete(fn);} });
  load(); await new Promise(setImmediate);
  assert.ok(sent > 0);
  if (upgrade) {
    registration.active = modern; serviceWorker.controller = modern;
    handlers.controllerchange?.(); await new Promise(setImmediate);
  }
  for (const timer of timers) timer();
  return window.__hadayahPageReady;
}
assert.equal(await handshake(false, true), true, 'first current worker acknowledges');
assert.equal(await handshake(true, true), true, 'old worker ignored message; updated controller retries');
assert.equal(await handshake(false, false), false, 'missing acknowledgement fails closed');
console.log('PASS: initial worker, old-to-new controller acknowledgement, bounded missing-ack failure');
