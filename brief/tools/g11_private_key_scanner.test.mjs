import assert from 'node:assert/strict';
import test from 'node:test';
import { countPrivateKeyMaterial } from './g11_private_key_scanner.mjs';

const syntheticBody = 'A'.repeat(64); // Deliberately invalid key material.

test('flags PEM material even when the closing marker is missing', () => {
  assert.equal(countPrivateKeyMaterial(`-----BEGIN PRIVATE KEY-----\n${syntheticBody}\n`), 1);
  assert.equal(countPrivateKeyMaterial(`-----BEGIN RSA PRIVATE KEY-----\\n${syntheticBody}\\n`), 1);
});

test('ignores bare headers quoted in prose or scan output', () => {
  assert.equal(countPrivateKeyMaterial('Checked -----BEGIN PRIVATE KEY----- pattern: zero hits'), 0);
  assert.equal(countPrivateKeyMaterial('-----BEGIN OPENSSH PRIVATE KEY-----\nNo key body follows.'), 0);
});
