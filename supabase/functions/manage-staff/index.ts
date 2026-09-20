import { createClient, type SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2';

const allowedOrigins = (Deno.env.get('APP_ORIGINS') ?? '').split(',').map((value) => value.trim()).filter(Boolean);
const allowedRoles = new Set(['admin', 'teacher']);
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const jsonHeaders = { 'Content-Type': 'application/json', Vary: 'Origin' };

type StaffRole = 'admin' | 'teacher';
type RequestBody = {
  full_name?: string;
  personal_email?: string;
  internal_email?: string;
  role?: string;
  department_id?: string | null;
};

function corsHeaders(request: Request) {
  const origin = request.headers.get('origin') ?? '';
  const allowedOrigin = allowedOrigins.includes(origin) ? origin : allowedOrigins[0] ?? '';
  return { ...jsonHeaders, ...(allowedOrigin ? { 'Access-Control-Allow-Origin': allowedOrigin } : {}) };
}

function response(request: Request, body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: corsHeaders(request) });
}

function normalizeEmail(value: unknown) {
  return typeof value === 'string' ? value.trim().toLowerCase() : '';
}

async function sha256(value: string) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);
  return Array.from(new Uint8Array(digest)).map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

function token() {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
}

async function authenticatedClient(request: Request) {
  const authorization = request.headers.get('authorization');
  if (!authorization?.toLowerCase().startsWith('bearer ')) return { error: 'Authentication required' };
  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anonKey || !serviceKey) return { error: 'Server authentication is not configured' };
  const userClient = createClient(url, anonKey, { global: { headers: { Authorization: authorization } } });
  const { data, error } = await userClient.auth.getUser();
  if (error || !data.user) return { error: 'Invalid or expired access token' };
  const adminClient = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const { data: profile, error: profileError } = await adminClient
    .from('profiles').select('id, role, status').eq('id', data.user.id).maybeSingle();
  if (profileError || !profile || profile.status !== 'active') return { error: 'Active profile not found' };
  return { user: data.user, profile, adminClient };
}

function validUuid(value: unknown) {
  return typeof value === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value);
}

