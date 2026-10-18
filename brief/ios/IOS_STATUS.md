# iOS build status

Plan: `IOS_PLAN_V2.md`. History: `IOS_PROGRESS.md`. Decisions/verdicts: `IOS_LEDGER.md`.

## Snapshot

| Field | Value |
|---|---|
| Updated | 2026-10-18, Codex; audit follow-up findings 1, 2, 6–10 (see IOS_PROGRESS.md) |
| Track | A, Windows; Mac not available |
| Resume | Hard stop: physical Mac or real CI log for W13 / M1–M3 |
| Progress | 18 / 20 work orders complete |
| Evidence | W19/W20 and publisher Dart E1 mocked/host; native shell, Apple capability and phone media E0. No native compile/run, E2, E2S, E3 or E4. |
| Mac / iPhone | Mac arriving, ETA unknown; iPhone availability unknown |
| Apple enrollment | Deferred by owner, D4; Debug/free-team builds must exclude paid capabilities |
| Usage policy | No cap; owner update 2026-10-17. Historical meters are informational. |
| Latest checks | Audit follow-up: flutter analyze --no-pub 0 issues (48.8s); full flutter test --reporter expanded 1,165 passed / 0 failed / 0 skipped (05:52); Edge npm test 16/16; python -B project/ios/Publisher/test_configure.py 4/4; doctor fixtures 6/6 and Bash syntax passed; 1,897 EN/AR keys symmetric. 41 new pgTAP assertions written, not executed. Android/web tracked diff empty. |

## Work orders

| WO | Title | Status | Commit selector or hash | Checkpoint |
|---|---|---|---|---|
| W1 | Generate ios/ | DONE | 5605451 | C1 |
| W2 | Identity | DONE | 88c65a0 | C1 |
| W3 | Info.plist | DONE | 3214951 | C2 |
| W4 | Privacy manifest | DONE | d6e6278 | C2 |
| W5 | URL scheme and deep links | DONE | 5c4dcbd | C2 |
| W6 | Firebase inert on iOS | DONE | 72802e5 | C2 |
| W7 | WKWebView / YouTube audit | DONE | 580dc75 | C2 |
| W8 | Branch audit and gating | DONE | 0123921 | C3 |
| W9 | Sign in with Apple | DONE | f715230 | C3 |
| W10 | iOS-override tests | DONE | 4fa027b | C3 |
| W11 | App Review compliance | PARTIAL — public delivery / native verification | 4923c13 | C3 |
| W12 | Codemagic config | DONE | d35721d | C4 |
| W13 | Compile-fix loop | WAITING — real CI/Mac log | a3da856 | C4 |
| W14 | App Store pack | DONE | d9f33e2 | C4 |
| W15 | Truth reconciliation | DONE | 5f250f3 | C4 |
| W16 | Mac setup runbook | DONE | 6b667f4 | C4 |
| W17 | Phone publisher | DONE | 63b288f; c4c81c2 (native); afd862d (review) | Track B |
| W18 | Push spec | DONE | bd442c8 | Track B |
| W19 | Apple deletion revocation | DONE | d5e4b6b | §12 |
| W20 | Legal drafts / public gaps | DONE | a0ebf8d | §12 |
| M1–M5 | Mac track | WAITING for physical Mac | | C5/C6 |

Resolve a commit selector with `git rev-parse '<selector>'`.

## Evidence by feature

