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

-- Delete rules:
--   * Family members (any @theguthries.org address) may delete their OWN posts.
--   * The admin (michael@theguthries.org) may delete ANY post.
-- (Drop the older policy first so this script stays re-runnable.)
drop policy if exists "Posts: delete own" on public.posts;
drop policy if exists "Posts: delete own (family)" on public.posts;
drop policy if exists "Posts: admin delete any" on public.posts;

create policy "Posts: delete own (family)"
  on public.posts for delete
  using (
    auth.uid() = user_id
    and lower(auth.jwt() ->> 'email') like '%@theguthries.org'
  );

create policy "Posts: admin delete any"
  on public.posts for delete
  using (lower(auth.jwt() ->> 'email') = 'michael@theguthries.org');

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

-- Photo delete rules mirror the post rules: family members can delete photos
-- in their own folder; the admin can delete any family photo.
drop policy if exists "Photos: delete own" on storage.objects;
drop policy if exists "Photos: delete own (family)" on storage.objects;
drop policy if exists "Photos: admin delete any" on storage.objects;

create policy "Photos: delete own (family)"
  on storage.objects for delete
  using (
    bucket_id = 'family-photos'
    AND auth.uid()::text = (storage.foldername(name))[1]
    AND lower(auth.jwt() ->> 'email') like '%@theguthries.org'
  );

create policy "Photos: admin delete any"
  on storage.objects for delete
  using (
    bucket_id = 'family-photos'
    AND lower(auth.jwt() ->> 'email') = 'michael@theguthries.org'
  );

-- 5. REACTIONS TABLE
--    One row per user per emoji per post (toggled on/off)
create table if not exists public.reactions (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid references public.posts(id) on delete cascade,
  user_id    uuid references auth.users(id) on delete cascade,
  emoji      text not null,
  created_at timestamptz default now(),
  unique(post_id, user_id, emoji)
);

alter table public.reactions enable row level security;

create policy "Reactions: read by members"
  on public.reactions for select
  using (auth.role() = 'authenticated');

create policy "Reactions: insert by members"
  on public.reactions for insert
  with check (auth.uid() = user_id);

create policy "Reactions: delete own"
  on public.reactions for delete
  using (auth.uid() = user_id);

-- 6. COMMENTS TABLE
create table if not exists public.comments (
  id         uuid primary key default gen_random_uuid(),
  post_id    uuid references public.posts(id) on delete cascade,
  user_id    uuid references auth.users(id) on delete cascade,
  author     text not null,
  body       text not null,
  created_at timestamptz default now()
);

alter table public.comments enable row level security;

create policy "Comments: read by members"
  on public.comments for select
  using (auth.role() = 'authenticated');

create policy "Comments: insert by members"
  on public.comments for insert
  with check (auth.uid() = user_id);

create policy "Comments: delete own"
  on public.comments for delete
  using (auth.uid() = user_id);

-- 7. INVITE-ONLY ACCESS
--    Only emails listed in public.allowed_emails may create an account.
--    Existing accounts are unaffected (the trigger only runs on sign-up).
--    To invite someone: add their email to public.allowed_emails (via the
--    Supabase Table Editor or: insert into public.allowed_emails(email) values ('them@example.com');)
create table if not exists public.allowed_emails (
  email      text primary key,
  note       text,
  created_at timestamptz default now()
);

alter table public.allowed_emails enable row level security;

-- Only the admin can view/manage the invite list from the client.
drop policy if exists "Allowlist: admin manage" on public.allowed_emails;
create policy "Allowlist: admin manage"
  on public.allowed_emails for all
  using (lower(auth.jwt() ->> 'email') = 'michael@theguthries.org')
  with check (lower(auth.jwt() ->> 'email') = 'michael@theguthries.org');

-- Reject sign-ups whose email is not on the allow-list.
create or replace function public.enforce_invite_only()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if not exists (
    select 1 from public.allowed_emails
    where lower(email) = lower(new.email)
  ) then
    raise exception 'invite_only: this email has not been invited';
  end if;
  return new;
