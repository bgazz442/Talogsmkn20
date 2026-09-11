-- Read-only checks for the staff security setup.
-- Run the assertions in the Supabase SQL editor after applying all migrations.
-- This file does not create users or insert application data.

begin;

-- No anonymous table access to sensitive identity and academic records.
do $$
begin
  if has_table_privilege('anon', 'public.profiles', 'select') then
    raise exception 'anon still has SELECT on profiles';
  end if;
  if has_table_privilege('anon', 'public.teachers', 'select') then
    raise exception 'anon still has SELECT on teachers';
  end if;
  if has_table_privilege('anon', 'public.admins', 'select') then
    raise exception 'anon still has SELECT on admins';
  end if;
  if has_table_privilege('anon', 'public.students', 'select') then
    raise exception 'anon still has SELECT on students';
  end if;
  if has_table_privilege('anon', 'public.invitations', 'select') then
    raise exception 'anon still has SELECT on invitations';
  end if;
end;
$$;

-- Internal role helpers must not be executable by anonymous callers.
do $$
begin
  if has_function_privilege('anon', 'public.current_user_role()', 'execute') then
    raise exception 'anon still has EXECUTE on current_user_role';
  end if;
  if has_function_privilege('anon', 'public.resolve_login_email(text)', 'execute') then
    raise exception 'anon still has EXECUTE on resolve_login_email';
  end if;
end;
$$;

-- Required constraints and indexes exist.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'profiles_role_check') then raise exception 'profiles role check missing'; end if;
  if not exists (select 1 from pg_constraint where conname = 'profiles_status_check') then raise exception 'profiles status check missing'; end if;
  if not exists (select 1 from pg_constraint where conname = 'invitations_accepted_once_check') then raise exception 'invitation accepted-once check missing'; end if;
  if to_regclass('public.invitations_pending_email_unique_idx') is null then raise exception 'pending invitation unique index missing'; end if;
  if to_regclass('public.profiles_role_idx') is null then raise exception 'profiles role index missing'; end if;
end;
$$;

rollback;

-- Manual authenticated scenarios (replace UUIDs with real test users; never use production users):
-- 1. POST /functions/v1/manage-staff as student with role=teacher -> 403.
-- 2. POST as teacher with role=admin -> 403.
-- 3. POST as admin with role=admin -> 403.
-- 4. POST as admin with role=teacher and valid department_id -> 201.
-- 5. POST as superadmin with role=admin -> 201.
-- 6. POST as superadmin with role=teacher and valid department_id -> 201.
-- 7. Repeat an existing pending internal_email -> 409.
-- 8. Use an unknown department_id -> 400.
-- 9. POST /functions/v1/manage-staff/accept with an expired/revoked token -> 410.
-- 10. Attempt to update profiles.role to superadmin from a normal user session -> RLS denial.
-- 11. Set request.jwt.claims to a student JWT and select another student's grades -> zero rows.
-- 12. Set request.jwt.claims to an anonymous request and select profiles -> permission denied/zero rows.
