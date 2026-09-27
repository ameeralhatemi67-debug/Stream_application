# FIX-04: profile editing and card polish

Implemented on main `master` after `50349af`. No new branch, external task, push, app installation or hosted database operation.

## Behavior

- Profile cards use a top-end arrow (mirrored in Arabic) only when the biography exceeds its collapsed space or additional branch/own-organization actions exist. The generic YouTube metadata and Show more text are removed.
- Map cards have a soft shadow. The close decoration is 32px at 60% opacity, with a 21.6px X and a 48px touch target. It sits at the top end, beside the status chip.
- Discovery cards open the streamer profile, including live cards. Real saved tags replace the View channel button; empty tags produce no invented content.
- Verification forms stack paired fields below 600px and cap the sheet at 720px. Initial fields no longer inject sample credentials, biography, venue or tags.
- Viewer editing remains the separate name/avatar dialog. Approved-streamer editing has its own save path and explanatory copy; it does not offer an account-type switch or resubmit initial verification.
- Name, biography, academic/institution data, category and tags publish immediately. Contact email, phone, city/venue/coordinates, YouTube channel URL and handle changes create a pending revision. Approved public details remain until review. Email here is contact email, not an authentication-provider email change.
- Server-side ownership/approval/ban checks, a field allowlist and table guards enforce the rule. Pending revisions do not replace the broadcasting channel. Approval publishes a revision atomically; rejection preserves existing verification. Organization revisions preserve the existing organization ID. Save/review failures propagate instead of becoming cached success.

## Backend prerequisite

Apply `supabase/migrations/20260927030000_profile_edit_review.sql` to the intended backend before testing the new profile-save flow. It is **not applied to a hosted backend**. The editor fails visibly and retains the form if its RPC is unavailable; it does not silently use the old submission path. Existing initial approval remains separate. STREAM-D8 channel-ownership authorization is not solved by this change.

## Verification

- Flutter analyzer: zero issues.
- Full Flutter suite: **945 tests PASS across 66 files** (5m44s).
- SQL: fresh application of migrations after `20260925100000` to a schema-only local copy, then 478 passing assertions across all 24 test files. The copy includes only schema and deterministic feature-flag/keyword/bucket seeds, no account data from the source database. The existing local app databases were not modified.
- The new SQL regression covers every sensitive column, safe fields, ownership denial, direct-write/self-approval denial, rejection, repeated submissions and stable organization identity. Transport regressions cover server errors and rejection without revocation. Card tests cover short/long biographies, actual tags, en/ar, text scaling and desktop width caps; the existing map matrix spans 280–1280px.
- Logs: `brief/.runtime/fix04/`, including `flutter-full.log`, `analyze.log`, SQL logs and `sql-results.json`. Summary and final source hashes are retained beside this document.

## Owner retest after backend migration and hot restart

1. Discovery: check actual tags, then tap a card to open its channel.
2. Profile: a short biography has no expand arrow; a long one expands/collapses with the top-end arrow. Switch Arabic and check mirroring.
3. Map: check the softer shadow and smaller close decoration; close and venue navigation still work independently.
4. Viewer: Edit Account Profile offers only name/avatar.
5. Approved streamer: change name, biography, affiliation and tags; save, reload and confirm no new review is created.
6. Change one contact/location/YouTube field; confirm it waits in the admin review queue while the approved public channel/location remains unchanged. Reject a revision and confirm the original approval remains; submit again and approve to verify publication.
7. Repeat the form on a narrow phone and laptop, including Arabic and larger text.

Physical acceptance is pending. P5/P6 remain NOT ACCEPTED; P6S remains INCOMPLETE / NOT ACCEPTED; STREAM-D8 remains HIGH.
