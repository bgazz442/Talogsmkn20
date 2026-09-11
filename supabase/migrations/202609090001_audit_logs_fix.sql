-- Ensure the audit log table, policies, and RPC exist in a safe, idempotent manner.
-- This migration is intended to repair a missing or partial public.audit_logs schema.

create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_role text not null default 'system',
  action text not null,
  target_user_id uuid references auth.users(id) on delete set null,
  target_table text,
  target_record_id text,
  description text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

alter table public.audit_logs
  alter column actor_role set default 'system';
alter table public.audit_logs
  alter column metadata set default '{}'::jsonb;

create index if not exists audit_logs_actor_user_id_idx on public.audit_logs (actor_user_id);
create index if not exists audit_logs_target_user_id_idx on public.audit_logs (target_user_id);
create index if not exists audit_logs_action_idx on public.audit_logs (action);
create index if not exists audit_logs_created_at_idx on public.audit_logs (created_at desc);

alter table public.audit_logs enable row level security;

revoke update, delete on public.audit_logs from public, anon, authenticated;
revoke insert on public.audit_logs from public, anon, authenticated;

drop policy if exists audit_logs_read_admin on public.audit_logs;
create policy audit_logs_read_admin on public.audit_logs
for select to authenticated
using (public.is_active_role(array['admin', 'superadmin']));

drop policy if exists audit_logs_insert_authenticated on public.audit_logs;
create policy audit_logs_insert_authenticated on public.audit_logs
for insert to authenticated
with check (
  actor_user_id = (select auth.uid())
  and public.is_active_role(array['student', 'teacher', 'admin', 'superadmin'])
);

drop policy if exists audit_logs_update_protect on public.audit_logs;
create policy audit_logs_update_protect on public.audit_logs
for update to authenticated
using (false)
with check (false);

drop policy if exists audit_logs_delete_protect on public.audit_logs;
create policy audit_logs_delete_protect on public.audit_logs
for delete to authenticated
using (false);

create or replace function public.log_audit_event(
  p_action text,
  p_description text default null,
  p_target_user_id uuid default null,
  p_target_table text default null,
  p_target_record_id text default null,
  p_metadata jsonb default '{}'::jsonb
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_id uuid := (select auth.uid());
  v_role text;
  v_id uuid;
begin
  if v_actor_id is null then
    raise exception 'Audit actor tidak tersedia.';
  end if;

  if nullif(trim(coalesce(p_action, '')), '') is null then
    raise exception 'Audit action wajib diisi.';
  end if;

  select role into v_role
  from public.profiles
  where id = v_actor_id and status = 'active';

  if v_role is null then
    v_role := 'unknown';
  end if;

  insert into public.audit_logs (
    actor_user_id,
    actor_role,
    action,
    target_user_id,
    target_table,
    target_record_id,
    description,
    metadata
  ) values (
    v_actor_id,
    v_role,
    trim(p_action),
    p_target_user_id,
    p_target_table,
    p_target_record_id,
    p_description,
    coalesce(p_metadata, '{}'::jsonb)
  ) returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.log_audit_event(text, text, uuid, text, text, jsonb) to authenticated;

create or replace function public.resolve_username_email(p_username text)
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p.email::text
  from public.profiles p
  where p.username is not null
    and lower(p.username) = lower(trim(p_username))
    and p.status = 'active'
  limit 1;
$$;

grant execute on function public.resolve_username_email(text) to anon, authenticated;

create or replace function public.update_user_role(
  p_user_id uuid,
  p_new_role text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_caller_role text;
  v_target_old_role text;
  v_target_email text;
begin
  select role into v_caller_role
  from public.profiles
  where id = (select auth.uid()) and status = 'active';

  if v_caller_role <> 'superadmin' then
    raise exception 'Hanya superadmin yang dapat mengubah role user.';
  end if;

  if p_new_role not in ('student', 'teacher', 'admin') then
    raise exception 'Role tujuan tidak valid: %', p_new_role;
  end if;

  select role, email into v_target_old_role, v_target_email
  from public.profiles
  where id = p_user_id;

  if v_target_old_role is null then
    raise exception 'User tidak ditemukan.';
  end if;

  if v_target_old_role = 'superadmin' then
    raise exception 'Role superadmin tidak boleh diubah.';
  end if;

  update public.profiles
  set role = p_new_role, updated_at = now()
  where id = p_user_id;

  perform public.log_audit_event(
    'ROLE_CHANGED',
    format('Perubahan role user %s dari %s menjadi %s', v_target_email, v_target_old_role, p_new_role),
    p_user_id,
    'profiles',
    p_user_id::text,
    jsonb_build_object('old_role', v_target_old_role, 'new_role', p_new_role)
  );
end;
$$;

grant execute on function public.update_user_role(uuid, text) to authenticated;