| Feature | Level claimed | Limit |
|---|---|---|
| iOS native shell | E0 | Implemented, not run on iOS; CocoaPods, bundle sa.hadayah.streamerapp, target 15.0, iPhone only. |
| iOS identity | E0 | Implemented, not run on iOS. Opaque 1024px icon; dark launch uses AppTheme.media #243536. |
| Discovery/watch/chat/map/profile shared Dart | E1 host baseline | Windows tests only; no iOS runtime proof. |
| WKWebView playback | E0 | Existing settings audited against official WKWebView 3.25.1 source. Inline/autoplay/JS/referrer/runtime behavior unverified on iOS. |
| Google redirect | E0 | Custom scheme registered; app_links owns auth callback. Hosted allowlist and cold/warm return unverified. |
| Sign in with Apple | E1 host exchange tests; E0 native capability | Native button + nonce exchange implemented; Release/Profile entitlement only. Paid provider/device flow deferred; Debug has no entitlements. |
| Phone publishing | E0 native / E1 mocked Dart | Implemented, not run on iOS. Default-off gate and direct-entry permission guard; explicit SwiftPM opt-in, actor capture/static IDR/background intent/drop detection; Dart owns bounded authorization/retry with transport-only pause. Native compilation and E3 matrix pending. |
| Push | E0 spec; E1 host exclusion | W18 spec complete, ESC-4 future backend migration. iOS Firebase remains disabled; no APNs/plist/background change and no native delivery proof. |
| Location and gallery permissions / native localization | E0 | Foreground location/gallery for default viewer. Experimental alternate publisher plist adds camera/microphone/audio mode only on opt-in; no native permission proof. [AUDIT P1 fixed 2026-10-18: purposes moved to opt-in Runner/PublisherStrings, swapped by configure.py; viewer strings carry only name/location/photo.] |
| App privacy manifest | E0 | Default viewer: 11 linked functionality data types, no tracking; reasons CA92.1/C617.1. Opt-in publisher variant adds AudioData (12 rows); video extends PhotosOrVideos. Inactive until flag on; packaged report unverified. |
| HTTPS organization invitations | Deferred | Open in browser. No Associated Domains entitlement or non-auth link consumer; future owner plan in OWNER_STEPS_IOS.md. |
| iOS channel connection | E1 host guard | UI notice plus service rejection before backend access. Android/web flow preserved; no iOS OAuth channel flow. |
| iOS platform adaptation tests | E1 Windows target-platform override | Apple iOS/Android EN/AR matrix, consent/error/cancel/paused signup, channel UI guard, Apple Maps/fallback, actual provider ios identity path. No native plugin runtime proof. |
| App Review legal / UGC / deletion | E1 host UI; submission BLOCKED | W19 revocation source E1 mocked; W20 complete bilingual legal draft/readers E1. Counsel approval, hosted legal record/public-page deployment, SQL/provider/device behavior and submission remain pending. |
| Pre-Mac compile workflow | E0 configuration; E1 Windows baseline | Manual-only Codemagic YAML, Flutter 3.41.2, unsigned release/example defines. No CI job, no E2 claim. |
| App Store pack | E0 drafts | Seven files: EN/AR copy, privacy mapping, age questionnaire, review notes and both requested screenshot size plans. No images, account form or upload; W11 blockers carried forward. |
| Mac handoff | E0 runbook / host fixtures | M1–M3 doctor command is non-fatal; checked Xcode iOS/CocoaPods rows are required. Six host fixtures and Bash syntax check passed. Version/source/signing/build/matrix gates retained; no Mac execution. |
| Apple deletion revocation | E1 host/mocked; SQL source/tests only | W19 proof binds updated_at, last_sign_in_at and SHA-256 identity-data hash. Current post-sheet session token and server flag precedence covered by mocked Dart tests. 41 pgTAP assertions written for guard/grants/expiry/stale proof/mixed providers; unexecuted. No SQL/hosted/provider/iPhone proof. |

## Blockers and owner actions

