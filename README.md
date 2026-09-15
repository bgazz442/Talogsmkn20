# TALog20

## Aplikasi Logbook & Monitoring Tugas SMKN 20 Jakarta

TALog20 adalah platform manajemen tugas akhir, logbook, pengumpulan tugas, penilaian, dan monitoring akademik berbasis **Flutter** dengan **Supabase PostgreSQL** sebagai backend.

Sistem dirancang sebagai aplikasi multi-user dengan:

- Supabase Auth
- PostgreSQL
- Row Level Security (RLS)
- Role-Based Access Control (RBAC)
- Supabase Storage
- Supabase Realtime
- UUID-based authentication
- Audit log
- Data isolation antar pengguna

---

# 1. Teknologi

| Komponen | Teknologi |
|---|---|
| Framework | Flutter 3.44.8 |
| Bahasa | Dart 3.12.2 |
| Backend | Supabase |
| Database | PostgreSQL 15+ |
| Authentication | Supabase Auth |
| Storage | Supabase Storage |
| Realtime | Supabase Realtime |
| Target Mobile | Android APK |
| Target Testing | Web / Chrome |
| IDE | Visual Studio Code / Android Studio |

---

# 2. Arsitektur Sistem

TALog20 menggunakan arsitektur:

```text
Flutter Application
        │
        ▼
Supabase Flutter SDK
        │
        ├── Supabase Auth
        │       └── Authentication
        │
        ├── PostgreSQL
        │       ├── Profiles
        │       ├── Students
        │       ├── Teachers
        │       ├── Admins
        │       ├── Classes
        │       ├── Todos
        │       ├── Submissions
        │       ├── Grades
        │       └── Audit Logs
        │
        ├── Row Level Security (RLS)
        │
        ├── Storage
        │       └── Assignment Submissions
        │
        └── Realtime
````

Identitas pengguna menggunakan:

```text
auth.users.id
       │
       ▼
public.profiles.id
```

Dengan demikian, data pengguna dapat diisolasi berdasarkan:

```sql
auth.uid()
```

---

# 3. Sistem Role

TALog20 memiliki empat role utama.

## Student

Siswa dapat:

* Login menggunakan email atau username
* Melihat dashboard siswa
* Melihat tugas
* Mengumpulkan tugas
* Mengunggah file
* Mengirim tautan/dokumen
* Melihat nilai
* Melihat feedback guru
* Melihat profil
* Mengubah username
* Mengubah password

Siswa tidak dapat:

* Mengakses Admin Dashboard
* Melihat data siswa lain
* Mengakses data staff
* Mengubah role pengguna

---

## Teacher

Guru dapat:

* Mengakses Admin Dashboard
* Membuat tugas
* Melihat pengumpulan siswa
* Melihat siswa berdasarkan kelas/jurusan
* Memberikan nilai 0–100
* Memberikan feedback
* Memantau tugas
* Menggunakan Staff Preview untuk melihat Student Dashboard

Guru tidak dapat:

* Mengubah role pengguna
* Mengakses audit log
* Mengubah security policy

---

## Admin

Admin dapat:

* Mengakses Admin Dashboard
* Monitoring tugas
* Monitoring pengumpulan
* Monitoring jurusan
* Monitoring pengguna
* Melakukan penilaian
* Melihat audit log
* Menggunakan Student Preview

Admin tidak dapat:

* Mengangkat pengguna menjadi superadmin
* Mengubah security policy
* Mengambil alih kontrol keamanan database

---

## Superadmin

Superadmin memiliki kontrol sistem tertinggi.

Fitur:

* User Management
* Mencari pengguna
* Mengubah role menjadi teacher/admin
* Monitoring seluruh tugas
* Monitoring seluruh nilai
* Monitoring seluruh jurusan
* Melihat audit log
* Student Preview
* Manajemen sistem secara global

Akun bootstrap:

```text
abubangkir@gmail.com
```

Akun superadmin harus dilindungi dari demosi atau perubahan role melalui client biasa.

---

# 4. Struktur Database

Database utama TALog20 terdiri dari tabel:

```text
departments
profiles
students
teachers
admins
invitations

