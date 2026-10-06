# Design handoff: what is on master, what is not, and what to do next

**2026-10-06 bookmarks update:** Bookmarked Lectures is now a functional saved
library rather than a fixed empty sheet. It uses the current Canopy header,
compact thumbnail/date rows, clear play/remove actions and type filters. Saved
recordings show thumbnail badges and checked green player actions; upcoming cards
have their own save control, independent of reminders. English/Arabic phone and
desktop renders were inspected, including large-text widget checks. The
owner-requested completed-session list in profile headers and the VOD avatar ring
are removed. Saving remains account-backed for signed-in viewers and session-only
for guests; it does not download videos.

**2026-10-06 update:** The owner approved the feed-card loading preview and
restricted implementation to Discovery Hub. Its card skeletons now follow the
actual first catalog request, stop on completion/failure, and preserve existing
or cached cards during refreshes. Discovery banner/avatar images have opt-in
placeholders until their first frame or error. Other screens keep their current
loading behavior. No artificial delay or random loading state was added.
The rest of this document retains the 2026-10-05 audit baseline.

Written 2026-10-05 at the end of the design-migration session. Read this first, then `Core_files/STATUS.md`, `Core_files/decisions.md` and `CLAUDE.md`. It is meant to be enough for a new agent to continue without asking the owner for context.

**Contents**

1. State of the app right now
2. Owner rules (non-negotiable; learned the hard way)
3. How a page gets ported (the method) and the design-system pieces we added
4. NOT used from the `design-audit/2026-10-identity` branch
5. NOT used from the three artifacts (Hadayah Identity Lab, Web Preview, Phone Audit)
6. Impeccable review of the live app: web (1280x800) and phone (390x844)
7. Suggestions: friendlier and more alive (web and phone may differ)
8. Recommended order of work for the next agent
9. Appendix: IDs, commands, gotchas

---

## 1. State of the app right now

- Repo: `C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app`. Branch `master` only (no PRs, no feature branches). Flutter app in `project/`. All Flutter commands run from `project/`.
- Live site: https://stream-application-ten.vercel.app (Vercel team `team_esYRC0Dnt9BlycZOvBkShY8T`, project `stream-application`; every push to `master` deploys, takes about 3 to 4 minutes).
- Hosted Supabase project: `zkkmfjsjouqzibvnzkau`. Use the Supabase MCP connector (`apply_migration`, `execute_sql`); the Supabase CLI login does not work on this machine. After applying a migration through MCP, rename the local file to the version MCP assigns (see the memory note "Supabase MCP deploy").
- Gates that were green at the last commit: `flutter analyze` 0 issues, `flutter test` 1056 passed, release web build compiles (`flutter build web --release --dart-define-from-file=dart_define.local.json`), translation catalogs symmetric (a script check, see the appendix).

### Commits made this session (newest first), all on `master` and pushed

| Commit | What |
| --- | --- |
| 7b26eb1 | Avatar rings removed from the four cards the owner named; profile card rises over the green panel; header icons at the top |
| afa67fa | Chat moderation in the sender window: mute 5/10/60 min or rest of stream, mute status and unmute, delete all of a sender's messages, make/remove moderator |
| 89c9924 | Rolling viewer count, animated bottom-nav pill, pull-to-refresh star (feed only) |
| 2d493d9 | Identity rings (CaAvatarRing), compact chat bubbles, sender profile window, `chat_moderator_since` migration |
| 696302d | Profile and Organization pages ported (archive, playlists, upcoming, video sheet, org hub/shows/membership/invitation/channels) |
| 3b194cc | Rounded-rectangle selected nav item; translation catalogs served `no-cache` (fixes raw keys appearing after deploys) |
| a394ff0 | Feed card: large avatar, taller banner, status badges on the banner corner |
| 7f8f3f1 | Discovery feed ported (card grid, filter sheet, notifications and bookmarks sheets, laptop side nav, phone bottom nav) |
| 1a5ef2c, 13c1c40, 63c6d54, d7b6cc0, 569d534 | Earlier ports: onboarding/apply wizard, admin, settings, streaming screens (earlier sessions) |

### Working tree

The profile chevron fix (section 6.2, RTL residue) was committed together with this file. The remaining modified and untracked files (`skill-observations/log.md`, `store/assets/icon_512.png`, `Core_files/LOGIC_RISK_REVIEW.md`, `Core_files/ORGANIZATION_FEATURE_*.md`, `brief/**`, `doc/Design_1/`) belong to the owner; do not commit them.

### What is migrated and what is not (user-visible)

