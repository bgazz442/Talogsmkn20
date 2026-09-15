import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { student, teacher, admin, superadmin }

class UserProfile {
  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.status,
    this.username,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final String status;
  final String? username;

  String get displayName {
    if (username != null && username!.trim().isNotEmpty) {
      return username!.trim();
    }
    if (fullName.trim().isNotEmpty) return fullName.trim();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Guest Explorer';
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final roleName = map['role']?.toString();
    final role = UserRole.values
        .where((value) => value.name == roleName)
        .firstOrNull;
    if (role == null) {
      throw const AuthException('PROFILE_ROLE_INVALID: role tidak dikenali.');
    }
    return UserProfile(
      id: map['id'].toString(),
      fullName: map['full_name']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      role: role,
      status: map['status']?.toString() ?? 'active',
      username: map['username']?.toString(),
    );
  }
}

class AuthService {
  AuthService(this.client);

  final SupabaseClient client;

  static String? validateUsername(String? value) {
    final clean = value?.trim().toLowerCase();
    if (clean == null || clean.isEmpty) {
      return 'Username tidak boleh kosong.';
    }
    if (clean.length < 3 || clean.length > 20) {
      return 'Username minimal 3 karakter dan maksimal 20 karakter.';
    }
    if (!RegExp(r'^[a-z0-9_]+$').hasMatch(clean)) {
      return 'Username hanya boleh berisi huruf kecil, angka, dan underscore.';
    }
    return null;
  }

  static String? validatePasswordUpdate({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) {
    if (currentPassword.trim().isEmpty) {
      return 'Password lama wajib diisi.';
    }
    if (newPassword.trim().isEmpty) {
      return 'Password baru wajib diisi.';
    }
    if (confirmPassword.trim().isEmpty) {
      return 'Konfirmasi password wajib diisi.';
    }
    if (newPassword.length < 6) {
      return 'Password baru minimal 6 karakter.';
    }
    if (newPassword != confirmPassword) {
      return 'Konfirmasi password tidak cocok dengan password baru.';
    }
    return null;
  }

  static String formatAuditError(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains('pgrst205') ||
        text.contains('could not find the table') ||
        text.contains('schema cache')) {
      return 'Gagal memuat aktivitas audit. Tabel audit log belum tersedia atau belum dapat diakses.';
    }

    if (text.contains('42501') ||
        text.contains('permission denied') ||
        text.contains('row-level security') ||
        text.contains('denied')) {
      return 'Akses audit log ditolak. Periksa izin admin.';
    }

    if (text.contains('timeout') ||
        text.contains('network') ||
        text.contains('socket')) {
      return 'Gagal memuat aktivitas audit. Silakan coba lagi.';
    }

    return 'Gagal memuat aktivitas audit. Silakan coba lagi.';
  }

  Future<void> changePassword(String newPassword) async {
    if (newPassword.length < 6) {
      throw const AuthException('Password baru minimal 6 karakter.');
    }
    await client.auth.updateUser(UserAttributes(password: newPassword));
    await logAudit(
      action: 'PASSWORD_CHANGED',
      description: 'Pengguna memperbarui kata sandi mandiri',
    );
  }

