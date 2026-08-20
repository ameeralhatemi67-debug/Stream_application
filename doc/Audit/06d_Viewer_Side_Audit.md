---
type: audit
project: Streamer_app
phase: 6d of 8 (role: Viewer)
created: 2026-08-20
status: complete
---

# 👀 Phase 6d — Viewer Side: Deep Audit

**Method:** Opened `discovery_feed_screen.dart`, `notification_center_sheet.dart`, and `broadcaster_profile_screen.dart` this pass; cross-referenced with the existing UX audit rather than re-doing its heuristic evaluation from scratch.

---

## Confirmed working well

- Discovery feed, spatial map, live playback, follow/reminders, bilingual RTL — all confirmed built and functional in earlier phases; nothing new to add here beyond what Phases 1, 4, and 5 already found.
- **Notification read/unread state is real, not cosmetic.** `notification_center_sheet.dart` uses `notif.isRead` to drive both bold/regular weight and text color — this is genuinely wired to state, not just a static UI mockup.

## Not independently confirmed this pass (flagging honestly rather than guessing)

- Whether there's an explicit "mark all as read" or "dismiss" action beyond the per-notification read state wasn't confirmed by this pass's search — the read/unread *state* is real, but I didn't locate a specifically-named bulk-clear action. Worth a quick look next time that screen is open rather than treating this as a confirmed gap.
- Whether `broadcaster_profile_screen.dart` visually distinguishes "this is your own profile, here are edit controls" from "this is someone else's profile, here's the follow button" wasn't confirmed by pattern search this pass (the specific patterns searched for weren't present, but may exist under different naming) — this is a genuine open question for Phase 8 or a follow-up rather than a confirmed finding either way.

## Confirmed still missing (carried forward from Phases 3 & 4, this is the viewer-facing half of those findings)

- **No report/block affordance anywhere in the viewer's experience** — not on a stream, not on a streamer's profile, not on an individual chat message. For a viewer who's a student encountering inappropriate behavior from another viewer in live chat, or content they want to flag, there is currently no path to do anything about it except leave. This is the same gap Phase 3 flagged as an Apple Guideline 1.2 risk, restated here specifically from the affected user's point of view.
- **No account/data deletion** — same Phase 3 finding, viewer-facing consequence: a guest or Google-authenticated viewer who wants to leave the platform and take their data with them currently can't, in-app or otherwise.
- **Venue "Directions" copies a URL to clipboard instead of opening native Maps** — UX audit finding, unchanged, worth an easy fix (a `url_launcher` call the app already depends on for other things).

## Priority fixes for this role

1. A basic "report" action on a live chat message and on a stream/streamer profile — smallest viewer-facing fix that closes the biggest store-compliance gap from this role's side.
2. Native Maps intent for venue directions — quick, already have the dependency.
3. Everything else for this role is in good shape relative to the other three — the viewer experience is the most complete of the four roles audited in this project.
