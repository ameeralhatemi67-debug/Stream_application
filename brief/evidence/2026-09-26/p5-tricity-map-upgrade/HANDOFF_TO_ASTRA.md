# Handoff to Astra: P5 three-city map upgrade

**Status: NEEDS WORK. All three critic rounds are used.** The final critic scores (round 3, on `87e3118`) are Functionality **8**, Accessibility and platform compatibility **7**, Integration and connectivity **8** and Ease of use **8**. No critical or high defect remains, and there is no unlicensed asset or failed technical gate on Chrome or Windows.

Two things still block acceptance:

- **F1, medium:** a layout regression in the map's venue summary card, introduced by the round-2 repair. It keeps Accessibility below 8.
- **Missing essential evidence:** SM-S936B, backend-current runs and A11.

Nothing is merged, pushed or deployed. P5 is not accepted. Under the three-round cap, no code was changed after critic round 3; the F1 fix must be verified by your audit.

## Where things are

| Item | Value |
|---|---|
| Worktree | `C:/Users/User/.codex/worktrees/p5-basemap-spike/Streamer_app` (the old branch `codex/p5-basemap-spike` at `86068e8` is untouched) |
| Branch / tip | `codex/tricity-map-upgrade`. The code tip is `a57dda7`; the tip itself is the documentation commit that adds this file (baseline `7b54cb5`). |
| Checks at `a57dda7` | `flutter analyze` 0 issues; full `flutter test` **734 passed**; `gates.mjs` 0 failing; i18n 1,476 keys in `en.json` and `ar.json`, symmetric. The critic re-ran all three independently with the same results. |
| Web build | `project/build/web` is a release build of `a57dda7` with `SUPABASE_URL=http://127.0.0.1:9` and a placeholder key. |
| Uncommitted | Only `project/windows/flutter/generated_plugin*`, which differ in line endings only. Never commit them. |
| Main checkout / stashes | Untouched and read-only throughout. Stashes `d646b945` and `d53c178e` are intact. `dart_define.local.json` was never read. |
| Temporary items (safe to remove) | Detached worktree `C:/Users/User/.codex/worktrees/tricity-baseline-7b54cb5` (APK baseline; remove it with `git worktree remove`). Headless Chrome test profiles `C:/Users/User/AppData/Local/Temp/p5r2`…`p5r5`. |

## Commits since the paused session (`87ecd98`)

| Commit | What |
|---|---|
| `4b7a84c` | fix(web): start without Flutter's deprecated service worker. It shared the offline worker's scope and added a second 4 s wait on a hanging network. Also adds the Windows picker render test. |
| `06d1a83` | Round-2 Chrome/Windows re-check evidence, D10 relabels, ADR-008 "unverified on hardware", D8 area disclosure |
| `cdd079e` | Critic round 2 record |
| `ad28998` | fix(map): round-2 repairs. D2 residual (venue sheet for 0,0), E1 (worker timeout only for page loads), E2 (one copy per path), E3 (self-hosted label fonts), E4 (Save keeps the prompt; "saved" wording), E5 (centre mark and wording), D5/D6 residuals |
| `a57dda7` | fix(web): the app's SVGs and built-in avatars are required for offline readiness (a re-save had dropped them) |
| `87e3118` | Evidence for the repair pass |
| (tip) | Critic round 3 record, F4 note, this handoff |

## Critic scores and why each is below 10

| Round (reviewed commit) | Functionality | Accessibility / platform | Integration / connectivity | Ease of use | Verdict |
|---|---|---|---|---|---|
| 1 (`53a6b9d`) | 7 | 6 | 7 | 7 | NEEDS WORK (D1 high) |
| 2 (`06d1a83`) | 8 | 8 | 7 | 8 | NEEDS WORK (D2 residual) |
| **3 (`87e3118`), final** | **8** | **7** | **8** | **8** | **NEEDS WORK (F1)** |

Why each final score is below 10, per the round-3 critic:

- **Functionality 8 (provisional).**
  - Native first-launch offline has no SM-S936B evidence.
  - Accurate city outlines (A11) are not met.
  - F2: the worker's list of pages started offline lives in memory only, so after the worker restarts, lazily loaded files can wait for the OS network timeout.
  - F3: a re-save still drops optional images the visit did not load (demo photos).
  - An unpinned application is stored as 0,0, and approval still hard-codes "Al Khobar".
- **Accessibility and platform 7 (fails).**
  - **F1:** the summary card's action row cannot shrink after its icon buttons became 48 px. At 320 dp and text scale 1.3, all six variants overflow by 18–38 px. On a 384 dp floating card at text 1.0, five of six overflow, worst in Arabic, and the Watch/Listen/Profile button is partly outside the card.
  - No Android, TalkBack or device text-size evidence.
  - The card's close button is still 28 px.
