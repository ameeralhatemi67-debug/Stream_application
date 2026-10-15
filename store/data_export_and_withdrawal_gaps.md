# P8B data export and consent withdrawal gap list

## Update 2026-10-15: export and deletion implemented locally

Migration `supabase/migrations/20261015090000_data_rights_export_and_deletion.sql` (not yet applied to the hosted project) closes most of the table below:

- `export_my_data()` is one server-side read covering the Auth account (email, created/last sign-in, providers), profile and consent, roles, permissions, device sessions, applications (reviewer removed) and their review history (actor removed), custom placeholders, suggested tags, follows, bookmarks, sent chat, reports filed, own blocks, mutes and mute history received, bans received, moderator assignments, broadcast sessions, upcoming schedules, reminders and deliveries, notification preferences, push devices (tokens never included), owned organizations, memberships, invitations (by profile or email), speaker links, ownership transfers, organization events, YouTube channel metadata (no credentials), actions recorded in the audit log, and uploaded file paths. It fails as a whole rather than returning silent empty sections. Settings saves it as a JSON file or copies it.
- Deletion: `prepare_account_deletion()` lists the caller's Storage files (own prefix, legacy uploads they own, files of a solo organization) and the client removes them through the Storage API; `delete_own_account()` refuses while files remain, while banned (`account_restricted`, handled by support so a ban cannot be shed), during an active broadcast, or while an owned organization has other active members. Before deleting it redacts the audit-log actor email/name, review-history applicant names and snapshots, speaker link email and invitations sent to the account's email. Tested by `supabase/tests/data_rights.test.sql` (39 assertions, disposable database).

Still open: a separate consent withdrawal (deletion remains the only route; counsel question 7), `stream_viewers` / `chat_stream_settings` / `removed_live_streams` linkability review, export of uploaded file bytes (paths are listed; files are public URLs), Auth/Storage logs and backups, revoking the YouTube OAuth grant at Google on deletion (credentials are deleted from Vault), and the retention periods counsel approves. Retention defaults in the migration are erase-or-redact.

The original inventory below is kept for reference.

Status: code work deliberately deferred while the owner tests P6. This is a repository inventory, not proof of a complete data-subject response. For counsel review where rights, legal basis, retention or third-party duties are involved.

## Existing behavior

AppProvider.exportMyData() in project/lib/core/providers/app_provider.dart exports one profiles row, broadcaster_applications where applicant_profile_id equals the user, and chat_messages where sender_id equals the user. project/lib/features/profile/presentation/settings/privacy_settings_section.dart shows JSON and lets the user copy it. Query errors silently become null or empty sections. Consent version/time are included only because they are columns of profiles. The Welcome gate records affirmative consent, but an existing signed-in session is not forced through a new version. Settings states deletion is the sole withdrawal mechanism.

## Required export coverage and access decisions

The P8B work plan explicitly names roles, memberships, devices, consent, reports filed, mutes/bans, follows and bookmarks. The complete table review below uses the current migrations. A user's own data can appear in an actor, target, owner, moderator or reporter column. Export must specify which relationship it represents and avoid exposing another person's private record. Choose a server-authorized RPC or narrowly scoped RLS for rows the client cannot read. Never broaden table SELECT to all authenticated users for convenience.