  Future<void> changePasswordWithCurrent({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final validationError = validatePasswordUpdate(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    if (validationError != null) {
      throw AuthException(validationError);
    }

    final currentUser = client.auth.currentUser;
    final email = currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) {
      throw const AuthException(
        'Sesi pengguna tidak tersedia. Silakan login kembali.',
      );
    }

    try {
      await client.auth.signInWithPassword(
        email: email,
        password: currentPassword,
      );
    } on AuthException {
      throw const AuthException('Password lama salah.');
    }

    await client.auth.updateUser(UserAttributes(password: newPassword));
    await logAudit(
      action: 'PASSWORD_CHANGED',
      description: 'Pengguna memperbarui kata sandi mandiri',
    );
  }

  Future<void> resetPassword(String email) async {
    await client.auth.resetPasswordForEmail(email.trim().toLowerCase());
  }

  Future<void> signOut() async {
    try {
      await logAudit(
        action: 'USER_LOGOUT',
        description: 'Pengguna keluar dari aplikasi',
      );
    } catch (_) {}
    await client.auth.signOut();
  }

  Future<UserProfile> signIn({
    required String loginInput,
    required String password,
  }) async {
    final trimmed = loginInput.trim();
    String targetEmail;

    if (trimmed.contains('@')) {
      targetEmail = trimmed.toLowerCase();
    } else {
      // Resolve username to email via secure server-side RPC
      try {
        final resolved = await client.rpc(
          'resolve_username_email',
          params: {'p_username': trimmed},
        );
        if (resolved == null || resolved.toString().trim().isEmpty) {
          throw const AuthException(
            'Username tidak ditemukan atau akun belum aktif.',
          );
        }
        targetEmail = resolved.toString().trim().toLowerCase();
      } catch (e) {
        if (e is AuthException) rethrow;
        debugPrint('Username login dependency unavailable: $e');
        throw const AuthException(
          'Login username belum tersedia. Gunakan email atau aktifkan contract username di database.',
        );
      }
    }

    late final AuthResponse response;
    try {
      response = await client.auth.signInWithPassword(
        email: targetEmail,
        password: password,
      );
      debugPrint('Auth signInWithPassword succeeded.');
    } on AuthException {
      debugPrint('Auth signInWithPassword failed.');
      rethrow;
    }

    final user = response.user;
    final session = response.session ?? client.auth.currentSession;
    debugPrint(
      'Auth session available: ${session != null}; user id available: ${user != null}',
    );
    if (user == null || session == null) {
      throw const AuthException(
        'SESSION_UNAVAILABLE: sesi login tidak tersedia.',
      );
    }

    late final UserProfile profile;
    try {
      profile = await getActiveProfile(user.id).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw const AuthException(
          'PROFILE_QUERY_ERROR: profile tidak merespons dalam 15 detik.',
        ),
      );
      debugPrint(
        'Profile loaded. role=${profile.role.name}; status=${profile.status}',
      );
    } on AuthException {
      debugPrint(
        'Profile load failed after successful Auth; preserving session.',
      );
      rethrow;
    } on PostgrestException catch (exception) {
      debugPrint(
        'Profile query failed after successful Auth; preserving session. code=${exception.code}',
      );
      throw AuthException(
        exception.code == '42501'
            ? 'PROFILE_RLS_DENIED: akses profile ditolak oleh RLS.'
            : 'PROFILE_QUERY_ERROR: profile tidak dapat dibaca.',
      );
    }

    await logAudit(
      action: 'USER_LOGIN',
      description: 'Pengguna berhasil login',
    );

    return profile;
  }

  Future<UserProfile> getCurrentProfile(String userId) async {
    final row = await client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (row == null) {
      debugPrint('Profile not found for authenticated user.');
      throw const AuthException(
        'PROFILE_NOT_FOUND: profile untuk user ini tidak ditemukan.',
      );
    }
    debugPrint('Profile row found for authenticated user.');
    return UserProfile.fromMap(row);
  }

  Future<UserProfile> getActiveProfile(String userId) async {
    final profile = await getCurrentProfile(userId);
    debugPrint(
      'Profile validation: role=${profile.role.name}; status=${profile.status}',
    );
    if (profile.status == 'pending') {
      throw const AuthException(
        'PROFILE_INACTIVE: akun masih menunggu konfirmasi undangan.',
      );
    }
    if (profile.status == 'disabled' || profile.status == 'inactive') {
      throw const AuthException('PROFILE_INACTIVE: akun sedang dinonaktifkan.');
    }
    if (profile.status != 'active') {
      throw const AuthException('PROFILE_INACTIVE: status akun tidak aktif.');
    }
    return profile;
  }

  Future<void> updateProfile({
    required String userId,
    String? fullName,
    String? username,
  }) async {
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null || currentUserId != userId) {
      throw const AuthException(
        'Akses profil ditolak. Anda hanya dapat mengubah akun sendiri.',
      );
    }

    final updates = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (fullName != null) {
      final cleanName = fullName.trim();
      if (cleanName.isEmpty) {
        throw const AuthException('Nama lengkap tidak boleh kosong.');
      }
      updates['full_name'] = cleanName;
    }

    if (username != null) {
      final validationError = validateUsername(username);
      if (validationError != null) {
        throw AuthException(validationError);
      }

      try {
        await client.from('profiles').select('username').limit(1);
      } on PostgrestException catch (error) {
        final normalized = error.message.toLowerCase();
        if (error.code == 'PGRST204' ||
            normalized.contains("could not find the 'username' column")) {
          throw const AuthException(
            'Schema Supabase belum memuat kolom profiles.username. Jalankan migrasi username resmi di server untuk mengaktifkan perubahan profil ini.',
          );
        }
        rethrow;
      }

      updates['username'] = username.trim().toLowerCase();
    }

