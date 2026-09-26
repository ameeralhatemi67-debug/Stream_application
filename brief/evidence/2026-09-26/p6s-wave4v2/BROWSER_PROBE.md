# Real Chrome adapter probe (E3)

Chrome153.0.8010.54. Source `5162addcc8a659d3c66dafde3f243565cc85acf7`; dedicated loopback server55990, existing `tool/p6s_browser_probe.dart`, no backend/auth/keys. Command from project: `flutter run --no-pub -d web-server -t tool/p6s_browser_probe.dart --web-hostname 127.0.0.1 --web-port 55990`.

Observed through the real Chrome UI:
- Actual youtube-nocookie iframe displayed the official API sample thumbnail and accessible native Play. Adapter status correctly stayed **unconfirmed**, not paused/live.
- Clicking native Play advanced the sample to2 seconds, then10 seconds; native Pause changed its button to Play at19 seconds. This verifies real iframe input and visible VOD progress, not streaming AV or audio audibility.
- Changing watch ID navigated to `abcdefghijk`; YouTube itself displayed Video unavailable. The app did not cover that error or claim playback.
- Restoring the sample ID and Remount muted returned a usable native Play surface. Screenshot: browser-remount.png. URL parameters requested autoplay0/mute1, but after user Play the native UI showed a Mute button; actual sound was not measured and persisted mute cannot be claimed from query parameters.
- One screenshot request timed out; the later remount capture succeeded.

The harness omits the full room, so its screenshot does not prove room tap overlays, live authorization, retry exhaustion, network switching, or physical acceptance. Chrome has no playback confirmation bridge in this adapter. Native-handshake suppression on Android and full-room physical AV remain NOT RUN. The browser probe tab and its own Flutter server were closed afterward.
