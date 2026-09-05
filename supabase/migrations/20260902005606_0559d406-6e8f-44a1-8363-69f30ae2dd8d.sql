create extension if not exists pgcrypto;

do $$ begin
  create type public.app_role as enum ('admin','moderator','user');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key,
  username text unique,
  display_name text,
  tagline text,
  bio text,
  avatar_url text,
  favicon_url text,
  theme text not null default 'paper',
  card_style text not null default 'classic',
  blocks jsonb not null default '[]'::jsonb,
  business_info jsonb not null default '{}'::jsonb,
  tier text not null default 'free',
  status text not null default 'active',
  verified boolean not null default false,
  verified_at timestamptz,
  verified_legal_name text,
  is_early_believer boolean not null default false,
  is_paid boolean not null default false,
  is_suspended boolean not null default false,
  is_banned boolean not null default false,
  subdomain_enabled boolean not null default false,
  custom_domain text,
  bluesky_did text,
  redirect_target text not null default 'hub',
  show_email_publicly boolean not null default false,
  forwarding_email text,
  forwarding_email_token text,
  forwarding_email_token_expires_at timestamptz,
  forwarding_email_verified boolean not null default false,
  handle_grant text,
  payment_method text,
  moderated_at timestamptz,
  moderated_by uuid,
  moderation_reason text,
  alias_status text not null default 'none',
  alias_sync_status text not null default 'idle',
  alias_sync_attempts integer not null default 0,
  alias_sync_error text,
  alias_synced_at timestamptz,
  referred_by uuid,
  referral_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on public.profiles to authenticated;
grant all on public.profiles to service_role;
alter table public.profiles enable row level security;
create policy "own profile read" on public.profiles for select to authenticated using (auth.uid() = id);
create policy "own profile insert" on public.profiles for insert to authenticated with check (auth.uid() = id);
create policy "own profile update" on public.profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

create table if not exists public.user_roles (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  role public.app_role not null,
  created_at timestamptz not null default now(),
  unique (user_id, role)
);
grant select on public.user_roles to authenticated;
grant all on public.user_roles to service_role;
alter table public.user_roles enable row level security;
create policy "read own roles" on public.user_roles for select to authenticated using (auth.uid() = user_id);

create or replace function public.has_role(_user_id uuid, _role public.app_role)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = _user_id and role = _role)
$$;

create table if not exists public.links (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  url text not null,
  icon text,
  position integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on public.links to authenticated;
grant select on public.links to anon;
grant all on public.links to service_role;
alter table public.links enable row level security;
create policy "public links read" on public.links for select to anon, authenticated using (true);
create policy "own links write" on public.links for all to authenticated using (auth.uid() = profile_id) with check (auth.uid() = profile_id);