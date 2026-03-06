-- ============================================================
-- Family Site — Supabase Database Setup
-- Run this entire script in: Supabase Dashboard → SQL Editor
-- ============================================================

-- 1. PROFILES TABLE
--    Stores each family member's display name
create table if not exists public.profiles (
  id   uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  created_at timestamptz default now()
);

-- 2. POSTS TABLE
--    Stores every post (text + optional photo)
create table if not exists public.posts (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete cascade,
  author     text not null,
  body       text,
  photo_url  text,
  created_at timestamptz default now()
);

-- 3. ROW LEVEL SECURITY
--    Only signed-in family members can see & create posts

-- Profiles: readable by any logged-in user, editable only by owner
alter table public.profiles enable row level security;

create policy "Profiles: read by members"
  on public.profiles for select
  using (auth.role() = 'authenticated');

create policy "Profiles: insert own"
  on public.profiles for insert
  with check (auth.uid() = id);

create policy "Profiles: update own"
  on public.profiles for update
  using (auth.uid() = id);

-- Posts: readable by any logged-in user
alter table public.posts enable row level security;

create policy "Posts: read by members"
  on public.posts for select
  using (auth.role() = 'authenticated');

create policy "Posts: insert by members"
  on public.posts for insert
  with check (auth.uid() = user_id);

create policy "Posts: delete own"
  on public.posts for delete
  using (auth.uid() = user_id);

-- 4. STORAGE BUCKET
--    Create the photo storage bucket (do this in Dashboard → Storage,
--    OR run the insert below if using the SQL editor with storage access)
insert into storage.buckets (id, name, public)
  values ('family-photos', 'family-photos', true)
  on conflict do nothing;

-- Storage policies — allow authenticated users to upload & view
create policy "Photos: upload by members"
  on storage.objects for insert
  with check (bucket_id = 'family-photos' AND auth.role() = 'authenticated');

create policy "Photos: read by anyone"
  on storage.objects for select
  using (bucket_id = 'family-photos');

create policy "Photos: delete own"
  on storage.objects for delete
  using (bucket_id = 'family-photos' AND auth.uid()::text = (storage.foldername(name))[1]);

-- ============================================================
-- Done! Your database is ready.
-- ============================================================
