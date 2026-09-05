create table if not exists public.analytics_events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references public.profiles(id) on delete cascade,
  event_type text not null,
  device_type text,
  referrer text,
  created_at timestamptz not null default now()
);
grant insert on public.analytics_events to anon, authenticated;
grant select on public.analytics_events to authenticated;
grant all on public.analytics_events to service_role;
alter table public.analytics_events enable row level security;
create policy "anyone can log events" on public.analytics_events for insert to anon, authenticated with check (true);
create policy "own events read" on public.analytics_events for select to authenticated using (auth.uid() = profile_id);

create table if not exists public.tracked_qrs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  slug text not null unique,
  dashboard_token text not null unique,
  kind text not null default 'qr',
  label text,
  target_type text not null,
  target_url text not null,
  custom_domain text,
  short_link_enabled boolean not null default false,
  is_active boolean not null default true,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on public.tracked_qrs to authenticated;
grant insert on public.tracked_qrs to anon;
grant all on public.tracked_qrs to service_role;
alter table public.tracked_qrs enable row level security;
create policy "own qrs" on public.tracked_qrs for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id or user_id is null);
create policy "anon can create qrs" on public.tracked_qrs for insert to anon with check (user_id is null);

create table if not exists public.qr_scans (
  id uuid primary key default gen_random_uuid(),
  tracked_qr_id uuid not null references public.tracked_qrs(id) on delete cascade,
  scanned_at timestamptz not null default now(),
  country text,
  device text,
  user_agent text
);
grant select on public.qr_scans to authenticated;
grant all on public.qr_scans to service_role;
alter table public.qr_scans enable row level security;
create policy "own scans read" on public.qr_scans for select to authenticated using (
  exists (select 1 from public.tracked_qrs q where q.id = tracked_qr_id and q.user_id = auth.uid())
);

create table if not exists public.saved_qrs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  name text not null,
  qr_type text not null,
  qr_value text not null,
  config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant select, insert, update, delete on public.saved_qrs to authenticated;
grant all on public.saved_qrs to service_role;
alter table public.saved_qrs enable row level security;
create policy "own saved qrs" on public.saved_qrs for all to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);