todos
submissions
grades

classes
teacher_classes
student_classes
task_assignments

department_health
dashboard_metrics
activity_feed

audit_logs
```

Relasi utama:

```text
auth.users
    │
    ▼
profiles
    │
    ├── students
    │      │
    │      └── student_classes
    │
    ├── teachers
    │      │
    │      └── teacher_classes
    │
    └── admins


departments
    │
    ├── students
    ├── teachers
    └── classes

classes
    │
    ├── student_classes
    ├── teacher_classes
    └── task_assignments

todos
    │
    ├── task_assignments
    └── submissions
             │
             └── grades
```

---

# 5. Database Migration

Urutan migration TALog20:

```text
202609040001_auth_roles.sql
202609040002_project_data.sql
202609040003_dashboard_seed.sql
202609040004_complete_setup.sql
202609050000_class_structure.sql
202609050001_staff_security.sql
202609050002_profile_contact_email.sql
202609060001_hardening.sql
202609060002_multi_user_hardening.sql
```

Fungsi masing-masing:

### 202609040001_auth_roles.sql

Membuat:

* departments
* profiles
* students
* teachers
* admins
* invitations

### 202609040002_project_data.sql

Membuat:

* todos
* submissions
* grades

### 202609040003_dashboard_seed.sql

Membuat data dashboard:

* dashboard_metrics
* activity_feed
* department health

### 202609040004_complete_setup.sql

Menambahkan:

* classes
* teacher_classes
* student_classes
* task_assignments
* Storage submissions

### 202609050000_class_structure.sql

Normalisasi struktur kelas.

### 202609050001_staff_security.sql

Menambahkan:

* Validasi role
* Security function
* RLS staff
* Pembatasan akses staff

### 202609050002_profile_contact_email.sql

Menambahkan pemisahan email kontak personal.

### 202609060001_hardening.sql

Menambahkan trigger:

```text
set_updated_at
```

untuk tabel yang membutuhkan `updated_at`.

### 202609060002_multi_user_hardening.sql

Menambahkan:

* username
* audit_logs
* resolve_username_email
* update_user_role
* proteksi superadmin
* Storage isolation

---

# 6. SQL Struktur Database

> Query berikut digunakan untuk membentuk struktur dasar database.
>
> Query ini **tidak membuat akun Supabase Auth** dan **tidak menyimpan password**.

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TABLE IF NOT EXISTS public.departments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code citext UNIQUE NOT NULL,
  name text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id),
  email citext UNIQUE NOT NULL,
  full_name text NOT NULL,
  role text NOT NULL DEFAULT 'student'
    CHECK (role IN ('student', 'teacher', 'admin', 'superadmin')),
  status text NOT NULL DEFAULT 'active'
    CHECK (status IN ('pending', 'active', 'disabled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  personal_email citext,
  username text
);

CREATE TABLE IF NOT EXISTS public.students (
  id uuid PRIMARY KEY REFERENCES public.profiles(id),
  department_id uuid NOT NULL REFERENCES public.departments(id),
  student_number integer NOT NULL CHECK (student_number > 0)
);

CREATE TABLE IF NOT EXISTS public.teachers (
  id uuid PRIMARY KEY REFERENCES public.profiles(id),
  department_id uuid REFERENCES public.departments(id),
  personal_email citext,
  internal_email citext UNIQUE
);

CREATE TABLE IF NOT EXISTS public.admins (
  id uuid PRIMARY KEY REFERENCES public.profiles(id),
  admin_number bigint GENERATED ALWAYS AS IDENTITY UNIQUE,
  personal_email citext,
  internal_email citext UNIQUE
);

CREATE TABLE IF NOT EXISTS public.invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  personal_email citext NOT NULL,
  internal_email citext NOT NULL,
  role text NOT NULL
    CHECK (role IN ('teacher', 'admin')),
  department_id uuid REFERENCES public.departments(id),
  invited_by uuid NOT NULL REFERENCES public.profiles(id),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'accepted', 'revoked')),
  created_at timestamptz NOT NULL DEFAULT now(),
  accepted_at timestamptz,
  token_hash text,
  expires_at timestamptz,
  accepted_by uuid REFERENCES public.profiles(id)
);

CREATE TABLE IF NOT EXISTS public.todos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  department_id uuid REFERENCES public.departments(id),
  assigned_to uuid REFERENCES public.profiles(id),
  due_at timestamptz,
  is_complete boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.submissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  todo_id uuid NOT NULL REFERENCES public.todos(id),
  student_id uuid NOT NULL REFERENCES public.students(id),
  file_url text,
  note text,
  submitted_at timestamptz NOT NULL DEFAULT now(),
  submission_type text
    CHECK (
      submission_type IS NULL
      OR submission_type IN ('text', 'file', 'text_and_file')
    ),
  content_text text,
  file_path text,
  file_name text,
  file_size bigint,
  mime_type text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  status text NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('draft', 'submitted', 'returned', 'graded'))
);

CREATE TABLE IF NOT EXISTS public.grades (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  submission_id uuid UNIQUE NOT NULL
    REFERENCES public.submissions(id),
  teacher_id uuid NOT NULL REFERENCES public.teachers(id),
  score numeric NOT NULL CHECK (score >= 0 AND score <= 100),
  feedback text,
  graded_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.classes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL,
  name text NOT NULL,
  grade_level text NOT NULL,
  department_id uuid NOT NULL REFERENCES public.departments(id),
  academic_year text NOT NULL,
  homeroom_teacher_id uuid REFERENCES public.teachers(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.teacher_classes (
  teacher_id uuid NOT NULL REFERENCES public.teachers(id),
  class_id uuid NOT NULL REFERENCES public.classes(id),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (teacher_id, class_id)
);

CREATE TABLE IF NOT EXISTS public.student_classes (
  student_id uuid NOT NULL REFERENCES public.students(id),
  class_id uuid NOT NULL REFERENCES public.classes(id),
  enrolled_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (student_id, class_id)
);

CREATE TABLE IF NOT EXISTS public.task_assignments (
  todo_id uuid NOT NULL REFERENCES public.todos(id),
  class_id uuid NOT NULL REFERENCES public.classes(id),
  assigned_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (todo_id, class_id)
);

CREATE TABLE IF NOT EXISTS public.department_health (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  department_id uuid UNIQUE NOT NULL
    REFERENCES public.departments(id),
  score integer NOT NULL CHECK (score >= 0 AND score <= 100),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.dashboard_metrics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  metric_key text UNIQUE NOT NULL,
  label text NOT NULL,
  value text NOT NULL,
  scope text NOT NULL
    CHECK (scope IN ('student', 'teacher', 'solar')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.activity_feed (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  student_name text NOT NULL,
  detail text NOT NULL,
  is_active boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid REFERENCES auth.users(id),
  actor_role text NOT NULL,
  action text NOT NULL,
  target_user_id uuid REFERENCES auth.users(id),
  target_table text,
  target_record_id text,
  description text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

---

# 7. Supabase Setup

## 7.1 Membuat Project

Buat project baru di Supabase.

Setelah project dibuat, buka:

```text
Supabase Dashboard
        ↓
