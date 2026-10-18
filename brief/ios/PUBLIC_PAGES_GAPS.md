# Public pages gaps for iOS

2026-10-18. Local-source review only. No hosted Supabase/Vercel access this round.
No edits to project/web/ or Play launch work. These pages already exist in commit
5991d38; the historical W11 live-response problem is a deployment gap, not missing
source pages. Claude/owner own the public-page edits and redeployment.

## Source today and iOS changes for Claude

| Page / local source | What it says today | Required iOS review delta |
|---|---|---|
| privacy.html:109–125 | Android/web scope, Google identity, profile/application/contact/venue/chat/activity/device/consent data; phone media described without iOS scope. | Add eligible iOS Apple sign-in, provider subject and private relay email. Explain default iOS viewer scope: no phone publishing, channel OAuth or push. Describe any later opted-in media separately. Preserve accurate Android/web descriptions. |
| privacy.html:129–158 | Google/YouTube operations, provider policies, Supabase/Google/Vercel/map providers and public visibility. No Apple provider. Says the app shows no advertising. | Add Apple authentication/revocation processing and transient credentials/private revocation proof. Distinguish app behavior from provider-controlled YouTube ads/collection; remove a blanket ad-free implication. Confirm providers, hosting regions, contractual protections and actual analytics purposes with owner/counsel. |
| privacy.html:164–177 | Export, immediate in-app deletion, support request within 30 days, active-account retention and limited backup copies. | Replace unconditional immediate-deletion claims with actual restrictions and failure paths. Add fresh Apple reauthorization + server token revocation; unavailable/cancelled/failed means account kept. Mention separate cleanup steps, proof validity/retention, provider copies and owner-confirmed log/backup periods. Do not imply W19 source is deployed. |
| about.html:78–95 and Arabic counterpart | Viewer and broadcasting capabilities together, Google-only sign-in explanation, coming to Google Play. | Identify Apple or Google on eligible iOS builds and viewer-first availability. Do not advertise iOS phone/OBS/channel/push as released. Keep Android/web capabilities accurately labeled. Add iOS availability only after actual release evidence. |
| delete-account.html:280–342 and Arabic counterpart | Current Hadayah branding, deletion inventory, immediate sign-in revocation and instant self-service, support form with a 30-day promise. | Explain Apple-linked reauthorization/revocation and blocked/retry/support paths. Account removal is not proof every existing access token/provider copy immediately disappears. Verify the support promise, intake and response operations. Apple relay email may differ from the address a person normally uses; support must verify identity without provider passwords/codes. |
| All three | Public support contact exists and EN/AR variants are committed. | Keep the same AppIdentity contact and links in both languages; confirm the mailbox is monitored and support can review restrictions and assist in-app deletion. Support cannot complete Apple-linked deletion by email alone. Approve operator identity/address, audience/children's policy and retention with counsel. |

The deletion page's form opens a mailto composer (source lines 412–430); it is not a server-submitted deletion ticket. Owner acceptance must send a test request and confirm receipt/completion, rather than infer that opening the composer submits it.

The default in-app model is now an iOS-aware **draft for counsel review** at
v1.1.0-ios-draft. It includes Apple/Google identity, data/purposes, public visibility,
permissions, YouTube/providers, retention/copies, export/correction/withdrawal,
deletion/revocation, support, security and audience limits. Consent summaries and
privacy labels are bilingual and key-symmetric. This does not overwrite a hosted
legal record and does not publish the web policy.

## Concrete bilingual additions for review

W21 finding 3: **copy done, design decision open**. Replace every public promise
that email support will delete an Apple-linked account with this explanation:

- EN: "An account linked to Apple can only be fully deleted inside the iOS app
  with fresh Apple authorization. Support cannot complete deletion by email
  alone. Support will explain this and offer assisted in-app deletion."
- AR: "لا يمكن إكمال حذف حساب مرتبط بـ Apple إلا داخل تطبيق iOS بتفويض جديد
  من Apple. لا يستطيع الدعم إكمال الحذف بالبريد الإلكتروني وحده. يوضح الدعم
  ذلك ويقدّم مساعدة للحذف داخل التطبيق."

Apply this limit to the deletion form, restricted-account guidance and privacy
rights text in both languages. Support can review restrictions and guide retries;
it has no Apple-deletion bypass. The owner override decision remains open in
OWNER_STEPS_IOS.md. The committed public pages have not been edited or deployed.

- EN: "On eligible iOS builds you can sign in with Apple or Google. Apple may
  provide a private relay email. The default iOS app supports viewing and account
  features; phone publishing, channel connection and push are not available.
  An Apple-linked account requires fresh Apple authorization and successful
  server revocation before deletion. If a required step is unavailable,
  cancelled or fails, the account is kept and the app explains how to retry or
  contact support."
- AR: "يمكنك تسجيل الدخول باستخدام Apple أو Google في نسخ iOS المؤهلة، وقد
  توفر Apple بريد ترحيل خاصًا. يدعم تطبيق iOS الافتراضي المشاهدة وميزات الحساب،
  ولا يتيح البث من الهاتف أو ربط القنوات أو الإشعارات الفورية. يتطلب حذف الحساب
  المرتبط بـ Apple تفويضًا جديدًا وإلغاءه بنجاح على الخادم. إذا تعذرت خطوة لازمة
  أو أُلغيت أو فشلت يبقى الحساب وتوضح الرسالة كيفية المحاولة مجددًا أو التواصل
  مع الدعم."

These paragraphs supplement a complete policy, not replace it. Do not publish
an operational promise until its backend/device/support acceptance is verified.

## Deployment and acceptance owned by Claude/owner

1. Review/apply the iOS copy deltas to the existing pages in the separate public
   site task. Preserve Play launch behavior and approved Google disclosures.
2. Redeploy the already-committed static pages with routing that serves
   privacy.html/about.html/delete-account.html before the Flutter SPA fallback.
   The October 17 W11 observation is historical: privacy/about returned the root
   bootstrap body and deletion returned old branding. No new live probe was made.
3. Check public body/title/content, not just HTTP 200, without login on a phone.
   Privacy/about must show actual documents rather than the Flutter bootstrap;
   deletion must show current Hadayah branding and the real support path.
4. Match approved EN/AR text in the existing hosted Admin Hub legal record and
   default fallback, including a deliberate policy version/consent transition.
   Verify pre-login reader and Settings on a native build.
5. Verify W19 server deployment and actual Apple revocation/deletion, support
   intake/completion, and actual provider/retention disclosures before App Review.

ESC-3's in-app draft/source gap is addressed by W20 at E1. Its public delivery
part remains deployment of the existing pages, with the above content review
list for Claude. It does not block W17 source work under section 12.

Sources: local committed pages and code; [Apple 5.1.1](https://developer.apple.com/app-store/review/guidelines/#privacy),
[Apple account deletion](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion),
[Google API user data policy](https://developers.google.com/terms/api-services-user-data-policy),
[YouTube terms](https://www.youtube.com/t/terms),
[Google privacy policy](https://policies.google.com/privacy).
