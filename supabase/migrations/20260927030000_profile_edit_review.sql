-- Profile editing is distinct from initial verification. Sensitive revisions
-- retain the approved application as the public source until an admin approves.
begin;
alter table public.broadcaster_applications add column revision_of uuid
  references public.broadcaster_applications(id) on delete restrict;
create unique index application_one_pending_revision on public.broadcaster_applications(revision_of)
  where revision_of is not null and status = 'pending';

create or replace function public.guard_profile_edit_fields() returns trigger
language plpgsql security invoker set search_path = '' as $$
begin
  if current_user not in ('anon', 'authenticated') or public.is_admin_tier() then return new; end if;
  if tg_table_name = 'broadcaster_applications' then
    if tg_op = 'INSERT' then new.revision_of := null;
    else new.revision_of := old.revision_of; end if;
  elsif tg_table_name = 'profiles' then
    -- Auth email changes have their own verified flow. A contact edit here must
    -- never change auth.users or bypass broadcaster review through table writes.
    if tg_op = 'UPDATE' then
      new := jsonb_populate_record(new, jsonb_build_object(
        'email', old.email, 'youtube_handle', old.youtube_handle,
        'city_en', old.city_en, 'city_ar', old.city_ar,
        'venue_name_en', old.venue_name_en, 'venue_name_ar', old.venue_name_ar,
        'latitude', old.latitude, 'longitude', old.longitude));
    end if;
  else
    if tg_op = 'INSERT' then new.approved_application_id := null;
    else
      new.approved_application_id := old.approved_application_id;
      new.youtube_handle := old.youtube_handle;
    end if;
  end if;
  return new;
end;
$$;
create trigger guard_profile_edit_fields before update on public.profiles
for each row execute function public.guard_profile_edit_fields();
create trigger guard_org_edit_fields before insert or update on public.organizations
for each row execute function public.guard_profile_edit_fields();
create trigger guard_application_revision before insert or update on public.broadcaster_applications
for each row execute function public.guard_profile_edit_fields();
revoke all on function public.guard_profile_edit_fields() from public, anon, authenticated;