- **Integration 8 (provisional).**
  - A14/A15/A17 have no runtime evidence against a reachable backend.
  - The live Venue tab's 0,0 path is proven only by a widget test of the shared sheet.
  - F2.
- **Ease of use 8.**
  - F1 makes the card look broken for Arabic and large-text users.
  - F5: "Get Driving Directions" is still offered for an unpinned venue and then says directions are unavailable.
  - The Save prompt also shows while the browser itself is offline.
  - Top-edge place labels sit under the search bar.
  - No testing with real users.

## Delivered (verified on Chrome and Windows and by tests; the phone is unverified)

- **Map pack and renderer:**
  - A bundled, hash-verified vector map pack: 11,919,559 B, SHA-256 `1deb87ea…6a87`. All 8,298 tiles decode.
  - flutter_map 8.3.2 with flutter_map_vector_tiles 2.9.0, fed by a bounded local range client (no server, fork or parser).
- **Camera and domain:**
  - One viewport policy for every camera path: max zoom 18, no rotation, feasible canvas. The first view re-frames with the measured, mirrored insets until the user moves the map.
  - The venue domain filter; unsourced polygons and Saudi-wide presets removed; the D8 wider area disclosed in the app and in REPORT.
- **Web offline:**
  - Readiness requires the start-up shell, engine, Latin and Arabic label fonts, interface images and the map.
  - It survives a long session: verified with the 250-entry timing buffer full.
  - Offline Arabic cold start with joined labels, a hanging-network start (`main.dart.js` at 4.45 s), and an online revisit that keeps the worker.
  - Eviction re-prompt, and an interrupted re-save that keeps the live copy.
- **Location picker:** exact point only; a centre mark and "Pin the centre mark" path (Windows real engine); legacy out-of-area points kept; direction-aware insets.
- **Unpinned venues:** they never show a distance or open directions to 0,0 anywhere.
- **Build size:** APK delta +12.3 to 13.7 MB (target is 40 MB or less; not rebuilt after `d11e9f2`, and later commits change no native code).

## Unmet, pending or needing an owner decision

1. **F1 (fix first, then audit).**
   - Let the summary card's primary button shrink or wrap, or move the icon buttons, at `marker_summary_card.dart` around `:153-285`.
   - Make the close button 48 px.
   - Add a layout-sweep case with a venue selected: English and Arabic, 320–412 dp, text 1.0–1.6.
   - Optionally, in the same audited change: F5 (hide "Get Driving Directions" for unusable points at `live_broadcast_screen.dart:2152-2172`), hide the web Save prompt while the browser is offline, F2 (persist or derive the offline-page decision) and F3.
2. **A11 accurate city outlines: NOT MET.** No licensed municipal geometry exists. It needs an owner-authorized data request (Balady, Eastern Province Municipality or GEOSA).
3. **SM-S936B physical runs are all pending.** See OWNER_RETEST_SCRIPT.md: first-use offline, reboot, rotation, TalkBack, text size, frame and memory, mini-player, map → live → map. Add: tap a venue in Arabic at text size 1.3 (F1).
4. **Backend-current runs** (A14, A15, A17, and A19 through the signed-in apply flow) need an authorized non-production backend.
5. **D8 venue area:** the rectangle includes Qatif, Saihat, Tarout, Safwa and Ras Tanura. The owner must decide whether to keep it or narrow it.
6. **Pre-existing, not changed:**
   - Approval hard-codes `cityEn: 'Al Khobar'` and a placeholder `youtubeVideoId` (`app_provider.dart` around line 4420).
   - The apply form allows no pin.
   - VenueNavigationSheet measures distance from a fixed Al Khobar point.
   - There is no in-app licences screen.
   - The credit wording needs counsel sign-off.
7. **Documented platform limits:**
   - Labels use platform default fonts, not IBM Plex.
   - A browser that has never visited the site cannot start offline.
   - Web storage can be evicted (detected and re-prompted).
   - Readiness needs the engine's fallback fonts, from the font CDN or self-hosted. This is not yet written in ADR-008 (critic E3 residual).
   - Only headless Chrome 153 was tested on the web.

## Next steps

1. Fix F1 (and optionally F5 and the smaller items) as one small change. Re-run `flutter analyze`, the full `flutter test`, `gates.mjs`, and a Chrome check of the venue card in English and Arabic. Your audit is its verification; no critic round remains.
2. Owner: run OWNER_RETEST_SCRIPT.md on the SM-S936B with the test app id `sa.hadayah.streamer_app.maptest`. Do not install over the production app.
3. Owner: decide D8 and whether to request licensed geometry for A11; arrange a non-production backend for A14/A15/A17/A19.

## Not authorized

Merge, push, deploy, hosted database changes, production credentials, installing over the owner's app, reading `dart_define.local.json`.
