-- Align task visibility with the admin task form's department_id.
-- Students may see tasks for their department, or tasks assigned to their class.

drop policy if exists todos_read_permitted on public.todos;
create policy todos_read_permitted on public.todos
for select to authenticated using (
  public.is_active_role(array['admin','superadmin'])
  or assigned_to = (select auth.uid())
  or (
    public.current_user_role() = 'student'
    and (
      exists (
        select 1
        from public.students s
        where s.id = (select auth.uid())
          and s.department_id = todos.department_id
      )
      or exists (
        select 1
        from public.student_classes sc
        where sc.student_id = (select auth.uid())
          and sc.class_id = todos.class_id
      )
    )
  )
  or (
    public.current_user_role() = 'teacher'
    and exists (
      select 1
      from public.teachers t
      where t.id = (select auth.uid())
        and (
          t.department_id = todos.department_id
          or exists (
            select 1
            from public.teacher_classes tc
            where tc.teacher_id = t.id
              and (tc.class_id = todos.class_id or tc.class_id is not distinct from todos.class_id)
          )
        )
    )
  )
);