async function createInvitation(request: Request, client: SupabaseClient, actor: { id: string; role: string }) {
  const body = await request.json().catch(() => ({})) as RequestBody;
  const fullName = body.full_name?.trim() ?? '';
  const personalEmail = normalizeEmail(body.personal_email);
  const internalEmail = normalizeEmail(body.internal_email);
  const role = body.role;
  if (fullName.length < 2 || fullName.length > 160) return response(request, { error: 'full_name must be 2-160 characters' }, 400);
  if (!emailPattern.test(personalEmail) || !emailPattern.test(internalEmail)) return response(request, { error: 'Valid personal_email and internal_email are required' }, 400);
  if (!allowedRoles.has(role ?? '')) return response(request, { error: 'role must be admin or teacher' }, 400);
  if (actor.role === 'admin' && role !== 'teacher') return response(request, { error: 'Admin may invite teachers only' }, 403);
  if (role === 'teacher' && !validUuid(body.department_id)) return response(request, { error: 'A valid department_id is required for teachers' }, 400);
  if (role === 'admin' && body.department_id != null) return response(request, { error: 'Admins do not use department_id' }, 400);

  if (role === 'teacher') {
    const { data: department, error } = await client.from('departments').select('id').eq('id', body.department_id).maybeSingle();
    if (error || !department) return response(request, { error: 'department_id does not reference a valid department' }, 400);
  }
  const { data: duplicate, error: duplicateError } = await client.from('profiles').select('id').or(`email.eq.${internalEmail},email.eq.${personalEmail}`).maybeSingle();
  if (duplicateError) return response(request, { error: 'Could not validate existing accounts' }, 500);
  if (duplicate) return response(request, { error: 'An account already exists for this email' }, 409);
  const { data: pending, error: pendingError } = await client.from('invitations').select('id').or(`personal_email.eq.${personalEmail},internal_email.eq.${internalEmail}`).eq('status', 'pending').maybeSingle();
  if (pendingError) return response(request, { error: 'Could not validate pending invitations' }, 500);
  if (pending) return response(request, { error: 'A pending invitation already exists for this email' }, 409);

  const inviteToken = token();
  const tokenHash = await sha256(inviteToken);
  const { data: authUser, error: authError } = await client.auth.admin.createUser({
    email: internalEmail,
    email_confirm: false,
    user_metadata: { full_name: fullName, role },
  });
  if (authError || !authUser.user) return response(request, { error: authError?.message ?? 'Could not create invited account' }, 400);

  const { error: profileError } = await client.from('profiles').insert({
    id: authUser.user.id, email: internalEmail, full_name: fullName, role, status: 'pending',
  });
  if (profileError) {
    await client.auth.admin.deleteUser(authUser.user.id);
    return response(request, { error: 'Could not create pending profile' }, 500);
  }
  const staffInsert = role === 'teacher'
    ? client.from('teachers').upsert({
        id: authUser.user.id,
        department_id: body.department_id ?? null,
        personal_email: personalEmail,
        internal_email: internalEmail,
      }, { onConflict: 'id' })
    : client.from('admins').upsert({
        id: authUser.user.id,
        personal_email: personalEmail,
        internal_email: internalEmail,
      }, { onConflict: 'id' });
  const { error: staffError } = await staffInsert;
  if (staffError) {
    await client.from('profiles').delete().eq('id', authUser.user.id);
    await client.auth.admin.deleteUser(authUser.user.id);
    return response(request, { error: 'Could not create staff identity record' }, 500);
  }
  const { data: invitation, error: invitationError } = await client.from('invitations').insert({
    personal_email: personalEmail, internal_email: internalEmail, role,
    department_id: body.department_id ?? null, invited_by: actor.id,
    status: 'pending', token_hash: tokenHash, expires_at: new Date(Date.now() + 7 * 86400000).toISOString(),
  }).select('id, status, expires_at').single();
  if (invitationError || !invitation) {
    await client.from('profiles').delete().eq('id', authUser.user.id);
    await client.auth.admin.deleteUser(authUser.user.id);
    return response(request, { error: 'Could not create invitation' }, 500);
  }
  const baseUrl = Deno.env.get('INVITATION_BASE_URL') ?? '';
  return response(request, { invitation, invite_url: `${baseUrl.replace(/\/$/, '')}/accept-invitation?token=${inviteToken}` }, 201);
}

async function acceptInvitation(request: Request, client: SupabaseClient) {
  const body = await request.json().catch(() => ({})) as { token?: string; password?: string };
  if (!body.token || body.token.length < 40) return response(request, { error: 'Invitation token is required' }, 400);
  if (typeof body.password !== 'string' || body.password.length < 8) return response(request, { error: 'Password must contain at least 8 characters' }, 400);
  const tokenHash = await sha256(body.token);
  const { data: invitation, error } = await client.from('invitations').select('*').eq('token_hash', tokenHash).maybeSingle();
  if (error || !invitation) return response(request, { error: 'Invitation is invalid' }, 400);
  if (invitation.status !== 'pending' || new Date(invitation.expires_at) <= new Date()) return response(request, { error: 'Invitation is expired, revoked, or already accepted' }, 410);
  const { data: userPage, error: usersError } = await client.auth.admin.listUsers({ perPage: 1000 });
  const user = userPage?.users.find((candidate) => candidate.email?.toLowerCase() === invitation.internal_email.toLowerCase());
  if (usersError || !user) return response(request, { error: 'Invited account is unavailable' }, 404);
  const { error: updateError } = await client.auth.admin.updateUserById(user.id, { password: body.password, email_confirm: true });
  if (updateError) return response(request, { error: 'Could not activate account' }, 500);
  const { error: profileError } = await client.from('profiles').update({ status: 'active' }).eq('id', user.id).eq('status', 'pending');
  if (profileError) return response(request, { error: 'Could not activate profile' }, 500);
  const { error: staffError } = invitation.role === 'teacher'
    ? await client.from('teachers').upsert({
        id: user.id,
        department_id: invitation.department_id,
        personal_email: invitation.personal_email,
        internal_email: invitation.internal_email,
      }, { onConflict: 'id' })
    : await client.from('admins').upsert({
        id: user.id,
        personal_email: invitation.personal_email,
        internal_email: invitation.internal_email,
      }, { onConflict: 'id' });
  if (staffError) return response(request, { error: 'Could not activate staff record' }, 500);
  const { error: acceptedError } = await client.from('invitations').update({ status: 'accepted', accepted_at: new Date().toISOString(), accepted_by: user.id, token_hash: null }).eq('id', invitation.id).eq('status', 'pending');
  if (acceptedError) return response(request, { error: 'Could not finalize invitation' }, 500);
  return response(request, { message: 'Invitation accepted' });
}