end;
$$;

drop trigger if exists enforce_invite_only on auth.users;
create trigger enforce_invite_only
  before insert on auth.users
  for each row execute function public.enforce_invite_only();

-- Seed the admin so they can always sign in.
insert into public.allowed_emails (email, note)
  values ('michael@theguthries.org', 'admin')
  on conflict (email) do nothing;

-- 8. PUSH NOTIFICATIONS (native iOS app via APNs)
--    Device tokens registered by the iOS app are stored here.
create table if not exists public.device_tokens (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid references auth.users(id) on delete cascade,
  token      text not null unique,
  updated_at timestamptz default now()
);
alter table public.device_tokens enable row level security;
drop policy if exists "Device tokens: manage own" on public.device_tokens;
create policy "Device tokens: manage own"
  on public.device_tokens for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

--    Two deployed Edge Functions do the actual APNs sending:
--      notify-new-post   payload { postId, authorName, excludeUserId }
--      notify-engagement payload { postId, postAuthorId, engagementType, actorName }
--    Database triggers below call them via pg_net so that:
--      * a new post notifies everyone except its author, and
--      * a comment/reaction notifies only the post's author (skipping self-engagement).
--    The bearer token is the public anon key (only needs to satisfy the
--    functions' verify_jwt); the functions use their own service-role secret.
create extension if not exists pg_net;

create or replace function public.send_push_notification(fn text, payload jsonb)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform net.http_post(
    url := 'https://otdpvabxlaygvxpqgwuk.supabase.co/functions/v1/' || fn,
    body := payload,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im90ZHB2YWJ4bGF5Z3Z4cHFnd3VrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MTEwODgsImV4cCI6MjA4ODM4NzA4OH0.DpSiLf0cJ4CqUvS2efm4C7qw1YaVi-9ZY5DIWiJrEws'
    )
  );
exception when others then
  raise warning 'send_push_notification(%) failed: %', fn, sqlerrm;
end;
$$;

create or replace function public.tg_notify_new_post()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform public.send_push_notification('notify-new-post', jsonb_build_object(
    'postId', new.id,
    'authorName', coalesce(new.author, 'Someone'),
    'excludeUserId', new.user_id
  ));
  return new;
end;
$$;

create or replace function public.tg_notify_comment()
returns trigger language plpgsql security definer set search_path = '' as $$
declare post_author uuid;
begin
  select user_id into post_author from public.posts where id = new.post_id;
  if post_author is not null and post_author <> new.user_id then
    perform public.send_push_notification('notify-engagement', jsonb_build_object(
      'postId', new.post_id,
      'postAuthorId', post_author,
      'engagementType', 'comment',
      'actorName', coalesce(new.author, 'Someone')
    ));
  end if;
  return new;
end;
$$;

create or replace function public.tg_notify_reaction()
returns trigger language plpgsql security definer set search_path = '' as $$
declare post_author uuid; actor_name text;
begin
  select user_id into post_author from public.posts where id = new.post_id;
  if post_author is not null and post_author <> new.user_id then
    select name into actor_name from public.profiles where id = new.user_id;
    perform public.send_push_notification('notify-engagement', jsonb_build_object(
      'postId', new.post_id,
      'postAuthorId', post_author,
      'engagementType', 'reaction',
      'actorName', coalesce(actor_name, 'Someone')
    ));
  end if;
  return new;
end;
$$;

drop trigger if exists notify_new_post on public.posts;
create trigger notify_new_post after insert on public.posts
  for each row execute function public.tg_notify_new_post();

drop trigger if exists notify_comment on public.comments;
create trigger notify_comment after insert on public.comments
  for each row execute function public.tg_notify_comment();

drop trigger if exists notify_reaction on public.reactions;
create trigger notify_reaction after insert on public.reactions
  for each row execute function public.tg_notify_reaction();

-- ============================================================
-- Done! Your database is ready.
-- ============================================================
