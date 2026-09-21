import fs from 'node:fs';
import path from 'node:path';
function* walk(d) { for(const e of fs.readdirSync(d,{withFileTypes:true})) { const p=path.join(d,e.name);if(e.isDirectory())yield* walk(p);else if(p.endsWith('.dart'))yield p;} }
// Balanced constructor spans, not a regex spanning unrelated widget trees.
function close(s,start){let depth=0;for(let i=start;i<s.length;i++){if(s[i]==='(')depth++;if(s[i]===')'&&--depth===0)return i+1;}throw Error('Unbalanced constructor');}
for(const f of walk('project/lib')) {
 if(f.includes(`${path.sep}theme${path.sep}`))continue;
 let s=fs.readFileSync(f,'utf8');
 const matches=[...s.matchAll(/\b(?:const )?(?:Linear|Radial)Gradient\(/g)];
 for(const m of matches.reverse()) {
   const end=close(s,s.indexOf('(',m.index));
   // Surfaces and media scrims are flat. The progress accent uses the named brand gradient.
   const prefix=s.slice(Math.max(0,m.index-70),m.index);
   if(/gradient:\s*active\s*\?\s*$/.test(prefix))s=s.slice(0,m.index)+'AppGradients.brand'+s.slice(end);
   else {
     const prop=s.lastIndexOf('gradient:',m.index);
     const decor=s.lastIndexOf('BoxDecoration(',prop);
     const hasColor=/\bcolor:/.test(s.slice(decor,prop));
     const media=/Colors\.black/.test(s.slice(m.index,end)) || f.includes('live_audio_stage');
     s=s.slice(0,prop)+(hasColor?'':`color: AppTheme.${media?'media':'surfaceAlt'},`)+s.slice(s[end]===','?end+1:end);
   }
 }
 fs.writeFileSync(f,s);
}
const welcome='project/lib/features/auth/presentation/welcome_screen.dart';
let s=fs.readFileSync(welcome,'utf8');
s="import '../../../core/widgets/app_logo.dart';\nimport '../../../core/config/app_identity.dart';\n"+s;
let a=s.indexOf('                  Container('),b=close(s,s.indexOf('(',a));
s=s.slice(0,a)+'                  const AppLogo(size: 96)'+s.slice(b);
s=s.replace("'auth_welcome.brand_title'.tr()","AppIdentity.name(context.locale.languageCode)");
s=s.replace("Text('Google Sign-In failed: $e')","Text('auth_welcome.sign_in_failed'.tr())");
s=s.replace(/boxShadow: \[\s*BoxShadow\([\s\S]*?\),\s*\],/g,'');
fs.writeFileSync(welcome,s);
const splash='project/lib/features/splash/presentation/app_splash_screen.dart';
s=fs.readFileSync(splash,'utf8');s="import '../../../../core/widgets/app_logo.dart';\nimport '../../../../core/config/app_identity.dart';\n"+s;
a=s.indexOf('                        child: Container(');b=close(s,s.indexOf('(',a));
s=s.slice(0,a)+'                        child: const AppLogo(size: 104)'+s.slice(b);
s=s.replace("isAr ? 'منصة البث التعليمي' : 'Educational Streamer'","AppIdentity.name(context.locale.languageCode)");
s=s.replace('color: Colors.white','color: AppTheme.textPrimary');
fs.writeFileSync(splash,s);
const settings='project/lib/features/profile/presentation/settings_screen.dart';
s=fs.readFileSync(settings,'utf8');s="import '../../../core/widgets/app_logo.dart';\nimport '../../../core/config/app_identity.dart';\n"+s;
a=s.indexOf('  Widget _buildVersionInfoCard');b=s.indexOf('  Widget _buildGovernanceCard',a);
s=s.slice(0,a)+`  Widget _buildVersionInfoCard(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppTheme.spaceLg),
    decoration: BoxDecoration(color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd), border: Border.all(color: AppTheme.border)),
    child: Column(children: [
      const AppLogo(size: 64), const SizedBox(height: AppTheme.spaceMd),
      Text(AppIdentity.name(context.locale.languageCode), style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: AppTheme.spaceSm),
      Text('settings.build_version'.tr(), textAlign: TextAlign.center),
      Text('settings.release_pending'.tr(), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
    ]),
  );

`+s.slice(b);
fs.writeFileSync(settings,s);
for(const locale of ['en','ar']) {
 const f=`project/assets/i18n/${locale}.json`,v=JSON.parse(fs.readFileSync(f,'utf8'));
 v.auth_welcome.sign_in_failed=locale==='ar'?'تعذر تسجيل الدخول. يرجى المحاولة مجددًا.':'Sign-in failed. Please try again.';
 v.settings.build_version=locale==='ar'?'الإصدار 1.0.0 (1)':'Version 1.0.0 (1)';
 v.settings.release_pending=locale==='ar'?'الإصدار قيد الاختبار. مراجعة النشر لم تكتمل بعد.':'Testing build. Release review is still pending.';
 fs.writeFileSync(f,JSON.stringify(v,null,2)+'\n');
}
const main='project/lib/main.dart';s=fs.readFileSync(main,'utf8');s="import 'core/config/app_identity.dart';\n"+s;s=s.replace("title: 'Educational Streamer'","title: AppIdentity.name(context.locale.languageCode)");fs.writeFileSync(main,s);
