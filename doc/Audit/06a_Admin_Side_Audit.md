---
type: audit
project: Streamer_app
phase: 6a of 8 (role: Admin)
created: 2026-08-20
status: complete
---

# 🛡️ Phase 6a — Admin Side: Deep Audit

**Method:** Opened `admin_hub_screen.dart` (67 KB) and `org_management_view.dart` (54 KB) directly this pass rather than relying on Phase 4's doc-based summary.

---

## Correction to Phase 4's inventory

- **"Advanced verification queue filtering" — Phase 4 said "Missing." Basic filtering already exists.** Confirmed status filter chips (All / Pending / Approved / Rejected) and a separate streamer-type filter (scholars vs. organizations) are both implemented and functional in `AdminHubScreen`. **Status: Partial, not Missing** — the filtering that exists is genuinely useful; what's still absent is anything beyond single-dimension filters (no combined/multi-filter, no search-by-name/institution) and, separately, **batch actions are confirmed still entirely absent** — grepped specifically for batch-related code and found none; every approve/reject/status-change action operates on one application at a time.

## This role is where the security findings concentrate hardest

Worth restating plainly rather than just cross-referencing Phase 1, because this role *is* the thing Phase 1's findings compromise: admin access today is "you're logged in and your email is one of three hardcoded strings" — no server, no signed claims, and (per VULN-AUTH-01) a bug in the sign-in error handler that hands out that exact identity to anyone whose sign-in throws an exception, with no attacker effort required beyond, say, being offline for a moment during login. Combined with VULN-RBAC-01 (no route guard on `/admin`), the practical reality is that **the admin role currently has no real access control**, only a UI convenience that hides the nav-bar link from people who aren't supposed to see it. Everything else in this report — the features described below — is genuinely well-built *as a UI and data model*. The gap is entirely in who's allowed to reach it, not in what it does once reached.

## Functional completeness, feature by feature

- **Broadcaster verification queue** (approve/reject/request-changes with reviewer notes) — Done, solid.
- **Organization management** (`OrgManagementView`) — Done; a substantial, well-built screen handling org registration review and affiliation requests.
- **Terms & Conditions / governance editor** — Done, matches `STATUS.md`'s claims.
- **Viewer analytics** — basic version exists; didn't independently assess depth/accuracy this pass.
- **Live chat / stream content moderation** — confirmed still entirely absent, distinct from application moderation above. There is nothing in `AdminHubScreen` that lets an admin (or the streamer themselves) act on something said in a live chat while a broadcast is running. This is the same gap flagged in Phase 3 as an Apple review risk — worth building here specifically since Admin Hub is the natural home for platform-wide moderation tooling, even if per-stream moderation (mute/report in the chat itself) also needs its own affordance for streamers, covered in Phase 6b/6d.
- **Batch actions** — confirmed missing (see correction above).

## Priority fixes for this role

1. **This is where the "you need a real backend" conversation from Phase 1 matters most** — admin/super-admin access is the single highest-value target for that architecture work, since it currently grants full platform control to anyone who can read a string out of the compiled app.
2. Add the route guard (`GoRouter`'s `redirect:`) as the fastest, cheapest partial mitigation while the backend work is planned — it doesn't fix the underlying trust model, but it closes the "type `/admin` in the address bar" and deep-link paths immediately.
3. Batch actions for the verification queue — genuine efficiency win once you have more than a handful of pending applications at once, and no architectural blockers to building it now.
4. Live-chat moderation tooling — needed for store compliance (Phase 3) as much as for admin completeness.
