# Streaming core: diagnosis and plan (2026-10-04)

Owner goal: an approved streamer (solo, organization member, or invited member who switches between the two) taps **Go live** and is live on YouTube. Title and description are optional. Phone and laptop are one step; OBS is a few guided steps. This must work on Android, iPhone, and Windows/web, and on low-end phones too.

## 1. Why you cannot go live today

Hosted evidence comes from the `streamer_app` project (zkkmfjsjouqzibvnzkau) for 2026-10-04, 16:20–16:40 UTC. The sources are Edge and Postgres logs, `broadcast_sessions`, and `private.broadcast_provider`.

| # | Finding | Evidence | Severity |
|---|---|---|---|
| F1 | **Every Preview camera fails after YouTube has already created the feed.** YouTube returns `rtmps://a.rtmps.youtube.com/live2` (OBS's built-in "YouTube - RTMPS" server is the same host). Our code accepts only `*.rtmp.youtube.com`. The check exists in three places: the Edge function (`ingestionAddress`), the SQL step `broadcast_provider_step`, and the app (`app_provider.dart`, `checkBroadcastPermission`). | Three sessions today (`c261a66e`, `06e6be58`, `1b5a3471`): `broadcast-control` returned 409, `provider_stream_id` was never stored, and no Postgres error was logged, so the failure was on the provider/validation side. Every test fixture used an invented `a.rtmp.youtube.com` value, so the tests agreed with the bug. | **Blocker** |
| F2 | A validation failure that happens *after* a successful YouTube write was marked "not ambiguous". Every retry therefore created another orphaned YouTube stream key. | `broadcast_control.ts` `write()` | High |
| F3 | The recovery job re-claims finished shows that never had a YouTube feed every ~minute, forever, because `feed_retired` can never become true. This wastes a Google token refresh each time. | All 3 sessions show `checked_at` 16:36:01, still claimed after completion | Medium |
| F4 | Errors were invisible. Every RPC failure became `409 session_operation_unavailable`, and the provider reason was never logged, so diagnosis needed database forensics. | `broadcast-control/index.ts` | Medium |
| F5 | **The Google OAuth app is in Testing mode.** You saw the "Google hasn't verified this app" screen. In Testing mode, refresh tokens for the YouTube scope **expire 7 days after consent**, and only listed test users can connect. Even after F1 is fixed, every channel stops working a week after connecting. | Google: "Manage App Audience"; "OAuth app state overview" | **Blocker for release** |
| F6 | The consent screen shows `zkkmfjsjouqzibvnzkau.supabase.co` as the app. Google verification requires a domain you own and have verified. The OAuth callback must therefore move to your own domain, through a Supabase custom domain or a redirect on your Vercel domain. | Screenshot 2 | Release blocker (for F5) |
| F7 | YouTube API quota: the default is 10,000 units/day **for the whole app**. Each show today costs about 300 write units (stream insert 50 + broadcast insert 50 + bind 50 + go-live transition 50 + complete 50 + stream delete 50) plus polling. That is roughly 25–30 shows per day across all users, and a preview that is opened and cancelled still spends about 150. | YouTube "Quota calculator" | Scaling blocker |
| F8 | The title is mandatory. Preview stays disabled until a title is typed (screenshot 6). The goal is "or simply just go live". | Studio screenshot | UX |
| F9 | Solo "Upcoming Live" entries are announcements only. Going live creates a new unrelated session. Organization schedules do materialize sessions. | `broadcast_reconcile_claim` materializes only `organization_id is not null` schedules | UX / consistency |
| F10 | Personal sessions get `expected_end_at = start + 1h`. `broadcast_reserve` refuses `start` after that time. A show longer than an hour that needs to reconnect after minute 60 will probably be refused (**verify**). | `organization_v1_sessions.sql:240` | Risk |
| F11 | **There is no iOS app at all.** `project/` has `android`, `web` and `windows`, but no `ios/`, and the phone encoder (`RtmpPublisherBridge.kt`, RootEncoder) is Android-only. | `ls project` | Platform gap |
| F12 | The old manual path still worked on 2026-09-26 (sessions with real `stream_id`s). That path was: the streamer pastes a stream key and watch link, or uses OBS. On 2026-10-01 (`2149722`) it was replaced by the OAuth path, which was first exercised against real YouTube today. | `broadcast_sessions` history | Process |

### Already fixed locally (F1–F4), not yet deployed

- `supabase/functions/_shared/youtube_broadcast.ts`: accepts `*.rtmps.youtube.com` and `*.rtmp.youtube.com`, and still requires `rtmps:`, port 443 or none, and no credentials in the URL.
- `supabase/functions/_shared/broadcast_control.ts`: a result that is refused after a successful write is now ambiguous, so the retry adopts the existing feed instead of creating another.
- `supabase/functions/broadcast-control/index.ts` and `reconcile-broadcasts/index.ts`: log structured reason codes. Tokens and keys are never logged.
- `supabase/migrations/20261005054018_youtube_rtmps_host_and_reconcile_scope.sql`: corrects the SQL host check, and stops re-claiming finished shows that have no feed.
- `project/lib/core/providers/app_provider.dart`: corrects the client host check.
- Fixtures now use the real host. A new regression case in `brief/tools/broadcast_control_check.mjs` fails without the fix and passes with it.
- Verified: provider and broadcast-control checks pass, `flutter analyze` reports 0 issues, and 78 streaming tests pass. **Not verified:** the SQL suite (needs the local Docker stack), deployment, and a real phone → YouTube run.

**Deploy order:** (1) apply the migration, (2) deploy `broadcast-control`, `reconcile-broadcasts` and `channel-authorization` (they share `_shared/`), (3) install a new APK, because the client check changed, (4) delete the orphaned "Hadayah session …" stream keys in YouTube Studio → Go Live → Stream settings (they are harmless).

## 2. Is "Connect YouTube" the right design? Yes — keep it, plus a fallback

OAuth channel connection is the only design that gives all of the following together:

- **One-tap go live.** The server creates the broadcast and stream key, so the streamer never copies a key or a share link. This removes the old "stream key + share link" burden entirely, because the server knows the video ID.
- **Organizations.** The org owner connects the org channel once. Members stream to it without ever seeing the key. Each show gets its own non-reusable stream key, so 2–3 members can be live on the same org channel at the same time (the server already allows 3).
- **Invited streamers** pick the destination (org channel or personal channel) per show.
- Automatic end, replay, recovery and moderation.

What it costs, and the plan must pay for it: Google verification (F5/F6), a YouTube quota extension (F7), and a fallback for channels that cannot or will not connect.

**Fallback ("Manual key" mode):** keep the pre-2026-10-01 flow (paste stream key + watch link, or OBS), clearly labelled as advanced. Use it while Google verification is pending, when the daily quota is exhausted, or when an owner refuses OAuth. The i18n strings still exist. Verify that the code path is still reachable.

## 3. Target system

```
Streamer taps Go live (title optional)
   │
   ▼
App ── broadcast-control:prepare ──► Edge (verifies user, permission, device, destination)
                                       │ refresh token (Vault) → Google access token
                                       │ YouTube: use pooled stream key, insert broadcast (enableAutoStart)
                                       ▼
App ◄── rtmps URL + key (memory only) ─┘
   │
   ├─ Android: RootEncoder RtmpStream   ─┐
   ├─ iPhone:  HaishinKit RTMPStream    ─┼─► rtmps://a.rtmps.youtube.com/live2 ─► YouTube auto-starts
   └─ Laptop:  OBS (copy URL+key, or one-click)  ─┘
   │
   └─ poll session state (DB, Realtime) ── reconcile job observes YouTube → session.live
```

### Design decisions

1. **Prepare at Go live, not at Preview.** The camera preview is local and free. YouTube resources are created only when the streamer commits. This removes the quota cost of abandoned previews and the "End or cancel show" dead end.
2. **`enableAutoStart: true`.** YouTube goes live as soon as media arrives, with no `transition live` call and no 65-second client polling loop. Keep `enableAutoStop: false`, so a brief network drop does not end the show; our End and recovery handle ending.
3. **Reusable stream key per channel connection (a small pool).** Keep one reusable `liveStream` per connection and add one more per concurrent org show. This saves about 100 units per show (no insert/delete). The per-show broadcast stays unique.
4. **Defaults.** Title = upcoming entry title → else "<display name> – Live" (ar/en). Description = profile bio line. Audio-only toggle is remembered per streamer.
5. **Upcoming Live is the same object for everyone.** Solo and org schedules both materialize a `broadcast_session` inside the preflight window. Go live attaches to the matching session, otherwise it creates an ad-hoc one. Concurrency stays enforced in SQL: 1 active per person, up to N per org.
6. **Long shows.** Extend `expected_end_at` while the session is live, or exempt `start`/reconnect of an already-live session from the window check (F10).
7. **Errors are typed end to end.** The Edge function returns a reason code, and the app maps each code to a specific message and action: reconnect channel, enable live on YouTube, quota exhausted → use manual key, and so on. "The operation could not be confirmed" is reserved for real ambiguity.

### Platform matrix

| Platform | Sender | Work |
|---|---|---|
| Android (all) | Native RootEncoder (exists) | Low-end profile (below), real-device matrix |
| iPhone / iPad | **New** native bridge with HaishinKit (supports RTMPS), same method-channel contract as `RtmpPublisherBridge` | `flutter create --platforms=ios`, needs **a Mac or macOS CI** (Codemagic / GitHub Actions macOS) because Windows cannot build iOS. Background: camera stops when the app is backgrounded (iOS rule); audio continues with the `audio` background mode. Info.plist camera/mic strings. |
| Windows / Mac / web (laptop) | OBS with server-issued URL + key (exists as the "OBS" toggle) | Clear 3-step guide, copy buttons, "waiting for OBS…" live detection. Optional later: OBS WebSocket one-click config. Browser-camera streaming would need a paid WebRTC→RTMP relay and is out of scope for v1. |

Note: streaming from our app is "encoder streaming", so YouTube's mobile-app 50-subscriber rule does not apply. The channel still needs live streaming enabled (phone-verified, about 24 h first-time wait). Surface `liveStreamingNotEnabled` as its own message with a link to YouTube Studio.

### Low-end device profile

- Pick the encoder profile from device class (Android `ActivityManager.isLowRamDevice`, RAM < 3 GB, or hardware encoder caps): **low** 854×480@24 fps, 1.0 Mbps, 64 kbps audio; **default** 1280×720@30, 2.5 Mbps; **audio-only** for very weak devices or networks.
- Enable RootEncoder's bitrate adapter (drop on congestion, recover slowly). Hardware encoder only.
- During live, show chat as a lightweight list and do not mount the YouTube WebView on the sender device (already partly done). Keep the screen on, and release the camera on End or background.

## 4. Phases (each ends with a commit, per CLAUDE.md)

| Phase | Scope | Exit gate |
|---|---|---|
| **P0 — Unblock (today)** | Deploy the F1–F4 fixes. New APK. | Owner phone: Go live → visible on YouTube + Hadayah viewer → End → replay. Logs show reason codes. |
| **P1 — Google readiness** (start now: calendar time, not code) | Own domain for the OAuth callback (F6), privacy policy and terms URLs, brand + sensitive-scope verification for `youtube.force-ssl` (F5), YouTube API compliance audit + quota extension request (F7). Until approved: reconnect weekly, test users only. | Consent screen shows "Hadayah", no unverified warning, refresh token survives more than 7 days, quota raised. |
| **P2 — One-tap flow** | Decisions 1–4 and 7: optional title, prepare-on-Go-live, autoStart, reusable key pool, typed errors, manual-key fallback restored. | Solo: 1 tap with no title. Org: 2 members live at the same time on one org channel. Invited: switches destination. Quota per show ≈ 150 units (broadcast insert + bind + complete) plus reads. |
| **P3 — Upcoming Live unification** | Decision 5 + F10. | A scheduled solo show prefills and attaches. A 90-minute show survives a reconnect at minute 70. |
| **P4 — Low-end + Android device matrix** | Encoder profiles, adaptive bitrate, real phones (one low-end, one mid-range, one recent) on Wi-Fi and 4G. | No crash or ANR in 30-minute shows; recovers from a 20-second network drop. |
| **P5 — iOS** | Platform scaffold, HaishinKit bridge, background audio, macOS CI, TestFlight. | iPhone: Go live / End / audio-only / reconnect on a real device. |
| **P6 — Laptop polish** | OBS guide + live detection on Windows/web. | A first-time user reaches live in OBS from the in-app guide alone. |

## 5. Process rule going forward

Provider contract fixtures must come from **recorded real YouTube responses**, never invented values. Before any streaming change is called done, one real phone → YouTube round trip is required, and the result is recorded in `brief/evidence/`.
