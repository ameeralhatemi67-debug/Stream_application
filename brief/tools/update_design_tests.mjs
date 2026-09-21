import fs from 'node:fs';
function edit(f,fn){fs.writeFileSync(f,fn(fs.readFileSync(f,'utf8')));}
edit('project/test/cluster_3_4_categories_moderation_test.dart',s=>"import 'package:flutter/material.dart';\n"+s);
for(const f of ['project/test/private_streaming_test.dart','project/test/issue_log_fixes_test.dart']){
 edit(f,s=>{
 s="import 'support/localized_app.dart';\n"+s;
 s=s.replace('TestWidgetsFlutterBinding.ensureInitialized();','TestWidgetsFlutterBinding.ensureInitialized();\n  setUpAll(initializeTestLocalization);');
 // Both test hosts use home only. Preserve their widget trees and interactions.
 s=s.replaceAll('MaterialApp(','localizedApp(');
 return s.replace(/await tester.pumpWidget\(wrap\(([^)]*)\)\);/g,'await tester.pumpWidget(wrap($1));\n      await tester.pump();');
 });
}
edit('project/test/v04_ui_ux_specialist_test.dart',s=>{
 const map={bg:'FFFFFFFF',surface:'FFFFFFFF',surfaceAlt:'FFECF6EF',textPrimary:'FF202B2B',textSecondary:'FF485554',textMuted:'FF586563',danger:'FF9D3044',success:'FF22613D',primary:'FF17643F',accent:'FF17643F'};
 for(const [k,v]of Object.entries(map))s=s.replace(new RegExp(`expect\\(AppTheme\\.${k}, equals\\(const Color\\(0x[0-9A-F]+\\)\\)\\);`,'g'),`expect(AppTheme.${k}, equals(const Color(0x${v})));`);
 return s.replaceAll('Minimalist Dark Theme','Scheme A Light Theme').replaceAll('Dark Theme Base','Light Theme Base');
});
for(const f of ['project/test/auth_onboarding_and_org_affiliation_test.dart','project/test/playlist_and_audio_polish_test.dart'])edit(f,s=>s.replaceAll("'STREAMER APP'","'Hadayah Live'").replaceAll("'Educational Streamer'","'Hadayah Live'"));
for(const f of ['project/test/rtmp_ip_dialog_test.dart','project/test/playlist_and_audio_polish_test.dart'])edit(f,s=>s.replace(/[\p{Extended_Pictographic}\p{Emoji_Presentation}\uFE0F\u200D]/gu,'').replace(/(['"]) +(?=[A-Za-z\u0600-\u06FF])/g,'$1'));
