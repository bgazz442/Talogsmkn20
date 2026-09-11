import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:talog20/auth_service.dart';
import 'package:talog20/dashboard_service.dart';
import 'package:talog20/main.dart';

void main() {
  test('audit error formatter hides raw PostgrestException output', () {
    final message = AuthService.formatAuditError(
      "PostgrestException(message: Could not find the table 'public.audit_logs' in the schema cache, code: PGRST205, details: Not Found)",
    );

    expect(message, contains('Gagal memuat aktivitas audit'));
    expect(message, isNot(contains('PGRST205')));
    expect(message, isNot(contains('public.audit_logs')));
  });

  test('task delete policy prefers archive when submissions or grades exist', () {
    expect(DashboardService.shouldPreferArchiveBeforeDelete(0), isFalse);
    expect(DashboardService.shouldPreferArchiveBeforeDelete(1), isTrue);
    expect(DashboardService.shouldPreferArchiveBeforeDelete(0, gradeCount: 1), isTrue);
  });

  test('teacher task department filter hides TJKT and related networking departments only in task creation UI', () {
    final departments = [
      {'id': '1', 'code': 'TJKT', 'name': 'Teknik Jaringan Komputer'},
      {'id': '2', 'code': 'TKJ', 'name': 'Teknik Komputer Jaringan'},
      {'id': '3', 'code': 'RPL', 'name': 'Rekayasa Perangkat Lunak'},
      {'id': '4', 'code': 'BDP', 'name': 'Bisnis Daring Pemasaran'},
    ];

    final visible = DashboardService.filterTeacherTaskDepartments(departments);

    expect(visible.map((e) => e['code']), equals(['RPL', 'BDP']));
  });

  test('submission MIME detection uses standards-compliant types for supported files', () {
    expect(DashboardService.detectMimeType(filePath: 'photo.jpg'), equals('image/jpeg'));
    expect(DashboardService.detectMimeType(filePath: 'photo.jpeg'), equals('image/jpeg'));
    expect(DashboardService.detectMimeType(filePath: 'logo.png'), equals('image/png'));
    expect(DashboardService.detectMimeType(filePath: 'image.gif'), equals('image/gif'));
    expect(DashboardService.detectMimeType(filePath: 'image.webp'), equals('image/webp'));
    expect(DashboardService.detectMimeType(filePath: 'image.bmp'), equals('image/bmp'));
    expect(DashboardService.detectMimeType(filePath: 'logo.svg'), equals('image/svg+xml'));
    expect(DashboardService.detectMimeType(filePath: 'notes.pdf'), equals('application/pdf'));
    expect(DashboardService.detectMimeType(filePath: 'notes.doc'), equals('application/msword'));
    expect(DashboardService.detectMimeType(filePath: 'notes.docx'), equals('application/vnd.openxmlformats-officedocument.wordprocessingml.document'));
    expect(DashboardService.detectMimeType(filePath: 'sheet.xls'), equals('application/vnd.ms-excel'));
    expect(DashboardService.detectMimeType(filePath: 'sheet.xlsx'), equals('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'));
    expect(DashboardService.detectMimeType(filePath: 'deck.ppt'), equals('application/vnd.ms-powerpoint'));
    expect(DashboardService.detectMimeType(filePath: 'deck.pptx'), equals('application/vnd.openxmlformats-officedocument.presentationml.presentation'));
    expect(DashboardService.detectMimeType(filePath: 'data.txt'), equals('text/plain'));
    expect(DashboardService.detectMimeType(filePath: 'data.csv'), equals('text/csv'));
    expect(DashboardService.detectMimeType(filePath: 'archive.zip'), equals('application/zip'));
    expect(DashboardService.detectMimeType(filePath: 'archive.rar'), equals('application/vnd.rar'));
    expect(DashboardService.detectMimeType(filePath: 'archive.7z'), equals('application/x-7z-compressed'));
    expect(
      DashboardService.detectMimeType(
        filePath: 'photo.jpeg',
        mimeType: 'application/jpeg',
      ),
      equals('image/jpeg'),
    );
  });

  test('submission validation blocks unsupported or oversized files before upload', () {
    expect(
      DashboardService.validateSubmissionFile(
        fileName: 'photo.jpg',
        fileSize: 2 * 1024 * 1024,
      ),
      isNull,
    );
    expect(
      DashboardService.validateSubmissionFile(
        fileName: 'photo.jpeg',
        fileSize: 2 * 1024 * 1024,
        mimeType: 'image/jpeg',
      ),
      isNull,
    );
    expect(
      DashboardService.validateSubmissionFile(
        fileName: 'file.docx',
        fileSize: 2 * 1024 * 1024,
      ),
      isNull,
    );
    expect(
      DashboardService.validateSubmissionFile(
        fileName: 'file.pptx',
        fileSize: 2 * 1024 * 1024,
      ),
      isNull,
    );
    expect(
      DashboardService.validateSubmissionFile(
        fileName: 'file.7z',
        fileSize: 2 * 1024 * 1024,
      ),
      isNull,
    );
    expect(
      DashboardService.validateSubmissionFile(
        fileName: 'layout.exe',
        fileSize: 1024,
      ),
      contains('Format file tidak didukung'),
    );
    expect(
      DashboardService.validateSubmissionFile(
        fileName: 'large.pdf',
        fileSize: DashboardService.maxSubmissionSizeBytes + 1,
        mimeType: 'application/pdf',
      ),
      contains('File terlalu besar'),
    );
  });

  test('application/jpeg is never normalized for Supabase upload payload', () {
    final mimeType = DashboardService.detectMimeType(
      filePath: 'report.jpeg',
      mimeType: 'application/jpeg',
    );

    expect(mimeType, equals('image/jpeg'));
    expect(mimeType, isNot(equals('application/jpeg')));
  });

  test('submission MIME resolution prefers file extension over raw browser octet-stream', () {
    expect(
      DashboardService.resolveSubmissionMimeType(
        fileName: 'file.pdf',
        detectedMime: 'application/octet-stream',
      ),
      equals('application/pdf'),
    );
    expect(
      DashboardService.resolveSubmissionMimeType(
        fileName: 'file.png',
        detectedMime: 'application/octet-stream',
      ),
      equals('image/png'),
    );
    expect(
      DashboardService.resolveSubmissionMimeType(
        fileName: 'file.jpg',
        detectedMime: 'application/octet-stream',
      ),
      equals('image/jpeg'),
    );
    expect(
      DashboardService.resolveSubmissionMimeType(
        fileName: 'file.jpeg',
        detectedMime: 'application/octet-stream',
      ),
      equals('image/jpeg'),
    );
    expect(
      DashboardService.resolveSubmissionMimeType(
        fileName: 'file.docx',
        detectedMime: 'application/octet-stream',
      ),
      equals(
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      ),
    );
    expect(
      DashboardService.resolveSubmissionMimeType(
        fileName: 'file.pptx',
        detectedMime: 'application/octet-stream',
      ),
      equals(
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      ),
    );
    expect(
      DashboardService.resolveSubmissionMimeType(
        fileName: 'file.xlsx',
        detectedMime: 'application/octet-stream',
      ),
      equals(
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ),
    );
  });

  test('student password validation requires old password and matching confirmation', () {
    expect(
      AuthService.validatePasswordUpdate(
        currentPassword: '',
        newPassword: 'secret123',
        confirmPassword: 'secret123',
      ),
      'Password lama wajib diisi.',
    );
    expect(
      AuthService.validatePasswordUpdate(
        currentPassword: 'oldpass',
        newPassword: 'new',
        confirmPassword: 'new',
      ),
      'Password baru minimal 6 karakter.',
    );
    expect(
      AuthService.validatePasswordUpdate(
        currentPassword: 'oldpass',
        newPassword: 'secret123',
        confirmPassword: 'secret456',
      ),
      'Konfirmasi password tidak cocok dengan password baru.',
    );
    expect(
      AuthService.validatePasswordUpdate(
        currentPassword: 'oldpass',
        newPassword: 'secret123',
        confirmPassword: 'secret123',
      ),
      isNull,
    );
  });

  testWidgets('admin dashboard hides audit and live update while teacher is kept on admin dashboard', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RoleDashboard(
          profile: const UserProfile(
            id: 'admin-id',
            fullName: 'Admin User',
            email: 'admin@example.com',
            role: UserRole.admin,
            status: 'active',
          ),
        ),
      ),
    );

    expect(find.text('Pengguna'), findsOneWidget);
    expect(find.text('Audit Log'), findsNothing);
    expect(find.text('Live Update'), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: RoleDashboard(
          profile: const UserProfile(
            id: 'teacher-id',
            fullName: 'Teacher User',
            email: 'teacher@example.com',
            role: UserRole.teacher,
            status: 'active',
          ),
        ),
      ),
    );

    expect(find.text('Pengumpulan'), findsOneWidget);
    expect(find.text('Pengguna'), findsNothing);
    expect(find.text('Audit Log'), findsNothing);
    expect(find.text('Live Update'), findsNothing);
  });

  testWidgets('password visibility button toggles password text', (WidgetTester tester) async {
    final controller = TextEditingController(text: '141414');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InputField(
            label: 'Password',
            hint: 'Masukkan password',
            password: true,
            controller: controller,
          ),
        ),
      ),
    );

    final textField = tester.widget<TextField>(find.byType(TextField));
    expect(textField.obscureText, isTrue);

    await tester.tap(find.byTooltip('Tampilkan password'));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
    expect(find.byTooltip('Sembunyikan password'), findsOneWidget);
  });

  testWidgets('staff preview keeps admin session intact and hides logout actions', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: StudentPage(
          profile: const UserProfile(
            id: 'admin-id',
            fullName: 'Admin User',
            email: 'admin@example.com',
            role: UserRole.admin,
            status: 'active',
          ),
          isStaffPreview: true,
        ),
      ),
    );

    expect(find.text('Kembali ke Dashboard Admin'), findsOneWidget);
    expect(find.byTooltip('Keluar'), findsNothing);
    expect(find.byTooltip('Profil & Username'), findsNothing);
    expect(find.byTooltip('Ganti Password'), findsNothing);
  });

  testWidgets('TALog20 login and registration navigation', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Selamat datang.'), findsOneWidget);
    expect(find.text('Masuk untuk melanjutkan aktivitas Anda di TALog20.'), findsOneWidget);

    final registrationLink = find.text('Belum punya akun siswa?  Daftar sekarang ->');
    await tester.ensureVisible(registrationLink);
    await tester.tap(registrationLink);
    await tester.pumpAndSettle();

    expect(find.text('Daftar sekarang.'), findsOneWidget);
    expect(find.text('BUAT AKUN SISWA  /  01 / 01'), findsOneWidget);
  });
}
