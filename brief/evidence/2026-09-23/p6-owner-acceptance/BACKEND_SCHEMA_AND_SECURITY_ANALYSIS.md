# Backend Schema Drift & Supabase Security Analysis Report

**Date:** 2026-09-23  
**Trigger:** P6-06 Keyword Filter test failed with `"Couldn't reach the server. Nothing was changed."`  
**Evidence Files:**
- `brief/evidence/2026-09-23/p6-owner-acceptance/supabase_logs.csv`
- `brief/evidence/2026-09-23/p6-owner-acceptance/screenshots/issue/P6-06-server-unreachable-missing-match-mode.png`

---

## 1. Executive Root Cause Analysis

### The Failure Symptom
When the Master Admin attempted to load or add a keyword in **Admin Hub → Safety → Chat keywords**, the interface displayed:
> *"Couldn't reach the server. Nothing was changed."*

### The Actual Root Cause: Production Database Schema Drift
The app is connected to the hosted Supabase project (`zkkmfjsjouqzibvnzkau.supabase.co`).
The app code in `master` expects the full migration chain up to `20260923140000`, but **the hosted database is missing multiple migrations dating from September 20 onwards.**

Specifically, the database logs in `supabase_logs.csv` reveal:
```text
postgres | error | 42703 | column chat_banned_keywords.match_mode does not exist
edge     | warning | 400 | GET  /rest/v1/chat_banned_keywords?select=id,keyword,match_mode,created_at
edge     | warning | 400 | POST /rest/v1/chat_banned_keywords
```
Because the column `match_mode` does not exist on the hosted `chat_banned_keywords` table, PostgREST rejects both reads and writes with HTTP 400, causing the client to report a server error.

---

## 2. Inventory of Missing Schema Objects

From the terminal logs and `supabase_logs.csv`, the following tables, columns, and RPC functions are missing from the hosted database:

| Missing Object | Type | Error Code | Required Migration File |
| :--- | :--- | :--- | :--- |
| `chat_banned_keywords.match_mode` | Column | Postgres 42703 (HTTP 400) | `20260921120000_chat_keyword_boundaries_and_normalization.sql` |
| `public.app_flags` | Table | PGRST205 (HTTP 404) | `20260923120000_chat_blocks_and_app_flags.sql` |
| `public.banned_users` | Table | PGRST205 (HTTP 404) | `20260922110000_admin_user_directory.sql` |
| `public.device_sessions` | Table | PGRST205 (HTTP 404) | `20260923100000_admin_device_sessions_read_guard.sql` |
| `public.follows` | Table | PGRST205 (HTTP 404) | `20260920150000_follows_and_bookmarks.sql` |
| `public.bookmarks` | Table | PGRST205 (HTTP 404) | `20260920150000_follows_and_bookmarks.sql` |
| `public.academic_categories` | Table | PGRST205 (HTTP 404) | Admin category migrations |
| `public.tags` | Table | PGRST205 (HTTP 404) | Tag moderation migrations |
| `admin_user_directory(...)` | RPC | PGRST202 (HTTP 404) | `20260922110000_admin_user_directory.sql` |
| `admin_user_detail(...)` | RPC | PGRST202 (HTTP 404) | `20260922110000_admin_user_directory.sql` |
| `claim_broadcaster_device(...)` | RPC | PGRST202 (HTTP 404) | Broadcaster session migration |
| `sweep_stale_live_flags()` | RPC | PGRST202 (HTTP 404) | Live cleanup migration |

> [!IMPORTANT]
> This confirms Section 1 of `brief/evidence/2026-09-23/p6-owner-acceptance/README.md`:
> *"project/dart_define.local.json points to the repo's linked production Supabase project... The file is not the disposable local database used for the 283 SQL assertions... Do not run P6-02 through P6-10 with that file yet... A successful app launch is not proof that production has the required migrations."*

---

## 3. Supabase Security Advisor Audit & Risk Assessment

From the Security Advisor inspection on `zkkmfjsjouqzibvnzkau.supabase.co`:

### A. Critical Security Findings (ERROR level)

