-- v0.9 Checkpoint 2, Phase 1: Account & Data Deletion
--
-- Google Play / App Store submission blocker (doc/Audit/03_Saudi_Legal_And_Store_Compliance_Audit.md,
-- doc/Audit/01_Security_Data_Protection_Audit.md VULN-COMP-03): there is no
-- account-deletion path anywhere. profiles.id already references
-- auth.users(id) on delete cascade (20260821203000_initial_schema.sql), and
-- everything that hangs off a profile (broadcaster_applications, chat_messages
-- via sender_id, user_roles, user_permissions) already cascades cleanly on
-- profile deletion. audit_logs.actor_profile_id is `on delete set null`,
-- which is the table that actually needs to survive a deleted user for audit
-- integrity -- so it already does the right thing.
--
-- The one real blocker is organizations.owner_profile_id, which is
-- `on delete restrict` (deliberately, so an org can't vanish out from under
-- its venues/speakers by accident elsewhere in the app). Self-service account
-- deletion needs to clear that deliberately instead, which is what this
-- trigger does.
--
-- Deviation from the original plan draft: chat_messages has no denormalized
-- sender_name/message_text columns to rewrite into "Deleted User" -- sender
-- display names are always resolved live from profiles via the
-- chat_sender_info() RPC (20260823140000_chat_sender_info.sql), never stored
-- on the message row. With sender_id on delete cascade, a deleted user's
-- messages are removed along with them, which is a cleaner PDPL erasure
-- outcome than a half-anonymized row and needs no schema/UI changes beyond
-- this migration.
create or replace function public.handle_profile_before_delete()
returns trigger
security definer
set search_path = public
language plpgsql
as $$
begin
  -- Organizations owned by this profile would otherwise block the delete
  -- (owner_profile_id is `on delete restrict`). Removing them here lets the
  -- rest of the cascade (org_venues, org_speakers, org_speaker roles, etc.,
  -- all already `on delete cascade` off organizations) proceed normally.
  delete from public.organizations where owner_profile_id = old.id;

  return old;
end;
$$;

drop trigger if exists tr_profiles_before_delete on public.profiles;

create trigger tr_profiles_before_delete
  before delete on public.profiles
  for each row
  execute function public.handle_profile_before_delete();

-- ---------------------------------------------------------------------------
-- Self-service deletion entry point. Regular authenticated clients cannot
-- delete from auth.users directly (that table is owned by
-- supabase_auth_admin, not exposed via the Data API), so this narrow
-- security definer RPC does it on the caller's behalf -- strictly for their
-- own auth.uid(), never a parameterized target id, so there is no way to use
-- it to delete anyone else's account.
-- ---------------------------------------------------------------------------
create or replace function public.delete_own_account()
returns void
security definer
set search_path = public
language plpgsql
as $$
begin
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_own_account() from public;
grant execute on function public.delete_own_account() to authenticated;
