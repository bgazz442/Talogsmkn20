-- Keep personal contact identity separate from the Supabase Auth login email.
-- This migration does not create users or modify existing UUIDs.

alter table public.profiles
  add column if not exists personal_email citext;

create unique index if not exists profiles_personal_email_unique_idx
  on public.profiles (personal_email)
  where personal_email is not null;