| ID | Who | Action |
|---|---|---|
| O1 | Owner | Paid Apple enrollment deferred (D4). Needed for Apple capability/device testing, TestFlight and App Store submission. |
| O2 | Owner | Provide Mac access when it arrives and an iPhone when available; follow MAC_SETUP.md. Owner handles local account/license/trust/define-file steps. No paid enrollment needed for Simulator/unsigned build or free-team Debug device install. |
| O3 | Owner / Claude | W20 in-app draft complete at E1. Owner/counsel approve; Claude handles iOS public copy gaps and owner redeploys the existing committed pages (5991d38) before SPA fallback. PUBLIC_PAGES_GAPS.md and OWNER_STEPS_IOS.md have concrete deltas and content acceptance. No web edits/live access this round. |
| O4 | Owner | Verify existing Supabase OAuth callback allowlist, later run cold/warm Google return; exact steps in OWNER_STEPS_IOS.md. No hosted settings changed. |
| O5 | Owner / scoped future work | After paid enrollment: host AASA, implement invite link consumer, attach Associated Domains only to paid builds and verify on device. Deferred per D4. |
| O6 | Owner, later paid activation | Apple App ID/capability and Supabase Apple provider setup; native bundle ID audience, optional browser Services ID/key/secret rotation. Exact deferred steps in OWNER_STEPS_IOS.md. |
| O7 | Owner, backend deployment / later paid verification | W19 source complete; ESC-2 resolved at E1 mocked. Audit/deploy only the new function/secrets/migration, verify SQL guard/grants and real revocation/deletion with paid iPhone. OWNER_STEPS_IOS.md contains commands, secret names and ordered acceptance. |
| O8 | Owner, optional before Mac | Push and manually run Codemagic ios-compile-check; supply non-secret first-error logs or successful native build evidence. CI_OWNER_STEPS.md and OWNER_STEPS_IOS.md contain exact steps. Skip if Mac available. |
| O9 | Owner, at submission prep | Confirm actual privacy purposes/provider data, age/content answers, rights holder/content rights, hosted flags and review accounts; capture genuine iOS screenshots and enter metadata only after W11/native/paid gates. OWNER_STEPS_IOS.md and store/README.md have steps. |
| O10 | Owner / Mac + iPhone | W17 source ready E0 native/E1 mocked; keep flag off. First run viewer M1–M3, then follow IOS_PUBLISHER_HANDOFF.md opt-in/rollback and E3 media matrix. No paid capability needed for free-team Debug camera/mic; do not ship before E3/privacy review. |
| O11 | Owner / Claude, deferred Track B | ESC-4: decide separate push migration/implementation later. Both backend platform validations and both client registration labels need ios; APNs/Firebase setup needs paid owner action. IOS_PUSH_SPEC.md and OWNER_STEPS_IOS.md contain scope and acceptance tests. W18 spec is complete. |

Account-gated steps do not block unrelated Windows work.

## Next three steps

1. Owner transfers the intended master commits plus manager plan/ledger documents to the Mac when available, then runs MAC_SETUP.md M1–M3 with the publisher off. A supplied CI/Mac log takes priority under W13.
2. Owner audits/deploys W19 function/secrets/new migration and verifies SQL/grants/provider deletion; owner/counsel/Claude approve and deliver matching W20 legal/public text.
3. After viewer compilation, optionally activate W17 per IOS_PUBLISHER_HANDOFF.md and execute the iPhone E3 matrix. Paid Apple sign-in/distribution and deferred push remain separate owner gates.

## Audit notes and verification limits

