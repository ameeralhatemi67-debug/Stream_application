# FIX-02: responsive map card and controls

2026-09-27, local master after `0f7d474`. Owner budget: at most 3 additional weekly percentage points; entry 54%, ceiling 57%. Latest app meter reports 54% (rounded, account-wide).

- Drawer button shares a horizontally aligned bottom row with the OpenStreetMap credit; expand button hidden. All-three-cities navigation remains in the city dropdown.
- Card takes available width with 16px side margins, capped at 420 logical pixels. Identity, venue, secondary actions and full-width primary action keep a consistent order. Height is bounded and scrollable above the attribution/control row; credit wraps at large text sizes.
- 126 populated card cases cover widths 280/320/360/384/412/600/1280, 600x360 landscape, en/ar, text scales 1/1.6/2 and video/audio/offline states. Assertions cover width, control alignment/no overlap, absent expand, reachable primary/close actions and no Flutter exceptions.
- Full Flutter suite: **905 PASS**, all test files covered exactly once across eight sequential disjoint file batches. See [results and file inventory](results.json). Command per batch: `flutter test --no-pub --concurrency=1 <batch files> --reporter expanded` from `project/`. Logs: ignored `brief/.runtime/map-card-ui/`.
- Analyzer: zero issues. No physical acceptance claimed.
- Initial failures were two old tests expecting or tapping the hidden control; corrected to assert its absence and navigate through the city dropdown. Final focused check and full relevant batch pass; earlier failed logs retained.

Owner retest: restart from main master; select a map pin, check full card width and primary action, rotate phone, and open the drawer beside attribution. On desktop the card must remain at most 420 logical pixels wide. Physical outcome: **NOT RUN on changed source**.
