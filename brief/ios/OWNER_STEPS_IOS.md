# Owner iOS actions

Updated 2026-10-17, W5. Follow `IOS_PLAN_V2.md`. Paid enrollment remains deferred by D4. The Windows builder continues around account actions. Never put credentials, callback tokens or signing material into this file, logs or Git.

## Now, without paid enrollment

### Verify the existing Google OAuth return allowlist

1. Owner opens the existing Supabase project in its dashboard, then Authentication > URL Configuration.
2. Check Additional Redirect URLs includes exactly `sa.hadayah.streamerapp://login-callback`. This is the existing Android production scheme, so it may already be present. Preserve every existing Android/web/test entry and the Site URL. If absent, add only this callback and save.
3. Keep the current Google provider configuration. iOS uses the existing Supabase browser OAuth flow; this work does not require a Firebase iOS app, GoogleService-Info.plist or native Google client configuration.
4. On the Mac, with the app configured through the local defines copied by the owner, test Google sign-in from the UI with the app both running and initially closed. Confirm the browser returns to the app and the signed-in route appears. Record the device/simulator, date and observation, without the returned URL's parameters.

The builder has not inspected the hosted allowlist or executed an iOS OAuth return. Its native scheme registration is E0. Supabase's existing app_links consumer handles the auth return and auth-state refresh; Flutter's competing default link handler is disabled on iOS.

The registered scheme accepts both of these URL forms. iOS registers schemes rather than host-specific routes; Dart decides what a received URL means.

| URL | Scope |
|---|---|
| `sa.hadayah.streamerapp://login-callback` | Google OAuth return, pending iOS run |
| `sa.hadayah.streamerapp://channel-connected` | Scheme reserved; channel connection is deferred/gated on iOS in W8 |

A later simulator smoke command can check that the OS opens the app, but an empty callback does not prove authentication:

```sh
xcrun simctl openurl booted 'sa.hadayah.streamerapp://login-callback'
```

## Later, after paid enrollment and domain setup

### Enable HTTPS organization invitations as universal links

Current limit: HTTPS invitation URLs open the browser. No Associated Domains entitlement is installed. Free-team Debug builds must continue without that paid capability.

The current public domain in `project/lib/core/config/app_identity.dart` is `stream-application-ten.vercel.app`. Current shared invite links use `https://stream-application-ten.vercel.app/#/org-invite/<token>`. A path-only AASA rule would miss those fragment routes.

1. After M1–M3 and when the owner elects to enroll, register/confirm the explicit app identifier `sa.hadayah.streamerapp` in the paid team. Obtain its Application Identifier Prefix from Apple's app identifier or signed application-identifier entitlement. Use that prefix in the template; do not assume it always equals the Team ID.
2. Through a separately authorized public-site change, host the following JSON at `https://stream-application-ten.vercel.app/.well-known/apple-app-site-association`, with no filename extension. Serve HTTP 200 over HTTPS, `application/json`, with no redirects. Replace the placeholder locally before publishing. Confirm it survives the SPA routing fallback. The hash-route rule matches existing links; the path rule supports a future canonical path route.

```json
{
  "applinks": {
    "details": [
      {
        "appIDs": ["<APPLICATION_IDENTIFIER_PREFIX>.sa.hadayah.streamerapp"],
        "components": [
          {"/": "/", "#": "/org-invite/*"},
          {"/": "/org-invite/*"}
        ]
      }
    ]
  }
}
```

3. Request a scoped builder work order for non-auth app_links routing into the existing `/org-invite/:id` GoRouter route. Today Supabase owns the app_links stream for auth; adding an entitlement alone will not implement invitation navigation. Keep the built-in Flutter link handler disabled while app_links owns delivery. Preserve auth callbacks and test signed-in, guest and account-switch cases without logging invitation tokens.
4. Only after the paid identifier and hosted file are ready, add the Associated Domains capability and the `com.apple.developer.associated-domains` array value `applinks:stream-application-ten.vercel.app` to the paid Release/Profile signing configuration. Keep it out of Debug/free-team entitlements. Regenerate the paid provisioning profile using Xcode's signing controls. No signing artifacts belong in Git.
5. Verify AASA delivery and Apple's associated-domain diagnostics on the Mac, then tap a real invitation link from another app on an iPhone. Cover cold and warm launch, the current hash form, the path form if published, and expired/used tokens. Record only redacted evidence. This requires E3 before claiming device support.

