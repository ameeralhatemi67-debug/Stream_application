import fs from 'node:fs';
function edit(f,fn){let s=fs.readFileSync(f,'utf8');fs.writeFileSync(f,fn(s));}
function wrap(s,needle,wrapper='Flexible'){
 const pos=s.indexOf(needle);if(pos<0)throw Error(needle);
 const start=s.lastIndexOf('Text(',pos);let depth=0,end=start;
 for(let i=start+4;i<s.length;i++){if(s[i]==='(')depth++;if(s[i]===')'&&--depth===0){end=i+1;break;}}
 return s.slice(0,start)+`${wrapper}(child: `+s.slice(start,end)+')'+s.slice(end);
}
edit('project/lib/features/auth/presentation/streamer_apply_screen.dart',s=>{
 s=s.replace('Row(\n                        mainAxisAlignment: MainAxisAlignment.spaceBetween,','Wrap(\n                        alignment: WrapAlignment.spaceBetween,\n                        spacing: AppTheme.spaceSm,');
 s=s.replace('Row(\r\n                        mainAxisAlignment: MainAxisAlignment.spaceBetween,','Wrap(\r\n                        alignment: WrapAlignment.spaceBetween,\r\n                        spacing: AppTheme.spaceSm,');
 return wrap(s,"_currentStep == _totalSteps - 1\n                                          ? 'wizard_steps.btn_submit'");
});
edit('project/lib/features/discovery/presentation/discovery_feed_screen.dart',s=>{
 const p=s.indexOf("'feed.streamers'.tr()");const row=s.lastIndexOf('Row(',p);
 return s.slice(0,row)+s.slice(row).replace(/Row\(\s*mainAxisAlignment: MainAxisAlignment.spaceBetween,/, 'Wrap(alignment: WrapAlignment.spaceBetween, spacing: AppTheme.spaceMd, runSpacing: AppTheme.spaceSm,');
});
edit('project/lib/features/profile/presentation/settings_screen.dart',s=>{
 let p=s.indexOf('  Widget _buildSectionHeader');s=s.slice(0,p)+wrap(s.slice(p),'          title,','Expanded');
 p=s.indexOf("'settings.viewer_badge'.tr()");
 const start=s.lastIndexOf('          Container(',p);let depth=0,end=start;
 for(let i=s.indexOf('(',start);i<s.length;i++){if(s[i]==='(')depth++;if(s[i]===')'&&--depth===0){end=i+1;break;}}
 s=s.slice(0,start)+'          Flexible(child: '+s.slice(start,end).trim()+')'+s.slice(end);
 s=wrap(s,"'settings.viewer_badge'.tr()");
 return s;
});
