import 'package:flutter/foundation.dart';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardService {
  DashboardService(this.client);

  final SupabaseClient client;

  static const String assignmentSubmissionBucket = 'assignment-submissions';
  static const int maxSubmissionSizeBytes = 50 * 1024 * 1024;
  static final Set<String> allowedSubmissionExtensions = {
    'pdf',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'txt',
    'csv',
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
    'svg',
    'zip',
    'rar',
    '7z',
  };
  static final Set<String> allowedSubmissionMimeTypes = {
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/vnd.ms-excel',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-powerpoint',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'text/plain',
    'text/csv',
    'image/png',
    'image/jpeg',
    'image/gif',
    'image/webp',
    'image/bmp',
    'image/svg+xml',
    'application/zip',
    'application/vnd.rar',
    'application/x-7z-compressed',
  };

  static bool shouldPreferArchiveBeforeDelete(
    int submissionCount, {
    int gradeCount = 0,
  }) => submissionCount > 0 || gradeCount > 0;

  static String sanitizeSubmissionFileName(String fileName) {
    final trimmed = fileName.trim();
    final withoutSlashes = trimmed.replaceAll(RegExp(r'[\\/]'), '_');
    final cleaned = withoutSlashes.replaceAll(RegExp(r'\s+'), '_');
    final normalized = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (normalized.isEmpty || normalized == '.' || normalized == '..') {
      return 'upload_file';
    }
    return normalized;
  }

  static String detectMimeType({
    required String filePath,
    String? mimeType,
    String? fileName,
  }) {
    final explicit = (mimeType ?? '').trim();
    if (explicit.isNotEmpty) {
      final normalized = explicit.toLowerCase();
      if (normalized == 'application/octet-stream' ||
          normalized == 'application/jpeg') {
        // Ignore generic or invalid browser MIME values; resolve using extension.
      } else if (allowedSubmissionMimeTypes.contains(normalized)) {
        return normalized;
      } else if (normalized == 'application/x-jpeg' ||
          normalized == 'image/jpg' ||
          normalized == 'image/pjpeg') {
        return 'image/jpeg';
      } else if (normalized == 'application/x-pdf') {
        return 'application/pdf';
      }
    }

    final safePath = filePath.trim();
    final safeFileName = (fileName ?? '').trim();
    final lookupSource = safePath.isNotEmpty &&
            !safePath.startsWith('blob:') &&
            !safePath.startsWith('http://') &&
            !safePath.startsWith('https://')
        ? safePath
        : safeFileName.isNotEmpty
            ? safeFileName
            : safePath;

    final lookup = lookupMimeType(lookupSource);
    if (lookup != null && allowedSubmissionMimeTypes.contains(lookup.toLowerCase())) {
      return lookup.toLowerCase();
    }

    final extension = lookupSource.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      case 'csv':
        return 'text/csv';
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/vnd.rar';
      case '7z':
        return 'application/x-7z-compressed';
      default:
        throw Exception('Unsupported submission file type: .$extension');
    }
  }

  static String resolveSubmissionMimeType({
    required String fileName,
    String? detectedMime,
  }) {
    final extension = fileName.split('.').last.toLowerCase().trim();
    const mimeByExtension = <String, String>{
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'bmp': 'image/bmp',
      'svg': 'image/svg+xml',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt': 'text/plain',
      'csv': 'text/csv',
      'zip': 'application/zip',
      'rar': 'application/vnd.rar',
      '7z': 'application/x-7z-compressed',
    };

    final extensionMime = mimeByExtension[extension];
    if (extensionMime != null) {
      return extensionMime;
    }

    final normalizedDetected = (detectedMime ?? '').trim();
    if (normalizedDetected.isNotEmpty &&
        normalizedDetected != 'application/octet-stream' &&
        normalizedDetected != 'application/jpeg' &&
        allowedSubmissionMimeTypes.contains(normalizedDetected)) {
      return normalizedDetected;
    }

    throw Exception('Unsupported submission file type: .$extension');
  }

  static String? validateSubmissionFile({
    required String fileName,
    int? fileSize,
    String? mimeType,
    String? filePath,
  }) {
    final safeFileName = sanitizeSubmissionFileName(fileName);
    if (safeFileName.trim().isEmpty) return 'Nama file tidak valid.';
    final lowerName = safeFileName.toLowerCase();
    final extension = lowerName.split('.').last;
    if (extension.isEmpty || !allowedSubmissionExtensions.contains(extension)) {
      return 'Format file tidak didukung. Gunakan PDF, DOC, DOCX, XLS, XLSX, TXT, PNG, JPG, JPEG, GIF, WEBP, ZIP, atau RAR.';
    }

    final normalizedMimeType = resolveSubmissionMimeType(
      fileName: safeFileName,
      detectedMime: mimeType ?? detectMimeType(
        filePath: filePath ?? safeFileName,
        fileName: safeFileName,
        mimeType: mimeType,
      ),
    );
    if (!allowedSubmissionMimeTypes.contains(normalizedMimeType)) {
      return 'Tipe file tidak didukung oleh storage.';
    }

    final pathValue = filePath?.trim() ?? '';
    if (pathValue.contains('..') || (pathValue.contains('\\') && pathValue.contains('..'))) {
      return 'Lokasi file tidak valid.';
    }
    if (fileSize != null && fileSize > maxSubmissionSizeBytes) {
      return 'File terlalu besar. Maksimal ukuran file adalah 50 MiB.';
    }
    return null;
  }

  static String objectPathForSubmission({
    required String assignmentId,
    required String studentId,
    required String fileName,
  }) {
    final safeAssignmentId = sanitizeSubmissionFileName(assignmentId)
        .replaceAll(RegExp(r'\.'), '_');
    final safeStudentId = sanitizeSubmissionFileName(studentId)
        .replaceAll(RegExp(r'\.'), '_');
    final safeName = sanitizeSubmissionFileName(fileName);
    final uniqueSuffix = DateTime.now().toUtc().millisecondsSinceEpoch;
    return '$safeAssignmentId/$safeStudentId/${uniqueSuffix}_$safeName';
  }

  static String storagePathForSubmission({
    required String assignmentId,
    required String studentId,
    required String fileName,
  }) {
    return '$assignmentSubmissionBucket/${objectPathForSubmission(assignmentId: assignmentId, studentId: studentId, fileName: fileName)}';
  }

  static List<Map<String, dynamic>> filterTeacherTaskDepartments(
    List<Map<String, dynamic>> departments,
  ) {
    return departments.where((department) {
      final code = (department['code'] ?? '').toString().trim().toUpperCase();
      if (code.isEmpty) return true;
      return ![
        'TJKT',
        'TKJ',
        'JARINGAN',
      ].any((blocked) => code.contains(blocked));
    }).toList();
  }

  static String contentTypeForFileName(String fileName) {
    return detectMimeType(filePath: fileName);
  }

  Future<List<Map<String, dynamic>>> fetchDepartments() async {
    final rows = await client
        .from('departments')
        .select('id, code, name')
        .order('name');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchTodos({
    bool activeOnly = false,
  }) async {
    var query = client
        .from('todos')
        .select(
          'id, name, description, department_id, due_at, is_complete, created_at, departments(code, name)',
        );
    if (activeOnly) {
      query = query
          .eq('is_complete', false)
          .or(
            'due_at.is.null,due_at.gte.${DateTime.now().toUtc().toIso8601String()}',
          );
    }
    final rows = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> archiveTodo(String todoId, {required bool archived}) async {
    await client
        .from('todos')
        .update({
          'is_complete': archived,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', todoId);
  }

  Future<void> deleteTodo(String todoId) async {
    try {
      await client.from('todos').delete().eq('id', todoId);
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      if (message.contains('foreign key') ||
          message.contains('child') ||
          message.contains('violates') ||
          message.contains('submission')) {
        throw Exception(
          'Tugas tidak dapat dihapus karena masih memiliki data pengumpulan siswa. Gunakan Archive untuk menyembunyikan tugas.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, int>> getTodoUsage(String todoId) async {
    final rows = await client
        .from('submissions')
        .select('id, grades(id)')
        .eq('todo_id', todoId);

    var submissionCount = 0;
    var gradeCount = 0;
    for (final row in rows) {
      submissionCount += 1;
      final grades = row['grades'];
      if (grades is List) {
        gradeCount += grades.length;
      } else if (grades is Map && grades.isNotEmpty) {
        gradeCount += 1;
      }
    }
    return {'submissions': submissionCount, 'grades': gradeCount};
  }

  Future<int> countTaskSubmissions(String todoId) async {
    final rows = await client
        .from('submissions')
        .select('id')
        .eq('todo_id', todoId);
    return rows.length;
  }

  Future<List<Map<String, dynamic>>> fetchMySubmissions() async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await client
        .from('submissions')
        .select('''
          id,
          todo_id,
          file_path,
          file_name,
          file_size,
          mime_type,
          submission_type,
          content_text,
          status,
          note,
          submitted_at,
          updated_at,
          todos(name, due_at),
          grades(score, feedback, graded_at)
        ''')
        .eq('student_id', userId)
        .order('submitted_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> fetchMyTaskProgress() async {
    final todos = await fetchTodos();
    final submissions = await fetchMySubmissions();
    final submissionsByTodo = <String, Map<String, dynamic>>{
      for (final submission in submissions)
        submission['todo_id'].toString(): submission,
    };

    return todos.map((todo) {
      final progress = Map<String, dynamic>.from(todo);
      progress['submission'] = submissionsByTodo[todo['id']?.toString()];
      return progress;
    }).toList();
  }

  Future<void> submitAssignment({
    required String todoId,
    String? filePath,
    String? fileName,
    int? fileSize,
    String? mimeType,
    String? submissionType,
    String? contentText,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Belum masuk sesi.');

    final todo = await client
        .from('todos')
        .select('due_at')
        .eq('id', todoId)
        .maybeSingle();
    if (todo == null) {
      throw Exception('Tugas tidak ditemukan atau tidak dapat diakses.');
    }
    final dueAt = DateTime.tryParse(todo['due_at']?.toString() ?? '');
    if (dueAt != null && DateTime.now().toUtc().isAfter(dueAt.toUtc())) {
      throw Exception('Deadline tugas sudah lewat.');
    }

    final trimmedText = contentText?.trim();
    final normalizedType = (submissionType ?? '').trim().isNotEmpty
        ? submissionType!.trim()
        : ((trimmedText != null && trimmedText.isNotEmpty) &&
                  (filePath != null && filePath.isNotEmpty)
              ? 'text_and_file'
              : (filePath != null && filePath.isNotEmpty ? 'file' : 'text'));

    if (normalizedType == 'text' &&
        (trimmedText == null || trimmedText.isEmpty)) {
      throw Exception('Jawaban teks tidak boleh kosong.');
    }
    if (normalizedType == 'file' && (filePath == null || filePath.isEmpty)) {
      throw Exception('File tugas belum dipilih.');
    }
    if (normalizedType == 'text_and_file' &&
        (filePath == null || filePath.isEmpty) &&
        (trimmedText == null || trimmedText.isEmpty)) {
      throw Exception('Lengkapi jawaban teks atau file yang akan dikumpulkan.');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, dynamic>{
      'todo_id': todoId,
      'student_id': userId,
      'file_path': filePath?.trim().isNotEmpty == true
          ? filePath!.trim()
          : null,
      'file_name': fileName?.trim().isNotEmpty == true
          ? fileName!.trim()
          : null,
      'file_size': fileSize,
      'mime_type': mimeType?.trim().isNotEmpty == true
          ? mimeType!.trim()
          : null,
      'submission_type': normalizedType,
      'content_text': trimmedText?.isNotEmpty == true ? trimmedText : null,
      'status': 'submitted',
      'note': trimmedText,
      'submitted_at': now,
      'updated_at': now,
    };

    await client
        .from('submissions')
        .upsert(payload, onConflict: 'todo_id,student_id');
  }

  Future<String> uploadSubmissionFile({
    required String assignmentId,
    required String studentId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
    String? filePath,
  }) async {
    final currentUserId = client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Sesi user tidak tersedia.');
    if (bytes.isEmpty) throw Exception('File kosong tidak dapat diunggah.');

    final safeFileName = sanitizeSubmissionFileName(fileName);
    final resolvedFileName = safeFileName.isEmpty ? fileName : safeFileName;
    final sourcedFilePath = (filePath ?? '').trim();
    final effectiveFilePath = sourcedFilePath.isNotEmpty &&
            !sourcedFilePath.startsWith('blob:') &&
            !sourcedFilePath.startsWith('http://') &&
            !sourcedFilePath.startsWith('https://')
        ? sourcedFilePath
        : resolvedFileName;

    final detectedMime = detectMimeType(
      filePath: effectiveFilePath,
      fileName: resolvedFileName,
      mimeType: contentType,
    );
    final resolvedMimeType = resolveSubmissionMimeType(
      fileName: fileName,
      detectedMime: detectedMime,
    );
    if (resolvedMimeType == 'application/jpeg') {
      throw Exception('MIME type tidak valid. Gunakan image/jpeg untuk JPG/JPEG.');
    }

    final validation = validateSubmissionFile(
      fileName: fileName,
      fileSize: bytes.length,
      mimeType: resolvedMimeType,
      filePath: filePath ?? fileName,
    );
    if (validation != null) throw Exception(validation);

    final relativePath = objectPathForSubmission(
      assignmentId: assignmentId,
      studentId: studentId,
      fileName: fileName,
    );
    final fullStoragePath = storagePathForSubmission(
      assignmentId: assignmentId,
      studentId: studentId,
      fileName: fileName,
    );
    final extension = resolvedFileName.split('.').last.toLowerCase();
    debugPrint('UPLOAD DEBUG');
    debugPrint('fileName=$resolvedFileName');
    debugPrint('filePath=$effectiveFilePath');
    debugPrint('extension=$extension');
    debugPrint('resolvedMime=$resolvedMimeType');
    debugPrint('bucket=assignment-submissions');
    debugPrint('UPLOAD MIME: file=$resolvedFileName ext=$extension mime=$resolvedMimeType');
    debugPrint('UPLOAD START');

    try {
      await client.storage
          .from(assignmentSubmissionBucket)
          .uploadBinary(
            relativePath,
            bytes,
            fileOptions: FileOptions(
              contentType: resolvedMimeType,
              upsert: false,
            ),
          );
      debugPrint('UPLOAD SUCCESS');
    } on StorageException catch (error) {
      final statusCode = (() {
        try {
          return (error as dynamic).statusCode?.toString();
        } catch (_) {
          return null;
        }
      })();
      final errorMessage = (() {
        try {
          return (error as dynamic).message?.toString();
        } catch (_) {
          return null;
        }
      })();
      final errorDetails = (() {
        try {
          return (error as dynamic).error?.toString();
        } catch (_) {
          return null;
        }
      })();
      final fullErrorText = [
        statusCode,
        errorMessage,
        errorDetails,
        error.toString(),
      ].whereType<String>().join(' ').toLowerCase();

      debugPrint(
        'Storage upload failure => statusCode=$statusCode, '
        'message=${errorMessage ?? 'n/a'}, error=${errorDetails ?? 'n/a'}, '
        'raw=${error.toString()}',
      );

      if (statusCode == '404' ||
          fullErrorText.contains('bucket') &&
              (fullErrorText.contains('not found') ||
                  fullErrorText.contains('missing'))) {
        throw Exception(
          'Bucket Supabase $assignmentSubmissionBucket belum tersedia di storage.',
        );
      }
      if (fullErrorText.contains('permission') ||
          fullErrorText.contains('unauthorized') ||
          fullErrorText.contains('forbidden') ||
          fullErrorText.contains('policy')) {
        throw Exception(
          'Akses upload file ditolak oleh policy storage. Pastikan bucket $assignmentSubmissionBucket hanya mengizinkan upload authenticated user pada path $assignmentId/$studentId/ dan RLS/storage policy tetap aman.',
        );
      }
      if (statusCode == '415' ||
          fullErrorText.contains('invalid_mime_type') ||
          fullErrorText.contains('mime type') ||
          fullErrorText.contains('mime')) {
        throw Exception(
          'Tipe file yang dikirim tidak didukung oleh Supabase Storage. Gunakan JPG/JPEG sebagai image/jpeg, PNG sebagai image/png, atau PDF sebagai application/pdf.',
        );
      }
      if (fullErrorText.contains('network') ||
          fullErrorText.contains('socket') ||
          fullErrorText.contains('timeout')) {
        throw Exception('Koneksi bermasalah saat upload file.');
      }

      throw Exception(
        'Upload file gagal: ${errorMessage ?? errorDetails ?? error.toString()}',
      );
    }
    return fullStoragePath;
  }

  Future<List<Map<String, dynamic>>> fetchStaffSubmissions() async {
    final rows = await client
        .from('submissions')
        .select('''
          id,
          todo_id,
          student_id,
          file_path,
          file_name,
          file_size,
          mime_type,
          submission_type,
          content_text,
          status,
          note,
          submitted_at,
          updated_at,
          todos(name, due_at),
          students!student_id(profiles(full_name, email)),
          grades(id, score, feedback, graded_at)
        ''')
        .order('submitted_at', ascending: false)
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> gradeSubmission({
    required String submissionId,
    required double score,
    String? feedback,
  }) async {
    final graderId = client.auth.currentUser?.id;
    if (graderId == null) throw Exception('Belum masuk sesi.');

    final profile = await client
        .from('profiles')
        .select('role')
        .eq('id', graderId)
        .single();
    final role = profile['role']?.toString();
    if (role != 'teacher' && role != 'admin' && role != 'superadmin') {
      throw Exception('Role tidak memiliki izin untuk memberi nilai.');
    }

    final gradedAt = DateTime.now().toUtc().toIso8601String();
    final data = <String, dynamic>{
      'submission_id': submissionId,
      'score': score,
      'feedback': feedback?.trim(),
      'graded_at': gradedAt,
      'grader_user_id': graderId,
    };

    if (role == 'teacher') {
      final teacher = await client
          .from('teachers')
          .select('id')
          .eq('id', graderId)
          .maybeSingle();
      if (teacher == null) {
        throw Exception(
          'Akun teacher belum memiliki record teacher yang valid. Jalankan onboarding staff resmi (manage-staff/accept) agar record public.teachers dibuat sebelum memberi nilai.',
        );
      }
      data['teacher_id'] = graderId;
    } else {
      data['teacher_id'] = null;
    }

    await client.from('grades').upsert(data, onConflict: 'submission_id');
    await client
        .from('submissions')
        .update({'status': 'graded', 'updated_at': gradedAt})
        .eq('id', submissionId);
  }

  Future<void> createTodo({
    required String name,
    required String description,
    required String departmentId,
    DateTime? dueAt,
  }) async {
    final data = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      'department_id': departmentId,
    };
    if (dueAt != null) data['due_at'] = dueAt.toUtc().toIso8601String();
    await client.from('todos').insert(data);
  }

  Future<String?> submissionDownloadUrl(String? storagePath) async {
    if (storagePath == null || storagePath.trim().isEmpty) return null;
    try {
      final relativePath =
          storagePath.startsWith('$assignmentSubmissionBucket/')
          ? storagePath.replaceFirst('$assignmentSubmissionBucket/', '')
          : storagePath;
      final response = await client.storage
          .from(assignmentSubmissionBucket)
          .createSignedUrl(relativePath, 3600);
      return response;
    } catch (_) {
      return null;
    }
  }

  RealtimeChannel watchTable({
    required String channelName,
    required String table,
    required void Function(PostgresChangePayload payload) onChange,
  }) => client
      .channel(channelName)
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        callback: onChange,
      )
      .subscribe();
}
