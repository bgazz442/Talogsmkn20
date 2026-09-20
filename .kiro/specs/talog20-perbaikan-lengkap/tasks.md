# Implementation Plan: talog20-perbaikan-lengkap

## Overview

Implementasi tiga tugas perbaikan pada aplikasi TALog20 (Flutter + Supabase):
- **Tugas 1**: Hapus registrasi mandiri dari UI dan perbarui pesan error `PROFILE_NOT_FOUND`
- **Tugas 2**: Tambah panel `AccountManagementPanel`, action `create_student` di edge function, dan tab navigasi baru
- **Tugas 3**: Hapus tombol "Ubah Role" dan method `_showChangeRoleDialog` dari `UserManagementPanel`

Bahasa: **Dart** (Flutter) + **TypeScript** (Supabase Edge Function).

---

## Tasks

- [ ] 1. Tugas 1 — Hapus registrasi mandiri dari LoginPage dan perbarui readableAuthError
  - [ ] 1.1 Perbarui fungsi `readableAuthError` di `lib/main.dart`
    - Ganti handler `profile_not_found` dari mengembalikan `'Login Auth berhasil, tetapi profile pengguna belum dibuat.'` menjadi `'Akun belum terdaftar. Hubungi admin sekolah untuk dibuatkan akun.'`
    - Lokasi: fungsi `readableAuthError` (baris ~95 area kode saat ini), blok `if (message.contains('profile_not_found'))`
    - _Requirements: 1.5, 1.6_

  - [ ] 1.2 Hapus tautan registrasi dari `_LoginPageState.build` di `lib/main.dart`
    - Hapus widget `Center(child: TextButton(...RegisterPage...))` beserta `const SizedBox(height: 22)` di atasnya dari `Column` di method `build` pada `_LoginPageState`
    - Widget yang dihapus dimulai dari `const SizedBox(height: 22),` sebelum `Center(child: TextButton(onPressed: () => Navigator.push(...RegisterPage()...)))`
    - Pastikan tidak ada referensi navigasi ke `RegisterPage` yang tersisa di `_LoginPageState`
    - _Requirements: 1.1, 1.2_

  - [ ] 1.3 Hapus kelas `RegisterPage` dan `_RegisterPageState` dari `lib/main.dart`
    - Hapus seluruh deklarasi kelas `RegisterPage extends StatefulWidget` dan `_RegisterPageState extends State<RegisterPage>` beserta semua isinya
    - Pastikan tidak ada kelas, method, atau referensi navigasi lain ke `RegisterPage` yang tersisa di file
    - _Requirements: 1.3_

- [ ] 2. Tugas 3 — Hapus fitur Ubah Role dari UserManagementPanel
  - [ ] 2.1 Hapus method `_showChangeRoleDialog` dari `_UserManagementPanelState` di `lib/main.dart`
    - Hapus seluruh method `void _showChangeRoleDialog(Map<String, dynamic> user) { ... }` dari kelas `_UserManagementPanelState`
    - _Requirements: 3.2, 3.3_

  - [ ] 2.2 Hapus tombol "Ubah Role" dari `itemBuilder` di `_UserManagementPanelState.build`
    - Dalam `itemBuilder` pada `ListView.separated`, hapus `const SizedBox(width: 12),` dan widget `OutlinedButton(onPressed: () => _showChangeRoleDialog(user), child: const Text('Ubah Role'))` dari dalam widget `actions` (Row)
    - Pertahankan badge role (Container dengan `role.toUpperCase()`) sebagai tampilan read-only
    - _Requirements: 3.1, 3.6, 3.7_

- [ ] 3. Tugas 2A — Tambah dependency `path_provider` ke pubspec.yaml
  - [ ] 3.1 Tambahkan `path_provider: ^2.1.4` ke blok `dependencies` di `pubspec.yaml`
    - Tambahkan setelah baris `flutter_secure_storage: ^9.2.2`
    - _Requirements: 2.23_

