alter table public.qr_scans drop column if exists user_agent;
alter table public.qr_scans add column if not exists browser text;
alter table public.qr_scans add column if not exists os text;

drop function if exists public.log_qr_scan(uuid, text, text, text);

create or replace function public.log_qr_scan(
  _tracked_qr_id uuid,
  _device text default null,
  _country text default null,
  _browser text default null,
  _os text default null
) returns void language plpgsql volatile security definer set search_path = public as $$
begin
  insert into public.qr_scans (tracked_qr_id, device, country, browser, os)
  values (_tracked_qr_id, left(_device, 20), left(_country, 2), left(_browser, 20), left(_os, 20));
end;
$$;
revoke all on function public.log_qr_scan(uuid, text, text, text, text) from public;
grant execute on function public.log_qr_scan(uuid, text, text, text, text) to anon, authenticated, service_role;

create or replace function public.short_link_stats(_token text)
returns jsonb language sql stable security definer set search_path = public as $$
  select case when q.id is null then null else jsonb_build_object(
    'qr', to_jsonb(q),
    'scans', coalesce((
      select jsonb_agg(jsonb_build_object(
        'scanned_at', s.scanned_at, 'country', s.country,
        'device', s.device, 'browser', s.browser, 'os', s.os
      ) order by s.scanned_at desc)
      from public.qr_scans s where s.tracked_qr_id = q.id
    ), '[]'::jsonb)
  ) end
  from public.tracked_qrs q
  where q.dashboard_token = _token
  limit 1;
$$;
revoke all on function public.short_link_stats(text) from public;
grant execute on function public.short_link_stats(text) to anon, authenticated, service_role;

revoke all on public.alias_sync_jobs from anon, authenticated;
revoke all on public.referral_visits from anon, authenticated;
revoke all on public.upload_rate_limits from anon, authenticated;
revoke all on public.webhook_events from anon, authenticated;
grant all on public.alias_sync_jobs to service_role;
grant all on public.referral_visits to service_role;
grant all on public.upload_rate_limits to service_role;
grant all on public.webhook_events to service_role;
grant select on public.alias_sync_jobs to authenticated;
grant select on public.webhook_events to authenticated;

create policy "Admins can read alias sync jobs" on public.alias_sync_jobs
  for select to authenticated using (public.has_role(auth.uid(), 'admin'));
create policy "Admins can read webhook events" on public.webhook_events
  for select to authenticated using (public.has_role(auth.uid(), 'admin'));
create policy "Service role manages referral visits" on public.referral_visits
  for all to service_role using (true) with check (true);
create policy "Service role manages upload rate limits" on public.upload_rate_limits
  for all to service_role using (true) with check (true);

DROP TABLE IF EXISTS public.referral_visits CASCADE;

create table if not exists public.signin_throttle (
  identity_hash text primary key,
  failures int not null default 0,
  window_started_at timestamptz not null default now(),
  locked_until timestamptz
);

grant all on public.signin_throttle to service_role;
alter table public.signin_throttle enable row level security;

