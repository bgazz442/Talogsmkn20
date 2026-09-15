# TALog20 Supabase setup

## Apply migrations

Run the existing migrations in timestamp order. If the database audit shows
that the class tables are missing, run
`migrations/202609050000_class_structure.sql` before
`migrations/202609050001_staff_security.sql`. The security migration then
seeds the official class names after ensuring all seven departments exist.
Both migrations are idempotent and never create users or remove old
departments such as TJKT.

Recommended order for a database where only the first three migrations were
applied:

```text
202609040001_auth_roles.sql
202609040002_project_data.sql
202609050000_class_structure.sql
202609050001_staff_security.sql
202609050002_profile_contact_email.sql
202609060001_hardening.sql
202609060002_multi_user_hardening.sql
202609070001_security_realtime_hardening.sql
202609070003_grade_actor_compatibility.sql
202609080002_admin_dashboard_fixes.sql
202609080003_fix_role_switch_order.sql
202609150001_superadmin_user_auth_sync.sql
```

If `202609040004_complete_setup.sql` was already applied, do not run it again
as a substitute for auditing. The compatibility migration uses
`CREATE TABLE IF NOT EXISTS` and preserves its existing rows and UUIDs.

The final profile migration adds only the nullable, unique `profiles.personal_email`
contact field. It does not create a Super Admin account.

The final hardening migrations are additive. They lock audit writes behind
`log_audit_event`, add realtime publication membership for task flow tables,
and preserve teacher identity while allowing admin/superadmin grading through
`grades.grader_user_id`.

The user management migration makes the Super Admin user list join
`public.profiles` with `auth.users`, so profiles without a current Supabase
Auth account are not displayed.

After applying them, verify realtime and presence in the SQL editor:

```sql
select pubname, schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
  and schemaname = 'public'
  and tablename in ('todos', 'submissions', 'grades')
order by tablename;

select column_name
from information_schema.columns
where table_schema = 'public'
  and table_name = 'grades'
  and column_name = 'grader_user_id';
```

Verify the schema and master data:

```sql
select table_name from information_schema.tables
where table_schema = 'public' order by table_name;

select code, name from public.departments order by code;
```

## First Super Admin

Create the first Auth user manually in the Supabase Dashboard using the real
operator's email. Then, in the SQL editor, replace only the UUID and real name
with that operator's values:

```sql
insert into public.profiles (id, email, full_name, role, status)
values ('REAL_AUTH_USER_UUID', 'real.operator@your-domain.example', 'Nama Operator', 'superadmin', 'active');
```

For the configured Super Admin identity, create or confirm the Auth user in
the Dashboard first with the login email `sa@talogsmkn20.com`. Then use the Auth
user UUID in this statement:

```sql
insert into public.profiles (id, email, personal_email, full_name, role, status)
values (
  'AUTH_USER_UUID_FROM_AUTH_USERS',
  'sa@talogsmkn20.com',
  'abubangkir@gmail.com',
  'Super Admin',
  'superadmin',
  'active'
)
on conflict (id) do update set
  email = excluded.email,
  personal_email = excluded.personal_email,
  full_name = excluded.full_name,
  role = 'superadmin',
  status = 'active';
```

Never put the Super Admin password in this repository or in a migration. Set
or reset it only in Supabase Auth Dashboard.

Do not place the service-role key in Flutter, SQL committed to the repository,
or client-side code. The first Super Admin is the only manual staff profile.

## Deploy manage-staff

The presence of `supabase/functions/manage-staff/index.ts` in this repository
does not mean the Edge Function is active in Supabase. It becomes active only
after a successful deployment and should be checked in the Supabase Dashboard
or CLI deployment output.

Set only server-side secrets/configuration, then deploy:

```text
supabase secrets set INVITATION_BASE_URL="https://your-app.example"
supabase secrets set APP_ORIGINS="https://your-app.example"
supabase functions deploy manage-staff --no-verify-jwt
```

The function reads `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` from the server environment. Never send any of
these values to the client or include them in logs.

## Staff invitation flow

The Super Admin or Admin sends a bearer token to `POST /manage-staff`:

```json
{
  "full_name": "Nama Guru",
  "personal_email": "real.personal@example.com",
  "internal_email": "real.internal@school.example",
  "role": "teacher",
  "department_id": "REAL_DEPARTMENT_UUID"
}
```

Super Admin may use `role: "admin"` or `role: "teacher"`. Admin may use only
`role: "teacher"`. The response contains the one-time `invite_url`; deliver it
to the real invitee through an approved channel. The token is stored only as a
hash, expires after seven days, and cannot be accepted twice.

The invitee submits their own password to `POST /manage-staff/accept`:

```json
{ "token": "ONE_TIME_INVITATION_TOKEN", "password": "user-chosen-password" }
```

This confirms the Auth account, changes the profile from `pending` to `active`,
creates the matching `admins` or `teachers` row, and marks the invitation
`accepted`. A revoked or expired invitation cannot activate an account. Passwords
are never stored in public tables.

## Account management

- To create an Admin, an active Super Admin calls `POST /manage-staff` with
  `role: "admin"` and no `department_id`.
- To create a Teacher, an active Super Admin or Admin calls the same endpoint
  with `role: "teacher"` and a valid `department_id`.
- To disable an account, a trusted server-side administrator sets the profile
  `status` to `disabled`, or sends `PATCH /manage-staff` with
  `{ "user_id": "REAL_USER_UUID", "status": "disabled" }`.
- A disabled account cannot pass the function's role check or database RLS.
- There is no API path to create or promote a `superadmin`.

## RLS and security tests

All sensitive tables require the `authenticated` role and active database role
checks. Students can read their own academic records, teachers can manage tasks
and their grades, Admins manage teachers, and Super Admins manage all staff.
Anonymous access to profiles, staff, students, invitations, submissions, and
grades is revoked. Policies use `(select auth.uid())` and never trust mutable
user metadata.

Run `tests/staff_security.sql` after migration. It contains read-only privilege
assertions plus the manual endpoint scenarios for student/teacher/admin/
superadmin authorization, duplicate invitations, invalid departments, revoked
links, and cross-student grade access.

The old `bootstrap-demo` function is not part of this provisioning flow. Do not
deploy or invoke it because it creates fake users and sample academic records.