- [ ] 4. Tugas 2B — Implementasi action `create_student` di edge function manage-staff
  - [ ] 4.1 Tambahkan tipe `CreateStudentBody` dan fungsi `createStudent` ke `supabase/functions/manage-staff/index.ts`
    - Buat type baru: `type CreateStudentBody = { full_name?: string; email?: string; username?: string; department_id?: string | null; password?: string; }`
    - Implementasi fungsi `async function createStudent(request: Request, client: SupabaseClient, actor: { id: string; role: string })` dengan alur:
      1. Parse body request
      2. Validasi `full_name` (2-160 chars), `email` (format valid), `username` (3-20 chars, `[a-z0-9_]`), `password` (min 8 chars)
      3. Izin: `admin` hanya bisa buat `student`, `superadmin` bisa buat semua
      4. Cek duplikat email di tabel `profiles` → return 409 jika sudah ada
      5. `adminClient.auth.admin.createUser({ email, password, email_confirm: true })`
      6. Insert ke `profiles` dengan `{ id, email, full_name, role: 'student', status: 'active', username }`
      7. Insert ke `students` dengan `{ id, department_id }` (jika `department_id` ada dan valid UUID)
      8. Rollback (delete students, profiles, deleteUser) jika salah satu insert gagal
      9. Return 201 dengan `{ user: { id, email, full_name } }`
    - _Requirements: 2.7, 2.8, 2.9, 2.10, 2.21_

  - [ ] 4.2 Tambahkan fungsi `resetAccountPassword` ke `supabase/functions/manage-staff/index.ts`
    - Implementasi fungsi `async function resetAccountPassword(request: Request, client: SupabaseClient, actor: { role: string })` dengan alur:
      1. Parse body: `user_id` (UUID wajib) dan `new_password` (string, min 8 chars)
      2. Validasi UUID dan panjang password
      3. `client.auth.admin.updateUserById(user_id, { password: new_password })`
      4. Return 200 dengan `{ user_id, message: 'Password berhasil direset' }`
    - _Requirements: 2.14_

  - [ ] 4.3 Perbarui `Deno.serve` handler di `index.ts` untuk merutekan ke fungsi baru
    - Tambahkan routing path `/create-student` → panggil `createStudent(...)` (method POST)
    - Tambahkan routing path `/reset-password` → panggil `resetAccountPassword(...)` (method PATCH)
    - Pastikan CORS OPTIONS handler juga mengizinkan method baru
    - _Requirements: 2.7, 2.8, 2.14_

- [ ] 5. Checkpoint — Verifikasi perubahan Tugas 1, 3, dan edge function
  - Pastikan `lib/main.dart` tidak mengandung referensi ke `RegisterPage`
  - Pastikan `lib/main.dart` tidak mengandung `_showChangeRoleDialog` atau tombol "Ubah Role"
  - Pastikan `readableAuthError` mengembalikan pesan yang benar untuk `profile_not_found`
  - Pastikan `index.ts` mengandung fungsi `createStudent` dan `resetAccountPassword`
  - Jalankan `flutter analyze` untuk memastikan tidak ada error kompilasi
  - Tanya pengguna jika ada pertanyaan sebelum melanjutkan ke Tugas 2 bagian UI

