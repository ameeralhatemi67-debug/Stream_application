# Acceptance results (A01-A19)

Rows first recorded at tip `5e10678`. **Round 2 update (code tip `4b7a84c`):** the round-1 repairs (`d11e9f2`) and the start-up fix (`4b7a84c`) were re-checked in Chrome and on Windows (see "Round 2 re-check" below and VERIFICATION.md). Rows A01, A04, A09 and A13 were relabelled PARTIAL (round-1 D10) because their Android cells are NOT RUN; an overall PASS now requires every applicable platform cell. Legend: **PASS**, **PARTIAL** (some required evidence present, some missing), **FAIL**, **NOT RUN** (no evidence; reason given), **N/A** (inapplicable by agreed scope; reason given). Mocked providers are never counted as rendering or persistence proof. SM-S936B is the required physical target; it was **not available** in this session, so every "Android physical" cell is NOT RUN and appears in [OWNER_RETEST_SCRIPT.md](OWNER_RETEST_SCRIPT.md).

| ID | Android SM-S936B | Chrome | Windows | Automated | Overall and notes |
|---|---|---|---|---|---|
| A01 first-use offline | NOT RUN (no device) | Web equivalent only (not the native case A01 defines): prepared origin, server down, DNS blocked, guest entry 0.5 s, all three cities render; re-checked in round 2 after a long session, in Arabic | PARTIAL: real engine renders the bundled pack with backend unreachable (integration test); not a fresh install with the network disabled before first launch | pack/local-only tests | **PARTIAL** — native first-launch-offline is the core claim and needs the phone run |
| A02 later offline cold starts | NOT RUN | PASS (two separate profiles/builds) | NOT RUN (process cold start offline) | - | **PARTIAL** |
| A03 browser prepare + cold start | N/A | PASS: 31 files, cold start offline from the service worker, never-visited origin fails as expected; `persist()` false in headless | N/A | fake-store state tests | **PASS (Chrome only)** |
| A04 missing/corrupt/incompatible | NOT RUN (on-device fixture) | PASS: evicted pack -> honest unavailable card, credit kept | - | PASS: flipped byte, truncation, missing pack/style/notice, edited style, schema 2, zoom 0-14, remote style rule, retry recovers | **PARTIAL** (unit + Chrome; the Chrome fixture was a browser eviction, not an invalid bundle; on-device fixture NOT RUN); invalid boundary asset N/A (no boundaries ship) |
| A05 interrupted update | N/A native: no update path, bundle replaced atomically by app install; app-version replacement on device NOT RUN | PASS: server killed during re-preparation -> failed, live copy + record intact, staging removed | N/A | fake-store failure test | **PASS for web**; optional remote-delivery portions N/A (remote hosting deferred by owner) |
| A06 storage pressure / eviction | N/A for low storage (native writes nothing); NOT RUN otherwise | PASS eviction + blocked storage message; QuotaExceeded NOT RUN (not injected) | N/A locked files (no writes) | - | **PARTIAL** |
| A07 reset, age, version | N/A native (nothing to reset) | PASS: remove (now with confirmation), older-pack record -> "not prepared" -> re-prepare; >90-day advisory implemented after the Chrome runs (unit-tested rule; UI not screenshotted) | - | PASS stale rule 90/91 days | **PARTIAL** (advisory UI not captured) |
| A08 legal zoom range | NOT RUN | PASS: min/mid/max screenshots, no missing-data tiles at 18, wheel beyond limits | PASS: zoom 30 -> 18, zoom 2 refused | PASS: 0.25-step sweep beyond both limits, corners inside extent | **PARTIAL** (no phone pinch/continuous video) |
| A09 every navigation path | NOT RUN | PASS dropdown, city search, cluster zoom, overview | PASS dropdown, overview, locale | PASS legal targets, focus refusal, dropdown/search agreement | **PARTIAL** (automated + desktop; phone NOT RUN); round 2: Arabic overview button honours the mirrored button inset (R2-05/R3-05), but the first view on opening the map uses the default left-to-right inset; deep links N/A (none target the map) |
| A10 resize / rotation / layout | NOT RUN (rotation) | desktop-size canvas only | PASS desktop (feasible canvas + side panel) | PASS 8 canvases incl. 915x412 and 1440x900; layout sweep 7 sizes x 3 scales x 2 locales | **PARTIAL**; known limit: phone landscape with the offline chip falls back to containment (overview slightly under controls) |
| A11 geometry / city identity | - | - | - | - | **NOT MET (deferred)**: no licensed municipal geometry; polygons and "municipal" claims removed; city names are views only |
| A12 labels, locale, RTL, a11y | NOT RUN (device, TalkBack) | PASS Arabic joining incl. deep-zoom street names; locale switch keeps camera | PASS Arabic | PASS Arabic widget layout, semantics labels on credit/chip/cluster/picker | **PARTIAL** (no TalkBack/keyboard traversal, no device text scale) |
| A13 attribution / details | NOT RUN | PASS in online/offline/unavailable/Arabic states; round 2 offline Arabic details (R3-07) | PASS | PASS widget | **PARTIAL** (desktop + automated; phone NOT RUN) |
| A14 backend vs basemap | NOT RUN | PASS pack ready x backend unreachable; pack unavailable x backend unreachable | PASS pack ready x backend offline | PASS pack unavailable x online/offline | **PARTIAL**: pack ready x backend current not run (no reachable backend) |
| A15 moderation, caches, out-of-area | NOT RUN | PASS saved-venue domain filter and offline search (synthetic) | - | PASS existing moderation/null-vs-empty tests + domain filter | **PARTIAL**: reconnect-removal with a live backend not run |
| A16 clusters and coordinates | NOT RUN | PASS cluster and max-zoom member list | - | PASS 1,000-point projection count, stable ids | **PARTIAL** (no profiling) |
| A17 map -> stream -> map | NOT RUN | NOT RUN | NOT RUN | existing route guards untouched | **NOT RUN** (needs device, live fixture and backend) |
| A18 directions | NOT RUN (native handler) | - | - | PASS exact-coordinate URLs; localized failure message | **PARTIAL** |
| A19 location picker (both flows) | NOT RUN | NOT RUN (apply flow needs sign-in) | PASS round 2 (real engine, real pack): crosshair, "Pin the map centre" pins exactly the camera centre (26.25361, 50.21674), Arabic layout, no-location directions message (`screenshots/windows-r2/P01-P04`) | PASS: legacy outside point kept and shown, tap records exact point only, main venue keeps typed text/city, cancel keeps point, branch pin optional (null when unpinned), centre pin and no blind pin while the map is not showing | **PARTIAL** (picker rendered standalone on Windows, not through the signed-in apply flow; no TalkBack) |

