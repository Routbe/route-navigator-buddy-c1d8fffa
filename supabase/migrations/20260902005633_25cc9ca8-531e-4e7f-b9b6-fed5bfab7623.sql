create table if not exists public.badges (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  name text not null,
  description text not null default '',
  icon text not null default 'award',
  color text not null default 'slate',
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
grant select on public.badges to anon, authenticated;
grant all on public.badges to service_role;
alter table public.badges enable row level security;
create policy "badges are public" on public.badges for select to anon, authenticated using (true);

create table if not exists public.user_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  badge_id uuid not null references public.badges(id) on delete cascade,
  awarded_by uuid,
  awarded_at timestamptz not null default now(),
  unique (user_id, badge_id)
);
grant select on public.user_badges to anon, authenticated;
grant all on public.user_badges to service_role;
alter table public.user_badges enable row level security;
create policy "user badges readable" on public.user_badges for select to anon, authenticated using (true);

create table if not exists public.badge_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  badge_slug text not null,
  action text not null default 'granted',
  source text not null default 'system',
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
grant select on public.badge_events to authenticated;
grant all on public.badge_events to service_role;
alter table public.badge_events enable row level security;
create policy "own badge events" on public.badge_events for select to authenticated using (auth.uid() = user_id or public.has_role(auth.uid(),'admin'));

create table if not exists public.admin_audit_log (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null,
  admin_email text,
  action text not null,
  target_user_id uuid,
  target_label text,
  notes text,
  created_at timestamptz not null default now()
);
grant select on public.admin_audit_log to authenticated;
grant all on public.admin_audit_log to service_role;
alter table public.admin_audit_log enable row level security;
create policy "admins read audit" on public.admin_audit_log for select to authenticated using (public.has_role(auth.uid(),'admin'));

create table if not exists public.alias_sync_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null,
  action text not null,
  status text not null default 'pending',
  attempts integer not null default 0,
  max_attempts integer not null default 5,
  payload jsonb not null default '{}'::jsonb,
  last_error text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
grant all on public.alias_sync_jobs to service_role;
alter table public.alias_sync_jobs enable row level security;