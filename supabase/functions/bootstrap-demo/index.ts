import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-bootstrap-secret',
};

type DemoUser = {
  email: string;
  password: string;
  fullName: string;
  role: 'superadmin' | 'admin' | 'teacher' | 'student';
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (request.method !== 'POST') return json({ error: 'POST required' }, 405);

  const bootstrapSecret = Deno.env.get('BOOTSTRAP_SECRET');
  if (!bootstrapSecret || request.headers.get('x-bootstrap-secret') !== bootstrapSecret) {
    return json({ error: 'Unauthorized' }, 401);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Supabase server secrets are not configured' }, 500);
  }

  const admin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  const body = await request.json().catch(() => ({}));
  const passwordFor = (key: string) => {
    const password = body[key];
    if (typeof password !== 'string' || password.length < 8) {
      throw new Error(`Missing valid ${key}`);
    }
    return password;
  };
  const users: DemoUser[] = [
    {
      email: 'sa@talogsmkn20.com',
      password: passwordFor('superadminPassword'),
      fullName: 'Super Admin',
      role: 'superadmin',
    },
    {
      email: 'admin1@talogsmkn20',
      password: passwordFor('adminPassword'),
      fullName: 'Admin TALog20',
      role: 'admin',
    },
    {
      email: 'guru.rpl@talogsmkn20',
      password: passwordFor('teacherPassword'),
      fullName: 'Guru RPL',
      role: 'teacher',
    },
    {
      email: 'siswa.rpl@talogsmkn20',
      password: passwordFor('studentPassword'),
      fullName: 'Siswa Demo RPL',
      role: 'student',
    },
  ];

  const ids = new Map<string, string>();
  for (const demoUser of users) {
    const { data: existingUsers, error: listError } = await admin.auth.admin.listUsers({ perPage: 1000 });
    if (listError) return json({ error: listError.message }, 500);
    const existing = existingUsers.users.find((user) => user.email?.toLowerCase() === demoUser.email.toLowerCase());
    let userId = existing?.id;

    if (userId) {
      const { error } = await admin.auth.admin.updateUserById(userId, {
        password: demoUser.password,
        email_confirm: true,
        user_metadata: { role: demoUser.role, full_name: demoUser.fullName },
      });
      if (error) return json({ error: error.message }, 500);
    } else {
      const { data, error } = await admin.auth.admin.createUser({
        email: demoUser.email,
        password: demoUser.password,
        email_confirm: true,
        user_metadata: {
          role: demoUser.role,
          full_name: demoUser.fullName,
          ...(demoUser.role === 'student'
            ? { department_code: 'RPL', student_number: 14 }
            : {}),
        },
      });
      if (error || !data.user) return json({ error: error?.message ?? 'User creation failed' }, 500);
      userId = data.user.id;
    }
    ids.set(demoUser.role, userId);
  }

  const adminId = ids.get('admin');
  const teacherId = ids.get('teacher');
  const studentId = ids.get('student');
  const superadminId = ids.get('superadmin');
  if (!adminId || !teacherId || !studentId || !superadminId) return json({ error: 'Demo IDs missing' }, 500);

  const { data: rpl, error: departmentError } = await admin
    .from('departments').select('id').eq('code', 'RPL').single();
  if (departmentError || !rpl) return json({ error: departmentError?.message ?? 'RPL not found' }, 500);

  const { data: rplX, error: classError } = await admin
    .from('classes').select('id').eq('name', 'RPL X').single();
  if (classError || !rplX) return json({ error: classError?.message ?? 'RPL X not found' }, 500);

  const { error: profileError } = await admin.from('profiles').upsert([
    { id: superadminId, email: 'sa@talogsmkn20.com', full_name: 'Super Admin', role: 'superadmin', status: 'active' },
    { id: adminId, email: 'admin1@talogsmkn20', full_name: 'Admin TALog20', role: 'admin', status: 'active' },
    { id: teacherId, email: 'guru.rpl@talogsmkn20', full_name: 'Guru RPL', role: 'teacher', status: 'active' },
    { id: studentId, email: 'siswa.rpl@talogsmkn20', full_name: 'Siswa Demo RPL', role: 'student', status: 'active' },
  ]);
  if (profileError) return json({ error: profileError.message }, 500);

  await admin.from('admins').upsert({
    id: adminId,
    personal_email: body.adminPersonalEmail ?? 'admin.pribadi@example.com',
    internal_email: 'admin1@talogsmkn20',
  });
  await admin.from('teachers').upsert({
    id: teacherId,
    department_id: rpl.id,
    personal_email: body.teacherPersonalEmail ?? 'guru.pribadi@example.com',
    internal_email: 'guru.rpl@talogsmkn20',
  });

  const { error: studentError } = await admin.from('students').upsert({
    id: studentId,
    department_id: rpl.id,
    student_number: 14,
  });
  if (studentError) return json({ error: studentError.message }, 500);

  const { error: studentClassError } = await admin.from('student_classes').upsert({
    student_id: studentId,
    class_id: rplX.id,
  });
  if (studentClassError) return json({ error: studentClassError.message }, 500);

  const { data: todo, error: todoError } = await admin
    .from('todos').select('id').eq('name', 'Tugas pengenalan kelas').single();
  if (todoError || !todo) return json({ error: todoError?.message ?? 'Demo task not found' }, 500);

  await admin.from('teacher_classes').upsert({ teacher_id: teacherId, class_id: rplX.id });
  await admin.from('task_assignments').upsert({ todo_id: todo.id, class_id: rplX.id });

  const { data: submission, error: submissionError } = await admin
    .from('submissions')
    .upsert({
      todo_id: todo.id,
      student_id: studentId,
      note: 'Submission demo siap diperiksa.',
    }, { onConflict: 'todo_id,student_id' })
    .select('id')
    .single();
  if (submissionError || !submission) return json({ error: submissionError?.message ?? 'Submission failed' }, 500);

  const { error: gradeError } = await admin.from('grades').upsert({
    submission_id: submission.id,
    teacher_id: teacherId,
    score: 88,
    feedback: 'Struktur tugas sudah baik. Pertahankan dokumentasinya.',
  }, { onConflict: 'submission_id' });
  if (gradeError) return json({ error: gradeError.message }, 500);

  return json({
    message: 'Demo data is ready',
    accounts: users.map(({ email, role }) => ({ email, role })),
    studentPassword: body.studentPassword ?? '141414',
    adminPassword: body.adminPassword ?? 'Admin12345!',
    teacherPassword: body.teacherPassword ?? 'Guru12345!',
  });
});
