# Verification record

All commands ran in the isolated worktree `C:/Users/User/.codex/worktrees/p5-basemap-spike/Streamer_app`, from `project/` unless stated. Results below are from this session only; no historical counts are reused. Raw artifacts are in `raw/`, `screenshots/` and [pack-validation.json](pack-validation.json).

## Environment

| Item | Value |
|---|---|
| Flutter / Dart / DevTools | 3.41.2 (framework 90673a4eef, engine d96704abcc) / 3.11.0 / 2.54.1 |
| Windows | 10.0.26200.9550 (Windows 11 Home Single Language), `flutter devices` |
| Chrome | 153.0.8010.54, driven headless through puppeteer-core 24.43.1 (`raw/chrome_driver.js`) |
| Android toolchain | SDK `D:/app/Android/Sdk`, build-tools 37.0.0, compile/target SDK 36. **No device or emulator attached** (`adb devices` empty, `flutter emulators` none). |
| Backend config for app runs | `--dart-define=SUPABASE_URL=http://127.0.0.1:9` (closed/unsafe port: backend deliberately unreachable) and a placeholder anon key. A first web build pointed at `127.0.0.1:54321`, where a local Supabase stack answered 401 to the placeholder key; it was switched to port 9 so that stack is not touched. `dart_define.local.json` was never read. One extra build used `http://10.255.255.1` (non-routable) to test a black-holed backend. |

## Dependencies (from `pubspec.lock`)

| Package | Before | After |
|---|---|---|
| flutter_map | 7.0.2 | **8.3.2** (sha256 `9bbe5472…d767f`) |
| flutter_map_vector_tiles | - | **2.9.0** (sha256 `77176ea7…977a8`) |
| flutter_map_cancellable_tile_provider | 3.0.2 | removed (no imports) |
| crypto / web | transitive | direct, 3.0.7 / 1.1.1 |
| dio, dio_web_adapter, logger, polylabel | transitive | removed; `dart_polylabel2` 1.0.0 added transitively |
| integration_test (dev, SDK) | - | added for the real-engine render test |

FlutterMap 8 migration: the only compile breaks were `MapCamera.project/unproject` (now `projectAtZoom/unprojectAtZoom`, `Offset`). All FlutterMap callers (Spatial Map, picker, cluster layout, models) were reviewed.

## Pack build and validation

| Step | Result |
|---|---|
| go-pmtiles | v1.31.2, commit a3e4951e; release zip SHA-256 `a658baa4…85a1` matched the GitHub release digest |
| Source build | `20260926.pmtiles`, 138,339,871,890 B, b3sum `01bd8808…4c45`, version 4.15.2 (build-metadata.protomaps.dev) |
| Dry runs | bbox 49.80,26.00,50.33,26.65 -> 10 MB; 49.70,25.95,50.35,26.70 -> 11 MB; final 49.70,25.95,50.45,26.80 -> 12 MB transferred |
| Candidates | v1 10,985,214 B (east 50.35/north 26.70), v2 11,598,190 B (east 50.45), **v3 11,919,559 B** (north 26.80, shipped). v1/v2 were superseded when the viewport tests showed the overview could not be framed below the controls on wide/tall canvases. |
| `pmtiles verify` | pass (structure only) |
| `validate_tricity_pack.py` | **PASS**: 8,298 slots z0-15, 0 missing, 0 decode errors; 15/15 controls with roads (Khobar corniche, Aqrabiyah, Rakah, Aziziyah, causeway approach; KFUPM, Aramco residential, Ithra, Dhahran Mall; Dammam corniche, Faisaliyah, Adamah, Shatea, 2nd Industrial City, King Fahd Intl Airport); 386 named places |
| Name coverage (sample, z15 controls) | Road names exist but English/Arabic translations are sparse (e.g. Dammam corniche 24 roads, 7 `name:ar`, 10 `name:en`); the style falls back to the local `name`, never machine translation |
| Committed bytes vs manifest | `git show HEAD:…` SHA-256 equals the manifest for pack, styles and NOTICE (`.gitattributes` `-text`) |

## Automated checks

