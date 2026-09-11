-- Ensure profiles.username exists and is safe for admin and student profile editing.
create extension if not exists citext;

alter table public.profiles
  add column if not exists username citext;

create unique index if not exists profiles_username_unique_idx
  on public.profiles (username)
  where username is not null;

alter table public.profiles enable row level security;

-- Restrict profile updates to the current authenticated user.
drop policy if exists profiles_update_own_safe_fields on public.profiles;
create policy profiles_update_own_safe_fields on public.profiles
for update to authenticated
using (id = (select auth.uid()) and status = 'active')
with check (id = (select auth.uid()) and role = public.current_user_role() and status = 'active');

revoke update (username, full_name, updated_at) on public.profiles from public, anon, authenticated;
grant update (full_name, username, updated_at) on public.profiles to authenticated;

-- Re-ensure profile reads remain limited to the owner or staff.
drop policy if exists "users read own profile" on public.profiles;
create policy "users read own profile" on public.profiles
for select to authenticated
using (id = auth.uid() or public.current_user_role() in ('admin', 'superadmin'));
