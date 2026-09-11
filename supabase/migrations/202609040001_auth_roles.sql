create extension if not exists citext;

create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  code citext not null unique,
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email citext not null unique,
  full_name text not null,
  role text not null default 'student' check (role in ('student', 'teacher', 'admin', 'superadmin')),
  status text not null default 'active' check (status in ('pending', 'active', 'disabled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.students (
  id uuid primary key references public.profiles(id) on delete cascade,
  department_id uuid not null references public.departments(id),
  student_number integer not null check (student_number > 0),
  unique (department_id, student_number)
);

create table if not exists public.teachers (
  id uuid primary key references public.profiles(id) on delete cascade,
  department_id uuid references public.departments(id),
  personal_email citext,
  internal_email citext unique
);

create table if not exists public.admins (
  id uuid primary key references public.profiles(id) on delete cascade,
  admin_number bigint generated always as identity unique,
  personal_email citext,
  internal_email citext unique
);

alter table public.admins
  add column if not exists internal_email citext;

create unique index if not exists admins_internal_email_unique_idx
  on public.admins (internal_email)
  where internal_email is not null;

create table if not exists public.invitations (
  id uuid primary key default gen_random_uuid(),
  personal_email citext not null,
  internal_email citext not null,
  role text not null check (role in ('teacher', 'admin')),
  department_id uuid references public.departments(id),
  invited_by uuid not null references public.profiles(id),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'revoked')),
  created_at timestamptz not null default now(),
  accepted_at timestamptz
);

create or replace function public.current_user_role()
returns text language sql stable security definer set search_path = public
as $$ select role from public.profiles where id = auth.uid() $$;

create or replace function public.resolve_login_email(login_name text)
returns text language sql stable security definer set search_path = public
as $$ select email::text from public.profiles where lower(full_name) = lower(trim(login_name)) limit 1 $$;

revoke all on function public.resolve_login_email(text) from public;
grant execute on function public.resolve_login_email(text) to anon, authenticated;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
declare department public.departments;
begin
  -- Staff and superadmin accounts are provisioned manually by a privileged operator.
  if coalesce(new.raw_user_meta_data->>'role', 'student') <> 'student' then
    return new;
  end if;
  select * into department from public.departments
    where code = upper(new.raw_user_meta_data->>'department_code');
  if department.id is null then raise exception 'Kode kelas atau jurusan tidak valid.'; end if;
  insert into public.profiles (id, email, full_name, role, status)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', ''), 'student', 'active');
  insert into public.students (id, department_id, student_number)
  values (new.id, department.id, (new.raw_user_meta_data->>'student_number')::integer);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.departments enable row level security;
alter table public.profiles enable row level security;
alter table public.students enable row level security;
alter table public.teachers enable row level security;
alter table public.admins enable row level security;
alter table public.invitations enable row level security;

drop policy if exists "departments readable by signed in users" on public.departments;
create policy "departments readable by signed in users" on public.departments
for select to authenticated using (true);
drop policy if exists "users read own profile" on public.profiles;
create policy "users read own profile" on public.profiles
for select to authenticated using (id = auth.uid() or public.current_user_role() in ('admin', 'superadmin'));
drop policy if exists "students read own record" on public.students;
create policy "students read own record" on public.students
for select to authenticated using (id = auth.uid() or public.current_user_role() in ('teacher', 'admin', 'superadmin'));
drop policy if exists "staff read teachers" on public.teachers;
create policy "staff read teachers" on public.teachers
for select to authenticated using (public.current_user_role() in ('admin', 'superadmin') or id = auth.uid());
drop policy if exists "admins read admins" on public.admins;
create policy "admins read admins" on public.admins
for select to authenticated using (public.current_user_role() = 'superadmin' or id = auth.uid());
drop policy if exists "staff manage invitations" on public.invitations;
create policy "staff manage invitations" on public.invitations
for all to authenticated using (public.current_user_role() in ('admin', 'superadmin'))
with check (public.current_user_role() in ('admin', 'superadmin'));