-- Ensure optional class and assignment tables exist before staff security.
-- This migration creates structure and master class names only; it creates no users.

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
  created_at timestamptz not null default now(),
  primary key (teacher_id, class_id)
);

create table if not exists public.student_classes (
  student_id uuid primary key references public.students(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.task_assignments (
  todo_id uuid not null references public.todos(id) on delete cascade,
  class_id uuid not null references public.classes(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  primary key (todo_id, class_id)
);

alter table public.todos
  add column if not exists class_id uuid references public.classes(id) on delete set null;

create index if not exists classes_department_id_idx on public.classes (department_id);
create index if not exists teacher_classes_class_id_idx on public.teacher_classes (class_id);
create index if not exists student_classes_class_id_idx on public.student_classes (class_id);
create index if not exists task_assignments_class_id_idx on public.task_assignments (class_id);
create index if not exists task_assignments_todo_id_idx on public.task_assignments (todo_id);
create index if not exists todos_class_id_idx on public.todos (class_id);

-- Preserve existing class rows and add only official class master names.
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

alter table public.classes enable row level security;
alter table public.teacher_classes enable row level security;
alter table public.student_classes enable row level security;
alter table public.task_assignments enable row level security;

drop policy if exists classes_read_active on public.classes;
create policy classes_read_active on public.classes
for select to authenticated
using (public.current_user_role() is not null);

drop policy if exists classes_manage_admin on public.classes;
create policy classes_manage_admin on public.classes
for all to authenticated
using (public.current_user_role() in ('admin', 'superadmin'))
with check (public.current_user_role() in ('admin', 'superadmin'));

drop policy if exists teacher_classes_read_permitted on public.teacher_classes;
create policy teacher_classes_read_permitted on public.teacher_classes
for select to authenticated
using (
  teacher_id = (select auth.uid())
  or public.current_user_role() in ('admin', 'superadmin')
);

drop policy if exists teacher_classes_manage_admin on public.teacher_classes;
create policy teacher_classes_manage_admin on public.teacher_classes
for all to authenticated
using (public.current_user_role() in ('admin', 'superadmin'))
with check (public.current_user_role() in ('admin', 'superadmin'));

drop policy if exists student_classes_read_permitted on public.student_classes;
create policy student_classes_read_permitted on public.student_classes
for select to authenticated
using (
  student_id = (select auth.uid())
  or public.current_user_role() in ('teacher', 'admin', 'superadmin')
);

drop policy if exists student_classes_manage_admin on public.student_classes;
create policy student_classes_manage_admin on public.student_classes
for all to authenticated
using (public.current_user_role() in ('admin', 'superadmin'))
with check (public.current_user_role() in ('admin', 'superadmin'));

drop policy if exists task_assignments_read_permitted on public.task_assignments;
create policy task_assignments_read_permitted on public.task_assignments
for select to authenticated
using (
  public.current_user_role() in ('admin', 'superadmin')
  or exists (
    select 1 from public.student_classes sc
    where sc.student_id = (select auth.uid())
      and sc.class_id = task_assignments.class_id
  )
  or exists (
    select 1 from public.teacher_classes tc
    where tc.teacher_id = (select auth.uid())
      and tc.class_id = task_assignments.class_id
  )
);

drop policy if exists task_assignments_manage_staff on public.task_assignments;
create policy task_assignments_manage_staff on public.task_assignments
for all to authenticated
using (public.current_user_role() in ('teacher', 'admin', 'superadmin'))
with check (public.current_user_role() in ('teacher', 'admin', 'superadmin'));
