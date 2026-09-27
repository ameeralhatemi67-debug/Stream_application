# FIX-03: studio language/help and selected map pin

2026-09-27, main master after `5555eb0`. Owner permits at most five additional weekly percentage points: baseline 54%, ceiling 59%. No new branch, delegation, push, hosted operation or device install.

## Changes

- Studio header reuses the existing language SVG with no visible language text, a 48px touch target and language tooltip. Row direction places it at the right in English and left in Arabic. Switching keeps entered drafts.
- Phone Live Link help opens page 1; Stream Key help opens page 2 of the same guide. Pages have a number/title indicator, previous/next buttons, localized explanations and the exact supplied Share/Copy screenshots with rounded corners. Clipboard access, key persistence and broadcast permissions are unchanged. Existing secret-versus-public-link explanation and phone limitations remain visible.
- Selected public-catalog pins are no longer suppressed above zoom 13.5. The selected record stays outside clusters at its saved coordinates, with a repeating 1.0–1.16 scale pulse. It resets on deselection and when animations are disabled or the tab is inactive; leaving the map clears selection. The cached-only details-sheet flow is unchanged.

## Verification

Focused studio/guide tests and the 143-test map file pass. Regressions cover both help entry points/images and navigation, en/ar guide pages, icon-only language mirroring with retained draft, a selected pin among overlapping records, visible card+pin across zooms, changing scale and tab exit/return. Initial compile failure was a duplicate underscore parameter name in the new test callback; corrected before the passing map run. Deprecated TickerMode.of calls were replaced with the installed SDK's valuesOf API. No production source changes during the final full-suite run.

**Complete suite: 908 PASS across all 64 test files**, in eight disjoint file batches (80/78/94/220/76/186/47/127). See [results and file inventory](results.json). Final analyzer: **zero issues**. The refined language test starts from both en and ar; its complete 24-test studio file passed again after the batches. Final weekly reading: **55%**, versus 54% entry (rounded/account-wide), within the 59% ceiling. Full logs stay in ignored `brief/.runtime/studio-pin/`. The language regression was refined to exercise both initial locales and is rerun separately after the full batches.

The supplied MP4 was not played: browser policy rejects local file URLs. No workaround was attempted. Pin disappearance was reproduced from the explicit marker-suppression code and verified through widgets. Physical acceptance is pending.

References for animation lifecycle: [Flutter AnimationController](https://api.flutter.dev/flutter/animation/AnimationController-class.html), [TickerMode](https://api.flutter.dev/flutter/widgets/TickerMode-class.html). The installed go_router indexed-stack implementation uses TickerMode for inactive branches.

## Owner retest

Stop and rerun the app from main `project/` so the new image assets are included.

1. Open Broadcaster Studio. Tap the SVG-only language button; confirm it moves to the other header edge and your draft remains.
2. Select Phone. Open the Live Link info button: expect Share screenshot and page 1/2. Go next/back. Open Stream Key info: expect Copy screenshot and page 2/2. Check Arabic too.
3. Select a map pin: its avatar must remain visible and gently grow/shrink while its card is open. Close the card or switch to Discovery: the selection pulse stops. Return to Map: no stale selected card/pulse.

All three owner retests: NOT RUN on repaired source. Release acceptance and existing STREAM-D8 blocker remain unchanged.
