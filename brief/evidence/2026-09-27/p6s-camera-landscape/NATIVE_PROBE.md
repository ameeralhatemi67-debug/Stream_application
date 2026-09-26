# Native receive probe — limited local evidence

The final probe used only the task's private Android 16 / API 36 x86_64 AVD `wave4v2`, serial `emulator-5586`, two cores/2 GB/SwiftShader, emulated rear camera and no host camera/audio. A local FFmpeg receiver listened on port 55935. No physical phone, Google account, YouTube ingest or hosted backend was used. The probe entrypoint bypasses normal application authorization only for its fixed emulator-to-loopback endpoint and is debug-only; it is not the acceptance application.

## Final source run

- Engine ready at 8.853 s, one Live at 14.197 s, stopped at 71.480 s. Timed actions: landscape left at 30 s, portrait at 40 s, front refusal at 45 s, landscape right at 50 s, Hide video at 60 s, End at 70 s. No second Live/retry event. See `native-events-final.txt`.
- Receiver: H.264 1280x720 and AAC 44.1 kHz stereo, 59.113 s container. **484 video frames**, video PTS 6.852–55.594 s, delivered **9.91 fps** across that interval, largest gap **1.00 s**. The advertised 30 fps is not observed delivery. See `native-output-final.json` and `frame-timing-final.json`.
- Visually inspected `received-final-5.png` and `received-final-34.png`: fitted portrait with side bars. `received-final-24.png` and `received-final-44.png`: opposite rotations, full-width landscape framing. The emulator's generated house scene stays fixed when Android display rotation changes, so its sideways house **does not establish physical uprightness or the sign of physical camera correction**. The real TOP-arrow test remains mandatory.
- `received-final-49.png` is black after Hide video. These filenames are FFmpeg input seek offsets, not action-clock timestamps. The container starts at 3.513 s; do not align filenames directly with probe action time. Audio track presence does not establish microphone quality or lip sync.
- After End, camera clients are empty (`native-camera-after-end-final.txt`), and there is no application foreground service (`native-services-after-end-final.txt`). That dump retains a historical System UI ANR record, not an active app service.
- `native-preview-final.png` shows the stopped probe behind **System UI isn't responding**. Cause remains unestablished. **This is not a native UX, smoothness, thermal, background or physical acceptance pass.** Final receiver exited on stream shutdown (FFmpeg records input I/O error at peer disconnect); the private emulator was then stopped. Neither port nor task processes remain active.

## Earlier attempts preserved

1. `native-packaging-failure.txt` / `native-failed-apk-hash.json`: Java helper under the Kotlin source directory was absent from the APK although compilation passed. Moving it to `src/main/java` fixed runtime loading.
2. `native-events-packaged.txt`, `native-output.json`, `frame-timing.json`, `received-*.png`: 127 frames, but framing remained portrait. `preview.display.rotation` was zero because Flutter used a virtual display. Final code receives the Activity's real display ID.

Both earlier attempts also encountered System UI ANR. Their screenshots and hashes remain evidence of failures, not final-source passes. The older September 26 native probe is preserved in its original folder as well.

## Reproduce without real services

From `project/`, build the native fixture using the same source as the candidate:

```powershell
flutter build apk --debug --no-pub --android-project-arg=wave4v2TestApp=true --target=tool/wave4v2_native_probe.dart
```

Use only a dedicated test emulator. Run FFmpeg before launching the installed fixture:

```powershell
ffmpeg -hide_banner -listen 1 -i rtmp://127.0.0.1:55935/probe -map 0 -c copy -t 80 received.mkv
```

Save app-PID-filtered WAVE4V2 events, camera/service dumps after End, ffprobe streams and actual frame timestamps, and received stills. Use a new filename for each attempt. Do not install this fixture over a configured acceptance app; its application ID is the same isolated test ID. Local automatic rotation is only a rendering/lifecycle probe. Follow WAVE4V2_RETEST_SCRIPT.md for actual device and YouTube evidence.
