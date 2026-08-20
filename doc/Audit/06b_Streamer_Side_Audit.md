---
type: audit
project: Streamer_app
phase: 6b of 8 (role: Streamer / Individual Broadcaster)
created: 2026-08-20
status: complete
---

# 🎙️ Phase 6b — Streamer (Individual Broadcaster) Side: Deep Audit

**Method:** Opened the actual application-wizard and studio files this pass, rather than relying on doc cross-referencing like Phase 4 did. Good news first: **several items Phase 4 marked "Missing" or "Partial" turned out to already be built** once I read the real code. Corrections below are flagged explicitly so the punch list in Phase 8 doesn't duplicate work that's already done.

---

## Corrections to Phase 4's inventory (read this first)

- **Saudi phone number validation — Phase 4 said "Missing." It's actually built, and built well.** `apply_step_4_location.dart`'s `_validatePhone()` strips whitespace automatically, rejects any non-digit/non-`+` character, and validates against all three real Saudi formats (`05XXXXXXXX`, `9665XXXXXXXX`, `+9665XXXXXXXX`) with specific "too short" messages per format. This is one of the better-implemented pieces of the wizard. **Status: Done.**
- **Org roster auto-fill from existing handle — Phase 4 said "Partial, not confirmed." It's built.** `apply_step_3_5_org_speakers.dart`'s `checkAndAutofill()` looks up the typed handle against `provider.streamers`, and on a match fills name/bio/YouTube/avatar automatically with a visible "Auto-filled from registered streamer profile!" confirmation banner. **Status: Done**, matches your own note's spec closely.
- **Map pin auto-fills the venue description field — confirmed working**, but the underlying "address" it generates is not real reverse-geocoding. `LocationPickerModal._resolveAddressFromCoordinates()` is three hardcoded latitude/longitude thresholds mapping to one fixed string each ("Al-Faisaliyah, Dammam", "KFUPM Innovation District, Dhahran", "Corniche / Al-Rakah, Al Khobar") — anything outside those three zones silently falls through to the Khobar string regardless of where it actually is, even though the city dropdown itself also offers Al-Ahsa, Jubail, and Riyadh. **Status: Partial** — wiring is correct, but the content it fills in is a mock/placeholder, not accurate for 4 of the 7 supported cities. Worth either doing this properly with a real geocoding call or being upfront that it's a starting-point suggestion the applicant should edit.
- **Terms & Conditions checkbox + dynamic label — confirmed correctly implemented.** `apply_step_5_review.dart` wires the checkbox to `agreedToTerms`/`onTermsToggled`, and the clickable terms link correctly swaps text depending on `isOrganization`. **Status: Done.**

## Still open, confirmed unchanged from your own notes / Phase 1 & 4

- Image re-arrange/crop tool still doesn't match the X/Twitter-style behavior you asked for (your own note in `fix bug list.md`).
- No gray/broken-image detection or user-facing error flag on upload.
- YouTube handle format check and *live* existence verification: not found implemented — the wizard still needs both a regex check and a real "does this channel exist" call before showing any "verified" message.
- Phone number **display masking** (so the number shown isn't directly callable) — not found implemented, separate from the validation logic above which is done.
- "Edit Step" jump buttons on the review screen — still absent (UX audit finding, unchanged).
- The two phone-viewport overflow bugs from your own bug list (Step 3, 9.9px each) — not something a code read alone resolves; needs a device/emulator check.

## Security & data-handling notes specific to this role (from Phase 1)

Everything a streamer submits in the application wizard — legal name, phone, venue coordinates, YouTube channel — lands in `AdminDatabaseService`'s plaintext `SharedPreferences` store. The phone-masking gap above is a UX nice-to-have; the bigger issue is that the *underlying* number is stored unencrypted regardless of what's displayed. Once account deletion is built (Phase 3), it needs to actually purge this applicant record, not just the account flags.

## Streamer Studio / Go-Live (post-approval)

Confirmed built and functional: format switch (video/audio), RTMP target dialog, YouTube Live linking. The RTMP IP field takes free text with no format validation (Phase 1's re-scored VULN-DATA-03) — low security risk, but worth a basic "does this look like an IP" check purely for UX (typo prevention), independent of the security re-scoring.

## Priority fixes for this role

1. Phone masking + YouTube handle format/live verification (quick, well-scoped).
2. Decide whether to invest in real reverse-geocoding for the location auto-fill, or relabel it as a "suggestion, please confirm" rather than presenting it as authoritative.
3. Image re-arrange tool rebuild (your own note already scoped this against a known reference implementation — X/Twitter — so it's a matter of dev time, not design ambiguity).
4. "Edit Step" buttons on review — moderate UX win, not hard to add given the wizard already tracks per-step state.
