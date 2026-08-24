---
type: audit
tags:
  - arabic-localization
  - rtl-ergonomics
  - i18n
  - overflow-prevention
  - streamer-app
created: 2026-08-18
updated: 2026-08-18
---

# 🇸🇦 Comprehensive Arabic Localization, RTL Ergonomics & Missing Translations Audit

> **Target System:** Streamer App (Knowledge & Educational Cloud Platform — Eastern Province)  
> **Prepared by:** Elite Arabic Localization & RTL Layout Specialist  
> **Parent Indexes:** `[[Main Work Flow]]` | `[[Active Projects.md|Active Projects]]` | `[[AUTH_ONBOARDING_ORG_MANAGEMENT_SPEC.md]]`

---

## 🏛️ 1. Executive Summary

This audit delivers an exhaustive, line-by-line inspection of the **Streamer App** Flutter codebase regarding Arabic language integration, missing localization keys, linguistic and academic cultural tone, and RTL layout ergonomics.

### Critical Findings Overview:
1. **Unregistered Localization Keys Crashing to Raw Keys:** In `org_management_view.dart`, calls to `'common.cancel'.tr()` and `'common.save'.tr()` fail because no `"common"` root dictionary exists in either `en.json` or `ar.json`, rendering raw `common.cancel` to users.
2. **Entire Unlocalized Auth & Verification Subsystems:** The entire new 5-step Verification Application Wizard (`ApplyStep1Identity` through `ApplyStep5Review`), `WelcomeScreen`, `ViewerSetupScreen`, `RoleSelectScreen`, `ApplicationPendingScreen`, `JoinOrgModalSheet`, and `RtmpIpSettingsDialog` are currently hardcoded in English with zero `.tr()` integration.
3. **Linguistic Mismatches with Saudi Academic Context:** Several existing translations in `ar.json` use literal machine-translated terms (e.g., "مذيع معتمد" instead of "محاضر أكاديمي معتمد", "وضع المخرج للعرض التقديمي" instead of "استوديو التحكم في البث", "مقدم برامج تعليمية" instead of "محاضر وباحث أكاديمي").
4. **RTL Directionality & Icon Inversion Defects:** Forward navigation arrows (`Icons.arrow_forward_rounded`) and backward arrows (`Icons.arrow_back_rounded`) are hardcoded without directionality mirroring, causing directional arrows to point backwards in Arabic RTL mode.
5. **Cursive Ligature Corruption:** Welcome and brand headers apply `letterSpacing: 2.5` to uppercase text, which if used on Arabic typography breaks the cursive script and splits Arabic letters into disconnected glyphs.
6. **Horizontal RenderFlex Overflows:** Arabic text expands by **22% to 38%** in length. Unconstrained `Row` children in `ApplyStep3Professional` entity buttons, `OrgManagementView` action bars, and `StreamerApplyScreen` bottom navigation bars overflow the viewport on standard 360–390dp mobile screens.

---

## 🔍 2. Full Audit: `assets/i18n/en.json` vs `assets/i18n/ar.json` & Hardcoded UI Widgets

