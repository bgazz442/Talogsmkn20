# Design Document

## Feature: talog20-perbaikan-lengkap

---

## Overview

Perbaikan ini mencakup tiga perubahan saling berkaitan pada aplikasi TALog20 (Flutter + Supabase):

1. **Tugas 1** — Hapus registrasi mandiri: `RegisterPage` dihapus dari UI, navigasi ke-nya dihapus dari `LoginPage`, dan pesan error `PROFILE_NOT_FOUND` diperbarui.
2. **Tugas 2** — Panel manajemen akun baru (`AccountManagementPanel`) untuk admin/superadmin, didukung oleh action baru `create_student` di edge function `manage-staff`.
3. **Tugas 3** — Hapus tombol "Ubah Role" dan method `_showChangeRoleDialog` dari `UserManagementPanel`.

Prinsip utama: service role key tetap hanya di edge function, semua teks UI berbahasa Indonesia, tidak ada perubahan signature metode yang sudah ada.

---

## Architecture

```
Flutter App (Client)
├── LoginPage               ← HAPUS tombol RegisterPage, UPDATE readableAuthError
├── RegisterPage            ← HAPUS widget ini
├── AccountManagementPanel  ← BARU: form buat akun, daftar, import CSV
├── UserManagementPanel     ← HAPUS _showChangeRoleDialog, HAPUS tombol "Ubah Role"
├── RoleDashboard           ← TAMBAH tab "Manajemen Akun" + routing
└── Shell (NavigationRail)  ← TAMBAH destination "Manajemen Akun"

AuthService (lib/auth_service.dart)
├── registerStudent()       ← DIPERTAHANKAN tanpa perubahan
├── updateUserRole()        ← DIPERTAHANKAN tanpa perubahan
└── logAudit()              ← DIGUNAKAN oleh AccountManagementPanel

Supabase Edge Function (manage-staff/index.ts)
├── createInvitation()      ← TIDAK DIUBAH
├── acceptInvitation()      ← TIDAK DIUBAH
├── updateStaffStatus()     ← TIDAK DIUBAH
├── createStudent()         ← BARU: buat akun siswa langsung active
└── resetAccountPassword()  ← BARU: reset password via PATCH /reset-password

pubspec.yaml
└── path_provider: ^2.1.4   ← DITAMBAHKAN
```

---

## Components

### 1. LoginPage (modifikasi)

**Perubahan:**
- Hapus `Center(child: TextButton(...RegisterPage...))` dari `Column` di `build()`.
- Perbarui `readableAuthError`: ubah handler `profile_not_found` menjadi mengembalikan `"Akun belum terdaftar. Hubungi admin sekolah untuk dibuatkan akun."`.

**Yang tidak berubah:**
- Form login (email/username + password).
- Tombol "Lupa password?" dan `_ResetPasswordDialog`.
- `ActionButton('Masuk')`.

### 2. RegisterPage (dihapus)

Seluruh kelas `RegisterPage` dan `_RegisterPageState` dihapus dari `lib/main.dart`. Tidak ada referensi navigasi ke kelas ini yang tersisa.

### 3. AccountManagementPanel (baru)

Widget `StatefulWidget` baru di `lib/main.dart` dengan dua sub-panel:

#### Sub-panel A: Form Pembuatan Akun

```dart
// Kolom input:
TextEditingController nameController;       // Nama lengkap
TextEditingController emailController;      // Email
TextEditingController usernameController;   // Username
DropdownButton<String> roleDropdown;        // student | teacher | admin
DropdownButton<String?> departmentDropdown; // tampil HANYA jika role == 'student'
TextEditingController passwordController;   // auto-generate, bisa disalin

// Tombol:
// [Salin Password]  [Simpan Akun]  [Import CSV]
```

**Logika pembuatan akun:**
- Jika role == `student` → POST ke `/manage-staff/create-student`
- Jika role == `teacher` atau `admin` → POST ke `/manage-staff` (createInvitation, path yang sudah ada)
- Setelah berhasil → panggil `AuthService.logAudit(action: 'ACCOUNT_CREATED', ...)`

**Password auto-generate:**
```dart
String _generatePassword() {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
}
```

#### Sub-panel B: Daftar Pengguna & Aksi

- Daftar pengguna dari `AuthService.searchUsers('')` (semua pengguna).
- Per baris: nama, email, badge role (read-only), status.
- Tombol aksi: **Nonaktifkan** (jika status active) / **Aktifkan** (jika status disabled) → PATCH ke `/manage-staff` (updateStaffStatus yang sudah ada).
- Tombol **Reset Password**: tampil dialog input password baru → PATCH ke `/manage-staff/reset-password`.
- Audit log otomatis setelah setiap aksi.

#### Sub-panel C: Import CSV

