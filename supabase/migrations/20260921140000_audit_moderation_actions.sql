-- P6.3 — let the audit log record moderation actions at all.
--
-- `audit_logs.action` carries a CHECK constraint enumerating the 19 values of
-- the `OrgAuditAction` Dart enum. Every one of them is an ORGANIZATION action
-- (create org, add venue, grant permission, ...), because that is all the audit
-- log was originally for.
--
-- P6.3 requires every chat-moderation action to write `log_audit_event`. Those
-- action names are not in the enumeration, so each insert would be rejected
-- with `23514 audit_logs_action_check`. And because an audit write must never
-- undo a mute or a delete that already took effect, both call sites are
-- deliberately best-effort try/catch -- so the rejection would have been
-- swallowed and the moderation audit trail would have been silently, uniformly
-- empty. Nothing in the client would have reported a problem.
--
-- Found by `supabase/tests/chat_moderation_authority.test.sql`, which calls
-- log_audit_event as a real API role rather than asserting the call site exists.
--
-- The constraint is kept rather than dropped: an open `action` column would let
-- a typo become a permanent, unqueryable audit category. Adding the four values
-- the moderation paths actually use keeps the column a closed vocabulary.
begin;

alter table public.audit_logs drop constraint audit_logs_action_check;

alter table public.audit_logs add constraint audit_logs_action_check
  check (action = any (array[
    -- Organization actions (unchanged, mirrors OrgAuditAction).
    'createOrganization',
    'updateOrganizationProfile',
    'addVenueBranch',
    'updateVenueBranch',
    'removeVenueBranch',
    'addSpeakerToRoster',
    'updateSpeakerDetails',
    'removeSpeakerFromRoster',
    'grantBroadcastPermission',
    'revokeBroadcastPermission',
    'updatePermissions',
    'assignOwnerRole',
    'revokeOwnerRole',
    'startLiveBroadcast',
    'endLiveBroadcast',
    'applyBroadcaster',
    'submitAffiliationRequest',
    'acceptAffiliationRequest',
    'declineAffiliationRequest',
    -- P6.3 chat moderation. Platform-scope: these are written with a null
    -- organization_id, which log_audit_event accepts precisely because a
    -- moderation action does not belong to one organization.
    'chatReportDismissed',
    'chatMessageDeleted',
    'chatSenderMuted',
    'chatSenderBanned'
  ]));

comment on column public.audit_logs.action is
  'Closed vocabulary. Organization actions mirror the OrgAuditAction Dart enum; the chat* values are platform-scope moderation actions (P6.3) written with a null organization_id. Extend the CHECK constraint in a new migration when adding one -- an unlisted value is rejected with 23514, and the callers are best-effort, so it would fail silently.';

commit;