### 2.1 Root Dictionary Comparison
| Dictionary Root Key | In `en.json`? | In `ar.json`? | Code Integration Status |
| :--- | :---: | :---: | :--- |
| `app` | ✅ Yes (3 keys) | ✅ Yes (3 keys) | Fully synchronized |
| `nav` | ✅ Yes (8 keys) | ✅ Yes (8 keys) | Fully synchronized |
| `map` | ✅ Yes (21 keys) | ✅ Yes (21 keys) | Fully synchronized |
| `feed` | ✅ Yes (37 keys) | ✅ Yes (37 keys) | Fully synchronized |
| `profile` | ✅ Yes (45 keys) | ✅ Yes (45 keys) | Fully synchronized |
| `live` | ✅ Yes (52 keys) | ✅ Yes (52 keys) | Synchronized |
| `safety` | ✅ Yes (3 keys) | ✅ Yes (3 keys) | Synchronized |
| `language` | ✅ Yes (7 keys) | ✅ Yes (7 keys) | Synchronized |
| `venue` | ✅ Yes (11 keys) | ✅ Yes (11 keys) | Synchronized |
| `settings` | ✅ Yes (96 keys) | ✅ Yes (96 keys) | Synchronized |
| `onboarding` | ✅ Yes (11 keys) | ✅ Yes (11 keys) | Synchronized |
| `notifications` | ✅ Yes (2 keys) | ✅ Yes (2 keys) | Synchronized |
| `application` | ✅ Yes (41 keys) | ✅ Yes (41 keys) | **Legacy keys only**; misses new 5-step wizard fields |
| `admin` | ✅ Yes (78 keys) | ✅ Yes (78 keys) | Synchronized for main admin; misses affiliation & sub-tabs |
| **`common`** | ❌ **MISSING** | ❌ **MISSING** | **Fatal bug:** Called in `org_management_view.dart` (`common.cancel`, `common.save`) |
| **`auth_welcome`** | ❌ **MISSING** | ❌ **MISSING** | Entire `welcome_screen.dart` is hardcoded |
| **`viewer_setup`** | ❌ **MISSING** | ❌ **MISSING** | Entire `viewer_setup_screen.dart` is hardcoded |
| **`role_select`** | ❌ **MISSING** | ❌ **MISSING** | Entire `role_select_screen.dart` is hardcoded |
| **`wizard_steps`** (1–5) | ❌ **MISSING** | ❌ **MISSING** | All wizard step widgets are hardcoded |
| **`wizard_pending`** | ❌ **MISSING** | ❌ **MISSING** | `application_pending_screen.dart` is hardcoded |
| **`affiliation_modal`** | ❌ **MISSING** | ❌ **MISSING** | `join_org_modal_sheet.dart` & org views hardcoded |
| **`live_studio`** | ❌ **MISSING** | ❌ **MISSING** | `rtmp_ip_dialog.dart` is hardcoded |

---

## 🎓 3. Arabic Linguistic & Cultural Accuracy Audit

### 3.1 Academic Terminology Assessment Matrix (Saudi / Gulf Standard)

| English Term | Current / Literal Arabic | Authentic Saudi Academic Standard | Rationale & Regulatory Alignment |
| :--- | :--- | :--- | :--- |
| **Individual Broadcaster / Scholar** | مقدم برامج تعليمية / مذيع معتمد | **محاضر وباحث أكاديمي معتمد** | "مذيع" denotes commercial TV/radio anchor. Saudi higher-education platforms use "محاضر" (Lecturer) or "باحث أكاديمي" (Academic Researcher). |
| **Organization / Entity** | منظمة / جهة / مؤسسة تعليمية | **صرح تعليمي / أكاديمية معتمدة** | "صرح تعليمي" and "أكاديمية معتمدة" align with Saudi Technical & Vocational Training Corporation (TVTC) and Ministry of Education terminology. |
| **Core Faculty** | كادر دائم | **أعضاء هيئة التدريس الأساسية** | Institutional standard across KFUPM, IAU, and King Saud University. |
| **Guest Speaker** | مدرب زائر | **محاضر زائر / مدرب متعاون** | "مدرب متعاون" is the official Saudi academic classification for adjunct/guest lecturers. |
| **Account Verification** | توثيق الحساب | **توثيق واعتماد الهوية الأكاديمية** | Distinguishes social media blue checks from formal academic accreditation. |
| **Eastern Province / Al Khobar** | المنطقة الشرقية - الخبر | **المنطقة الشرقية — الخبر والظهران والدمام** | Reflects the tri-city academic corridor (KFUPM in Dhahran, IAU in Dammam, Prince Mohammad Bin Fahd Univ in Khobar). |
| **Spatial Discovery Map** | الخريطة التفاعلية | **الخريطة المكانية التفاعلية للفعاليات والمحاضرات** | GIS / spatial intelligence context. |
| **In-Person Attendance & RSVP** | التنقل الميداني / حجز مقعد | **الحضور الفعلي وحجز المقعد بالمدرج** | "المدرج" (Auditorium) and "الحضور الفعلي" (In-person presence) match university campus phrasing. |
| **Pitch Director Mode** | وضع المخرج للعرض التقديمي | **استوديو التحكم في البث المباشر (وضع العرض)** | "وضع المخرج" sounds like film production; "استوديو التحكم" accurately conveys live broadcast directorship. |
| **Governance & PDPL** | حوكمة المنصة والخصوصية | **حوكمة المنصة والامتثال لنظام حماية البيانات الشخصية السعودي (PDPL)** | Exact reference to the Saudi Data and AI Authority (SDAIA) Personal Data Protection Law. |

