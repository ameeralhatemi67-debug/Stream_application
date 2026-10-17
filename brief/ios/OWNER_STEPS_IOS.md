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

### ESC-2 — Apple account deletion

The existing Settings > Account & Data > Delete Account path deletes app/auth data through existing RPCs. It does not revoke Apple's authorization. Do not activate the Apple provider for a submission build until this gap is resolved.

1. Owner/Claude authorize a separate backend work order. Choose either fresh native Apple reauthorization at deletion, with a server-side authorization-code exchange and token revocation, or secure server-side retention of a provider refresh token established during Apple authorization. Bind the Apple subject to the signed-in account; do not accept a client-supplied unrelated identity.
2. Supply the Apple signing key/client-secret setup only through the backend secret manager. The server exchanges the authorization code as required, then revokes an Apple access/refresh token at `https://appleid.apple.com/auth/revoke`. An Apple identity token or a Supabase session token is not a substitute. Nothing secret belongs in Flutter or Git.
3. Integrate that result with the existing prepare-account-deletion/Storage cleanup/delete-own-account flow. Define retry/failure behavior so the app cannot silently report complete deletion while leaving provider authorization intact.
4. Review the existing banned-user, active-broadcast, organization-ownership and remaining-files deletion restrictions. Document legitimate retained records and a usable completion path; do not infer compliance from an enabled button.
5. Test first Apple sign-in, subsequent sign-in, hidden email, reauthorization/cancellation, revocation failure/retry, completed deletion and a later fresh authorization on an iPhone. Keep test credentials and tokens out of evidence. Claude audits the separate backend change before submission.

References: [Apple account deletion](https://developer.apple.com/help/app-review/guideline-reference/5-1-1-account-deletion), [Sign in with Apple revocation](https://developer.apple.com/documentation/signinwithapplerestapi/revoke-tokens). W11 made no backend or secret change.

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
