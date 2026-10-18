import 'package:flutter/foundation.dart';

import '../../../core/config/app_identity.dart';

/// Platform Terms of Service, Broadcaster Guidelines, and Privacy Policy Model
@immutable
class TermsAndConditionsModel {
  final String version;
  final DateTime lastUpdated;
  final String termsOfServiceEn;
  final String termsOfServiceAr;
  final String broadcasterGuidelinesEn;
  final String broadcasterGuidelinesAr;
  final String privacyPolicyEn;
  final String privacyPolicyAr;

  const TermsAndConditionsModel({
    required this.version,
    required this.lastUpdated,
    required this.termsOfServiceEn,
    required this.termsOfServiceAr,
    required this.broadcasterGuidelinesEn,
    required this.broadcasterGuidelinesAr,
    required this.privacyPolicyEn,
    required this.privacyPolicyAr,
  });

  String getLocalizedTerms(String languageCode) =>
      languageCode == 'ar' ? termsOfServiceAr : termsOfServiceEn;

  String getLocalizedGuidelines(String languageCode) =>
      languageCode == 'ar' ? broadcasterGuidelinesAr : broadcasterGuidelinesEn;

  String getLocalizedPrivacy(String languageCode) =>
      languageCode == 'ar' ? privacyPolicyAr : privacyPolicyEn;