---

## 📐 4. RTL Layout Architecture & Overflow Prevention

### 4.1 Text Expansion Factors (English vs. Arabic)
Arabic text occupies **20% to 38% more horizontal width** than English due to cursive letter connectivity and dual-word compounds.

### 4.2 Layout Safeguards & Engineering Prescriptions

#### 1. Horizontal `Row` Wrapping and Flex Constraints:
* **Prescription:** Every text label inside a `Row` containing trailing icons, badges, or action buttons must be wrapped in `Expanded` or `Flexible` with `overflow: TextOverflow.ellipsis` and `maxLines: 1` or `maxLines: 2`.

#### 2. Directionality & Arrow Mirroring:
* **Defect:** `Icons.arrow_forward_rounded` always renders pointing to the right ($0^\circ$). In LTR (English), right means forward. In RTL (Arabic), right means **backward** and left means **forward**!
* **Prescription:**
```dart
Widget buildForwardArrow(BuildContext context, {double size = 16, Color? color}) {
  final isRtl = Directionality.of(context) == TextDirection.rtl;
  return Transform.scale(
    scaleX: isRtl ? -1.0 : 1.0,
    child: Icon(Icons.arrow_forward_rounded, size: size, color: color),
  );
}
```

#### 3. Typography & Cursive Ligature Integrity:
* **Defect:** `letterSpacing: 2.5` applied to Arabic strings splits connected letters (e.g. `"م ن ص ة"`), causing an unacceptable typographic defect.
* **Prescription:** Always condition `letterSpacing` by locale:
```dart
letterSpacing: context.locale.languageCode == 'ar' ? 0.0 : 2.0,
```

#### 4. Arabic Line-Height (Ascender/Descender Clearance):
* Arabic glyphs with dots and diacritics (مثل: ي، غ، ة، ط، ظ، أ، إ) require a baseline `height: 1.4` to `1.5` in `TextStyle`.

---

## 🗂️ 5. Master `ar.json` Key Additions

