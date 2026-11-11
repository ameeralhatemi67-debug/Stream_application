# Handoff 2: Lantern and Arch run, stopped on 2026-11-11

The run stopped because the context and the 5-hour limit were almost full.
Nothing is broken. All work is committed locally. Nothing was pushed, no
hosted migration was applied, no key or secret was created or changed.

**To continue:** start a new session, paste the owner's first handoff
("Handoff: Lantern and Arch skin, clean-up, speed, and a Play-ready Android
build") and then say: *read `brief/fable/HANDOFF.md` in the worktree
`.claude/worktrees/fable-lantern` and continue*. The first handoff is the
authority. This file only adds the state.

## 1. Where the work is

| Thing | Place |
|---|---|
| Work branch | `fable/lantern-skin` (from `master` `77bcff0`), 12 commits, last `57a16e0` |
| Worktree | `.claude/worktrees/fable-lantern` (Flutter app in `project/`) |
| Main checkout | on `master`, holds the owner's uncommitted studio work. **Do not touch it.** |
| Design source | main checkout, untracked: `brief/design/lantern_and_arch/` (`source_parts/web_js_85_notes.js` page notes, `web_js_86_handoff.js`, `app_css_1.css`) |
| Build guide for the skin | `project/lib/core/widgets/lantern/README.md` |
| Map of the old code | `brief/fable/scratch/CODE_MAP.md` |
| Play findings | `brief/fable/ANDROID_PLAY_STATUS.md` (its header names an old branch; fix the line) |
| Progress file | `brief/fable/PROGRESS.md` (stale: stops before the rooms and the map) |

Always start shell commands with an absolute `cd` to the worktree. The
shell directory drifts.

## 2. Rules that stay in force (short form; the first handoff has the full text)

- No cost of any kind. No paid service, font, icon set, plan upgrade or CI minutes.
- Never push. Commit locally on `fable/lantern-skin` only.
- Do not apply migrations to hosted Supabase. Do not deploy edge functions.
- Do not change secrets, `.env` files, signing keys or store credentials. Never create, print or commit a key or password.
- Do not submit real accounts on the emulator.
- Gold & black and Hedayah must look and behave exactly as on `master`. No new features for them.
- One screen never mixes widgets from two skins.
- Gates: `flutter analyze` 0 issues, full `flutter test` green, `en.json`/`ar.json` key-symmetric, RTL by `Directionality`, AA contrast, calm motion respected.
- Ask the owner before: push, deploy, hosted migration, deleting data or branches, anything that costs money, any message to real people.

## 3. Done and committed

| Commit | Content | Tests |
|---|---|---|
| `2bc80ca` | Old-skin capture test (38 pictures) | |
| `d64f8c5`, `d82e114` | Foundation: third skin, tokens, theme, kit (`lib/core/widgets/lantern/`), tab shell, Settings tile, isolation rule, compare tool | `lantern_skin_test` 23, `lantern_isolation_test` 10 |
| `093b900` | Discover | `lantern_discover_test` 23 |
| `c1c2635`, `e4f3610`, `f1d2bf6`, `9761a7e` | Android Play readiness: manifest, backup off, ProGuard, deletion page, store notes, status file | |
| `b8c8aae` | Opening screen (normal, slow, offline) | `lantern_opening_test` 12 |
| `4bce2db` | Live and audio rooms, new chat, drawn reactions | `lantern_room_test` 45 |
| `57a16e0` | **WIP** map: pins, grouping by pin box, place cards, short list | `lantern_map_test` 20 pass, **1 fails** |

How the skin is isolated (to be written as ADR-026 in `Core_files/decisions.md`):
every Lantern widget `implements LanternSkinWidget`; an existing screen keeps
its logic and hands over at the top of `build` when `context.isLanternSkin`;
Lantern screens wrap in `LanternSurface`.

## 4. Open right now

1. **One failing test**: `test/lantern_map_test.dart`, "in the app › a pin
   opens the Lantern place card" (expects 1 place card, finds 0). The tap on
   the pin does not open the card in the test. Not yet investigated: it can
   be the test (tap position, settle time) or the hook in
   `spatial_map_screen.dart`. Check by hand in Chrome first.
2. Map shots are not yet in `test/lantern_capture_test.dart` and not reviewed
   against the design.
3. Map chrome is still the classic widgets under Lantern (search, layer
   chips, list panel, zoom, locate, legend). `LanternMapLegend` exists but is
   not used. This breaks the "no mixed skins" rule on the map until done.
4. The full `flutter test` suite was last run at the baseline. Run it.

## 5. Two helpers: work not yet reviewed or merged

Both worktrees are locked and keep their files. Both started from `d82e114`.

| Helper | Worktree and branch | State |
|---|---|---|
| A. Classic kits under Lantern (`ds/*`, web kit, lessons kit, `lantern_compat.dart`, `test/lantern_compat_test.dart`) | `.claude/worktrees/agent-a042ac1f6af7bfaa3`, `worktree-agent-a042ac1f6af7bfaa3` | Finished and committed there as `c3ac6c3` (on top of `d82e114`). Its report says: analyzer 0, `lantern_compat_test` 148 pass, old-skin pictures 34 of 38 the same (the 4 known ones). **Not reviewed by me, not merged.** Known gaps it reported: `CaAppBar` only restyled by the theme; lessons screens use `TC.*` colours directly, so they stay gold-era until helper B's screens replace them; `CaSwitch` has an empty screen-reader label under Lantern. |
| B. Lantern lessons screens (`lib/features/lessons/presentation/lantern/*`, hooks, `20_lessons.json`) | `.claude/worktrees/agent-a4b85e7d6e6275098`, `worktree-agent-a4b85e7d6e6275098` | **Stopped by me in the middle.** About 3 own commits and 11 uncommitted files. May not compile. |

To merge each: read the diff (`git -C <worktree> diff d82e114`), commit in
that worktree, cherry-pick onto `fable/lantern-skin`, then run
`python brief/tools/merge_lantern_i18n.py` (do not hand-merge the catalogs),
`flutter analyze`, their tests and `lantern_isolation_test.dart`. Helper B's
work needs a finishing pass or a new helper with the same brief.

## 6. Still to do, in order

1. Fix item 4.1, map shots, map chrome, commit the map as `feat(map)`.
2. Merge helpers A and B.
3. Screens not started: settings (category list, Appearance pane with
   day/night/system and calm motion: the provider fields exist),
   notifications drawer, bookmarks, welcome/sign-in; channel page; broadcast
   studio (3-step checklist, hold-to-confirm); 5-step application with inline
   errors and status tracker; admin hub (rail, KPI cards, batch bar,
   pipeline); organization hub; chat moderation dialogs (today the classic
   sheets open); empty, loading, error and 404 states.
4. Report action for a stream and a channel (Google's user-content rule;
   today only chat messages can be reported). Lantern first; old skins only
   as a separate commit the owner can refuse.
5. The surprise feature: not chosen, not built.
6. Speed work for all skins with before and after numbers (ADR-025 round 2).
   Nothing measured yet.
7. Android: no signed AAB is possible, `project/android/key.properties` does
   not exist and I must not create a key (owner runs
   `brief\launch\make_upload_key.ps1`). Still to do: emulator pass in three
   skins (`Pixel_5`, SDK on `D:\app\Android\Sdk`), "use my location" after the
   manifest change, 16 KB check, version code decision.
8. Proof that the old skins did not change: run the capture test on a
   `master` worktree and on the branch **in the same minute** (lesson and map
   pictures hold countdowns), then
   `python brief/tools/compare_skin_captures.py <before> <after>`. After the
   foundation 34 of 38 were identical; the 4 others were the Settings tile
   (intended) and a countdown. Emulator pairs under
   `brief/fable/skin_regression/` are not made yet.
9. Docs: ADR-026, `STATUS.md`, `LEDGER.md` RESUME block, `PROGRESS.md`,
   contrast test (`test/lantern_contrast_test.dart` is named in a comment but
   not written).
10. `brief/fable/FINAL_REPORT.md` and the private artifact.

## 7. Defaults chosen for the open questions (each easy to change)

Day is the default appearance (`LanternAppearance.fallback`). The arch is the
signature frame. Reactions are drawn icons, not emoji. Chat roles are
labelled chips. No new font files (Readex Pro and IBM Plex Sans Arabic as
shipped; Hacen Maghreb not bundled). No speaking signal in audio rooms.
Opening screen shows at least 1.5 s (0.3 s with calm motion). Locate button,
the Now/Tonight/This week control and the hold-to-confirm list are not
decided yet.

## 8. Tools and traps

- Quiet test runner: `FT_TAIL=200 brief/fable/scratch/ft.sh test/<file>` from `project/`.
- Lantern pictures: `LANTERN_CAPTURE_DIR=<dir> flutter test test/lantern_capture_test.dart` (output in `brief/fable/shots/`, not committed).
- Old-skin pictures: `SKIN_REGRESSION_DIR=<dir> flutter test test/skin_regression_capture_test.dart`.
- Text: add a file `brief/tools/lantern_i18n/NN_area.json`, then run `python brief/tools/merge_lantern_i18n.py` from the worktree root.
- Icons: edit `brief/tools/lantern_icons.json`, then `node brief/tools/make_lantern_icons.mjs`.
- Design pictures: `brief/fable/scratch/design_shots.mjs` (needs the saved prototype as `design.html`; the old copy and the review sheets were in the session's temp folder and may be gone).
- Write long scripts with the Write tool, not shell heredocs (quotes break them).
- Use `git add <paths> 2>/dev/null`. Do not `git add brief/fable` as a whole: `shots/` holds many pictures.
- Three files under `project/windows/flutter/generated_*` show as modified. They are generated. Do not commit them.
- Text styles in the theme must be `inherit: true`, component styles `inherit: false`, or the skin switch throws.
- Plural keys such as `web.stat_live` need `.plural(n)`, not `.tr()`.
- A test room needs an 11-character stream id (`lanternLive`).

## 9. Known risks to report to the owner

- The owner's uncommitted studio work on `master` touches `app_provider.dart`, which this branch also changes. Commit or set that work aside before a merge.
- The existing "mini player" only leaves a shortcut back; playback stops. The Lantern corner button does the same. A corner player that keeps playing is not built.
- The audio stage draws over the YouTube player (also in the old skins): a YouTube terms risk.
- `privacy.html` has no YouTube API Services statement.
- For a new Play app Google makes its own signing key by default. The owner must choose "use your own key" before the first release if he wants his own.
