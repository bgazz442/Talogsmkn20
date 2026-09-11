-- TALOG20: additive security and realtime hardening.
-- This migration does not delete data, users, tables, functions, or roles.

-- Audit entries must be created through log_audit_event so actor fields come from auth.uid().
drop policy if exists audit_logs_insert_authenticated on public.audit_logs;
revoke insert on public.audit_logs from public, anon, authenticated;
grant execute on function public.log_audit_event(text, text, uuid, text, text, jsonb) to authenticated;

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

  select role into v_role
  from public.profiles
  where id = v_actor_id and status = 'active';

  if v_role is null then
    raise exception 'Akun aktif tidak ditemukan.';
  end if;

  if nullif(trim(p_action), '') is null then
    raise exception 'Audit action wajib diisi.';
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

-- A staff account cannot be changed to student without the required student row.
-- Provisioning that row needs real department and student-number data; do not invent either.
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
  if p_new_role = 'student'
     and not exists (select 1 from public.students where id = p_user_id) then
    raise exception 'User belum memiliki data student; lengkapi department dan nomor siswa terlebih dahulu.';
  end if;

  update public.profiles
  set role = p_new_role, updated_at = now()
  where id = p_user_id;

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

-- Restrict client profile updates to fields exposed by AuthService.updateProfile.
revoke update on public.profiles from public, anon, authenticated;
grant update (full_name, username, updated_at) on public.profiles to authenticated;

-- Teachers may manage assignments only for classes they teach; admins retain management access.
drop policy if exists task_assignments_manage_staff on public.task_assignments;
create policy task_assignments_manage_staff on public.task_assignments
for all to authenticated
using (
  public.is_active_role(array['admin', 'superadmin'])
  or (
    public.current_user_role() = 'teacher'
    and exists (
      select 1 from public.teacher_classes tc
      where tc.teacher_id = (select auth.uid())
        and tc.class_id = task_assignments.class_id
    )
  )
)
with check (
  public.is_active_role(array['admin', 'superadmin'])
  or (
    public.current_user_role() = 'teacher'
    and exists (
      select 1 from public.teacher_classes tc
      where tc.teacher_id = (select auth.uid())
        and tc.class_id = task_assignments.class_id
    )
  )
);

-- Ensure the task flow tables are in Supabase Realtime without duplicating publication entries.
do $$
declare
  table_name text;
begin
  foreach table_name in array array['todos', 'submissions', 'grades'] loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format('alter publication supabase_realtime add table public.%I', table_name);
    end if;
  end loop;
end;
$$;