| Area | Looks like | Notes |
| --- | --- | --- |
| Discovery feed, notifications/bookmarks/filter sheets | New (Emerald Canopy) | Column rule is master's, not the redesign's |
| Broadcaster / organization profile, video sheet, playlists, upcoming | New | |
| Organization hub, shows, members, invitation, channels | New | |
| Settings, admin console, apply wizard, role choice, application pending, edit profile, location picker | New | |
| Live room (viewer), phone studio, chat | New | |
| Navigation shell (laptop side nav, phone bottom pill) | New (restyled in master's structure) | `CaShell`/`CaRail` from the redesign exist but are not used |
| **Welcome, viewer setup, splash, account-banned** | **Old** | Still `EntryBackground`, three white buttons |
| **Map and all `features/map/**` widgets** | **Old** | Red accent, side drawer, stacked search/filters |
| **Consent, device-conflict, duplicate-channel dialogs** | **Old** | |
| Global theme (`app_theme.dart`) | Old values with additive Canopy members | Flipping it restyles every screen at once |

---

## 2. Owner rules (non-negotiable)

These came from the owner in chat. Several were stated more than once.

**Process**

1. Commit to `master` directly. One conventional commit per task, listing every owner deviation from the redesign in the message. End with `Co-Authored-By: Claude <model> <noreply@anthropic.com>`. Push when finished (the owner asked for pushes in the porting workflow) and confirm the Vercel production deployment for the commit reaches READY with `list_deployments` / `get_deployment`.
2. Stage only the files you changed. Never commit the owner's unrelated files: `skill-observations/log.md`, `store/assets/icon_512.png`, and untracked notes (`Core_files/LOGIC_RISK_REVIEW.md`, `Core_files/ORGANIZATION_FEATURE_*.md`, `brief/**`, `doc/Design_1/`).
3. Never replace a shared widget's default look. Add opt-in flags only. `app_theme.dart` on master only ever gains additive members.
4. Never port pixel-golden tests. Take the design branch's version of a test only if it covers pages already merged; otherwise adjust only the affected expectations.
5. Look at the result before committing: write a throwaway widget test that pumps the page at 390x844 and 1280x800 in `en` and `ar`, loads IBM Plex Sans / IBM Plex Sans Arabic / MaterialIcons with `FontLoader`, run with `--update-goldens`, read the PNGs, then delete the throwaway files.
6. Ask before outward-facing or hard-to-reverse actions. The owner approved the `chat_moderator_since` migration explicitly; other database changes need approval.

**Design**

1. **No background circle behind any icon or SVG.** Use the opt-in flags: `CaIconButton(bare: true)`, `CaButton(bareTrailing: true)`, `LanguageSwitcher(canopy: true, bare: true)`, `CaLanguageChip(bare: true, compact: true)`, `CaAppBar(languageBare: true, compactLanguage: true)`, `CaSheet(bareChrome: true)`, `showCaSheet(..., bareChrome: true)`.
2. **The language control is icon only.** No "عربي" / "EN" text next to it.
3. **Bottom sheets are full phone width on phones only** (`showCaSheet(..., fullWidthOnPhone: true, flushOnPhone: true)`); web and tablet keep their current presentation. Do not use `useRootNavigator: false` for these; they must cover the bottom navigation.
4. **Cards:** phones show exactly one card per row; laptops up to four. Rule: `columns = (maxWidth / 300).floor().clamp(1, 4)` (master's, kept on purpose). Never `CaStreamerCard.columnsForWidth` (forces two).
5. **Feed app bar has no logo.**
6. **Laptop side navigation** keeps master's structure and order: logo, Discovery Hub, Spatial GIS Map, (Studio profile for streamers), Settings, (Admin Hub with pending badge), (Org Admin for permitted admins), Streamer/Viewer mode card at the bottom. The selected item is a rounded rectangle (`CanopyRadius.input`), never a full pill.
7. **Arabic/RTL must work.** Use start/end, never left/right. Note: `Icons.chevron_left/right` already mirror themselves in RTL (`matchTextDirection`); never switch glyphs by hand.
8. **Avatar rings** (the Identity Lab "LQ" ring): green gradient ring for admins and broadcasters/organizations, spinning crimson when live, violet for chat moderators. The owner then asked for them to be **removed from four places only**: map cards, discovery cards, the account page, the settings card. They stay in chat, admin lists, the live room, organization headers and the video sheet. Do not add them back to those four.
9. **Profile page:** keep the green gradient panel exactly as designed (160 dp, lattice); the card with banner and avatar rises about 18% over it; the back/language/share icons sit at the top of the panel; the avatar has a white stroke ring; archive tiles and playlist rows are all the same height; descriptions show 2 lines with a down/up arrow; the upcoming-live tab uses the date-badge cards.
10. **Chat:** compact bubbles, role shown only by avatar ring (no names or badges for admin, moderator, broadcaster), messages over two lines collapse behind an arrow, sender profile window on avatar tap.
11. Translations: every `'x.y'.tr()` used in `project/lib` must exist in `assets/i18n/en.json`; `en.json` and `ar.json` stay key-symmetric; never change existing values. New Arabic strings are drafts (owner reviews).

---

## 3. How a page gets ported, and what we added to the design system

### Method (same every time)

1. `git show design-audit/2026-10-identity:<path> > <path>` for the requested files only. Never copy shared files wholesale (`app_theme.dart`, `entry_background.dart`, `app_router.dart`, `language_switcher.dart`).
2. Recolour only the ported files with these `AppTheme` to `Canopy` replacements: `bg` to `Canopy.dawn`; `surfaceAlt` to `Canopy.mint`; `border` to `Canopy.hairline`; `borderStrong` to `Canopy.hairlineStrong`; `textPrimary` to `Canopy.ink`; `textSecondary` to `Canopy.slate`; `textMuted` to `Canopy.haze`; `success` to `Canopy.leaf`; `danger` and `live` to `Canopy.liveCrimson`; `shadowSoft` to `Color(0x1F123E26)`; `shadow` to `Color(0x33123E26)`; `shadowStrong` to `Color(0x4D123E26)`. (A one-line `sed -E` over the files works.) Note: nine of those shadow literals are now scattered in the code; a `CanopyShadow` token would be cleaner.
3. Backgrounds: design-system code uses `core/widgets/ds/canopy_lattice_background.dart` (`CanopyLatticeBackground`), not `EntryBackground` (which is the welcome screen's background on master).
4. Run `flutter analyze` and fix additively (add missing members or opt-in flags).
5. Translation check, tests, throwaway render, commit, push, confirm Vercel READY.

Tooling gotchas: do not put Python containing `'''` inside a bash heredoc (the shell breaks); write the script to the scratchpad with the Write tool and run it. Never `pumpAndSettle` on screens with the live ring or lattice (they animate forever); pump fixed durations. `AnimationController` created lazily inside `dispose()` throws; create controllers in `initState`.

### Additive design-system pieces added this session (all default off or new)

| Piece | Where | Purpose |
| --- | --- | --- |
| `AppGradients.panel` | `core/theme/app_theme.dart` | The green panel gradient (alias of `CanopyGradients.panel`) |
| `CanopyGradients.liveRing`, `.moderatorRing` | `core/theme/canopy_tokens.dart` | Crimson and violet sweep gradients |
| `CaAvatar(ring: CaAvatarRing.{none,brand,admin,moderator})` | `ds/ca_cards.dart` | Identity ring; `live: true` always wins (spinning crimson). Footprint stays 2r+4, the picture shrinks to fit the ring |
| `CaCardImage` | `ds/ca_cards.dart` | Public banner image with canopy-gradient fallback |
| `CaScholarCard(largeAvatar, bannerOverlay)` | `ds/ca_cards.dart` | 68 px avatar straddling the banner; badges on the banner's top-end corner |
| `CaFixedLines` | `ds/ca_fixed_lines.dart` | Text that always takes exactly N lines, for equal-height tiles |
| `CaSheet(bareChrome)`, `showCaSheet(bareChrome, flushOnPhone)`, `CaDialog(bareClose)` | `ds/ca_surfaces.dart` | Icon-only sheet chrome; edge-to-edge phone sheets |
| `CaChatBubble(role, handRaised, pending, onAvatarTap)` + `CaChatRole` | `ds/ca_feedback.dart` | Compact chat bubble, 2-line cap, arrival motion |
| `CaRollingCount` (per-digit roll) | `ds/canopy_content_motion.dart` | Viewer count (rolls only when the number changes) |
| `CaHeroCard(viewerCount, viewerSuffix)` | `ds/ca_discovery.dart` | Rolling viewer pill on the feed hero |
| `CaNavBar` animated flex-grow pill | `ds/ca_navigation.dart` | Active item grows, other folds, 320 ms |
| `CaPullToRefresh` | `ds/ca_pull_to_refresh.dart` | Star draws as you pull, spins while loading (feed only so far) |
| `AppRouter._canopyPage` | `core/routing/app_router.dart` | Card-to-page transition for `/profile/:id` and `/live/:id` (see audit finding on back gesture) |
| `ChatSenderProfileSheet`, `showChatSenderProfile`, `ChatMessageRole` | `features/live_stream/presentation/widgets/chat_sender_profile_sheet.dart` | Sender window with moderation tools |
| `LiveChatController.muteUser(duration)`, `muteStatus`, `deleteMessagesFrom`, `moderatorSince`, `revokeStreamModerator` (now detects refusal) | `live_stream/services/live_chat_controller.dart` | Backend calls for the above |
| Migration `20261005144121_chat_moderator_since` | `supabase/migrations/` | Applied to the hosted project |

---

## 4. NOT used from `design-audit/2026-10-identity`

### 4.1 Facts about the branch (read before deleting anything)

- It is **not pushed to GitHub** (`git ls-remote` shows only `master`). 44 commits are on it that are not on master (as of the merge-base `7011de6`); master has since moved on by the port commits.
- Its worktree is `.claude/worktrees/design-audit` (2.6 GB). It has uncommitted generated files and untracked `doc/screenshots_4-10/` and `project/test/failures/`. There is a stash on that branch (`stash@{0}`, "owner prompt preserved before design fixes and phase 5"). Stashes are shared across worktrees, so it survives deleting the folder.
- If the owner wants the history, push the branch or archive it before deleting. Deleting only the worktree folder (not the branch) is safe.
- Its docs are the design source of truth for what was intended: `design-audit/DESIGN.md` (tokens and rules), `09_OWNER_DECISIONS.md` (owner decisions A to G), `08_DEFECTS_FOUND.md` (D1 to D39), `15_PHONE_AUDIT.md`, `16_RESPONSIVE_SYSTEM.md`, `REDESIGN_LEDGER.md`, `REDESIGN_STATUS.md`. Copy the ones worth keeping into master (`Core_files/` or `doc/`) before deleting.

### 4.2 Screens and files still to port (design branch version differs from master)

Sizes are lines changed against master (additions + deletions of the whole-file diff, so they overstate real remaining work for files that only need recolouring).

| Area | Files | Size | Notes |
| --- | --- | --- | --- |
| **Map** | `features/map/presentation/spatial_map_screen.dart` | ~310 | Redesigned map screen |
| | `widgets/venue_navigation_sheet.dart` | ~620 | |
| | `widgets/streamer_sliding_drawer.dart` | ~390 | Redesign turns the side drawer into a persistent bottom sheet |
| | `widgets/map_status_details.dart` | ~290 | |
| | `top_spatial_search_bar.dart`, `pulsing_live_marker.dart`, `map_discovery_channel_card_marker.dart`, `map_diagnostic_logger.dart` | small | |
| | rings were removed from map cards by the owner (section 2) | | Do not re-add |
| **Welcome / entry** | `features/auth/presentation/welcome_screen.dart` | ~510 | Mesh gradient + lattice, one filled primary |
| | `viewer_setup_screen.dart` | ~300 | |
| | `screens/account_banned_screen.dart` | ~210 | |
| | `features/splash/presentation/app_splash_screen.dart` | ~160 | Capsule loader + wordmark |
| | `core/widgets/entry_background.dart` | ~300 | The redesign's version; master deliberately keeps its own |
| **Global dialogs / shared** | `duplicate_channel_resolution_dialog`, `device_session_conflict_dialog`, `device_session_presenter`, `consent_dialog` | ~100 each | |
| | `hadayah_loading_indicator`, `connectivity_banner`, `floating_stream_mini_player`, `streamer_identity_card`, `app_logo`, `content_width` | small | |
| **App-wide** | `core/theme/app_theme.dart` | ~300 | Global Canopy colours, radii, spacing and Readex Pro headings (see 4.4) |
| | `lib/main.dart` | small | Text-scale cap constant (`CanopySize.textScaleMax`) and reading-order focus traversal |
| | `pubspec.yaml`, fonts | | `assets/fonts/ReadexPro-*.ttf` (3 files) and their `pubspec` entries |
| **Copy** | `assets/i18n/en.json` / `ar.json` | ~40 lines | App renamed "Hadayah Live" in `notification_models`, `terms_and_conditions_model`, and about eight strings; friendlier wording for developer-ish copy (D5, D6 below) |
| **Admin streamer editor** | `streamer_editor_sheet.dart` | ~55 | Admin opens it; stayed as master on purpose |
| **Tests** | about 35 files unique to the branch | | `redesign_phase*_test.dart`, `redesign_responsive_test`, `redesign_fixes_test`, `layout_sweep_test`, `canopy_components_test`, `theme_contrast_test`, `owner_design_edits_test`, `tile_bank_test`, `v04_ui_ux_specialist_test`, `admin_safety_console_test`, and others. Port only for pages already merged, adjusting expectations |

### 4.3 Never merge (branch-only scaffolding)

- `project/lib/design_audit/**` (audit harness, 6 files), `project/assets/design_audit/` (14 demo images), `debugAuditApplyState()` in `app_provider.dart`, the `analysis_options.yaml` exclude, the `archive` dependency in `pubspec.yaml`.
- `project/test/goldens/` (1,563 pixel goldens), `project/test/support/*goldens*`, `design-audit/screens/**` (about 400 reference screenshots), `brief/evidence/2026-10-02..04/**` (about 1,000 files). Keep as an archive outside the app if wanted.

### 4.4 Ported pages, but parts of the redesign deliberately not used

| Item | Redesign did | Master does | Why |
| --- | --- | --- | --- |
| Feed card columns | `CaStreamerCard.columnsForWidth` (always two on phones) | `(maxWidth/300).floor().clamp(1,4)` | Owner: one card per row on phones |
| Medium (600 to 899) navigation | Left rail `CaRail`, 84 dp, icon over label | Bottom pill below 900 | Owner: keep master's behaviour; `CaShell`/`CaRail` unused (audit P2) |
| Large (1280+) content cap | `CaShell` caps content at 1200 | No cap | Master structure kept |
| Rail logo | `AppLogo` | `AppLogo` (charity mark dropped: it has a grey background block) | |
| Page transitions | `_canopyPage` on profile, live and settings | Only profile and live | Settings left on the default |
| Circles behind icons, language label | Present | Removed everywhere (flags, section 2) | Owner rule |
| Header banner on profile | Not in redesign (identity card had no banner) | Banner in the card, panel kept | Owner |
| Avatar rings on cards | Redesign had a live ring only | Removed from four places | Owner |
| Hero `EntryBackground` in `CaHeroCard` / profile header | `EntryBackground` | `CanopyLatticeBackground` | Rule 3 in section 3 |
| `AppTheme` as global palette | Whole app restyled | Additive only | Master screens not yet migrated keep their palette |

### 4.5 Defects from `08_DEFECTS_FOUND.md` (D1 to D39): status on master

"Fixed" means the page was ported from the design branch and the specific defect no longer appears in source or in the renders we viewed; it was not re-verified on a physical device. "Present (confirmed)" means I checked master's source in this session.

| ID | Defect | Status |
| --- | --- | --- |
| D1, D2, D3 | White-on-white VOD/playlist/speaker titles | Fixed (profile ported; titles use `Canopy.ink`) |
| D4 | Invented lecture content in Sources tab (fake PDF, fake chapters) | **Partly present (confirmed):** `app_provider.dart:355` still defaults `_customSlidesUrl` to `https://kfupm.edu.sa/cs/slides/lecture_01.pdf`; `en.json` still has `slides_pdf_title`. The fake chapters no longer appear in `lib` |
| D5 | Development copy ("Testing Phase", "Profile Picture URL / Asset (Optional)", "Re-open Welcome & Onboarding") | **Present (confirmed)** in `en.json` lines 648, 659, 678 |
| D6 | Two product names ("Streamer App" vs "Hadayah Live"; `support@streamer.app` on the ban screen; `https://streamer.app/join/...` in `app_provider.dart:1829`) | **Present (confirmed)** |
| D7 | Crimson used as a primary colour | Fixed on migrated screens; still present on Map and old screens |
| D8 | Roles printed as words in chat names | Fixed (new chat) |
| D9 | Hero scales with the window | Fixed (hero heights capped per window class) |
| D10 | Rail shows a different brand mark | Fixed (`AppLogo`) |
| D11 | Organization screens unstyled | Fixed (ported) |
| D12 | Three input and four button styles | Partly: fixed in migrated screens; admin still uses legacy buttons (about 124) |
| D13 | 264 text styles at 11 px or smaller | **Present:** audit counted 565 `fontSize` literals, 36 below 12 |
| D14, D31 | Admin KPI "Unavailable" in display type; one tile per row | Fixed (`CaKpiTile`, "Not measured") |
| D15 | Live audio badge collision, bare minimise glyph | Fixed in ported live room (verify on device) |
| D16 | Profile opens on Archive | Check: default tab is index 0 (Archive); the redesign proposes Upcoming first |
| D17 | Map first-run banner stacks three layers | **Present** (map not ported) |
| D18 | Desktop dialogs/sheets not adapted | Partly: `CaSheet` becomes a dialog from 600 wide; old dialogs not |
| D19 | Tablet is the phone layout stretched | **Present at 600 to 899** (no rail) |
| D20 | Search filters only the grid | Unknown; verify |
| D21, D22, D36 | Go-live overflow; broadcasting screen; landscape controls | Fixed in ported studio (verify on a device) |
| D23 | Tab labels do not fit | Fixed (`CaSegmentedTabs`) |
| D24 | Feed cards tall, Offline chip each | Partly: cards shorter; the Offline chip stays (owner wants status on the banner) |
| D25 | Map list is a side drawer | **Present** (map not ported) |
| D26 | Sticky bars cover content | Fixed in ported screens |
| D27 | Crimson carries the broadcaster journey | Fixed in ported screens |
| D28 | Wizard progress stated three times | Fixed (`CaStepper`) |
| D29, D30 | Admin title truncated; admin lists tiny | D29 fixed; D30 partly |
| D32 | Settings one 3,800 px scroll | Fixed (grouped, rail on laptop) |
| D33 | Duplicate titles | Fixed on profile and video sheet |
| D34, D35 | Empty chat prompt; add-planned-stream spacing | Fixed in ported screens |
| D37 | Testing tools in the admin menu | **Present (confirmed):** `admin_hub_screen.dart` still has the "Pitch Director Mode" tab |
| D38 | Splash mostly empty | **Present** (splash not ported) |
| D39 | Stream key via clipboard | Check: a Paste action was proposed |

---

## 5. NOT used from the three artifacts

Artifact links (private, owner's account): Hadayah Identity Lab https://claude.ai/artifact/9WEaLx7wkN3x5TegWA2ZJu, Hadayah Web Preview https://claude.ai/artifact/RSVmhHK1MNHFoqe39msF8t, Hadayah Phone Audit https://claude.ai/artifact/LptPptMF3MCjHRHcJ431zn (all updated 2026-10-02). Read them with the Artifact tool (`action: read`); the full HTML is saved locally on read.

### 5.1 Hadayah Identity Lab

**Gradients.** Four presets exist: "Your sketch" (the one used: 65 degrees, depth 75, `#123E24 to #23773F to #31A05A`), **Canopy, Dawn, Teal tide (not used)**. Gradient motion options: Still, Drift (used on hero), **Sheen and Drift + sheen (not used)**. A live contrast guard and "Copy as Flutter" code exist in the artifact.

**Textures.** Twelve (nine geometric, three utility); only the **star lattice at 17% (0.136) on emerald with faded edges** is used. The other eleven are unused options. Texture motion: phones Drift; website Drift + Spotlight. Master has the pointer spotlight on the feed hero (web) only; spotlight on other large surfaces (profile header, sheet headers) is not wired. "Inspect x3" is an artifact tool only.

**Components tab (21 groups).** Used: buttons, icon buttons/language/glass, chips and filters, segmented tabs, inputs, search field, cards, lecture tile, status chips, avatars, chat, empty state, stepper, admin tiles, settings rows, quality presets, connection banner. **Built in the design system but not used by any screen:** `CaPersonRow` (person rows), `CaToast` (the app uses its own `interactive_toast_overlay`), `CaSuccessBloom`, `CanopyReconnectMotion`, `CaShell`, `CaRail`. Not built at all: "Loading" variants beyond the capsule loader and `CaSkeleton` (ring and indeterminate bar loaders were accepted by the owner).

**Motion tab: 27 demos, all accepted by the owner (decision D1 in `09_OWNER_DECISIONS.md`).** Status on master today:

| Group | Demo | On master |
| --- | --- | --- |
| Touch | Press feedback, button states, chip select, follow toggle (check draws), hold to end broadcast (1.2 s, phones) | Yes |
| Navigation | Sheet entrance, tab indicator thumb, card to page, popover/dialog, toast and swipe | Yes |
| | **Draggable sheet (peek / half / full snaps)** | **No** (belongs to the Map port) |
| | Bottom nav pill (flex grow) | Yes (added this session) |
| | **Page push (shared axis)** | Only on `/profile` and `/live` |
| Loading | Skeleton to content (blur 4 to 0), loaders that stay, list stagger | Partial: skeletons only on page-loading branches; the feed stays blank until images arrive (audit finding) |
| | Pull to refresh | **Feed only** (added this session); not on profile, org hub, notifications, map list |
| Live | Live signal (ring ping + spinning ring), floating reactions, chat arrival, viewer count roll, audio level meter, reconnect banner (`CanopyReconnectMotion` exists, unused) | Yes except reconnect banner motion unused. The spinning ring was removed from the four card surfaces by the owner |
| State | Success bloom (`CaSuccessBloom` exists, unused), empty-state draw-in | Empty draw-in yes; bloom unused |
| Ambient | Gradient drift (hero), lattice light following the pointer (web hero) | Hero only |

**Screens tab (before and after).** Three screens; the full set lives in the Phone Audit.

### 5.2 Hadayah Web Preview

A responsive prototype of four screens (Welcome, Feed, Live room, Profile) with a width slider, "Today vs Proposed", and four window classes: compact under 600, medium 600 to 899, expanded 900 to 1279, large 1280 and up.

| Item | Proposed | On master |
| --- | --- | --- |
| Compact | Floating pill nav (2 items), hero + live rail + banner cards, bottom sheets | Yes (pill nav, feed) |
| **Medium (tablet / foldable)** | Rail 84 dp icon over label; hero + 2 columns; sheets as side sheets or centred | **No** (bottom pill until 900) |
| Expanded | Rail 224 dp labelled with role badge; hero band 8/4 + 3 columns; live room video + 340 chat | Side nav yes; feed hero band 8/4 yes; columns by master rule |
| **Large** | 1200 content cap; 4 columns; chat 400; profile 360 pane | Partly (profile pane; no cap) |
| **Live-room "below the video" tabs** | `Chat / Sources / Venue` card area on wide screens | Partly (ported live room) |
| **Welcome on web** | Brand panel 50% left with moving mesh gradient shader (WebGL), card on the right; medium: headline top, card below; phone landscape split | **No** (Welcome not ported) |
| **Phone landscape** | Pill nav kept; no keyboard (rotate-upright hint); hero 170 | Studio/chat yes; others not audited |
| **Faint lattice on the main background at 900+** | Allowed on web only | Not used |
| **Profile on wide screens: two columns (330 pane + content)** | | Yes (`CaPane`) |

### 5.3 Hadayah Phone Audit

28 of the owner's 88 Android screenshots, each with pinned findings (the pins are in the artifact's `AUDIT` array; the same defects are D1 to D39). Proposed screens rebuilt at 320/360/393/412/600 widths, with 1.0x/1.3x/1.6x text and EN/AR. **Not yet delivered from its proposals** (everything else was ported):

- **Welcome:** keep as the pattern but add the moving mesh gradient + lattice, one filled green primary, one mint secondary, a text link (not three equal white buttons), a single promise line (D7).
- **Feed:** offline scholars lose the OFFLINE chip and show the next scheduled time instead; search and filter share one field; one hero for what is live now with a **live rail** of smaller cards.
- **Map:** persistent bottom sheet list with peek row; search and filters in one floating card; neutral locate button instead of the crimson button; one tap target per row with distance (D17, D25).
- **Studio / go-live:** Paste action on the masked stream key; mark the recommended quality preset for mobile data.
- **Admin overview:** "Needs attention" list (queue and chat reports first, with counts) at the top; section chip row besides the drawer.
- **Notifications:** empty state with an action (turn on live alerts).
- **Phone rules** (the rules tab): thumb zones (primary action and navigation in the lower third; destructive actions top corner with a hold); 48 dp targets with 8 dp gaps; 16 dp inset (24 dp from 600); text floor 12 dp; one scroll and one sticky action per form; sheets: persistent bottom sheet over maps, modal sheet up to 90% for forms, centred dialog for confirmations; tab labels one or two words; chip rows with edge fades keeping the selected chip in view; one green primary per screen, crimson only for LIVE and destructive actions. Most are followed in migrated screens; the old screens break them.

---

## 6. Impeccable review of the live app: web (1280x800) and phone (390x844)

Run on 2026-10-05 with the `impeccable` skill (`critique` + `audit`, report only, nothing edited). Three independent assessments: **A**, a design review driven in the browser at both sizes; **B**, detector and browser evidence (console, network, accessibility tree, overflow); **C**, a source-based native audit (`audit.native.md`, adaptive Android/iOS/web). Screens covered: Welcome, Discovery feed, a broadcaster profile, Map, and Settings (Settings is auth-guarded, so it was reviewed **from source only**).

Caveats, read first:

- The live build A inspected still showed the avatar ring and the old profile header spacing, so it was probably an earlier deployment. Profile findings about the header may already be fixed by `7b26eb1`; re-check against the newest deployment before acting on them.
- Guest consent was never ticked; both browser assessments reached the feed by opening `/#/feed` directly. No form was submitted, nobody logged in.
- Phone accessibility semantics could not be enabled in the emulation (B), so phone a11y claims come from screenshots and source.
- The detector overlay could not load into the https page (the pane blocks localhost scripts). It would say little about a canvas app anyway. CLI detector results are below.
- There is no `project/ios/` and `flutter_launcher_icons` has `ios: false`, so iOS findings are latent risks, not observed behaviour.

### 6.1 Verdict

**Design specificity (A): partly authored.** Authored: the emerald panel with the faint star lattice, the mihrab-arch empty state, the leaf-hands logo, full RTL mirroring, the Eastern Province map. Not authored: the discovery content layer, which is five identical "Academic Broadcaster / #AI #Software" creator cards, all "Offline", with no lecture, topic, time or institution. Net: "a competent creator directory with a green skin", not yet "an Eastern Province lecture platform". Welcome is a stock centred card; the Map is stock yellow/orange OSM tiles that fight the emerald system.

**Nielsen heuristics (A): 21/40, "Acceptable".**

| # | Heuristic | Score | Key issue |
| --- | --- | --- | --- |
| 1 | System status | 2 | Feed cards are blank white boxes for about 5 to 9 s, then images pop in. Map is blank blue for 15 to 20 s. No skeletons. |
| 2 | Match with the real world | 2 | "Spatial GIS Map" and "Discovery Hub" (web) vs "Discovery Feed" (phone). Arabic nav says "دليل البث المباشر" (Live Broadcast Guide). Names half machine-transliterated ("A Pop" to "أبوب"), half Latin. |
| 3 | User control | 2 | Web profile drops the side nav (only a small back chevron). Guest path forces a consent dialog with a checkbox before any content. |
| 4 | Consistency | 2 | Three language-switch treatments (bare icon on feed/profile, labelled chip on map and welcome). Crimson-outlined list button on the map breaks "crimson means live or destructive". The bell is also the archive empty-state glyph. |
| 5 | Error prevention | 3 | Little to break as a guest; role switch disabled until approved; Danger Zone separated. |
| 6 | Recognition over recall | 2 | Every header action is icon-only (language, bell, bookmark, settings, filter); two unlabelled arrow icons per map row. |
| 7 | Flexibility | 2 | No "live now" or "next up" sort; no quick follow from the card. |
| 8 | Minimalist design | 3 | Phone profile and feed are calm. Penalties: cards about 480 px tall, dead green fields under profile content, five-layer control stack on the phone map. |
| 9 | Error recovery | 2 | Empty states are friendly but dead ends. |
| 10 | Help | 1 | No in-flow help; nothing explains the bell next to Follow or the verified tick; no guest onboarding. |

**Cognitive load:** 4 of 8 checks fail (single focus on the map, chunking in the feed header and chip row, visual hierarchy of feed and Welcome, minimal choices). More than four options at one decision point: feed chip row (8+), phone feed top bar (5 icon actions), phone map top (search, language, city, topic, banner), web map rows.

**Native audit (C): 13/20, "Acceptable".** Accessibility 2, Performance 3, Appearance and theming 3, Platform conformance 2, Adaptivity 3. P0 0, P1 5, P2 9, P3 6. Conditional pass on Android, unverifiable on iOS. The design-system core (`core/widgets/ds`) is near-perfect (0 hard-coded colours, 0 `fontSize` literals, labelled and focus-ringed controls); almost every other problem lives in un-migrated screens or in a few app-shell decisions.

**Detector (B):** `impeccable detect` found 0 issues in `web/index.html` and `build/web/index.html`; 2 in the static legal page `web/delete-account.html` (a 10 px "NO APP NEEDED" badge, and the Inter font, fine for a static page). It says nothing about the app itself, because Flutter web is a canvas.

### 6.2 Findings in both views

| Sev | Finding | Source | Fix | Command |
| --- | --- | --- | --- | --- |
| P1 | **The feed is a directory, not a schedule.** No live-now band, no next-lecture line, five identical cards | A | Live/Next-up band (when empty it still says "Next lecture Thu 8 pm"); next-lecture line replaces "Academic Broadcaster"; sort live, then upcoming, then offline | layout, clarify |
| P1 | **Blank first paint**: white card shells 5 to 9 s, map blank 15 to 20 s. The map pulls one 11.9 MB `basemap.pmtiles` (HTTP 200, no `Accept-Ranges`) | A, B | Skeleton cards, a "Loading map" cue, an emerald-toned basemap, downscaled banners; serve pmtiles with range support | harden, optimize |
| P1 | **Text scale hard-capped at 1.3** app-wide (`main.dart:133`); fails WCAG 1.4.4. `CanopySize.textScaleMax = 1.6` is unused; the layout sweep tests 2.0, which production can never reach; 18 call sites branch on `>= 1.3` | C | Remove or raise the clamp to 2.0, constrain only fixed chrome | adapt |
| P1 | **Viewport blocks pinch zoom** on web (runtime meta has `maximum-scale=1.0, user-scalable=no`) | B | Declare a viewport meta in `web/index.html` without those flags and confirm the engine does not re-add them | harden |
| P1 | **21 of 76 `IconButton`s have no tooltip or label**, including back buttons (`viewer_setup_screen.dart:108`, `org_admin_screen.dart:45`, `admin_hub_screen.dart:314`, `phone_broadcast_screen.dart:2218`), map search clear (`top_spatial_search_bar.dart:188`), toast dismiss (`interactive_toast_overlay.dart:259`) | C | `CaIconButton` (labelled, 48 dp, focus ring) or localized tooltips | harden |
| P1 | **Orientation lock leaks.** After any live screen the whole app stays portrait (`live_broadcast_screen.dart:463/472`, `phone_broadcast_screen.dart:569`); `web/manifest.json` forces `portrait-primary` | C | Restore `DeviceOrientation.values` on exit; lock only phones (`context.isPhone`); relax the manifest | adapt |
| P1 | **Custom transitions bypass system back** on `/profile/:id` and `/live/:id` (`app_router.dart:41-57`, used at 289 and 307); no `PageTransitionsTheme`, no `enableOnBackInvokedCallback` (inferred from source, not tested on a device) | C | Base on the platform builder (predictive back), keep the card reveal for forward navigation only, declare `android:enableOnBackInvokedCallback="true"` | harden |
| P1 | **Feed builds every card eagerly** (`Wrap` in a `ListView`, a `GlobalKey` per card, an O(n) height measurement; `discovery_feed_screen.dart:377, 473-496, 66-86`) | C | `SliverGrid` with a builder delegate, equal height by aspect ratio | optimize |
| P2 | **Empty states are dead ends** with a bell glyph; the profile opens on Archive (empty) | A | Action copy ("Remind me when Ameer schedules a lecture", "Browse other scholars"), calendar/play glyphs, default to the first non-empty tab | clarify, delight |
| P2 | **Welcome hierarchy** (not migrated): "Sign Up with Google" is white on white, no filled primary, the guest path is "(Skip Sign In)" and opens a consent gate; the four buttons are 32 to 39 px tall | A, B | One filled emerald primary, a secondary, guest as a clear tertiary, one value line; consent as a footer line instead of a gate | bolder, layout |
| P2 | **565 `fontSize` literals** (admin 206, auth 97, profile 91, live 76, map 56), 36 below 12 (`interactive_toast_overlay.dart:221,252`, `device_session_conflict_dialog.dart:130,171`, `welcome_screen.dart:315`) | C | `textTheme` roles, floor of 12 | typeset |
| P2 | **Icon drift**: 575 Material `Icons.*` against 54 `CaIcon` and 22 `CaIconButton` | C | Extend `CaGlyph` with the 15 most common Material icons (close, person, apartment, verified, error, mic, check, block, warning, arrow_back, wifi_off, location, info, delete, translate) and migrate by script | polish |
| P2 | **Gesture-only controls, 0 `FocusTraversalGroup`, 0 `meetsGuideline` tests** (`viewer_setup_screen.dart:178,200`, `live_audio_stage_multi_speaker.dart:196,434,591`) | C | `InkWell` + `Semantics`, a traversal group in the shell, tap-target and label guideline tests | harden |
| P2 | **28 to 32 dp targets in chat and toasts**: chat avatar (`ca_feedback.dart:107-117`), "show more" (`:169`), toast close (`interactive_toast_overlay.dart:243`), small buttons (`live_broadcast_screen.dart:2050,2065`) | C | Pad the hit region to 48 dp, keep the visual size | harden |
| P2 | **Light theme only** (a recorded product decision); live viewing at night is bright | C | Keep the decision; live room and full-screen player are the first candidates for a dark surface | colorize |
| P2 | **Startup**: `main.dart:34-46` awaits Supabase and Firebase before `runApp`; splash has a fixed 1350 ms timer and a looping pulse with no reduced-motion check (`app_splash_screen.dart:33-36, 56`) | C | `runApp` first and init behind the splash; "ready or at most N ms" | optimize |
| P2 | **No disk cache for network images** (`NetworkImage`); `cached_network_image` is in pubspec but only dead code uses it; some images not downscaled (`vod_grid_tile.dart:40`, `streamer_identity_card.dart:35`) | C | `CachedNetworkImageProvider` inside `resolveImageProviderOrNull`; add `downscaledImage(width:)` | optimize |
| P2 | **Backend over-fetch for guests**: a 401 from `GET .../rest/v1/` on every load (24 in 6 min); the guest feed also requests `broadcaster_applications?limit=1000`, `audit_logs`, `platform_analytics`, `terms_and_conditions`, `affiliation_requests` and got 200 (bodies not inspected) | B | With the Supabase MCP, confirm RLS returns nothing sensitive to `anon`; stop fetching admin tables for guests; stop polling the bare REST root. Needs owner approval before changing policies | harden |
| P3 | **Accessibility tree**: no heading nodes on any screen; feed card images unlabelled (10 imgs); the consent checkbox has no label of its own; the "Islamic Studies" chip is clipped by its scroller | B | `Semantics(header: true)` on titles, labels on avatars and banners, label the checkbox | harden |
| P3 | **Web shell**: source `index.html` has no `lang` or `dir` (the engine sets `lang` at runtime, `dir` stays empty even in Arabic) and no `theme-color` | B, C | `<html lang="en">`, `theme-color` `#17643F` | polish |
| P3 | **Dead code (about 550 lines)**: `pulsing_live_marker.dart`, `offline_marker.dart`, `map_discovery_channel_card_marker.dart`, `CaShell`/`CaRail` (unless adopted), `CanopySize.textScaleMax`. Shadow tint written as raw `Color(0x33123E26)`-style literals 9 times, a raw violet `0xFF4B3F96` in `chat_sender_profile_sheet.dart:350` | C | Delete or adopt; add `CanopyShadow` and a violet token | distill |
| P3 | **Forms**: 0 `autofillHints`, 0 `keyboardDismissBehavior`, `textInputAction` in 2 of about 81 fields | C | Add them | harden |
| P3 | **RTL residue**: the hand-picked chevron in `broadcaster_profile_screen.dart` (fixed in the working tree, section 1), physical left/right in `spatial_map_screen.dart:543,834,916` and `entry_background.dart:69-70` | C | Directional APIs | polish |
| P3 | **Foldables**: no `displayFeatures` handling, so two-pane layouts can sit across a hinge | C | Handle in an expanded Android pass | adapt |

### 6.3 Web only (1280x800)

| Sev | Finding | Fix |
| --- | --- | --- |
| P1 | **Profile loses the app shell** (A): the side navigation disappears, the card sits in a 290 to 360 px left column, the right pane is a large empty green gradient with one short white card, an abrupt seam, and a half-sized card is visible mid tab-switch | Keep the rail on the profile; fill the right column with content (next lecture, latest recordings, about); cap the green area; cross-fade tabs |
| P2 | **Cards and text are small** (about 10 to 11 px role and tags; name offset from the avatar) | 13 to 14 px body, align name/role/tags on one edge. Columns follow the owner's rule (floor(w/300), up to 4) |
| P2 | **Map**: stock OSM roads, three unlabelled icons per broadcaster row, "Settings" duplicated in the list panel, crimson-outlined list button, a visible tile seam while loading | Emerald-toned basemap, neutral list button, labels and tooltips, remove the duplicate |
| P2 | The feed header loses bell/bookmark/settings for the first seconds, then they appear (layout shift) | Reserve the space |
| P3 | "Viewer Mode" in the rail looks like a control but is a label | Make it a real switch or style it as status |

### 6.4 Phone only (390x844)

| Sev | Finding | Fix |
| --- | --- | --- |
| P1 | **Map control overload** (A): search, language chip, city and topic dropdowns and the offline-save banner use about 25 percent of the screen and cover pins; the list button is bottom-left with a crimson border | One expanding search-and-filter pill; dismiss the banner after first view; neutral list button at the end edge; persistent bottom-sheet list (Phone Audit design) |
| P2 | **Feed card scale**: each card is about 480 px, under two per screen. One card per row and no logo in the app bar are owner decisions and stay | Shorten cards (banner about 120 px, tighter padding) while keeping one per row |
| P2 | **Profile spacing**: placeholder bio text ("what ?") crowds Follow Channel; the bell next to Follow has no label; the lower half is empty green | A gap above the primary action, "Notify me" tooltip and label, sanitise test bios, fill the empty area (section 7) |
| P2 | The phone map nav's inactive destination is an unlabelled icon | Label both |
| P3 | The language toggle on the phone profile lagged several seconds with no feedback, tempting a double tap | Optimistic state change or a brief cue |
| P3 | One screenshot after the first interaction showed content cropped at the right edge at 390 px while DOM metrics stayed at 390. Probably an emulation capture artifact, not reproduced | Verify on the Galaxy M30s |

### 6.5 Personas (A)

- **Casey, distracted on a phone:** top-bar icons out of thumb range, the map's five-layer top stack, the crimson list button, slow first paint, the language lag.
- **Jordan, first-timer:** Welcome explains little, weak primary action, a legal gate before content, five identical offline cards, unexplained icon-only bell/bookmark/filter, "Spatial GIS Map" jargon.
- **Sam, accessibility:** no heading nodes, unlabelled card images, small role and tag text, mint-on-mint chips, 32 to 39 px Welcome buttons, no focus traversal, pinch zoom disabled, text capped at 130 percent.
- **Arabic-speaking student on a phone:** the nav label changes meaning, names half transliterated and half Latin, hashtags Latin, map attribution English. Mirroring itself is correct.
- **Scholar or organization admin who broadcasts:** "Go live" is two levels deep (Settings, Broadcaster Studio Preferences), no persistent Go Live action in the nav or feed, and an empty Upcoming tab has no "Schedule one" call for the owner.

### 6.6 What is working (keep)

- The phone broadcaster profile: emerald header, lattice, floating card, mint segmented tabs.
- RTL: every tested screen mirrors correctly, tabs reorder, chevrons point the right way. The Arabic toggle is a real delight.
- Colour discipline: green does the work, crimson is absent from feed and profile. The pill bottom nav is a good thumb-zone solution.
- Delivery: brotli on JS, fonts, JSON and pmtiles; `no-cache` on the translation catalog; `must-revalidate` on `main.dart.js`; no JS exceptions, no horizontal overflow at either size, no long tasks on the feed.
- Reduced motion is respected in 62 places; exceptions are the splash and the stream placeholder.
- Insets and keyboard (57 `SafeArea`, 12 `viewInsets` uses), deferred admin imports, downscaled feed images, `context.select` 58 times against 10 `watch`.

### 6.7 Performance numbers (B; decoded bytes only, paint timings were unreliable)

Navigation timing at 1280x800: Welcome load 659 ms, feed 974 ms, map about 1 s. First-load assets: `canvaskit.wasm` 5.69 MB (gstatic), `main.dart.js` 5.65 MB, `IBMPlexSans-Variable.ttf` 537 KB (requested twice), Arabic fonts 247 KB and 236 KB, `en.json` 115 KB, a Roboto fallback from fonts.gstatic.com. The map adds the 11.9 MB pmtiles, fetched whole in about 0.4 s. Slowest request: Supabase at 300 to 505 ms. The feed fires 38 Supabase requests.

---

## 7. Suggestions: friendlier and more alive

The owner said web may have designs that phones do not. Each idea is tagged **[web]**, **[phone]** or **[both]** with an effort: S under half a day, M a day or two, L more. All must respect section 2 (no circles behind icons, icon-only language control, one card per row on phones, no feed logo, rings only where allowed).

### 7.1 Make the first ten seconds feel like a lecture hall, not a form

1. **Skeleton and staged reveal on every first paint** [both, S]. Mint skeleton cards for the feed, skeleton card and panel for profile and organization, then banner images fade in with a blur of 4 to 0. Reuse `CaSkeleton` and `CanopyContentMotion`. Fixes the biggest status gap.
2. **Rebuild Welcome with the Phone Audit pattern** [both, M]. Mesh gradient plus lattice, one filled green primary, a mint secondary, Google sign-in as a text row, one promise line; on web a 50/50 split with a brand panel (Web Preview). Consent becomes a footer line with a link. Reuse `CanopyLatticeBackground`, `CaButton`, `CanopyGradients.panel`.
3. **A lecture-first feed** [both, M]. "Live now" hero, a "Next up" strip with date badges (reuse the profile's upcoming-live card), then the scholar directory. Each scholar card shows the next lecture line ("Thu 8 pm, Tafsir") instead of the repeated role. Needs a small query for the next scheduled stream per broadcaster.
4. **Empty states with a next step** [both, S]. Keep the mihrab-arch art; add an action ("Remind me when Ameer schedules a lecture", "Browse other scholars") and a calendar or play glyph.
5. **Guided first run for guests** [phone, M]. Three coach marks on the feed: filter, bell, bookmark.

### 7.2 Make it feel alive (motion and feedback that mean something)

6. **Finish the accepted motion set** [both, S to M]: `CaSuccessBloom` after follow, reminder set, application submitted, stream scheduled; `CanopyReconnectMotion` on the connection banner; shared-axis page push on Settings, Admin and Org routes; list stagger on the feed's first appearance. All are built and unused.
7. **Pull to refresh wherever a list lives** [phone, S]: profile, organization hub, notifications, map list (today feed only). On web use a small refresh button.
8. **Live presence on cards** [both, M]. When a scholar is live, the card banner gets a slow crimson edge glow (not the avatar ring, which the owner removed) and the viewer count rolls (`CaRollingCount`). Offline cards stay still and quiet.
9. **Time awareness** [both, M]. An optional line on the feed hero ("Maghrib in 42 min. 3 lectures tonight") computed from the device time and region. It ties the app to its audience, which review A found missing, and needs no backend. Ask the owner before shipping anything religious or schedule-related, and make it mutable.
10. **Gesture polish on phones** [phone, M]: swipe a card to bookmark (haptic and bloom), long-press for a quick preview sheet (next lecture, follow), draggable sheet snaps (peek, half, full) for the map list (the Identity Lab motion not yet built), haptics on follow, send and hold-to-end.
11. **Cursor-follow lattice spotlight and hover lift** [web, S]. The spotlight exists on the feed hero; add it to the profile header and sheet headers, a 2 px lift with shadow on card hover, and pointer cursors (C counted 0 `SystemMouseCursors`).
12. **Cross-fade between tabs and filters** [both, S]. Fade the grid when a chip changes instead of swapping; animate the chip indicator.

### 7.3 Friendlier language and guidance

13. **Words for mystery icons** [both, S]. Tooltips on web, a "Notify me" label next to Follow, a first-use hint on bookmark and filter; call the map "Map" or "Nearby"; use the same nav labels on web and phone; fix the Arabic nav label so it carries the English meaning.
14. **Names that read well in Arabic** [both, S to M]. Let broadcasters enter an Arabic display name instead of machine transliteration.
15. **A search that helps** [both, M]. Suggestions while typing (scholars, topics, places), recent searches, a "no results, try X" state. Verify defect D20 (does search filter more than the grid?).
16. **Follow from the card** [both, S]. A small Follow toggle on the card (check draws on success), so the profile is not the only place.
17. **Go live within reach** [phone, M]. A raised central action in the bottom nav for approved broadcasters, and a "Schedule a lecture" call in the owner's own empty Upcoming tab.

### 7.4 Web-only ideas (allowed to differ)

18. **Profile on wide screens** [web, M]: keep the rail, make the right pane a content grid (next lecture, latest recordings, playlists shelf, about, share card), cap the green gradient to the header band. Use the Web Preview's two-pane proportions.
19. **Theatre mode in the live room** [web, M]. Video 8/12 with chat 4/12, a collapse-chat button, picture-in-picture, keyboard shortcuts (space, F, M, C) with a "?" cheat sheet.
20. **Command palette** [web, M]. `/` or Ctrl+K searches scholars, topics and pages. Reuse the search field and `CaSheet` as a dialog.
21. **Rotating featured lecture on the hero** [web, M], with a progress bar that pauses on hover and respects reduced motion.
22. **A "Today" column on the feed** [web, M]: upcoming lectures, notification digest, bookmarks, so wide pages are not empty.
23. **Medium-width rail (600 to 899)** [web and tablets, M]. Adopt `CaShell`/`CaRail` (84 dp), which also removes the 900 literal repeated in 6 files.

### 7.5 Accessibility that also feels friendly

24. Text scale to 2.0 with reflow, labelled icon buttons, `Semantics(header)` on titles, a `FocusTraversalGroup`, a visible web focus ring, the viewport zoom fix. S to M.
25. A calmer offline and reconnect state: the banner says what still works ("You can still watch saved lectures") and has an animated Retry. S.
26. An opt-in dark surface for live viewing. M.

---

## 8. Recommended order of work for the next agent

Take small independent tasks, one commit each, running the gates in section 9 every time. Do **not** start by flipping the global theme.

**Step 0 (housekeeping).** Check `git status`. Vercel deployments for `afa67fa` and `7b26eb1` were confirmed READY after this was written; check the one for the commit that added this file. Agree with the owner what to keep from the design branch (section 4.1) and archive those docs, after which the owner can delete the worktree.

**Step 1 (high reach, low risk, from the audit).**
1. Remove or raise the 1.3 text clamp (`main.dart:133`) and adjust the 18 `>= 1.3` call sites; expect clipped widgets at 2.0 and fix them.
2. Restore orientation on exit from live and studio; lock only phones; relax `web/manifest.json`.
3. Label the 21 icon buttons (section 6.2).
4. Platform back: a `PageTransitionsTheme` plus `android:enableOnBackInvokedCallback`; keep the card reveal for forward navigation.
5. Web shell: `lang`, `theme-color`, viewport without `user-scalable=no`.
6. Check the guest over-fetch and 401 with the Supabase MCP; propose any policy change to the owner.

**Step 2 (content defects that embarrass in a demo, section 4.5).** D4 fake PDF URL (`app_provider.dart:355`, `en.json` `slides_pdf_title`); D5 development copy (`en.json` 648, 659, 678); D6 product name ("Streamer App" to "Hadayah Live" in `en.json` 670, 671, 1072, 1104, `notification_models`, the terms model; `support@streamer.app` in `account_banned_screen.dart`; the join link at `app_provider.dart:1829`: ask the owner for the real domain); D37 remove "Pitch Director Mode" and testing tools from `admin_hub_screen.dart` or hide them behind a debug flag. Add Arabic drafts for new strings and keep the catalogs symmetric.

**Step 3 (migrate the remaining screens, one per commit, method in section 3).**
1. Welcome, Viewer setup, Account banned, Splash (where new users start). Include consent wording and test the dialogs.
2. Dialogs: consent, device-session conflict, duplicate channel (small).
3. Map: spatial_map_screen, venue sheet, sliding drawer to a persistent bottom sheet on phones, status details, search bar; neutral list button, emerald basemap; no avatar rings on map cards. Largest remaining port, about 1,600 lines.
4. Global theme: only after 1 to 3. Flip `app_theme.dart` to Canopy values, add Readex Pro fonts and `pubspec` entries, then clean up leftovers in measured batches (565 `fontSize` literals, 575 `Icons.*`, 124 legacy buttons in admin).

**Step 4 (the "alive" layer, section 7).** Skeletons, empty-state actions, the accepted motion set, lecture-first feed, wide-screen profile, web extras. Ask the owner before building anything religious or schedule-related.

**Step 5 (verification).** Re-run `impeccable critique` and `audit` after Step 3 and compare with the baseline in section 6 (A 21/40, C 13/20). Do a real-device pass on the Galaxy M30s (never done; everything so far is emulator, live site and renders).

Rules for every step: section 2; one commit per task; list owner deviations in the message; stage only your files; push and confirm Vercel; do not commit the owner's untracked notes.

---

## 9. Appendix

**IDs and places**

- Repo root `C:\Users\User\Documents\Amir Ob\projects\Ideas\Current\Streamer_app`; Flutter app in `project/`; design worktree `.claude/worktrees/design-audit` on branch `design-audit/2026-10-identity` (local only).
- Live site https://stream-application-ten.vercel.app. Vercel team `team_esYRC0Dnt9BlycZOvBkShY8T`, project `stream-application`. Supabase project `zkkmfjsjouqzibvnzkau`.
- Android test phone: Galaxy M30s, serial `RZ8MB1LKGMH`; adb at `D:\app\Android\Sdk\platform-tools\adb.exe`; JDK 21 for Gradle.
- Local config `project/dart_define.local.json` is gitignored; never print its contents.
- Impeccable: `PRODUCT.md` exists at the repo root but uses a legacy schema (the tool reports `CONTEXT_STALE`); there is no `DESIGN.md`. Offer the owner `$impeccable init` / `document` rather than running them unasked. Token sources: `Core_files/Desgin.md`, `lib/core/theme/canopy_tokens.dart`, and `design-audit/DESIGN.md` on the design branch.

**Gates (from `project/`)**

```powershell
flutter analyze
flutter test
flutter build web --release --dart-define-from-file=dart_define.local.json
```

Translation check: collect every `'x.y'.tr()` key under `lib/`, assert each exists in `assets/i18n/en.json`, and assert `en.json` and `ar.json` have identical key sets (write a short script in your scratchpad; there is no committed checker).

**Gotchas that cost time this session**

- Python with nested quotes inside a bash heredoc breaks; write scripts with the Write tool and run them. Very long heredocs also fail (`ENAMETOOLONG`).
- The browser cached an old `en.json` and showed raw keys after a deploy. Fixed with `no-cache` for `/assets/assets/i18n/` in `vercel.json`; tell the owner to hard-refresh after big releases.
- `CustomPaint` stretches when wrapped in `Positioned(left, right)`; wrap in `Align` plus a fixed size.
- `TextPainter` ignores the inherited font (merge a `DefaultTextStyle`) and cannot lay out `WidgetSpan`.
- Create `AnimationController`s in `initState`, never lazily in `dispose`.
- Never `pumpAndSettle` on screens with the spinning ring, shimmer or lattice; pump fixed durations.
- `Icons.chevron_left/right` already mirror in RTL; do not branch on direction.
- Never run a bare `git stash`; the design worktree's `stash@{0}` holds the owner's prompt.
- The Supabase CLI login fails; use the MCP connector and rename the local migration file to the version MCP assigns.
- The Impeccable live-server creates a `.impeccable/` folder in the repo; delete it if it appears.

**Files created this session worth knowing**

`Core_files/DESIGN_HANDOFF.md` (this file), `project/lib/core/widgets/ds/ca_fixed_lines.dart`, `ca_pull_to_refresh.dart`, `project/lib/features/live_stream/presentation/widgets/chat_sender_profile_sheet.dart`, `project/test/chat_identity_test.dart`, `supabase/migrations/20261005144121_chat_moderator_since.sql`.
