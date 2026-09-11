-- Project data used by the current Flutter dashboard and the next role modules.
create table if not exists public.todos (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  department_id uuid references public.departments(id) on delete set null,
  assigned_to uuid references public.profiles(id) on delete set null,
  due_at timestamptz,
  is_complete boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.submissions (
  id uuid primary key default gen_random_uuid(),
  todo_id uuid not null references public.todos(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  file_url text,
  note text,
  submitted_at timestamptz not null default now(),
  unique (todo_id, student_id)
);

create table if not exists public.grades (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null unique references public.submissions(id) on delete cascade,
  teacher_id uuid not null references public.teachers(id),
  score numeric(5, 2) not null check (score >= 0 and score <= 100),
  feedback text,
  graded_at timestamptz not null default now()
);

alter table public.todos enable row level security;
alter table public.submissions enable row level security;
alter table public.grades enable row level security;

drop policy if exists "signed in users read todos" on public.todos;
create policy "signed in users read todos" on public.todos
for select to authenticated using (
  public.current_user_role() in ('admin', 'superadmin')
  or assigned_to = auth.uid()
  or (
    public.current_user_role() = 'student'
    and exists (
      select 1 from public.students s
      where s.id = auth.uid() and s.department_id = public.todos.department_id
    )
  )
  or (
    public.current_user_role() = 'teacher'
    and exists (
      select 1 from public.teachers t
      where t.id = auth.uid() and t.department_id = public.todos.department_id
    )
  )
);
drop policy if exists "staff manage todos" on public.todos;
create policy "staff manage todos" on public.todos
for all to authenticated using (public.current_user_role() in ('teacher', 'admin', 'superadmin'))
with check (public.current_user_role() in ('teacher', 'admin', 'superadmin'));

drop policy if exists "students manage own submissions" on public.submissions;
create policy "students manage own submissions" on public.submissions
for all to authenticated using (
  student_id = auth.uid() or public.current_user_role() in ('teacher', 'admin', 'superadmin')
)
with check (student_id = auth.uid() or public.current_user_role() in ('teacher', 'admin', 'superadmin'));
drop policy if exists "users read permitted grades" on public.grades;
create policy "users read permitted grades" on public.grades
for select to authenticated using (
  public.current_user_role() in ('teacher', 'admin', 'superadmin')
  or exists (
    select 1 from public.submissions s
    where s.id = submission_id and s.student_id = auth.uid()
  )
);
drop policy if exists "staff manage grades" on public.grades;
create policy "staff manage grades" on public.grades
for all to authenticated using (public.current_user_role() in ('teacher', 'admin', 'superadmin'))
with check (public.current_user_role() in ('teacher', 'admin', 'superadmin'));

insert into public.departments (code, name)
values
  ('RPL', 'Rekayasa Perangkat Lunak'),
  ('BD', 'Bisnis Daring'),
  ('TJKT', 'Teknik Jaringan Komputer dan Telekomunikasi'),
  ('AKL', 'Akuntansi dan Keuangan Lembaga'),
  ('ML', 'Manajemen Logistik')
on conflict (code) do update set name = excluded.name;

insert into public.todos (name, description, department_id)
select seed.name, seed.description, departments.id
from (values
  ('Final Project - Website Portfolio', 'Bangun dan dokumentasikan website portfolio.', 'RPL'),
  ('Dokumentasi dan laporan akhir', 'Lengkapi laporan dan dokumentasi tugas akhir.', 'RPL'),
  ('Presentasi proyek kelas', 'Siapkan materi presentasi proyek.', 'BD')
) as seed(name, description, department_code)
join public.departments on departments.code = seed.department_code
where not exists (
  select 1 from public.todos existing where existing.name = seed.name
);