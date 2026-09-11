# TALog20 — Aplikasi Logbook & Monitoring Tugas SMKN 20

TALog20 adalah platform manajemen tugas akhir, logbook, dan monitoring akademik berbasis Flutter dengan Supabase PostgreSQL sebagai backend. Sistem dirancang dengan arsitektur multi-user yang mengutamakan keamanan data (Data Isolation) melalui Row Level Security (RLS) PostgreSQL, autentikasi berbasis UUID (`auth.uid()`), dan sistem peran (Role-Based Access Control).

---

## 1. Spesifikasi Environment
* **Flutter**: 3.44.8 stable
* **Dart**: 3.12.2
* **Backend**: Supabase (PostgreSQL 15+, Supabase Auth, Storage, Realtime)
* **Target Utama**: Android APK & Web (Chrome testing)
* **Konfigurasi Client**: `--dart-define=SUPABASE_URL=...` dan `--dart-define=SUPABASE_ANON_KEY=...`

---

## 2. Arsitektur Peran (Role System)
TALog20 membagi pengguna ke dalam 4 tingkatan peran:
1. **Student (Siswa)**:
   - Akses: Student Dashboard, penugasan kelas/jurusan, pengumpulan tugas, nilai & feedback, profil, ganti username, dan ganti password.
   - Pembatasan: Dilarang keras mengakses Admin Dashboard. RLS menolak akses ke data staff atau pengumpulan siswa lain.
2. **Teacher (Guru)**:
   - Akses: Admin Dashboard, pembuatan tugas, peninjauan pengumpulan tugas siswa dalam departemen/kelasnya, penilaian real-time, feedback, dan pratinjau Student Dashboard melalui fitur Staff Preview.
   - Pembatasan: Tidak dapat mengubah role pengguna lain atau mengakses audit log.
3. **Admin**:
   - Akses: Admin Dashboard, monitoring operasional, manajemen penugasan & pengumpulan, monitoring jurusan, audit log, dan pratinjau Student Dashboard.
   - Pembatasan: Tidak dapat mengangkat akun menjadi superadmin atau mengubah security policy.
4. **Superadmin**:
   - Akses: Kendali penuh sistem, User Management (pencarian pengguna, promosi/perubahan role menjadi teacher/admin), monitoring tugas & nilai secara global, audit log append-only, dan pratinjau Student Dashboard.
   - Akun bootstrap default: `abubangkir@gmail.com` (terproteksi dari demosi/perubahan oleh sesi biasa).

---

## 3. Fitur Utama

### A. Autentikasi Fleksibel (Email atau Username)
* Pengguna dapat masuk menggunakan alamat **Email** atau **Username**.
* Resolusi username ke email dilakukan secara aman via RPC server-side PostgreSQL (`resolve_username_email`) dengan `search_path` terisolasi dan validasi status akun aktif.
* Pengguna baru mendaftar secara publik otomatis berstatus peran `student` dengan password sementara (nomor absen x3) yang diarahkan untuk segera diganti di dashboard.

### B. Student Dashboard
* Sapaan cerdas real-time (*Good Morning*, *Good Afternoon*, *Good Night*) berdasarkan waktu lokal perangkat.
* Tema dinamis adaptif waktu (Day / Night).
* Ringkasan progres tugas & metrik realtime.
* Pengumpulan tugas dengan penyimpanan file/tautan dokumen.
* Transparansi nilai dan umpan balik (feedback) dari guru penguji.

### C. Admin Dashboard
* Tampilan dashboard komprehensif tanpa merusak struktur visual yang sudah ada.
* Tab Navigasi:
  - **Overview**: Live metrics, Student Activity Feed, Department Health.
  - **Tugas**: Manajemen dan penambahan tugas baru.
  - **Pengumpulan & Penilaian**: Daftar pengumpulan siswa dengan formulir penilaian angka (0-100) dan catatan evaluasi.
  - **User Management (Superadmin)**: Pencarian pengguna dan perubahan peran.
  - **Audit Log (Admin & Superadmin)**: Rekaman jejak aktivitas sistem.
  - **Buka Student View**: Membuka dashboard siswa dalam mode preview menggunakan sesi staf aktif tanpa manipulasi token/sesi palsu.

### D. Keamanan Data & RLS
* **Identitas Data**: Terikat pada `auth.uid()` (`public.profiles.id = auth.users.id`).
* **Isolasi Pengumpulan**: File submission siswa disimpan dalam bucket privat `submissions/<auth.uid>/...` dan hanya dapat dibaca oleh pemilik berkas serta staf pengajar. Siswa lain diblokir oleh storage policy.
* **Audit Trail**: Seluruh aktivitas krusial (login, ganti password, perubahan role, pembuatan tugas, penilaian) tercatat dalam tabel `public.audit_logs` yang bersifat append-only (tidak dapat diubah atau dihapus via client).

---

## 4. Cara Menjalankan & Membangun Aplikasi

### Menjalankan di Chrome / Web (Testing):
```powershell
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://bnajhpskaspkpqobipzc.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<SUPABASE_ANON_KEY>
```

### Menjalankan di Perangkat Android:
```powershell
flutter run -d android `
  --dart-define=SUPABASE_URL=https://bnajhpskaspkpqobipzc.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<SUPABASE_ANON_KEY>
```

### Build APK Release:
```powershell
flutter build apk --release `
  --dart-define=SUPABASE_URL=https://bnajhpskaspkpqobipzc.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<SUPABASE_ANON_KEY>
```
File APK siap digunakan di: `build/app/outputs/flutter-apk/app-release.apk`.

---

## 5. Ringkasan Migrasi Database
1. `202609040001_auth_roles.sql`: Skema awal departemen, profil, peran, siswa, guru, admin.
2. `202609040002_project_data.sql`: Tabel todos, submissions, grades, dan data departemen.
3. `202609040003_dashboard_seed.sql`: Metrik dashboard dan feed aktivitas.
4. `202609040004_complete_setup.sql`: Kelas, relasi kelas siswa/guru, dan bucket submissions.
5. `202609050000_class_structure.sql`: Normalisasi struktur kelas.
6. `202609050001_staff_security.sql`: Pengetatan autentikasi staf, validasi peran, dan fungsi RLS.
7. `202609050002_profile_contact_email.sql`: Pemisahan email kontak personal.
8. `202609060001_hardening.sql`: Trigger otomatis `set_updated_at` untuk semua tabel data.
9. `202609060002_multi_user_hardening.sql`: Penambahan kolom `username`, tabel `audit_logs` append-only, RPC `resolve_username_email`, RPC `update_user_role`, proteksi superadmin, dan pengisolasian akses file storage.
