-- Harden staff provisioning, invitations, indexes, master data, and RLS.
-- This migration is additive and intentionally does not create users or delete data.

alter table public.invitations
  add column if not exists expires_at timestamptz,
  add column if not exists accepted_at timestamptz,
  add column if not exists token_hash text,
  add column if not exists accepted_by uuid references auth.users(id);

update public.invitations
set expires_at = coalesce(expires_at, created_at + interval '7 days')
where expires_at is null;

alter table public.invitations
  alter column expires_at set default (now() + interval '7 days');

create unique index if not exists invitations_token_hash_unique_idx
  on public.invitations (token_hash)
  where token_hash is not null;
create unique index if not exists invitations_pending_email_unique_idx
  on public.invitations (internal_email)
  where status = 'pending';
create unique index if not exists invitations_pending_personal_email_unique_idx
  on public.invitations (personal_email)
  where status = 'pending';
create unique index if not exists teachers_personal_email_unique_idx
  on public.teachers (personal_email)
  where personal_email is not null;
create unique index if not exists admins_personal_email_unique_idx
  on public.admins (personal_email)
  where personal_email is not null;
create index if not exists invitations_status_idx on public.invitations (status);
create index if not exists invitations_personal_email_idx on public.invitations (personal_email);
create index if not exists invitations_internal_email_idx on public.invitations (internal_email);
create index if not exists invitations_invited_by_idx on public.invitations (invited_by);
create index if not exists invitations_department_id_idx on public.invitations (department_id);

create index if not exists profiles_role_idx on public.profiles (role);
create index if not exists profiles_status_idx on public.profiles (status);
create index if not exists students_department_id_idx on public.students (department_id);
create index if not exists teachers_department_id_idx on public.teachers (department_id);
create index if not exists todos_assigned_to_idx on public.todos (assigned_to);
create index if not exists todos_department_id_idx on public.todos (department_id);
create index if not exists submissions_student_id_idx on public.submissions (student_id);
create index if not exists submissions_todo_id_idx on public.submissions (todo_id);
create index if not exists grades_teacher_id_idx on public.grades (teacher_id);
create index if not exists grades_submission_id_idx on public.grades (submission_id);
create index if not exists teacher_classes_class_id_idx on public.teacher_classes (class_id);
create index if not exists student_classes_class_id_idx on public.student_classes (class_id);
create index if not exists task_assignments_class_id_idx on public.task_assignments (class_id);
create index if not exists todos_class_id_idx on public.todos (class_id);

insert into public.departments (code, name)
values
  ('RPL', 'Rekayasa Perangkat Lunak'),
  ('BD', 'Bisnis Digital'),
  ('BR', 'Bisnis Retail'),
  ('AKL', 'Akuntansi'),
  ('LPS', 'Layanan Perbankan Syariah'),
  ('MP', 'Manajemen Perkantoran'),
  ('ML', 'Manajemen Logistik')
on conflict (code) do update set name = excluded.name;

insert into public.classes (department_id, name, grade_level)
select d.id, seed.class_name, seed.grade_level
from (values
  ('RPL', 'RPL X', 10), ('RPL', 'RPL XI', 11), ('RPL', 'RPL XII', 12),
  ('BD', 'BD X', 10), ('BD', 'BD XI', 11), ('BD', 'BD XII', 12),
  ('BR', 'BR X', 10), ('BR', 'BR XI', 11), ('BR', 'BR XII', 12),
  ('AKL', 'AKL X', 10), ('AKL', 'AKL XI', 11), ('AKL', 'AKL XII', 12),
  ('LPS', 'LPS X', 10), ('LPS', 'LPS XI', 11), ('LPS', 'LPS XII', 12),
  ('MP', 'MP X', 10), ('MP', 'MP XI', 11), ('MP', 'MP XII', 12),
  ('ML', 'ML X', 10), ('ML', 'ML XI', 11), ('ML', 'ML XII', 12),
  ('TJKT', 'TJKT X', 10), ('TJKT', 'TJKT XI', 11), ('TJKT', 'TJKT XII', 12)
) as seed(department_code, class_name, grade_level)
join public.departments d on d.code = seed.department_code
on conflict (department_id, name) do nothing;

create or replace function public.current_user_role()
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p.role
  from public.profiles as p
  where p.id = (select auth.uid())
    and p.status = 'active'
$$;

create or replace function public.is_active_role(required_roles text[])
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(public.current_user_role() = any(required_roles), false)
$$;

create or replace function public.validate_staff_profile_role()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.role = 'admin' and exists (select 1 from public.teachers where id = new.id) then
    raise exception 'A profile cannot be both admin and teacher';
  end if;
  if new.role = 'teacher' and exists (select 1 from public.admins where id = new.id) then
    raise exception 'A profile cannot be both teacher and admin';
  end if;
  if new.role in ('student', 'superadmin')
     and (exists (select 1 from public.admins where id = new.id)
       or exists (select 1 from public.teachers where id = new.id)) then
    raise exception 'The profile role does not match its staff record';
  end if;
  return new;