| Command | Result |
|---|---|
| `flutter analyze` | **No issues found** at `5e10678` |
| `flutter test` (full) | **727 passed, 0 failed** at `5e10678` (earlier checkpoints: 725 at `41cf23d`/`47ed6f8`) |
| New/changed test files | `map_viewport_policy_test.dart` (8), `map_pack_test.dart` (17, real shipped bytes incl. real tile reads for all three cities, corrupt/truncated/missing/incompatible fixtures, local-only style rule, web state machine with a fake store), `map_tricity_widgets_test.dart` (9: screen states, dropdown/search agreement, rotation off, zoom limits, details sheet, Arabic layout, directions failure, picker outside/inside, step-4 main and branch flows), updated `spatial_map_test`, `map_p5_presentation_test`, `live_stream_test`, `playlist_and_audio_polish_test` |
| `layout_sweep_test.dart` map cases | pass: 7 sizes x text scale 1.0/1.3/2.0 x en/ar (found and fixed a 0.007 px overflow in the new empty notice at 320 px, scale 2.0) |
| `node brief/tools/gates.mjs` | **0 failing** at tip and at baseline. G3 first flagged the copyright sign and G6 flagged an `addText('…')` warm-up string; resolved by sourcing the visible credit (with the sign) from the pack manifest and naming the non-UI string. No gate or allowlist edited. |
| Style compile | `ThemeReader` warnings: 0 (en and ar, all scales) |

## Builds

