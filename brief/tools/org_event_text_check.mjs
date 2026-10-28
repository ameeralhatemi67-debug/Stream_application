// node --experimental-transform-types brief/tools/org_event_text_check.mjs
import assert from 'node:assert/strict';
import {orgEventText} from '../../supabase/functions/_shared/org_event_text.ts';
const kinds=['invitation','invitation_answered','join_request','join_request_answered','assignment','assignment_changed',
  'assignment_cancelled','assignment_answered','assignment_reminder','membership_changed','show_live','show_ending',
  'transfer_proposed','transfer_cancelled','transfer_completed','application_approved','application_rejected'];
const payload={organization_name_en:'Pilot org',organization_name_ar:'مؤسسة',title_en:'Weekly',title_ar:'',role:'manager',accepted:true,email:'a@b.invalid'};
for(const kind of kinds) for(const language of ['en','ar']) {
  const text=orgEventText({kind,payload},language);
  assert.ok(text.title.length>0 && text.body.length>0,`${kind}/${language} has text`);
  assert.doesNotMatch(text.title+text.body,/undefined|null|\$\{/,`${kind}/${language} is fully rendered`);
}
assert.match(orgEventText({kind:'assignment',payload},'ar').body,/Weekly/,'Arabic falls back to the English title');
assert.match(orgEventText({kind:'invitation',payload},'en').body,/manager/,'Role is named');
assert.match(orgEventText({kind:'invitation',payload:{}},'en').body,/Your organization/,'Missing names degrade gracefully');
// A personal live names its presenter, never "Your organization".
const personal={title_en:'Tafsir',title_ar:'تفسير',presenter_name_en:'Sheikh A',presenter_name_ar:'الشيخ أ'};
assert.equal(orgEventText({kind:'show_live',payload:personal},'en').body,'Tafsir — Sheikh A');
assert.equal(orgEventText({kind:'show_live',payload:personal},'ar').body,'تفسير — الشيخ أ');
assert.equal(orgEventText({kind:'show_live',payload:{title_en:'Tafsir'}},'en').body,'Tafsir');
// Decisions: the note is quoted once, without doubled punctuation.
const rejected={reason:'Add a clearer photo.',name_en:'Omar',name_ar:'عمر'};
assert.equal(orgEventText({kind:'application_rejected',payload:rejected},'en').body,
  "Reviewer's note: Add a clearer photo. Update it in Settings and apply again.");
assert.match(orgEventText({kind:'application_rejected',payload:rejected},'ar').body,/^ملاحظة المراجع: Add a clearer photo\. عدّله/);
assert.equal(orgEventText({kind:'application_rejected',payload:{edit:true}},'en').body,'Your channel keeps its approved details.');
assert.match(orgEventText({kind:'application_approved',payload:rejected},'en').body,/^Welcome, Omar\. Your channel is verified/);
assert.match(orgEventText({kind:'application_approved',payload:{organization:true}},'ar').body,/^مؤسستك موثّقة/);
assert.equal(orgEventText({kind:'application_approved',payload:{edit:true}},'en').title,'Your changes were approved');
console.log('org event text: '+kinds.length*2+' renderings and 9 wording checks passed');