Connect
```

Ambil:

```text
Project URL
Publishable Key
```

Contoh:

```text
Project URL:
https://<project-ref>.supabase.co

Publishable Key:
sb_publishable_<your-key>
```

> Jangan gunakan `service_role` key atau secret key di aplikasi Flutter.

---

# 8. Menjalankan SQL di Supabase

Masuk ke:

```text
Supabase Dashboard
        ↓
SQL Editor
        ↓
New Query
```

Kemudian masukkan migration SQL sesuai urutan.

Contoh:

```text
001_auth_roles.sql
002_project_data.sql
003_dashboard_seed.sql
...
```

Jalankan satu per satu sesuai urutan migration.

> Jangan menjalankan migration secara acak karena beberapa tabel memiliki foreign key terhadap tabel lain.

---

# 9. Koneksi Flutter dengan Supabase

## 9.1 Install Supabase Flutter

Jalankan:

```bash
flutter pub add supabase_flutter
```

Cek:

```bash
flutter pub get
```

---

# 10. Konfigurasi Environment

TALog20 menggunakan:

```text
--dart-define
```

untuk memasukkan konfigurasi Supabase.

Format:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

atau publishable key sesuai konfigurasi project Supabase.

Jangan menaruh secret key di source code.

---

# 11. Inisialisasi Supabase

Contoh dasar `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
  );

  const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception(
      'SUPABASE_URL dan SUPABASE_ANON_KEY belum dikonfigurasi.',
    );
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TALog20',
      home: const Scaffold(
        body: Center(
          child: Text('TALog20'),
        ),
      ),
    );
  }
}
```

> Jika versi `supabase_flutter` yang digunakan menggunakan parameter `publishableKey`, gunakan parameter tersebut sesuai API versi SDK yang terpasang.

---

# 12. Test Koneksi Supabase

Contoh mengambil data:

```dart
final data = await supabase
    .from('todos')
    .select()
    .order('created_at', ascending: false);