| Build | Result |
|---|---|
| `flutter build web --release` (placeholder backend) | success (several times; final at the tip's code) |
| `flutter build apk --profile --target-platform android-arm64 --android-project-arg=streamerTestId=maptest` | success; package `sa.hadayah.streamer_app.maptest` (aapt2); clean build 76,783,749 B, SHA-256 `bc89fd5f…53a4` |
| Baseline APK (same command without the suffix, at `7b54cb5`, fresh worktree) | 63,063,482 B, SHA-256 `88ca3105…149a`, package `sa.hadayah.streamer_app` |
| Release APK/AAB | **not built**: release signing fails closed without the owner's `key.properties` (gate G8); no production credentials were used |
| Windows | `flutter test integration_test/map_render_test.dart -d windows` built and ran the app (debug) |

## Real-engine runs

**Windows (debug integration test, real pack, real isolates, backend offline)** — `screenshots/windows/`, `map-render-results-windows.json`: ready in 1,634 ms (verify+open 1,025 ms), overview zoom 10.77, request for zoom 30 clamped to 18, request for zoom 2 refused (stays 10.77), camera unchanged across the Arabic switch, 0 style warnings. Arabic labels join correctly with Windows system fonts.

**Chrome 153 (release web build, local static server)** — `screenshots/chrome/`:

| Run | Observation |
|---|---|
| G0 first render | Streets, water, labels from same-origin pack only. Arabic labels were tofu (`G0-01`): the package caches shaped text before the Noto Arabic fallback font loads. Fixed by rebuilding the layer on the engine font-change signal (`G0-02`). |
| Network (backend unreachable) | Map data: only `manifest.json`, `basemap.pmtiles`, `style-en/ar.json`, `NOTICE.txt` from the site origin; CanvasKit and Roboto from gstatic (engine, app-wide); `raw/net-G0-online-backend-unreachable.json` |
| Preparation | 31 entries incl. pack, both styles, notice, i18n, CanvasKit, Roboto, Noto Sans Arabic (warmed even though that visit only showed English) |
| Offline cold start | Server stopped **and** Chrome relaunched with `--host-resolver-rules=MAP * ~NOTFOUND`: app shell boots, guest entry reaches feed in ~0.5 s, map renders all three cities; every response `fromServiceWorker`; `raw/net-A03-offline-final.json` |
| Never-visited origin offline | `127.0.0.1:8765` in the same browser: "This site can't be reached" (expected browser limit) |
| Eviction | Deleting the stored pack entry: honest "map can't be shown" card, credit still visible; details say the browser removed the saved map and offer Prepare/Remove |
| Interrupted update | Readiness marked as an older pack, server stopped, Prepare tapped: "Saving stopped…", live cache still 31 entries with its record, staging removed (`A05-01`). An earlier run exposed that the worker answered preparation from the old cache; fixed in `47ed6f8` and re-verified. |
| Blocked storage | A long profile path made Chrome's CacheStorage throw an internal error; the app showed "This browser window can't save the map" (`A06-01`) |
| Saved venues (synthetic, `raw/seed-saved-venues.js`) | 5 in-domain pins, Riyadh and (0,0) records excluded; a 3-venue cluster in Al Khobar; same-coordinate pair ends in "2 venues here" list at maximum zoom; offline search finds only in-domain saved venues |
| Black-holed backend (`10.255.255.1`) | guest Enter to feed in 524 ms: the analytics dependency did not block in Chrome; no code change made (not demonstrated) |

## Round 2 re-check (2026-09-27, after critic round 1)

All in the same worktree. Tooling: `raw/chrome_driver.js` (puppeteer-core 24.43.1 against the installed Chrome 153, headless, 412x860 at DPR 2), `raw/spa_server.py`, and `raw/hang_server.py`, which accepts connections and never answers.

| Command / run | Result |
|---|---|
| `flutter analyze` at `4b7a84c` | **No issues found** |
| `flutter test` (full) at `4b7a84c` | **732 passed**, 0 failed |
| `node brief/tools/gates.mjs` at `4b7a84c` | **0 failing** |
| `flutter build web --release --dart-define=SUPABASE_URL=http://127.0.0.1:9 --dart-define=SUPABASE_ANON_KEY=local-placeholder-not-a-key` | success at `d11e9f2` (the build left by the paused session, checked: its worker and page match the source) and again at `4b7a84c` |
| `flutter test integration_test/map_render_test.dart -d windows --dart-define=MAP_RENDER_OUT=<evidence>/screenshots/windows-r2` | pass: ready 1,657 ms (verify+open 1,082 ms), overview 10.76, zoom 30 -> 18, zoom 2 -> 10.57 (minimum), 0 style warnings (`windows-r2/map-render-results-windows.json`) |
| `flutter test integration_test/picker_render_test.dart -d windows --dart-define=MAP_RENDER_OUT=...` (new) | pass: pack ready; "No point chosen yet"; **Pin the map centre** pinned exactly the camera centre `26.253614, 50.216742` (inside the domain); Arabic layout; "This venue has no pinned location yet…" for (0,0) (`windows-r2/picker-render-results-windows.json`, `P01-P04`) |

| Chrome run (profile) | Observation |
|---|---|
| Long session then Save, build `d11e9f2` (`p5r2`) and `4b7a84c` (`p5r3`, fresh) | Guest onboarding in English, then `performance.clearResourceTimings()` and 320 fetches of `version.json?longsession=N`. Timing buffer 250 (full) with no `main.dart.js`, CanvasKit or Noto Arabic; the page observer held 341 URLs. Map opened, the prompt appeared, **Save**: "Saving… 28 of 350" and then "Ready". Cache: 351 entries incl. every required shell, engine, font and map file (`raw/r2/cache-after-long-session.json`; `d11e9f2-cache-after-long-session.json` for the first build) |
| Offline cold start, Arabic | Server stopped, relaunch with `--host-resolver-rules=MAP * ~NOTFOUND`: page load 0.5 s (`d11e9f2`) / 1.3 s (`4b7a84c`); Arabic onboarding, map: 29/29 responses from the service worker, only `127.0.0.1:9` failed (`raw/r2/net-offline-ar-cold-start.json`). Joined Arabic city, district and street labels at overview and deep zoom; details sheet says "ready" (R3-04..R3-07). Console: backend `ERR_UNSAFE_PORT` lines and one expected worker update-check error |
| Hanging network (connects, never answers) | `d11e9f2`: navigation answered from the cache at 4.26 s, but CanvasKit/`main.dart.js` were requested only at 8.4 s. Cause: the generated `flutter_bootstrap.js` passed `serviceWorkerSettings`, so the loader registered `flutter_service_worker.js` and waited its 4 s timeout. `4b7a84c` (minimal `web/flutter_bootstrap.js`, per the Flutter web initialization docs): `main.dart.js` at 4.70 s, 17/17 from the worker (`raw/r2/net-hanging-network.json`, `d11e9f2-net-hanging-network.json`) |
| Online revisit after preparing | `d11e9f2`: `flutter_service_worker.js` fetched (200 then 304) at the same scope; the offline worker stayed active in this run. `4b7a84c`: no request for it, one navigation, offline worker active and in control, copy ready (`raw/r2/online-revisit-registration.json`, `server-online-revisit.log`) |

Not re-run in round 2: the pack validator (pack bytes unchanged, SHA-256 `1deb87ea…6a87`), the APK build (`4b7a84c` changes only web start-up and a test file), the eviction, interrupted-update and blocked-storage Chrome runs. `d11e9f2` changed the preparation code these depend on (required-file list, incomplete failure, eviction prompt), so after round 1 they are covered only by the fake-store unit tests. The prompt reappearing after eviction was not exercised in Chrome.

## Round 2 repair pass (2026-09-27, after critic round 2)

Code tip `a57dda7` (`ad28998` round-2 repairs, then `a57dda7`, found during this re-check).

| Command / run | Result |
|---|---|
| `flutter analyze` at `a57dda7` | **No issues found** |
| `flutter test` (full) at `a57dda7` | **734 passed**, 0 failed (2 new: unpinned-venue sheet; web prompt Save/fail/ready) |
| `node brief/tools/gates.mjs` at `a57dda7` | **0 failing** |
| i18n symmetry | 1,476 keys in `en.json` and `ar.json`, none missing |
| Windows `picker_render_test.dart` at `ad28998` | pass; new centre mark and wording (`screenshots/windows-r3/P01-P04`) |
| `flutter build web --release` (placeholder backend) | success at `ad28998` and at `a57dda7` |

| Chrome run (profile, build) | Observation |
|---|---|
| Long session then Save (`p5r4`, `ad28998`) | Ready; details now read "saved in this browser and open without internet" (R4-02); 32 stored files instead of 351: one `version.json`, not 320 query copies; the prompt's dismissal key was **not** written by Save (`raw/r3/ad28998-cache-after-save.json`) |
| Eviction (`p5r4`) | Deleting the stored pack, reloading and opening the map shows "The browser removed the saved offline map. Save it again while connected." with Save; the first view is re-framed below it (R4-03) |
| Interrupted re-preparation (`p5r4`) | Readiness marked as an older pack: the prompt returns (R4-04). Server stopped, Save: "Some app files could not be saved, so nothing was marked ready…" with Prepare; the live copy keeps its 26 files and its old record, and no staging cache is left (R4-05, `raw/r3/ad28998-interrupted-save-caches.json`) |
| Hanging network (`p5r4`, `ad28998`) | Page from the worker at 4.06 s, `main.dart.js` at 4.45 s, 16/16 from the worker |
| Offline Arabic cold start (`p5r4`, `ad28998`) | The first map view uses the mirrored insets (R4-07, same framing as the overview button). **Found:** after two re-saves the built-in avatars and logo were no longer stored (a save keeps only what that visit observed and drops older files), so 69 image requests failed offline. Fixed in `a57dda7` |
| Save and re-save (`p5r5`, fresh, `a57dda7`) | First save 36 files; re-save after an older-pack mark 35 files; both include 4 avatars, 6 SVGs, `main.dart.js`, Noto Sans Arabic and the pack (`raw/r3/first-save.json`, `re-save.json`) |
| Offline Arabic cold start (`p5r5`, `a57dda7`) | Avatars render on the offline onboarding (R5-03); map first view mirrored (R5-04); 29/29 responses from the worker, only `127.0.0.1:9` failed |

Not re-run at `a57dda7`: the hanging-network start (the worker is unchanged since `ad28998`), the Windows map render and the APK build (no native or map-render change after `d11e9f2`, apart from the picker, which was rendered at `ad28998`).

## Not verified here

Physical SM-S936B (no device), Android emulator (none), TalkBack/keyboard traversal on device, frame/memory profiling, text-scale on device, mini-player coexistence and map -> live -> map with a real stream, backend-reachable runs, Edge/Firefox/Safari, iOS. Windows timings are from a debug build and are not release performance figures.
