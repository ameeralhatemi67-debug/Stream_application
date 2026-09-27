# DES-01: unified streamer cards

2026-09-27, main master after `8aa86f4`. Owner selected compact option B with the refinements below and explicitly authorized implementation. No new branch, dependency, agent dispatch, hosted operation, push or device install.

## Behavior

- One shared identity card renders each actual banner, leading avatar straddling the banner edge, verified indicator, name/title and top-end status. Missing/broken images use neutral fallbacks. Card width follows its container up to 420 logical pixels; content height grows with text. Arabic mirrors through Directionality. Banner height is proportional to width within 80–112px, approximating one third of the compact card at ordinary text size; it does not force a fixed total height.
- Map: tapping the card opens the streamer profile even when live. The entire venue section launches Google Maps at the exact saved destination, without also opening the profile. Directions and profile shortcut buttons below the card are gone; close remains. Existing invalid-location and launch-failure messages remain. Other venue launchers retain their existing platform preference.
- Discovery: banner/avatar/name/title and View channel or Watch/Listen live. No next-lecture block, follow or reminder. Existing own-channel identification and stale/offline live-status suppression remain. The fixed-height grid becomes a wrapping layout with content-sized cards and one column on narrow phones.
- Profile: academic title/organization and expandable description, without the academic icon. Show more/less also exposes the existing organization/archive details. Follow occupies available row width; reminder is a labelled 48px icon. Existing live access, organization branches and featured-channel filtering remain reachable.
- Settings: account handle, email and description below the common identity. The existing Edit Account Profile button stays outside the card. Account-role badge now sits below identity in its separate row to avoid overflow with enlarged text.

## Verification

**Full suite: 941 tests PASS across all 65 test files; analyzer: zero issues.** Source/catalog/test hashes matched after the complete run. English/Arabic catalog keys match and `git diff --check` passes. [Results and file inventory](results.json). Full logs are retained in ignored `brief/.runtime/unified-streamer-cards/`. Added 33 tests covering all four contexts at 320/1280px, English/Arabic, 1x/2x text, expanded/collapsed profile details, working Follow/Reminder, absent unwanted actions and separate map-card/Google-destination navigation. The existing 126-case map matrix still covers 280–1280px widths, 600x360 landscape, two languages and three broadcast states. Existing organization, Settings, ownership and offline tests are retained with expectations adjusted for the approved controls/content-sized cards.

Initial checks found an oversized map venue target in enlarged Arabic landscape, profile empty-tab Columns overflowing after description expansion, and a Settings account badge overflowing its row. Those layouts were corrected. New nested-scroll test taps now wait for scroll layout and locate controls even after the header scrolls offstage. No hardware, external Google Maps app, or real account/backend operation was performed by these tests; the launch URI is intercepted in the widget test.

Changed source/catalog/test hashes: [source-hashes.json](source-hashes.json).

## Owner retest

Hot restart the current master run, then:

1. Map: open a pin; confirm banner/avatar/card fit, tap venue to open the saved destination in Google Maps, return and tap the card name/background to open the streamer profile. Close still works.
2. Discovery: confirm compact cards with no lecture/follow/reminder section; verify channel or live entry still works.
3. Streamer profile: expand and collapse details; toggle Follow and reminder. Check portrait, landscape and larger system text in English/Arabic.
4. Settings: confirm handle/email/bio, with one editor button outside the card. On a laptop the card remains bounded instead of stretching across the screen.

All physical retests pending. P5/P6/P6S acceptance and STREAM-D8 remain unchanged.
