# TALog20

## Aplikasi Logbook, Monitoring Tugas & Penilaian SMKN 20 Jakarta

**TALog20** adalah aplikasi manajemen tugas dan monitoring akademik untuk SMKN 20 Jakarta yang dibangun menggunakan **Flutter** sebagai frontend dan **Supabase** sebagai backend.

TALog20 dirancang sebagai sistem multi-user untuk mengelola:

* Tugas siswa
* Pengumpulan tugas
* Upload file
* Penilaian dan feedback
* AI-assisted grading
* Monitoring siswa dan tugas
* Manajemen kelas dan jurusan
* Dashboard berdasarkan role
* Authentication
* Audit log
* Data isolation menggunakan PostgreSQL RLS

---

# 1. Teknologi

| Komponen       | Teknologi                                        |
| -------------- | ------------------------------------------------ |
| Framework      | Flutter 3.44.8                                   |
| Bahasa         | Dart 3.12.2                                      |
| Backend        | Supabase                                         |
| Database       | PostgreSQL 15+                                   |
| Authentication | Supabase Auth                                    |
| Storage        | Supabase Storage                                 |
| Security       | PostgreSQL Row Level Security                    |
| Authorization  | Role-Based Access Control                        |
| Realtime       | Supabase Realtime                                |
| AI Grading     | Google Gemini API melalui Supabase Edge Function |
| Mobile         | Android                                          |
| Desktop        | Windows                                          |
| Testing        | Chrome / Web                                     |
| IDE            | Visual Studio Code / Android Studio              |

Dependency utama Flutter:

```yaml
supabase_flutter
file_picker
flutter_secure_storage
path_provider
http
url_launcher
mime
```

---

# 2. Tujuan Sistem

TALog20 dibuat untuk menyediakan satu sistem terintegrasi yang dapat digunakan oleh siswa, guru, admin, dan superadmin.

Sistem menangani alur:

```text
Guru membuat tugas
        │
        ▼
Tugas diberikan ke kelas
        │
        ▼
Siswa melihat tugas
        │
        ├── Jawaban teks
        │
        └── Upload file
                │
                ▼
          Submission tersimpan
                │
                ▼
       Guru melakukan penilaian
                │
        ┌───────┴────────┐
        ▼                ▼
   Manual grading     AI grading
        │                │
        └───────┬────────┘
                ▼
          Nilai & feedback
                │
                ▼
        Siswa melihat hasil
```

---

# 3. Role & Hak Akses

TALog20 menggunakan empat role utama:

```text
student
teacher
admin
superadmin
```

## Student

Siswa dapat:

* Login menggunakan email atau username
* Melihat dashboard
* Melihat tugas
* Melihat tugas berdasarkan kelas
* Mengirim jawaban
* Mengunggah file tugas
* Melihat status submission
* Melihat nilai
* Melihat feedback
* Melihat profil
* Mengubah informasi akun sesuai izin sistem

Siswa tidak dapat:

* Mengakses dashboard staff
* Melihat data siswa lain
* Mengakses data internal staff
* Mengubah role pengguna
* Mengakses fungsi administratif

---

## Teacher

Guru dapat:

* Mengakses Teacher/Admin Dashboard
* Membuat tugas
* Menentukan kelas penerima tugas
* Menentukan format pengumpulan
* Melihat submission siswa
* Melihat file yang dikumpulkan
* Memberikan nilai
* Memberikan feedback
* Melakukan penilaian manual
* Menjalankan AI-assisted grading
* Meninjau hasil penilaian AI
* Melakukan Student Preview

Guru tidak dapat:

* Mengubah role secara bebas
* Mengubah security policy database
* Mengambil alih kontrol superadmin

---

## Admin

Admin memiliki akses monitoring dan pengelolaan sistem yang lebih luas.

Fitur:

* Admin Dashboard
* Monitoring tugas
* Monitoring submission
* Monitoring siswa
* Monitoring kelas dan jurusan
* Penilaian
* Audit log
* Student Preview
* Pengelolaan data operasional

---

## Superadmin

Superadmin memiliki kontrol administratif tertinggi.

Fitur utama:

* User Management
* Manajemen role
* Monitoring seluruh sistem
* Monitoring tugas
* Monitoring submission
* Monitoring nilai
* Monitoring jurusan
* Audit log
* Student Preview
* Pengelolaan sistem secara global

Akun superadmin tidak dituliskan di repository untuk menjaga keamanan.

