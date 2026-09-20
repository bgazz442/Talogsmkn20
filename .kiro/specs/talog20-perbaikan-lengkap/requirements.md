# Requirements Document

## Introduction

Dokumen ini mendefinisikan persyaratan untuk perbaikan aplikasi TALog20 (Flutter + Supabase) yang mencakup tiga tugas utama:

- **Tugas 1**: Hapus registrasi mandiri — pengguna tidak lagi dapat mendaftar sendiri; akun hanya dibuat oleh admin/superadmin.
- **Tugas 2**: Pembuatan akun oleh admin/superadmin — panel manajemen akun baru di dashboard, termasuk pembuatan akun per-individu, import massal CSV, dan pengelolaan status akun.
- **Tugas 3**: Hapus fitur Ubah Role di UI superadmin — role ditentukan saat akun dibuat dan tidak dapat diubah lewat UI.

Semua teks UI menggunakan Bahasa Indonesia. Perubahan database bersifat aditif. Service role key hanya boleh ada di edge function.

---

## Glossary

- **TALog20**: Aplikasi manajemen tugas dan nilai siswa SMKN 20 berbasis Flutter dan Supabase.
- **LoginPage**: Halaman login tunggal yang menjadi titik masuk aplikasi setelah penghapusan RegisterPage.
- **RegisterPage**: Widget Flutter yang sebelumnya memungkinkan pendaftaran mandiri siswa; dihapus dari UI pada Tugas 1.
- **UserManagementPanel**: Widget Flutter yang menampilkan daftar pengguna dan aksi manajemen; dipertahankan tanpa tombol "Ubah Role".
- **AccountManagementPanel**: Widget Flutter baru berupa panel "Manajemen Akun" yang ditambahkan sebagai tab di dashboard admin dan superadmin.
- **AuthService**: Kelas Dart di `lib/auth_service.dart` yang menyediakan fungsi autentikasi dan manajemen profil.
- **manage-staff**: Supabase Edge Function di `supabase/functions/manage-staff/index.ts` yang menangani operasi akun dengan service role key.
- **action create_student**: Aksi baru yang ditambahkan ke manage-staff untuk membuat akun siswa langsung berstatus active.
- **RoleDashboard**: Widget Flutter dashboard untuk peran teacher, admin, dan superadmin.
- **ShellState**: State dari widget Shell yang menangani navigasi dan layout utama.
- **profiles**: Tabel Supabase berisi id, email, full_name, role, status, username.
- **students**: Tabel Supabase berisi id, department_id, student_number.
- **audit_logs**: Tabel Supabase untuk pencatatan jejak audit aksi sistem.
- **log_audit_event**: RPC Supabase yang digunakan untuk mencatat aksi ke tabel audit_logs.
- **path_provider**: Package Flutter yang ditambahkan ke pubspec.yaml untuk mendukung ekspor CSV via dart:io.
- **readableAuthError**: Fungsi di main.dart yang mengkonversi kode error internal menjadi pesan ramah pengguna berbahasa Indonesia.

---

## Requirements

### Requirement 1 — Hapus Registrasi Mandiri (Tugas 1)

**User Story:** Sebagai administrator sekolah, saya ingin menghapus fitur pendaftaran mandiri agar hanya akun yang dibuat oleh admin/superadmin yang dapat mengakses sistem.

#### Acceptance Criteria

1. THE LoginPage SHALL menampilkan hanya dua elemen aksi: form login (email/username + password) dan tombol "Lupa password?", tanpa tautan atau tombol menuju RegisterPage.

2. WHEN pengguna membuka aplikasi, THE LoginPage SHALL tidak menyertakan referensi navigasi ke RegisterPage dalam widget tree maupun kode aktif.

3. THE RegisterPage widget SHALL dihapus sepenuhnya dari kode yang aktif digunakan di UI, sehingga tidak dapat diakses dari jalur navigasi mana pun.

4. THE AuthService.registerStudent() method SHALL tetap ada di `lib/auth_service.dart` tanpa perubahan implementasi, meskipun tidak dipanggil dari UI.

5. WHEN pengguna yang memiliki akun Supabase Auth tetapi tidak memiliki baris di tabel profiles berhasil login, THE LoginPage SHALL menampilkan pesan: "Akun belum terdaftar. Hubungi admin sekolah untuk dibuatkan akun."

6. WHEN kode error `PROFILE_NOT_FOUND` diterima oleh fungsi readableAuthError, THE readableAuthError SHALL mengembalikan string: "Akun belum terdaftar. Hubungi admin sekolah untuk dibuatkan akun."

7. THE LoginPage SHALL mempertahankan fungsi "Lupa password?" yang membuka dialog reset password via email.

---

### Requirement 2 — Pembuatan Akun oleh Admin/Superadmin (Tugas 2)

**User Story:** Sebagai admin atau superadmin, saya ingin dapat membuat dan mengelola akun pengguna dari dalam aplikasi agar tidak perlu menggunakan dashboard Supabase secara langsung.

#### Acceptance Criteria

1. THE RoleDashboard SHALL menambahkan tab baru bernama "Manajemen Akun" di navigasi untuk pengguna dengan role admin dan superadmin, tanpa mengganti atau menghapus tab yang sudah ada.

2. WHEN tab "Manajemen Akun" dipilih, THE AccountManagementPanel SHALL ditampilkan di area konten utama.

3. THE AccountManagementPanel SHALL menampilkan form pembuatan akun dengan kolom: nama lengkap, email, username, role (pilihan: student/teacher/admin), dan kelas/jurusan (hanya ditampilkan jika role yang dipilih adalah student).

