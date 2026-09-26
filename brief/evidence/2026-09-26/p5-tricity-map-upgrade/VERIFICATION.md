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

## Not verified here

Physical SM-S936B (no device), Android emulator (none), TalkBack/keyboard traversal on device, frame/memory profiling, text-scale on device, mini-player coexistence and map -> live -> map with a real stream, backend-reachable runs, Edge/Firefox/Safari, iOS. Windows timings are from a debug build and are not release performance figures.
