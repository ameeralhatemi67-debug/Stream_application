# Owner retest: three-city map on SM-S936B

About 30 minutes. This uses a **separate test app** (`sa.hadayah.streamer_app.maptest`), so your Wave 4 app, its data and your sign-in are not touched. It appears as a second "Hadayah Live" icon; uninstall it afterwards.

Record for each step: pass/fail, a screenshot, and anything odd. Note the phone's Android and One UI version (Settings > About phone > Software information).

## 1. Build and install (on the PC, from `project/` in the branch worktree)

```powershell
flutter build apk --profile --target-platform android-arm64 --android-project-arg=streamerTestId=maptest --dart-define=SUPABASE_URL=http://127.0.0.1:9 --dart-define=SUPABASE_ANON_KEY=local-placeholder-not-a-key
```

```powershell
adb install build\app\outputs\flutter-apk\app-profile.apk
```

This build has no backend on purpose (no venues, offline chip shown). Do **not** use `adb install -r` on your real app's package.

## 2. First launch with no internet (A01)

1. Turn on Airplane mode (Wi-Fi and mobile data off) **before** opening the test app for the first time.
2. Open it: Continue as Guest > agree > enter a name > Enter. It should reach the feed within about 2 seconds.
3. Open Spatial Map. Expect streets, water and the names Dammam, Dhahran, Al Khobar within about 2 seconds, and a small "Offline · …" line at the top.
4. Pick each city in the city menu; then zoom in as far as it goes somewhere you never looked before (e.g. Al Aziziyah, King Fahd airport). Expect street names and buildings, never grey "no data" squares; zoom stops by itself.
5. Tap عربي. Arabic street and place names should be joined properly, not boxes. The map should stay where it was.

## 3. Restart and reboot (A02)

Close the app from Recents, reopen (still offline) and repeat step 2.3. Reboot the phone, keep Airplane mode on, reopen and repeat.

## 4. Movement limits and layout (A08-A10, A12)

1. Try to drag and pinch far out toward Riyadh or the open sea: the map should stop at the Eastern Province edge; two-finger twist should not rotate.
2. Double-tap to zoom, tap the "four arrows" button: it returns to all three cities.
3. Rotate the phone to landscape and back: no crash, controls reachable.
4. Settings > Display > Font size to the largest: labels grow, the © OpenStreetMap line and the info button stay visible.
5. Turn on TalkBack: move through search, city menu, topic menu, the two round buttons and "© OpenStreetMap"; each should be announced. Turn TalkBack off.

## 5. Credits and details (A13)

Tap the (i) next to © OpenStreetMap: it should show map date 2026-09-26, "not official city boundaries", and "Licences and sources" readable offline. Tapping © OpenStreetMap should try to open a browser (fails offline; that is fine).

## 6. With your usual test account (optional, A14/A15/A17/A19)

Only if you choose to: rebuild step 1 with your own non-production `--dart-define-from-file`, install the same test id, then:

1. Map shows current venues; turning Wi-Fi off keeps the streets and shows saved venues with a date, no LIVE badges.
2. Open a live venue from the map, return: the map is where you left it; no audio keeps playing.
3. Apply > location step: tap the pin button, tap a spot, "Use This Location". The typed venue name must stay as you typed it; the city menu must not change; "Pinned point: …" shows the coordinates. Try once with Airplane mode on.

## 7. Clean up

```powershell
adb uninstall sa.hadayah.streamer_app.maptest
```

Send the screenshots and notes back; they fill the SM-S936B column in `ACCEPTANCE_RESULTS.md`.
