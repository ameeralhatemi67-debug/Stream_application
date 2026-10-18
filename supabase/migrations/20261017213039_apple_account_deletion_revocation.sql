-- W19 source only. Owner applies after auditing the Edge Function and secrets.
begin;

create table private.apple_deletion_revocations (
  identity_id uuid primary key references auth.identities(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  subject text not null,
  identity_version text not null,
  revoked_at timestamptz not null default clock_timestamp()
);
alter table private.apple_deletion_revocations enable row level security;
revoke all on private.apple_deletion_revocations from public, anon, authenticated, service_role;

-- Epoch timestamps keep the opaque version stable across session time zones.
-- Repeat sign-ins may leave updated_at unchanged; bind sign-in time and data too.
create function public.apple_deletion_identities(p_user_id uuid)
returns jsonb language plpgsql security definer set search_path = '' as $$
begin
  if not exists (select 1 from auth.users where id = p_user_id)
      or private.account_deletion_blocker(p_user_id) is not null then
    raise exception 'Account deletion unavailable' using errcode = '55000';
  end if;
  return coalesce((select jsonb_agg(jsonb_build_object(
    'identity_id', i.id, 'subject', i.provider_id,
    'version', jsonb_build_array(
          extract(epoch from i.updated_at), extract(epoch from i.last_sign_in_at),
          encode(sha256(convert_to(i.identity_data::text, 'UTF8')), 'hex'))::text))
    from auth.identities i where i.user_id = p_user_id and i.provider = 'apple'), '[]'::jsonb);
end;
$$;
revoke all on function public.apple_deletion_identities(uuid) from public, anon, authenticated;
grant execute on function public.apple_deletion_identities(uuid) to service_role;

create function public.record_apple_deletion_revocation(
  p_user_id uuid, p_identity_id uuid, p_subject text, p_version text)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(20260920, 12);
  if not exists (select 1 from auth.identities i
      where i.id = p_identity_id and i.user_id = p_user_id and i.provider = 'apple'
        and i.provider_id = p_subject
        and jsonb_build_array(
          extract(epoch from i.updated_at), extract(epoch from i.last_sign_in_at),
          encode(sha256(convert_to(i.identity_data::text, 'UTF8')), 'hex'))::text = p_version)
      or private.account_deletion_blocker(p_user_id) is not null then
    raise exception 'Apple identity changed' using errcode = '55000';
  end if;
  insert into private.apple_deletion_revocations
    (identity_id, user_id, subject, identity_version, revoked_at)
    values (p_identity_id, p_user_id, p_subject, p_version, clock_timestamp())
  on conflict (identity_id) do update set user_id = excluded.user_id,
    subject = excluded.subject, identity_version = excluded.identity_version,
    revoked_at = excluded.revoked_at;
end;
$$;
revoke all on function public.record_apple_deletion_revocation(uuid,uuid,text,text)
  from public, anon, authenticated;
grant execute on function public.record_apple_deletion_revocation(uuid,uuid,text,text)
  to service_role;

-- Protect the existing deletion RPC even if a client omits the Edge Function.
create function private.require_apple_revocation_before_deletion()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform pg_advisory_xact_lock(20260920, 12);
  if exists (
    select 1 from auth.identities i where i.user_id = old.id and i.provider = 'apple'
      and not exists (
        select 1 from private.apple_deletion_revocations r
        where r.identity_id = i.id and r.user_id = old.id and r.subject = i.provider_id
          and r.identity_version = jsonb_build_array(
          extract(epoch from i.updated_at), extract(epoch from i.last_sign_in_at),
          encode(sha256(convert_to(i.identity_data::text, 'UTF8')), 'hex'))::text
          and r.revoked_at >= clock_timestamp() - interval '10 minutes'
      )
  ) then
    raise exception 'apple_revocation_required' using errcode = '55000';
  end if;
  return old;
end;
$$;
revoke all on function private.require_apple_revocation_before_deletion()
  from public, anon, authenticated, service_role;
create trigger require_apple_revocation_before_deletion
  before delete on auth.users for each row
  execute function private.require_apple_revocation_before_deletion();

create or replace function public.prepare_account_deletion()
returns jsonb language plpgsql stable security definer set search_path = '' as $$
declare v uuid := auth.uid();
begin
  if v is null then raise exception 'Not signed in' using errcode = '42501'; end if;
  return jsonb_build_object(
    'blocker', private.account_deletion_blocker(v),
    'requires_apple_revocation', exists (
      select 1 from auth.identities i where i.user_id = v and i.provider = 'apple'),
    'storage_paths', coalesce((select jsonb_agg(p)
      from private.account_storage_paths(v) p), '[]'::jsonb));
end;
$$;
revoke all on function public.prepare_account_deletion() from public, anon;
grant execute on function public.prepare_account_deletion() to authenticated;

comment on table private.apple_deletion_revocations is
  'Short-lived revocation proof, no Apple tokens or secrets. Identity updates invalidate proof; account/identity deletion cascades it.';
commit;
