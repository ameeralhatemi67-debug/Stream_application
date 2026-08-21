---
type: roadmap
project: Streamer_app
created: 2026-08-20
status: active
current_version: v0.4
---

# 🗺️ Master Roadmap: v0.4 → v1.1 (Publication Ready)

> Companion to `doc/Audit/` (the publishing-readiness audit) and superseding `doc/roadmap to publishing.md`'s Phase 5–8 section, which this replaces with the structure below.

This roadmap is organized **Version → Checkpoint → Phase → Task**. A **Version** is a major slice of the app (e.g. "the backend exists now," "chat actually works"). Each Version contains several **Checkpoints** — natural pause points where we stop, you review, we discuss, and you can hand things to a separate agent for a polish pass if you want one. Each Checkpoint contains several **Phases** — each Phase ends in one commit. Each Phase is a handful of concrete **Tasks**.

---

## How this actually runs, day to day

- **Branching:** direct to `master`. No feature branches, no PRs — matches how this repo already works (confirmed connected to `github.com/ameeralhatemi67-debug/Stream_application`, currently up to date).
- **Commit cadence:** one commit at the end of every Phase. Commit messages follow the existing convention already visible in this repo's history (`feat(scope): ...`, `fix(scope): ...`, `docs: ...`).
- **Push cadence:** at the **start** of every Checkpoint, before its first Phase begins, push `master` to GitHub. This is also a natural moment to pull/confirm nothing external changed.
- **The pause at every Checkpoint's end is deliberate:** that's where we talk — questions, direction changes, and it's an explicit invitation for you to make manual polish edits yourself before we continue. A separate agent session can also be used here to do a dedicated polish pass on whatever the checkpoint just built, if you want one — this roadmap will note "🧹 optional polish session" at each checkpoint boundary as a reminder, not an obligation.
- **Housekeeping before Checkpoint 1 of v0.5 starts:** `git status` currently shows ~30 files flagged "modified" that nobody actually touched (translation services, gradle wrapper, launch backgrounds, etc.) — almost certainly CRLF/LF line-ending noise from viewing this Windows-authored repo through a different environment, not real changes. Worth a `.gitattributes` fix (`* text=auto`) as the very first task so future phase-commits don't get polluted with phantom whole-file diffs. This is a 5-minute task, not a checkpoint of its own.

---

## Recommended Claude Agent Skills & Staged Activation

To maintain peak code quality, security verification, and store compliance throughout this roadmap, the following specialized skills/plugins are integrated into the workflow. If an agent does not have a required skill installed in its environment, it should prompt the user to install it or use the appropriate CLI/tooling to enable it.

| Skill / Repository | Target Milestones | Primary Purpose |
|---|---|---|
| **`supabase/agent-skills`** | `v0.5`, `v0.6`, `v0.8` | Supabase Auth, PostgreSQL schema conventions, Realtime channels, and CLI management. |
| **`rls-audit`** (`ekhorkov/rls-audit`) | `v0.5`, `v0.8` | Automated verification of Row Level Security policies to prevent privilege escalation or data leaks. |
| **`claude-flutter-skill`** (`Arcturus91/claude-flutter-skill`) | `v0.5` through `v1.1` | Flutter/Dart best practices, widget rebuild tree optimization, Provider/Selector state architecture. |
| **`appstore-review-skill`** (`devsemih/appstore-review-skill`) | `v0.9`, `v1.0`, `v1.1` | App Store Review Guidelines auditing (Account deletion flow, Guideline 1.2 UGC moderation, `PrivacyInfo.xcprivacy`). |
| **`google-playstore-toolkit`** (`crgeee/google-playstore-toolkit`) | `v1.0` | Google Play Store Data Safety section, 16KB page-size alignment, release bundle configuration. |
| **`owasp-security`** (`agamm/claude-code-owasp`) | `v0.5`, `v0.9` | Mobile application security hardening (transport layer, credentials, PII leakage). |
| **`Graphify`** | `v0.5` CP4, `v0.8` | Architecture and dependency graph mapping for large refactors (e.g. `AppProvider` refactor). |
| **`Thermo-Nuclear Code Review`** / **`Improve Codebase Architecture`** | Checkpoint boundaries | Deep code review during "🧹 optional polish sessions" at checkpoint boundaries. |

