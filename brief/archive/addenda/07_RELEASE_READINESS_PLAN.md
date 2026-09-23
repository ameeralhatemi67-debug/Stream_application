# Archived addendum — release readiness focus (2026-09-23)

**Superseded and merged into [`../../03_WORK_PLAN.md`](../../03_WORK_PLAN.md) on 2026-09-23.** Retained as historical source material; use the canonical plan and current verification index for active work.

This archived source records the owner's streaming, navigation and account-state requests. Its unique phase and schedule content was merged into `../../03_WORK_PLAN.md`; use that plan and `../../06_VERIFICATION.md` for active work. A checked UI or passing widget test does not prove a live stream works on a phone or laptop.

## Current truth

- The 2026-09-22 UI pass recorded 463 passing Flutter tests, zero analyzer issues and a successful web build. This review reran `brief/tools/gates.mjs`: every gate passes except G6 (528 regex matches; inspect the matches before classifying them). The fresh `flutter analyze` attempt did not finish and was stopped; the recorded analyzer result is inherited, not a fresh pass.
- P6.4 user directory code exists, but its local SQL test found an access-policy regression and malformed pgTAP quoting. Repair and rerun the local database tests before calling that item complete. P6.4 items 2–6 remain open.
- The OBS tab configures the YouTube watch target and saved RTMP details; a real phone/laptop OBS ingest-to-viewer run has not been evidenced. The Phone tab uses a manual YouTube stream key and Android native RTMP publishing; its physical-device path remains unverified. The Local tab only saves a laptop IP and shows a URL; it does not start a same-Wi-Fi stream.
- `kPrivateStreamingEnabled` is false. The old whitelist, knock and invite state is client-side demo logic; there is no server-enforced private entitlement or usable invite flow. Do not expose it by flipping the flag.
- The floating mini-player renders a thumbnail and local play/mute state, then reopens the room; it does not carry the active video player across navigation. Fullscreen/orientation controls exist, but their phone/device transitions have not been verified end to end.
- The existing [feature issue screenshot](../../evidence/2026-09-22/screenshots/Screenshot%202026-09-22%20143939.png) shows a red Flutter error after “Live from the phone” opens on web: `Unsupported operation: Platform._operatingSystem`. `phone_camera_preview.dart` calls `Platform.isAndroid` without a web guard. Route and preview capability checks must prevent this crash before a Laptop choice is advertised.
- `Core_files/STATUS.md` and `Core_files/progres.md` date from August, and `Roadmap.md` still lists work that later reports say was completed or partially completed. Older audits also repeat now-resolved owner decisions (exact public venue coordinates and the privacy URL). Reconcile them against the code and latest evidence before treating them as current.

## New phase P6S — broadcast and navigation reliability

Run after the P6.4 directory SQL repair and before final release verification. P5, P7, P8B and P9 still remain in scope. Each item below needs a reproducible scenario, a fix if it fails, and the evidence described in `06_VERIFICATION.md`.

| ID | Work and acceptance | Priority |
| --- | --- | --- |
| S1 | OBS workflow: broadcast from a laptop and check the requested phone path with a supported OBS-compatible sender, through the configured ingest and watch link. Confirm camera/mic, video/audio sync, live-state change, viewer playback, clean stop and reconnect. Record which sender actually runs on each platform; do not infer support from the setup screen. | Release gate |
| S2 | Direct phone to YouTube: validate real key/ingest URL, channel/watch ID, permission prompts, start/stop order, network drop/reconnect, audio-only and failure messages on a physical Android phone. Never expose a stream key in logs, screenshots or client-side sharing. | Release gate |
| S3 | Rename the Phone mode to **Direct broadcast** (working label) and offer Phone and Laptop as source choices. First fix the web crash when the current Phone route opens, with a clear unsupported-platform state. Keep the Android path; then prove a laptop capture/encode/ingest design for the supported desktop target. A browser cannot be assumed to publish RTMP directly; select and test an actual ingest path before presenting laptop as available. | Release gate if laptop is promised in v1.0 |
| S4 | Same-Wi-Fi local stream: define host/viewer topology and supported phone/laptop combinations, then implement real discovery or explicit address entry, local media transport, access control, stop/rejoin and network-loss behavior. The current URL-only Local tab must not claim a stream is running. | Release gate if Local remains visible |
| S5 | Public/private on OBS, Direct and Local: one clear setting and consistent discovery rules. Store authorization on the server for internet streams and enforce it on stream metadata, playback entry, chat and invites; use a host-controlled local authorization path for LAN streams. Verify unauthorized accounts cannot join by URL or API. Keep the feature hidden until enforcement passes. | Security release gate |
| S6 | Private invites: create scoped, expiring, revocable invitations; test share/open/accept/deny on a second account and device, including logout, reuse, expiration and a host ending the stream. Decide how YouTube visibility and possession of its watch URL interact with the app's privacy promise; an unlisted YouTube URL alone is not access control. | Security release gate |
| S7 | Portrait ↔ landscape and normal ↔ fullscreen ↔ mini-player: preserve the same live session and media where supported, restore system UI/orientation on every exit, keep controls reachable, and make mini-player playback/mute/close real. Test rapid transitions, back gestures, app background/foreground and a stream ending mid-transition. | Release gate |
| S8 | Escape audit: for every route, sheet, setup step, loading state and live/reconnect state, prove cancel/back/close/end works, releases camera/mic/wakelock/session resources and never leaves an endless spinner. Include denied permissions, offline starts and server errors. | Release gate |
| S9 | Account-state audit: after sign-in or account switch, derive approved-streamer/application state from the current backend account before showing role prompts. An approved streamer must not see “want to be a streamer?”; a viewer must not inherit another account's channel or live controls. Test guest → viewer → approved streamer → second account → sign-out/sign-in. | Release gate |

