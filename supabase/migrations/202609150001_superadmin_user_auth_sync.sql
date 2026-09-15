-- Only expose profiles that still have a matching Supabase Auth account.
create or replace function public.list_managed_users(p_query text default '')
returns table (
  id uuid,
  full_name text,
  email text,
  role text,
  status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_caller_role text;
  v_query text := lower(trim(coalesce(p_query, '')));
begin
  select p.role
  into v_caller_role
  from public.profiles p
  where p.id = (select auth.uid())
    and p.status = 'active';

  if coalesce(v_caller_role, '') <> 'superadmin' then
    raise exception 'Hanya superadmin yang dapat melihat daftar pengguna.';
  end if;

  return query
  select
    p.id,
    p.full_name::text,
    coalesce(p.email::text, u.email::text)::text as email,
    p.role,
    p.status,
    p.created_at
  from public.profiles p
  join auth.users u on u.id = p.id
  where v_query = ''
     or lower(coalesce(p.email::text, u.email::text)) like '%' || v_query || '%'
    or lower(coalesce(p.full_name, '')) like '%' || v_query || '%'
  order by p.created_at desc
  limit 50;
end;
$$;

revoke all on function public.list_managed_users(text) from public, anon, authenticated;
grant execute on function public.list_managed_users(text) to authenticated;

notify pgrst, 'reload schema';