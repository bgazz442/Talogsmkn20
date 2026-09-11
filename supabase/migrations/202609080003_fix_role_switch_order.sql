-- Move staff records before changing profiles.role so profile triggers see a
-- consistent state throughout the transaction.

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

  delete from public.teachers where id = p_user_id;
  delete from public.admins where id = p_user_id;

  update public.profiles
  set role = p_new_role, updated_at = now()
  where id = p_user_id;

  if p_new_role = 'teacher' then
    insert into public.teachers (id) values (p_user_id);
  elsif p_new_role = 'admin' then
    insert into public.admins (id) values (p_user_id);
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

revoke all on function public.update_user_role(uuid, text) from public;
grant execute on function public.update_user_role(uuid, text) to authenticated;