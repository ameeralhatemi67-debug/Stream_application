# Lantern and Arch: report for the owner

> **Update, 2026-11-12, later the same day.** The owner asked to finalize, merge and push. Since this report was written: the migration `20261111120000_content_reports.sql` was tested on a local database (all 110 migrations apply on a fresh database; 17 rule checks pass) and applied to the hosted project; the owner's own studio work was committed on `master` (`fix(studio): ...`); and this branch was merged into `master` with one conflict resolved in `channel_connections_screen.dart` (both sides kept). On the merged code the analyzer reports 0 issues, the full suite passes (2,476 passed, 0 failed) and the web build succeeds. The sections below describe the state before that; their "waiting for you" items 1 and 2 are done. The push and the deployment are recorded in `brief/LEDGER.md`.

Written 2026-11-12. Branch `fable/lantern-skin`, in the worktree `.claude/worktrees/fable-lantern`. Nothing was pushed. Nothing was deployed. No migration was applied to the hosted database. No key or secret was created, printed or changed.

**In short.** The third design, Lantern and Arch, is built for almost every screen of the app and is chosen in Settings → Design. Gold & black is still the default. The two older designs changed in two places only, both intended: the new tile in Settings → Design, and a Report button for a broadcast or a channel, which you approved on 2026-11-12 so that Google's reviewer finds it in the default design. Pictures of 19 screens in both older designs, taken on `master` and on this branch at the same minute, show no other difference. The full test suite passes: 2,474 tests passed and 0 failed (65 more are picture tests that only run on request). All three designs were run on the Android emulator from a real Android build, with no error in the device log. Two things are not done: a signed app bundle (it needs your key), and a real run of the new database table (it needs your approval).

**Three decisions are waiting for you.** They are in section 7, first table.

---

## 1. The surprise

**An invitation picture for every mosque lesson.** Mosque lessons are announced with pictures that people forward in WhatsApp groups. The app now makes that picture itself.

- Where: open any lesson in the Lantern design, press Share, then "Make an invitation picture".
- What you get: a 1080 × 1350 picture in the Lantern identity (night ground, your lattice motif, the gold arch, the star, the Hedayah logo in white) with the lesson title, the preacher, the day with its Hijri date, the time by the prayer, the mosque, and the lesson's link.
- "Send the picture" opens the phone's share sheet with the picture and the link.
- It is made on the phone. Nothing is uploaded, no service is called, and it costs nothing.
- Code: `project/lib/core/widgets/lantern/lantern_poster.dart`. Tests: `project/test/lantern_poster_test.dart` (5).

A sample is at `brief/fable/shots/poster-en.png` after you run the picture command in section 2.

Pictures of the Lantern design running on the Android emulator (opening screen, Discover, map, place card, channel, replay, lessons; day and night; Arabic and English) are in `brief/fable/shots/emulator/`. They are on this computer only and are not committed.

---

## 2. What you can test now

### On your laptop, in Chrome

From the worktree's `project/` folder:

```powershell
flutter run -d chrome --dart-define-from-file="..\..\..\..\project\dart_define.local.json"
```

Then:

1. Open Settings → Design and choose **Lantern and Arch**. On the web you can also add `?skin=lantern-arch` to the address.
2. Settings → Design → Appearance: try Day, Night, Follow the device, and Calm motion.
3. Discover: the hero, "Also live", "Starting soon", the lessons row, the map card.
4. Open a live channel: the room is full screen. Leave with the close button in the top corner.
5. Map: search, the layer chips, the filter button, zoom, the legend, the list. Tap a group of places: the map comes closer until they separate. Tap a pin: the place card opens. Make the window wider than 1024 px: the list moves to a panel at the side.
6. Lessons: the home, the calendar (14-day strip, week grid), a lesson, a preacher, a mosque. On a lesson press Share → "Make an invitation picture".
7. A channel page: Follow, reminder, the four tabs, and the flag button (Report).
8. Signed in as a broadcaster: the studio from the channel page. "Hold to go live" and "Hold to end" need a press of about one second.
9. Signed in as an admin: `/admin`. The rail has four groups. The verification queue has checkboxes and a batch bar. The moderation tab has two parts: chat messages, and broadcasts and channels.
10. Switch back to Gold & black and to Hedayah. They must look as before, with one addition: a warning-sign button on a channel page and in a live room. It opens "Report this channel" or "Report this broadcast".