- [ ] 6. Tugas 2C — Buat widget `AccountManagementPanel` di `lib/main.dart`
  - [ ] 6.1 Buat kelas `ImportResult` dan helper `_generatePassword` di `lib/main.dart`
    - Tambahkan kelas data `ImportResult` dengan field: `rowIndex` (int), `name` (String), `email` (String), `success` (bool), `errorMessage` (String?)
    - Tambahkan fungsi top-level atau static method `_generatePassword()` yang menggunakan `Random.secure()` dan menghasilkan 12 karakter alfanumerik (`[a-zA-Z0-9]`)
    - _Requirements: 2.4_

  - [ ] 6.2 Buat `AccountManagementPanel` StatefulWidget dan `_AccountManagementPanelState` dengan sub-panel form pembuatan akun
    - Deklarasi kelas `AccountManagementPanel extends StatefulWidget` dan `_AccountManagementPanelState extends State<AccountManagementPanel>`
    - Tambahkan state: controllers (nameController, emailController, usernameController, passwordController), `selectedRole` (String, default 'student'), `selectedDepartmentId` (String?), `departments` (List), `isLoading` (bool), `errorMessage` (String?)
    - Implementasi `initState` untuk memanggil `_loadDepartments()` dan generate password awal
    - Implementasi `_loadDepartments()` yang fetch departments dari Supabase
    - Implementasi form UI di `_buildCreateForm()`:
      - `InputField` nama lengkap, email, username
      - `DropdownButton<String>` role (student/teacher/admin)
      - `DropdownButton<String?>` kelas/jurusan (hanya tampil jika role == 'student')
      - Row password: `InputField` (read-only) + tombol "Salin" (Clipboard) + tombol regenerate
    - _Requirements: 2.3, 2.4_

  - [ ] 6.3 Implementasi `_submitCreateAccount()` di `_AccountManagementPanelState`
    - Validasi semua field wajib tidak kosong
    - Jika `role == 'student'`: POST ke `${supabase.supabaseUrl}/functions/v1/manage-staff/create-student` dengan body `CreateStudentRequest` (full_name, email, username, department_id, password) dan header Authorization Bearer token
    - Jika `role == 'teacher'` atau `'admin'`: POST ke endpoint `manage-staff` yang sudah ada (createInvitation) — gunakan format body yang kompatibel
    - Handle response: 201 (sukses → tampilkan SnackBar + audit log + refresh daftar), 409 (email duplikat), 400 (validasi), 403 (izin), error jaringan
    - Setelah berhasil: panggil `AuthService(supabase).logAudit(action: 'ACCOUNT_CREATED', description: 'Akun dibuat: $fullName ($role)')`
    - _Requirements: 2.5, 2.6, 2.18_

  - [ ] 6.4 Implementasi sub-panel daftar pengguna (`_buildUserList()`) di `_AccountManagementPanelState`
    - Fetch dan tampilkan daftar pengguna dengan `AuthService(supabase).searchUsers('')`
    - Per baris: nama, email, badge role (read-only, warna sesuai role), status badge
    - Tombol **Nonaktifkan** (jika status == 'active'): PATCH ke manage-staff `updateStaffStatus` dengan `{ user_id, status: 'disabled' }` → audit log `ACCOUNT_STATUS_CHANGED`
    - Tombol **Aktifkan** (jika status == 'disabled'): PATCH ke manage-staff `updateStaffStatus` dengan `{ user_id, status: 'active' }` → audit log `ACCOUNT_STATUS_CHANGED`
    - Tombol **Reset Password**: buka dialog input password baru → PATCH ke `/manage-staff/reset-password` dengan `{ user_id, new_password }` → audit log `ACCOUNT_PASSWORD_RESET`
    - _Requirements: 2.11, 2.12, 2.13, 2.14, 2.19, 2.20_

  - [ ] 6.5 Implementasi sub-panel import CSV (`_buildImportCsv()`) di `_AccountManagementPanelState`
    - Tombol "Import CSV" memanggil `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'])` untuk memilih file
    - Parse isi file: split baris, skip header, validasi setiap baris memiliki 4 kolom (nama, email, username, kelas)
    - Proses setiap baris valid secara berurutan: panggil `create_student` → kumpulkan `ImportResult`
    - Baris dengan email duplikat (response 409): tandai `success = false, errorMessage = 'Email sudah terdaftar'`, lanjut ke baris berikutnya
    - Setelah semua baris diproses: tampilkan dialog ringkasan dengan jumlah berhasil/gagal dan detail per baris
    - _Requirements: 2.15, 2.16, 2.17, 2.22_

  - [ ] 6.6 Implementasi method `build` pada `_AccountManagementPanelState`
    - Wrap dalam `Panel(title: 'MANAJEMEN AKUN', heading: 'Buat & Kelola Akun Pengguna', ...)`
    - Tampilkan dua bagian: form pembuatan akun (Sub-panel A) dan daftar pengguna + tombol import CSV (Sub-panel B)
    - Handle loading state dan pesan error
    - _Requirements: 2.2, 2.3_

