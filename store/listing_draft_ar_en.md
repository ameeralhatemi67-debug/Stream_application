# Google Play listing copy, English and Arabic

Status: 2026-10-16, ready to paste. Rewritten from the code and the launch scope; it replaces the 2026-09-24 draft. Organizations are a core feature, so they are described. Everything below ships in the release build; nothing promises private streams, same-Wi-Fi Local, front camera, picture-in-picture, desktop capture inside the app, or a launch date (all still unavailable, see `brief/management/RELEASE_SCOPE.md`).

Limits: name 30, short description 80, full description 4,000, release notes 500 (counted in characters; the counts below were measured).

Before pasting: check every sentence against the signed build and the screenshots. If organizations are still switched off on the hosted backend when Google's reviewer opens the app (Admin > Safety), the organization paragraph will not match what they see. Switch it on first (see `reviewer_access.md`).

## Store settings

| Field | Value |
| --- | --- |
| App type / price | App, free |
| Category | Education |
| Tags (pick up to 5 that Play offers) | Education, Video, Lectures, Live streaming, Religion/Culture if offered |
| Contact email | the support address from `AppIdentity.supportEmail` |
| Website | https://stream-application-ten.vercel.app |
| Privacy policy | https://stream-application-ten.vercel.app/privacy.html |
| Default language | Arabic (add English as a translation) |

## English (en-US)

**App name** (12): Hadayah Live

**Short description** (73):
Watch live lectures, follow channels and find venues. Arabic and English.

**Full description** (1925):

Hadayah Live brings educational live broadcasts, recorded lectures and the venues that host them into one app, in Arabic or English with full right-to-left support.

WATCH AND DISCOVER
• See what is live now, and browse recorded lectures and playlists from each channel.
• Join a live room to watch, chat with other viewers and send reactions.
• Follow channels, and save recordings and upcoming streams to your bookmarks.
• Planned streams show their time in Saudi time. Turn on a reminder and get a notification before a stream starts.

FIND VENUES ON THE MAP
• Explore lecture halls and centres in Al Khobar, Dhahran and Dammam. Streets and place names can be saved on your phone and work without internet.
• Open directions to a venue in your maps app.

GO LIVE
• Approved broadcasters connect their own YouTube channel and go live from their phone, with video or audio only. A live notification keeps the broadcast running when the screen locks. A computer with OBS also works.
• If the connection drops, viewers see "We'll be right back", and the broadcast carries on if the broadcaster returns within two minutes.

ORGANIZATIONS
• Every organization has its own page with its team, venues, scheduled shows and live status.
• Owners invite co-owners, managers, moderators and presenters, decide who may broadcast and schedule shows. Up to three shows can be live at the same time.

SAFE BY DESIGN
• Report messages, block users, and rely on moderators who can delete messages and mute or ban accounts.
• Export your data or delete your account at any time, from Settings or from our web page.

Guests can browse and watch without signing in. Signing in with Google lets you chat, follow, save and set reminders. Broadcasting needs approval from our review team.

Hadayah Live uses YouTube API Services and the YouTube player. By using it you also agree to the YouTube Terms of Service (https://www.youtube.com/t/terms).

**What's new, 1.0.0** (131):
First release: live lectures and chat, recordings and playlists, venue map, reminders, organizations and phone or OBS broadcasting.

## العربية (ar)

**اسم التطبيق** (10): منصة هدايه

**الوصف المختصر** (74):
شاهد المحاضرات المباشرة وتابع القنوات واكتشف الأماكن بالعربية والإنجليزية.

**الوصف الكامل** (1644):

تجمع منصة هدايه البثوث التعليمية المباشرة والمحاضرات المسجّلة والأماكن التي تستضيفها في تطبيق واحد، بالعربية أو الإنجليزية مع دعم كامل للكتابة من اليمين إلى اليسار.

شاهد واكتشف
• تعرّف على ما يُبَثّ الآن، وتصفّح المحاضرات المسجّلة وقوائم التشغيل لكل قناة.
• ادخل غرفة البث للمشاهدة والدردشة مع المشاهدين الآخرين وإرسال التفاعلات.
• تابع القنوات، واحفظ التسجيلات والبثوث القادمة في المحفوظات.
• تظهر مواعيد البثوث المجدولة بتوقيت السعودية. فعّل التذكير ليصلك إشعار قبل بدء البث.

اعثر على الأماكن في الخريطة
• استكشف القاعات والمراكز في الخبر والظهران والدمام. ويمكن حفظ الشوارع وأسماء الأماكن على هاتفك لتعمل دون إنترنت.
• افتح اتجاهات الوصول إلى أي مكان في تطبيق الخرائط لديك.

ابدأ بثك
• يربط المذيعون المعتمدون قناتهم على يوتيوب ويبثون من هواتفهم بالصوت والصورة أو بالصوت فقط. ويُبقي إشعار البث التطبيق شغّالًا عند قفل الشاشة. كما يمكن البث من الحاسوب عبر OBS.
• إذا انقطع الاتصال يرى المشاهدون «سنعود حالًا»، ويستمر البث إذا عاد المذيع خلال دقيقتين.

المؤسسات
• لكل مؤسسة صفحتها الخاصة بفريقها وأماكنها وبثوثها المجدولة وحالة البث المباشر.
• يدعو المالك الشركاء والمديرين والمشرفين والمقدّمين، ويحدد من يحق له البث، ويجدول البثوث. ويمكن أن يُبَثّ ثلاثة برامج في الوقت نفسه.

آمن بطبيعته
• أبلغ عن الرسائل واحظر المستخدمين، ويتولى المشرفون حذف الرسائل وكتم الحسابات أو حظرها.
• صدّر بياناتك أو احذف حسابك في أي وقت من الإعدادات أو من صفحة الويب.

يمكن للزوار التصفح والمشاهدة دون تسجيل الدخول. وتسجيل الدخول بحساب Google يتيح الدردشة والمتابعة والحفظ وضبط التذكيرات. أما البث فيحتاج إلى موافقة فريق المراجعة.

تستخدم منصة هدايه خدمات YouTube API ومشغّل يوتيوب، وباستخدامها توافق أيضًا على شروط خدمة يوتيوب (https://www.youtube.com/t/terms).

**الجديد في 1.0.0** (121):
الإصدار الأول: محاضرات مباشرة ودردشة، وتسجيلات وقوائم تشغيل، وخريطة الأماكن، وتذكيرات، ومؤسسات، وبث من الهاتف أو عبر OBS.

## Checks before submitting

- Screenshots and the feature graphic must show real features of this build (`screenshot_shot_list.md`). Do not show a stream key, a real user's name or an email address.
- The description says "approved broadcasters". The reviewer needs a test account that is approved (`reviewer_access.md`).
- Name and wording are not legal advice; counsel reviews Arabic wording and the platform name (counsel question 5).
