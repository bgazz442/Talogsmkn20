import 'dart:convert' as dart_convert;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
          todos(id, name, due_at, department_id, assigned_to),
          grades(id, score, feedback, graded_at, grader_user_id, source, needs_review)
        ''')
        .order('submitted_at', ascending: false)
        .limit(50);

    final studentIds = rows
        .map((row) => row['student_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    final profileMap = <String, Map<String, dynamic>>{};
    if (studentIds.isNotEmpty) {
      final profiles = await client
          .from('profiles')
          .select('id, full_name, email')
          .inFilter('id', studentIds);
      for (final profile in profiles) {
        final id = profile['id']?.toString();
        if (id != null && id.isNotEmpty) {
          profileMap[id] = Map<String, dynamic>.from(profile);
        }
      }
    }

    return rows.map((row) {
      final normalized = Map<String, dynamic>.from(row);
      final studentId = normalized['student_id']?.toString();
      if (studentId != null && profileMap.containsKey(studentId)) {
        normalized['student_profile'] = profileMap[studentId];
      }
      return normalized;
    }).toList();
  }

  Future<Map<String, dynamic>> gradeSubmission({
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
      'grader_user_id': graderId,
      'score': score,
      'feedback': feedback?.trim(),
      'graded_at': gradedAt,
    };

    if (role == 'teacher') {
      final teacher = await client
          .from('teachers')
          .select('id')
          .eq('id', graderId)
          .maybeSingle();
      if (teacher != null) {
        data['teacher_id'] = graderId;
      }
    }

    final existingGrade = await client
        .from('grades')
        .select('id')
        .eq('submission_id', submissionId)
        .maybeSingle();

    if (existingGrade != null) {
      await client
          .from('grades')
          .update(data)
          .eq('submission_id', submissionId);
    } else {
      await client.from('grades').insert(data);
    }

    try {
      await client
          .from('submissions')
          .update({'status': 'graded', 'updated_at': gradedAt})
          .eq('id', submissionId);
    } catch (e) {
      debugPrint('Submissions status update skipped/ignored: $e');
    }

    final savedGrade = await client
        .from('grades')
        .select('id, submission_id, score, feedback, grader_user_id, graded_at')
        .eq('submission_id', submissionId)
        .maybeSingle();

    return savedGrade ?? data;
  }

  Future<void> createTodo({
    required String name,
    required String description,
    required String departmentId,
    String? assignedTo,
    DateTime? dueAt,
    String submissionFormat = 'essai',
    List<String>? aiCriteria,
  }) async {
    final creatorId = (assignedTo != null && assignedTo.isNotEmpty)
        ? assignedTo
        : client.auth.currentUser?.id;
    final data = <String, dynamic>{
      'name': name.trim(),
      'description': description.trim(),
      'department_id': departmentId,
      if (creatorId != null && creatorId.isNotEmpty) 'assigned_to': creatorId,
      'submission_format': submissionFormat,
      if (aiCriteria != null && aiCriteria.isNotEmpty) 'ai_criteria': aiCriteria,
    };
    if (dueAt != null) data['due_at'] = dueAt.toUtc().toIso8601String();
    await client.from('todos').insert(data);
  }

  /// Panggil edge function file-grade untuk menilai submission FILE dengan AI.
  Future<Map<String, dynamic>> aiGradeFileSubmission({
    required String submissionId,
  }) async {
    final session = client.auth.currentSession;
    if (session == null) throw Exception('Belum masuk sesi.');

    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    if (supabaseUrl.isEmpty) throw Exception('SUPABASE_URL tidak dikonfigurasi.');

    final uri = Uri.parse('$supabaseUrl/functions/v1/file-grade');

    final http.Response resp;
    try {
      resp = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${session.accessToken}',
          'apikey': anonKey,
        },
        body: dart_convert.jsonEncode({'submission_id': submissionId}),
      );
    } catch (e) {
      throw Exception('Gagal terhubung ke server AI: $e');
    }

    if (resp.statusCode == 503) {
      final decoded = dart_convert.jsonDecode(resp.body) as Map<String, dynamic>;
      if (decoded['code']?.toString() == 'AI_NOT_CONFIGURED') {
        throw Exception('Fitur AI belum dikonfigurasi. Hubungi administrator untuk mengatur LLM_API_KEY.');
      }
    }
    if (resp.statusCode == 422) {
      final decoded = dart_convert.jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(decoded['error']?.toString() ?? 'Format file tidak dapat diproses oleh AI.');
    }
    if (resp.statusCode != 200) {
      final decoded = dart_convert.jsonDecode(resp.body) as Map<String, dynamic>;
      throw Exception(decoded['error']?.toString() ?? 'Gagal menilai file dengan AI.');
    }
    return dart_convert.jsonDecode(resp.body) as Map<String, dynamic>;
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

  /// Ambil kunci jawaban untuk satu tugas. Return null jika belum ada.
  Future<Map<String, dynamic>?> fetchAnswerKey(String todoId) async {
    try {
      final row = await client
          .from('answer_keys')
          .select('id, todo_id, question_type, answer_key, rubric, max_score, created_at')
          .eq('todo_id', todoId)
          .maybeSingle();
      return row != null ? Map<String, dynamic>.from(row) : null;
    } on PostgrestException catch (e) {
      if (e.code == 'PGRST116' ||
          e.message.toLowerCase().contains('answer_keys') ||
          e.message.toLowerCase().contains('does not exist')) {
        return null;
      }
      rethrow;
    }
  }

  /// Simpan atau perbarui kunci jawaban untuk satu tugas.
  Future<void> saveAnswerKey({
    required String todoId,
    required String questionType,
    required Map<String, dynamic> answerKey,
    String? rubric,
    double maxScore = 100,
  }) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) throw Exception('Belum masuk sesi.');
    final now = DateTime.now().toUtc().toIso8601String();
    await client.from('answer_keys').upsert({
      'todo_id':       todoId,
      'created_by':    userId,
      'question_type': questionType,
      'answer_key':    answerKey,
      'rubric':        rubric,
      'max_score':     maxScore,
      'updated_at':    now,
    }, onConflict: 'todo_id');
  }

  /// Jalankan penilaian otomatis untuk semua submission di satu tugas.
  Future<Map<String, dynamic>> autoGradeTodo(String todoId) async {
    try {
      final result = await client.rpc(
        'auto_grade_todo',
        params: {'p_todo_id': todoId},
      );
      if (result is Map) return Map<String, dynamic>.from(result);
      return {'graded': 0, 'skipped': 0, 'needs_ai': 0, 'errors': 0};
    } on PostgrestException catch (e) {
      throw Exception('Gagal menilai otomatis: ${e.message}');
    }
  }

  /// Cek apakah fitur AI aktif. Toleran jika tabel belum ada.
  Future<bool> fetchAiEnabled() async {
    try {
      final row = await client
          .from('app_settings')
          .select('value')
          .eq('key', 'ai_grading_enabled')
          .maybeSingle();
      if (row == null) return true;
      return row['value']?.toString() != 'false';
    } catch (_) {
      return true;
    }
  }

  /// Aktifkan atau nonaktifkan fitur AI grading.
  Future<void> setAiEnabled({required bool enabled}) async {
    try {
      await client.from('app_settings').upsert(
        {'key': 'ai_grading_enabled', 'value': enabled.toString()},
        onConflict: 'key',
      );
    } on PostgrestException catch (e) {
      final msg = '${e.message} ${e.details ?? ''} ${e.code ?? ''}'.toLowerCase();
      if (msg.contains('app_settings') ||
          msg.contains('does not exist') ||
          msg.contains('pgrst205') ||
          e.code == 'PGRST205') {
        // Tabel belum ada — abaikan, fitur AI tetap dapat digunakan
        return;
      }
      throw Exception('Gagal mengubah pengaturan AI: ${e.message}');
    } catch (e) {
      throw Exception('Gagal mengubah pengaturan AI: $e');
    }
  }

  static Map<String, dynamic>? _gradeMapStatic(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List && value.isNotEmpty && value.first is Map) {
      return Map<String, dynamic>.from(value.first as Map);
    }
    return null;
  }

  /// Ambil rekap nilai semua siswa × semua tugas.
  Future<Map<String, dynamic>> fetchGradeRecap({String? departmentId}) async {
    var baseQuery = client
        .from('todos')
        .select('id, name, due_at, departments(code, name)');
    if (departmentId != null && departmentId.isNotEmpty) {
      baseQuery = baseQuery.eq('department_id', departmentId);
    }
    final todos = List<Map<String, dynamic>>.from(
      await baseQuery.order('created_at', ascending: false),
    );

    final subsRaw = await client
        .from('submissions')
        .select('id, todo_id, student_id, submitted_at, grades(score, source, needs_review)')
        .order('submitted_at', ascending: false);
    final subs = List<Map<String, dynamic>>.from(subsRaw);

    final studentIds = subs
        .map((s) => s['student_id']?.toString())
        .whereType<String>()
        .toSet()
        .toList();

    final profilesRaw = studentIds.isEmpty
        ? <Map<String, dynamic>>[]
        : List<Map<String, dynamic>>.from(
            await client.from('profiles').select('id, full_name').inFilter('id', studentIds),
          );

    final profileMap = <String, String>{
      for (final p in profilesRaw) p['id'].toString(): p['full_name']?.toString() ?? 'Siswa',
    };

    final matrix = <String, Map<String, dynamic>>{};
    for (final sub in subs) {
      final sid = sub['student_id']?.toString() ?? '';
      final tid = sub['todo_id']?.toString() ?? '';
      if (sid.isEmpty || tid.isEmpty) continue;
      matrix[sid] ??= {'full_name': profileMap[sid] ?? 'Siswa', 'grades': <String, dynamic>{}};
      final g = _gradeMapStatic(sub['grades']);
      (matrix[sid]!['grades'] as Map)[tid] = {
        'score': g?['score'],
        'source': g?['source'] ?? 'manual',
        'needs_review': g?['needs_review'] ?? false,
      };
    }

    return {'todos': todos, 'matrix': matrix};
  }

}