```dart
// Format CSV (header): nama,email,username,kelas
// Proses per baris:
// 1. Parse baris → data siswa
// 2. Panggil create_student
// 3. Kumpulkan hasil: List<ImportResult> {baris, nama, status, alasan?}
// 4. Tampilkan ringkasan dialog
```

### 4. UserManagementPanel (modifikasi)

**Dihapus:**
- Method `_showChangeRoleDialog(Map<String, dynamic> user)`
- `OutlinedButton` dengan teks `'Ubah Role'` dari `itemBuilder` di `ListView.separated`

**Dipertahankan:**
- Search bar + tombol Cari
- Daftar pengguna dengan badge role (read-only, warna berdasarkan role)
- Layout responsif

### 5. RoleDashboard & Shell (modifikasi navigasi)

**Tab index baru untuk admin:**

| Tab | Teacher | Admin | Superadmin |
|-----|---------|-------|------------|
| 0   | Overview | Overview | Overview |
| 1   | Tugas | Tugas | Tugas |
| 2   | Pengumpulan | Pengguna | Pengguna |
| 3   | — | Manajemen Akun | Audit Log |
| 4   | — | — | Manajemen Akun (superadmin) |
| 5   | — | — | Live Update |

> **Catatan desain:** Tab "Manajemen Akun" ditempatkan setelah "Pengguna" di kedua role admin dan superadmin. Untuk superadmin: tab 4. Untuk admin: tab 3.

**Perubahan `_buildContentForTab` di `_RoleDashboardState`:**

```dart
Widget _buildContentForTab(int tab) {
  if (tab == 0) return _buildOverview();
  if (tab == 1) return StaffTasksPanel(profile: widget.profile);
  if (tab == 2 && role == UserRole.teacher) return StaffSubmissionsPanel(profile: widget.profile);
  if (tab == 2 && canManageUsers) return const UserManagementPanel();
  if (tab == 3 && role == UserRole.superadmin) return const AuditLogsPanel();
  if (tab == 3 && role == UserRole.admin) return const AccountManagementPanel();  // BARU
  if (tab == 4 && role == UserRole.superadmin) return const AccountManagementPanel();  // BARU
  if (tab == 5 && canViewLiveUpdate) return const LiveUpdatePage(); // DIGESER dari 4 ke 5
  return _buildOverview();
}
```

> **Catatan:** `liveUpdateTab` getter perlu diperbarui: `role == UserRole.superadmin ? 5 : -1`.

**Perubahan destinations di `_ShellState.build`:**

```dart
if (canManageUsers) ...[
  const NavigationRailDestination(
    icon: Icon(Icons.people_outline),
    selectedIcon: Icon(Icons.people),
    label: Text('Pengguna'),
  ),
  const NavigationRailDestination(    // BARU
    icon: Icon(Icons.manage_accounts_outlined),
    selectedIcon: Icon(Icons.manage_accounts),
    label: Text('Manajemen Akun'),
  ),
],
if (role == UserRole.superadmin)
  const NavigationRailDestination(
    icon: Icon(Icons.security_outlined),
    selectedIcon: Icon(Icons.security),
    label: Text('Audit Log'),
  ),
if (role == UserRole.superadmin)
  const NavigationRailDestination(
    icon: Icon(Icons.dynamic_feed_outlined),
    selectedIcon: Icon(Icons.dynamic_feed),
    label: Text('Live Update'),
  ),
```

---

## Data Models

### CreateStudentRequest (ke edge function)

```dart
// Dikirim sebagai JSON body ke POST /manage-staff/create-student
{
  "full_name": String,      // required, 2-160 chars
  "email": String,          // required, valid email
  "username": String,       // required, 3-20 chars, [a-z0-9_]
  "department_id": String?, // opsional UUID
  "password": String        // required, min 8 chars
}
```

### ResetPasswordRequest (ke edge function)

```dart
// Dikirim sebagai JSON body ke PATCH /manage-staff/reset-password
{
  "user_id": String,        // required, UUID
  "new_password": String    // required, min 8 chars
}
```

### ImportResult

```dart
class ImportResult {
  final int rowIndex;
  final String name;
  final String email;
  final bool success;
  final String? errorMessage;
}
```

---

## Interfaces

### Edge Function: `create_student` action

**Request:** `POST /manage-staff/create-student`
**Auth:** Bearer token (anon key + user JWT)
**Body:** `CreateStudentRequest`

**Flow server-side:**
1. Validasi token JWT → cek profil actor (admin/superadmin)
2. Validasi input (`full_name`, `email`, `username`, `password`)
3. Cek duplikat email di `profiles`
4. `adminClient.auth.admin.createUser({ email, password, email_confirm: true })`
5. Insert ke `profiles` dengan `status: 'active'`, `role: 'student'`
6. Insert ke `students` dengan `id`, `department_id` (jika ada)
7. Return `201` dengan data akun

