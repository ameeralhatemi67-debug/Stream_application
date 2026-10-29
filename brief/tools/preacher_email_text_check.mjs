// node --experimental-transform-types brief/tools/preacher_email_text_check.mjs
import assert from 'node:assert/strict';
import {preacherEmail, dayLabel} from '../../supabase/functions/_shared/preacher_email_text.ts';

const site = 'https://example.invalid/';
const kinds = ['invite', 'application_received', 'application_approved', 'application_rejected', 'lesson_assigned',
  'request_approved', 'request_rejected', 'lesson_cancelled', 'lesson_changed', 'lesson_tomorrow', 'card_approved',
  'card_rejected'];
const lesson = {name_ar: 'فهد السالم', name_en: 'Fahd Al-Salem', title_ar: 'تفسير جزء عم', title_en: 'Tafsir of Juz Amma',
  date: '2026-10-31', dates: ['2026-10-31'], count: 1, slot: 'maghrib', exact_time: null, mosque_ar: 'جامع الهدى',
  mosque_en: 'Al-Huda Mosque', maps_url: 'https://www.google.com/maps/search/?api=1&query=26.29,50.19',
  reason: 'السفر.', token: 'abc123', link_kind: 'once', valid_until: null, account: false};
let n = 0;
for (const kind of kinds) {
  for (const account of [true, false]) {
    const e = preacherEmail({...lesson, kind, account}, site);
    n++;
    assert.ok(e.subject.includes(' | '), `${kind}: subject has both languages`);
    assert.doesNotMatch(e.subject + e.html + e.text, /undefined|null|NaN|\$\{/, `${kind}: fully rendered`);
    assert.match(e.html, /dir="rtl"[\s\S]*dir="ltr"/, `${kind}: Arabic block first, then English`);
    assert.ok(e.text.includes('السلام عليكم فهد السالم،') && e.text.includes('Dear Fahd Al-Salem,'), `${kind}: greets him by name`);
  }
}
// Links: the invitation carries his key; an account preacher opens his page; a
// link preacher is not sent to a page he cannot open.
assert.match(preacherEmail({...lesson, kind: 'invite'}, site).html, /href="https:\/\/example\.invalid\/preacher\/abc123"/);
assert.match(preacherEmail({...lesson, kind: 'request_approved', account: true}, site).text, /\/lessons\/me\/preacher/);
assert.doesNotMatch(preacherEmail({...lesson, kind: 'request_approved', account: false}, site).text, /\/lessons\/me\/preacher/);
assert.match(preacherEmail({...lesson, kind: 'lesson_tomorrow'}, site).html, /google\.com\/maps/, 'the reminder links directions');
// The day, prayer and mosque are spelled out; a reason is quoted once.
const assigned = preacherEmail({...lesson, kind: 'lesson_assigned'}, site).text;
assert.match(assigned, /Saturday,? 31 October 2026/);
assert.match(assigned, /بعد صلاة المغرب/);
assert.match(assigned, /جامع الهدى/);
assert.match(preacherEmail({...lesson, kind: 'lesson_cancelled'}, site).text, /السبب: السفر\.\n/);
assert.match(preacherEmail({...lesson, kind: 'lesson_assigned', count: 3, dates: ['2026-10-31', '2026-11-07', '2026-11-14']}, site).text,
  /\(3 sessions\)[\s\S]*Dates: Saturday,? 31 October 2026; Saturday,? 7 November 2026; Saturday,? 14 November 2026/);
assert.match(dayLabel('2026-10-31', 'ar'), /١٤٤٨|1448/, 'the Arabic date carries the Hijri year');
// Anything a person typed is escaped in the HTML.
const hostile = preacherEmail({...lesson, kind: 'request_rejected', reason: '<img src=x onerror=alert(1)>'}, site).html;
assert.doesNotMatch(hostile, /<img/);
assert.match(preacherEmail({...lesson, kind: 'lesson_changed'}, site).subject, /^تغيّر موعد درسك أو مكانه: تفسير جزء عم \| Your lesson moved$/);
console.log(`preacher email text: ${n} renderings and 12 wording checks passed`);
