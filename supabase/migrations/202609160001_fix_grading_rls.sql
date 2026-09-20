-- Migration: Fix RLS policies for table public.grades and public.submissions
-- Allows authorized teachers and admins to grade student submissions securely without disabling RLS.

-- 1. Ensure columns and constraints are sound on public.grades
alter table public.grades
  add column if not exists grader_user_id uuid references public.profiles(id) on delete set null;

alter table public.grades
  alter column teacher_id drop not null;

alter table public.grades drop constraint if exists grades_actor_check;
alter table public.grades
  add constraint grades_actor_check
  check (teacher_id is not null or grader_user_id is not null);

create index if not exists grades_grader_user_id_idx
  on public.grades (grader_user_id);

-- 2. Drop old policies on public.grades
drop policy if exists grades_teacher_write on public.grades;
drop policy if exists grades_staff_write on public.grades;
drop policy if exists grades_read_permitted on public.grades;
drop policy if exists "users read permitted grades" on public.grades;
drop policy if exists "staff manage grades" on public.grades;

-- 3. Create sound SELECT policy on public.grades
create policy grades_read_permitted on public.grades
for select to authenticated using (
  public.is_active_role(array['admin', 'superadmin'])
  or (
    coalesce(grader_user_id, teacher_id) = (select auth.uid())
    or grader_user_id = (select auth.uid())
    or teacher_id = (select auth.uid())
  )
  or exists (
    select 1
    from public.submissions s
    where s.id = grades.submission_id
      and s.student_id = (select auth.uid())
  )
  or (
    public.current_user_role() = 'teacher'
    and exists (
      select 1
      from public.submissions s
      join public.todos todo on todo.id = s.todo_id
      left join public.teachers t on t.id = (select auth.uid())
      where s.id = grades.submission_id
        and (
          todo.assigned_to = (select auth.uid())
          or (t.department_id is not null and t.department_id = todo.department_id)
        )
    )
  )
);

-- 4. Create secure INSERT / UPDATE / ALL policy on public.grades
create policy grades_staff_write on public.grades
for all to authenticated
using (
  public.is_active_role(array['admin', 'superadmin'])
  or (
    public.current_user_role() = 'teacher'
    and (
      coalesce(grader_user_id, teacher_id) = (select auth.uid())
      or grader_user_id = (select auth.uid())
      or teacher_id = (select auth.uid())
      or exists (
        select 1
        from public.submissions s
        join public.todos todo on todo.id = s.todo_id
        left join public.teachers t on t.id = (select auth.uid())
        where s.id = grades.submission_id
          and (
            todo.assigned_to = (select auth.uid())
            or (t.department_id is not null and t.department_id = todo.department_id)
          )
      )
    )
  )
)
with check (
  (
    public.is_active_role(array['admin', 'superadmin'])
    and (grader_user_id = (select auth.uid()) or teacher_id = (select auth.uid()))
  )
  or (
    public.current_user_role() = 'teacher'
    and (grader_user_id = (select auth.uid()) or teacher_id = (select auth.uid()))
    and exists (
      select 1
      from public.submissions s
      join public.todos todo on todo.id = s.todo_id
      left join public.teachers t on t.id = (select auth.uid())
      where s.id = grades.submission_id
        and (
          todo.assigned_to = (select auth.uid())
          or (t.department_id is not null and t.department_id = todo.department_id)
        )
    )
  )
);

-- 5. Submissions update policy for teachers/staff when marking graded
drop policy if exists submissions_staff_update on public.submissions;
create policy submissions_staff_update on public.submissions
for update to authenticated
using (
  public.is_active_role(array['admin', 'superadmin'])
  or (
    public.current_user_role() = 'teacher'
    and exists (
      select 1
      from public.todos todo
      left join public.teachers t on t.id = (select auth.uid())
      where todo.id = submissions.todo_id
        and (
          todo.assigned_to = (select auth.uid())
          or (t.department_id is not null and t.department_id = todo.department_id)
        )
    )
  )
)
with check (
  public.is_active_role(array['admin', 'superadmin'])
  or (
    public.current_user_role() = 'teacher'
    and exists (
      select 1
      from public.todos todo
      left join public.teachers t on t.id = (select auth.uid())
      where todo.id = submissions.todo_id
        and (
          todo.assigned_to = (select auth.uid())
          or (t.department_id is not null and t.department_id = todo.department_id)
        )
    )
  )
);