No paid enrollment, dashboard change, public-file deployment, entitlement or invite-routing change was performed in W5.

## Before submission

- W4 declares the viewer scope from `store/data_safety.md` and the current privacy page. Owner/Claude must review Xcode's packaged privacy report after a real build and reconcile the public policy's Android/web-only platform wording with iOS through a separate site task. Do not edit the Play launch work as part of the iOS run.
- Paid Apple sign-in/provider, App Store and signing instructions will be expanded by their work orders. They are deferred actions, not prerequisites for Windows work or free-team Debug builds.

## Sources

- [Supabase Flutter deep-link configuration](https://github.com/supabase/supabase-flutter/blob/main/packages/supabase_flutter/README.md#deep-links), fetched through Context7.
- [app_links iOS setup](https://github.com/llfbandit/app_links/blob/main/doc/README_ios.md) and [v7 scene lifecycle](https://github.com/llfbandit/app_links/blob/main/doc/README_ios_7.md), fetched through Context7. The pinned app_links 7.0.0 uses automatic FlutterSceneDelegate delivery; no custom manual delegate is added.
- [Apple Associated Domains and AASA](https://developer.apple.com/documentation/xcode/supporting-associated-domains), fetched through Context7. Template uses its appIDs/components schema and fragment/path matching.
- [Supabase TLS change, 2026-10-12](https://supabase.com/changelog/cbc-tls-ciphers-deprecated): legacy CBC cipher removal is announced; it does not change callback registration. Real native HTTPS connectivity remains part of Mac/device verification.

## Sign in with Apple (W9; paid activation deferred)

The iOS button is implemented, but no Apple/Supabase account settings have been changed. Debug deliberately has no entitlements file. Simulator and personal-team Debug builds must remain usable without enrollment; native Apple authentication cannot be claimed until the paid capability and provider are configured and tested. Release and Profile alone reference `Runner/Runner.entitlements`.

When the owner elects to activate Apple sign-in:

1. In the paid Apple team, register/confirm the explicit App ID `sa.hadayah.streamerapp`, enable Sign in with Apple, and refresh the relevant provisioning profiles. Keep the Debug configuration free of this capability; select the paid team for the Release/Profile validation build.
2. In Supabase Dashboard > Authentication > Sign In / Providers > Apple, enable the provider and include `sa.hadayah.streamerapp` in Client IDs. The native ID token audience must match this bundle ID. Native iOS ID-token sign-in does not require a browser Services ID or an OAuth client secret by itself.
3. If the owner also configures Apple's browser OAuth flow later, create a Services ID under Identifiers, associate it with the primary App ID, and configure the website domain `<project-ref>.supabase.co` and return URL `https://<project-ref>.supabase.co/auth/v1/callback`. Put the Services ID first in Supabase's Client IDs list, followed by the native bundle ID. Preserve all existing providers.
4. For that browser flow, create a Sign in with Apple signing key in the Apple portal, store the downloaded .p8 securely outside the repo, and generate the Apple client secret using the Team ID, Key ID and Services ID. Enter it only in the Supabase provider settings. Rotate the secret before its six-month expiry. Never paste IDs tied to accounts, keys, secrets, authorization codes or identity tokens into source, logs or these handoff files.
5. Register the project's outbound email sender/domain with Apple's private email relay if emails will be sent to hidden-email accounts. Leave the unsupported Supabase server-to-server notification endpoint blank, per its provider guide.
6. With a paid-capability build on a real iPhone, verify first authorization and subsequent sign-in, hidden-email choice, cancellation, disabled-provider/network failure, and sign-out then Google sign-in. Confirm consent precedes Apple authorization and the existing Supabase auth listener/role route receives the session. Never record token-bearing callback URLs. Apple returns full name only on initial consent; this implementation uses the existing editable profile/email fallback rather than storing a native credential.
7. Before submission, finish W11's account-deletion/revocation review for Apple identities and validate the Release entitlement with Xcode's resolved build settings and signed app. Source inspection of Debug is not a build/signing proof.

Sources: [Supabase Apple provider guide](https://supabase.com/docs/guides/auth/social-login/auth-apple), [native Flutter nonce exchange](https://github.com/supabase/supabase-flutter/blob/main/packages/supabase_flutter/README.md#native-apple-sign-in), [plugin integration and button](https://github.com/aboutyou/dart_packages/blob/master/packages/sign_in_with_apple/sign_in_with_apple/README.md), [Apple entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.applesignin). Fetched through Context7; installed plugin is 8.1.0, compatible with the pinned Flutter 3.41.2/Dart 3.11.0. Native execution remains unverified.

## W11 submission blockers (ESC-2 and ESC-3)

### ESC-2 / W19 — Apple account deletion source complete, deployment pending

Section 12 authorized W19. The previous forbidden-source blocker is resolved at
E1 with mocked tests. Nothing has been deployed, no real Apple token has been
exchanged/revoked, and the SQL migration has not been executed.

The new function `apple-account-revocation` authenticates the current Supabase
user with `auth.getUser`, loads Apple subjects from database-owned identities,
exchanges a fresh native authorization code, verifies the returned signed Apple
identity/nonce/audience, revokes its refresh token, then records proof. It never
deletes the account itself or stores provider tokens. The existing deletion RPC
and Storage cleanup remain the deletion path.

A new migration `20261017213039_apple_account_deletion_revocation.sql` adds a
private, RLS-protected proof table and a BEFORE DELETE guard on auth.users.
Service-role-only RPCs read the identity snapshot and record proof for exactly
that user/subject/identity version. Updated identities invalidate proof; validity
is ten minutes. Proof rows contain identity identifiers/timestamps, not secrets,
and cascade with identity/account deletion. Expired rows have no authority but
may remain until the next attempt or account/identity deletion.

Owner steps, after choosing paid Apple activation:

1. Audit the new migration and `supabase/functions/apple-account-revocation/`.
   Check the intended project's auth.identities UUID id/provider_id schema,
   migration history, existing deletion restrictions and deployment runtime.
   Do not edit historical migrations or apply the deferred ESC-4 push migration.
   The local CLI generated this filename in UTC on October 17; the work was
   performed October 18 in Riyadh.
2. Configure these environment-only secrets in the intended Edge Functions
   secret manager: `APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_CLIENT_ID`,
   `APPLE_PRIVATE_KEY`. For this native flow APPLE_CLIENT_ID is the exact
   bundle ID `sa.hadayah.streamerapp`, not a browser Services ID and not a
   Team-ID-prefixed value. Use the Sign in with Apple ES256 private key.
   PEM line breaks may be real newlines or escaped newline sequences.
   Never place values in Git, chat, shell command arguments/history or evidence.
3. The function also reads the platform-provided `SUPABASE_URL`,
   `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, and the existing
   `PUBLIC_APP_ORIGIN` for browser-origin/CORS checks. Use the existing public
   app origin. Keep server credentials server-side.
4. Use the owner's authenticated CLI/console for secrets. CLI 2.115.0 help was
   checked: `npx supabase secrets set --env-file <owner-private-file>` is
   supported. The private file must live outside this checkout and evidence.
   Recheck help if the owner uses a newer CLI; develop-branch docs describe a
   different upcoming environment command. No secret command was executed here.
5. Deploy only this function with
   `npx supabase functions deploy apple-account-revocation`, after selecting
   the intended linked project privately. Never omit the function name, which
   would deploy all functions. Keep the gateway's default JWT verification;
   the function independently validates the bearer token. Confirm the function's
   deno.json imports and locked dependency/runtime compatibility in staging.
6. Apply the new migration through the owner's reviewed migration workflow,
   checking the pending migration set before the owner runs `npx supabase db push`.
   Do not blindly include unrelated pending migrations. Install the server guard
   before releasing a client that relies on it. With the guard installed, old
   clients cannot bypass revocation by calling delete_own_account directly.
   If function/secrets are missing, Apple deletion fails closed. Non-Apple
   deletion keeps its existing path.
7. In staging, verify direct RPC deletion of an Apple account without proof is
   refused, ordinary users cannot write proof/call the service-only RPCs, stale
   identity versions and expired proof are refused, and non-Apple deletion and
   existing banned/broadcast/organization/Storage restrictions are preserved.
   The SQL was source-reviewed only here; no local/hosted DB assertions ran.
8. On a paid-capability iPhone build, use a disposable Apple-linked account.
   Test cancellation, wrong Apple account, missing configuration, expired/used
   code, provider/network failure, then successful revocation and actual data
   deletion. Include hidden email and an account linked to both Apple and Google.
   Compare the Apple subject, not the email. No tokens or account identifiers in
   evidence. A signed-in Apple-linked account on unsupported platforms receives
   the localized unavailable message rather than silently skipping revocation.
9. Revocation, Storage cleanup and SQL deletion are separate external operations.
   A later cleanup/deletion failure may leave the account alive with Apple already
   revoked and some uploads removed. A retry obtains fresh authorization. Review
   the existing banned-user and organization-owner restrictions and provide the
   documented support completion path before submission.

Local proof: 16 Node tests with mocked HTTP, including generated in-memory
cryptographic keys, plus 12 new Flutter deletion tests. `deno check` passed for
the production index using Deno 2.9.6. This is E1 host/source proof, not a Supabase
deployment, actual account deletion, iOS build or Apple revocation proof.

References: [Apple token exchange](https://developer.apple.com/documentation/signinwithapplerestapi/generate-and-validate-tokens),
[revocation](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens),
[client secret](https://developer.apple.com/documentation/accountorganizationaldatasharing/creating-a-client-secret),
[verification](https://developer.apple.com/documentation/signinwithapple/verifying-a-user).
Context7 and the official references were checked; installed client/CLI APIs were
also read. Supabase's October 12 TLS notice affects obsolete ciphers from November
10; current Edge/Dart clients need no source workaround.

### ESC-3 — Legal/support documents and complete privacy disclosures

Observed on 2026-10-17: `/privacy.html` and `/about.html` return the same Flutter bootstrap body as `/`, including the same SHA-256. `/delete-account.html` returns an old Dalilk-branded page. All return 200, so a status-only check misses the problem. The default in-app legal model also contains only a short Google-profile policy. Hosted legal content was not inspected.

1. In a separately authorized public-site task, serve the actual documents at the existing AppIdentity URLs before the SPA fallback: `https://stream-application-ten.vercel.app/privacy.html`, `/about.html`, and `/delete-account.html`. Start from the repository's existing `project/web/` documents, preserve the Play launch work, and reconcile the old deletion-page branding.
2. Publish complete matching English/Arabic privacy disclosures for iOS as well as existing platforms. Reconcile them against `store/data_safety.md`, the W4 manifest, actual third-party services and the Xcode packaged privacy report. Cover Apple/Google identity and private relay email, optional profile/organization/contact/location/images, chat and reports, identifiers/usage, provider processing, retention/deletion, consent withdrawal/data rights and the published support contact. Do not claim the embedded video provider is ad-free or infer tracking behavior solely from the app manifest.
3. Prepare the platform paragraph for review using this concrete delta:
   - EN: “On iOS, Hadayah Live offers Sign in with Apple and Google sign-in. Apple may provide a private relay email address. The initial iOS release supports viewing and account features; phone publishing, channel connection and push notifications are deferred. Foreground location and selected-photo access are requested only when using the relevant feature.”
   - AR: “يوفر Hadayah Live على iOS تسجيل الدخول باستخدام Apple أو Google، وقد توفر Apple عنوان بريد إلكتروني خاصًا لإخفاء بريدك. يدعم الإصدار الأول على iOS المشاهدة وميزات الحساب، مع تأجيل البث من الهاتف وربط القنوات والإشعارات الفورية. يُطلب الوصول إلى الموقع أثناء الاستخدام والصور المحددة عند استخدام الميزة المعنية فقط.”
   This supplements the complete collection/retention policy; it is not a replacement for the full policy.
4. Through an authorized admin account, open the existing Admin Hub Terms tab (`admin.tab_terms`), edit both Privacy Policy fields and save (`admin.btn_save_terms`). Verify the saved text appears in the pre-sign-in consent reader and Settings legal reader in both languages. Arrange a scoped source change for the default offline/unconfigured fallback after the same full text is approved. No hosted editor was used by the builder.
5. Fetch each public URL and inspect both body and title. Privacy/about must contain their actual content and differ from the Flutter root bootstrap; deletion instructions must identify Hadayah Live and the current support channel. Check on a phone browser and in-app reader, with no login required for the policy.
6. Only after these checks, use the public URLs in App Store Connect. The W14 listing pack deliberately marks URL/content readiness as blocked rather than treating 200 as success.

## W12 / W13 — optional pre-Mac compile gate

Owner account action: push the intended master commits, sign in to Codemagic, connect the intended repository, choose YAML workflow `ios-compile-check` on master and start one manual run after reviewing current minutes/billing. Do not add Apple signing or publishing integrations. It uses example defines only; never upload the local define file. Retain the commit SHA, run URL, tool versions, analyzer/test results and unsigned native build result. For failure, return about 150 lines around the first real error without secrets. Full click/command/evidence steps are in [CI_OWNER_STEPS.md](CI_OWNER_STEPS.md).

No job has been started and no CI account has been accessed by the builder. W13 has no real build log to fix yet. Skip Codemagic when the physical Mac is available and use Track M directly.

## W14 — Store metadata and forms (later paid account)

The seven drafts in `brief/ios/store/` are a reviewable pack, not submitted metadata. English/Arabic names, subtitles, promotion, keywords and description fit Apple's current limits; Arabic keywords are 75 UTF-8 bytes. Review-note paste text is 1,728 bytes.

After M1–M3, the required device checks and the owner's decision to enroll:

1. In App Store Connect > Apps > New App, select iOS, the paid-team bundle ID `sa.hadayah.streamerapp`, the owner-confirmed app name/primary language and an owner-chosen SKU. Do not invent an account identifier or change the bundle ID to work around signing.
2. Add English (U.S.) and Arabic metadata from listing_en.md / listing_ar.md. Use Education as the proposed category and the actual uploaded version/build. Enter the real rights holder in Copyright; Apple's UI adds the symbol. The first version has no What's New field.
3. Resolve ESC-3 before entering the support/privacy URLs. Confirm actual documents and contact information are delivered, not HTTP 200 Flutter fallback HTML. Reconcile the in-app default and hosted legal text with the form.
4. Complete App Privacy from privacy_answers.md and the packaged privacy report, resolving App Functionality/Analytics purposes, provider behavior/retention and any additional categories. Optional app actions are not automatically optional disclosures.
5. Complete the current age questionnaire from age_rating.md after reviewing the actual catalog/live-content policy. Declare UGC/chat and assess social media, ads and player navigation honestly; no parental/age-assurance feature is implemented. Use Connect's computed rating and review territories.
6. Prepare the actual review fixtures, main demo account and separate disposable deletion account. Enter credentials and review contact name/phone only in App Store Connect; never in this repo. Finish ESC-2 Apple revocation first. Validate every navigation label in app_review_notes.md and replace its bracketed placeholders in Connect.
7. Capture genuine iOS screenshots using screenshots.md for 6.9-inch and 6.5-inch sets in both languages. No Android captures or invented iPhone screens. Confirm supported pixels, no alpha, safe areas, actual feature visibility and absence of private data.
8. Confirm content rights, the final encryption/export-compliance answers and all regional/account requirements against the actual build. No export-compliance plist answer has been guessed in this work.
9. Upload a signed archive through the owner's Xcode/App Store workflow after the device checks. A processed TestFlight build supports E4; an unsigned CI artifact does not. Owner reviews the final metadata and clicks Submit in M5.

No paid account operation, upload, metadata publication or screenshot capture was performed by the builder.

## W16 — Mac and free-team setup

When the Mac arrives, follow [MAC_SETUP.md](MAC_SETUP.md), including the current Xcode/macOS requirement check, pinned Flutter 3.41.2, CocoaPods, repository transfer and exact M1–M5 commands. The owner must ensure manager-authored plans/pending ledger decisions are included in the pushed checkout; untracked files do not arrive through a clone automatically.

Owner-only hands: install/sign in to Xcode locally (Settings > Accounts), handle system/license/keychain prompts, copy the ignored local define file by hand without printing it, and later connect/unlock/trust the iPhone and enable Developer Mode. Use the free personal team only for Debug; do not attach Apple sign-in, Associated Domains or APNs entitlements to it. Simulator/unsigned M1 compilation needs no paid enrollment. Never commit account/team/provisioning material. Paid activation/distribution remains deferred until the owner decides after M1–M3.

## W17 — Publisher dependency

Section 12 withdraws the W11 dependency and authorizes flagged W17 implementation on Windows. The publisher must default off, with native configuration/dependency in a separate revertable commit from Dart changes. No paid account is required to write source; native compilation and device behavior still await the Mac/iPhone. IOS_PUBLISHER_HANDOFF.md is historical research until W17 updates it.

## W18 — Push, deferred by D3/D4

The complete implementation proposal and acceptance matrix are in [IOS_PUSH_SPEC.md](IOS_PUSH_SPEC.md). W18 is spec only; iOS Firebase stays disabled and free-team Debug keeps no entitlement file.

1. Owner/Claude decide ESC-4: authorize a separate backend migration that adds `ios` to both the push-device table CHECK and registration RPC validator while preserving hardened ownership, banned-user restrictions and grants. Audit Android/web regression, token transfer/cleanup and both reminder/organization dispatchers. No migration was applied by the builder.
2. Only after paid enrollment is chosen, enable Push Notifications for `sa.hadayah.streamerapp`. Create the Firebase iOS app in the existing reminder Firebase project. The owner creates/stores the APNs authentication key outside the repo and uploads it under Firebase Project Settings > Cloud Messaging > iOS app configuration with the requested identifiers; no key, identifier, token or account screenshot belongs in the repo/evidence.
3. In a separately scoped implementation, supply the public per-platform Firebase iOS configuration locally, add paid-build-only APNs/background configuration, and fix both initial/refresh platform labels plus APNs-token readiness. Do not add APNs entitlements or Firebase auto-initialization to Debug. Do not disable FlutterFire method swizzling.
4. Verify the final signed app's APNs environment against its provisioning profile through the owner's local Xcode workflow, without exporting signing/account material into evidence. Use paid Profile/Release for push tests; keep the free-team Debug build available.
5. On an actual iPhone, execute the spec's opt-in/denial/token lifecycle, foreground/background/cold-open, EN/AR, correct-recipient and two-message-type matrix. Later test production delivery on a processed TestFlight build. Update legal/privacy/store declarations before enabling push in a release.

These are later owner steps. No paid enrollment, Firebase console, APNs key, backend deployment or push delivery was attempted.