### Pictures without running the app

From `project/`:

```powershell
$env:LANTERN_CAPTURE_DIR = "..\brief\fable\shots"
flutter test test/lantern_capture_test.dart test/lantern_studio_test.dart test/lantern_poster_test.dart
```

This writes about 45 pictures of the Lantern screens: phone, tablet and laptop, Arabic and English, day and night.

### The closed-test build

It cannot be built yet. The steps are in section 6.

---

## 3. What was built

Every screen below has a phone layout and a website layout (1024 px and wider), in Arabic and English, in day and night. Each area has its own test file that checks layout without overflow, its states, and that its buttons call the same code as the older screen.

| Area | What is in it | Tests |
|---|---|---|
| Foundation | Colours for day and night, type, 96 drawn icons, the kit (buttons, hold-to-confirm, chips, fields, cards, badges, sheets, dialogs, the arch, the star, the lattice), the phone frame with the floating navigation, the website header and footer | `lantern_skin_test` 23, `lantern_compat_test` 148 |
| Opening screen | The arch drawn in gold, the star, the white logo, the gilt progress line; slow-network and offline states | `lantern_opening_test` 12 |
| Discover | Hero, also live, starting soon, scholar cards, lessons row, map card | `lantern_discover_test` 23 |
| Live and audio rooms | Full screen, one screen tall, only the chat scrolls; new chat with labelled roles; drawn reactions; Lantern message menu and sender window | `lantern_room_test` 45 |
| Map | Pins that never cover each other (labels included), groups that zoom until they separate, a short list for places on one spot, place cards, search, filters, zoom, legend, list, side panel, offline line, credits | `lantern_map_test` 39 |
| Lessons | Home, calendar, lesson, preacher, mosque, series | `lantern_lessons_test` 38 |
| Broadcast studio | One night page: status (not live, ready, live), three steps with one next step, controls, hold to go live and hold to end | `lantern_studio_test` 13 |
| Channel page | Night cover, identity below it, actions, four tabs with counts, organization variant | `lantern_channel_test` 22 |
| Broadcaster application | Step rail, one card per step, errors under each field with a summary, review with Edit links, status page | `lantern_apply_test` 29 |
| Settings, sign-in and the rest | Category list with panes, the Appearance pane, delete account as press-and-hold; welcome and consent; notifications; saved items; role choice; suspended account; page not found | `lantern_account_test` 68 |
| Admin | Night rail with four groups, overview cards, verification queue with batch actions and the five-stage approval, chat report queue, content report queue | `lantern_admin_test` 35 |
| Organizations | Organization home, shows and assignments with the schedule editor, YouTube connections | `lantern_org_test` 31 |
| Reports | Report a broadcast or a channel; admin queue. In all three designs since 2026-11-12 | `lantern_report_test` 19, `content_report_older_designs_test` 18 |
| Invitation picture | Section 1 | `lantern_poster_test` 5 |
| Contrast | Every colour pairing the kit uses, by the WCAG formula | `lantern_contrast_test` 9 |
| Isolation | No Lantern widget is built under an older design | `lantern_isolation_test` |

How the new design is kept apart from the older ones is written down as ADR-026 in `Core_files/decisions.md`. The build guide for anyone who adds a Lantern screen is `project/lib/core/widgets/lantern/README.md`.