print(data);
```

Jika berhasil, Flutter sudah terhubung dengan PostgreSQL Supabase.

---

# 13. Authentication

TALog20 menggunakan Supabase Auth.

User tidak dibuat dengan:

```sql
INSERT INTO auth.users
```

User harus dibuat melalui Supabase Auth.

---

## 13.1 Login dengan Email

```dart
final response = await supabase.auth.signInWithPassword(
  email: email,
  password: password,
);
```

Contoh:

```dart
await supabase.auth.signInWithPassword(
  email: 'student@example.com',
  password: password,
);
```

Password harus berasal dari input pengguna atau sistem autentikasi resmi.

Jangan hard-code password production.

---

# 14. Login dengan Username

TALog20 mendukung:

```text
Email
atau
Username
```

Alur:

```text
Input Login
    │
    ├── Email
    │      ↓
    │   Supabase Auth
    │
    └── Username
           ↓
    resolve_username_email()
           ↓
         Email
           ↓
    Supabase Auth
```

Resolusi username dilakukan melalui RPC PostgreSQL:

```text
resolve_username_email
```

Tujuannya agar Flutter tidak perlu mencari email pengguna secara langsung dari tabel public.

---

# 15. Current User

Untuk mendapatkan user yang sedang login:

```dart
final user = supabase.auth.currentUser;

if (user != null) {
  print(user.id);
  print(user.email);
}
```

UUID user:

```dart
final userId = supabase.auth.currentUser!.id;
```

UUID tersebut digunakan untuk isolasi data.

---

# 16. Mengambil Profile User

```dart
final userId = supabase.auth.currentUser!.id;

final profile = await supabase
    .from('profiles')
    .select()
    .eq('id', userId)
    .single();

print(profile);
```

---

# 17. Mengambil Submission Milik Siswa

```dart
final userId = supabase.auth.currentUser!.id;

final submissions = await supabase
    .from('submissions')
    .select()
    .eq('student_id', userId)
    .order('submitted_at', ascending: false);
```

RLS PostgreSQL tetap menjadi lapisan keamanan utama.

Flutter tidak boleh mengandalkan filter UI saja.

---

# 18. Mengambil Nilai Siswa

```dart
final userId = supabase.auth.currentUser!.id;

final grades = await supabase
    .from('grades')
    .select('''
      id,
      score,
      feedback,
      graded_at,
      submissions!inner(
        id,
        student_id,
        todo_id
      )
    ''')
    .eq('submissions.student_id', userId)
    .order('graded_at', ascending: false);
```

---

# 19. Upload File Submission

Bucket Storage untuk submission harus bersifat:

```text
PRIVATE
```

Contoh struktur path:

```text
assignment-submissions/
    <user-id>/
        <todo-id>/
            <file-name>
```

Contoh Flutter:

```dart
final userId = supabase.auth.currentUser!.id;

final filePath = '$userId/$todoId/$fileName';

await supabase.storage
    .from('assignment-submissions')
    .uploadBinary(
      filePath,
      fileBytes,
      fileOptions: FileOptions(
        contentType: mimeType,
        upsert: false,
      ),
    );
