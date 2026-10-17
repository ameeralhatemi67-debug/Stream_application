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
