# G6 scanner repair, 2026-09-24

- Base: local `master` at `345cfbd`; isolated branch `codex/g6-localization-gate`.
- Before: G6 reported 565 `Text('...')` candidates. After: 1. The scanner now excludes a candidate only when its literal is immediately followed by a `.tr(...)` call, allowing whitespace. The other 564 were translated calls.
- Remaining match: `project/lib/features/map/presentation/spatial_map_screen.dart:628` displays `Esri, HERE, Garmin, OpenStreetMap contributors` as map attribution. Provider names should remain verbatim; `contributors` is English UI copy. No application localization change was made.
- Verification: `node --test brief/tools/g6_scanner.test.mjs` passed; `node brief/tools/gates.mjs` exited 0 and reported G6=1, with all other target gates passing. G6 remains failing against its target of 0.
- Limit: G6 retains its original single-quoted `Text(...)` candidate scope. It does not scan double-quoted strings, other widgets, or text built from multiple expressions; comments between a literal and `.tr(...)` may still be counted.
