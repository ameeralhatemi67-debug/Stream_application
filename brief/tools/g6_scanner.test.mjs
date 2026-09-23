import assert from 'node:assert/strict';
import test from 'node:test';
import { findHardCodedText } from './g6_scanner.mjs';

test('counts hard-coded Text literals, including non-translation method calls', () => {
  const source = `
    Text('Hello world')
    Text('Still English'.toUpperCase())
    Text('Other copy', style: style)
    Text('looks.like.a.key')
  `;
  assert.deepEqual(findHardCodedText(source).map((match) => match.text), [
    "Text('Hello world'",
    "Text('Still English'",
    "Text('Other copy'",
    "Text('looks.like.a.key'",
  ]);
});

test('excludes translated Text literals with optional whitespace and arguments', () => {
  const source = `
    Text('live.chat_empty_title'.tr())
    Text('admin.pending'.tr(args: ['2']))
    Text('settings.privacy'  .tr  ())
    Text('onboarding.title'\n      .tr())
  `;
  assert.deepEqual(findHardCodedText(source), []);
});

test('requires an actual tr call immediately after the literal', () => {
  const source = `
    Text('Literal text'.trim())
    Text('Literal label'.translate())
    Text('Literal note'.tr)
  `;
  assert.equal(findHardCodedText(source).length, 3);
});