- [ ] 7. Tugas 2D — Perbarui navigasi di `RoleDashboard` dan `Shell`
  - [ ] 7.1 Perbarui method `_buildContentForTab` di `_RoleDashboardState`
    - Ganti logika tab saat ini:
      - Tab 3 dan role == `superadmin` → `AuditLogsPanel` (tidak berubah)
      - Tab 3 dan role == `admin` → `AccountManagementPanel` (BARU)
      - Tab 4 dan role == `superadmin` → `AccountManagementPanel` (BARU, geser dari LiveUpdatePage)
      - Tab 5 dan role == `superadmin` → `LiveUpdatePage` (DIGESER dari tab 4)
      - Hapus kondisi `if (tab == 3 && role == UserRole.admin) return const UserManagementPanel();` yang ada saat ini (duplikat/salah logika)
    - Perbarui getter `liveUpdateTab` dari `role == UserRole.superadmin ? 4 : -1` menjadi `role == UserRole.superadmin ? 5 : -1`
    - _Requirements: 2.1, 2.2_

  - [ ] 7.2 Tambahkan destination "Manajemen Akun" di `_ShellState.build` (NavigationRail)
    - Dalam blok `if (canManageUsers)` di list `destinations`, tambahkan `NavigationRailDestination` baru setelah destination "Pengguna":
      ```dart
      const NavigationRailDestination(
        icon: Icon(Icons.manage_accounts_outlined),
        selectedIcon: Icon(Icons.manage_accounts),
        label: Text('Manajemen Akun'),
      ),
      ```
    - Pastikan destination "Audit Log" dan "Live Update" superadmin tetap ada dan urutannya sesuai tabel di design (Audit Log sebelum Manajemen Akun untuk superadmin)
    - _Requirements: 2.1_

- [ ] 8. Final Checkpoint — Pastikan semua tugas selesai
  - Jalankan `flutter analyze` untuk memastikan tidak ada error kompilasi di `lib/main.dart`
  - Verifikasi semua requirements tercakup:
    - Req 1.1–1.7: LoginPage tanpa RegisterPage, `readableAuthError` sudah diperbarui
    - Req 2.1–2.23: Tab Manajemen Akun ada di admin/superadmin, AccountManagementPanel lengkap, edge function punya `create_student` dan `reset_account_password`
    - Req 3.1–3.7: UserManagementPanel tanpa tombol "Ubah Role" dan tanpa `_showChangeRoleDialog`
  - Pastikan semua tests pass, tanya pengguna jika ada pertanyaan.

---

## Notes

- Tasks 1 dan 2 (Tugas 1 dan Tugas 3) lebih sederhana dan bisa dikerjakan terlebih dahulu karena hanya menghapus kode
- Task 4 (edge function) harus dikerjakan sebelum Task 6 (UI Flutter yang memanggilnya)
- Task 7 (navigasi) harus dikerjakan setelah Task 6 karena mereferensikan `AccountManagementPanel`
- `path_provider` di pubspec (Task 3) bisa dikerjakan kapan saja sebelum flutter pub get
- Seluruh teks UI menggunakan Bahasa Indonesia sesuai requirements
- Service role key tidak pernah dikirim ke klien — semua operasi admin via edge function
- `AuthService.registerStudent()` dan `AuthService.updateUserRole()` **tidak diubah** (hanya dihapus pemanggilnya dari UI)

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "2.1", "2.2", "3.1"] },
    { "id": 1, "tasks": ["4.1", "4.2", "6.1"] },
    { "id": 2, "tasks": ["4.3", "6.2"] },
    { "id": 3, "tasks": ["6.3", "6.4", "6.5"] },
    { "id": 4, "tasks": ["6.6", "7.1"] },
    { "id": 5, "tasks": ["7.2"] }
  ]
}
```
