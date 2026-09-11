-- TALOG20: preserve teacher grading identity while allowing admin grading safely.
-- Existing teacher_id values remain valid; admin/superadmin grades use grader_user_id.

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

drop policy if exists grades_teacher_write on public.grades;
create policy grades_staff_write on public.grades
for all to authenticated
using (
  public.is_active_role(array['admin', 'superadmin'])
  or (
    public.current_user_role() = 'teacher'
    and exists (
      select 1
      from public.submissions s
      join public.todos todo on todo.id = s.todo_id
      join public.teachers t on t.id = (select auth.uid())
      where s.id = grades.submission_id
        and (
          t.department_id = todo.department_id
          or exists (
            select 1 from public.teacher_classes tc
            where tc.teacher_id = t.id and tc.class_id = todo.class_id
          )
        )
    )
  )
)
with check (
  (
    public.is_active_role(array['admin', 'superadmin'])
    and grader_user_id = (select auth.uid())
  )
  or (
    public.current_user_role() = 'teacher'
    and teacher_id = (select auth.uid())
    and exists (
      select 1
      from public.submissions s
      join public.todos todo on todo.id = s.todo_id
      join public.teachers t on t.id = (select auth.uid())
      where s.id = grades.submission_id
        and (
          t.department_id = todo.department_id
          or exists (
            select 1 from public.teacher_classes tc
            where tc.teacher_id = t.id and tc.class_id = todo.class_id
          )
        )
    )
  )
);
