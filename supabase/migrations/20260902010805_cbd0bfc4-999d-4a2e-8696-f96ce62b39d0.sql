-- avatars: owner-scoped writes, readable by everyone
drop policy if exists "avatars read" on storage.objects;
create policy "avatars read" on storage.objects
  for select to anon, authenticated
  using (bucket_id = 'avatars');

drop policy if exists "avatars insert own folder" on storage.objects;
create policy "avatars insert own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars update own folder" on storage.objects;
create policy "avatars update own folder" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "avatars delete own folder" on storage.objects;
create policy "avatars delete own folder" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- qr-files: fully owner-scoped
drop policy if exists "qr files read own folder" on storage.objects;
create policy "qr files read own folder" on storage.objects
  for select to authenticated
  using (bucket_id = 'qr-files' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "qr files insert own folder" on storage.objects;
create policy "qr files insert own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'qr-files' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "qr files update own folder" on storage.objects;
create policy "qr files update own folder" on storage.objects
  for update to authenticated
  using (bucket_id = 'qr-files' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'qr-files' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "qr files delete own folder" on storage.objects;
create policy "qr files delete own folder" on storage.objects
  for delete to authenticated
  using (bucket_id = 'qr-files' and (storage.foldername(name))[1] = auth.uid()::text);

CREATE TABLE public.contact_submissions (
  id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
  name text NOT NULL,
  email text NOT NULL,
  subject text NOT NULL,
  message text NOT NULL,
  ip_hash text,
  created_at timestamptz NOT NULL DEFAULT now()
);

GRANT INSERT ON public.contact_submissions TO anon, authenticated;
GRANT ALL ON public.contact_submissions TO service_role;
ALTER TABLE public.contact_submissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can submit contact form"
  ON public.contact_submissions FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

CREATE POLICY "Service role can read submissions"
  ON public.contact_submissions FOR ALL
  TO service_role
  USING (true) WITH CHECK (true);

create or replace function public.contact_submissions_recent_count(_ip_hash text, _minutes int default 60)
returns int
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
  from public.contact_submissions
  where ip_hash = _ip_hash
    and created_at > now() - (_minutes || ' minutes')::interval;
$$;

revoke all on function public.contact_submissions_recent_count(text, int) from public;
grant execute on function public.contact_submissions_recent_count(text, int) to anon, authenticated, service_role;

create index if not exists contact_submissions_ip_created_idx
  on public.contact_submissions (ip_hash, created_at desc);

ALTER TABLE public.contact_submissions
  ADD COLUMN IF NOT EXISTS user_agent_hash text,
  ADD COLUMN IF NOT EXISTS fingerprint_hash text;

CREATE INDEX IF NOT EXISTS contact_submissions_fingerprint_created_idx
  ON public.contact_submissions (fingerprint_hash, created_at desc);