    try {
      await client.from('profiles').update(updates).eq('id', userId);
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST204' ||
          error.message.toLowerCase().contains(
            "could not find the 'username' column",
          )) {
        throw const AuthException(
          'Kolom username belum tersedia di schema remote. Jalankan migrasi resmi 202609090002_fix_profiles_username.sql sebelum mengubah username.',
        );
      }
      if (error.code == '23505' ||
          error.message.toLowerCase().contains('unique')) {
        throw const AuthException(
          'Username sudah digunakan oleh akun lain. Silakan pilih username lain.',
        );
      }
      if (error.code == '42501' ||
          error.message.toLowerCase().contains('row-level security')) {
        throw const AuthException(
          'Akses profil ditolak oleh keamanan database.',
        );
      }
      rethrow;
    }

    await logAudit(
      action: 'PROFILE_UPDATED',
      description: 'Pengguna memperbarui data profil',
      targetUserId: userId,
      targetTable: 'profiles',
      targetRecordId: userId,
    );
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final clean = query.trim().toLowerCase();
    final rows = await client.rpc(
      'list_managed_users',
      params: {'p_query': clean},
    );
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> updateUserRole({
    required String userId,
    required String newRole,
  }) async {
    final cleanUserId = userId.trim();
    final cleanRole = newRole.trim();

    if (cleanUserId.isEmpty) {
      throw const AuthException('User target tidak valid.');
    }

    if (cleanRole.isEmpty) {
      throw const AuthException('Role baru tidak valid.');
    }

    const allowedRoles = {'student', 'teacher', 'admin'};
    if (!allowedRoles.contains(cleanRole)) {
      throw AuthException(
        'Role "$cleanRole" tidak valid untuk perubahan user.',
      );
    }

    try {
      await client.rpc(
        'update_user_role',
        params: {'p_new_role': cleanRole, 'p_user_id': cleanUserId},
      );
    } on PostgrestException catch (error) {
      final normalized =
          '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
              .toLowerCase();
      debugPrint(
        'update_user_role failed: type=${error.runtimeType} code=${error.code} message=${error.message} details=${error.details} hint=${error.hint}',
      );

      if (error.code == 'PGRST202' ||
          normalized.contains('could not find the function') ||
          normalized.contains('update_user_role')) {
        throw const AuthException(
          'Fungsi perubahan role tidak tersedia di database. Hubungi administrator sistem.',
        );
      }
      if (error.code == '42501' ||
          normalized.contains('permission denied') ||
          normalized.contains('row-level security')) {
        throw const AuthException(
          'Anda tidak memiliki izin untuk mengubah role user.',
        );
      }
      throw AuthException(
        'Gagal memperbarui role user. ${error.message.isNotEmpty ? error.message : 'Silakan coba lagi.'}',
      );
    } catch (error) {
      debugPrint(
        'update_user_role unexpected error: type=${error.runtimeType} value=$error',
      );
      throw AuthException(
        'Gagal memperbarui role user. ${error.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 50}) async {
    try {
      final rows = await client
          .from('audit_logs')
          .select('id, actor_role, action, description, metadata, created_at')
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(rows);
    } on PostgrestException catch (error) {
      final normalized =
          '${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
              .toLowerCase();
      debugPrint(
        'audit_logs unavailable: code=${error.code} message=${error.message} details=${error.details} hint=${error.hint}',
      );

      if (error.code == 'PGRST205' ||
          normalized.contains('could not find the table') ||
          normalized.contains('audit_logs')) {
        throw const AuthException('Audit log belum tersedia pada database.');
      }

      if (error.code == '42501' ||
          normalized.contains('permission denied') ||
          normalized.contains('row-level security') ||
          normalized.contains('denied')) {
        throw const AuthException(
          'Akses audit log ditolak. Periksa izin admin.',
        );
      }

      throw AuthException(
        'Gagal memuat aktivitas audit. ${error.message.isNotEmpty ? error.message : 'Silakan coba lagi.'}',
      );
    } catch (error) {
      debugPrint(
        'getAuditLogs unexpected error: type=${error.runtimeType} value=$error',
      );
      throw AuthException(
        'Gagal memuat aktivitas audit. ${error.toString().replaceAll('Exception: ', '')}',
      );
    }
  }

  Future<void> logAudit({
    required String action,
    String? description,
    String? targetUserId,
    String? targetTable,
    String? targetRecordId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await client.rpc(
        'log_audit_event',
        params: {
          'p_action': action,
          'p_description': description,
          'p_target_user_id': targetUserId,
          'p_target_table': targetTable,
          'p_target_record_id': targetRecordId,
          'p_metadata': metadata ?? {},
        },
      );
    } catch (error) {
      debugPrint('Audit logging unavailable for $action: $error');
    }
  }

  Future<void> registerStudent({
    required String fullName,
    required String email,
    required String departmentCode,
    required int attendanceNumber,
  }) async {
    final password = '$attendanceNumber$attendanceNumber$attendanceNumber';
    await client.auth.signUp(
      email: email.trim().toLowerCase(),
      password: password,
      data: {
        'full_name': fullName.trim(),
        'department_code': departmentCode.trim().toUpperCase(),
        'student_number': attendanceNumber,
        'role': 'student',
      },
    );
  }
}
