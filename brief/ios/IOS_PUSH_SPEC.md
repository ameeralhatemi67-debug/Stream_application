# W18 — iOS push specification

2026-10-17. **Spec complete; implementation deferred.** No Dart, iOS, Android,
backend, hosted setting, secret or signing material is changed by W18.

D3 keeps push outside the viewer-first launch. D4 defers paid Apple enrollment.
The current iOS Firebase exclusion stays in place, and Debug/Simulator/free-team
device builds must remain usable without APNs or any paid entitlement.

## Current source evidence

| Area | Finding |
|---|---|
| Client guard | `project/lib/core/config/reminder_firebase_config.dart:14` supports web and Android only. iOS is unsupported and unconfigured, covered by `ios_firebase_config_test.dart`. |
| Installed packages | `firebase_core 4.15.0`, `firebase_messaging 16.7.0`; no package upgrade is proposed. |
| Initial registration | `reminder_push_service.dart:85` sends `kIsWeb ? 'web' : 'android'`. Simply enabling iOS would mislabel it. |
| Token refresh | The independent call at `reminder_push_service.dart:57` has the same problem. Both must use one tested platform mapping. |
| Backend boundary | `upcoming_schedule_service.dart:134` calls `register_schedule_push_device`; removal filters the current viewer ID and token. |
| Table constraint | `supabase/migrations/20260930010000_upcoming_live_schedules.sql:125` allows only `android` and `web`. |
| RPC validation | The same migration's line 170 separately rejects other platforms. Changing just the table is insufficient. |
| Later hardening | `20261015174637_reconcile_post_hardening_grants.sql:88–98` splits own-row policies and retains banned-user write restrictions. No later local migration admitting iOS was found. Hosted state was not inspected. |
| Delivery | `dispatch-upcoming-reminders/index.ts` and `dispatch-organization-events/index.ts` send common FCM notification/data payloads with additional Android tag fields. Neither contains explicit APNs options. That alone does not prove Apple delivery is broken; common FCM fields can be cross-platform. |
| Native baseline | No GoogleService-Info.plist, APNs entitlement or remote-notification mode. W9's entitlement file is attached to Release/Profile only and currently contains Apple sign-in only. |
| In-app routing | `AppProvider.attachReminderPush` handles upcoming reminders and organization events; the foreground path checks current recipient identity. Audit the open/tap path and auth timing before enabling another platform. |

## Owner account setup — later, not now

1. After the owner chooses paid enrollment and authorizes push, enable Push
   Notifications on the existing explicit App ID `sa.hadayah.streamerapp`.
   Keep its identity; do not create a workaround bundle ID.
2. In the intended Firebase project, register a new **iOS app** with that exact
   bundle ID. Confirm it is the project used by the existing reminder dispatchers.
   Android/web app IDs are not interchangeable with the iOS Firebase app ID.
3. In Apple Certificates, Identifiers & Profiles > Keys, create the APNs
   authentication key with the scope/environment required by the account's current
   UI. The owner downloads and stores it securely outside the repository. In
   Firebase Project Settings > Cloud Messaging > iOS app configuration, upload the
   APNs key and enter the requested key/team identifiers locally.
4. Record only setup completion and environment, with no key, key ID, team ID,
   device token or account screenshot in Git/evidence. Keep existing Firebase
   server credentials in their current backend secret manager; never embed service
   account material in Flutter.
5. Provide the public Firebase iOS client configuration through an approved local
   build configuration. Decide the exact config scheme in the implementation work
   order. Prefer separate per-platform define values over reusing the Android app
   ID. If a native Firebase plist is chosen instead, scope its target/configuration
   and initialization carefully so it cannot auto-enable Firebase in free Debug.