## Four-day target and model handoffs

This is a target for an engineering release candidate, not a promise of Play publication. It assumes the owner can supply physical devices, OBS, a real YouTube test channel/key, signing material and local database tooling promptly. Keep one checkpoint record per day; a different model should start from the current checkpoint and evidence, not the historical prompts.

1. **Day 1 — truth and architecture:** GPT-6 Sol repairs the P6.4 SQL regression and runs local DB checks; GPT-6 Astra resolves Direct Laptop, LAN transport and private-access design against the existing architecture. Establish the exact device/OBS test matrix and reproduce S1–S4 before coding them.
2. **Day 2 — broadcast paths:** GPT-6 Sol implements and verifies S1–S4, with real laptop and phone tests. Mark an unsupported path unavailable in the UI until it works; log the decision as a scoped release cut if needed.
3. **Day 3 — access and lifecycle:** GPT-6 Astra handles S5–S6 authorization and threat cases; GPT-6 Sol handles S7–S9. Claude Opus 5.5 performs an independent code and flow review of the resulting changes. Fix findings before moving on.
4. **Day 4 — release gate:** GPT-6 Luna reconciles active docs and evidence; GPT-6 Sol runs Flutter, local SQL, device and release-build checks; GPT-6 Astra reviews security and the final go/no-go. Finish the already-planned P5/P7/P8B work or explicitly cut/defer it with product approval. The owner completes signing, production migration review, store/legal decisions and any Play Console actions.

If Direct Laptop, LAN transport or private entitlements need new infrastructure, or if P5/P7/P8B remain open, four days may produce a tested subset rather than a publishable app. Never label the app release-ready while a visible stream mode fails or a private stream can be entered without authorization.

## `brief/` cleanup plan

Do this after recording the current checkpoint; keep history intact until references and evidence links have been checked.

1. Make `brief/README.md` the short entry point: current phase, next three actions, blockers, owner actions, and links to `03_WORK_PLAN.md`, `06_VERIFICATION.md`, this addendum and the latest `LEDGER.md` RESUME block.
2. Keep the active root small: README, 03 work plan, 05 decisions, 06 verification, this addendum, LEDGER and OWNER_ACTIONS. Move dated audits, UI inventories/reports, overrun/checkpoint reports and old prompts into named `archive/` subfolders; preserve Git history and repair relative links.
3. Move raw analyzer/test/gate logs and screenshots into `evidence/YYYY-MM-DD/<checkpoint>/`. Keep a short evidence index that states command, platform, result and limits. Preserve source screenshots and design choices as evidence, not live instructions. Keep `tools/` in place while active scripts depend on its paths.
4. Replace competing model-specific master prompts with one short handoff template that points to the active files and names the model's bounded task. Archive the old prompts and the Claude-specific budget protocol after separating any still-binding safety rules from historical quota assumptions. Do not assume a ChatGPT 5x upgrade changes release requirements or tool availability.
5. Reconcile `Roadmap.md`, `Core_files/STATUS.md`, `Core_files/progres.md`, `AGENTS.md` and stale audits with the code and latest verified result. Keep historical progress as history; make the current status page say what is implemented, verified, unverified and blocked. Close or supersede owner actions already decided in `05_DECISIONS.md`.
6. Add a simple rule: every checkpoint updates only the current status, work-plan row, evidence index and one ledger entry. Raw logs never accumulate at the root again. Recheck `rg` links and `git status` before moving anything.