---

# 4. Fitur Utama

## Authentication

TALog20 menggunakan **Supabase Auth**.

Login mendukung:

```text
Email
   │
   ▼
Supabase Auth
```

atau:

```text
Username
   │
   ▼
resolve_username_email()
   │
   ▼
Email
   │
   ▼
Supabase Auth
```

Identitas pengguna menggunakan UUID dari Supabase Auth.

```text
auth.users.id
      │
      ▼
profiles.id
```

---

# 5. Role-Based Access Control

Role pengguna disimpan pada sistem profile dan digunakan untuk menentukan akses fitur.

Role:

```text
student
teacher
admin
superadmin
```

Akses tidak hanya dibatasi pada tampilan Flutter.

Keamanan utama tetap berada pada:

```text
PostgreSQL
    │
    └── Row Level Security
```

---

# 6. Data Isolation

TALog20 menggunakan UUID pengguna dan:

```sql
auth.uid()
```

untuk membantu memastikan pengguna hanya dapat mengakses data yang diizinkan.

Konsep:

```text
User A
  │
  └── UUID A
       │
       └── Data A

User B
  │
  └── UUID B
       │
       └── Data B
```

Flutter tidak dijadikan satu-satunya lapisan keamanan.

Pembatasan akses dilakukan melalui **PostgreSQL Row Level Security (RLS)**.

---

# 7. Manajemen Tugas

Guru dapat membuat tugas dengan informasi seperti:

* Nama tugas
* Deskripsi
* Jurusan
* Kelas
* Deadline
* Format pengumpulan
* Kriteria penilaian AI

Format submission:

```text
essai
file
```

Tugas dapat dikaitkan dengan kelas melalui:

```text
task_assignments
```

---

# 8. Submission Siswa

TALog20 mendukung tiga tipe pengumpulan:

```text
text
file
text_and_file
```

Data submission dapat menyimpan:

* Jawaban teks
* File path
* Nama file
* Ukuran file
* MIME type
* Waktu pengumpulan
* Status submission

Status submission meliputi:

```text
submitted
graded
late
```

---

# 9. File Upload

File submission disimpan pada Supabase Storage menggunakan bucket private:

```text
assignment-submissions
```

Batas ukuran file:

```text
50 MiB
```

Bucket tidak dibuat public.

File dapat berupa berbagai format yang dikonfigurasi pada Storage, termasuk:

```text
PDF
DOC
DOCX
XLS
XLSX
PPT
PPTX
TXT
CSV
PNG
JPG
JPEG
GIF
WEBP
BMP
SVG
ZIP
RAR
7Z
```

Struktur penyimpanan menggunakan path berbasis identitas submission/pengguna.

Akses file dikontrol menggunakan Storage RLS policy.

---

# 10. AI-Assisted Grading

TALog20 memiliki fitur **AI-assisted grading** untuk membantu guru melakukan penilaian tugas berbasis file.

Alurnya:

```text
Siswa
  │
  ▼
Upload File
  │
  ▼
Supabase Storage
  │
  ▼
file-grade Edge Function
  │
  ▼
Ekstraksi teks
  │
  ▼
Google Gemini
  │
  ▼
Score + Feedback
  │
  ▼
Supabase Database
```

AI grading menggunakan kriteria yang ditentukan pada tugas.

Contoh:

```text
Kriteria:
1. Memiliki pendahuluan
2. Menjelaskan metode
3. Memiliki hasil
4. Memiliki kesimpulan
```

AI mengevaluasi dokumen berdasarkan kriteria tersebut.

Nilai dihitung secara proporsional berdasarkan jumlah kriteria yang terpenuhi.

---

# 11. Format File untuk AI Grading

File yang saat ini dapat diproses oleh Edge Function `file-grade` untuk ekstraksi teks:

```text
TXT
CSV
PDF
DOCX
```

File yang hanya berupa gambar/scan atau format binary yang tidak dapat diekstrak teksnya dapat ditolak oleh proses AI grading.

AI grading juga membutuhkan:

```text
AI criteria
```

pada tugas.

Jika tugas tidak memiliki kriteria AI, proses grading akan dihentikan.

---

# 12. AI Grade Review

Hasil AI grading disimpan dengan informasi tambahan seperti:

```text
source
ai_feedback
needs_review
confidence
```

Sumber nilai dapat berupa:

```text
manual
auto
ai
```

Nilai AI ditandai untuk ditinjau kembali oleh guru.