APNs-key upload is described in [Firebase's Apple client setup](https://firebase.google.com/docs/cloud-messaging/ios/client).
These are owner actions; no account or key operation has been performed.

## Future native configuration contract

| Configuration | Required behavior |
|---|---|
| Debug / Simulator / free-team device | No `CODE_SIGN_ENTITLEMENTS`, no APNs initialization/registration and no paid capability. Existing W6 iOS guard remains false. Merely supplying Android Firebase defines must never enable iOS push. |
| Paid Profile / Release test build | Explicit push opt-in plus complete iOS Firebase configuration; capability/entitlements match the actual paid provisioning profile. Keep default viewer builds opt-out. |
| Distributed paid release | Inspect the final signed product, not only the source plist. APNs environment must match distribution provisioning; prove delivery on an iPhone before advertising push. |

The iOS entitlement key is **`aps-environment`**, with `development` or
`production`. Xcode derives it from provisioning: development profiles use the
development environment, production profiles and TestFlight use production. Do
not infer the value from a configuration name alone or use the macOS
`com.apple.developer.aps-environment` key. Extend W9's paid-only configuration
deliberately without attaching its entitlement file to Debug.
[Apple entitlement documentation](https://developer.apple.com/documentation/bundleresources/entitlements/aps-environment)

Firebase's Flutter guide requires Push Notifications and Background Modes >
Background fetch / Remote notifications, APNs-key upload, and method swizzling.
For the future opted-in paid configuration, use the documented
`UIBackgroundModes` values `fetch` and `remote-notification`; keep today's
viewer Debug plist unchanged. Do not set `FirebaseAppDelegateProxyEnabled` to
false. Preserve Flutter 3.41's implicit-engine/plugin registration.
[Firebase Flutter setup](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[Apple background-mode values](https://developer.apple.com/documentation/bundleresources/information-property-list/uibackgroundmodes)

## Future client behavior

Implement only in a separately authorized work order:

- Select the iOS Firebase options and opt-in only for an eligible paid build.
  Keep absent/invalid configuration a graceful `unavailable` state.
- Replace **both** hardcoded platform expressions with one function returning
  `ios`, `android` or `web` for supported platforms; unsupported platforms stay
  unavailable. Android/web values and existing consent behavior must be preserved.
- Ask notification permission only from the user's reminder action. Handle
  not-determined, denied, authorized and provisional states explicitly; do not
  repeatedly request a denied OS permission. The existing passive sync uses
  `getNotificationSettings`.
- On iOS, wait for a non-null `getAPNSToken()` before `getToken()` and other
  dependent FCM registration calls. A missing token is pending/unavailable, not
  success; use bounded retry or a later foreground sync. Never busy-loop.
- Keep initial token save and refresh bound to the current signed-in account and
  auth generation. Test sign-out/account change while a token operation is
  pending. Remove obsolete tokens and invalidate on sign-out; never store or
  print real tokens in source, test fixtures, logs or evidence.
- Reuse `onMessage`, `onMessageOpenedApp` and `getInitialMessage()`, with
  validated message types/IDs, current-recipient checks and auth/router readiness.
  Do not navigate to arbitrary URLs supplied in a push body.
- Start with the existing in-app foreground notification treatment. If OS
  foreground banners are later desired, explicitly choose presentation options
  and prevent duplicates. Background/terminated alerts must not depend on Dart UI
  running. A silent/data-only background handler is separate scope; do not
  promise precise or guaranteed delivery.

The installed 16.7.0 Dart source was checked for the named methods, including
`getAPNSToken`, `getToken`, `onTokenRefresh` and the default false foreground
presentation options. Use the installed API, not a newer quickstart's unrelated
registration example. Permission/APNs ordering comes from
[Firebase's Flutter client guide](https://firebase.google.com/docs/cloud-messaging/flutter/get-started);
app-state/tap semantics from the
[receive-messages guide](https://firebase.google.com/docs/cloud-messaging/flutter/receive).

## ESC-4 — backend migration proposal for owner/Claude decision

**Required decision:** authorize a separate migration and backend audit, or keep
iOS push deferred. Do not edit the historical migration or relax RLS to work around
registration failure. W18 applies no SQL.

The proposed migration would allow exactly `android`, `web`, `ios` in both the
`schedule_push_devices` platform CHECK and
`register_schedule_push_device` validator. Preserve the function's authenticated
ownership transfer, banned-user rejection, token-length/language validation,
empty search path and hardened grants/policies. Inspect the actual constraint
name and hosted schema in that authorized task before creating a new
timestamped migration.

Retain existing claim/delivery deduplication, lease/retry and invalid-token cleanup.
Verify both upcoming and organization notification dispatchers. Common FCM
notification/data may be sufficient ([cross-platform message guide](https://firebase.google.com/docs/cloud-messaging/customize-messages/cross-platform)); do not add APNs fields or change Android
payloads merely because the source currently contains an Android tag. Decide
Apple expiration/collapse behavior against actual required semantics so expired
reminders cannot mislead users. If headers/options are needed, validate them
against the FCM HTTP v1 schema and preserve Android/web behavior.

Required backend acceptance: authenticated iOS registration and refresh succeed;
Android/web registration still succeeds; unknown/empty/null platforms and invalid
token/language inputs fail; anonymous/banned/other-user writes remain denied;
account transfer cannot inherit prior-user reminders or delivery history; logout
and account deletion remove registrations; jobs cannot send another user's
content. Include both dispatchers and invalid-token cleanup. A local migration
test is separate from hosted verification and device delivery.

## Verification before enabling or shipping

| Gate | Evidence required |
|---|---|
| E1 client | Both registration paths map iOS correctly; Debug/config opt-out; APNs token pending; permission denial/provisional; token rotation; sign-out/account race; validated cold/warm tap routing. Real EN/AR catalogs stay symmetric. |
| Backend | Migration/RPC/RLS and delivery regression results above, including Android/web. Owner/Claude audit; no production change inferred from repository SQL. |
| E2 | Paid-target code compiles on Mac and baseline free-team Debug still compiles with no entitlement file. |
| E2S | Simulator-only launch/config/UI checks may supplement evidence; do not award real push delivery or E3 from simulator injection. |
| E3 | Actual iPhone: opt-in, denial/settings return, foreground, background, normal terminated cold-open, lock, offline/reconnect, token refresh, EN/AR, both message types, correct recipient after account change. Record actual OS/model/build/fixture/results without identifiers/tokens. |
| Distribution | Later paid/TestFlight production-environment delivery and processing proof; update privacy policy, W4 manifest and store privacy answers for the added installation/device identifiers and Firebase processing before release. |

W18 reaches **E0 specification only**, with the existing E1 host Firebase exclusion
unchanged. No APNs delivery, iOS compilation or device behavior is claimed.

Official references were fetched using Context7 and checked on 2026-10-17.
[Firebase Flutter prerequisites](https://firebase.google.com/docs/flutter/setup),
[Apple APNs registration](https://developer.apple.com/documentation/usernotifications/registering-your-app-with-apns),
[Apple account/personal-team limits](https://developer.apple.com/help/account/basics/about-your-developer-account).
