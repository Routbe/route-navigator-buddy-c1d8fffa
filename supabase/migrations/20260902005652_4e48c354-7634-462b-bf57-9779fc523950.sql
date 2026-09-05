create table if not exists public.api_keys (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  key_hash text not null,
  key_prefix text not null,
  scopes text[] not null default '{}',
  rate_limit integer not null default 1000,
  request_count integer not null default 0,
  last_used_at timestamptz,
  revoked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on public.api_keys to authenticated;
grant all on public.api_keys to service_role;
alter table public.api_keys enable row level security;
create policy "own api keys" on public.api_keys for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.custom_domains (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  domain text not null unique,
  status text not null default 'pending',
  verification_token text not null,
  verified_at timestamptz,
  last_checked_at timestamptz,
  is_default boolean not null default false,
  short_links_enabled boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on public.custom_domains to authenticated;
grant all on public.custom_domains to service_role;
alter table public.custom_domains enable row level security;
create policy "own domains" on public.custom_domains for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.reserved_handles (
  handle text primary key,
  reason text not null default 'reserved',
  label text,
  created_at timestamptz not null default now()
);
grant select on public.reserved_handles to anon, authenticated;
grant all on public.reserved_handles to service_role;
alter table public.reserved_handles enable row level security;
create policy "reserved handles readable" on public.reserved_handles for select to anon, authenticated using (true);

create table if not exists public.security_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  kind text not null,
  message text not null,
  severity text not null default 'info',
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
grant select on public.security_events to authenticated;
grant all on public.security_events to service_role;
alter table public.security_events enable row level security;
create policy "own security events" on public.security_events for select to authenticated using (auth.uid() = user_id or public.has_role(auth.uid(),'admin'));

create table if not exists public.showcase_profiles (
  id uuid primary key default gen_random_uuid(),
  handle text not null unique,
  display_name text not null,
  tagline text not null default '',
  bio text not null default '',
  avatar_url text,
  theme text not null default 'paper',
  link_count integer not null default 0,
  verified boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select on public.showcase_profiles to anon, authenticated;
grant all on public.showcase_profiles to service_role;
alter table public.showcase_profiles enable row level security;
create policy "showcase public" on public.showcase_profiles for select to anon, authenticated using (true);

create table if not exists public.upload_rate_limits (
  client_ip text primary key,
  upload_count integer not null default 0,
  window_start timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant all on public.upload_rate_limits to service_role;
alter table public.upload_rate_limits enable row level security;

create table if not exists public.verification_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  tier text not null,
  amount_cents integer not null,
  currency text not null default 'EUR',
  donation_cents integer not null default 0,
  donation_plan text not null default 'none',
  provider text not null default 'manual',
  provider_ref text,
  reference_code text,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert on public.verification_payments to authenticated;
grant all on public.verification_payments to service_role;
alter table public.verification_payments enable row level security;
create policy "own payments" on public.verification_payments for select to authenticated using (auth.uid() = user_id);
create policy "own payments insert" on public.verification_payments for insert to authenticated with check (auth.uid() = user_id);

create table if not exists public.webhook_events (
  id text primary key,
  source text not null,
  kind text,
  created_at timestamptz not null default now()
);
grant all on public.webhook_events to service_role;
alter table public.webhook_events enable row level security;

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  kind text not null,
  title text not null,
  body text not null default '',
  locale text not null default 'en',
  severity text not null default 'info',
  details jsonb not null default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
grant select, update on public.notifications to authenticated;
grant all on public.notifications to service_role;
alter table public.notifications enable row level security;
create policy "own notifications" on public.notifications for select to authenticated using (auth.uid() = user_id);
create policy "own notifications update" on public.notifications for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);

create table if not exists public.referral_visits (
  id uuid primary key default gen_random_uuid(),
  handle text not null,
  inviter_id uuid,
  created_at timestamptz not null default now()
);
grant all on public.referral_visits to service_role;
alter table public.referral_visits enable row level security;