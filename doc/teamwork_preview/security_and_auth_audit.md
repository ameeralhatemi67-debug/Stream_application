# 🛡️ Security & RLS Policy Audit Report

> **Project:** Educational Cloud Streaming Application (Streamer App)  
> **Target Path:** [`supabase/migrations/`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/supabase/migrations)  
> **Auditor Role:** Security & RLS Policy Auditor  
> **Status:** Complete  

---

## 🚨 Summary of Identified Vulnerabilities

A thorough audit of the 19 SQL migration files in `supabase/migrations/` and client integrations in `lib/core/services/` uncovered 3 major security vulnerabilities in Row Level Security (RLS) enforcement.

---

## 1. 🛑 CRITICAL: Chat Moderation Hijacking (`owns_stream` Logic Flaw)

* **Migration Source:** [`20260825090000_chat_moderation.sql`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/supabase/migrations/20260825090000_chat_moderation.sql)
* **Vulnerability:** The helper function `owns_stream(p_stream_id)` grants stream owner privileges by comparing `p_stream_id` against `profiles.active_stream_id`.
* **Exploit Vector:** Any authenticated user can issue an `UPDATE profiles SET active_stream_id = 'target_stream_id' WHERE id = auth.uid()`. Once set, the user is recognized as the stream owner by `owns_stream()`, granting them full permission to delete messages and mute/ban viewers across another scholar's live chat.
* **Remediation:** Validate stream ownership against the authoritative `streamers` table (`streamers.id` / `streamers.owner_profile_id`) rather than mutable viewer profile states.

```sql
-- Fix: Query authoritative streamers table
CREATE OR REPLACE FUNCTION public.owns_stream(p_stream_id text)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.streamers s
    WHERE (s.active_stream_id = p_stream_id OR s.id = p_stream_id)
      AND s.owner_profile_id = auth.uid()
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

---

## 2. ⚠️ HIGH: Broadcaster Application Admin Field Manipulation

* **Migration Source:** [`20260828100000_broadcaster_applications_delete_admin.sql`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/supabase/migrations/20260828100000_broadcaster_applications_delete_admin.sql) & [`20260821203100_row_level_security.sql`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/supabase/migrations/20260821203100_row_level_security.sql)
* **Vulnerability:** The policy `broadcaster_applications_update_own_pending` permits applicants to update their pending rows. However, Supabase RLS policies do not restrict column updates by default.
* **Exploit Vector:** A pending applicant can execute an UPDATE query that modifies `admin_review_notes` or `reviewed_by` fields, masking rejection feedback or faking administrative verification.
* **Remediation:** Add a BEFORE UPDATE trigger that prevents non-admin users from altering administrative columns (`admin_review_notes`, `reviewed_by`, `status`).

---

## 3. ⚠️ MEDIUM: Chat Report Metadata Forgery

* **Migration Source:** [`20260824090000_chat_reports.sql`](file:///c:/Users/User/Documents/Amir%20Ob/projects/Ideas/Current/Streamer_app/supabase/migrations/20260824090000_chat_reports.sql)
* **Vulnerability:** The `chat_reports_insert_self` policy allows viewers to report chat messages, but does not verify that `reported_sender_id` and `stream_id` match the actual `chat_messages` table row.
* **Exploit Vector:** A malicious user can submit a report for a legitimate `message_id` while providing a fake `reported_sender_id`, framing innocent viewers or poisoning the Admin Hub moderation queue.
* **Remediation:** Enforce key integrity in `chat_reports` via a foreign key constraint or a validation trigger checking `chat_messages(id, sender_profile_id, stream_id)`.

---

## 📊 Summary of RLS Coverage & Governance Findings

| Feature / Table | Current Policy Status | Vulnerability Level | Action Required |
| :--- | :---: | :---: | :--- |
| **`chat_messages` / Moderation** | `is_admin_tier() OR owns_stream()` | **CRITICAL** | Patch `owns_stream()` to query `streamers` table. |
| **`broadcaster_applications`** | `authenticated` pending UPDATE | **HIGH** | Add column immutability trigger for admin fields. |
| **`chat_reports` Queue** | `authenticated` INSERT | **MEDIUM** | Enforce message-sender foreign key validation. |
| **PII Protection (`user_profiles`)** | Restricted via RLS | 🟢 **SECURE** | Retain `20260822140000_restrict_pii_rls.sql`. |
| **RBAC Roles & Permissions** | Hardened (`has_permission()`) | 🟢 **SECURE** | Confirmed 0 anon policy coverage. |
