# iPhone screenshot shot list

Plan only; no screenshots have been fabricated or reused from Android. Capture the actual iOS app after M2/M3 against approved review fixtures, then verify the submission build has the same UI. Native visual evidence is currently absent.

| Size class requested | Preferred portrait capture | Other currently accepted portrait size(s) |
|---|---|---|
| 6.9-inch | 1320 × 2868 | 1260 × 2736; 1290 × 2796 |
| 6.5-inch | 1242 × 2688 | 1284 × 2778 |

Apple currently accepts 1–10 JPEG/JPG/PNG screenshots per set with no alpha/transparency. Its reference allows the 6.5-inch requirement to be covered by a supplied 6.9-inch set; the plan still prepares both sets. Use the device/runtime whose native pixel dimensions match a supported size; do not stretch an Android capture or invent an iPhone frame. No iPad set for device family 1.

## Capture the same order in English and Arabic

| # | Actual app surface | English caption proposal | Arabic caption proposal | Fixture / acceptance |
|---|---|---|---|---|
| 1 | Discovery with real channel/content cards | Discover educational broadcasts | اكتشف البثوث التعليمية | Approved titles/images; no fabricated LIVE status |
| 2 | Recording/player room with controls | Watch educational lectures | شاهد المحاضرات التعليمية | Actual YouTube playback; optional test chat without real personal data |
| 3 | Channel page / recordings or playlist | Explore lectures and playlists | تصفح المحاضرات وقوائم التشغيل | Public approved replay list, loaded successfully |
| 4 | Tri-city map with a selected venue | Find lecture venues | اكتشف أماكن المحاضرات | Public venue point/name in Khobar, Dhahran or Dammam; no private live GPS |
| 5 | Followed channels / saved library | Return to your saved content | عد إلى المحتوى المحفوظ | Real test-account follow/bookmark state |
| 6 | Organization public page | Explore participating organizations | تعرف على المؤسسات المشاركة | Only if its visibility/pilot is enabled and metadata retains the organization paragraph |
| 7 | Native welcome / language selection | Choose Arabic or English | اختر العربية أو الإنجليزية | Native Apple/Google buttons and correct RTL; no claim that an unconfigured provider succeeded |
| 8, optional | Settings privacy/legal controls | Manage your account and privacy | أدر حسابك وخصوصيتك | Current policy, support and deletion controls; no credentials/private profile data |

Capture up to eight if each adds useful evidence; choose the strongest set within Apple's limit. Captions are optional and must match the captured feature. Save source images without overlays first. If a live stream is not running, capture a recording and label it accurately.

## File and QA record

Suggested filename: `<language>_<size-class>_<shot-number>_<surface>.<png-or-jpg>`, e.g. `ar_6-9_01_discovery.png`. Record commit/build, device or simulator model, OS/runtime, native pixel dimensions, language, fixture and date. Store verification evidence under `brief/evidence/<date>/ios-sim/`; final selected assets can be copied into this store folder once genuinely captured.

Check safe areas, readable Arabic/RTL, text scaling, image loading, no debug banner or exception UI, consistent truthful status, no stream key/account credentials and no accidental private messages. Validate encoded dimensions and lack of alpha rather than relying on the filename. Retake after a material UI change.

Source: [Apple screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/), retrieved 2026-10-17; sizes/format limits must be rechecked at submission.