```json
{
  "common": {
    "cancel": "إلغاء",
    "save": "حفظ التغييرات",
    "back": "رجوع",
    "next": "التالي",
    "submit": "إرسال",
    "confirm": "تأكيد",
    "close": "إغلاق",
    "loading": "جاري التحميل...",
    "search": "بحث...",
    "decline": "رفض",
    "accept": "قبول",
    "delete": "حذف",
    "edit": "تعديل",
    "arrange": "ضبط وتوسيط",
    "change": "تغيير"
  },
  "auth_welcome": {
    "brand_title": "منصة البث التعليمي",
    "subtitle": "المنصة السحابية للبث المعرفي والتعليمي المباشر\nالمنطقة الشرقية — الخبر / الظهران / الدمام",
    "card_title": "ابدأ رحلتك التعليمية",
    "card_subtitle": "سجّل الدخول أو أنشئ حساباً عبر Google للوصول إلى البث المباشر، وحجز المقاعد بالقاعات، وأدوات المحاضرين.",
    "btn_google_signup": "إنشاء حساب عبر Google",
    "btn_google_login": "لديك حساب بالفعل؟ تسجيل الدخول",
    "divider_or": "أو",
    "btn_guest": "المتابعة كزائر مستمع (تخطي تسجيل الدخول)",
    "error_google_failed": "تعذر تسجيل الدخول عبر Google: "
  },
  "viewer_setup": {
    "title": "إعداد الملف التعريفي للمستمع",
    "subtitle": "اختر الاسم المستعار والصورة الرمزية لمشاهدة المحاضرات المباشرة والمشاركة في محادثة البث.",
    "avatar_section_title": "اختر الصورة الرمزية",
    "name_label": "اسم العرض في المنصة (إلزامي)",
    "name_hint": "مثال: فيصل الغامدي",
    "btn_enter": "الدخول إلى دليل البث المباشر",
    "error_name_empty": "يرجى إدخال اسم العرض للمتابعة."
  },
  "role_select": {
    "welcome_user": "أهلاً بك، {}!",
    "prompt_title": "كيف ترغب في تجربة منصة البث اليوم؟",
    "viewer_title": "أنا مستمع / باحث",
    "viewer_badge": "دخول فوري ومباشر",
    "viewer_desc": "استكشف المحاضرات التعليمية المباشرة، وتصفح الأرشيف العلمي، وتعرف على القاعات الجامعية في المنطقة الشرقية، وتفاعل في المحادثة.",
    "viewer_btn": "الدخول كمستمع",
    "streamer_title": "أرغب في الانضمام كمحاضر / صرح تعليمي",
    "streamer_badge": "يتطلب توثيق واعتماد",
    "streamer_desc": "أطلق البث المرئي والصوتي المباشر، واربط قنواتك على يوتيوب، وأدر مقراتك ومدرجاتك المتعددة، وتواصل مع طلاب المنطقة.",
    "streamer_btn": "تقديم طلب توثيق البث (معالج من 5 خطوات)"
  },
  "wizard_steps": {
    "step_progress": "الخطوة {} من {}",
    "step_completed": "{}% مكتمل",
    "btn_next": "الخطوة التالية",
    "btn_submit": "إرسال طلب التوثيق",
    "btn_back": "السابق",
    "org_title": "توثيق صرح تعليمي ({} من {})",
    "streamer_title": "توثيق محاضر أكاديمي ({} من {})",
    "step1_title": "الخطوة 1: الهوية والبيانات التعريفية",
    "step1_desc": "أدخل اسمك الكامل المعتمد، ومعرّف البث العام، ونبذة أكاديمية موجزة عن خبراتك.",
    "step1_name_label": "الاسم الكامل المعتمد *",
    "step1_name_hint": "مثال: د. فيصل بن عبدالله الغامدي",
    "step1_handle_label": "معرّف البث العام *",
    "step1_handle_hint": "مثال: faisal_ai@ أو dalilk_academy@",
    "step1_bio_label": "النبذة الأكاديمية والتعريفية *",
    "step1_bio_hint": "لخص بإيجاز خلفيتك العلمية، ومجالات تخصصك، وخبراتك في تقديم المحاضرات والدروس.",
    "step2_title": "الخطوة 2: الصور والهوية البصرية",
    "step2_desc": "ارفع صورتك الشخصية المعتمدة وغلاف القناة. تدعم المنصة جميع أبعاد الصور مع التوسيط والقص التلقائي.",
    "step2_banner_label": "غلاف القناة (تكيف وتوسيط تلقائي لجميع الأبعاد) *",
    "step2_banner_tap": "اضغط لرفع غلاف القناة (يدعم التوسيط والقص التلقائي)",
    "step2_avatar_label": "الصورة الشخصية / الرمزية *",
    "step2_upload_btn": "رفع صورة",
    "step2_arrange_btn": "ضبط وتوسيط الصورة",
    "step3_title": "الخطوة 3: الارتباط المهني وقناة يوتيوب",
    "step3_desc": "حدد ما إذا كنت تبث كمحاضر مستقل أو كصرح تعليمي، واربط قناة يوتيوب المعتمدة للبث.",
    "step3_entity_type": "نوع الكيان ومسار البث *",
    "step3_type_individual": "محاضر وباحث أكاديمي مستقل",
    "step3_type_individual_sub": "أستاذ جامعي، باحث، مدرب معتمد",
    "step3_type_org": "صرح تعليمي / أكاديمية / مركز",
    "step3_type_org_sub": "جامعة، أكاديمية تدريبية، مركز أبحاث",
    "step3_org_name_label": "الاسم الرسمي للصرح التعليمي / الأكاديمية *",
    "step3_org_name_hint": "مثال: أكاديمية دليل للتدريب والتعليم",
    "step3_affiliation_org": "المقر الرئيسي / الجهة التابعة (اختياري)",
    "step3_affiliation_ind": "الجامعة / الجهة الأكاديمية التابع لها *",
    "step3_affiliation_ind_hint": "مثال: جامعة الملك فهد للبترول والمعادن، جامعة الإمام عبدالرحمن بن فيصل",
    "step3_youtube_label": "معرّف أو رابط قناة يوتيوب المعتمدة *",
    "step3_yt_required": "إلزامي: مثلاً https://www.youtube.com/@handle أو handle@",
    "step3_yt_invalid": "يجب أن يبدأ الرابط بـ https://www.youtube.com/@ أو handle@",
    "step3_yt_checking": "جاري التحقق من وجود القناة على يوتيوب...",
    "step3_yt_verified": "✓ تم التحقق من القناة على يوتيوب ({})",
    "step3_yt_format_ok": "صيغة الرابط صحيحة (سيتم اعتماد البث من الإشراف)",
    "step3_categories_title": "التخصصات والمجالات العلمية الرئيسية ({}/6) *",
    "step3_add_custom_field": "إضافة تخصص جديد",
    "step3_add_dialog_title": "إضافة تخصص أكاديمي مخصص",
    "step3_tags_title": "الوسوم العلمية (دليل الاكتشاف)",
    "step3_5_title": "الخطوة 3.5: إدارة كادر الصرح التعليمي",
    "step3_5_desc": "أضف المحاضرين والمدربين المعتمدين الذين سيبثون تحت مظلة هذا الصرح التعليمي.",
    "step3_5_roster_count": "المحاضرون التابعون ({})",
    "step3_5_add_btn": "إضافة محاضر للكادر",
    "step3_5_dialog_title": "إضافة محاضر لصرح تعليمي",
    "step3_5_dialog_add": "إضافة إلى الكادر",
    "step4_title_ind": "الخطوة 4: المقر الميداني وبيانات التواصل",
    "step4_title_org": "الخطوة 4: المقرات والمدرجات وبيانات التواصل",
    "step4_desc": "حدد المقر الجامعي أو المدرج الذي يمكن للمستمعين الحضور إليه ميدانياً أثناء المحاضرة.",
    "step4_hq_badge": "المقر والمدرج الرئيسي",
    "step4_pinpoint_btn": "تحديد على الخريطة",
    "step4_venue_org_label": "اسم المدرج / المبنى بالمقر الرئيسي *",
    "step4_venue_ind_label": "وصف القاعة أو المدرج الجامعي",
    "step4_add_branch_btn": "إضافة فرع / مقر إضافي",
    "step4_phone_label": "رقم الهاتف / الواتساب الرسمي للتواصل *",
    "step4_phone_pref": "قناة التواصل المفضلة",
    "step5_title": "الخطوة 5: مراجعة البيانات وميثاق البث",
    "step5_desc": "تأكد من صحة بطاقة المحاضر ووافق على ميثاق البث الأكاديمي قبل إرسال الطلب للاعتماد.",
    "step5_terms_modal_org": "الشروط والأحكام الخاصة بالمؤسسات والأكاديميات",
    "step5_terms_modal_ind": "الشروط والأحكام الخاصة بالمحاضرين الأكاديميين",
    "step5_charter_title": "ميثاق وحوكمة المنصة (الإصدار {})",
    "step5_agree_btn": "قرأت ووافقت على الشروط والميثاق",
    "step5_agree_checkbox": "أوافق على ",
    "step5_agree_terms_link": "الشروط والأحكام المعتمدة",
    "step5_agree_standards": " والمعايير الفنية للبث الأكاديمي."
  },
  "wizard_pending": {
    "title": "تم إرسال طلب التوثيق بنجاح!",
    "subtitle": "طلبك معروض حالياً على الإدارة المركزية والتحقق الأكاديمي.",
    "step1_title": "إجراءات التحقق والمراجعة",
    "step1_desc": "يقوم فريق الإشراف بمراجعة بيانات يوتيوب، والتوافق الأكاديمي، وبيانات المدرج الجغرافي.",
    "step2_title": "تنبيه فوري داخل التطبيق",
    "step2_desc": "ستصلك إشعارات وتحديثات فورية عبر التطبيق والبريد فور اعتماد شارة المحاضر الموثق.",
    "step3_title": "إمكانية الاستفادة الكاملة كمستمع",
    "step3_desc": "يمكنك متابعة كافة المحاضرات المباشرة، وحجز المقاعد، واستكشاف الخريطة أثناء فترة المراجعة.",
    "btn_explore": "استكشف المنصة كمستمع أثناء انتظار الاعتماد"
  },
  "affiliation_modal": {
    "title": "الانضمام إلى صرح تعليمي",
    "subtitle": "قدم طلبك للبث تحت مظلة أكاديمية أو جامعة معتمدة واستفد من مدرجاتها المتعددة.",
    "select_org": "اختر الصرح التعليمي المستهدف *",
    "proposed_role": "المسمى والتخصص المقترح بالمنظمة",
    "proposed_role_hint": "مثال: مدرب آيلتس أول / باحث ذكاء اصطناعي",
    "intro_note": "النبذة التعريفية ورسالة الانضمام *",
    "intro_note_hint": "عرّف بخبراتك والمحاضرات والمدرجات التي ترغب في تقديمها والتعاون بشأنها.",
    "submit_btn": "إرسال طلب الانضمام",
    "submitted_toast": "تم إرسال طلب الانضمام للصرح التعليمي بنجاح ✓",
    "error_select_org": "يرجى اختيار صرح تعليمي للانضمام إليه.",
    "error_note_empty": "يرجى كتابة رسالة تعريفية موجزة بمحاضراتك."
  },
  "live_studio": {
    "dialog_title": "استوديو التحكم في البث المباشر",
    "dialog_tag": "الاستوديو",
    "dialog_subtitle": "البث المباشر عبر OBS Studio المحلي أو ربط يوتيوب لايف",
    "status_live": "🔴 بث مباشر نشط الآن",
    "status_offline": "⚪ البث المكتبي غير متصل حالياً",
    "status_live_desc": "يتم إرسال إشعار فوري لجميع المتابعين على الخريطة والدليل",
    "status_offline_desc": "اضغط لبدء البث والظهور المباشر على الخريطة التفاعلية",
    "btn_go_live": "إطلاق البث المباشر",
    "btn_end_live": "إنهاء البث المباشر",
    "toast_rtmp_set": "تم ضبط وجهة RTMP المحلية بنجاح: {}",
    "toast_yt_set": "تم ضبط وجهة يوتيوب لايف بنجاح لمعرّف الفيديو: {}"
  }
}
```