4. THE AccountManagementPanel SHALL menampilkan kolom password awal yang di-generate otomatis sepanjang minimal 8 karakter alfanumerik, beserta tombol "Salin" untuk menyalin password ke clipboard.

5. WHEN tombol simpan pada form pembuatan akun ditekan untuk role student, THE AccountManagementPanel SHALL memanggil action `create_student` pada manage-staff edge function dengan data: full_name, email, username, department_id, dan password.

6. WHEN tombol simpan pada form pembuatan akun ditekan untuk role teacher atau admin, THE AccountManagementPanel SHALL memanggil action `createInvitation` yang sudah ada pada manage-staff edge function.

7. THE manage-staff edge function SHALL menambahkan penanganan action baru bernama `create_student` yang menerima: full_name, email, username, department_id (opsional), dan password.

8. WHEN action `create_student` diproses oleh manage-staff, THE manage-staff SHALL membuat akun auth Supabase, baris profiles dengan status `active`, dan baris students menggunakan service role key tanpa melalui invitation flow.

9. WHEN action `create_student` berhasil, THE manage-staff SHALL mengembalikan respons HTTP 201 berisi data akun yang dibuat.

10. IF action `create_student` menerima email yang sudah terdaftar di tabel profiles, THEN THE manage-staff SHALL mengembalikan respons HTTP 409 dengan pesan error yang informatif.

11. THE AccountManagementPanel SHALL menampilkan daftar pengguna terdaftar dengan opsi aksi: nonaktifkan akun (mengubah status menjadi `disabled`) dan aktifkan kembali akun (mengubah status menjadi `active`).

12. WHEN tombol "Nonaktifkan" ditekan pada satu akun, THE AccountManagementPanel SHALL memanggil action `updateStaffStatus` pada manage-staff dengan status `disabled` dan menampilkan konfirmasi keberhasilan.

13. WHEN tombol "Aktifkan" ditekan pada satu akun dengan status disabled, THE AccountManagementPanel SHALL memanggil action `updateStaffStatus` pada manage-staff dengan status `active` dan menampilkan konfirmasi keberhasilan.

14. THE AccountManagementPanel SHALL menyediakan fitur reset password yang memungkinkan admin memasukkan password baru untuk akun target dan memanggil endpoint yang sesuai di manage-staff.

15. THE AccountManagementPanel SHALL menyediakan tombol "Import CSV" untuk import massal siswa dengan format kolom: nama, email, username, kelas.

16. WHEN file CSV dipilih dan diproses, THE AccountManagementPanel SHALL membuat akun untuk setiap baris CSV yang valid dengan memanggil action `create_student` secara berurutan, dan menampilkan ringkasan hasil (berhasil/gagal per baris).

17. WHEN baris CSV mengandung email yang sudah terdaftar, THE AccountManagementPanel SHALL mencatat baris tersebut sebagai gagal dengan alasan "Email sudah terdaftar" tanpa menghentikan pemrosesan baris lainnya.

18. WHEN aksi pembuatan akun berhasil, THE AccountManagementPanel SHALL memanggil AuthService.logAudit dengan action `ACCOUNT_CREATED` dan deskripsi yang mencantumkan nama dan role akun baru.

19. WHEN aksi nonaktifkan atau aktifkan akun berhasil, THE AccountManagementPanel SHALL memanggil AuthService.logAudit dengan action `ACCOUNT_STATUS_CHANGED` dan deskripsi perubahan status.

20. WHEN aksi reset password berhasil, THE AccountManagementPanel SHALL memanggil AuthService.logAudit dengan action `ACCOUNT_PASSWORD_RESET` dan deskripsi yang mencantumkan identitas akun target.

21. THE manage-staff edge function SHALL tetap menggunakan service role key hanya di sisi server (edge function), tidak dikirim ke klien Flutter.

22. WHERE fitur import CSV digunakan, THE AccountManagementPanel SHALL menggunakan package `file_picker` untuk memilih file CSV dari perangkat pengguna.

23. THE pubspec.yaml SHALL menambahkan dependency `path_provider` dengan versi yang kompatibel untuk mendukung operasi file pada dart:io.

---

### Requirement 3 — Hapus Fitur Ubah Role di UI Superadmin (Tugas 3)

**User Story:** Sebagai pengelola sistem, saya ingin menghapus kemampuan mengubah role pengguna melalui UI agar role hanya ditentukan saat akun dibuat dan tidak dapat diubah sembarangan.

#### Acceptance Criteria

1. THE UserManagementPanel SHALL tidak menampilkan tombol "Ubah Role" pada daftar pengguna mana pun.

2. THE UserManagementPanel._showChangeRoleDialog method SHALL dihapus dari kode widget UserManagementPanel.

3. THE UserManagementPanel SHALL tidak memanggil AuthService.updateUserRole() dari kode UI mana pun.

4. THE AuthService.updateUserRole() method SHALL tetap ada di `lib/auth_service.dart` tanpa perubahan implementasi.

5. THE RPC `update_user_role` di database SHALL tidak dimodifikasi atau dihapus.

6. THE UserManagementPanel SHALL tetap menampilkan badge role pengguna (label teks role saat ini) dalam daftar pengguna sebagai informasi read-only.

7. WHEN pengguna dengan role superadmin melihat daftar pengguna di UserManagementPanel, THE UserManagementPanel SHALL menampilkan data pengguna lengkap (nama, email, role badge) tanpa opsi mengubah role.
