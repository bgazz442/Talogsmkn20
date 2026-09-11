-- Complete the remaining project setup: classes, assignments, storage, and active-only RLS.

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  department_id uuid not null references public.departments(id) on delete cascade,
  name text not null,
  grade_level integer not null check (grade_level between 10 and 12),
  created_at timestamptz not null default now(),
  unique (department_id, name)
);

create table if not exists public.teacher_classes (
  teacher_id uuid not null references public.teachers(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  primary key (teacher_id, class_id)
);

create table if not exists public.student_classes (
  student_id uuid primary key references public.students(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete restrict
);

alter table public.todos
  add column if not exists class_id uuid references public.classes(id) on delete set null;

create table if not exists public.task_assignments (
  todo_id uuid not null references public.todos(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  primary key (todo_id, class_id)
);

insert into public.classes (department_id, name, grade_level)
select departments.id, seed.class_name, seed.grade_level
from (values
  ('RPL', 'RPL X', 10), ('RPL', 'RPL XI', 11), ('RPL', 'RPL XII', 12),
  ('BD', 'BD X', 10), ('BD', 'BD XI', 11), ('BD', 'BD XII', 12),
  ('TJKT', 'TJKT X', 10), ('TJKT', 'TJKT XI', 11), ('TJKT', 'TJKT XII', 12),
  ('AKL', 'AKL X', 10), ('AKL', 'AKL XI', 11), ('AKL', 'AKL XII', 12),
  ('ML', 'ML X', 10), ('ML', 'ML XI', 11), ('ML', 'ML XII', 12)
) as seed(department_code, class_name, grade_level)
join public.departments on departments.code = seed.department_code
on conflict (department_id, name) do nothing;

insert into public.todos (name, description, department_id, class_id)
select
  'Tugas pengenalan kelas',
  'Buat ringkasan profil dan tujuan belajar kelas.',
  departments.id,
  classes.id
from public.departments
join public.classes on classes.department_id = departments.id and classes.name = 'RPL X'
where departments.code = 'RPL'
  and not exists (
    select 1 from public.todos where name = 'Tugas pengenalan kelas'
  );

insert into public.task_assignments (todo_id, class_id)
select todos.id, classes.id
from public.todos
join public.classes on classes.name = 'RPL X'
join public.departments on departments.id = classes.department_id and departments.code = 'RPL'
where todos.name = 'Tugas pengenalan kelas'
on conflict (todo_id, class_id) do nothing;

-- The bucket is private. Files are accessed through signed URLs only.
insert into storage.buckets (id, name, public)
values ('submissions', 'submissions', false)
on conflict (id) do update set public = false;

alter table public.classes enable row level security;
alter table public.teacher_classes enable row level security;
alter table public.student_classes enable row level security;
alter table public.task_assignments enable row level security;

create or replace function public.current_user_role()
returns text language sql stable security definer set search_path = public
as $$
  select role
  from public.profiles
  where id = auth.uid() and status = 'active'
$$;

drop policy if exists "active users read classes" on public.classes;
create policy "active users read classes" on public.classes
for select to authenticated
using (public.current_user_role() is not null);

drop policy if exists "staff manage classes" on public.classes;
create policy "staff manage classes" on public.classes
for all to authenticated
using (public.current_user_role() in ('admin', 'superadmin'))
with check (public.current_user_role() in ('admin', 'superadmin'));

drop policy if exists "users read permitted teacher classes" on public.teacher_classes;
create policy "users read permitted teacher classes" on public.teacher_classes
for select to authenticated
using (teacher_id = auth.uid() or public.current_user_role() in ('admin', 'superadmin'));

drop policy if exists "staff manage teacher classes" on public.teacher_classes;
create policy "staff manage teacher classes" on public.teacher_classes
for all to authenticated
using (public.current_user_role() in ('admin', 'superadmin'))
with check (public.current_user_role() in ('admin', 'superadmin'));

drop policy if exists "users read permitted student classes" on public.student_classes;
create policy "users read permitted student classes" on public.student_classes
for select to authenticated
using (
  student_id = auth.uid()
  or public.current_user_role() in ('teacher', 'admin', 'superadmin')
);

drop policy if exists "staff manage student classes" on public.student_classes;
create policy "staff manage student classes" on public.student_classes
for all to authenticated
using (public.current_user_role() in ('admin', 'superadmin'))
with check (public.current_user_role() in ('admin', 'superadmin'));

drop policy if exists "users read task assignments" on public.task_assignments;
create policy "users read task assignments" on public.task_assignments
for select to authenticated
using (
  public.current_user_role() in ('admin', 'superadmin')
  or exists (
    select 1 from public.student_classes sc
    where sc.student_id = auth.uid() and sc.class_id = task_assignments.class_id
  )
  or exists (
    select 1 from public.teacher_classes tc
    where tc.teacher_id = auth.uid() and tc.class_id = task_assignments.class_id
  )
);

drop policy if exists "staff manage task assignments" on public.task_assignments;
create policy "staff manage task assignments" on public.task_assignments
for all to authenticated
using (public.current_user_role() in ('teacher', 'admin', 'superadmin'))
with check (public.current_user_role() in ('teacher', 'admin', 'superadmin'));

-- Replace broad profile and task access with active-account checks.
drop policy if exists "users read own profile" on public.profiles;
create policy "users read own profile" on public.profiles
for select to authenticated
using (
  (id = auth.uid() and status = 'active')
  or public.current_user_role() in ('admin', 'superadmin')
);

drop policy if exists "signed in users read todos" on public.todos;
create policy "signed in users read todos" on public.todos
for select to authenticated
using (
  public.current_user_role() in ('admin', 'superadmin')
  or assigned_to = auth.uid()
  or (
    public.current_user_role() = 'student'
    and (
      exists (
        select 1 from public.student_classes sc
        where sc.student_id = auth.uid() and sc.class_id = public.todos.class_id
      )
      or exists (
        select 1 from public.students s
        where s.id = auth.uid() and s.department_id = public.todos.department_id
      )
    )
  )
  or (
    public.current_user_role() = 'teacher'
    and (
      exists (
        select 1 from public.teacher_classes tc
        where tc.teacher_id = auth.uid() and tc.class_id = public.todos.class_id
      )
      or exists (
        select 1 from public.teachers t
        where t.id = auth.uid() and t.department_id = public.todos.department_id
      )
    )
  )
);

-- Private submission storage: students upload only to their own folder;
-- staff can read files after authentication.
drop policy if exists "students upload own submissions" on storage.objects;
create policy "students upload own submissions" on storage.objects
for insert to authenticated
with check (
  bucket_id = 'submissions'
  and (storage.foldername(name))[1] = auth.uid()::text
  and public.current_user_role() = 'student'
);

drop policy if exists "active users read submissions" on storage.objects;
create policy "active users read submissions" on storage.objects
for select to authenticated
using (
  bucket_id = 'submissions'
  and public.current_user_role() is not null
);

drop policy if exists "students delete own submissions" on storage.objects;
create policy "students delete own submissions" on storage.objects
for delete to authenticated
using (
  bucket_id = 'submissions'
  and (storage.foldername(name))[1] = auth.uid()::text
  and public.current_user_role() = 'student'
);
