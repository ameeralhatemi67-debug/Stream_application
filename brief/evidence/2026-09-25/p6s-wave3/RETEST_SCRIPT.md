# Owner retest script: P6S wave 3 (two phones, Chrome, YouTube, Local)

This is the E4 run. Nothing in the branch counts as physically accepted until these rows pass on your devices. Record PASS or FAIL for each row, the time, and a screenshot or short recording. Keep one evidence folder per run.

## Before you start

- **Build.** Record the commit (`git rev-parse HEAD` on the branch or the merge). Build the Android APK from that commit.
- **Backend.** Use a **non-production** Supabase project with migration `20260925100000_broadcast_sessions_and_live_controls.sql` applied. Do not apply it to production until the branch has been reviewed. Record the project reference, never its keys.
- **YouTube API key.** Build with the `YOUTUBE_API_KEY` dart-define so that the watch-link check can run. Without the key, every link is listed with the "not fully checked" note, and row 6 cannot pass.
- **Accounts.**
  - **C**: an approved broadcaster, signed in on Phone 1 and Phone 2. The approved application's YouTube handle must be the test channel.
  - **V**: a separate viewer account in Chrome. Not an admin.
  - **M**: a Master Admin, in a second Chrome profile.
  - **G**: a Google account that has never signed in to the app, for row 9.
- **YouTube.** Use a test channel. **Never screenshot or record the stream-key field**, in the app, OBS, Larix or YouTube Studio.
- **Nonce.** On camera, show a paper card with the current time and say a short spoken word, so that V can confirm it is the same broadcast and hears the sound.

Each row gives the expected result in three places:
- **Sender**: the phone or OBS doing the broadcasting.
- **Server**: M's Admin Hub live list and the audit log.
- **Viewer**: V in Chrome.

## Rows

| # | Steps | Sender | Server | Viewer |
|---|---|---|---|---|
| 1 | Phone 1: Studio → Phone → paste the key and watch link → 720p → Open Camera. Wait for LIVE. | "LIVE", with a real kbps figure. The **End broadcast** button is visible in portrait. | C is listed live with sender `phone_direct`. The session starts in the audit log. | V's feed or map shows C live within about 30 s. The room plays exactly this watch ID (card nonce and spoken word match). There is no sample video, and no other streamer's video. |
| 2 | Rotate Phone 1 to landscape. Tap the picture to hide the controls. | **End broadcast** is still visible and tappable. (Known gap D7: the transmitted picture does not rotate.) | No change. | Still the same broadcast, with no interruption. Record whether the picture looks rotated or letterboxed. |
| 3 | Phone 1: press system Back. Choose **Stay**. Then press Back again and choose **End broadcast**. | The first Back shows "End this broadcast?" and the note that background broadcasting is not available. Stay keeps sending. End stops the camera and leaves the screen. | The session ends as ended by the broadcaster. | Within about 20 s the room shows "ended", and the feed no longer lists C. |
| 4 | Transfer while someone is watching: go live on Phone 1 (row 1) while V is watching. On Phone 2, use "Use this device" to claim the broadcaster role. | Phone 1 leaves the broadcast screen and the camera turns off. Phone 2 does **not** go live by itself. | Phone 1's session ends with reason transfer. Only one device is primary. | V's room ends within about 20 s (no stale LIVE). The feed and map drop C within about 30 s. |
| 5 | Admin controls. C goes live again on Phone 2. M uses, in order: **Hide from app discovery** → check V → **Show in app discovery** → **End** → C tries to reconnect → go live again with a **new** watch link → M uses **End and block link** → C retries the same link. | After Hide, Phone 2 keeps broadcasting. After End, Phone 2 stops sending and does not relist when the encoder reconnects. With a new link it can go live again. After End and block, reusing that link is refused. | Each action appears once in the audit log. C stays an approved broadcaster and the device stays primary throughout (it is never demoted). | Hide: V's feed drops C, but V's open room keeps playing. Show: C is listed again. End: the room ends. |
| 6 | Wrong-link refusals (Encoder tab, "OBS on a computer"). Paste each of these as the watch link: (a) a regular uploaded video, (b) a finished past broadcast, (c) a live broadcast on **another** channel, (d) a mistyped ID, (e) the stream key itself. | Each is refused with its own message: (a) regular video, (b) already ended, (c) different channel, (d) not found, (e) looks like a stream key. The key is never shown back. | Nothing is listed. No session starts. | Nothing changes. |
| 7 | OBS on a laptop: start streaming in OBS to the test channel, then paste the watch link in the Encoder tab with "OBS on a computer" and Go Live. | The Encoder tab never shows or copies a stream key or ingest URL. A toast says the server accepted the video ID and that the app cannot see OBS. | Sender is `obs_laptop`. Ingest is shown as unknown (the app cannot observe OBS). | V sees the OBS scene and hears it. The nonce matches. |
| 8 | Another phone app (optional, for D6). Install Larix Broadcaster (record its version and any free-tier limits), point it at the test channel, then list it with "Another phone app". | The copy never calls the app OBS. The toast refers to "your phone app". | Sender is `external_phone`. | V sees Larix's camera, and the nonce matches. |
| 9 | Google sign-in refused. With sign-ups paused, on Phone 1 sign in with account G. | A dialog says that new sign-ups are paused and names the account that is still signed in (if any). There is no silent failure. | No new user is created. | — |
| 10 | Viewer playback. On a phone viewer (the Android app): play, pause, mute and full screen in the room, and rotate between portrait and landscape. Mute, then tap Retry (or reopen the room). Leave with the minimize button. In Chrome: use the YouTube player's own controls. | — | — | Phone: the room's buttons act on the real player (the video really pauses and mutes, and the icons follow). Rotating or going full screen does not restart the video. After Retry the viewer is still muted. Leaving shows a "Return to broadcast" shortcut saying playback stopped; tapping it reopens the room. No picture-in-picture is offered. Chrome: the room shows no play/pause/mute buttons of its own. |
| 11 | Local mode on Phone 1, then in Chrome on the laptop: Studio → Local. | Local is shown as unavailable, with the explanation. Nothing asks for an address or starts the camera. Tapping the button explains again and saves nothing. | Nothing. | Nothing. |
| 12 | Arabic: switch the app to Arabic and repeat rows 1–3 briefly. | The End button reads إنهاء البث, and the confirmation reads إنهاء هذا البث؟ with the البقاء / إنهاء البث buttons. No clipped or English-only labels in the studio or on the broadcast screen. | — | — |

## Recording

For each FAIL, write down:
- the row number;
- what each of the three places showed (Sender, Server, Viewer);
- the time;
- the build commit.

Do not paste keys, tokens or the contents of `dart_define.local.json` into the report.