create or replace function public.signin_guard_status(_identity_hash text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare r public.signin_throttle;
begin
  select * into r from public.signin_throttle where identity_hash = _identity_hash;
  if r.identity_hash is null or r.locked_until is null or r.locked_until <= now() then
    return jsonb_build_object('locked', false, 'retry_after', 0);
  end if;
  return jsonb_build_object('locked', true,
    'retry_after', greatest(1, ceil(extract(epoch from (r.locked_until - now())))::int));
end;
$$;

create or replace function public.signin_guard_record(_identity_hash text, _success boolean)
returns jsonb language plpgsql volatile security definer set search_path = public as $$
declare r public.signin_throttle; new_failures int; lock_for interval;
begin
  if _identity_hash is null or length(_identity_hash) not between 16 and 128 then
    return jsonb_build_object('locked', false, 'retry_after', 0);
  end if;

  if _success then
    delete from public.signin_throttle where identity_hash = _identity_hash;
    return jsonb_build_object('locked', false, 'retry_after', 0);
  end if;

  select * into r from public.signin_throttle where identity_hash = _identity_hash for update;

  if r.identity_hash is null or r.window_started_at < now() - interval '15 minutes' then
    insert into public.signin_throttle (identity_hash, failures, window_started_at, locked_until)
    values (_identity_hash, 1, now(), null)
    on conflict (identity_hash) do update
      set failures = 1, window_started_at = now(), locked_until = null;
    return jsonb_build_object('locked', false, 'retry_after', 0);
  end if;

  new_failures := r.failures + 1;
  lock_for := case
    when new_failures >= 10 then interval '15 minutes'
    when new_failures >= 7 then interval '5 minutes'
    when new_failures >= 5 then interval '1 minute'
    else null end;

  update public.signin_throttle
     set failures = new_failures,
         locked_until = case when lock_for is null then null else now() + lock_for end
   where identity_hash = _identity_hash;

  delete from public.signin_throttle
   where window_started_at < now() - interval '1 day'
     and (locked_until is null or locked_until < now());

  if lock_for is null then
    return jsonb_build_object('locked', false, 'retry_after', 0);
  end if;
  return jsonb_build_object('locked', true,
    'retry_after', ceil(extract(epoch from lock_for))::int);
end;
$$;

revoke all on function public.signin_guard_status(text) from public;
revoke all on function public.signin_guard_record(text, boolean) from public;
grant execute on function public.signin_guard_status(text) to anon, authenticated, service_role;
grant execute on function public.signin_guard_record(text, boolean) to anon, authenticated, service_role;

create or replace function public.log_qr_scan(
  _tracked_qr_id uuid,
  _device text default null,
  _country text default null,
  _browser text default null,
  _os text default null
) returns void language plpgsql volatile security definer set search_path = public as $$
declare recent int;
begin
  if _tracked_qr_id is null then return; end if;

  select count(*) into recent
    from public.qr_scans
   where tracked_qr_id = _tracked_qr_id
     and scanned_at > now() - interval '1 minute';

  if recent >= 60 then return; end if;

  insert into public.qr_scans (tracked_qr_id, device, country, browser, os)
  values (_tracked_qr_id, left(_device, 20), left(_country, 2), left(_browser, 20), left(_os, 20));
end;
$$;
revoke all on function public.log_qr_scan(uuid, text, text, text, text) from public;
grant execute on function public.log_qr_scan(uuid, text, text, text, text) to anon, authenticated, service_role;

drop view if exists public.public_profiles;

create or replace view public.public_profiles
with (security_invoker = false) as
select
  p.id,
  p.username,
  p.display_name,
  p.tagline,
  p.bio,
  p.avatar_url,
  p.favicon_url,
  p.theme,
  p.card_style,
  p.blocks,
  p.business_info,
  p.tier,
  p.status,
  p.verified,
  p.verified_at,
  p.is_early_believer,
  p.is_suspended,
  p.is_banned,
  p.subdomain_enabled,
  p.custom_domain,
  p.bluesky_did,
  p.created_at,
  p.show_email_publicly,
  case when p.show_email_publicly then p.forwarding_email else null end as forwarding_email
from public.profiles p;

grant select on public.public_profiles to anon, authenticated;
grant select on public.public_profiles to service_role;

drop policy if exists "Profiles are publicly viewable" on public.profiles;
drop policy if exists "Users view own profile" on public.profiles;
drop policy if exists "Admins view all profiles" on public.profiles;

create policy "Users view own profile"
on public.profiles for select
to authenticated
using (auth.uid() = id);

create policy "Admins view all profiles"
on public.profiles for select
to authenticated
using (public.has_role(auth.uid(), 'admin'));

revoke select on public.profiles from anon;

create or replace function public.is_handle_available(_username text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select not exists (
    select 1 from public.profiles
    where username = lower(_username)
      and id <> coalesce(auth.uid(), '00000000-0000-0000-0000-000000000000'::uuid)
  );
$$;

revoke all on function public.is_handle_available(text) from public;
grant execute on function public.is_handle_available(text) to authenticated;

create or replace function public.get_public_profile(_username text)
returns table (
  id uuid,
  username text,
  display_name text,
  tagline text,
  bio text,
  avatar_url text,
  favicon_url text,
  theme text,
  card_style text,
  blocks jsonb,
  business_info jsonb,
  tier text,
  status text,
  verified boolean,
  verified_at timestamptz,
  is_early_believer boolean,
  is_suspended boolean,
  is_banned boolean,
  subdomain_enabled boolean,
  custom_domain text,
  bluesky_did text,
  created_at timestamptz,
  show_email_publicly boolean,
  forwarding_email text
)
language sql
stable
security definer
set search_path = public
as $$
  select *
  from public.public_profiles
  where username = lower(_username)
    and is_suspended = false
    and is_banned = false
  limit 1;
$$;

revoke all on function public.get_public_profile(text) from public;
grant execute on function public.get_public_profile(text) to anon, authenticated, service_role;

alter table public.profiles add column if not exists url_style text default 'handle';
alter table public.profiles add column if not exists subdomain_alias text;
alter table public.profiles add column if not exists display_prefs jsonb default '{}'::jsonb;

comment on column public.profiles.url_style is 'Either "handle" (/u/:handle) or "subdomain" (:handle.rout.be)';
comment on column public.profiles.subdomain_alias is 'Subdomain used when url_style = "subdomain"';
comment on column public.profiles.display_prefs is 'Public profile display preferences (e.g. font, density)';

alter table public.profiles add column if not exists forwarding_email text;
alter table public.profiles add column if not exists show_email_publicly boolean default false;

comment on column public.profiles.forwarding_email is 'Contact email shown on public profile if show_email_publicly is true';
comment on column public.profiles.show_email_publicly is 'Whether to display forwarding_email on the public profile';