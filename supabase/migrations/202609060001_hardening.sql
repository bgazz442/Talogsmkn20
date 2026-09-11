-- Hardening: add auto-update triggers for updated_at columns.
-- This migration is additive and does not modify existing data.

-- Reusable trigger function for updated_at
create or replace function public.set_updated_at()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Apply to all tables that have an updated_at column
drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists set_todos_updated_at on public.todos;
create trigger set_todos_updated_at
before update on public.todos
for each row execute function public.set_updated_at();

-- Revoke direct access to trigger function
revoke all on function public.set_updated_at() from public, anon, authenticated;
