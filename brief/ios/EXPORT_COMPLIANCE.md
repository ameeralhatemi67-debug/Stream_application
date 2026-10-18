# Encryption export compliance draft

2026-10-18, W22. Source inventory E1; native binary inventory E0. The owner
confirms the submitted binary, distribution territories and current Connect
answers. No Info.plist change or account access was made.

## What the app uses

| Use | Repository evidence | Interpretation |
|---|---|---|
| Supabase Auth/REST/Storage/Functions and Realtime | project/lib/core/config/supabase_config.dart; core/services/supabase_auth_service.dart; provider service calls | HTTPS and secure WebSockets protect transport. Supabase handles provider sessions and server tokens. No user-facing encryption product. |
| Google/Apple authentication and YouTube playback | supabase_auth_service.dart:46,72; features/live_stream/presentation/adapters/youtube_player_adapter.dart | Native/browser authentication and HTTPS player/API traffic. Apple nonces use the standard SHA-256 implementation in package:crypto, not a proprietary algorithm. |
| Maps, images, links | features/map/presentation/venue_directions_launcher.dart and map/image URL callers | Standard HTTPS transport through Flutter/native/browser components. External apps have their own implementations. |
| Opt-in publisher, absent from default viewer dependency graph | ios/Runner/Publisher/PublisherPipeline.swift; live_stream/services/rtmp_publish_engine.dart | RTMPS uses TLS in the pinned SDK/native stack. Reassess the opt-in archive separately; it is not the launch viewer binary. |
| Server-side Apple exchange/revocation | supabase/functions/apple-account-revocation/ | Standard ES256 signing and RS256 JWT validation run on the server, not shipped as client signing code. No signing key is included in the app. |

Additional standard hashes exist: `public_catalog_cache.dart:42` uses SHA-1
for a cache digest, and `features/map/services/map_pack_platform_io.dart:9` uses
SHA-256 for downloaded pack integrity. These do not encrypt user content.

The app defines no custom cipher, VPN, encrypted file store or end-to-end
messaging protocol. This does **not** mean no cryptography. Flutter/Dart secure
sockets use a bundled SSL implementation; native/web views use Apple networking.
The [Dart 3.11 source](https://github.com/dart-lang/sdk/blob/3.11.0/runtime/bin/secure_socket_filter.cc)
uses SSL APIs for secure sockets, including Apple trust evaluation. Do not
select an OS-only answer merely because the app is written in Flutter. Hashes
in pubspec.lock are package integrity metadata, not app encryption features.

## Likely classification, owner confirms

Limited standard transport/authentication is likely eligible for an export
exception, rather than proprietary/nonstandard-encryption treatment. This is
an inference from source use, not approval of a compiled archive. Apple says
OS-only encryption needs no Connect documentation, and separately describes
documentation for standard algorithms outside the OS, including France-specific
requirements. The linked SDK/engine and chosen countries matter. See
[Apple documentation table](https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption/).

Before certifying an exemption, the owner checks the final Pods/engine inventory
and confirms the applicable transport/authentication or ancillary-function
exception with counsel if needed. HTTPS-only is not literally the entire network
inventory: secure WebSockets exist, and RTMPS exists in the opt-in variant.
Do not use a U.S./Canada-only exception for the proposed Saudi distribution.

## App Store Connect owner worksheet

Open **Apps > Hadayah Live > App Information > App Encryption Documentation > +**,
or **TestFlight > build > Manage** beside missing encryption information.
[Apple's current entry instructions](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/)
explain the conditional questionnaire. No logged-in form was inspected; exact
follow-up wording depends on the build and previous answers. Verify it on the
owner's screen instead of treating this worksheet as a completed declaration.

| Prompt / conditional item | Recommended answer, owner confirms |
|---|---|
| “Does your app use encryption?” | **Yes**, including TLS. This is different from asking whether it uses non-exempt encryption. |
| “What type of encryption algorithms does your app implement?” | Standard algorithms used by SDK/engine transport and SHA-256; **no proprietary algorithm**. If the selector distinguishes standard algorithms outside Apple OS, do not choose OS-only/none without verifying the actual engine. |
| Category 5 Part 2 / documentation exemption follow-up | **Likely Yes only after confirming the applicable limited-use exemption** for the shipped viewer and its SDKs. Do not certify solely from the absence of an app-written cipher. |
| Proprietary/nonstandard algorithms follow-up | **No**, subject to final linked SDK review. |
| Standard algorithms in addition to Apple OS follow-up | **Yes if asked**, accounting for Dart SSL and package:crypto. Follow Apple's resulting documentation request; do not change the answer to avoid it. |
| Availability in France follow-up | **Owner confirms actual selected territories**. The proposed Saudi scope does not establish whether France is enabled. |
| Non-exempt encryption build declaration | **Likely No only after the above exemption review**. Keep Info.plist unchanged in W22; a later owner-approved declaration may record the resolved answer. |

The two short prompt labels above are the expected Connect labels, not evidence
of today's account form. The owner should paste any differently worded question
back to Claude before choosing an unsupported answer. Never paste credentials.

[Apple's overview](https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/)
requires a determination even for OS cryptography. Its
[Security guidance](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations)
explains exempt versus non-exempt declarations and possible annual reporting.
No export classification, filing, French approval or App Store acceptance is
claimed by this draft. Re-check when the archive or distribution changes.
