// node --experimental-transform-types brief/tools/org_event_text_check.mjs
import assert from 'node:assert/strict';
import {orgEventText} from '../../supabase/functions/_shared/org_event_text.ts';
const kinds=['invitation','invitation_answered','join_request','join_request_answered','assignment','assignment_changed',
  'assignment_cancelled','assignment_answered','assignment_reminder','membership_changed','show_live','show_ending',
  'transfer_proposed','transfer_cancelled','transfer_completed'];
const payload={organization_name_en:'Pilot org',organization_name_ar:'مؤسسة',title_en:'Weekly',title_ar:'',role:'manager',accepted:true,email:'a@b.invalid'};
for(const kind of kinds) for(const language of ['en','ar']) {
  const text=orgEventText({kind,payload},language);
  assert.ok(text.title.length>0 && text.body.length>0,`${kind}/${language} has text`);
  assert.doesNotMatch(text.title+text.body,/undefined|null|\$\{/,`${kind}/${language} is fully rendered`);
}
assert.match(orgEventText({kind:'assignment',payload},'ar').body,/Weekly/,'Arabic falls back to the English title');
assert.match(orgEventText({kind:'invitation',payload},'en').body,/manager/,'Role is named');
assert.match(orgEventText({kind:'invitation',payload:{}},'en').body,/Your organization/,'Missing names degrade gracefully');
console.log('org event text: '+kinds.length*2+' renderings passed');
