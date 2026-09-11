-- 202609060002_multi_user_hardening.sql
-- TALog20: Multi-user hardening, username support, audit logs, storage isolation, superadmin management

-- 1. Add username column to public.profiles if not exists
alter table public.profiles
  add column if not exists username citext;

create unique index if not exists profiles_username_unique_idx
  on public.profiles (username)
  where username is not null;

-- 2. Create audit_logs table
create table if not exists public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_user_id uuid references auth.users(id) on delete set null,
  actor_role text not null,
  action text not null,
  target_user_id uuid references auth.users(id) on delete set null,
  target_table text,
  target_record_id text,
  description text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists audit_logs_actor_user_id_idx on public.audit_logs (actor_user_id);
create index if not exists audit_logs_target_user_id_idx on public.audit_logs (target_user_id);
create index if not exists audit_logs_action_idx on public.audit_logs (action);
create index if not exists audit_logs_created_at_idx on public.audit_logs (created_at desc);

-- 3. Audit logs RLS: Only admin and superadmin can read; append-only for authenticated
alter table public.audit_logs enable row level security;

drop policy if exists audit_logs_read_staff on public.audit_logs;
create policy audit_logs_read_staff on public.audit_logs
for select to authenticated
using (public.is_active_role(array['admin', 'superadmin']));

drop policy if exists audit_logs_insert_authenticated on public.audit_logs;
create policy audit_logs_insert_authenticated on public.audit_logs
for insert to authenticated
with check (actor_user_id = (select auth.uid()));

-- Revoke all update and delete on audit_logs (immutable)
revoke update, delete on public.audit_logs from public, anon, authenticated;
grant select, insert on public.audit_logs to authenticated;

-- 4. Helper function to record audit log securely
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
  v_role text;
  v_id uuid;
begin
  select role into v_role from public.profiles where id = (select auth.uid());
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
    (select auth.uid()),
    v_role,
    p_action,
    p_target_user_id,
    p_target_table,
    p_target_record_id,
    p_description,
    p_metadata
  ) returning id into v_id;

  return v_id;
end;
$$;

grant execute on function public.log_audit_event(text, text, uuid, text, text, jsonb) to authenticated;

-- 5. Safe username resolution for login (strictly returns email only for an exact username match)
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

revoke all on function public.resolve_username_email(text) from public;
grant execute on function public.resolve_username_email(text) to anon, authenticated;

-- 6. Superadmin User Management: update_user_role RPC
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
  -- Validate caller is superadmin
  select role into v_caller_role
  from public.profiles
  where id = (select auth.uid()) and status = 'active';

  if v_caller_role <> 'superadmin' then
    raise exception 'Hanya superadmin yang dapat mengubah role user.';
  end if;

  -- Validate target role
  if p_new_role not in ('student', 'teacher', 'admin') then
    raise exception 'Role tujuan tidak valid: %', p_new_role;
  end if;

  -- Validate target user
  select role, email into v_target_old_role, v_target_email
  from public.profiles
  where id = p_user_id;

  if v_target_old_role is null then
    raise exception 'User tidak ditemukan.';
  end if;

  if v_target_old_role = 'superadmin' then
    raise exception 'Role superadmin tidak boleh diubah.';
  end if;

  -- Update role
  update public.profiles
  set role = p_new_role, updated_at = now()
  where id = p_user_id;

  -- Maintain teacher / admin / student sub-tables if needed
  if p_new_role = 'teacher' and not exists (select 1 from public.teachers where id = p_user_id) then
    delete from public.admins where id = p_user_id;
    insert into public.teachers (id) values (p_user_id) on conflict do nothing;
  elsif p_new_role = 'admin' and not exists (select 1 from public.admins where id = p_user_id) then
    delete from public.teachers where id = p_user_id;
    insert into public.admins (id) values (p_user_id) on conflict do nothing;
  elsif p_new_role = 'student' then
    delete from public.teachers where id = p_user_id;
    delete from public.admins where id = p_user_id;
  end if;

  -- Log role change in audit_logs
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

revoke all on function public.update_user_role(uuid, text) from public;
grant execute on function public.update_user_role(uuid, text) to authenticated;

-- 7. Update prevent_protected_role_change trigger to allow superadmin via RPC or direct update,
-- while completely protecting superadmin role from any demotion or unauthorized escalation.
create or replace function public.prevent_protected_role_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_caller_role text;
begin
  if old.role = 'superadmin' and new.role <> 'superadmin' then
    raise exception 'The superadmin role cannot be changed';
  end if;

  if (select auth.uid()) is not null and new.role <> old.role then
    select role into v_caller_role
    from public.profiles
    where id = (select auth.uid()) and status = 'active';

    if v_caller_role <> 'superadmin' then
      raise exception 'Profile roles cannot be changed by non-superadmin session';
    end if;

    if new.role = 'superadmin' then
      raise exception 'Cannot escalate any account to superadmin via client session';
    end if;
  end if;
  return new;
end;
$$;

-- 8. Bootstrap abubangkir@gmail.com as superadmin if existing
update public.profiles
set role = 'superadmin', status = 'active'
where email = 'abubangkir@gmail.com';

-- 9. Update handle_new_user() trigger to automatically assign superadmin to abubangkir@gmail.com
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  department public.departments;
  user_role text := 'student';
begin
  -- Bootstrap initial superadmin by configured primary email
  if lower(trim(new.email)) = 'abubangkir@gmail.com' then
    user_role := 'superadmin';
    insert into public.profiles (id, email, full_name, role, status)
    values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', 'Super Admin'), 'superadmin', 'active')
    on conflict (id) do update set role = 'superadmin', status = 'active';
    return new;
  end if;

  -- Staff and other accounts: default role is student
  select * into department from public.departments
    where code = upper(coalesce(new.raw_user_meta_data->>'department_code', ''));

  insert into public.profiles (id, email, full_name, role, status)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''), 'student', 'active')
  on conflict (id) do nothing;

  if department.id is not null and (new.raw_user_meta_data->>'student_number') is not null then
    insert into public.students (id, department_id, student_number)
    values (new.id, department.id, (new.raw_user_meta_data->>'student_number')::integer)
    on conflict do nothing;
  end if;

  return new;
end;
$$;

-- 10. Storage RLS Hardening: Fix critical vulnerability where students could read other students' files
-- Remove broad "active users read submissions"
drop policy if exists "active users read submissions" on storage.objects;
drop policy if exists "submissions_read_isolated" on storage.objects;

-- Staff (teacher, admin, superadmin) can read all submissions
create policy "submissions_read_staff" on storage.objects
for select to authenticated
using (
  bucket_id = 'submissions'
  and public.is_active_role(array['teacher', 'admin', 'superadmin'])
);

-- Students can ONLY read their own folder: submissions/<auth.uid()>/...
create policy "submissions_read_own_student" on storage.objects
for select to authenticated
using (
  bucket_id = 'submissions'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- 11. Allow user to update their own profile username and full_name
drop policy if exists profiles_update_own_safe_fields on public.profiles;
create policy profiles_update_own_safe_fields on public.profiles
for update to authenticated
using (id = (select auth.uid()) and status = 'active')
with check (id = (select auth.uid()) and role = public.current_user_role() and status = 'active');