| Table or system | User link and current gap | Needed decision/work |
| --- | --- | --- |
| auth.users / Auth identities | Auth ID, email, provider identities and session metadata are absent. | Define safe export fields and server path; do not export tokens or secrets. |
| profiles | Existing row is exported, including consent_version and consent_accepted_at. | Confirm field completeness, null handling and stale-version semantics. |
| broadcaster_applications | Own applicant rows exported; reviewed_by links an admin. | Keep applicant data; decide whether reviewer-linked audit belongs in a separate rights response. |
| chat_messages | Sent rows exported. | Handle pagination, deleted messages and query failure explicitly. |
| user_roles and user_permissions | profile_id subject; granted_by may also identify user. Neither exported. | Export own grants, scope and timestamps; decide treatment of grants issued by the user. |
| organizations, org_speakers, affiliation_requests and org_venues | owner_profile_id, linked_profile_id/linked_email, streamer_profile_id, plus linked organization/venue records. None exported. | Export own ownership, roster/membership, requests, permissions and related venue data with authorization; do not disclose unrelated members' private fields. |
| device_sessions | user_id, device_id/name/platform, last_active_at. Missing. | Export own device records. |
| chat_reports | reporter_id and reported_sender_id. Missing. | Export reports filed by user, with safe message/reason fields; decide whether reports about user are disclosable and how to protect reporters. |
| chat_muted_users, chat_mute_audit_log, banned_users | muted_profile_id/profile_id, muted_by, banned_by and reason/last_messages. Missing. | Export own moderation decisions and reasons as permitted; redact third-party message text and moderator identity as appropriate. For counsel review. |
| chat_user_blocks | blocker_id and blocked_id. Missing. | Export own block list; decide whether blocks made by others must remain private. |
| follows and bookmarks | follower_profile_id / profile_id. Missing. | Export targets, VOD IDs and timestamps. |
| stream_moderators | profile_id and assigned_by. Missing. | Export own assignments/scope; review assignments made by user. |
| streamer_custom_placeholders and Storage objects | streamer_id, uploaded image_url, reviewed_by; actual bytes in streamer-assets. Missing. | Export asset metadata and provide an authorized asset download path or explain copy limits. |
| audit_logs | actor_profile_id plus actor_email/name and metadata; org-linked rows may include the user. Missing, and identity can survive deletion. | Search metadata and surviving denormalized identity, define safe subject access and retention/redaction. |
| tags and chat_stream_settings | created_by and updated_by can identify user. Missing. | Include user-linked contribution/update records if retained and disclosable. |
| stream_viewers and removed_live_streams | viewer_key or stream_id might be linkable, but neither has a direct profile FK. | Inspect key derivation and linkability; include if reasonably attributable to the requester. |
| Supabase Auth/Storage logs and local caches | Not part of current JSON. | Inventory service-side access logs/backups and device SharedPreferences; define separate access/export route or explain limits. For counsel review. |

The migration files used for this inventory are 20260821203000_initial_schema.sql, 20260824090000_chat_reports.sql, 20260825090000_chat_moderation.sql, 20260830120000_streamer_custom_placeholders.sql, 20260830160000_stream_moderators.sql, 20260830170000_banned_users.sql, 20260831090000_device_sessions.sql, 20260831100000_chat_mute_audit_log.sql, 20260920150000_follows_and_bookmarks.sql, 20260920160000_viewer_presence.sql, 20260920170000_chat_rate_limit_and_settings.sql, 20260923110000_admin_auth_account_actions.sql and 20260923120000_chat_blocks_and_app_flags.sql.

## Implementation shape to review after P6

1. Define a versioned export schema, the subject relationships per table, a maximum page size and continuation mechanism. Fail the export if a required section fails; show the user what is missing. Test a user with data in every named table, a second user, and a banned/deleted user against a disposable local database. Verify no other user's private data leaks.
2. Decide the legal bases that survive withdrawal and the user-facing choices. The current Settings note offers only account deletion; add a genuine withdrawal request/path if counsel says a separate route is required, and enforce it in data processing. Define effect on account access, existing content, logs, backups, and Google/YouTube data. Record the request and outcome without keeping more personal data than necessary. **For counsel review.**
3. Check deletion alongside export: the self-delete RPC cascades profile-linked DB rows and owned organizations, while audit_logs identity fields and Storage objects may persist. Specify retention or anonymization for each exception; verify on a disposable local stack and review third-party deletion requests. **For counsel review.**

SDAIA describes rights to access, obtain a readable copy, correction, destruction and withdrawal. Their conditions and exceptions need counsel's interpretation for this service. [SDAIA data-subject rights](https://dgp.sdaia.gov.sa/wps/portal/pdp/knowledgecenter/details/PDPLCP) [SDAIA implementing regulation](https://dgp.sdaia.gov.sa/wps/portal/pdp/knowledgecenter/details/PDPL2)