| Rule | Affected Entity | Description | Remediation |
| :--- | :--- | :--- | :--- |
| `security_definer_view` | `public.organization_public_profiles` | View bypasses caller RLS policies, evaluating under view creator privileges. | Recreate view with `SECURITY INVOKER` or standard security rules. |
| `security_definer_view` | `public.streamer_public_profiles` | View bypasses caller RLS policies, evaluating under view creator privileges. | Recreate view with `SECURITY INVOKER`. |

### B. High-Priority Warnings (WARN level)

1. **Broad Storage Bucket Listing (`public_bucket_allows_listing`):**
   * **Bucket:** `streamer-assets`
   * **Risk:** Anyone can list all filenames/keys in the bucket via SELECT on `storage.objects`.
   * **Fix:** Restrict SELECT policy on `storage.objects` to specific paths or rely on direct asset URL access without object directory listing.

2. **Public / Anon Callable SECURITY DEFINER Functions (`anon_security_definer_function_executable`):**
   * **Functions:** `bootstrap_admin_role()`, `has_permission()`, `is_admin_tier()`, `is_master_admin()`, `chat_can_moderate()`, `chat_check_banned_keywords()`, `chat_is_muted()`, `chat_sender_info()`, `log_audit_event()`, `owns_organization()`, `owns_stream()`, `sync_org_owner_role()`.
   * **Risk:** Anonymous callers can invoke these sensitive RPCs directly via `/rest/v1/rpc/...`.
   * **Fix:** Revoke `EXECUTE` from `public` and `anon`; grant execute strictly to `authenticated` or internal trigger roles:
     ```sql
     REVOKE EXECUTE ON FUNCTION public.bootstrap_admin_role() FROM public, anon;
     ```

3. **Function Search Path Mutable (`function_search_path_mutable`):**
   * **Function:** `public.set_updated_at`
   * **Risk:** Lacks `SET search_path = ''`, making it susceptible to schema search path hijacking.
   * **Fix:** Add `SET search_path = ''` to the function definition.

4. **Leaked Password Protection Disabled (`auth_leaked_password_protection`):**
   * **Fix:** Enable HaveIBeenPwned checking in Supabase Auth settings.

---

## 4. Screenshot Evidence Renamed

* **`screenshots/issue/P6-06-server-unreachable-missing-match-mode.png`** (formerly `Screenshot 2026-09-23 205755.png`):
  Shows the Admin Hub Chat Keywords tab displaying the red notification: *"Couldn't reach the server. Nothing was changed."* caused by the missing `match_mode` database column.
* **`screenshots/issue/P6-08-user-directory-unable-to-load-missing-rpc.png`** (formerly `Screenshot 2026-09-23 215302.png`):
  Shows the Admin Hub User Directory displaying *"Unable to load accounts. Check the connection and server setup."* when searching "Amir", caused by the missing `public.admin_user_directory` RPC.

---

## 5. Strategic Decision: How to Proceed with Testing

You have two paths forward:

### Path A: Safe Local Disposable Database (Recommended by README §1)
* Run local Supabase via Docker on your laptop (`npx supabase start`).
* All migrations (including `match_mode`, `app_flags`, `banned_users`, etc.) and all 283 passing SQL test assertions are already present here.
* Zero risk to production data.

### Path B: Update the Hosted/Production Database
* If you want your hosted cloud Supabase project to match the current Flutter code, the pending migrations must be pushed:
  ```powershell
  npx supabase db push
  ```
* Once pushed, all 10 missing tables/columns/functions will immediately exist, resolving:
  1. Chat keywords add/remove.
  2. Platform switches (registrations & chat pause).
  3. Banned users & user directory actions.
  4. Device sessions and multi-device collision checks.

---

## 6. What Can Be Tested Next Right Now?

While the backend schema decision is made:

### Available Next:
1. **Interactive Viewer & Stream Features (Client-side / Read paths):**
   - Testing chat UI controls (composer, scrolling, reaction floating, local badging).
   - Discovery feed cards and Spatial Map interactions.
2. **Review & Preparation for `db push` or Local Stack switch:**
   - Deciding whether to push migrations to the hosted database or start the local test stack.
