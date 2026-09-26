# Native SDK probe (E3, not physical acceptance)

Source c292db3. Fresh private AVD `wave4v2` in `brief/.runtime/wave4v2-avd`, emulator serial5586, Android16/API36 x86_64 Google APIs Playstore image. No existing emulator userdata or owner app was used. Two CPU cores,1536MB RAM, SwiftShader,720×1280 screen; `-no-window -no-audio -no-snapshot`. Both cameras use the emulator's synthetic pattern; host camera/microphone were not used.

Built `flutter build apk --debug --no-pub -t tool/wave4v2_native_probe.dart --android-project-arg=wave4v2TestApp=true`. Packaged ID was inspected with aapt: `sa.hadayah.streamer_app.wave4v2`, label `Streamer Wave4v2`, MainActivity in the original code namespace. Only this APK was installed on the new AVD; no owner-phone install.

FFmpeg listened only on `rtmp://127.0.0.1:55935/probe`; the probe used Android's host alias10.0.2.2. Receiver command: `ffmpeg -hide_banner -listen 1 -i rtmp://127.0.0.1:55935/probe -map 0 -c copy -t 60 brief/.runtime/wave4v2/native-received.mkv`. The fixture has no backend and explicitly returns true for local recovery authorization; it does not prove the app's server-authority path.

Actual observations:
- Camera ready at10.952s, RTMP live at21.002s. One live transition; no reconnect reported during the scheduled rotations, front-camera switch and video-hide toggle. Stop completed at56.727s. The fixture rotated at10/20/40s, switched camera at30s, hid video at50s and requested Stop at55s.
- Receiver contains H2641280×720, AAC,37.603s container duration and48 decoded video frames. Declared30fps is metadata, not measured delivery. The low actual frame count does **not** meet smooth-video acceptance.
- Extracted14s frame has portrait content fitted into the unchanged landscape canvas;26s frame shows the applied landscape transform. Synthetic camera pixels do not establish correct physical front/back orientation, crop or mirroring.
- Preview capture shows **System UI isn't responding**. The initial Android activity launch timed out. This low-resource emulator pass is limited and is not a successful native UX/continuity test. Cause of the System UI ANR is not established; do not dismiss it as proven host-only behavior.
- After Stop both camera devices were closed with no active client, and no broadcast service remained. Resource state files are saved. Receiver demux ended with I/O error after the sender closed, with the media file finalized.

Evidence: native-events.txt, native-output.json, native-preview.png, native-received-14s.png, native-received-26s.png, native-services-after-end.txt. Full receiver/camera logs and received MKV stay in ignored runtime; hashes are in identity.json. No physical AV, thermal, background, TalkBack or network-recovery result is claimed. The private emulator was stopped through its identified adb serial; its files remain for reproduction.