```

---

# 20. Storage Security

Storage submission harus menggunakan policy.

Konsep isolasinya:

```text
Student A
    ↓
/student-a/...
    ↓
Boleh akses file sendiri

Student B
    ↓
/student-a/...
    ↓
DITOLAK
```

Guru/staff yang memiliki izin dapat mengakses submission sesuai department/class yang menjadi tanggung jawabnya.

Jangan membuat Storage policy seperti:

```sql
USING (true)
```

untuk file submission yang bersifat privat.

---

# 21. Row Level Security

RLS merupakan bagian penting dari keamanan TALog20.

Setiap tabel yang berisi data pengguna harus menggunakan RLS sesuai kebutuhan.

Contoh konsep:

```sql
auth.uid()
```

digunakan untuk memastikan pengguna hanya dapat mengakses data miliknya.

Contoh:

```sql
SELECT *
FROM public.submissions
WHERE student_id = auth.uid();
```

Namun filter Flutter saja tidak cukup.

Keamanan sebenarnya harus berada di PostgreSQL RLS.

---

# 22. Data Isolation

Contoh:

```text
User A
UUID: aaa-aaa
```

dan:

```text
User B
UUID: bbb-bbb
```

User A hanya boleh mengakses data:

```text
student_id = aaa-aaa
```

User B hanya boleh mengakses:

```text
student_id = bbb-bbb
```

RLS harus memastikan user tidak dapat mengganti parameter client untuk membaca data user lain.

---

# 23. Audit Log

Aktivitas penting sistem dicatat pada:

```text
public.audit_logs
```

Contoh aktivitas:

```text
LOGIN
LOGOUT
PASSWORD_CHANGED
ROLE_CHANGED
TASK_CREATED
SUBMISSION_CREATED
GRADE_CREATED
FEEDBACK_UPDATED
```

Struktur:

```text
actor_user_id
actor_role
action
target_user_id
target_table
target_record_id
description
metadata
created_at
```

Audit log dirancang sebagai:

```text
APPEND-ONLY
```

Client tidak boleh bebas:

```text
UPDATE audit_logs
DELETE audit_logs
```

---

# 24. Dashboard

## Student Dashboard

Menampilkan:

* Greeting berdasarkan waktu
* Status tugas
* Progress tugas
* Submission
* Nilai
* Feedback
* Profil

Greeting:

```text
Good Morning
Good Afternoon
Good Night
```

Tema dapat menyesuaikan waktu perangkat.

---

## Admin Dashboard

Tab utama:

```text
Overview
Tugas
Pengumpulan & Penilaian
User Management
Audit Log
Buka Student View
```

### Overview

Menampilkan:

* Live metrics
* Student Activity Feed
* Department Health

### Tugas

Untuk:

* Membuat tugas
* Mengelola tugas
* Mengatur assignment

### Pengumpulan & Penilaian

Untuk:

* Melihat submission
* Memberikan nilai
* Memberikan feedback
* Monitoring status

### User Management

Khusus superadmin:

* Search user
* Melihat role
* Mengubah role sesuai kewenangan

### Audit Log

Untuk:

* Monitoring aktivitas sistem
* Investigasi perubahan data

---

# 25. Staff Preview

Guru dan admin dapat membuka:

```text
Student View
```

Preview harus menggunakan sesi staff yang sedang aktif.

Tidak boleh:

```text
Memalsukan token
Mengganti auth.uid()
Membuat session palsu
```

Preview hanya mengubah konteks tampilan aplikasi, sedangkan keamanan database tetap dikontrol oleh Supabase Auth dan RLS.

---

# 26. Dokumentasi User

Gunakan data contoh berikut:

```text
Student:
student@example.com

Teacher:
teacher@example.com

Admin:
admin@example.com

Password:
<DIATUR_DI_SUPABASE_AUTH>
```

Jangan menggunakan akun production dalam README.

---

# 27. Menjalankan di Chrome

Gunakan:

```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL="https://<project-ref>.supabase.co" `
  --dart-define=SUPABASE_ANON_KEY="<SUPABASE_PUBLISHABLE_KEY>"
```