end;
$$;

create or replace function public.prevent_protected_role_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if old.role = 'superadmin' and new.role <> old.role then
    raise exception 'The superadmin role cannot be changed';
  end if;
  if (select auth.uid()) is not null and new.role <> old.role then
    raise exception 'Profile roles cannot be changed by a user session';
  end if;
  return new;
end;
$$;

drop trigger if exists validate_staff_profile_role on public.profiles;
create trigger validate_staff_profile_role
before insert or update of id, role on public.profiles
for each row execute function public.validate_staff_profile_role();
drop trigger if exists prevent_protected_role_change on public.profiles;
create trigger prevent_protected_role_change
before update of role on public.profiles
for each row execute function public.prevent_protected_role_change();

create or replace function public.validate_admin_record_role()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not exists (select 1 from public.profiles where id = new.id and role = 'admin') then
    raise exception 'Admin record requires an admin profile';
  end if;
  return new;
end;
$$;

drop trigger if exists validate_admin_record_role on public.admins;
create trigger validate_admin_record_role
before insert or update of id on public.admins
for each row execute function public.validate_admin_record_role();

create or replace function public.validate_teacher_record_role()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not exists (select 1 from public.profiles where id = new.id and role = 'teacher') then
    raise exception 'Teacher record requires a teacher profile';
  end if;
  return new;
end;
$$;

drop trigger if exists validate_teacher_record_role on public.teachers;
create trigger validate_teacher_record_role
before insert or update of id on public.teachers
for each row execute function public.validate_teacher_record_role();

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('student', 'teacher', 'admin', 'superadmin'));
alter table public.profiles drop constraint if exists profiles_status_check;
alter table public.profiles add constraint profiles_status_check
  check (status in ('pending', 'active', 'disabled'));
alter table public.invitations drop constraint if exists invitations_status_check;
alter table public.invitations add constraint invitations_status_check
  check (status in ('pending', 'accepted', 'revoked'));
alter table public.invitations drop constraint if exists invitations_accepted_once_check;
alter table public.invitations add constraint invitations_accepted_once_check
  check ((status = 'accepted') = (accepted_at is not null and accepted_by is not null));

revoke all on function public.resolve_login_email(text) from anon, authenticated;
revoke all on function public.validate_staff_profile_role() from public, anon, authenticated;
revoke all on function public.validate_admin_record_role() from public, anon, authenticated;
revoke all on function public.validate_teacher_record_role() from public, anon, authenticated;
revoke all on function public.prevent_protected_role_change() from public, anon, authenticated;
revoke all on function public.is_active_role(text[]) from anon;
grant execute on function public.current_user_role() to authenticated;
grant execute on function public.is_active_role(text[]) to authenticated;

alter table public.departments enable row level security;
alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.teachers enable row level security;
alter table public.admins enable row level security;
alter table public.invitations enable row level security;
alter table public.todos enable row level security;
alter table public.submissions enable row level security;
alter table public.grades enable row level security;
-- Remove earlier broad policies before installing the least-privilege policy set.
do $$
declare policy_record record;
begin
  for policy_record in
    select policyname, tablename
    from pg_policies
    where schemaname = 'public'
      and tablename in ('departments', 'profiles', 'students', 'teachers', 'admins', 'invitations',
                        'todos', 'submissions', 'grades')
  loop
    execute format('drop policy if exists %I on public.%I', policy_record.policyname, policy_record.tablename);
  end loop;
end;
$$;

create policy departments_read_authenticated on public.departments
for select to authenticated using (public.current_user_role() is not null);
create policy profiles_read_own_or_superadmin on public.profiles
for select to authenticated using (id = (select auth.uid()) or public.is_active_role(array['superadmin']));
create policy profiles_update_own_safe_fields on public.profiles
for update to authenticated
using (id = (select auth.uid()) and status = 'active')
with check (id = (select auth.uid()) and role = public.current_user_role() and status = 'active');
create policy superadmin_update_staff_status on public.profiles
for update to authenticated
using (public.is_active_role(array['superadmin']) and role in ('admin', 'teacher'))
with check (public.is_active_role(array['superadmin']) and role in ('admin', 'teacher'));
create policy admin_update_teacher_status on public.profiles
for update to authenticated
using (public.is_active_role(array['admin']) and role = 'teacher')
with check (public.is_active_role(array['admin']) and role = 'teacher');
create policy students_read_own_or_staff on public.students
for select to authenticated using (id = (select auth.uid()) or public.is_active_role(array['teacher','admin','superadmin']));
create policy teachers_read_self_or_staff on public.teachers
for select to authenticated using (id = (select auth.uid()) or public.is_active_role(array['admin','superadmin']));
create policy admins_read_self_or_superadmin on public.admins
for select to authenticated using (id = (select auth.uid()) or public.is_active_role(array['superadmin']));
create policy invitations_read_own_or_managers on public.invitations
for select to authenticated using (invited_by = (select auth.uid()) or public.is_active_role(array['superadmin']));
create policy invitations_manager_update on public.invitations
for update to authenticated using (public.is_active_role(array['admin','superadmin']))
with check (public.is_active_role(array['admin','superadmin']));