async function updateStaffStatus(request: Request, client: SupabaseClient, actor: { role: string }) {
  const body = await request.json().catch(() => ({})) as { user_id?: string; status?: string };
  if (!validUuid(body.user_id) || !['active', 'disabled'].includes(body.status ?? '')) {
    return response(request, { error: 'user_id and status (active or disabled) are required' }, 400);
  }
  const { data: target, error: targetError } = await client.from('profiles').select('id, role').eq('id', body.user_id).maybeSingle();
  if (targetError || !target) return response(request, { error: 'Staff profile not found' }, 404);
  if (!['admin', 'teacher'].includes(target.role)) return response(request, { error: 'Only admin and teacher status may be changed' }, 403);
  if (actor.role === 'admin' && target.role !== 'teacher') return response(request, { error: 'Admin may change teacher status only' }, 403);
  const { error } = await client.from('profiles').update({ status: body.status }).eq('id', target.id);
  if (error) return response(request, { error: 'Could not change staff status' }, 500);
  return response(request, { user_id: target.id, status: body.status });
}

type CreateStudentBody = {
  full_name?: string;
  email?: string;
  username?: string;
  department_id?: string | null;
  password?: string;
  role?: string;
};

async function createStudent(request: Request, client: SupabaseClient, actor: { id: string; role: string }) {
  const body = await request.json().catch(() => ({})) as CreateStudentBody;
  const fullName = body.full_name?.trim() ?? '';
  const email = normalizeEmail(body.email);
  const username = body.username?.trim().toLowerCase() ?? '';
  const password = body.password ?? '';
  const departmentId = body.department_id ?? null;
  const targetRole = body.role?.trim().toLowerCase() ?? 'student';

  // Validasi
  if (fullName.length < 2 || fullName.length > 160) return response(request, { error: 'full_name harus 2-160 karakter' }, 400);
  if (!emailPattern.test(email)) return response(request, { error: 'Email tidak valid' }, 400);
  if (!/^[a-z0-9_]{3,20}$/.test(username)) return response(request, { error: 'Username harus 3-20 karakter, hanya huruf kecil, angka, dan underscore' }, 400);
  if (password.length < 8) return response(request, { error: 'Password minimal 8 karakter' }, 400);

  // Izin: admin hanya bisa buat student, superadmin bisa buat student/teacher/admin
  const allowedByActor = actor.role === 'superadmin'
    ? ['student', 'teacher', 'admin', 'superadmin'].includes(targetRole)
    : targetRole === 'student';
  if (!allowedByActor) return response(request, { error: 'Anda tidak memiliki izin untuk membuat akun dengan role ini' }, 403);

  // Cek duplikat email
  const { data: existing } = await client.from('profiles').select('id').eq('email', email).maybeSingle();
  if (existing) return response(request, { error: 'Email sudah terdaftar' }, 409);

  // Cek duplikat username
  const { data: existingUsername } = await client.from('profiles').select('id').eq('username', username).maybeSingle();
  if (existingUsername) return response(request, { error: 'Username sudah digunakan' }, 409);

  // Buat auth user
  const { data: authUser, error: authError } = await client.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName, role: targetRole },
  });
  if (authError || !authUser.user) return response(request, { error: authError?.message ?? 'Gagal membuat akun' }, 400);

  // Insert profiles
  const { error: profileError } = await client.from('profiles').insert({
    id: authUser.user.id,
    email,
    full_name: fullName,
    role: targetRole,
    status: 'active',
    username,
  });
  if (profileError) {
    await client.auth.admin.deleteUser(authUser.user.id);
    return response(request, { error: 'Gagal membuat profil akun' }, 500);
  }

  // Insert ke tabel role-specific
  if (targetRole === 'student') {
    if (departmentId && validUuid(departmentId)) {
      const { error: studentError } = await client.from('students').insert({
        id: authUser.user.id,
        department_id: departmentId,
        student_number: Math.floor(Math.random() * 9000) + 1000,
      });
      if (studentError) {
        await client.from('profiles').delete().eq('id', authUser.user.id);
        await client.auth.admin.deleteUser(authUser.user.id);
        return response(request, { error: 'Gagal membuat data siswa' }, 500);
      }
    }
  } else if (targetRole === 'teacher') {
    await client.from('teachers').upsert({ id: authUser.user.id, department_id: departmentId }, { onConflict: 'id' });
  } else if (targetRole === 'admin') {
    await client.from('admins').upsert({ id: authUser.user.id }, { onConflict: 'id' });
  } else if (targetRole === 'superadmin') {
    // superadmin tidak memiliki tabel role-specific terpisah; profile saja sudah cukup
  }

  return response(request, { user: { id: authUser.user.id, email, full_name: fullName, role: targetRole } }, 201);
}

