# Apple privacy nutrition-label draft

For the default iOS viewer build, not the Android publisher/push build. Source: store/data_safety.md plus the W3/W4/W6/W8 implementation. No App Store form has been submitted. Treat this as the reviewable mapping, not a claim that third-party/native behavior has been verified.

Screening: **Yes, data is collected.** Do not select Data Not Collected. The eleven rows below match Runner/PrivacyInfo.xcprivacy. Draft purpose is **App Functionality**, linked to the user **Yes**, tracking **No**, for every row. Optional user actions remain declared; choosing not to sign in is not a blanket disclosure exemption.

| Apple data type | iOS viewer collection / code source |
|---|---|
| Name | Account/profile names; Apple or Google identity and optional applications |
| Email Address | Account email, including Apple's private relay address when chosen |
| Phone Number | Optional broadcaster/application contact, even though iOS phone publishing is deferred |
| Physical Address | Organization/venue/application address fields; conservative W4 declaration |
| Precise Location | Foreground location can set a venue pin; only a confirmed point is saved, and may coincide with the device position |
| Emails or Text Messages | Live chat, message reports and their associated sender identifiers |
| Photos or Videos | User-selected avatar/banner/application images; this category is declared for photos, not iOS camera broadcasting |
| Other User Content | Profile/bio, organization/academic text, applications and schedules |
| User ID | Supabase profile/account IDs and related authorization/consent records |
| Device ID | Local device identity/primary-device state and viewer presence; iOS Firebase/push-token collection is disabled |
| Product Interaction | Follows, bookmarks, reminders/schedules, views/presence and feature interactions |

## Differences from Play answers

- No iOS microphone/phone-camera media collection in the viewer release; do not copy the Android live-video/voice-recording upload answers. Watching a video is distinct from collecting the viewer's microphone recording.
- No iOS FCM token/APNs registration is enabled. Do not justify Device ID using active iOS Firebase messaging. W6 verifies the client guard; native SDK launch remains untested.
- iOS directions prefer Apple Maps, with Google HTTPS fallback. Supabase, YouTube, map/tile/image services and their actual disclosures still require review; Play's service-provider/shared exemption is not an automatic answer to Apple's tracking question.
- Tracking No is the app's current declaration and implementation intent. Confirm the final embedded-player/SDK practices; absence of an advertising SDK does not establish a third party's collection behavior.

## Owner decisions before entering the form

1. Compare this mapping with the signed build's Xcode privacy report and network/provider inventory, preserving the same categories and purposes in the app manifest. Do not submit while the W11 public/in-app policy content is inconsistent.
2. Review App Functionality versus Analytics for Product Interaction: AdminDatabaseService.saveAnalytics writes platform_analytics, even though there is no analytics SDK. If that use meets Apple's Analytics purpose, authorize a manifest/form purpose update. No purpose was silently changed in W14.
3. Review third-party retention of searches, connection metadata, video interactions and any advertising data. Declare any additional category/purpose that the final assessment requires; do not infer non-collection from missing app-side persistence.
4. Confirm whether external, user-initiated support email meets every optional-disclosure criterion. If it does not, assess Customer Support and linked-email treatment; an external Mail button is not an automatic exemption.
5. Confirm any sensitive information actually solicited/retained by profile, organization or content workflows, and provider/backup retention. No such data or hosted records were inspected here.
6. Validate real disposable-account deletion, uploaded-file removal and surviving audit records, plus Apple authorization revocation (ESC-2). There is no inspected table-wide retention schedule; do not promise a deletion period or complete third-party erasure without evidence.

Source: [Apple app privacy details](https://developer.apple.com/app-store/app-privacy-details/) (retrieved 2026-10-17) for categories, linked/tracking/purpose questions and optional disclosure; the row assessments come from repository data flows. The owner completes the account form after reconciliation.