> **Agent Note:** When starting a Version or Checkpoint, check the skill table above. If the recommended skill is not active in your session, notify the user with the installation command or repository link so it can be loaded before executing the checkpoint.

---

## The versions

| Version | Goal | Checkpoints |
|---|---|---|
| **v0.5** | Backend Foundation — Supabase migration (auth, data, RLS). Resolves nearly all of Phase 1's critical security findings as a side effect of being built properly. | 5 |
| **v0.6** | Live Chat & Realtime Engagement — chat that actually works between everyone in a stream, reactions, role badges, real moderation. | 4 |
| **v0.7** | Mobile Streaming (Android) — stream video or audio-only from the phone's own camera/mic into YouTube, same distribution pipeline as OBS. | 4 |
| **v0.8** | Admin Upgrade — the tiered Master Admin / Admin / Permitted Admin (Org Owner & Co-Owner) hierarchy, with checkbox-style granular permission grants. | 4 |
| **v0.9** | Settings Cleanup, Account Deletion, Consent & Legal — role-aware settings, experimental toggles moved to Admin-only surfaces, in-app account/data deletion, PDPL consent flow. | 3 |
| **v1.0** | Full Onboarding Tour + Store Submission Prep — the guided first-run walkthrough (built once chat/streaming exist to show off), Saudi legal close-out, Play Store submission mechanics, remaining performance/UX polish. | 4 |
| **v1.1** | iOS Integration — last, as requested. Platform bring-up from scratch, Sign in with Apple, iOS phone streaming, Apple submission prep. | 3 |

Each version has its own file in this folder (`v0.5_Backend_Foundation.md`, etc.) with the full Checkpoint → Phase → Task breakdown. The nearer-term versions (v0.5–v0.8) are broken down in full working detail since we're about to start there; v0.9–v1.1 are still fully structured but will likely get refined further as we approach them and the app itself changes underneath.

---

## Decisions this roadmap locks in (so we don't relitigate them mid-build)

- **Backend:** Supabase, staged per your own cost model — Free Tier now (Stage 1 of your plan), with Pro/dedicated-region upgrades explicitly deferred to whenever traffic actually warrants them, not built speculatively now.
- **Chat:** Supabase Realtime (broadcast channels), not a third-party chat SDK.
- **Phone streaming distribution:** phone → YouTube RTMP ingest, same pipeline OBS/web already uses. No new video CDN/player needed for this.
- **Phone streaming platform order:** Android first (v0.7); iOS's version of the same feature ships inside the iOS version (v1.1), not built twice.
- **YouTube stream key entry:** manual paste for now (matches the existing OBS pattern, zero new OAuth scopes); automated key-fetch via the YouTube Live Streaming API is an explicit "revisit later" item, flagged in v0.7 rather than promised.
- **Admin hierarchy:** Master Admin (can grant Master Admin/Admin to others — multiple Master Admins supported) → Admin → Permitted Admin (Organization Owner/Co-Owner, org-scoped) → plus per-user checkbox-style granular capability grants layered on top of any tier.
- **Settings:** role-aware, not one-size-fits-all — a Viewer's settings are a subset of a Streamer's, which is a subset of an Org Owner's, which is a subset of Admin's. Experimental/dev toggles move out of user-facing settings entirely once Admin tooling exists to house them.
- **Onboarding tour:** built in v1.0, after chat and streaming exist, so it can actually show them off instead of needing a rewrite later.
- **Polish/performance items from the audit:** spread across whichever version's checkpoints touch that area, not consolidated into one dedicated "polish version."