- C1 (W1/W2) and C2 (W3–W7) await Claude audit. No iOS compilation or evidence promotion.
- Initial SHA-256 inventory was written to a sandbox temporary directory and could not be recovered after that process ended. Generation has a clean tracked Android/web diff; the persistent post-generation inventory covers 90 files (77 Android, 13 web). Do not claim a pre-generation SHA comparison.
- Flutter create also emitted an unrelated sample widget test and replaced web/Windows metadata entries. The new sample was removed and original metadata entries restored before testing.
- flutter_launcher_icons 0.14.4 rewrites unrelated asset-symbol settings in project.pbxproj. Restored to W1 during W2; inspect that diff after future regeneration.
- W8 widget tests must reset debugDefaultTargetPlatformOverride in the widget body finally, in addition to tearDown; Flutter verifies foundation invariants before ordinary tearDown. Keep this pattern in W9/W10.
- Owner removed every usage cap and soft stop on 2026-10-17. Do not interpret older meter/cap text as a stop condition.
- Apple plugin 8.1.0 is the newest solver-compatible version for Flutter 3.41.2/Dart 3.11.0; only three new lockfile entries, no existing package updates. Native/plugin compilation remains pending.
- W10 found the Arabic Google button was 61px high. Apple is now 64px (AppTheme tokens); the EN/AR test checks it remains at least as tall and fully localized. Android auth UI remains unchanged.
- C3 scoped sweep is committed for audit; W11 remains PARTIAL because ESC-2/ESC-3 are real submission blockers. Continue unrelated Windows work.
- W13 has zero native compile attempts and no real failure log. It is waiting for O8 or Mac access; do not preemptively patch/remove native plugins or award E2.
- W15 withdrew ADR-006's universal iOS playback claim, corrected its WKWebView API description, labeled historical Dart/SQL evidence separately and added the HTTPS invite limitation in all four allowed documents. Native E0 remains.
- C4 Windows artifacts are ready for audit. W13 native compilation is still blocked; no E2 inferred from CI YAML, store copy, truth correction or runbook.
- 2026-10-18 round follows §12: W17's W11 dependency withdrawn; W19 backend source authorized only for Apple deletion; W20 legal fallback authorized; push migration remains forbidden.
- W19 fixed a test-fixture issue: installed PostgREST expects http.Response.request. Mock responses now carry request metadata. Unrelated AppProvider formatter churn was removed; only deletion logic/blocker names changed.
- ESC-2 resolved at E1 mocked/source scope. Database proof validity is ten minutes and tied to current identity version; SQL guard/grants are unexecuted and real provider/device behavior remains pending.
- W20 complete default terms/guidelines/privacy at v1.1.0-ios-draft, marked for counsel review. No unverified PDPL compliance/instant deletion/ad-free promises in the draft text. [AUDIT P2 fixed 2026-10-18: settings.view_privacy/view_privacy_subtitle relabelled neutrally in en/ar.] Hosted legal content not overwritten; public source pages untouched.
- W17 §12 complete as source: Dart commit 63b288f, separate native dependency/config/media commit. SwiftPM opt-in only because HaishinKit 2.x discontinued CocoaPods; Flutter plugins stay CocoaPods/3.41.2. Default viewer has no SDK package/product references or generated flag. pubspec.yaml pins flutter.config.enable-swift-package-manager false; the explicit Runner publisher dependency opt-in is independent.
- W17 native self-review corrected ACK/event timing, exact orientation argument, retry quality retention, conditional permission macros and stale-operation checks. SDK loggers discard credential-bearing diagnostics; no compiler warning suppression. These are source checks, not compilation/runtime proof.
- W17 review: native commit c4c81c2 remains separate from Dart. Transport loss/retry-only watchdog pause retains capture during Dart's bounded authorization episode; user stop, revoked authorization and exhaustion fully release it. Background eligibility is an implementation intent requiring E3, not observed survival.
- Direct iOS phone setup now rejects unavailable/default-off capture before camera/microphone permission calls. Its narrow error screen wraps in EN/AR. Test fixture uses actual physicalSize/devicePixelRatio (known repository isolation issue); no rendering exceptions suppressed.
- All three optional Windows follow-ups completed: native/config self-review, script-like M1–M3 sequence, and RECON section 3 re-read (62 matching platform-site lines). Both production player factory callers select YouTube; the legacy localRtmp adapter is not a shipped alternate iOS path.
- Mac sequence was Bash syntax-checked only. It creates pending matrix rows, never automatic device passes. E2/E2S/E3 remain pending. Historical progress entries are preserved; later W17 review entries clarify bounded capture retention and direct-entry protection.

## Open escalations

- ESC-3 public half: W20 in-app draft/source resolved at E1; Claude/owner handle copy review and deployment of existing public pages. Counsel/hosted approval pending.
- ESC-4 (W18): future push implementation needs a separately authorized backend migration plus owner APNs/Firebase setup; specification complete, no backend changes.

## Manager audit follow-up 2026-10-18

Claude's original VERDICT and VERDICT follow-up remain in IOS_LEDGER.md. P1/P2 were fixed in d336e1f. This builder work order addresses findings 1, 2, 6, 7, 8, 9 and 10, with fresh host results recorded above and in IOS_PROGRESS.md. Evidence stays at E1 for mocked Dart/Edge checks; SQL and native execution remain unverified.

- Findings 1/2: identity version strengthened in the explicitly authorized, unapplied W19 migration; 41 pgTAP assertions added but not run. Edge code still passes the version through unchanged. The owner must run the local SQL suite before deployment.
- Findings 6/7: use the current session token after the Apple sheet and prefer an explicit server revocation flag. Tests cover rotation, logout, account switch, conflicting flags and legacy fallback.
- Findings 8/9/10: privacy §9 names Download My Data / تنزيل بياناتي; doctor output gates only the iOS rows; Flutter plugin SwiftPM is pinned off.
- Finding 3 remains an owner decision about support/admin deletion of Apple-linked accounts. Findings 4/5 remain Mac/iPhone work; no native media change in this work order.
- P3 remains an owner action: commit the intended manager plan, ledger and prompts for the Mac. This work order leaves those pending files untouched.
- W19 SQL execution/deployment, real Apple revocation, Mac/iPhone media, counsel/publication and submission gates remain pending. No evidence level is promoted.