Konsep:

```text
AI memberikan hasil
        │
        ▼
needs_review = true
        │
        ▼
Guru memeriksa
        │
        ▼
Hasil akhir
```

AI digunakan sebagai alat bantu penilaian, bukan sebagai pengganti kontrol guru.

---

# 13. File Grading Edge Function

Edge Function:

```text
supabase/functions/file-grade/
```

bertanggung jawab untuk:

1. Memvalidasi authentication
2. Memvalidasi role
3. Mengambil submission
4. Mengambil file dari Storage
5. Mengekstrak teks
6. Mengirim teks dan kriteria ke Gemini
7. Memproses response AI
8. Menyimpan hasil grading
9. Mengubah status submission
10. Mencatat aktivitas audit

Role yang dapat menjalankan AI grading:

```text
teacher
admin
superadmin
```

---

# 14. Gemini Chat

Repository juga memiliki:

```text
supabase/functions/gemini-chat/
```

Namun fungsi tersebut saat ini masih berupa placeholder dan belum menjadi fitur chat AI production.

Jangan menganggap Gemini Chat sudah aktif hanya karena folder Edge Function tersedia.

---

# 15. Database

Struktur utama database TALog20 meliputi:

```text
departments
profiles
students
teachers
admins
invitations

classes
teacher_classes
student_classes

todos
task_assignments
submissions
grades

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

# 16. Penilaian

TALog20 mendukung penilaian dengan rentang:

```text
0 - 100
```

Data nilai dapat berisi:

```text
score
feedback
graded_at
source
ai_feedback
needs_review
confidence
```

Guru dapat memberikan feedback kepada siswa setelah proses penilaian.

---

# 17. Audit Log

Aktivitas penting sistem dapat dicatat pada:

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
AI_FILE_GRADING_RUN
```

Audit log digunakan untuk membantu monitoring aktivitas sistem.

Konsepnya:

```text
User Action
     │
     ▼
Application
     │
     ▼
Audit Event
     │
     ▼
audit_logs
```

---

# 18. Security

Keamanan TALog20 menggunakan beberapa lapisan:

```text
Supabase Auth
      │
      ▼
UUID Identity
      │
      ▼
RBAC
      │
      ▼
PostgreSQL RLS
      │
      ▼
Storage RLS
      │
      ▼
Audit Log
```

Prinsip keamanan:

* Jangan menggunakan service role key di aplikasi Flutter.
* Jangan menyimpan password di source code.
* Jangan membuat Storage submission menjadi public.
* Jangan mengandalkan filter UI sebagai security.
* Gunakan RLS untuk data pengguna.
* Gunakan Edge Function untuk operasi server-side yang membutuhkan secret.
* Secret API AI harus disimpan sebagai environment/secret server-side.

---

# 19. Secure Authentication Storage

TALog20 menggunakan:

```text
flutter_secure_storage
```

untuk kebutuhan penyimpanan credential/session tertentu pada sisi client.

File terkait:

```text
lib/secure_auth_storage.dart
```

Tujuannya adalah menghindari penyimpanan informasi autentikasi sensitif menggunakan penyimpanan biasa.

---

# 20. Supabase Setup

Buat project pada Supabase kemudian siapkan:

```text
Project URL
Publishable / Anon Key
```

Konfigurasi dapat diberikan melalui:

```text
--dart-define
```

Contoh:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_KEY
```

Jangan memasukkan:

```text
service_role key
secret key
AI API key
```

ke dalam source code Flutter atau repository public.

Secret yang digunakan Edge Function harus dikonfigurasi di environment Supabase.

---

# 21. Database Migration

Migration berada di:

```text
supabase/migrations/
```

Migration terbaru mencakup pengembangan sistem AI grading dan file submission.

Contoh:

```text
202609160001_fix_grading_rls.sql
202609190001_ai_grading.sql
202609200001_file_grading.sql
```

Migration file grading menambahkan dukungan:

* File submission
* Submission format
* AI criteria
* AI grade metadata
* Private Storage bucket
* Storage policies
* Index tambahan

Migration harus dijalankan sesuai urutan pada project Supabase.

---

# 22. Supabase Edge Functions

Struktur:

```text
supabase/
└── functions/
    ├── file-grade/
    │   └── index.ts
    │
    ├── gemini-chat/
    │   └── index.ts
    │
    ├── manage-staff/
    │   └── index.ts
    │
    └── deno.json