-- Internal publisher: never grants a role, resets live state, or creates an org.
create function public.publish_profile_edit(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare a public.broadcaster_applications; city_name_en text; city_name_ar text;
begin
  select * into strict a from public.broadcaster_applications where id=p_id and status='approved';
  select v.en,v.ar into city_name_en,city_name_ar from (values
    ('khobar','Al Khobar','الخبر'),('dhahran','Dhahran','الظهران'),
    ('dammam','Dammam','الدمام'),('ahsa','Al-Ahsa','الأحساء'),
    ('jubail','Jubail','الجبيل'),('riyadh','Riyadh','الرياض'),
    ('other','Other KSA Region','منطقة أخرى في السعودية')) v(id,en,ar) where v.id=a.city_id;
  if a.account_type='individualScholar' then
    update public.profiles set display_name_en=a.applicant_name_en, display_name_ar=a.applicant_name_ar,
      title_en=a.academic_title_en,title_ar=a.academic_title_ar,
      organization_en=a.institution_en,organization_ar=a.institution_ar,
      bio_en=a.bio_en,bio_ar=a.bio_ar,category_id=a.category_id,tags=a.tags,
      avatar_url=a.avatar_url,banner_url=a.banner_url,email=a.email,
      youtube_handle=a.youtube_handle,venue_name_en=a.venue_name_en,venue_name_ar=a.venue_name_ar,
      latitude=a.latitude,longitude=a.longitude,
      city_en=coalesce(city_name_en,profiles.city_en),
      city_ar=coalesce(city_name_ar,profiles.city_ar)
      where id=a.applicant_profile_id;
  else
    update public.organizations set name_en=a.applicant_name_en,name_ar=a.applicant_name_ar,
      bio_en=a.bio_en,bio_ar=a.bio_ar,category_id=a.category_id,tags=a.tags,
      avatar_url=a.avatar_url,banner_url=a.banner_url,youtube_handle=a.youtube_handle,
      official_website_url=a.official_website_url
      where approved_application_id=a.id and owner_profile_id=a.applicant_profile_id;
  end if;
end;
$$;
revoke all on function public.publish_profile_edit(uuid) from public, anon, authenticated;

create function public.save_broadcaster_profile(p_application_id uuid, p_changes jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare a public.broadcaster_applications; proposed public.broadcaster_applications;
  pending_id uuid; sensitive boolean; safe jsonb; allowed jsonb; k text;
begin
  if auth.uid() is null or public.is_current_user_banned() then raise exception 'Profile edit denied' using errcode='42501'; end if;
  -- Serializes submissions from two devices for this account.
  perform 1 from public.profiles where id=auth.uid() for update;
  select * into a from public.broadcaster_applications where id=p_application_id and applicant_profile_id=auth.uid();
  if not found then raise exception 'Application unavailable' using errcode='42501'; end if;
  if a.revision_of is not null then select * into a from public.broadcaster_applications where id=a.revision_of; end if;
  if a.applicant_profile_id <> auth.uid() or a.status <> 'approved' or not (
    exists(select 1 from public.profiles where id=auth.uid() and is_streamer and is_verified)
    or exists(select 1 from public.organizations where owner_profile_id=auth.uid() and approved_application_id=a.id and is_verified)
  ) then raise exception 'Approved profile required' using errcode='42501'; end if;
  select * into a from public.broadcaster_applications where id=a.id for update;
  if jsonb_typeof(p_changes) <> 'object' then raise exception 'Invalid profile data'; end if;
  safe := '{}'::jsonb; allowed := '{}'::jsonb;
  foreach k in array array['applicant_name_en','applicant_name_ar','academic_title_en','academic_title_ar',
    'institution_en','institution_ar','category_id','tags','bio_en','bio_ar','avatar_url','banner_url',
    'organization_type','seating_capacity','official_website_url'] loop
    if p_changes ? k then safe := safe || jsonb_build_object(k,p_changes->k); end if;
  end loop;
  allowed := safe;
  foreach k in array array['email','phone','city_id','latitude','longitude','venue_name_en','venue_name_ar',
    'youtube_channel_url','youtube_handle'] loop
    if p_changes ? k then allowed := allowed || jsonb_build_object(k,p_changes->k); end if;
  end loop;
  proposed := jsonb_populate_record(a,allowed);
  if nullif(trim(proposed.applicant_name_en),'') is null or nullif(trim(proposed.applicant_name_ar),'') is null
    or proposed.email is null or position('@' in proposed.email)=0
    or proposed.phone is null or proposed.tags is null
    or proposed.latitude not between -90 and 90 or proposed.longitude not between -180 and 180
    or ((proposed.youtube_channel_url is distinct from a.youtube_channel_url or proposed.youtube_handle is distinct from a.youtube_handle)
      and (proposed.youtube_channel_url !~ '^https://(www\.)?youtube\.com/(channel/|@)' or nullif(trim(proposed.youtube_handle),'') is null))
  then raise exception 'Invalid profile data' using errcode='22023'; end if;
  sensitive := false;
  foreach k in array array['email','phone','city_id','latitude','longitude','venue_name_en','venue_name_ar',
    'youtube_channel_url','youtube_handle'] loop
    sensitive := sensitive or (to_jsonb(proposed)->k is distinct from to_jsonb(a)->k);
  end loop;
  -- Safe changes publish even when this save also requests sensitive changes.
  update public.broadcaster_applications set
    applicant_name_en=proposed.applicant_name_en,applicant_name_ar=proposed.applicant_name_ar,
    academic_title_en=proposed.academic_title_en,academic_title_ar=proposed.academic_title_ar,
    institution_en=proposed.institution_en,institution_ar=proposed.institution_ar,
    category_id=proposed.category_id,tags=proposed.tags,bio_en=proposed.bio_en,bio_ar=proposed.bio_ar,
    avatar_url=proposed.avatar_url,banner_url=proposed.banner_url,organization_type=proposed.organization_type,
    seating_capacity=proposed.seating_capacity,official_website_url=proposed.official_website_url
    where id=a.id;
  perform public.publish_profile_edit(a.id);
  select id into pending_id from public.broadcaster_applications where revision_of=a.id and status='pending';
  if sensitive then
    if pending_id is not null then delete from public.broadcaster_applications where id=pending_id; end if;
    proposed.id := coalesce(pending_id,gen_random_uuid());
    proposed.revision_of := a.id; proposed.status := 'pending'; proposed.submitted_at := now();
    proposed.reviewed_at := null; proposed.reviewed_by := null; proposed.admin_review_notes := null;
    insert into public.broadcaster_applications select proposed.*;
    return to_jsonb(proposed);
  end if;
  if pending_id is not null then delete from public.broadcaster_applications where id=pending_id; end if;
  return (select to_jsonb(b) from public.broadcaster_applications b where id=a.id);
end;
$$;
revoke all on function public.save_broadcaster_profile(uuid,jsonb) from public, anon;
grant execute on function public.save_broadcaster_profile(uuid,jsonb) to authenticated;

-- Admin status transition publishes revisions atomically. Rejection leaves the
-- approved base and public profile untouched; it does not revoke an account.
create function public.apply_profile_revision() returns trigger
language plpgsql security definer set search_path = '' as $$
declare base public.broadcaster_applications;
begin
  if new.revision_of is null or new.status <> 'approved' or old.status <> 'pending' then return new; end if;
  select * into strict base from public.broadcaster_applications where id=new.revision_of for update;
  if base.status <> 'approved' or base.applicant_profile_id <> new.applicant_profile_id
    or base.account_type <> new.account_type then raise exception 'Invalid profile revision'; end if;
  update public.broadcaster_applications set
    applicant_name_en=new.applicant_name_en,applicant_name_ar=new.applicant_name_ar,
    academic_title_en=new.academic_title_en,academic_title_ar=new.academic_title_ar,
    institution_en=new.institution_en,institution_ar=new.institution_ar,
    category_id=new.category_id,tags=new.tags,bio_en=new.bio_en,bio_ar=new.bio_ar,
    avatar_url=new.avatar_url,banner_url=new.banner_url,organization_type=new.organization_type,
    seating_capacity=new.seating_capacity,official_website_url=new.official_website_url,
    email=new.email,phone=new.phone,city_id=new.city_id,latitude=new.latitude,longitude=new.longitude,
    venue_name_en=new.venue_name_en,venue_name_ar=new.venue_name_ar,
    youtube_channel_url=new.youtube_channel_url,youtube_handle=new.youtube_handle,
    reviewed_at=new.reviewed_at,reviewed_by=new.reviewed_by where id=base.id;
  perform public.publish_profile_edit(base.id);
  return new;
end;
$$;
revoke all on function public.apply_profile_revision() from public, anon, authenticated;
create trigger apply_profile_revision after update of status on public.broadcaster_applications
for each row execute function public.apply_profile_revision();
commit;
