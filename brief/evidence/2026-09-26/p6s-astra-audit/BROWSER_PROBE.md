# Chrome adapter probe

E3 observation, 2026-09-26. Executed in real Chrome through the browser UI on `http://127.0.0.1:55890`, using `project/tool/p6s_browser_probe.dart`. No backend credentials or production defines. This small app instantiates the actual YouTubePlayerAdapter; it does not replace it with the layout-test stub.

The page is explicitly labelled “AUDIT HARNESS — no live broadcast”. It uses the YouTube API documentation's reference video `M7lc1UVf-VE` deliberately. The production fallback to that sample remains removed.

1. Before the web reload fix, the real iframe loaded the exact reference video on youtube-nocookie. The displayed adapter event was `live` even though autoplay was disabled and the thumbnail still showed Play.
2. Clicking Change watch ID changed the embedded URL to `abcdefghijk`, but the app drew “Connecting to live feed... / Negotiating with the broadcast server.” over it.
3. Changing back to the valid reference ID left that same cover in place. The installed web implementation sets iframe.src and has no page-finished callback to clear the app's loading flag.
4. Restarted the local server with the fix and reloaded Chrome. Initial event was `paused`, meaning no confirmed playback, and the YouTube thumbnail/control was visible.
5. Changed the watch ID away and back. Accessibility state showed the requested iframe URL each time, with no app connecting cover.
6. Clicked the real YouTube Play control. The embedded controls responded; later accessibility state showed changing captions from the reference video. This proves the input reached that embedded player and it played reference content in this browser.
7. Clicked Remount muted. A fresh iframe appeared with `mute=1` and the original watch ID; the app did not claim playback. This verifies the requested mute parameter, not audible mute or synchronization of Chrome's built-in mute back to Flutter.

The Flutter regression separately puts a tap-sensitive player under the actual room overlay and proves center taps reach it when app transport is unavailable. Another regression proves accepted command dispatch alone does not change play state. The JavaScript VM test executes the generated native HTML script against a controlled SDK stub.

Limits: this was not a physical Android run, an authenticated whole-room browser run, an OBS/phone nonce test, or a test of Android fullscreen retention. Browser accessibility inspection is not a TalkBack usability test. Those remain in E4_RETEST_SCRIPT.md. The temporary browser tab and local server were closed after the probe.