```

Fungsi utama:

### file-grade

AI-assisted grading untuk submission berbasis file.

### gemini-chat

Placeholder untuk pengembangan fitur Gemini Chat.

### manage-staff

Menangani operasi terkait manajemen staff sesuai authorization sistem.

---

# 23. Struktur Project

Struktur utama:

```text
talog20/
│
├── android/
├── ios/
├── linux/
├── macos/
├── windows/
│
├── lib/
│   ├── main.dart
│   ├── auth_service.dart
│   ├── dashboard_service.dart
│   ├── secure_auth_storage.dart
│   └── ...
│
├── supabase/
│   ├── functions/
│   │   ├── file-grade/
│   │   ├── gemini-chat/
│   │   └── manage-staff/
│   │
│   └── migrations/
│
├── docs/
│   └── manual-book-pengguna.md
│
├── test/
│
├── pubspec.yaml
├── pubspec.lock
└── README.md
```

---

# 24. Menjalankan Project

Clone repository:

```bash
git clone https://github.com/bgazz442/Talogsmkn20.git
```

Masuk ke folder:

```bash
cd Talogsmkn20
```

Install dependency:

```bash
flutter pub get
```

Cek Flutter:

```bash
flutter doctor
```

Jalankan:

```bash
flutter run
```

Atau dengan konfigurasi Supabase:

```bash
flutter run \
  --dart-define=SUPABASE_URL=YOUR_SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=YOUR_SUPABASE_KEY
```

---

# 25. Build Android

Build APK:

```bash
flutter build apk --release
```

Output:

```text
build/app/outputs/flutter-apk/app-release.apk
```

---

# 26. Build Windows

Pastikan Windows Desktop sudah tersedia:

```bash
flutter config --enable-windows-desktop
```

Kemudian:

```bash
flutter build windows --release
```

Output berada pada:

```text
build/windows/x64/runner/Release/
```

---

# 27. Testing

Cek analyzer:

```bash
flutter analyze
```

Jalankan test:

```bash
flutter test
```

Cek dependency:

```bash
flutter pub get
```

Untuk pengujian aplikasi:

```text
Android
Windows
Chrome
```

---

# 28. Dokumentasi

Manual pengguna tersedia pada:

```text
docs/manual-book-pengguna.md
```

Dokumentasi teknis utama terdapat pada:

```text
README.md
supabase/migrations/
supabase/functions/
```

---

# 29. Status Pengembangan

Fitur utama yang sudah tersedia di repository:

* [x] Flutter application
* [x] Supabase integration
* [x] Supabase Authentication
* [x] Multi-role system
* [x] Student dashboard
* [x] Staff dashboard
* [x] Task management
* [x] Class management
* [x] Student submission
* [x] Text submission
* [x] File submission
* [x] Private Supabase Storage
* [x] PostgreSQL RLS
* [x] Role-based access control
* [x] Audit log
* [x] Manual grading
* [x] AI-assisted file grading
* [x] Gemini integration untuk file grading
* [x] AI grading review flag
* [x] Secure authentication storage
* [x] Android build
* [x] Windows build
* [ ] Gemini Chat production implementation

---

# 30. Prinsip Arsitektur

TALog20 mengikuti prinsip:

```text
Flutter
   │
   ▼
Application Layer
   │
   ▼
Supabase
   │
   ├── Auth
   ├── PostgreSQL
   ├── Storage
   ├── Edge Functions
   └── Realtime
```

Security boundary:

```text
Client
  │
  ├── Authentication
  │
  └── Public/Publishable credentials
             │
             ▼
        Supabase
             │
       ┌─────┴─────┐
       ▼           ▼
      RLS      Edge Functions
                   │
                   ▼
             Server Secrets
```

---

# 31. Repository

Source code TALog20 tersedia di GitHub:

```text
https://github.com/bgazz442/Talogsmkn20
```

---

# 32. Ringkasan

**TALog20** merupakan platform akademik berbasis Flutter dan Supabase yang menggabungkan:

```text
Authentication
       +
Role Management
       +
Task Management
       +
Class Management
       +
File Submission
       +
Private Storage
       +
Manual Grading
       +
AI-Assisted Grading
       +
Dashboard
       +
Audit Log
       +
PostgreSQL RLS
```

Sistem dikembangkan dengan fokus pada **multi-user architecture, data isolation, security, task management, dan integrasi AI untuk membantu proses penilaian tugas**.