create policy todos_read_permitted on public.todos
for select to authenticated using (
  public.is_active_role(array['admin','superadmin'])
  or assigned_to = (select auth.uid())
  or (public.current_user_role() = 'student' and exists (
    select 1 from public.student_classes sc
    where sc.student_id = (select auth.uid()) and sc.class_id = todos.class_id
  ))
  or (public.current_user_role() = 'teacher' and exists (
    select 1 from public.teacher_classes tc
    where tc.teacher_id = (select auth.uid())
      and (tc.class_id = todos.class_id or tc.class_id is not distinct from todos.class_id)
  ))
);
create policy todos_manage_staff on public.todos
for all to authenticated
using (
  public.is_active_role(array['admin','superadmin'])
  or (
    public.current_user_role() = 'teacher'
    and exists (
      select 1 from public.teachers t
      where t.id = (select auth.uid())
        and (t.department_id = todos.department_id or exists (
          select 1 from public.teacher_classes tc
          where tc.teacher_id = t.id and tc.class_id = todos.class_id
        ))
    )
  )
)
with check (
  public.is_active_role(array['admin','superadmin'])
  or (
    public.current_user_role() = 'teacher'
    and exists (
      select 1 from public.teachers t
      where t.id = (select auth.uid())
        and (t.department_id = todos.department_id or exists (
          select 1 from public.teacher_classes tc
          where tc.teacher_id = t.id and tc.class_id = todos.class_id
        ))
    )
  )
);
create policy submissions_read_permitted on public.submissions
for select to authenticated using (
  student_id = (select auth.uid())
  or public.is_active_role(array['admin','superadmin'])
  or (
    public.current_user_role() = 'teacher'
    and exists (
      select 1 from public.todos todo
      join public.teachers t on t.id = (select auth.uid())
      where todo.id = submissions.todo_id
        and (t.department_id = todo.department_id or exists (
          select 1 from public.teacher_classes tc
          where tc.teacher_id = t.id and tc.class_id = todo.class_id
        ))
    )
  )
);
create policy submissions_student_write_own on public.submissions
for insert to authenticated with check (student_id = (select auth.uid()) and public.current_user_role() = 'student');
create policy submissions_student_update_own on public.submissions
for update to authenticated using (student_id = (select auth.uid()) and public.current_user_role() = 'student')
with check (student_id = (select auth.uid()) and public.current_user_role() = 'student');
create policy grades_read_permitted on public.grades
for select to authenticated using (
  (teacher_id = (select auth.uid()) and public.current_user_role() = 'teacher')
  or public.is_active_role(array['admin','superadmin'])
  or exists (select 1 from public.submissions s where s.id = submission_id and s.student_id = (select auth.uid()))
);
create policy grades_teacher_write on public.grades
for all to authenticated
using (
  public.is_active_role(array['admin','superadmin'])
  or (
    teacher_id = (select auth.uid())
    and exists (
      select 1
      from public.submissions s
      join public.todos todo on todo.id = s.todo_id
      join public.teachers t on t.id = (select auth.uid())
      where s.id = grades.submission_id
        and (t.department_id = todo.department_id or exists (
          select 1 from public.teacher_classes tc
          where tc.teacher_id = t.id and tc.class_id = todo.class_id
        ))
    )
  )
)
with check (
  public.is_active_role(array['admin','superadmin'])
  or (
    teacher_id = (select auth.uid())
    and exists (
      select 1
      from public.submissions s
      join public.todos todo on todo.id = s.todo_id
      join public.teachers t on t.id = (select auth.uid())
      where s.id = grades.submission_id
        and (t.department_id = todo.department_id or exists (
          select 1 from public.teacher_classes tc
          where tc.teacher_id = t.id and tc.class_id = todo.class_id
        ))
    )
  )
);
revoke all on table public.profiles, public.teachers, public.admins, public.students, public.invitations from anon;
revoke all on table public.profiles, public.teachers, public.admins, public.students, public.invitations from authenticated;
grant select, update on public.profiles to authenticated;
grant select on public.teachers, public.admins, public.students, public.invitations to authenticated;
grant update on public.invitations to authenticated;
revoke insert, delete on public.profiles, public.teachers, public.admins, public.students, public.invitations from authenticated;
