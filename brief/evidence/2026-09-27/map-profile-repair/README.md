# FIX-01: Spatial Map profiles and account category

Date: 2026-09-27. Main checkout, branch `master`, based on GitHub snapshot `e8201196171cf423b3344533ef974acd1298c787`. Owner requested both repairs after exploratory testing. No separate agent task, new branch, database operation or owner-profile edit.

## Repairs

- The map's shared catalog rejected blank-city records even when they had valid saved coordinates. These records never reached the pins, search or drawer, so their cards were inaccessible. Legacy pins now qualify within the existing three-city overview; known city records still use the existing city/safety-envelope checks. Neither city names nor coordinates are invented. Explicit other-city records, hidden/unverified records and invalid coordinates remain excluded. Cached pins use the same rule and retain Arabic-only city names. The overview is a product extent, not official municipal geometry; unknown-city pins outside it still require usable city data or a future boundary solution.
- Edit Account Profile restored `cs_tech` into a dropdown that did not contain that value. It now deduplicates choices by category ID, uses provider category labels, and preserves saved legacy/custom/inactive IDs until the user changes them. The shared helper covers individual and organization application editors.

The user's two reported coordinates and a third location are regression fixtures only, not hardcoded production exceptions. The live backend rows were not inspected. The blank-city failure is reproduced locally; confirmation that it explains all profiles missing from the owner's runtime remains pending.

## Verification

- Focused profile-editor suite: 7 PASS, including opening and submitting `computer_science`, `cs_tech` and `custom_subject` without changing the stored category.
- Map/catalog/cache regressions: exclusions and both supplied saved locations covered. Marker and drawer selection both open the card in a widget test.
- Initial new drawer test tapped before its opening animation completed; corrected test frame timing, then the test passed. No production UI adjustment was needed for that test failure.
- `flutter analyze --no-pub`: zero issues.
- Full Flutter suite: **851 PASS** in eight sequential disjoint shards (110, 111, 99, 120, 100, 108, 102, 101). Source is unchanged during the run. Commands: `flutter test --no-pub --concurrency=1 --total-shards=8 --shard-index=N --reporter=expanded`, N=0 through 7, from `project/`.
- Full logs remain locally in ignored `brief/.runtime/map-profile-repair/`; committed [results](verification.json) and [SHA-256 source manifest](source-sha256.json) identify this run.

No hosted backend writes, phone install or physical acceptance PASS is claimed. BUILD-01 host-memory recovery remains unconfirmed separately. P5/P6/P6S acceptance and STREAM-D8 are unchanged.

## Owner retest: three steps

Start a fresh run from the main `Streamer_app/project` folder on `master`, using the same local configuration that launches Chrome successfully. Existing running sessions may still contain the previous code.

1. Open Spatial Map with no category/search filter. Existing verified visible profiles with saved local pins should appear. Select one pin: its profile card must open.
2. Open the map's side drawer. Select a listed profile: the drawer must close and the same profile's card must open.
3. Open Settings > Edit Account Profile. The sheet must open without the red error screen and retain the saved category. If saving is desired, confirm the category remains unchanged unless deliberately selected differently.

Record observed platform/build and each result below. If profiles are still absent, record whether the drawer is also empty; do not add fake coordinates or edit individual records as a workaround.

| Check | Owner result |
|---|---|
| Map profile pin opens card | NOT RUN on repaired source |
| Drawer profile opens card | NOT RUN on repaired source |
| Edit Account Profile opens with saved category | NOT RUN on repaired source |

These focused checks supplement the consolidated `../hadayah-wave4v2-integration/WAVE4V2_RETEST_SCRIPT.md`; they do not mark its 36 acceptance cases passed.
