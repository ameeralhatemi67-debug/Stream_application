# App Review notes draft

Do not submit until README.md blockers and native checks are complete. Owner enters contact name/phone, demo username/password and any additional disposable-account credentials in App Store Connect only. No credentials or Apple account identifiers belong here.

## Owner preparation

- Provide a working, non-expiring, non-privileged viewer review account for the existing Google flow; verify it on iOS without an owner approval/recovery challenge. Do not invent a demo authenticated session or bypass backend roles.
- Apple sign-in uses the reviewer's device account. Activate and verify the paid native capability/provider and finish Apple deletion revocation first; never provide the owner's Apple credentials.
- Provide an actual replay and a review live-room fixture with permission to use its content. Keep services and moderation available during review. Put the exact test stream/replay URL and permitted test names in Connect, not token-bearing links or secrets in this repo.
- If organization content is advertised, confirm visibility/pilot flags and a public test organization. The viewer account needs no Master Admin privilege or connected publishing channel.
- Supply a separate disposable account for testing deletion, plus narrowly scoped moderator access only if needed to demonstrate moderation. Owner verifies the deletion flow beforehand.

## Paste-ready note (replace brackets in Connect)

Hadayah Live is an Arabic/English educational viewing app. The iOS release is viewer-first.

1. On Welcome, review the privacy notice and choose Continue as Guest Viewer. Browse discovery, open the supplied recording [REPLAY TITLE/URL], and view venue information in the Map tab.
2. For chat, follows and saved content, use Sign in with Google with the demo account entered in App Review Information, or Sign in with Apple using the review device's account. The account route follows the completed provider session.
3. In the supplied room [REVIEW ROOM/STREAM URL], long-press another test user's message to find Report and Block. Moderators can mute/delete through their stream role. Please use the prepared test content.
4. Follow a channel, save a recording/upcoming broadcast and open the library. On the map, choose a venue and open directions. Location is requested only when using the relevant location action; selected-photo access is optional.
5. Settings > Governance/Legal > Privacy Policy opens the policy reader; Contact Support opens email. Settings > Account & Data > Delete My Account opens confirmation (Yes, Delete My Account). An Apple-linked account is deleted inside the iOS app with fresh Apple authorization. If blocked, the account has not been deleted; email support to ask what is blocking it. Support cannot complete deletion by email alone. Use the separate disposable account supplied in Review Information when testing deletion.
6. Organization pages show participating organizations and venues [TEST ORGANIZATION, if included]. Arabic can be selected in-app; layout mirrors for RTL.
7. Phone publishing, OBS/channel setup and push are deferred in this iOS release. The corresponding entry points explain availability. HTTPS organization invitations currently open the browser; native universal links are not advertised.

No purchase flow is offered. The owner must keep backend services available during review. Contact the support address in Review Information with questions.

## Evidence / owner completion

Record the final uploaded version/build, review fixtures and flags, last verified native run date, and exact navigation labels before pasting. Replace every bracketed placeholder and enter credentials only in Connect. Do not use the Android phone-broadcasting instructions. App Store processing (E4) and submission remain owner steps; the builder has not created an account record or uploaded a build.

