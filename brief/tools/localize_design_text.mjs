import fs from 'node:fs';
import path from 'node:path';
const translations = {
 'Access Denied':'الوصول مرفوض', 'Admin Access Required':'يلزم إذن إداري',
 'Your account does not have Admin or Master Admin access. Ask a Master Admin to grant your account a role.':'لا يملك حسابك صلاحية مسؤول أو مسؤول رئيسي. اطلب من مسؤول رئيسي منحك الدور المناسب.',
 'Go to Account Settings':'الانتقال إلى إعدادات الحساب', 'Quick Actions & Governance Shortcuts':'الإجراءات السريعة واختصارات الإدارة',
 'No applications match the selected filter.':'لا توجد طلبات تطابق عامل التصفية.', 'Clear':'مسح', 'Reject Selected':'رفض المحدد', 'Approve Selected':'قبول المحدد',
 'Approve Selected Applications?':'قبول الطلبات المحددة؟', 'This feedback note is sent to every selected applicant:':'ستُرسل هذه الملاحظة إلى كل متقدم محدد:',
 'Approving Broadcaster':'قبول المذيع', 'Research Biography (English)':'السيرة البحثية بالإنجليزية', 'Approve Broadcaster':'قبول المذيع', 'Reject':'رفض','Close':'إغلاق',
 'AlSharqia Regional Engagement Breakdown':'تفاصيل التفاعل في المنطقة الشرقية','Organization Admin':'إدارة المؤسسة',
 'You are not an Owner or Co-Owner of any organization.':'لست مالكًا أو شريكًا في ملكية أي مؤسسة.', 'Select Category Icon':'اختيار أيقونة التصنيف','Pick Icon':'اختيار أيقونة',
 'Mute duration':'مدة الكتم','Permanent':'دائم','Ban Account Platform-Wide?':'حظر الحساب على مستوى المنصة؟','Ban Platform-Wide':'حظر على مستوى المنصة','Chat Moderation':'إشراف المحادثة',
 'Reported live chat messages, platform-wide. Dismiss a report, delete the message (removes it from every viewer in real time), or mute/ban the sender from that stream.':'بلاغات المحادثات المباشرة على مستوى المنصة. يمكنك إغلاق البلاغ أو حذف الرسالة لدى جميع المشاهدين أو كتم المرسل في البث أو حظره.',
 'Muted Chatters Audit Log':'سجل المستخدمين المكتومين','No chatters have been muted yet.':'لم يُكتم أي مستخدم بعد.','Dismiss':'إغلاق','Mute in Stream':'كتم في البث','Delete Message':'حذف الرسالة',
 'Organization not found':'لم يُعثر على المؤسسة','No audit logs found for this organization.':'لا توجد سجلات تدقيق لهذه المؤسسة.','Incoming Affiliation Requests & Invites':'طلبات الانضمام والدعوات الواردة',
 'No affiliation requests found for this organization.':'لا توجد طلبات انضمام لهذه المؤسسة.','Decline':'رفض','Accept to Roster':'قبول في الفريق','Roles & Permissions':'الأدوار والصلاحيات',
 'Master Admin can grant/revoke Admin or Master Admin, and toggle extra capability checkboxes. Permitted Admin (Org Owner/Co-Owner) is auto-derived from organization ownership -- see the Organizations tab.':'يمكن للمسؤول الرئيسي منح وسحب الأدوار الإدارية وتعديل الصلاحيات الإضافية. يُشتق دور مالك المؤسسة من بيانات الملكية. راجع تبويب المؤسسات.',
 'Grant a Platform Role':'منح دور في المنصة','Admin':'مسؤول','Master Admin':'مسؤول رئيسي','Grant':'منح',
 'Auto-filled from registered streamer profile!':'مُلئت البيانات من ملف المذيع المسجل.','Please enter at least a name and handle.':'يرجى إدخال الاسم والمعرّف على الأقل.','No Speakers Added Yet':'لم يُضف أي متحدث بعد.',
 'Tap "+ Add Streamer" to invite or associate speakers with this organization.':'اضغط على إضافة مذيع لدعوة المتحدثين أو ربطهم بهذه المؤسسة.','Add First Streamer':'إضافة أول مذيع',
 'You can select a maximum of 6 academic/content fields.':'يمكنك اختيار ستة مجالات علمية أو مجالات محتوى كحد أقصى.','Maximum 6 fields limit reached. Remove a field to add another.':'وصلت إلى الحد الأقصى وهو ستة مجالات. احذف مجالًا لإضافة غيره.',
 'Add Additional Campus / Branch':'إضافة مقر أو فرع آخر','Cancel':'إلغاء','Please enter a branch name and address.':'يرجى إدخال اسم الفرع وعنوانه.','Add Branch':'إضافة فرع',
 'Accepts 05XXXXXXXX, 9665XXXXXXXX, or +9665XXXXXXXX without spaces (e.g. 050 XXX XXXX).':'يُقبل الرقم بصيغة 05XXXXXXXX أو 9665XXXXXXXX أو +9665XXXXXXXX دون مسافات.',
 'Preferred Admin Contact Method':'وسيلة التواصل الإداري المفضلة','Broadcasting & Audio-Visual Standards':'معايير البث والصوت والصورة','Privacy & Regional Telemetry Guidelines':'إرشادات الخصوصية وبيانات الموقع',
 'Image Decode Error':'تعذر قراءة الصورة','Apply':'تطبيق','Pinch to zoom and drag to reposition':'باعد بين إصبعيك للتكبير واسحب لتغيير الموضع',
 'Pinpoint Broadcast Location':'تحديد موقع البث','Tap anywhere on the map or move the marker to pin your venue.':'اضغط على الخريطة أو حرّك العلامة لتحديد موقعك.','Selected Location & Coordinates:':'الموقع والإحداثيات المحددة:','Use This Location':'استخدام هذا الموقع',
 'YouTube Player':'مشغّل يوتيوب','Permission required':'يلزم منح الإذن','Open Settings':'فتح الإعدادات','LIVE':'مباشر','AUDIO':'صوتي',
 'Camera is Off • Audio Only':'الكاميرا متوقفة • صوت فقط','Turn On Camera':'تشغيل الكاميرا','Streamer Quick Controls':'أدوات المذيع السريعة','Broadcaster Studio & End Stream':'استوديو المذيع وإنهاء البث',
 'Adjust stream settings or end broadcast session':'تعديل إعدادات البث أو إنهاء الجلسة','Presentation Deck (PDF Attached)':'العرض التقديمي (ملف PDF مرفق)','No attendees admitted yet.':'لم يُقبل أي مشارك بعد.','Kick Out':'إخراج',
 'Choose a broadcast quality':'اختيار جودة البث','Continue':'متابعة','Not now':'ليس الآن','Phone broadcasting is Android-only for now.':'البث من الهاتف متاح حاليًا على أندرويد فقط.',
 'VIP Invited':'مدعو','Waiting for host to admit you...':'بانتظار موافقة المضيف على دخولك…','This is a private broadcast':'هذا بث خاص','This broadcast is private':'هذا البث خاص','Contact the host for access.':'تواصل مع المضيف للحصول على إذن الدخول.','Request to Join':'طلب الانضمام',
 'Stream key copied to clipboard':'نُسخ مفتاح البث','Ingest URL copied to clipboard':'نُسخ رابط الاستقبال','RTMP URL copied to clipboard':'نُسخ رابط RTMP','End Stream':'إنهاء البث',
 'BROADCASTER':'مذيع','English (US)':'English (US)','LTR Interface':'واجهة من اليسار إلى اليمين','Join an Organization':'الانضمام إلى مؤسسة','AlSharqia Presets:':'مواقع المنطقة الشرقية:',
 'Computer Science & AI':'علوم الحاسب والذكاء الاصطناعي','Islamic Studies & Sharia':'الدراسات الإسلامية والشريعة','Engineering & Innovation':'الهندسة والابتكار','Medicine & Health':'الطب والصحة',
 'Computer Science & AI':'علوم الحاسب والذكاء الاصطناعي','Medicine & Health Sciences':'الطب والعلوم الصحية','Engineering & Architecture':'الهندسة والعمارة','Islamic & Arabic Studies':'الدراسات الإسلامية والعربية','Business & Fintech':'الأعمال والتقنية المالية',
 'Back to Discovery Feed':'العودة إلى الاستكشاف','STREAMER':'مذيع','AlSharqia Hub':'المنطقة الشرقية','Multiple Device Login Detected':'تم اكتشاف دخول من عدة أجهزة',
 'This account is currently active as a broadcaster on another device. How would you like to continue on this device?':'هذا الحساب نشط كمذيع على جهاز آخر. كيف تود المتابعة على هذا الجهاز؟',
 'Active Broadcaster Session':'جلسة المذيع النشطة','Current Local Session':'جلسة الجهاز الحالي','Continue as Viewer':'المتابعة كمشاهد','Transfer Broadcaster to This Device':'نقل البث إلى هذا الجهاز',
};
function* walk(d){for(const e of fs.readdirSync(d,{withFileTypes:true})){const p=path.join(d,e.name);if(e.isDirectory())yield*walk(p);else if(p.endsWith('.dart'))yield p;}}
const en=JSON.parse(fs.readFileSync('project/assets/i18n/en.json','utf8')),ar=JSON.parse(fs.readFileSync('project/assets/i18n/ar.json','utf8'));
en.design_ui={};ar.design_ui={};
const keys=new Map(Object.entries(translations).map(([value,arabic],i)=>{const key=value.toLowerCase().replace(/[^a-z0-9]+/g,'_').replace(/_$/,'').slice(0,65);en.design_ui[key]=value;ar.design_ui[key]=arabic;return[value,key];}));
for(const f of walk('project/lib')){
 let s=fs.readFileSync(f,'utf8'),changed=false;
 s=s.replace(/(?:const\s+)?Text\(\s*'([^'$]+)'(?!\s*\.tr\()/g,(match,value)=>{
   if(!keys.has(value))return match;changed=true;return `Text('design_ui.${keys.get(value)}'.tr()`;
 });
 if(changed){
   if(!s.includes("import 'package:easy_localization/easy_localization.dart';"))s="import 'package:easy_localization/easy_localization.dart';\n"+s;
   fs.writeFileSync(f,s);
 }
}
for(const [lang,v] of [['en',en],['ar',ar]])fs.writeFileSync(`project/assets/i18n/${lang}.json`,JSON.stringify(v,null,2)+'\n');