async function resetAccountPassword(request: Request, client: SupabaseClient, actor: { role: string }) {
  const body = await request.json().catch(() => ({})) as { user_id?: string; new_password?: string };
  if (!validUuid(body.user_id)) return response(request, { error: 'user_id tidak valid' }, 400);
  if (typeof body.new_password !== 'string' || body.new_password.length < 8) return response(request, { error: 'Password minimal 8 karakter' }, 400);
  const { error } = await client.auth.admin.updateUserById(body.user_id!, { password: body.new_password });
  if (error) return response(request, { error: 'Gagal mereset password: ' + error.message }, 500);
  return response(request, { user_id: body.user_id, message: 'Password berhasil direset' });
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: { ...corsHeaders(request), 'Access-Control-Allow-Methods': 'POST, PATCH, OPTIONS', 'Access-Control-Allow-Headers': 'authorization, apikey, content-type' } });
  if (!['POST', 'PATCH'].includes(request.method)) return response(request, { error: 'POST or PATCH required' }, 405);
  const url = Deno.env.get('SUPABASE_URL');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !serviceKey) return response(request, { error: 'Server secrets are not configured' }, 500);
  const serviceClient = createClient(url, serviceKey, { auth: { autoRefreshToken: false, persistSession: false } });
  const path = new URL(request.url).pathname.replace(/\/$/, '');
  if (path.endsWith('/accept')) return acceptInvitation(request, serviceClient);
  const auth = await authenticatedClient(request);
  if ('error' in auth) return response(request, { error: auth.error }, 401);
  if (!['admin', 'superadmin'].includes(auth.profile.role)) return response(request, { error: 'Only admin or superadmin may manage staff' }, 403);
  if (path.endsWith('/create-student')) return createStudent(request, auth.adminClient, { id: auth.user.id, role: auth.profile.role });
  if (path.endsWith('/reset-password') && request.method === 'PATCH') return resetAccountPassword(request, auth.adminClient, { role: auth.profile.role });
  if (request.method === 'PATCH') return updateStaffStatus(request, auth.adminClient, { role: auth.profile.role });
  return createInvitation(request, auth.adminClient, { id: auth.user.id, role: auth.profile.role });
});