  TermsAndConditionsModel copyWith({
    String? version,
    DateTime? lastUpdated,
    String? termsOfServiceEn,
    String? termsOfServiceAr,
    String? broadcasterGuidelinesEn,
    String? broadcasterGuidelinesAr,
    String? privacyPolicyEn,
    String? privacyPolicyAr,
  }) {
    return TermsAndConditionsModel(
      version: version ?? this.version,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      termsOfServiceEn: termsOfServiceEn ?? this.termsOfServiceEn,
      termsOfServiceAr: termsOfServiceAr ?? this.termsOfServiceAr,
      broadcasterGuidelinesEn:
          broadcasterGuidelinesEn ?? this.broadcasterGuidelinesEn,
      broadcasterGuidelinesAr:
          broadcasterGuidelinesAr ?? this.broadcasterGuidelinesAr,
      privacyPolicyEn: privacyPolicyEn ?? this.privacyPolicyEn,
      privacyPolicyAr: privacyPolicyAr ?? this.privacyPolicyAr,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'lastUpdated': lastUpdated.toIso8601String(),
        'termsOfServiceEn': termsOfServiceEn,
        'termsOfServiceAr': termsOfServiceAr,
        'broadcasterGuidelinesEn': broadcasterGuidelinesEn,
        'broadcasterGuidelinesAr': broadcasterGuidelinesAr,
        'privacyPolicyEn': privacyPolicyEn,
        'privacyPolicyAr': privacyPolicyAr,
      };

  factory TermsAndConditionsModel.fromJson(Map<String, dynamic> json) =>
      TermsAndConditionsModel(
        version: json['version'] as String? ?? 'v1.0.0',
        lastUpdated: DateTime.parse(
            json['lastUpdated'] as String? ?? DateTime.now().toIso8601String()),
        termsOfServiceEn: json['termsOfServiceEn'] as String? ?? '',
        termsOfServiceAr: json['termsOfServiceAr'] as String? ?? '',
        broadcasterGuidelinesEn:
            json['broadcasterGuidelinesEn'] as String? ?? '',
        broadcasterGuidelinesAr:
            json['broadcasterGuidelinesAr'] as String? ?? '',
        privacyPolicyEn: json['privacyPolicyEn'] as String? ?? '',
        privacyPolicyAr: json['privacyPolicyAr'] as String? ?? '',
      );

  static TermsAndConditionsModel createDefault() {
    return TermsAndConditionsModel(
      version: 'v1.1.0-ios-draft',
      lastUpdated: DateTime(2026, 10, 18),
      termsOfServiceEn: '''
# Hadayah Live terms of service
Draft for counsel review. Version v1.1.0-ios-draft, 18 October 2026. This default text is not a legal approval or a statement that optional features are released.

## 1. Service and agreement
Hadayah Live (منصة هدايه) supports educational discovery, YouTube viewing, venue information and account/community features. Review these terms and the privacy policy before signing in. You may browse available public content as a guest. Contact the operator at ${AppIdentity.supportEmail} about these terms or your account.

## 2. Accounts and availability
Use accurate information, protect your provider account and do not impersonate another person or organization. Google sign-in and, on eligible iOS builds, Sign in with Apple are offered. Provider authorization is separate from connecting a broadcaster's YouTube channel. The default iOS scope is viewing and account features; phone publishing, channel connection and push are unavailable there. Features depend on permissions, approval, connectivity and provider availability. Do not treat an unfinished feature notice as a working feature.

## 3. Your content and other people
Only submit content you have the right to share. Obtain permission before publishing another person's image, voice, contact details or private location. You retain your rights in your content and permit the processing needed to display, moderate and operate the features you use. Public profiles, chat, published venue points and organization pages can be seen or copied by others. Do not post confidential material.

## 4. Community safety
Harassment, hateful or unlawful material, sexual exploitation, fraud, spam, impersonation and infringement of others' rights are prohibited. Use message actions to report or block an account; moderators can remove messages and mute users. The service may restrict accounts or content to investigate abuse and protect others. Send an appeal or an urgent safety report to ${AppIdentity.supportEmail}; do not post sensitive evidence in a public chat.

## 5. Broadcasters and organizations
Publishing and privileged organization actions require approval and the relevant role. Verification is not an endorsement of every statement. Broadcasters are responsible for rights, speaker/venue permission, accurate titles and safe operation. YouTube account connection, when supported, authorizes only the requested channel operations. Streaming may be interrupted; stop a session when it ends and do not leave an ingest key exposed. This service does not replace emergency or professional advice.

## 6. Providers, payments and content
Viewing uses the YouTube player and API Services. YouTube terms (https://www.youtube.com/t/terms) and Google's privacy policy (https://policies.google.com/privacy) apply to provider-controlled activity. YouTube can serve advertisements or remove/restrict content; the app does not promise ad-free or permanent playback. No in-app purchase or payment flow is currently offered. Any future paid feature requires separate terms and the applicable store rules.

## 7. Leaving and deletion
Use Settings > Account & Data > Delete My Account, or contact ${AppIdentity.supportEmail} if you cannot use the app. The privacy policy explains export, deletion, provider revocation and restrictions. An Apple-linked account can only be fully deleted inside the iOS app with fresh Apple authorization and successful server revocation; an unavailable or failed step keeps the account. Support cannot complete deletion by email alone. Email ${AppIdentity.supportEmail} to ask what is blocking deletion. End active broadcasts and resolve organization ownership first. Support can review restricted-account cases and explain any permitted retention; this does not bypass the Apple in-app authorization requirement. Deleting this app account does not delete your Apple/Google account or YouTube videos.

## 8. Reliability, changes and contact
Content and network/provider availability can change. We do not promise uninterrupted service, perfect accuracy, secure private messaging or a particular educational outcome. Nothing here removes rights that applicable law gives you. Significant policy changes should receive an updated version and appropriate notice/consent. Counsel and the owner must approve the final operator details, retention rules and dispute provisions before publishing a production legal notice. Contact: ${AppIdentity.supportEmail}.
''',
      termsOfServiceAr: '''
# شروط خدمة Hadayah Live (منصة هدايه)
مسودة للمراجعة القانونية. الإصدار v1.1.0-ios-draft، 18 أكتوبر 2026. لا تمثل هذه النسخة الافتراضية اعتمادًا قانونيًا أو إعلانًا عن إطلاق الميزات الاختيارية.

## 1. الخدمة والموافقة
تتيح منصة هدايه اكتشاف المحتوى التعليمي ومشاهدة يوتيوب ومعلومات القاعات وميزات الحساب والمجتمع. راجع هذه الشروط وسياسة الخصوصية قبل تسجيل الدخول. يمكنك تصفح المحتوى العام المتاح بصفة زائر. للتواصل مع مشغّل الخدمة بشأن الشروط أو الحساب: ${AppIdentity.supportEmail}.

## 2. الحسابات وتوفر الميزات
استخدم معلومات صحيحة واحمِ حسابك لدى مزوّد تسجيل الدخول ولا تنتحل صفة شخص أو مؤسسة. يتاح تسجيل الدخول عبر Google، وعبر Apple في نسخ iOS المؤهلة. يختلف تفويض تسجيل الدخول عن ربط قناة المذيع على يوتيوب. تقتصر نسخة iOS الافتراضية على المشاهدة وميزات الحساب، ولا تتيح البث من الهاتف أو ربط القنوات أو الإشعارات الفورية. يعتمد توفر الميزات على الصلاحيات والاعتماد والاتصال والمزوّد. لا يعني إشعار الميزة قيد التطوير أنها تعمل بالفعل.

## 3. المحتوى وحقوق الآخرين
لا تنشر إلا ما يحق لك مشاركته. احصل على الإذن قبل نشر صورة شخص آخر أو صوته أو معلومات اتصاله أو موقعه الخاص. تحتفظ بحقوقك في محتواك وتسمح بمعالجته بالقدر اللازم لعرضه والإشراف عليه وتشغيل الميزات التي تستخدمها. قد يشاهد الآخرون الملفات العامة والدردشة ومواقع القاعات المنشورة وصفحات المؤسسات أو ينسخونها. لا تنشر مواد سرية.

## 4. سلامة المجتمع
يُحظر التحرش والكراهية والمحتوى غير المشروع والاستغلال الجنسي والاحتيال والإزعاج وانتحال الهوية وانتهاك الحقوق. استخدم إجراءات الرسالة للإبلاغ أو الحظر، ويمكن للمشرفين إزالة الرسائل وكتم المستخدمين. يجوز تقييد الحساب أو المحتوى للتحقق من الإساءة وحماية الآخرين. أرسل الاعتراضات وبلاغات السلامة العاجلة إلى ${AppIdentity.supportEmail} ولا تنشر أدلة حساسة في دردشة عامة.

## 5. المذيعون والمؤسسات
يتطلب البث وإدارة المؤسسة اعتمادًا والدور المناسب. لا يعني التوثيق تأييد كل ما يقال. يتحمل المذيع مسؤولية حقوق المحتوى وإذن المتحدثين والقاعة ودقة العناوين والتشغيل الآمن. يتيح ربط يوتيوب، حيث يتوفر، عمليات القناة التي طلبتها فقط. قد ينقطع البث؛ أنهِ الجلسة عند انتهاء النشاط ولا تكشف مفتاح الإرسال. لا تحل الخدمة محل الطوارئ أو الاستشارة المهنية.

## 6. المزوّدون والمدفوعات والمحتوى
تستخدم المشاهدة مشغّل يوتيوب وخدمات واجهاته. تسري شروط يوتيوب (https://www.youtube.com/t/terms) وسياسة خصوصية Google (https://policies.google.com/privacy) على النشاط الذي يتحكم به المزوّد. قد يعرض يوتيوب إعلانات أو يزيل المحتوى أو يقيّده؛ لا نعد بمشاهدة دائمة أو خالية من الإعلانات. لا توجد حاليًا عمليات شراء أو مدفوعات داخل التطبيق. تتطلب أي ميزة مدفوعة مستقبلية شروطًا مستقلة وقواعد المتجر المعنية.

## 7. المغادرة والحذف
استخدم الإعدادات > الحساب والبيانات > حذف حسابي، أو راسل ${AppIdentity.supportEmail} إذا تعذر استخدام التطبيق. توضح سياسة الخصوصية التصدير والحذف وإلغاء تفويض المزوّد والقيود. لا يمكن إكمال حذف الحساب المرتبط بـ Apple إلا داخل تطبيق iOS بتفويض جديد من Apple وإلغائه بنجاح على الخادم؛ يبقى الحساب إذا تعذرت أي خطوة. لا يستطيع الدعم إكمال الحذف بالبريد الإلكتروني وحده. راسل ${AppIdentity.supportEmail} للسؤال عمّا يمنع الحذف. أنهِ البث النشط وعالج ملكية المؤسسة أولًا. يراجع الدعم الحالات المقيّدة ويبين أي احتفاظ مسموح دون تجاوز شرط تفويض Apple داخل التطبيق. لا يحذف حذف حساب التطبيق حساب Apple أو Google أو فيديوهات يوتيوب.

## 8. الاستمرارية والتعديلات والتواصل
قد يتغير المحتوى وتوفر الشبكة والمزوّدين. لا نضمن الاستمرارية أو الدقة الكاملة أو سرية المراسلات العامة أو نتيجة تعليمية محددة. لا تسقط هذه الشروط حقوقك التي يمنحها القانون المنطبق. ينبغي إصدار نسخة محدثة وإشعار أو موافقة مناسبة للتغييرات المهمة. يجب اعتماد بيانات المشغّل وقواعد الاحتفاظ وأحكام النزاع من المالك والمستشار القانوني قبل نشر الإشعار النهائي. للتواصل: ${AppIdentity.supportEmail}.
''',
      broadcasterGuidelinesEn: '''
# Broadcaster guidelines
Draft for counsel review, 18 October 2026.

1. Obtain content, speaker and venue permissions; respect privacy and copyright.
2. Present educational material accurately, cite sources and avoid misleading verification claims.
3. Moderate chat, respond to reports and never disclose passwords or ingest keys.
4. Follow venue safety rules. Obtain consent before showing attendees or sharing their details.
5. Select video or audio-only only where supported; check the real output and stop the session when finished. No minimum video resolution is promised for an audio-only session.
6. Phone publishing is unavailable in the default iOS viewer build. Use only approved features and roles.
7. Report safety, rights or account problems to ${AppIdentity.supportEmail}.
''',
      broadcasterGuidelinesAr: '''
# إرشادات المذيعين
مسودة للمراجعة القانونية، 18 أكتوبر 2026.

1. احصل على أذونات المحتوى والمتحدثين والقاعة واحترم الخصوصية وحقوق النشر.
2. قدّم المادة التعليمية بدقة واذكر المصادر ولا توحِ بأن التوثيق اعتماد لكل محتوى.
3. أشرف على الدردشة واستجب للبلاغات ولا تكشف كلمات المرور أو مفاتيح البث.
4. اتبع قواعد سلامة القاعة واحصل على الموافقة قبل إظهار الحاضرين أو مشاركة بياناتهم.
5. اختر الفيديو أو الصوت فقط حيث تدعم الخدمة ذلك، وافحص الناتج الفعلي وأنهِ الجلسة عند الانتهاء. لا توجد دقة فيديو دنيا لجلسة صوتية فقط.
6. لا تتيح نسخة iOS الافتراضية للمشاهدة البث من الهاتف. استخدم الميزات والأدوار المعتمدة فقط.
7. أبلغ مشكلات السلامة والحقوق والحساب عبر ${AppIdentity.supportEmail}.
''',
      privacyPolicyEn: '''
# Hadayah Live privacy policy
Draft for counsel review. Version v1.1.0-ios-draft, 18 October 2026. This is a complete product-data draft, not a claim of legal certification. Contact the Hadayah Live operator at ${AppIdentity.supportEmail}.

## 1. Scope and choices
This policy covers the app's account, community, discovery, venue and supported broadcasting features. Public browsing can be used without signing in. Review this notice before account consent. Declining an optional location, photo, camera or microphone permission should only limit the feature that needs it. Permission controls are separate from account consent.

## 2. Google and Apple identity
Google sign-in, and Sign in with Apple on eligible iOS builds, provide account identifiers and may provide a name, avatar or email. Apple can supply a private relay email; do not assume it is your ordinary email or that your name is supplied on every authorization. We use provider identity to establish and protect your Supabase account, not your provider password. Authentication codes, tokens and nonces are used to complete the requested authentication or revocation flow and must be handled as credentials.

## 3. Profile, application and venue data
We process the display name, biography, avatar/banner and channel details you provide. Broadcaster/organization applications can include name, email, phone, academic/organization information, venue address/coordinates and uploaded images, together with review decisions and notes. Publish only information you are entitled to share. Profile/organization/venue material you publish can be public; authorized staff review applications. Avoid confidential documents in images intended for public display.

## 4. Chat, safety and support
Chat messages are visible in their room. Reports, block lists, mutes, bans and related review records support moderation and abuse prevention. Staff see the information needed to review a report or application. If you contact support, your email provider and the support operator process your message, address and attachments. Do not send passwords, authorization codes or ingest keys.

## 5. Activity and technical records
The service processes follows, saved items, schedules/reminders, notification preferences, live presence, account/device identifiers, platform/device name, last activity and the policy version/time you accepted. Administrative statistics may summarize service use. Providers process connection information such as IP address and requested content to serve APIs, video, maps and images. Where push is configured on supported platforms, Firebase registration data delivers reminders. Default iOS viewer builds do not initialize Firebase messaging or offer push.

## 6. Location, photos and publishing permissions
Using the location button reads your location to place a candidate venue pin. Only the venue point you confirm is saved; a published venue point/address is public. The app does not request background location. Selected photos can be uploaded for the profile or application feature you choose.

On supported phone-publishing builds, choosing to broadcast uses camera/microphone permission and sends live video or audio to the destination ingest provider. Audio-only publishing, when offered, can continue microphone capture in the background while the active session runs. Hadayah's app servers do not keep a recording of that live phone media; YouTube may retain the resulting video. Phone publishing and its media collection are disabled in the default iOS viewer build, as are channel connection and push.

## 7. Purposes, sharing and providers
We use these records to operate the features you request, review applications/roles, maintain viewer/session accuracy, moderate abuse, provide support, administer the service and meet applicable obligations. Publicly posted material is shared with its audience. Supabase provides authentication, database, storage and server functions. Google provides sign-in, YouTube APIs/player and Firebase messaging where enabled. Apple provides Apple authorization. Hosting, map and image providers process requests needed for their services. Providers may process data outside your country; the owner must confirm the final hosting locations and contractual protections before publishing this draft.

We do not sell personal data. Google API information is used for the requested features under the Google API Services User Data Policy, including Limited Use (https://developers.google.com/terms/api-services-user-data-policy). The YouTube player uses youtube-nocookie.com; this is not a promise of zero provider collection or advertising. YouTube terms (https://www.youtube.com/t/terms) and Google's privacy policy (https://policies.google.com/privacy) govern provider-controlled activity. We do not promise that embedded content is ad-free or infer every provider's tracking practices from the app's own manifest.

## 8. Retention and copies
Account-linked records remain while needed to operate your account and its features. Completed self-deletion removes the account and linked records and attempts removal of owned uploads. Identifying name/email copies in review/audit records are redacted by the current deletion path; non-identifying operational history can remain. Provider logs/backups have their own expiry schedules. Copies, exports or screenshots held by you or others and videos held by YouTube are not erased from those systems by deleting the app account.

For Apple-linked deletion, the server temporarily exchanges/revokes provider credentials without storing them. A private identity/version/timestamp record proves revocation for ten minutes. That record has no deletion authority after expiry and cascades with the identity/account, but may remain with an undeleted account until a later attempt or deletion. Exact backup/log retention periods and any legally required exceptions need owner/counsel confirmation; this draft does not promise an unverified erasure deadline.

## 9. Access, correction, withdrawal and deletion
Use Settings > Privacy > Download My Data to export linked data, and edit your profile to correct it. Disable optional permissions through device settings and supported reminder categories in-app. Withdraw account consent by deleting the account or contacting ${AppIdentity.supportEmail}; there is no separate in-app withdrawal that leaves the same account active.

Use Settings > Account & Data > Delete My Account. The process can require ending an active broadcast, transferring organization ownership or clearing owned files. Restricted-account cases need support review. An Apple-linked account can only be fully deleted inside the iOS app with fresh Apple authorization and successful server revocation; if unavailable, cancelled or failed, the account is kept with an explanatory message. Support cannot complete deletion by email alone. Email ${AppIdentity.supportEmail} to ask what is blocking deletion. Revocation, upload cleanup and account deletion are separate steps, so a later failure may leave an account alive after some cleanup. Email support to ask what is blocking deletion or why any records are retained.

If you cannot sign in, use ${AppIdentity.deleteAccountUrl} or email ${AppIdentity.supportEmail}. Verify your identity through support rather than sending provider passwords. Deletion of this account does not delete your Apple/Google account or YouTube videos. Manage other provider grants through the provider's own account controls.

## 10. Security, children and updates
We use account access controls and HTTPS for account APIs. Public chat/broadcasts are not confidential or end-to-end encrypted messaging; media transport depends on the provider and destination. No system guarantees perfect security. Report concerns to ${AppIdentity.supportEmail}.

The service is not designed specifically for children under 13 and has no built-in age-verification or parental-control system. A guardian who believes a child submitted personal data should contact support. Counsel must review the audience, children's policy and final legal basis/rights process. Material notice changes should use a new version and appropriate notice/consent. The current support/privacy links and published policy must be kept consistent with the actual released features.
''',
      privacyPolicyAr: '''
# سياسة خصوصية Hadayah Live (منصة هدايه)
مسودة للمراجعة القانونية. الإصدار v1.1.0-ios-draft، 18 أكتوبر 2026. هذه مسودة شاملة لتدفقات بيانات المنتج ولا تعني الحصول على شهادة امتثال قانوني. للتواصل مع مشغّل الخدمة: ${AppIdentity.supportEmail}.

## 1. النطاق والاختيارات
تشمل السياسة ميزات الحساب والمجتمع والاكتشاف والقاعات والبث المتاح. يمكن تصفح المحتوى العام دون تسجيل الدخول. راجع الإشعار قبل الموافقة على إنشاء الحساب. ينبغي أن يقتصر أثر رفض إذن اختياري للموقع أو الصور أو الكاميرا أو الميكروفون على الميزة التي تحتاجه. تختلف أذونات الجهاز عن الموافقة الخاصة بالحساب.

## 2. هوية Google وApple
يوفر تسجيل الدخول عبر Google، وعبر Apple في نسخ iOS المؤهلة، معرّفات الحساب وقد يوفر الاسم أو الصورة أو البريد. قد تمنح Apple عنوان بريد ترحيل خاصًا لإخفاء بريدك؛ لا تفترض أنه بريدك المعتاد أو أن الاسم يتاح في كل تفويض. نستخدم هوية المزوّد لإنشاء حساب Supabase وحمايته، ولا نتلقى كلمة مرور المزوّد. تُستخدم رموز التفويض والرموز الأمنية والقيم الفريدة لإتمام تسجيل الدخول أو إلغاء التفويض المطلوب، وتُعامل كبيانات اعتماد.

## 3. الملف والطلبات والقاعات
نعالج اسم العرض والنبذة والصورة والغلاف وبيانات القناة التي تقدمها. قد تتضمن طلبات المذيع أو المؤسسة الاسم والبريد والهاتف والمعلومات الأكاديمية أو المؤسسية وعنوان القاعة وإحداثياتها والصور المرفوعة وقرارات المراجعة وملاحظاتها. لا تشارك إلا ما يحق لك نشره. يمكن أن تكون بيانات الملف والمؤسسة والقاعة التي تنشرها عامة، ويراجع الموظفون المخوّلون الطلبات. تجنب المستندات السرية في الصور المخصصة للعرض العام.

## 4. الدردشة والسلامة والدعم
تظهر الرسائل داخل غرفة الدردشة. تدعم البلاغات وقوائم الحظر والكتم والإيقاف وسجلات المراجعة الإشراف ومنع الإساءة. يطّلع الموظفون على ما يلزم لمراجعة البلاغ أو الطلب. عند مراسلة الدعم يعالج مزوّد بريدك ومشغّل الدعم الرسالة والعنوان والمرفقات. لا ترسل كلمات المرور أو رموز التفويض أو مفاتيح البث.

## 5. النشاط والسجلات التقنية
تعالج الخدمة المتابعات والعناصر المحفوظة والمواعيد والتذكيرات وتفضيلات الإشعارات والحضور المباشر ومعرّفات الحساب والجهاز ونوع الجهاز واسمه وآخر نشاط وإصدار السياسة الذي وافقت عليه ووقتها. قد تلخّص الإحصاءات الإدارية استخدام الخدمة. يعالج المزوّدون معلومات الاتصال مثل عنوان IP والمحتوى المطلوب لتقديم الواجهات والفيديو والخرائط والصور. حيث تُفعّل الإشعارات على منصة مدعومة تُستخدم بيانات تسجيل Firebase لتوصيل التذكيرات. لا تهيّئ نسخة iOS الافتراضية للمشاهدة رسائل Firebase ولا تقدم الإشعارات الفورية.

## 6. أذونات الموقع والصور والبث
يقرأ زر الموقع موقعك لوضع علامة مقترحة للقاعة. لا يُحفظ إلا الموقع الذي تؤكده، ويكون موقع القاعة وعنوانها المنشوران عامّين. لا يطلب التطبيق الموقع في الخلفية. يمكن رفع الصور التي تختارها للملف أو الطلب الذي تستخدمه.

في نسخ البث المدعومة، يستخدم البث من الهاتف إذن الكاميرا والميكروفون ويرسل الفيديو أو الصوت المباشر إلى مزوّد استقبال البث. قد يواصل البث الصوتي، حيث يتاح، التقاط الميكروفون في الخلفية أثناء الجلسة النشطة. لا تحفظ خوادم تطبيق هدايه تسجيلًا لهذه الوسائط المباشرة، وقد يحتفظ يوتيوب بالفيديو الناتج. البث من الهاتف وجمع وسائطه معطّلان في نسخة iOS الافتراضية للمشاهدة، وكذلك ربط القنوات والإشعارات الفورية.

## 7. الأغراض والمشاركة والمزوّدون
نستخدم السجلات لتشغيل الميزات التي تطلبها ومراجعة الطلبات والأدوار ودقة الحضور والجلسات والإشراف والدعم وإدارة الخدمة والالتزامات المنطبقة. تُشارك المواد المنشورة علنًا مع جمهورها. يقدم Supabase تسجيل الدخول وقاعدة البيانات والتخزين ووظائف الخادم. تقدم Google تسجيل الدخول وواجهات يوتيوب ومشغّله ورسائل Firebase حيث تُفعّل. تقدم Apple تفويض Apple. يعالج مزوّدو الاستضافة والخرائط والصور الطلبات اللازمة لخدماتهم. قد تُعالج البيانات خارج بلدك؛ يجب أن يؤكد المالك مواقع الاستضافة والحماية التعاقدية قبل اعتماد هذه المسودة.

لا نبيع البيانات الشخصية. تُستخدم معلومات واجهات Google للميزات المطلوبة وفق سياسة بيانات مستخدمي خدمات Google API ومتطلبات الاستخدام المحدود (https://developers.google.com/terms/api-services-user-data-policy). يستخدم مشغّل يوتيوب youtube-nocookie.com، ولا يعني ذلك انعدام جمع المزوّد للبيانات أو الإعلانات. تنظم شروط يوتيوب (https://www.youtube.com/t/terms) وسياسة خصوصية Google (https://policies.google.com/privacy) النشاط الذي يتحكم به المزوّد. لا نعد بمحتوى مضمّن خالٍ من الإعلانات ولا نستنتج ممارسات تتبع كل المزوّدين من ملف خصوصية التطبيق وحده.

## 8. الاحتفاظ والنسخ
تبقى البيانات المرتبطة بالحساب بقدر الحاجة لتشغيله وميزاته. يزيل الحذف الذاتي المكتمل الحساب والسجلات المرتبطة ويحاول إزالة الملفات المرفوعة المملوكة لك. يحجب مسار الحذف الحالي نسخ الاسم والبريد المعرّفة بك في سجلات المراجعة والتدقيق، وقد يبقى تاريخ تشغيلي غير معرّف بالشخص. تخضع سجلات المزوّدين ونسخهم الاحتياطية لجداول انتهاء خاصة بهم. لا يزيل حذف حساب التطبيق النسخ أو الصادرات أو لقطات الشاشة لدى المستخدمين أو الفيديوهات لدى يوتيوب من تلك الأنظمة.

عند حذف حساب مرتبط بـ Apple يتبادل الخادم بيانات اعتماد المزوّد ويلغيها مؤقتًا دون تخزينها. يثبت سجل خاص للهوية وإصدارها ووقت الإلغاء نجاح الإلغاء لمدة عشر دقائق. لا يمنح السجل سلطة للحذف بعد انتهاء المدة، ويُزال تبعًا لحذف الهوية أو الحساب، لكنه قد يبقى مع حساب لم يُحذف حتى محاولة لاحقة أو الحذف. تحتاج مدد النسخ الاحتياطية والسجلات الدقيقة والاستثناءات القانونية إلى تأكيد المالك والمستشار؛ لا تعد هذه المسودة بموعد محو غير متحقق.

## 9. الاطلاع والتصحيح وسحب الموافقة والحذف
استخدم الإعدادات > الخصوصية > تنزيل بياناتي لتصدير البيانات المرتبطة بك، وعدّل ملفك لتصحيحها. عطّل الأذونات الاختيارية من إعدادات الجهاز وفئات التذكيرات المدعومة داخل التطبيق. اسحب موافقة الحساب بحذفه أو بمراسلة ${AppIdentity.supportEmail}؛ لا يوجد خيار مستقل داخل التطبيق لسحب الموافقة مع إبقاء الحساب نفسه نشطًا.

استخدم الإعدادات > الحساب والبيانات > حذف حسابي. قد يلزم إنهاء البث النشط أو نقل ملكية المؤسسة أو إزالة الملفات المملوكة. تحتاج الحسابات المقيّدة إلى مراجعة الدعم. لا يمكن إكمال حذف الحساب المرتبط بـ Apple إلا داخل تطبيق iOS بتفويض جديد من Apple وإلغائه على الخادم؛ إذا تعذر أو أُلغي أو فشل تبقى بيانات الحساب مع رسالة توضيحية. لا يستطيع الدعم إكمال الحذف بالبريد الإلكتروني وحده. راسل ${AppIdentity.supportEmail} للسؤال عمّا يمنع الحذف. الإلغاء وتنظيف الملفات وحذف الحساب خطوات مستقلة؛ وقد يبقى الحساب بعد تعثر خطوة لاحقة مع حدوث بعض التنظيف. راسل الدعم للسؤال عمّا يمنع الحذف أو عن سبب الاحتفاظ بأي سجلات.

إذا تعذر تسجيل الدخول فاستخدم ${AppIdentity.deleteAccountUrl} أو راسل ${AppIdentity.supportEmail}. أثبت هويتك عبر الدعم بدلًا من إرسال كلمة مرور المزوّد. لا يحذف هذا الإجراء حساب Apple أو Google أو فيديوهات يوتيوب. أدر تفويضات المزوّدين الأخرى من أدوات حساباتهم.

## 10. الأمان والأطفال والتحديثات
نستخدم ضوابط وصول الحساب وHTTPS لواجهات الحساب. ليست الدردشة والبث العامان مراسلات سرية أو مشفّرة بين الأطراف؛ ويعتمد نقل الوسائط على المزوّد والوجهة. لا يضمن أي نظام أمانًا كاملًا. أبلغ المخاوف عبر ${AppIdentity.supportEmail}.

الخدمة ليست مخصصة للأطفال دون 13 عامًا، ولا تتضمن نظام تحقق من العمر أو رقابة أبوية. على ولي الأمر الذي يعتقد أن طفلًا قدم بيانات شخصية التواصل مع الدعم. يجب مراجعة الجمهور وسياسة الأطفال والأساس القانوني وإجراءات الحقوق مع المستشار. ينبغي إصدار نسخة جديدة وإشعار أو موافقة مناسبة عند تغيير جوهري، ومطابقة روابط الدعم والخصوصية والسياسة المنشورة للميزات الصادرة فعلًا.
''',
    );
  }
}