---

# 28. Menjalankan di Android

```powershell
flutter run -d android `
  --dart-define=SUPABASE_URL="https://<project-ref>.supabase.co" `
  --dart-define=SUPABASE_ANON_KEY="<SUPABASE_PUBLISHABLE_KEY>"
```

---

# 29. Build APK Release

```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL="https://<project-ref>.supabase.co" `
  --dart-define=SUPABASE_ANON_KEY="<SUPABASE_PUBLISHABLE_KEY>"
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

# 30. Build Windows EXE

Pastikan Windows desktop support sudah aktif.

```bash
flutter config --enable-windows-desktop
```

Kemudian:

```powershell
flutter build windows --release `
  --dart-define=SUPABASE_URL="https://<project-ref>.supabase.co" `
  --dart-define=SUPABASE_ANON_KEY="<SUPABASE_PUBLISHABLE_KEY>"
```

Output:

```text
build/windows/x64/runner/Release/
```

---

# 31. Development Checklist

Sebelum menjalankan aplikasi:

```text
[ ] Flutter sudah terinstall
[ ] Flutter version 3.44.8
[ ] Dart version 3.12.2
[ ] Supabase project sudah dibuat
[ ] Database migration sudah dijalankan
[ ] RLS sudah aktif
[ ] Storage bucket sudah dibuat
[ ] Storage policy sudah dibuat
[ ] Supabase URL sudah benar
[ ] Publishable/Anon key sudah benar
[ ] Auth sudah dikonfigurasi
```

---

# 32. Security Checklist

Jangan pernah menyimpan:

```text
service_role key
secret key
password production
access token
refresh token
```

di:

```text
README.md
GitHub repository
source code public
screenshot
chat
```

Gunakan:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

atau publishable key untuk aplikasi client.

Keamanan data tetap harus dilakukan menggunakan:

```text
Supabase Auth
+
PostgreSQL RLS
+
Storage Policy
+
RPC Security
+
Audit Log
```

---

# 33. Contoh Query Membaca Profile

```sql
SELECT
  id,
  email,
  full_name,
  role,
  status
FROM public.profiles
WHERE email = 'student@example.com';
```

---

# 34. Contoh Query Submission User

```sql
SELECT
  id,
  todo_id,
  student_id,
  file_path,
  file_name,
  file_size,
  mime_type,
  status,
  submitted_at
FROM public.submissions
WHERE student_id = auth.uid()
ORDER BY submitted_at DESC;
```

---

# 35. Contoh Query Nilai User

```sql
SELECT
  g.id,
  g.submission_id,
  g.score,
  g.feedback,
  g.graded_at
FROM public.grades AS g
JOIN public.submissions AS s
  ON s.id = g.submission_id
WHERE s.student_id = auth.uid()
ORDER BY g.graded_at DESC;
```

---

# 36. Struktur Folder Flutter

Struktur yang direkomendasikan:

```text
lib/
├── main.dart
│
├── core/
│   ├── config/
│   ├── constants/
│   ├── theme/
│   └── utils/
│
├── models/
│   ├── profile.dart
│   ├── student.dart
│   ├── teacher.dart
│   ├── todo.dart
│   ├── submission.dart
│   └── grade.dart
│
├── services/
│   ├── auth_service.dart
│   ├── profile_service.dart
│   ├── task_service.dart
│   ├── submission_service.dart
│   ├── grade_service.dart
│   └── storage_service.dart
│
├── screens/
│   ├── auth/
│   ├── student/
│   ├── teacher/
│   ├── admin/
│   └── superadmin/
│
├── widgets/
│
└── routes/
```

---

# 37. Prinsip Pengembangan

TALog20 mengikuti prinsip:

```text
Security First
Data Isolation
Role-Based Access Control
Server-Side Authorization
Clean Architecture
Reusable Components
Responsive UI
Realtime Monitoring
```

Client Flutter bertanggung jawab terhadap:

```text
UI
State
Navigation
User Interaction
```

Supabase bertanggung jawab terhadap:

```text
Authentication
Authorization
Database
RLS
Storage
Realtime
Audit
```

---

