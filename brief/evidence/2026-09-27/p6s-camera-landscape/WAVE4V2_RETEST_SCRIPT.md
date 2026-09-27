# Start here: camera / landscape confirmation

**P6 and P6S are not accepted.** Run these fixes first, then the checkpoint regressions below. Use both physical phones as sender; observe received media on a separate phone and Chrome. Wave 4v2 names the test round for Hadayah.

## Build and setup once

Read README for the source/artifact identity. The provided isolated APK has ID `sa.hadayah.streamer_app.wave4v2`, label `Streamer Wave4v2`; it does not replace Hadayah. It is a local no-key diagnostic build, not a configured Google/YouTube acceptance app. Do not test the older installed app and attribute its results to this source.

A configured end-to-end candidate requires the disposable Google OAuth/test YouTube/API/ingest setup in [the preserved setup instructions](../../2026-09-26/p6s-wave4v2/HANDOFF.md). Use the new source commit from this README for the build commands there. Do not copy/open `project/dart_define.local.json`. No hosted database operation is requested. Installation/replacement of any existing test app remains owner-coordinated; preserve its data.

From this worktree's `project/`, after preparing ignored `../brief/.runtime/wave4v2/defines.acceptance.json` with dedicated test configuration:

```powershell
flutter build apk --debug --no-pub --android-project-arg=wave4v2TestApp=true --dart-define-from-file=../brief/.runtime/wave4v2/defines.acceptance.json
flutter build web --no-pub --dart-define-from-file=../brief/.runtime/wave4v2/defines.acceptance.json
Get-FileHash -Algorithm SHA256 build/app/outputs/flutter-apk/app-debug.apk
```

Do not run both builds at once. Record the resulting source commit, APK hash, config hash (not contents), package ID, backend identity, phone model/OS, WebView/Chrome versions, locale, font size, network and watch/session IDs in WAVE4V2_ACCEPTANCE_RESULTS.md. Never include stream keys. Use a dedicated test broadcast and an approved sender, separate viewer and admin. Keep a visible clock and a paper marked **TOP ↑**, a circle and a square in the scene. Speak a changing number so freeze, delay and duplicate audio are obvious. Use YouTube's fit/default view when judging bars; viewer zoom can hide them.

## Short fix confirmation (about 15–20 minutes per phone, excluding setup)

1. **C01 — rotation, medium preset.** Start rear-camera portrait. Capture sender preview and independent received video once it catches up; record normal YouTube delay. Portrait may have side bars inside the unchanged 16:9 encoded canvas. Rotate left, hold at least 15 seconds or until the new spoken number reaches the viewer; repeat portrait, then right. Repeat the cycle three times. Both preview and received image must be upright, TOP must point up, circles remain round, and landscape received video fills 16:9 with no source side bars. No new session, duplicate audio, camera freeze or reconnect due to rotation. Stop the case and record FAIL if either destination is wrong. Do not mistake delayed portrait frames for a failure; compare the spoken identifier.
2. **C02 — sizes/ratios.** Repeat a short left/right check at Low (640x360) and High (1920x1080), starting a separate session when changing quality. Repeat on the second phone. Capture the full viewer, not just a cropped screenshot. A 4:3 camera source should crop top/bottom to fill 16:9; a wider source crops sides. Portrait is fitted. Wide phone previews can crop more than a 16:9 receiver. Stop if stretched or unsupported; record exact preset/device, not a blanket all-phones PASS.
3. **C03 — landscape controls/chat.** With normal touch accessibility, tap empty video. Exactly End at top-left and settings/chat at top-right appear; tap again and they disappear. There is no solid header, title, bitrate badge or fullscreen icon. Reveal, open chat, confirm it extends close to the bottom safe area. Repeat in Arabic: End remains physically left. Native preview must keep moving throughout. Recovery/error messages may remain visible when needed.
4. **C04 — no landscape keyboard.** In portrait type an unsent chat draft and leave the real software keyboard open. Rotate; keyboard and composer/send controls disappear, chat remains readable. Tap/long-press chat, including Edit on your own message: landscape must never offer an editable field. Rotate back: draft is intact. Repeat as viewer and moderator/admin, including an Edit dialog opened in portrait and a studio opened from the video screen. No draft may be silently sent. Record sender and each viewer role separately.
5. **C05 — settings fit.** Landscape → three dots → scroll from first to last row. Mute and Hide video remain reachable; status is available here. Try largest device font and en/ar, short landscape phone and a short laptop window. No yellow/black overflow, clipped final row or inaccessible action. Opening full stream settings from the video asks for portrait; closing the prompt returns to the running preview. Recheck normal portrait typing.
6. **C06 — front deferred.** Tap front-camera Coming Soon. A visible localized explanation opens, the rear image remains unchanged in preview and viewer, and audio/session continue. Close it and repeat after reconnect. No front camera should activate.
7. **C07/C08 — safe End.** Hide controls; system Back must ask before ending. Cancel and continue. With TalkBack/keyboard focus, End stays discoverable and focused controls are not hidden by a media tap. Reveal and end normally. Sender stops; independent Android/Chrome viewers learn End without refresh (healthy room target 30 seconds, discovery/map target 40 seconds). Record sender stop, server-session state and each viewer's actual elapsed time separately. Approval/primary role remain correct; camera/mic/service resources release.
8. **C09/C10 — transition regressions.** Briefly interrupt sender network; rotate while reconnecting and end/transfer while settings/confirmation is open. No old session restarts. In the unconfirmed Chrome/native readiness case, the eye toggle and real player controls remain usable; Retry must follow current session truth. Use the existing controlled readiness recipe linked below, not a blocked iframe.

## Checkpoint regression and missing evidence

C01–C10 do not close the checkpoint. Run the [existing F01–F12 / R01–R12 / P01–P06 script](../../2026-09-26/p6s-wave4v2/WAVE4V2_RETEST_SCRIPT.md) on this new candidate and fill the matching rows in **this folder's** results file. All fresh rows are NOT RUN. F07 front operation is superseded by C06 / the explicit owner deferral; all rear-camera rows remain required.

Required coverage includes ordinary/admin End and role retention; sender/viewer drop, Wi-Fi/cellular switch, retry exhaustion and manual retry; End/block/transfer/revocation/sign-out during recovery; same-watch restart; real readiness failure with reachable iframe; mute/pause intent; Hide/Show/End-and-block and relist rules; channel/account validation; chat/report/mute/block/admin/account-state checks; unavailable modes. Old physical PASS labels do not count for this build.

Direct phone A, direct phone B and OBS each need a >=15-minute audiovisual run with changing identifiers and an interruption. These alone require >=45 minutes of stream time; allow another 45–90 minutes for the broader checks, more if provisioning or faults need diagnosis. Record Home/lock separately from foreground reconnect, temperature, gaps and camera indicator during Hide video (camera currently remains active).

Do not retry a failing case repeatedly without preserving its first evidence. Record FAIL/NOT RUN honestly. D8 remains a release blocker even if these UI/video cases pass. Assess P6 and P6S separately using P6_P6S_CLOSURE_MATRIX.md.