**Responses:**
- `201`: `{ user: { id, email, full_name } }`
- `400`: validasi gagal
- `409`: email sudah terdaftar di profiles
- `500`: error internal

### Edge Function: `reset_account_password` action

**Request:** `PATCH /manage-staff/reset-password`
**Auth:** Bearer token
**Body:** `ResetPasswordRequest`

**Flow server-side:**
1. Validasi token JWT → cek profil actor (admin/superadmin)
2. Validasi `user_id` (UUID) dan `new_password` (min 8 chars)
3. `adminClient.auth.admin.updateUserById(user_id, { password: new_password })`
4. Return `200` dengan `{ user_id, message: 'Password berhasil direset' }`

---

## Error Handling

### Flutter (AccountManagementPanel)

| Kondisi | Tampilan |
|---------|----------|
| Network error | SnackBar: "Gagal terhubung ke server. Periksa koneksi Anda." |
| HTTP 409 | SnackBar: "Email sudah terdaftar." |
| HTTP 400 | SnackBar: pesan dari server |
| HTTP 403 | SnackBar: "Anda tidak memiliki izin untuk aksi ini." |
| CSV parse error | Baris ditandai gagal, proses baris lain tetap berjalan |
| Import selesai | Dialog ringkasan: jumlah berhasil / gagal dengan detail per baris |

### Edge Function (manage-staff)

| Kondisi | Respons |
|---------|---------|
| Email sudah ada di profiles | 409 |
| Input tidak valid | 400 |
| Auth/JWT invalid | 401 |
| Actor bukan admin/superadmin | 403 |
| createUser gagal | 400 (pesan dari Supabase Auth) |
| Insert profiles gagal | 500 (rollback: deleteUser) |
| Insert students gagal | 500 (rollback: delete profiles + deleteUser) |

---

## Security Considerations

- **Service role key** hanya digunakan di edge function Deno, tidak pernah dikirim ke klien Flutter.
- **JWT validation** dilakukan di `authenticatedClient()` sebelum semua operasi admin.
- **Password auto-generate** menggunakan `Random.secure()` (cryptographically secure).
- **Role authorization**: admin hanya bisa membuat student, superadmin bisa membuat student/admin.
- **Import CSV**: setiap baris divalidasi secara individual sebelum dikirim ke server.

---

## pubspec.yaml

Tambahkan ke blok `dependencies`:

```yaml
path_provider: ^2.1.4
```

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

---

### Property 1: readableAuthError PROFILE_NOT_FOUND selalu mengembalikan pesan yang benar

*For any* string yang mengandung substring `profile_not_found` (case-insensitive), fungsi `readableAuthError` SHALL mengembalikan tepat string `"Akun belum terdaftar. Hubungi admin sekolah untuk dibuatkan akun."`.

**Validates: Requirements 1.6**

---

### Property 2: Password auto-generate selalu valid

*For any* pemanggilan fungsi `_generatePassword()` di `AccountManagementPanel`, string yang dihasilkan SHALL memiliki panjang minimal 8 karakter dan hanya berisi karakter alfanumerik (`[a-zA-Z0-9]`).

**Validates: Requirements 2.4**

---

### Property 3: Tab "Manajemen Akun" hanya muncul untuk admin dan superadmin

*For any* profil pengguna dengan role `admin` atau `superadmin`, daftar NavigationRail destinations SHALL mengandung destination dengan label `"Manajemen Akun"`. *For any* profil dengan role `teacher` atau `student`, daftar tersebut SHALL tidak mengandung destination tersebut.

**Validates: Requirements 2.1**

---

### Property 4: CSV parsing menghasilkan jumlah record yang sesuai dengan baris valid

*For any* string CSV dengan N baris data yang valid (non-empty, memiliki kolom nama, email, username, kelas), parser CSV di `AccountManagementPanel` SHALL menghasilkan tepat N objek `ImportResult` yang siap diproses.

**Validates: Requirements 2.16**

---

### Property 5: Import CSV mengisolasi kegagalan per baris

*For any* input CSV yang mengandung K baris dengan email duplikat dan M baris dengan data valid, setelah pemrosesan selesai hasil import SHALL memiliki tepat K entri dengan `success == false` dan M entri dengan `success == true`, tanpa menghentikan proses karena satu kegagalan.

**Validates: Requirements 2.17**

---

### Property 6: UserManagementPanel tidak mengandung tombol Ubah Role

*For any* daftar pengguna yang ditampilkan oleh `UserManagementPanel`, tidak ada satu pun widget berteks `"Ubah Role"` yang muncul di dalam daftar tersebut, terlepas dari role atau jumlah pengguna yang ditampilkan.

**Validates: Requirements 3.1**