# 38. Alur Login

```text
User
 │
 ▼
Login Page
 │
 ├── Email
 │      │
 │      ▼
 │   Supabase Auth
 │
 └── Username
        │
        ▼
 resolve_username_email()
        │
        ▼
      Email
        │
        ▼
 Supabase Auth
        │
        ▼
   auth.uid()
        │
        ▼
 public.profiles
        │
        ▼
      Check Role
        │
 ┌──────┼─────────────┐
 ▼      ▼             ▼
Student Teacher     Admin
                    │
                    ▼
                Superadmin
```

---

# 39. Alur Submission

```text
Student
   │
   ▼
Student Dashboard
   │
   ▼
Pilih Tugas
   │
   ▼
Upload File / Link / Text
   │
   ▼
Supabase Storage
   │
   ▼
public.submissions
   │
   ▼
Teacher/Admin
   │
   ▼
Review
   │
   ▼
Score + Feedback
   │
   ▼
public.grades
   │
   ▼
Student Dashboard
```

---

# 40. Alur Role Management

```text
Superadmin
    │
    ▼
User Management
    │
    ▼
Search User
    │
    ▼
Pilih User
    │
    ▼
update_user_role()
    │
    ├── student
    ├── teacher
    └── admin
```

Superadmin tidak dapat diubah menjadi role lain melalui operasi client biasa.

---

# 41. Catatan Penting Database

SQL struktur database di atas hanya membuat:

```text
TABLE
EXTENSION
FOREIGN KEY
CHECK CONSTRAINT
```

SQL tersebut **belum mencakup seluruh security configuration**.

Komponen keamanan berikut harus dikonfigurasi secara terpisah:

```text
RLS Policy
Storage Policy
RPC Security
Trigger
Function
Audit Protection
```

Gunakan migration security yang terdapat pada repository sebagai sumber konfigurasi security utama.

---

# 42. Troubleshooting

## Supabase tidak terhubung

Periksa:

```text
SUPABASE_URL
SUPABASE_ANON_KEY
```

Kemudian jalankan ulang:

```bash
flutter clean
flutter pub get
flutter run
```

---

## Error `auth.uid()`

Pastikan user sudah login:

```dart
final user = supabase.auth.currentUser;

if (user == null) {
  // User belum login
}
```

---

## Data tidak muncul

Periksa:

```text
RLS Policy
User Authentication
UUID
Foreign Key
Role
```

Jangan langsung menonaktifkan RLS hanya untuk menghilangkan error.

---

## Upload Storage gagal

Periksa:

```text
Bucket name
Bucket visibility
Storage policy
File path
Authenticated session
```

---

# 43. Prinsip Keamanan Utama

TALog20 **tidak menganggap Flutter sebagai lapisan keamanan utama**.

Flutter hanya merupakan client.

Keamanan sebenarnya berada di:

```text
Supabase Auth
      +
PostgreSQL RLS
      +
Storage Policy
      +
Secure RPC
      +
Database Constraint
```

Contoh:

```text
Flutter:
"Ambil data submission."

        ↓

Supabase

        ↓

PostgreSQL RLS

        ↓

Apakah user berhak?

   ┌────┴────┐
   │         │
  YES        NO
   │         │
   ▼         ▼
 Data       Error
```

---

# 44. License

Project ini dibuat untuk kebutuhan pengembangan dan monitoring akademik SMKN 20 Jakarta.

```text
TALog20
© SMKN 20 Jakarta
```

---

# 45. Status Project

```text
Project: TALog20
Platform: Flutter
Backend: Supabase
Database: PostgreSQL
Authentication: Supabase Auth
Storage: Supabase Storage
Security: PostgreSQL RLS
Status: Development
```

---

```

**Catatan penting:** saya sengaja memisahkan **SQL struktur database** dari **RLS/Storage policy**, karena kalau semua digabung sebagai satu SQL tanpa memastikan urutan function, trigger, policy, dan dependency-nya, justru lebih mudah muncul error di Supabase. Untuk repository GitHub, struktur README di atas sudah jauh lebih enak dijadikan dokumentasi teknis project.
```