**New features that exist only in Lantern:** the opening screen; full-screen rooms; the map grouping and place cards; the 14-day strip and week grid; hold-to-confirm for going live, ending and deleting an account; inline errors in the application; the Appearance pane; the invitation picture.

**The one new feature in all three designs: Report for a broadcast or a channel** (your decision of 2026-11-12). In gold & black and Hedayah it is a warning-sign button in the top bar of a channel page and of a live or audio room, and beside "Keep watching in the corner" in the website layout of a room. It opens a list of seven reasons; one tap sends the report, in the same way those designs already report a chat message. A guest is asked to sign in. The owner of a channel does not see the button on their own channel. Admins see the reports at the top of the chat moderation tab; that part draws nothing while there are no reports. The Lantern design keeps its own sheet (with an optional note) and its own queue.

---

## 4. Proof that the two older designs did not change

**Method.** A test (`project/test/skin_regression_capture_test.dart`) draws 19 screens in gold & black and in Hedayah: splash, welcome, Discover (phone and laptop, Arabic and English), the live room, the audio room, the map, lessons, the calendar, settings, a channel, the admin page and the lessons admin. One command runs it on a clean copy of `master` and on this branch at the same time, and compares the 38 pictures pixel by pixel:

```bash
bash brief/tools/skin_proof.sh <a checkout of master> <output folder>
```

The two runs must share the clock, because lesson and map screens show countdowns.

**Result before Report was added to the older designs (2026-11-12).** 36 of the 38 pictures were identical, pixel for pixel. The 2 that differed are the phone Settings page in gold & black and in Hedayah. The only difference is the new "Lantern and Arch" tile in Settings → Design, which moves the rows below it down. That change is intended: it is how a person chooses the new design. The pictures are in `brief/fable/skin_regression/tip_36308b5/` on this computer.