## Round 2 re-check (Chrome 153 headless and Windows, 2026-09-27)

Builds: `project/build/web` of `d11e9f2` (first pass, profile `p5r2`) and of `4b7a84c` (full repeat, fresh profile `p5r3`), both with `SUPABASE_URL=http://127.0.0.1:9` and a placeholder key. Screenshots `screenshots/chrome-r2/`, `screenshots/windows-r2/`; raw logs `raw/r2/`.

| Case (round-1 finding) | Result |
|---|---|
| Long session, then Save (D1) | PASS. English guest session; `performance.clearResourceTimings()` then 320 same-origin fetches: the browser's timing buffer was full (250) and no longer listed `main.dart.js`, CanvasKit or Noto Sans Arabic. The new prompt's **Save** reached "Ready" (350 files). The cache held `main.dart.js`, `flutter_bootstrap.js`, `canvaskit.js`/`.wasm`, Roboto, Noto Sans Arabic, the pack, both styles, both i18n files, FontManifest and all four declared fonts (`raw/r2/cache-after-long-session.json`). |
| Offline cold start in Arabic (D1) | PASS. Server stopped, Chrome relaunched with `--host-resolver-rules=MAP * ~NOTFOUND`: 29/29 responses from the service worker; only the unreachable backend failed. Arabic place and street names joined at overview and at deep zoom in a profile that never showed Arabic online (R3-04, R3-06). |
| Web prompt (D4) | PASS: "Use this map without internet? Save it once in this browser." with Save and dismiss, shown only while not prepared. |
| One Retry offline (D12) | PASS: only the connection line offers Retry (R2-01, R3-04). |
| Arabic insets (D6) | PARTIAL: buttons on the left; the overview button reframes clear of them (R2-05, R3-05). The first view after opening the map is framed with the default left-to-right inset (`spatial_map_screen.dart:77, :582`); it is legal and the cities are clear, but it is not the mirrored framing. |
| Picker crosshair and centre pin (D3), no-location directions (D2) | PASS on Windows real engine (`windows-r2/P01-P04`). |
| Connected network that never answers (D11) | PASS after `4b7a84c`. Before it, the page fell back after 4.3 s but `main.dart.js` arrived only at 8.8 s: Flutter's generated loader registered its deprecated worker and waited 4 s more. With the minimal `web/flutter_bootstrap.js`, `main.dart.js` arrives at 4.7 s, 17/17 responses from the worker. |
| Online revisit after preparing | PASS: the offline worker stays registered and in control, the copy stays ready, one navigation, no request for `flutter_service_worker.js` (`raw/r2/online-revisit-registration.json`). Before `4b7a84c` the same revisit also passed, but Flutter's clean-up worker was fetched at the same scope (race-dependent). |
| Windows map render (re-run at the repairs) | PASS: ready in 1,657 ms, max zoom 18, zoom 2 refused (minimum now 10.57 because the measured bottom notice changes the overview fit), Arabic overview with buttons on the left (`windows-r2/W01-W04`). |

Observed, not fixed: preparation also stores every other same-origin URL the visit loaded, including 320 query-string copies of `version.json` in this synthetic run (the worker matches with `ignoreSearch`, so they are redundant); the details sheet's "Map" paragraph still says "prepare the offline map below" once the copy is saved.

## Performance and size (proposed gates from the research)

| Gate | Result |
|---|---|
| APK/AAB delta <= 40 MB | **Met**: +12.27 MB (pre-`integration_test`) / +13.72 MB (clean, with the dev plugin that release excludes), arm64 profile |
| Active pack <= 64 MiB | **Met**: 11.37 MiB |
| Native map-ready <= 2 s | NOT MEASURED on phone; Windows debug 1.63 s entry-to-ready |
| Prepared Chrome cold map <= 3 s | Shell to Welcome 3.0 s headless; map paint after guest entry not separately timed |
| Frame, memory, warm re-entry | NOT RUN |
| Coverage | **Met** for the archive: 100% of 8,298 slots decode; controls pass |
| Network independence | **Met** in Chrome offline (all from service worker) and by design on native (no network code in the map path; unit-tested client refuses any other URL) |

## Overall

Not acceptable as P5 complete: A11 is unmet and the physical-device cases are unverified. Ready for independent audit of the implemented scope.
