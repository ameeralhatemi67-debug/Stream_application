import fs from 'node:fs';
import path from 'node:path';
function* walk(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);if(e.isDirectory())yield*walk(p);else if(p.endsWith('.dart'))yield p;}}
for(const f of walk('project/lib')){
 let s=fs.readFileSync(f,'utf8');
 const lex=/\/\/[^\n]*|\/\*[\s\S]*?\*\/|r?'''[\s\S]*?'''|r?"""[\s\S]*?"""|'(?:\\.|[^'\\])*'|"(?:\\.|[^"\\])*"|\bconst\b|[()[\]{}]/g;
 const stack=[], spans=[];
 let pending=null;
 for(const m of s.matchAll(lex)){
  const t=m[0];
  if(t==='const'){pending=m.index;continue;}
  if('([{'.includes(t)){stack.push({start:m.index,constant:pending});pending=null;}
  else if(')]}'.includes(t)){const o=stack.pop();if(o?.constant!=null&&s.slice(o.start,m.index).includes('.tr('))spans.push(o.constant);pending=null;}
  else if(pending!==null)pending=null;
 }
 for(const i of [...new Set(spans)].sort((a,b)=>b-a))s=s.slice(0,i)+s.slice(i+6);
 fs.writeFileSync(f,s);
}
const test='project/test/cluster_3_4_categories_moderation_test.dart';let s=fs.readFileSync(test,'utf8');
s=s.replace("ChatSenderBadge.moderator.emoji, equals('🛡️')","ChatSenderBadge.moderator.icon, equals(Icons.shield)").replace("ChatSenderBadge.admin.emoji, equals('👑')","ChatSenderBadge.admin.icon, equals(Icons.admin_panel_settings)");fs.writeFileSync(test,s);