**Result with Report in the older designs (2026-11-12, the final code).** 28 of the 38 pictures are identical. The 10 that differ are the 2 Settings pictures above, and 8 pictures where the new Report button sits: the live room on a phone and on a laptop, the audio room on a phone, and the channel page on a phone, in each of the two designs. In each of the 8 the difference is confined to the row of action buttons (one more button, and on a phone the room's title has less room). The pictures are in `brief/fable/skin_regression/with_report/` (`before/`, `after/`, `diff/`) on this computer; the result list is committed as `brief/fable/skin_regression/RESULT.md`.

**Tests.** The whole suite passes on the branch: 2,474 passed, 0 failed. `lantern_isolation_test.dart` fails if any Lantern widget is built on a screen of an older design.

**On the Android emulator.** I built the Android app from `master` and from this branch with the same settings, installed each on the same emulator (Pixel 5), and opened the same five screens as a guest in gold & black and in Hedayah, in Arabic: Discover, the map, lessons, a channel page, and a replay. Discover, the map and lessons are identical, pixel for pixel, in both designs. The channel page differs only inside its cover, which has a slowly moving pattern: two pictures of the same build taken four seconds apart differ in the same area. The replay differs only inside the YouTube player (the video frame). The pairs are in `brief/fable/skin_regression/emulator/` (`before/` is `master`, `after/` is the branch). These emulator pairs were taken before the Report button was added, so the channel page and the room in them do not show it yet.

**Not covered on the emulator.** Settings and the admin page need a signed-in account, and I did not sign in with a real account. No channel was live at the time, so the live room and the audio room were not opened on the emulator. The test pictures above cover Settings, the admin page and both rooms.

---

## 5. Speed

**Measured: the size of the web app's main script.** This is what every web visitor downloads before the first screen.

| Build | Main script | Compressed |
|---|---|---|
| `master` | 6,259 KB | 1,771 KB |
| This branch, before the change below | 6,913 KB | 1,944 KB |
| This branch, final (with the change below) | 6,433 KB | 1,814 KB |

**What the numbers say.** The new design adds code that every visitor downloads, whichever design they use. **Change made (all designs):** twelve pages that a visitor who only watches never opens are now downloaded when they are opened, not at the start: settings, the broadcaster application, the viewer set-up, the three organization pages, the invitation page, the three "my lessons" pages, the preacher application and the preacher's page. This took 480 KB (130 KB compressed) off the main script. The new design now costs a web visitor 174 KB more than `master` (43 KB compressed, about 2.4%). A page that was already opened builds at once the next time, without a loading frame; this also applies to the admin pages, which were already loaded on demand. On a phone the pages are already in the app, so nothing changes there. The change is in `project/lib/core/routing/app_router.dart`, with one new test file (`project/test/flutter_test_config.dart`) that loads these pages before each test file runs.

**Measured: the Android app, on the emulator.** A signed release build needs your key, so I measured a profile build (the same compiled code as a release build, with measuring tools left in) for one processor type, on the Pixel 5 emulator. The emulator is much slower than a phone, so read the two columns against each other, not as phone numbers.

| | `master` | This branch |
|---|---|---|
| Cold start to the first frame, middle value of 7 starts | 5.28 s (5.05 to 5.67) | 5.53 s (5.22 to 6.52) |
| Compiled app code (`libapp.so`) | 19.9 MB | 22.2 MB |
| Install file (profile, one processor type) | 56.8 MB | 59.1 MB |

The new design adds 2.3 MB of compiled code and about a quarter of a second to a cold start on the emulator. The second number is close to the spread between runs, so treat it as "no clear change" until it is measured on a real phone.

**Not measured, and not done.** Memory, rebuild counts and frame times; the size of the real app bundle (it needs your key); cold start on a real phone; and the network work of ADR-025 round 2 (map tiles by range, a cached public catalog, a `--wasm` trial). The time went to the screens. Section 8 lists these as the next speed work.

---

## 6. Android and Google Play

The full status, with Google's pages and the date each was read, is `brief/fable/ANDROID_PLAY_STATUS.md`. It lists 15 requirements, what Google says today, the source link, and where the app stands. The short version:

**Ready**
- Target API 36, minimum 24. The last release APK's native libraries pass Google's 16 KB check.
- The manifest asks only for what the app uses. Backup is off, because the stored session must not be copied to another phone.
- Account deletion in the app, and a web page for it.
- Drafts for every Play Console form are in `store/`.

**Changed in this run**
- Google's user-content rule asks for a way to report content and its publisher, not only chat messages. That now exists in all three designs, so the reviewer finds it in gold & black. It works only after the migration is applied (the first decision in section 7).

**You must do, in this order**
1. Create your key: run `brief\launch\make_upload_key.ps1` yourself, in your own PowerShell. Keep the file and the password in two safe places.
2. Decide the version number (it must be higher than every APK you shared).
3. Build: `flutter build appbundle --release --dart-define-from-file=dart_define.local.json --dart-define=DISTRIBUTION=play` from `project/`.
4. Run the secret scan, then the checks in section 5 of the status file.
5. In Play Console choose **use your own key** before the first upload. Google makes its own key by default.
6. Upload to closed testing and fill the forms from `store/`.
7. Twelve testers must stay opted in for 14 days in a row before you can apply for production. Recruit 15 to 20.

**Checked on the Android emulator in this run (2026-11-12, Pixel 5, guest, real data from the hosted backend).**
- The Android build of this branch installs over the `master` build and starts in all three designs. The device log shows no Flutter error and no crash.
- Lantern: the opening screen, Discover (day, night, Arabic, English), the map (a group of 4 places zoomed until it split; a pin opened the new place card), the channel page, a replay, and the lessons home.
- Gold & black and Hedayah: Discover, the map, lessons, a channel page and a replay, the same as on `master` (section 4).
- A replay failed once with a network error and played after Retry. The error page and its Retry button worked.

**Not checked on a device.** A signed release build. Sign-in, Settings, the studio, the admin page and phone broadcasting (they need an account; I did not sign in with a real one). A live room and an audio room (no channel was live). "Use my location" on the map. These need your test accounts and a real phone; the steps are in `brief/launch/02_TESTING_PLAN.md`.

---

## 7. What is not done, and what waits for you

### Decisions for you

| # | Decision | Why it matters | My advice |
|---|---|---|---|
| 1 | Apply the migration `supabase/migrations/20261111120000_content_reports.sql` | Until it is applied, the Report action answers "could not be sent". It was not run anywhere, not even on a local database, because Docker was not running on this machine. | Start Docker, run `npx supabase start` and `npx supabase db push` locally first, then apply it to hosted. |
| 2 | Merge order | Your uncommitted studio work on `master` touches `app_provider.dart` and `rtmp_ip_dialog.dart`. This branch changes both. | Commit your work first. Then merge this branch and resolve those two files. |
| 3 | The open design questions | Section 9 lists the default I chose for each. | Read section 9 and tell me which to change. |

### Not built

- **Screens still drawn by the older widgets under Lantern.** They are restyled by the shared kit, so they are one design, but they do not have their own Lantern layout: twelve admin tabs (registry, organizations management, analytics, terms, custom cards, categories, tags, banned accounts, roles, user directory, safety, testing tools); `/org-admin`; the organization invitation page and the members list; the "my lessons" pages, the preacher application and the preacher's link page; the lessons admin; the viewer set-up; the phone camera screen used while broadcasting.
- **A corner player that keeps playing.** Leaving a room still stops playback and leaves a way back, as in the older designs.
- **From the design, left out because the app has no data for it:** the Now / Tonight / This week control and the locate button on the map; charts and "days to review" in the admin overview; a speaking signal in audio rooms; "draft saved" in the application.
- **Report for one recording.** A broadcast can be reported while it is live, and a channel at any time. A single recording has no Report button of its own in any design; a viewer reports it through its channel.
- **The data export** (`20261015172851`) does not yet include the reports a person filed in the new table.
- Speed work beyond section 5, and the device checks listed as "not checked" in section 6.
- In the night look the map itself keeps its light colours; only the controls around it are dark.

### Known weak points

- Some older handlers still show a plain message bar under Lantern (for example after deleting an account or exporting data).
- Small action buttons on admin cards are 36 px high, below the 44 px target.
- The schedule editor uses the system date and time pickers.
- A full, successful broadcaster application is not covered by a test, because the map picker cannot be driven in tests.

---

## 8. Suggestions, ranked by value

All are free unless marked.

**Before the Play review**
1. Apply the migration before you submit (item 1 of section 7). Report is now in the default design, but it answers "could not be sent" until the table exists. Then send one test report and clear it from the admin tab, and keep a screenshot for Google's moderation form.
2. Add the YouTube API Services statement to `privacy.html`, with links to Google's privacy policy and the YouTube Terms. YouTube's terms require it.
3. The audio stage draws over the YouTube player, in all designs. YouTube's terms forbid drawing over the player. Move the player off screen at 200 × 200 px or show it.
4. Prepare the reviewer account from `store/reviewer_access.md` and test it on a real phone.

**Product**
5. Put the invitation picture on live broadcasts and channel pages too. The widget already takes any title, person and three facts.
6. A corner player that keeps playing while people browse.
7. The Now / Tonight / This week control on the map: it answers "what is near me tonight" in one tap.
8. Make Lantern the default after one release with both, and retire one older design. Three designs cost testing time on every change.

**Speed**
9. Load the broadcast studio on demand as well; then split the map and the lessons the same way.
10. Read map tiles by range instead of downloading the whole 11.8 MB file (ADR-025 round 2).
11. Measure cold start and memory on a real mid-range Android phone with a release build.

**Legal and privacy**
12. Saudi PDPL: name a contact for data requests in the privacy page, and state the retention time for reports and chat messages.
13. Add filed reports to the data export, and delete them with the account (the table already deletes them when the account is deleted).
14. Write down who reads content reports and how fast. Google asks for this in the moderation form.
15. Have a lawyer confirm the target age (the drafts say 18 and over).

**Security**
16. Run `npx supabase db advisors --linked --type security` after applying the migration.
17. The new table limits each account to 20 reports a day. Watch the queue in the first weeks and lower the limit if it is abused.
18. Rate-limit chat messages and follows on the server if that is not done yet.

**Accessibility**
19. A real screen-reader pass (TalkBack) on the rooms, the map and the studio. The tests check labels, not how it sounds.
20. Raise the small admin buttons to 44 px.

**Store listing and growth**
21. Use the Lantern pictures for the Play screenshots only after Lantern is the default; otherwise the listing shows a design people do not get.
22. Put a sample invitation picture in the listing: it shows what the app is for in one image.

---

## 9. Decisions I made on the open questions

Each is one place in the code and easy to change.

| Question | What I chose | Where to change it |
|---|---|---|
| Day or night by default | Day | `LanternAppearance.fallback` in `lib/core/theme/app_skin.dart` |
| The arch as the signature frame | Yes: cards, pins, the poster, the 404 page | `LArchBorder` in the kit |
| Reactions | Drawn icons, not emoji | `lantern_room_stage.dart` |
| Chat roles | Labelled chips | `lantern_room_chat.dart` |
| IBM Plex Sans Arabic 500 and 600 | Not added; the app ships 400 and 700 | `pubspec.yaml` fonts |
| Hacen Maghreb | Not bundled until the licence is confirmed; headings use Readex Pro | `Lantern.display` in the tokens |
| Locate button and the Now / Tonight / This week control | Not built | Section 7 |
| Speaking signal in audio rooms | Not built; there is no data for it | |
| Press and hold | Go live from a laptop, end a broadcast, cancel a prepared show, delete an account, delete or ban in moderation | `LHoldButton`; the length is `Lantern.hold` (1.2 s) |

---

## 10. Commits, the migration, and how to review and merge

**Commits.** 50 commits on `fable/lantern-skin`, on top of `master` `77bcff0`. See them with:

```bash
git log --oneline 77bcff0..fable/lantern-skin
```

**Migration waiting for approval.** One file: `supabase/migrations/20261111120000_content_reports.sql`. It adds the table `content_reports` with its rules: one report per person per thing, 20 a day per account, a person inserts as themselves and not about their own channel, only admin tiers read and clear.

**To review.**

```bash
git diff 77bcff0..fable/lantern-skin --stat
git diff 77bcff0..fable/lantern-skin -- project/lib ':!project/lib/**/lantern/**'
```

The second command shows only the changes to files the older designs use. They are additions behind `context.isLanternSkin`, the router change of section 5, the report service, and the Report button with its sheet and admin list for the older designs (`lib/features/moderation/presentation/content_report_sheet.dart`).

**One thing I changed on the emulator.** While I set the design from the command line, one failed step emptied the app's stored settings on the Pixel 5 emulator. The app then started as on a first run, and I entered again as a guest with the display name "Tester". No account was involved. If you kept a guest set-up on that emulator, it is gone.

**To merge and push** (pushing `master` deploys the website):

```bash
# 1. Commit or set aside your own uncommitted work on master first.
git checkout master
git merge --no-ff fable/lantern-skin
# 2. Resolve app_provider.dart and rtmp_ip_dialog.dart if your work touched them.
cd project && flutter analyze && flutter test
# 3. Only when you are satisfied:
git push origin master
```

**Left on disk by this run.** Worktrees of the helpers under `.claude/worktrees/agent-*` and a clean copy of `master` at `.claude/worktrees/skin-proof-master`. Their work is merged. Remove them with `git worktree remove <path>` when you no longer need them. I did not delete them, because deleting is yours to approve.
