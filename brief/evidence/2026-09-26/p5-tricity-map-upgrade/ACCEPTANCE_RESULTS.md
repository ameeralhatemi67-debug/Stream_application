# Acceptance results (A01-A19)

Tip `5e10678` (web/Windows runs used builds of the same map code; later commits changed only docs/advisory/test wiring, noted where relevant). Legend: **PASS**, **PARTIAL** (some required evidence present, some missing), **FAIL**, **NOT RUN** (no evidence; reason given), **N/A** (inapplicable by agreed scope; reason given). Mocked providers are never counted as rendering or persistence proof. SM-S936B is the required physical target; it was **not available** in this session, so every "Android physical" cell is NOT RUN and appears in [OWNER_RETEST_SCRIPT.md](OWNER_RETEST_SCRIPT.md).

| ID | Android SM-S936B | Chrome | Windows | Automated | Overall and notes |
|---|---|---|---|---|---|
| A01 first-use offline | NOT RUN (no device) | PASS for the web equivalent: prepared origin, server down, DNS blocked, guest entry 0.5 s, all three cities render | PARTIAL: real engine renders the bundled pack with backend unreachable (integration test); not a fresh install with the network disabled before first launch | pack/local-only tests | **PARTIAL** — native first-launch-offline is the core claim and needs the phone run |
| A02 later offline cold starts | NOT RUN | PASS (two separate profiles/builds) | NOT RUN (process cold start offline) | - | **PARTIAL** |
| A03 browser prepare + cold start | N/A | PASS: 31 files, cold start offline from the service worker, never-visited origin fails as expected; `persist()` false in headless | N/A | fake-store state tests | **PASS (Chrome only)** |
| A04 missing/corrupt/incompatible | NOT RUN (on-device fixture) | PASS: evicted pack -> honest unavailable card, credit kept | - | PASS: flipped byte, truncation, missing pack/style/notice, edited style, schema 2, zoom 0-14, remote style rule, retry recovers | **PASS (unit + Chrome)**; invalid boundary asset N/A (no boundaries ship) |
| A05 interrupted update | N/A native: no update path, bundle replaced atomically by app install; app-version replacement on device NOT RUN | PASS: server killed during re-preparation -> failed, live copy + record intact, staging removed | N/A | fake-store failure test | **PASS for web**; optional remote-delivery portions N/A (remote hosting deferred by owner) |
| A06 storage pressure / eviction | N/A for low storage (native writes nothing); NOT RUN otherwise | PASS eviction + blocked storage message; QuotaExceeded NOT RUN (not injected) | N/A locked files (no writes) | - | **PARTIAL** |
| A07 reset, age, version | N/A native (nothing to reset) | PASS: remove (now with confirmation), older-pack record -> "not prepared" -> re-prepare; >90-day advisory implemented after the Chrome runs (unit-tested rule; UI not screenshotted) | - | PASS stale rule 90/91 days | **PARTIAL** (advisory UI not captured) |
| A08 legal zoom range | NOT RUN | PASS: min/mid/max screenshots, no missing-data tiles at 18, wheel beyond limits | PASS: zoom 30 -> 18, zoom 2 refused | PASS: 0.25-step sweep beyond both limits, corners inside extent | **PARTIAL** (no phone pinch/continuous video) |
| A09 every navigation path | NOT RUN | PASS dropdown, city search, cluster zoom, overview | PASS dropdown, overview, locale | PASS legal targets, focus refusal, dropdown/search agreement | **PASS (automated + desktop)**; deep links N/A (none target the map) |
| A10 resize / rotation / layout | NOT RUN (rotation) | desktop-size canvas only | PASS desktop (feasible canvas + side panel) | PASS 8 canvases incl. 915x412 and 1440x900; layout sweep 7 sizes x 3 scales x 2 locales | **PARTIAL**; known limit: phone landscape with the offline chip falls back to containment (overview slightly under controls) |
| A11 geometry / city identity | - | - | - | - | **NOT MET (deferred)**: no licensed municipal geometry; polygons and "municipal" claims removed; city names are views only |
| A12 labels, locale, RTL, a11y | NOT RUN (device, TalkBack) | PASS Arabic joining incl. deep-zoom street names; locale switch keeps camera | PASS Arabic | PASS Arabic widget layout, semantics labels on credit/chip/cluster/picker | **PARTIAL** (no TalkBack/keyboard traversal, no device text scale) |
| A13 attribution / details | NOT RUN | PASS in online/offline/unavailable/Arabic states | PASS | PASS widget | **PASS (desktop + automated)** |
| A14 backend vs basemap | NOT RUN | PASS pack ready x backend unreachable; pack unavailable x backend unreachable | PASS pack ready x backend offline | PASS pack unavailable x online/offline | **PARTIAL**: pack ready x backend current not run (no reachable backend) |
| A15 moderation, caches, out-of-area | NOT RUN | PASS saved-venue domain filter and offline search (synthetic) | - | PASS existing moderation/null-vs-empty tests + domain filter | **PARTIAL**: reconnect-removal with a live backend not run |
| A16 clusters and coordinates | NOT RUN | PASS cluster and max-zoom member list | - | PASS 1,000-point projection count, stable ids | **PARTIAL** (no profiling) |
| A17 map -> stream -> map | NOT RUN | NOT RUN | NOT RUN | existing route guards untouched | **NOT RUN** (needs device, live fixture and backend) |
| A18 directions | NOT RUN (native handler) | - | - | PASS exact-coordinate URLs; localized failure message | **PARTIAL** |
| A19 location picker (both flows) | NOT RUN | NOT RUN (apply flow needs sign-in) | - | PASS: legacy outside point kept and shown, tap records exact point only, main venue keeps typed text/city, cancel keeps point, branch pin optional (null when unpinned) | **PARTIAL** (widget-level only) |

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
