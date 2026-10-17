# iOS App Review checklist

Snapshot: 2026-10-18. Viewer-first scope, iPhone, iOS 15+. This is a source/Windows-test sweep. No iOS build, device behavior or App Review approval is claimed.

**Submission blocked:** native Apple sign-in is not activated/tested; W19 Apple deletion source passes mocked E1 checks but awaits deployment and real revocation; hosted policy/support delivery and disclosures remain pending (ESC-3). The physical Mac/iPhone and paid distribution steps remain outstanding.

| Guideline / check | Result | Evidence and limit |
|---|---|---|
| 1.2 — filtering | Present in shared path; iOS host test | LiveChatController maps server banned-keyword refusal to a non-retryable failure. Existing keyword enforcement is in the backend, read only here; hosted enforcement not retested. |
| 1.2 — report, block, moderation | Reachable in iOS override | live_broadcast_screen.dart:2005 opens showChatMessageActionsSheet on long press. EN/AR tests find viewer report/block and moderator mute. Controller reportMessage/blockUser/muteUser use existing server paths; no iOS-only exclusion. No new live moderation proof. |
| 1.2 — published contact and response | Contact added; owner operations needed | Native iOS consent and legal settings show AppIdentity.supportEmail and a mail action. Missing Mail opens a selectable-address dialog. Owner must monitor reports/support and demonstrate timely response with the review account. |
| 5.1.1(v) — in-app deletion | Host UI reachable; W19 deployment/device pending | Settings account/data includes PrivacySettingsSection(dangerOnly: true). EN/AR tests exercise confirm, cancel and a refused request. AppProvider.deleteOwnAccount prepares deletion, removes owned Storage objects, invokes delete_own_account and signs out. No real deletion executed here. |
| Apple identity revocation on deletion | ESC-2 resolved at E1 mocked source; deployment/device pending | W19 adds native reauthorization, authenticated code exchange, signed identity/nonce binding, refresh-token revocation and service-only identity-version proof. New auth.users deletion guard refuses without fresh proof. 12 Flutter and 16 Node tests pass; production index Deno type check passes. SQL unexecuted, no hosted access or real Apple revoke/delete. |
| Deletion restrictions | Owner review required | Existing RPC refuses banned users, active broadcasts, organizations with other active members, or remaining files. Owner/Claude must review these restrictions against account-deletion requirements; a test of the UI does not validate retention policy. |
| 4.8 — equivalent sign-in | Dart/nonce E1; native capability E0 | iOS-only localized Apple button, equal/full-width placement; Arabic prominence corrected in W10. Consent precedes credentials; cancellation is quiet; generic failures leave Google usable. Raw nonce → SHA-256 → Apple → Supabase ID token covered by mocked exchange tests. Release/Profile entitlement only; Debug has none. Paid provider/device authentication deferred. |
| 5.1.1 — policy access | E1 in-app draft; counsel/hosted approval pending | W20 supplies complete EN/AR default terms/guidelines/privacy at v1.1.0-ios-draft, marked for counsel review. Apple/relay identity, data/purposes, permissions, providers/YouTube, retention/copies, deletion/revocation and support covered. Existing reader tests exercise both languages. Hosted legal text unchanged; owner must approve/publish consistent content. |
| 5.1.1 — public policy URL | Deployment pending — ESC-3 public half | W11 historical live result was bootstrap/old branding. Owner confirms committed pages were not redeployed; local pages already have Hadayah branding. W20 PUBLIC_PAGES_GAPS.md lists Apple/iOS copy deltas for Claude and deployment acceptance. No web edits or live access this round. HTTP 200 alone is insufficient. |
| Purpose strings / privacy declarations | E0 written | W3 foreground location/gallery only; W4 privacy manifest declares the viewer data inventory and required reasons. Native prompts and packaged privacy report unverified. No ATS exception or tracking request added. |
| Android / Google Play wording | Clear for viewer scope, source audit | Four Android-specific catalog entries occur only in gated phone/Studio content, or are unused. W8 blocks the entire native iOS Studio entry. No Google Play/store string found in shared viewer UI. Google remains a provider name; iOS secondary login now explicitly says Google rather than implying every account. Hosted/dynamic legal wording needs owner review. |
| Payments / 3.1 | No purchase flow found | No IAP, billing, checkout or payment SDK/call in pubspec or shared Dart. Existing reservations/RSVP are not payment. YouTube content may contain provider-served ads; no ad-free claim is made. Recheck if monetization is introduced. |
| 2.1 — complete actions | Viewer paths audited; native proof pending | No empty onPressed/onTap closures found in shared lib. Unfinished phone/OBS/channel entry points show the W8 notice. Network/auth failures use existing overlays/errors. Validate every viewer action, layout, playback, permission and link on the Mac and iPhone before submission. |
| HTTPS invitations | Known limitation | Links open the browser. No Associated Domains entitlement or non-auth invitation-link consumer. W5 owner plan is deferred; do not claim native universal-link support. |
| Review access / metadata | Owner gate | Provide a working non-privileged review account through App Store Connect only, a live/replay fixture and functioning backend. Do not place credentials in repo docs. W14 contains metadata/review-note drafts; screenshots must be genuine iOS captures. |

## Test evidence

- W9: four mocked native credential/HTTP tests cover matching fresh nonces, missing token/capability and cancellation.
- W10: fourteen new platform/UI tests plus existing three viewer gates. Full suite 1,130 pass; analyzer 0.
- W11: eleven new compliance tests cover EN/AR pre-auth policy/support, settings reader, deletion confirmation/refusal, viewer report/block, moderator mute, Android contact exclusion and keyword-failure classification. Focused W11 + W10: 25/25 pass. Final full-suite result is recorded in IOS_PROGRESS.md.
- W19: 12 mocked Flutter deletion tests and 16 mocked Node Edge/crypto tests; Deno 2.9.6 type check passed. SQL migration and real Apple/provider/deletion behavior are unverified.
- These tests prove host Dart behavior and reachability, not iOS OS/plugin behavior, hosted RLS, a real account deletion or successful moderation operations.

## Source references

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), retrieved 2026-10-17: UGC controls/contact, equivalent login, policy access, deletion and complete submission expectations.
- [Apple account deletion guidance](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion), retrieved 2026-10-17.
- [Apple Sign in with Apple token revocation](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens), fetched through Context7. This endpoint takes an access/refresh token and server-held client secret, not an identity token.
- [url_launcher official README](https://github.com/flutter/packages/blob/main/packages/url_launcher/url_launcher/README.md), fetched through Context7: direct launchUrl with failure fallback; scheme queries are for canLaunchUrl, which the new contact action does not call.
- Repo: project/lib/core/providers/app_provider.dart (deleteOwnAccount); project/lib/features/admin/models/terms_and_conditions_model.dart (default legal text); supabase/migrations/20261015172851_data_rights_export_and_deletion.sql:87 (read only).
- Live-page probe: privacy.html and about.html SHA-256 A0D5D6570ED2976719C13B3ABBBAAE44FB486CE4BF381F529A37C77B56918191, identical to /. delete-account.html SHA-256 044B783EB9CCCA37E9B25911FD6EB32B3E2050337BEF61A4C97F63B2B0ACA9FF. All returned HTTP 200. This is delivery evidence, not legal adequacy.

