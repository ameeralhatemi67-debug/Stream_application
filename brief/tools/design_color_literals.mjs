import fs from 'node:fs';
import path from 'node:path';
const colors={FFA1A1AA:'textMuted',FFE4E4E7:'onMedia',FF22C55E:'success',FF3F3F46:'media',FFD97706:'warning',FF14151B:'media',FF0C0D12:'media',FF2F3336:'border',FF38BDF8:'primary',FF71767B:'textMuted',FF10B981:'success',FFFF8080:'danger',FF2C2F3E:'disabled',FF121214:'bg', '33FFFFFF':'onMedia','5522C55E':'success'};
function* walk(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);if(e.isDirectory())yield*walk(p);else if(p.endsWith('.dart'))yield p;}}
for(const f of walk('project/lib')){
 if(f.includes(`${path.sep}theme${path.sep}`))continue;
 let s=fs.readFileSync(f,'utf8');
 s=s.replace(/(?:const )?Color\(0x([A-Fa-f0-9]{8})\)/g,(m,c)=> colors[c]?`AppTheme.${colors[c]}`:m);
 // White remains explicit on-media/on-primary rather than becoming dark during theme changes.
 s=s.replace(/Colors\.white\b/g,'AppTheme.onMedia').replace(/Colors\.black\b/g,'AppTheme.media');
 if(s.includes('AppTheme.')&&!s.includes('app_theme.dart'))s="import 'package:streamer_app/core/theme/app_theme.dart';\n"+s;
 fs.writeFileSync(f,s);
}
