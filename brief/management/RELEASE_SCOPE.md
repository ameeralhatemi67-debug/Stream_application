# Hadayah release scope and post-release register

## Organization V1 scope amendment — owner decision, 2026-10-01

The approved Organization broadcasting V1 plan supersedes POST-01 and the organization application deferral below. It also brings server-created YouTube resources during preflight into scope under POST-02. Deliver membership/RBAC, separate personal and organization approval, owner OAuth/Vault channel connections, accepted scheduled occurrences, three concurrent session identities, Android/OBS publishing, scoped moderation, durable notifications and truthful replay/recovery states. STREAM-D8 must be closed by the shared server authorization path. Start disabled, enable named pilot organizations, and retain end/recovery controls when starts are disabled. Three simultaneous real-channel shows and physical Android verification remain mandatory release gates. No production deployment is approved by this amendment; unrelated release blockers remain open.

Updated 2026-09-30. Sources are owner evidence and explicit owner messages. This register separates approved deferrals from unapproved cuts. It does not approve release or blanket-defer P7.

## Explicit owner deferrals

| ID | Feature | Decision / source | Required initial-release behaviour |
|---|---|---|---|
| POST-01 | Organization broadcasting, individual/organization broadcast identity switching and organization-scoped broadcast revocation | After publication. E4 Check 8, 2026-09-26 17:35 UTC+3, [owner results](../evidence/2026-09-26/p6s-astra-audit/E4_ACCEPTANCE_RESULTS.md). | Selection must be unavailable with a clear future-feature explanation and activation guards. Keep existing organization data, authorization and unrelated flows safe. |
| POST-02 | YouTube broadcast creation in advance | The 2026-09-30 owner plan supersedes this deferral for Upcoming Live **announcement schedules and reminders** in the current release. Creating a YouTube broadcast remains outside that plan. Original E4 Check 2 deferral: 2026-09-26 14:48 UTC+3. | Upcoming cards must say Planned and never set a channel Live. Delivery needs the local migration, server job, Firebase configuration and physical retest before acceptance. Preserve live/watch validation and negative scheduled/ended/VOD checks. |
| POST-03 | Return-to-broadcast floating shortcut polish | After publication. E4 Check 15, 2026-09-26 21:29 UTC+3, same owner results. | Do not present a shortcut as a functioning mini-player or PiP. Ordinary navigation and active-media teardown remain correct. |
| POST-04 | Front-camera switching | Deferred for now; owner camera follow-up reported 2026-09-27. Confirmed in `p6s-camera-landscape/REPAIR_REPORT.md` and the results scope amendment in the streaming worktree. No dated post-release milestone was promised. | Rear camera remains active; localized Coming Soon; switching cannot interrupt media/session or activate front camera after reconnect. |

The owner clarified on 2026-09-28 that Organization / Center must also be unavailable in both new application forms, with a coming-soon notice. Existing approved organization records and profile edits remain supported; this is not a waiver of their data and permission rules.

**SCHED-01 current-release addition (owner plan, 2026-09-30):** approved individual broadcasters manage weekly and one-time Saudi-time announcements; viewers can browse/share and signed-in accounts save channel/card reminders. Source and local tests do not establish delivered Android/browser notifications. Hosted migration, job scheduling, Firebase credentials and an installed test build require separate owner-directed steps; keep this release item open until end-to-end evidence exists.

## Suggestions retained without an approved delivery date

E4 Check 7, 2026-09-26 16:49 UTC+3, recommends a duplicate-channel indicator in the admin verification queue and alerts to the admin and legitimate owner when another account attempts to use that channel. Keep these as enhancement proposals pending prioritization. They do not replace server-side authorization, and their timing was not explicitly designated post-release in that result.

## Still open; do not silently defer

- **STREAM-D8:** server-side YouTube ownership/authorization remains HIGH and a release blocker by explicit owner decision. Client URL validation or a test account being refused does not prove server ownership enforcement. INT-01 does not implement a new OAuth architecture; plan a focused follow-up after its findings are known.
- **MAP-AREA (owner decision 2026-09-28):** the three named cities remain map views, but a streamer may submit an exact venue point anywhere inside the bundled map's usable navigation extent, including beyond those views. Points outside that extent cannot be submitted or moved there. This supersedes the earlier three-city-only venue rule; it does not establish municipal boundaries. The local guard migration `20260928010000_supported_broadcaster_map_location.sql` still requires isolated SQL and configured-backend verification before acceptance.
- Accurate municipal boundaries: no suitable licensed dataset has been obtained in the recorded work. This requirement is unmet, not owner-waived. Seek data or an explicit scope decision; never label guessed rectangles official city boundaries.
- Local same-Wi-Fi transport, private internet media, external phone sender, direct laptop capture, real PiP: unavailable or incomplete. Verify each approved platform/mode exclusion separately. An unavailable button is truthful UI, not acceptance of the underlying feature or proof of a scope waiver.
- Audio-only camera release, foreground/background/lock survival, physical encoding performance/thermal behaviour and supported resolution/Auto semantics remain separate evidence/scope items. Do not infer success from audible audio, a black video frame, a build or emulator run.
- The restored viewer audio stage pulses for active playback. Speech-specific pulse timing remains unverified because the YouTube player does not expose an authenticated microphone level to viewers; do not describe this as confirmed speech detection.
- The original request said 480/740/1080/Auto; the current camera follow-up reports 360/720/1080 encoder presets. Do not silently claim these are equivalent or that D1 is resolved. Confirm the intended shipped quality choices and honest playback controls.
- P7's remaining role/invitation/profile/admin security scope needs a release-scope reconciliation. POST-01 does not waive all organizations work or security for existing organization records.

Use qualified IDs above: streaming D8 and the map handoff's D8 geography decision are different items.

## Route to publication

1. INT-01 source `34d074a` / final `8e28801` is now locally merged into master at `c9e441f`, observed 2026-09-27 10:55 +03:00. Owner documentation was committed and reconciled, preserving evidence and both source histories. Exact tested source identity was verified; physical/backend scores remain provisional and no checkpoint is accepted. Main `project/` is the owner's requested checkout for the next build.
2. Resolve CFG-01 using INT-01's README setup checklist so one newly built, identified candidate can exercise the intended backend, Google sign-in and YouTube flows. The delivered artifacts are diagnostic; the dedicated setup is still missing. USB-routed local control-backend testing does not prove untethered backend transitions. No provisioning follow-up is dispatched.
3. Run a short owner smoke test, then consolidated Wave4v2. Fix failures in focused slices; keep build-specific results and retest impacted paths. Do not restart every past test automatically.
4. Resolve STREAM-D8 and remaining release-mode/scope decisions, alongside P5/P6/P6S evidence. Testing can identify other failures while D8 stays visibly open; it cannot waive it.
5. Reconcile retained P7 obligations and finish P8B data-rights/store/legal work. Store drafts already exist; drafts are not completed implementation or approved legal declarations.
6. Complete owner signing/configuration, signed AAB, artifact secret scan, physical release smoke, final P9 regression and release approvals. Android publication comes before the planned v1.1 iOS track.

This is a dependency order, not a duration or publication promise. Independent store preparation and owner setup may proceed alongside engineering when authorized and when they will not interrupt the active candidate. The 2026-09-23 calendar charts are historical estimates.
