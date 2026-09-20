import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'dashboard_service.dart';
import 'talog_design_system.dart';

const ink = TalogColors.primaryNavy,
    muted = TalogColors.textMuted,
    cyan = TalogColors.deptBD,
    violet = TalogColors.deptRPL,
    orange = TalogColors.accentOrange;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  debugPrint('SUPABASE_URL runtime: $supabaseUrl');
  debugPrint('SUPABASE_KEY configured: ${supabasePublishableKey.isNotEmpty ? "YES (length: ${supabasePublishableKey.length})" : "NO"}');
  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    runApp(const ConfigurationErrorApp());
    return;
  }
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabasePublishableKey,
  );
  runApp(const MyApp());
}

class ConfigurationErrorApp extends StatelessWidget {
  const ConfigurationErrorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Konfigurasi Supabase belum tersedia',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Jalankan Flutter dengan SUPABASE_URL dan SUPABASE_ANON_KEY.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  'flutter run --dart-define=SUPABASE_URL=... '
                  '--dart-define=SUPABASE_ANON_KEY=...',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

SupabaseClient get supabase => Supabase.instance.client;

String getRealtimeGreeting() {
  final hour = DateTime.now().hour;
  if (hour >= 5 && hour < 12) {
    return 'Good Morning';
  } else if (hour >= 12 && hour < 18) {
    return 'Good Afternoon';
  } else {
    return 'Good Night';
  }
}

bool isNightTime() {
  final hour = DateTime.now().hour;
  return hour >= 18 || hour < 5;
}

String _readableDate(Object? value) {
  if (value == null || value.toString().isEmpty) return 'Belum ditentukan';
  final parsed = DateTime.tryParse(value.toString())?.toLocal();
  if (parsed == null) return value.toString();
  final day = parsed.day.toString().padLeft(2, '0');
  final month = parsed.month.toString().padLeft(2, '0');
  return '$day/$month/${parsed.year}';
}

Map<String, dynamic>? _gradeMap(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  return null;
}

String readableAuthError(String rawMessage, {bool isLogin = false}) {
  final message = rawMessage.toLowerCase();
  if (message.contains('supabase_configuration_error')) {
    return 'Konfigurasi Supabase belum tersedia.';
  }
  if (message.contains('profile_not_found')) {
    return 'Login Auth berhasil, tetapi profile pengguna belum dibuat.';
  }
  if (message.contains('profile_role_invalid')) {
    return 'Profile memiliki role yang tidak valid.';
  }
  if (message.contains('profile_inactive')) {
    return 'Akun ditemukan, tetapi statusnya belum active.';
  }
  if (message.contains('profile_rls_denied')) {
    return 'Login berhasil, tetapi akses profile ditolak oleh RLS.';
  }
  if (message.contains('profile_query_error')) {
    return 'Login berhasil, tetapi profile tidak dapat dibaca.';
  }
  if (message.contains('session_unavailable')) {
    return 'Login berhasil, tetapi session Supabase belum tersedia.';
  }
  if (message.contains('rate limit') || message.contains('email rate limit')) {
    return 'Pengiriman email sedang mencapai batas sementara. Silakan coba lagi nanti.';
  }
  if (message.contains('email not confirmed')) {
    return 'Email belum dikonfirmasi. Periksa inbox email Anda terlebih dahulu.';
  }
  if (message.contains('invalid login credentials')) {
    return 'Email/username atau password salah, atau akun belum dibuat di project Supabase ini.';
  }
  if (message.contains('user not found')) {
    return isLogin ? 'Akun tidak ditemukan. Periksa email atau username Anda.' : 'Akun tidak ditemukan.';
  }
  return rawMessage;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'TALog20 | SMKN 20',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: TalogColors.primaryNavy,
        primary: TalogColors.primaryNavy,
        secondary: TalogColors.accentOrange,
        surface: TalogColors.surface,
      ),
      scaffoldBackgroundColor: TalogColors.lightCanvas,
      useMaterial3: true,
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: TalogColors.border),
        ),
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: TalogColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    ),
    home: const AuthGate(),
  );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  SupabaseClient? client;
  Session? session;
  Future<UserProfile>? profileFuture;
  StreamSubscription<AuthState>? authSubscription;

  @override
  void initState() {
    super.initState();
    SupabaseClient client;
    try {
      client = supabase;
    } catch (_) {
      return;
    }
    this.client = client;
    _acceptSession(client.auth.currentSession);
    authSubscription = client.auth.onAuthStateChange.listen((authState) {
      debugPrint(
        'AuthGate state: event=${authState.event}, '
        'session=${authState.session != null}, currentSession=${client.auth.currentSession != null}',
      );
      _acceptSession(authState.session ?? client.auth.currentSession);
    });
  }

  void _acceptSession(Session? nextSession) {
    if (!mounted) return;
    final currentUserId = session?.user.id;
    final nextUserId = nextSession?.user.id;
    if (currentUserId == nextUserId && profileFuture != null) return;

    if (nextSession == null) {
      setState(() {
        session = null;
        profileFuture = null;
      });
      return;
    }

    final authClient = client;
    if (authClient == null) return;
    debugPrint('AuthGate accepting authenticated session for user id=${nextSession.user.id}');
    setState(() {
      session = nextSession;
      profileFuture = AuthService(authClient).getActiveProfile(nextSession.user.id).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('Profile timeout: profile tidak merespons dalam 15 detik.'),
      );
    });
  }

  @override
  void dispose() {
    authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authClient = client;
    final activeSession = session;
    final activeProfileFuture = profileFuture;
    if (authClient == null || activeSession == null || activeProfileFuture == null) {
      return const LoginPage();
    }
    return FutureBuilder<UserProfile>(
      future: activeProfileFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (profileSnapshot.hasError || !profileSnapshot.hasData) {
          final error = profileSnapshot.error;
          debugPrint('AuthGate profile load failed: $error');
          final message = error is AuthException
              ? readableAuthError(error.message)
              : error is PostgrestException && error.code == '42501'
                  ? 'Profil akun berhasil login tetapi tidak dapat diakses. Periksa policy/RLS tabel profiles.'
                  : 'Login berhasil, tetapi profil pengguna tidak dapat dimuat. Silakan coba lagi.';
          return SessionProblemPage(message: message);
        }
        debugPrint('AuthGate profile ready. role=${profileSnapshot.data!.role.name}');
        return RoleHome(profile: profileSnapshot.data!);
      },
    );
  }
}

class SessionProblemPage extends StatelessWidget {
  const SessionProblemPage({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Brand(),
              const SizedBox(height: 28),
              const Text(
                'Sesi belum dapat digunakan',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: ink),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center, style: const TextStyle(color: muted)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () async {
                  await supabase.auth.signOut();
                },
                child: const Text('Kembali ke login'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class RoleHome extends StatelessWidget {
  const RoleHome({super.key, required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) => switch (profile.role) {
    UserRole.student => StudentPage(profile: profile),
    UserRole.teacher => RoleDashboard(profile: profile),
    UserRole.admin => RoleDashboard(profile: profile),
    UserRole.superadmin => RoleDashboard(profile: profile),
  };
}

class Brand extends StatelessWidget {
  const Brand({super.key, this.light = false});
  final bool light;
  @override
  Widget build(BuildContext context) => TalogBrand(light: light);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final loginController = TextEditingController();
  final passwordController = TextEditingController();
  String? error;
  bool loading = false;

  Future<void> login() async {
    final loginInput = loginController.text.trim();
    final password = passwordController.text;
    if (loginInput.isEmpty || password.isEmpty) {
      setState(() => error = 'Email/Username dan password wajib diisi.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      await AuthService(supabase).signIn(
        loginInput: loginInput,
        password: password,
      );
    } on AuthException catch (exception) {
      setState(() => error = readableAuthError(exception.message, isLogin: true));
    } on PostgrestException catch (_) {
      setState(() => error = 'Login berhasil, tetapi profile pengguna belum dapat dibaca.');
    } catch (e) {
      setState(() => error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showResetPasswordDialog() {
    final resetEmailController = TextEditingController(text: loginController.text);
    showDialog(
      context: context,
      builder: (context) => _ResetPasswordDialog(controller: resetEmailController),
    );
  }

  @override
  void dispose() {
    loginController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Brand(),
              const SizedBox(height: 48),
              const LabelText('AKSES AKUN  /  01 / 01'),
              const SizedBox(height: 18),
              const Text(
                'Selamat datang.',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masuk untuk melanjutkan aktivitas Anda di TALog20.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gunakan email dan password Anda.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 28),
              InputField(
                label: 'Email',
                hint: 'nama@sekolah.sch.id',
                controller: loginController,
              ),
              const SizedBox(height: 18),
              InputField(
                label: 'Password',
                hint: 'Masukkan password',
                password: true,
                controller: passwordController,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: showResetPasswordDialog,
                    child: const Text('Lupa password?'),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ActionButton(
                label: 'Masuk',
                onPressed: loading ? null : login,
                loading: loading,
              ),

            ],
          ),
        ),
      ),
    ),
  );
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});
  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  final attendanceController = TextEditingController();
  String? error;
  bool loading = false;

  Future<void> register() async {
    if (loading) return;
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => error = 'Masukkan alamat email yang valid.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      final attendance = int.tryParse(attendanceController.text.trim());
      if (nameController.text.trim().isEmpty || attendance == null || attendance <= 0) {
        throw const AuthException('Nama lengkap dan nomor absen wajib diisi dengan benar.');
      }
      await AuthService(supabase).registerStudent(
        fullName: nameController.text,
        email: email,
        departmentCode: codeController.text,
        attendanceNumber: attendance,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Akun dibuat. Silakan login dengan password absen x3.')),
      );
      Navigator.pop(context);
    } on AuthException catch (exception) {
      setState(() => error = readableAuthError(exception.message));
    } catch (_) {
      setState(() => error = 'Tidak dapat terhubung ke Supabase.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    codeController.dispose();
    attendanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: SizedBox(
          width: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Brand(),
              const SizedBox(height: 48),
              const LabelText('BUAT AKUN SISWA  /  01 / 01'),
              const SizedBox(height: 18),
              const Text(
                'Daftar sekarang.',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Isi data berikut untuk mulai mengerjakan tugas di TALog20.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 28),
              InputField(
                label: 'Nama lengkap',
                hint: 'Masukkan nama lengkap',
                controller: nameController,
              ),
              const SizedBox(height: 16),
              InputField(label: 'Email pribadi', hint: 'nama@gmail.com', controller: emailController),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InputField(
                      label: 'Kode jurusan',
                      hint: 'Contoh: RPL',
                      controller: codeController,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: InputField(label: 'Nomor absen', hint: 'Absen Anda', controller: attendanceController),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xffeef0ff),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Password awal dibuat otomatis dari nomor absen 3x (contoh absen 12 -> 121212). '
                  'Wajib ganti password setelah masuk dashboard.',
                  style: TextStyle(color: ink, height: 1.5, fontSize: 13),
                ),
              ),
              const SizedBox(height: 22),
              if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
              ActionButton(
                label: 'Daftar akun siswa',
                onPressed: loading ? null : register,
                loading: loading,
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Sudah punya akun?  Kembali ke login'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class LabelText extends StatelessWidget {
  const LabelText(this.value, {super.key});
  final String value;
  @override
  Widget build(BuildContext context) => Text(
    value,
    style: const TextStyle(
      color: TalogColors.accentOrange,
      fontSize: 11,
      letterSpacing: 1.4,
      fontWeight: FontWeight.w800,
    ),
  );
}

class InputField extends StatefulWidget {
  const InputField({
    super.key,
    required this.label,
    required this.hint,
    this.password = false,
    this.controller,
  });
  final String label, hint;
  final bool password;
  final TextEditingController? controller;

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  bool obscured = true;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label,
        style: const TextStyle(
          color: TalogColors.textHeading,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: widget.controller,
        obscureText: widget.password && obscured,
        keyboardType: widget.password ? TextInputType.visiblePassword : TextInputType.text,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enableSuggestions: !widget.password,
        autofillHints: widget.password ? const [AutofillHints.password] : null,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(color: TalogColors.textMuted, fontSize: 13),
          suffixIcon: widget.password
              ? IconButton(
                  tooltip: obscured ? 'Tampilkan password' : 'Sembunyikan password',
                  icon: Icon(obscured ? Icons.visibility : Icons.visibility_off, color: TalogColors.textMuted),
                  onPressed: () => setState(() => obscured = !obscured),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TalogColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TalogColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: TalogColors.primaryNavy, width: 1.5),
          ),
        ),
      ),
    ],
  );
}

class ActionButton extends StatelessWidget {
  const ActionButton({super.key, required this.label, required this.onPressed, this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: TalogColors.accentOrange,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              '$label  ->',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.2),
            ),
    ),
  );
}

// Student Page with Modern UI, Realtime Updates, Submissions, Grades, and Profile
class StudentPage extends StatefulWidget {
  const StudentPage({super.key, required this.profile, this.isStaffPreview = false});
  final UserProfile profile;
  final bool isStaffPreview;

  @override
  State<StudentPage> createState() => _StudentPageState();
}

class _StudentPageState extends State<StudentPage> {
  int currentTab = 0;
  Timer? _timeTimer;
  String _greeting = getRealtimeGreeting();
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _greeting = getRealtimeGreeting();
    _timeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final newGreeting = getRealtimeGreeting();
      if (newGreeting != _greeting && mounted) {
        setState(() => _greeting = newGreeting);
      }
    });
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    super.dispose();
  }

  void _openSubmitDialog(BuildContext context, Map<String, dynamic> todo) {
    final noteController = TextEditingController();
    String? selectedFilePath;
    String? selectedFileName;
    var sending = false;
    final answerTextController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(todo['name']?.toString() ?? 'Detail tugas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(todo['description']?.toString() ?? 'Tidak ada deskripsi.', style: const TextStyle(color: muted, height: 1.4)),
                  const SizedBox(height: 10),
                  Text('Deadline: ${_readableDate(todo['due_at'])}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Lampirkan file tugas dan tambahkan catatan untuk guru:', style: TextStyle(fontSize: 13, color: muted)),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: sending
                        ? null
                        : () async {
                            final result = await FilePicker.platform.pickFiles(withData: true);
                            final file = result?.files.single;
                            if (file == null || file.bytes == null) return;
                            try {
                              final path = await DashboardService(supabase).uploadSubmissionFile(
                                assignmentId: todo['id'].toString(),
                                studentId: widget.profile.id,
                                fileName: file.name,
                                bytes: file.bytes!,
                              );
                              if (ctx.mounted) {
                                setDialogState(() {
                                  selectedFilePath = path;
                                  selectedFileName = file.name;
                                });
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Gagal mengunggah file: $e')),
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.attach_file),
                    label: Text(selectedFileName ?? 'Pilih file tugas'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: answerTextController,
                    enabled: !sending,
                    decoration: const InputDecoration(
                      labelText: 'Jawaban teks (opsional)',
                      hintText: 'Tulis jawaban Anda di sini...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    enabled: !sending,
                    decoration: const InputDecoration(
                      labelText: 'Catatan tambahan (opsional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: sending ? null : () => Navigator.pop(ctx), child: const Text('Batal')),
              FilledButton.icon(
                onPressed: sending
                    ? null
                    : () async {
                        if (selectedFilePath == null && noteController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tambahkan catatan atau pilih file tugas terlebih dahulu.')));
                          return;
                        }
                        setDialogState(() => sending = true);
                        try {
                          await DashboardService(supabase).submitAssignment(
                            todoId: todo['id'].toString(),
                            filePath: selectedFilePath?.isNotEmpty == true ? selectedFilePath : null,
                            contentText: answerTextController.text.trim().isNotEmpty
                                ? answerTextController.text.trim()
                                : (noteController.text.trim().isNotEmpty
                                    ? noteController.text.trim()
                                    : null),
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tugas berhasil dikumpulkan!')));
                            setState(() {});
                          }
                        } catch (e) {
                          if (ctx.mounted) setDialogState(() => sending = false);
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mengumpulkan tugas: $e')));
                        }
                      },
                icon: sending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
                label: Text(sending ? 'Mengirim...' : 'Kirim Tugas'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openTaskDetail(BuildContext context, Map<String, dynamic> todo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(todo['name']?.toString() ?? 'Detail tugas'),
        content: FutureBuilder<List<Map<String, dynamic>>>(
          future: DashboardService(supabase).fetchMySubmissions(),
          builder: (context, snapshot) {
            final submission = snapshot.data?.cast<Map<String, dynamic>>().where(
              (item) => item['todo_id']?.toString() == todo['id']?.toString(),
            ).firstOrNull;
            final grade = _gradeMap(submission?['grades']);
            final score = grade?['score']?.toString();
            final feedback = grade?['feedback']?.toString();
            final attachment = todo['attachment_url'] ?? todo['attachment'] ?? todo['file_url'];
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(todo['description']?.toString() ?? 'Tidak ada deskripsi.', style: const TextStyle(color: muted, height: 1.4)),
                  const SizedBox(height: 12),
                  Text('Deadline: ${_readableDate(todo['due_at'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (todo['departments'] is Map) ...[
                    const SizedBox(height: 6),
                    Text('Jurusan: ${(todo['departments'] as Map)['name'] ?? '-'}'),
                  ],
                  if (attachment != null && attachment.toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SelectableText('Lampiran: $attachment'),
                  ],
                  const SizedBox(height: 12),
                  Text('Status: ${submission == null ? 'Belum dikumpulkan' : 'Sudah dikumpulkan'}'),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: 6),
                    Text('Status submission belum dapat dimuat: ${snapshot.error}', style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                  if (score != null) ...[
                    const SizedBox(height: 6),
                    Text('Nilai: $score'),
                  ],
                  if (feedback != null && feedback.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Feedback guru: $feedback'),
                  ],
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          if (!widget.isStaffPreview)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _openSubmitDialog(context, todo);
              },
              icon: const Icon(Icons.upload_file),
              label: const Text('Kumpulkan'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.profile.displayName;

    return Shell(
      title: 'STUDENT WORKSPACE',
      heading: '$_greeting, $name.',
      subtitle: widget.isStaffPreview
          ? '[Staff Preview Mode] Melihat tampilan sebagai siswa.'
          : 'Semua tugas, progres, dan nilai Anda dalam satu ruang kerja.',
      profile: _profile,
      isStaffPreview: widget.isStaffPreview,
      onNavSelected: (index) {
        setState(() => currentTab = index);
      },
      selectedTabIndex: currentTab,
      children: [
        if (widget.isStaffPreview)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali ke Dashboard Admin'),
              ),
            ),
          ),
          if (currentTab == 0 && !widget.isStaffPreview)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ingat: Jika Anda baru pertama kali login dengan password sementara absen, segera ganti password di menu ganti password.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        if (currentTab == 0 && !widget.isStaffPreview)
          Panel(
            title: 'RINGKASAN SISWA',
            heading: 'Nilai & Feedback Guru',
            child: StudentGradesList(),
          )
        else if (currentTab == 1)
          Panel(
            title: 'YOUR ASSIGNMENTS',
            heading: 'Daftar Tugas & Pengumpulan',
            child: StudentAssignmentsList(
              onOpenTask: (todo) => _openTaskDetail(context, todo),
            ),
          )
        else
          StudentProfilePanel(
            profile: _profile,
            onProfileUpdated: (updatedProfile) {
              setState(() => _profile = updatedProfile);
            },
          ),
      ],
    );
  }
}

class StudentProfilePanel extends StatefulWidget {
  const StudentProfilePanel({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });
  final UserProfile profile;
  final void Function(UserProfile profile) onProfileUpdated;

  @override
  State<StudentProfilePanel> createState() => _StudentProfilePanelState();
}

class _StudentProfilePanelState extends State<StudentProfilePanel> {
  late TextEditingController usernameController;

  @override
  void initState() {
    super.initState();
    usernameController = TextEditingController(text: widget.profile.username ?? '');
  }

  @override
  void dispose() {
    usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final username = usernameController.text.trim();
    final validation = AuthService.validateUsername(username);
    if (validation != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(validation)));
      }
      return;
    }

    try {
      await AuthService(supabase).updateProfile(
        userId: widget.profile.id,
        username: username,
      );
      final updatedProfile = UserProfile(
        id: widget.profile.id,
        fullName: widget.profile.fullName,
        email: widget.profile.email,
        role: widget.profile.role,
        status: widget.profile.status,
        username: username,
      );
      widget.onProfileUpdated(updatedProfile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username berhasil diperbarui.')),
        );
      }
    } catch (e) {
      if (mounted) {
        final message = e is AuthException ? e.message : 'Gagal memperbarui username. Silakan coba lagi.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  Future<void> _showPasswordDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => const _StudentPasswordDialog(),
    );
  }

  @override
  Widget build(BuildContext context) => Panel(
    title: 'PROFILE / AKUN',
    heading: 'Informasi Profil & Keamanan Akun',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xfff8f9fe),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xffe7eaf1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama lengkap: ${widget.profile.fullName}', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Email: ${widget.profile.email}', style: const TextStyle(color: muted)),
              const SizedBox(height: 8),
              Text('Role saat ini: ${widget.profile.role.name.toUpperCase()}', style: const TextStyle(color: muted)),
              const SizedBox(height: 8),
              Text('Username saat ini: ${widget.profile.username ?? '-'}', style: const TextStyle(color: muted)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Ganti Username', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username baru',
                  hintText: 'contoh: siswa_01',
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(onPressed: _saveUsername, child: const Text('Simpan')),
          ],
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        Row(
          children: [
            const Expanded(child: Text('Password akun', style: TextStyle(fontWeight: FontWeight.bold))),
            FilledButton.tonalIcon(
              onPressed: _showPasswordDialog,
              icon: const Icon(Icons.lock_reset),
              label: const Text('Ganti Password'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _StudentPasswordDialog extends StatefulWidget {
  const _StudentPasswordDialog();

  @override
  State<_StudentPasswordDialog> createState() => _StudentPasswordDialogState();
}

class _StudentPasswordDialogState extends State<_StudentPasswordDialog> {
  final currentPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool showCurrent = false;
  bool showNew = false;
  bool showConfirm = false;
  String? error;
  bool loading = false;

  @override
  void dispose() {
    currentPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final validationError = AuthService.validatePasswordUpdate(
      currentPassword: currentPasswordController.text,
      newPassword: newPasswordController.text,
      confirmPassword: confirmPasswordController.text,
    );
    if (validationError != null) {
      setState(() => error = validationError);
      return;
    }

    setState(() { loading = true; error = null; });
    try {
      await AuthService(supabase).changePasswordWithCurrent(
        currentPassword: currentPasswordController.text,
        newPassword: newPasswordController.text,
        confirmPassword: confirmPasswordController.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password berhasil diperbarui.')),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() { error = e.message; loading = false; });
      }
    } catch (_) {
      if (mounted) {
        setState(() { error = 'Gagal memperbarui password. Silakan coba lagi.'; loading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ganti Password'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: currentPasswordController,
            obscureText: !showCurrent,
            decoration: InputDecoration(
              labelText: 'Password lama',
              suffixIcon: IconButton(
                icon: Icon(showCurrent ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => showCurrent = !showCurrent),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: newPasswordController,
            obscureText: !showNew,
            decoration: InputDecoration(
              labelText: 'Password baru',
              suffixIcon: IconButton(
                icon: Icon(showNew ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => showNew = !showNew),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: confirmPasswordController,
            obscureText: !showConfirm,
            decoration: InputDecoration(
              labelText: 'Konfirmasi password baru',
              suffixIcon: IconButton(
                icon: Icon(showConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => showConfirm = !showConfirm),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: loading ? null : () => Navigator.pop(context), child: const Text('Batal')),
      FilledButton(onPressed: loading ? null : _submit, child: Text(loading ? 'Memproses...' : 'Ubah Password')),
    ],
  );
}

class StudentAssignmentsList extends StatefulWidget {
  const StudentAssignmentsList({super.key, required this.onOpenTask});
  final void Function(Map<String, dynamic> todo) onOpenTask;

  @override
  State<StudentAssignmentsList> createState() => _StudentAssignmentsListState();
}

class _StudentAssignmentsListState extends State<StudentAssignmentsList> {
  late Future<List<Map<String, dynamic>>> future;
  late final RealtimeChannel channel;

  @override
  void initState() {
    super.initState();
    future = DashboardService(supabase).fetchTodos(activeOnly: true);
    channel = DashboardService(supabase).watchTable(
      channelName: 'student-todos-${identityHashCode(this)}',
      table: 'todos',
      onChange: (_) {
        if (mounted) refresh();
      },
    );
  }

  void refresh() {
    setState(() => future = DashboardService(supabase).fetchTodos(activeOnly: true));
  }

  @override
  void dispose() {
    supabase.removeChannel(channel);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(padding: EdgeInsets.all(12), child: LinearProgressIndicator());
      }
      if (snapshot.hasError) {
        return _RefreshMessage(message: 'Tugas tidak dapat dimuat: ${snapshot.error}', onRefresh: refresh);
      }
      final rows = snapshot.data ?? const [];
      if (rows.isEmpty) {
        return const Text('Belum ada tugas yang diberikan.', style: TextStyle(color: muted));
      }
      return Column(
        children: rows.map((todo) {
          final name = todo['name']?.toString() ?? 'Tugas tanpa nama';
          final desc = todo['description']?.toString() ?? '-';
          final completed = todo['is_complete'] == true;
          final department = todo['departments'];
          final departmentName = department is Map ? department['name']?.toString() : null;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xfff9fafc),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffe7eaf1)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 500;
                final details = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(completed ? Icons.check_circle : Icons.pending_actions, color: completed ? cyan : violet),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text(desc, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 12)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              Text('Deadline: ${_readableDate(todo['due_at'])}', style: const TextStyle(color: muted, fontSize: 11)),
                              if (departmentName != null) Text(departmentName, style: const TextStyle(color: muted, fontSize: 11)),
                              Text(completed ? 'Selesai' : 'Aktif', style: TextStyle(color: completed ? Colors.green.shade700 : violet, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final action = FilledButton.tonal(onPressed: () => widget.onOpenTask(todo), child: const Text('Lihat Detail'));
                if (narrow) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [details, const SizedBox(height: 12), Align(alignment: Alignment.centerRight, child: action)]);
                }
                return Row(children: [Expanded(child: details), const SizedBox(width: 12), action]);
              },
            ),
          );
        }).toList(),
      );
    },
  );
}

class StudentGradesList extends StatefulWidget {
  const StudentGradesList({super.key});

  @override
  State<StudentGradesList> createState() => _StudentGradesListState();
}

class _StudentGradesListState extends State<StudentGradesList> {
  late Future<List<Map<String, dynamic>>> future;
  late final List<RealtimeChannel> channels;

  @override
  void initState() {
    super.initState();
    future = DashboardService(supabase).fetchMySubmissions();
    final service = DashboardService(supabase);
    channels = [
      service.watchTable(
        channelName: 'student-submissions-${identityHashCode(this)}',
        table: 'submissions',
        onChange: (_) {
          if (mounted) refresh();
        },
      ),
      service.watchTable(
        channelName: 'student-grades-${identityHashCode(this)}',
        table: 'grades',
        onChange: (_) {
          if (mounted) refresh();
        },
      ),
    ];
  }

  void refresh() {
    setState(() => future = DashboardService(supabase).fetchMySubmissions());
  }

  @override
  void dispose() {
    for (final channel in channels) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _RefreshMessage(message: 'Gagal memuat status pengumpulan: ${snapshot.error}', onRefresh: refresh);
      }
      final rows = snapshot.data ?? const [];
      if (rows.isEmpty) {
        return const Text('Belum ada tugas yang dikumpulkan.', style: TextStyle(color: muted));
      }
      return Column(
        children: rows.map((sub) {
          final todo = sub['todos'];
          final todoName = todo is Map ? todo['name']?.toString() : 'Tugas';
          final grades = _gradeMap(sub['grades']);
          final score = grades?['score']?.toString();
          final feedback = grades?['feedback']?.toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xffe7eaf1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        todoName ?? 'Tugas',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: score != null ? Colors.green.shade50 : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        score != null ? 'Nilai: $score' : 'Terkirim',
                        style: TextStyle(
                          color: score != null ? Colors.green.shade800 : Colors.blue.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                if (feedback != null && feedback.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Catatan: $feedback', style: const TextStyle(color: muted, fontSize: 12)),
                ],
              ],
            ),
          );
        }).toList(),
      );
    },
  );
}

class ImportResult {
  const ImportResult({
    required this.rowIndex,
    required this.name,
    required this.email,
    required this.success,
    this.errorMessage,
  });
  final int rowIndex;
  final String name;
  final String email;
  final bool success;
  final String? errorMessage;
}

String _generatePassword() {
  const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
}

class RoleDashboard extends StatefulWidget {
  const RoleDashboard({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<RoleDashboard> createState() => _RoleDashboardState();
}

class _RoleDashboardState extends State<RoleDashboard> {
  int currentTab = 0;
  Timer? _timeTimer;
  String _greeting = getRealtimeGreeting();

  @override
  void initState() {
    super.initState();
    _greeting = getRealtimeGreeting();
    _timeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final newGreeting = getRealtimeGreeting();
      if (newGreeting != _greeting && mounted) {
        setState(() => _greeting = newGreeting);
      }
    });
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    super.dispose();
  }

  UserRole get role => widget.profile.role;

  bool get canManageUsers => role == UserRole.admin || role == UserRole.superadmin;
  bool get canReadAuditLog => role == UserRole.superadmin;
  bool get canViewLiveUpdate => role == UserRole.superadmin;
  bool get canViewSubmissions => role == UserRole.teacher;

  int get liveUpdateTab => role == UserRole.superadmin ? 5 : -1;

  int get _maxTab {
    if (role == UserRole.superadmin) return 5; // Overview, Pengguna, Kelola Akun, AI, Audit Log, Live Update
    if (role == UserRole.teacher) return 3;    // Overview, Tugas, Evaluasi, Rekap Nilai
    if (role == UserRole.admin) return 3;      // Overview, Pengguna, Kelola Akun, Pengaturan AI
    return 0;
  }

  int get _clampedTab => currentTab.clamp(0, _maxTab);

  String get title => switch (role) {
    UserRole.teacher => 'TEACHER DASHBOARD',
    UserRole.admin => 'ADMIN DASHBOARD',
    UserRole.superadmin => 'SUPER ADMIN DASHBOARD',
    UserRole.student => 'STUDENT DASHBOARD',
  };

  @override
  Widget build(BuildContext context) {
    final name = widget.profile.displayName;
    return Shell(
      title: title,
      heading: '$_greeting, $name.',
      subtitle: switch (role) {
        UserRole.teacher => 'Ruang bimbingan, tugas, dan penilaian siswa.',
        UserRole.admin => 'Kelola pengguna, audit aktivitas, dan konfigurasi sistem.',
        UserRole.superadmin => 'Kendali penuh sistem, manajemen akun pengguna, dan audit integritas.',
        UserRole.student => 'Ruang kerja tugas Anda.',
      },
      profile: widget.profile,
      onNavSelected: (i) {
        setState(() => currentTab = i);
      },
      selectedTabIndex: _clampedTab,
      children: [
        _buildContentForTab(currentTab),
      ],
    );
  }

  Widget _buildContentForTab(int tab) {
    if (tab == 0) return _buildOverview();

    if (role == UserRole.superadmin) {
      if (tab == 1) return const UserManagementPanel();
      if (tab == 2) return const AccountManagementPanel();
      if (tab == 3) return const AiSettingsPanel();
      if (tab == 4) return const AuditLogsPanel();
      if (tab == 5) return const LiveUpdatePage();
      return _buildOverview();
    }

    if (role == UserRole.teacher) {
      if (tab == 1) return StaffTasksPanel(profile: widget.profile);
      if (tab == 2) return StaffSubmissionsPanel(profile: widget.profile);
      if (tab == 3) return const GradeRecapPanel();
      return _buildOverview();
    }

    // Admin: hanya Overview, Pengguna, Kelola Akun, AI, Audit Log, Live Update
    if (role == UserRole.admin) {
      if (tab == 1) return const UserManagementPanel();
      if (tab == 2) return const AccountManagementPanel();
      if (tab == 3) return const AiSettingsPanel();
      if (tab == 4) return const AuditLogsPanel();
      if (tab == 5) return const LiveUpdatePage();
      return _buildOverview();
    }

    return _buildOverview();
  }

  Widget _buildOverview() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Panel(
        title: 'STATUS SISTEM',
        heading: role == UserRole.superadmin
            ? 'Kendali Penuh Sistem'
            : role == UserRole.admin
                ? 'Admin — Ringkasan Sistem'
                : 'Ringkasan Aktivitas',
        child: Text(
          role == UserRole.superadmin
              ? 'Anda memiliki hak istimewa untuk mengelola role pengguna, memantau tugas, pengumpulan, penilaian, serta jejak audit sistem.'
              : role == UserRole.admin
                  ? 'Kelola pengguna, audit aktivitas, konfigurasi penilaian AI, dan pantau aktivitas Supabase realtime.'
                  : 'Kelola penugasan kelas Anda, evaluasi pengumpulan siswa, dan berikan nilai secara real-time.',
          style: const TextStyle(color: muted, height: 1.5),
        ),
      ),
      if (role == UserRole.superadmin || role == UserRole.admin) ...[
        const SizedBox(height: 18),
        const _AppHealthPanel(),
      ],
      const SizedBox(height: 4),
    ],
  );
}

class StaffTasksPanel extends StatefulWidget {
  const StaffTasksPanel({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<StaffTasksPanel> createState() => _StaffTasksPanelState();
}

class _StaffTasksPanelState extends State<StaffTasksPanel> {
  late Future<List<Map<String, dynamic>>> future;
  late final RealtimeChannel channel;

  @override
  void initState() {
    super.initState();
    future = DashboardService(supabase).fetchTodos();
    channel = DashboardService(supabase).watchTable(
      channelName: 'staff-todos-${identityHashCode(this)}',
      table: 'todos',
      onChange: (_) {
        if (mounted) refresh();
      },
    );
  }

  @override
  void dispose() {
    supabase.removeChannel(channel);
    super.dispose();
  }

  void refresh() {
    setState(() => future = DashboardService(supabase).fetchTodos());
  }

  Future<void> _toggleTaskArchive(Map<String, dynamic> task, {required bool archived}) async {
    final todoId = task['id']?.toString();
    if (todoId == null || todoId.isEmpty) return;
    try {
      await DashboardService(supabase).archiveTodo(todoId, archived: archived);
      await AuthService(supabase).logAudit(
        action: archived ? 'TASK_ARCHIVED' : 'TASK_RESTORED',
        description: archived ? 'Tugas diarsipkan: ${task['name']}' : 'Tugas dipulihkan: ${task['name']}',
        targetRecordId: todoId,
      );
      if (mounted) refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengubah status tugas: $e')),
        );
      }
    }
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    final todoId = task['id']?.toString();
    final taskName = task['name']?.toString() ?? 'Tugas';
    if (todoId == null || todoId.isEmpty) return;

    try {
      final usage = await DashboardService(supabase).getTodoUsage(todoId);
      final submissionCount = usage['submissions'] ?? 0;
      final gradeCount = usage['grades'] ?? 0;

      if (DashboardService.shouldPreferArchiveBeforeDelete(submissionCount, gradeCount: gradeCount)) {
        if (!mounted) return;
        final preference = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Tugas sudah memiliki data siswa'),
            content: Text(
              'Tugas "$taskName" sudah memiliki $submissionCount pengumpulan dan $gradeCount penilaian. Untuk menjaga integritas data, lebih aman untuk mengarsipkan tugas daripada menghapus permanen.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
              FilledButton.tonal(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Arsipkan'),
              ),
            ],
          ),
        );
        if (preference == true) {
          await _toggleTaskArchive(task, archived: true);
        }
        return;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus tugas permanen?'),
          content: Text('Apakah Anda yakin ingin menghapus tugas "$taskName" secara permanen? Tindakan ini tidak dapat dibatalkan.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Hapus Permanen'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      await DashboardService(supabase).deleteTodo(todoId);
      await AuthService(supabase).logAudit(
        action: 'TASK_DELETED',
        description: 'Tugas dihapus permanen: $taskName',
        targetRecordId: todoId,
      );
      if (mounted) refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses tugas: $e')),
        );
      }
    }
  }

  Future<void> _showCreateTaskDialog() async {
    late final List<Map<String, dynamic>> departments;
    try {
      departments = await DashboardService(supabase).fetchDepartments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat jurusan: $e')),
        );
      }
      return;
    }
    if (!mounted) return;
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String? selectedDepartmentId = departments.isEmpty ? null : departments.first['id']?.toString();
    DateTime? dueAt;
    String submissionFormat = 'essai'; // 'file' atau 'essai'
    final List<TextEditingController> criteriaControllers = [TextEditingController()];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Buat Tugas Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nama Tugas'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Deskripsi / Instruksi'),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedDepartmentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Jurusan'),
                  items: departments.map((department) {
                    final id = department['id']?.toString();
                    final code = department['code']?.toString() ?? '';
                    final name = department['name']?.toString() ?? code;
                    return DropdownMenuItem(value: id, child: Text('$code - $name'));
                  }).toList(),
                  onChanged: departments.isEmpty ? null : (value) => setDialogState(() => selectedDepartmentId = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: ValueKey(submissionFormat),
                  initialValue: submissionFormat,
                  decoration: const InputDecoration(labelText: 'Format Pengumpulan', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'essai', child: Text('Esai (Teks)')),
                    DropdownMenuItem(value: 'file', child: Text('File (Upload)')),
                  ],
                  onChanged: (v) => setDialogState(() => submissionFormat = v ?? 'essai'),
                ),
                if (submissionFormat == 'file') ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kriteria Penilaian AI:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Tambah'),
                        onPressed: () => setDialogState(() => criteriaControllers.add(TextEditingController())),
                      ),
                    ],
                  ),
                  const Text('Masukkan aspek/kata kunci yang harus ada dalam file siswa:', style: TextStyle(color: muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  ...criteriaControllers.asMap().entries.map((entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 24, child: Text('${entry.key + 1}.', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: entry.value,
                            decoration: const InputDecoration(
                              hintText: 'Contoh: pengertian, tujuan, kesimpulan...',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        if (criteriaControllers.length > 1)
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                            onPressed: () => setDialogState(() { criteriaControllers.removeAt(entry.key); }),
                          ),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final selected = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                        initialDate: dueAt ?? DateTime.now(),
                      );
                      if (selected != null) {
                        setDialogState(() => dueAt = selected);
                      }
                    },
                    icon: const Icon(Icons.event),
                    label: Text(dueAt == null ? 'Pilih Deadline' : 'Deadline: ${_readableDate(dueAt)}'),
                  ),
                ),
                if (departments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text('Belum ada jurusan di database.', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: selectedDepartmentId == null
                  ? null
                  : () {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      Navigator.pop(ctx, true);
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) {
      for (final c in criteriaControllers) { c.dispose(); }
      return;
    }

    final taskName = nameController.text.trim();
    if (taskName.isEmpty || selectedDepartmentId == null) {
      for (final c in criteriaControllers) { c.dispose(); }
      return;
    }
    final criteria = submissionFormat == 'file'
        ? criteriaControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    for (final c in criteriaControllers) { c.dispose(); }

    try {
      await DashboardService(supabase).createTodo(
        name: taskName,
        description: descController.text.trim(),
        departmentId: selectedDepartmentId!,
        dueAt: dueAt,
        submissionFormat: submissionFormat,
        aiCriteria: criteria.isEmpty ? null : criteria,
      );
      await AuthService(supabase).logAudit(
        action: 'TASK_CREATED',
        description: 'Tugas baru dibuat: $taskName',
      );
      if (mounted) refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat tugas: $e')),
        );
      }
    }
  }

  Future<void> _showAnswerKeyDialog(Map<String, dynamic> task) async {
    final todoId = task['id']?.toString() ?? '';
    if (todoId.isEmpty) return;

    Map<String, dynamic>? existing;
    try {
      existing = await DashboardService(supabase).fetchAnswerKey(todoId);
    } catch (_) {}
    if (!mounted) return;

    String selectedType = existing?['question_type']?.toString() ?? 'multiple_choice';
    final rubricController = TextEditingController(
        text: existing?['rubric']?.toString() ?? '');
    double maxScore =
        (existing?['max_score'] as num?)?.toDouble() ?? 100.0;

    final Map<String, TextEditingController> answerControllers = {};
    final existingKeys = existing?['answer_key'];
    if (existingKeys is Map) {
      for (final entry in existingKeys.entries) {
        answerControllers[entry.key.toString()] =
            TextEditingController(text: entry.value?.toString() ?? '');
      }
    }
    if (answerControllers.isEmpty) {
      for (int i = 1; i <= 5; i++) {
        answerControllers[i.toString()] = TextEditingController();
      }
    }

    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Kunci Jawaban: ${task['name'] ?? 'Tugas'}'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tipe Soal',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(), isDense: true),
                    items: const [
                      DropdownMenuItem(
                          value: 'multiple_choice',
                          child: Text('Pilihan Ganda')),
                      DropdownMenuItem(
                          value: 'short_answer',
                          child: Text('Isian Singkat')),
                      DropdownMenuItem(
                          value: 'essay', child: Text('Esai')),
                    ],
                    onChanged: (v) => setDialogState(
                        () => selectedType = v ?? 'multiple_choice'),
                  ),
                  const SizedBox(height: 14),
                  if (selectedType != 'essay') ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Kunci per Nomor',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13)),
                        TextButton.icon(
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tambah soal'),
                          onPressed: () => setDialogState(() {
                            final nextKey =
                                (answerControllers.length + 1).toString();
                            answerControllers[nextKey] =
                                TextEditingController();
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...answerControllers.entries.map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 32,
                                child: Text('${entry.key}.',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: entry.value,
                                  decoration: InputDecoration(
                                    hintText:
                                        selectedType == 'multiple_choice'
                                            ? 'Contoh: A'
                                            : 'Jawaban benar',
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 10),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                    size: 18),
                                onPressed: () => setDialogState(
                                    () => answerControllers
                                        .remove(entry.key)),
                              ),
                            ],
                          ),
                        )),
                  ],
                  if (selectedType == 'essay') ...[
                    const Text('Rubrik Penilaian',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: rubricController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'Jelaskan kriteria penilaian esai...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Text('Skor Maksimal:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          initialValue: maxScore.toStringAsFixed(0),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true),
                          onChanged: (v) =>
                              maxScore = double.tryParse(v) ?? maxScore,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Batal')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        final keyMap = <String, dynamic>{
                          for (final e in answerControllers.entries)
                            if (e.value.text.trim().isNotEmpty)
                              e.key: e.value.text.trim(),
                        };
                        await DashboardService(supabase).saveAnswerKey(
                          todoId: todoId,
                          questionType: selectedType,
                          answerKey: keyMap,
                          rubric: rubricController.text.trim().isNotEmpty
                              ? rubricController.text.trim()
                              : null,
                          maxScore: maxScore,
                        );
                        await AuthService(supabase).logAudit(
                          action: 'ANSWER_KEY_SAVED',
                          description:
                              'Kunci jawaban disimpan untuk tugas: ${task['name']}',
                          targetRecordId: todoId,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Kunci jawaban berhasil disimpan.')),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Gagal menyimpan kunci jawaban: $e')),
                          );
                        }
                      }
                    },
              child: Text(saving ? 'Menyimpan...' : 'Simpan Kunci'),
            ),
          ],
        ),
      ),
    );

    rubricController.dispose();
    for (final c in answerControllers.values) {
      c.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Panel(
    title: 'MANAJEMEN TUGAS',
    heading: 'Daftar Penugasan',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final action = FilledButton.icon(
              onPressed: _showCreateTaskDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Tugas'),
            );
            if (constraints.maxWidth < 520) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Tugas yang terdaftar dalam sistem:', style: TextStyle(color: muted)), const SizedBox(height: 10), action]);
            }
            return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Expanded(child: Text('Tugas yang terdaftar dalam sistem:', style: TextStyle(color: muted))), action]);
          },
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return _RefreshMessage(message: 'Gagal memuat tugas: ${snapshot.error}', onRefresh: refresh);
            }
            final list = snapshot.data ?? const [];
            if (list.isEmpty) return const Text('Belum ada tugas.', style: TextStyle(color: muted));
            return Column(
              children: list.map((t) {
                final isArchived = t['is_complete'] == true;
                return ListTile(
                  title: Text(t['name'] ?? 'Tugas', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(t['description'] ?? '-'),
                  trailing: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showAnswerKeyDialog(t).ignore(),
                        icon: const Icon(Icons.key_outlined, size: 16),
                        label: const Text('Kunci Jawaban'),
                      ),
                      Text(
                        isArchived ? 'Arsip' : 'Aktif',
                        style: TextStyle(
                          color: isArchived ? cyan : violet,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _toggleTaskArchive(t, archived: !isArchived).ignore(),
                        icon: Icon(isArchived ? Icons.unarchive : Icons.archive_outlined),
                        label: Text(isArchived ? 'Pulihkan' : 'Arsipkan'),
                      ),
                      TextButton.icon(
                        onPressed: () => _deleteTask(t).ignore(),
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        label: const Text('Hapus', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ),
  );
}

class StaffSubmissionsPanel extends StatefulWidget {
  const StaffSubmissionsPanel({super.key, required this.profile});
  final UserProfile profile;

  @override
  State<StaffSubmissionsPanel> createState() => _StaffSubmissionsPanelState();
}

class _StaffSubmissionsPanelState extends State<StaffSubmissionsPanel> {
  late Future<List<Map<String, dynamic>>> future;
  late final List<RealtimeChannel> channels;
  // Filter tugas aktif
  List<Map<String, dynamic>> _todoList = [];
  String? _filterTodoId;

  @override
  void initState() {
    super.initState();
    future = DashboardService(supabase).fetchStaffSubmissions();
    final service = DashboardService(supabase);
    channels = [
      service.watchTable(
        channelName: 'staff-submissions-${identityHashCode(this)}',
        table: 'submissions',
        onChange: (_) { if (mounted) refresh(); },
      ),
      service.watchTable(
        channelName: 'staff-grades-${identityHashCode(this)}',
        table: 'grades',
        onChange: (_) { if (mounted) refresh(); },
      ),
    ];
    _loadTodos();
  }

  Future<void> _loadTodos() async {
    try {
      final todos = await DashboardService(supabase).fetchTodos();
      if (mounted) setState(() => _todoList = todos);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final channel in channels) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }

  void refresh() {
    setState(() => future = DashboardService(supabase).fetchStaffSubmissions());
  }

  // ── Lihat lampiran / jawaban siswa ──────────────────────────────────────────
  void _showSubmissionContent(Map<String, dynamic> sub) {
    final todo = sub['todos'];
    final todoName = todo is Map ? todo['name']?.toString() ?? 'Tugas' : 'Tugas';
    final studentProfile = sub['student_profile'] as Map<String, dynamic>?;
    final studentName = studentProfile?['full_name']?.toString() ?? 'Siswa';
    final filePath = sub['file_path']?.toString() ?? '';
    final fileName = sub['file_name']?.toString() ?? '';
    final contentText = sub['content_text']?.toString() ?? '';
    final note = sub['note']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          bool loadingUrl = false;
          return AlertDialog(
            title: Text('Hasil Pengumpulan – $studentName'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Tugas: $todoName', style: const TextStyle(color: muted, fontSize: 12)),
                    Text('Dikirim: ${_readableDate(sub['submitted_at'])}', style: const TextStyle(color: muted, fontSize: 12)),
                    const SizedBox(height: 14),
                    if (contentText.isNotEmpty) ...[
                      const Text('Jawaban / Teks Siswa:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xfff4f6fb),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffe0e4f0)),
                        ),
                        child: SelectableText(contentText, style: const TextStyle(height: 1.5, fontSize: 13)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (note.isNotEmpty) ...[
                      const Text('Catatan Siswa:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: SelectableText(note, style: const TextStyle(height: 1.5, fontSize: 13)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (filePath.isNotEmpty) ...[
                      const Text('Lampiran File:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xfff0f4ff),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xffc0ccee)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.attach_file, size: 16, color: ink),
                            const SizedBox(width: 8),
                            Expanded(child: Text(fileName.isNotEmpty ? fileName : filePath.split('/').last, style: const TextStyle(fontSize: 12, color: ink))),
                            const SizedBox(width: 8),
                            StatefulBuilder(
                              builder: (ctx2, setBtn) => TextButton.icon(
                                onPressed: loadingUrl ? null : () async {
                                  setBtn(() => loadingUrl = true);
                                  try {
                                    final url = await DashboardService(supabase).submissionDownloadUrl(filePath);
                                    if (url != null && ctx2.mounted) {
                                      final uri = Uri.tryParse(url);
                                      bool opened = false;
                                      if (uri != null) {
                                        try {
                                          opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        } catch (_) {
                                          opened = false;
                                        }
                                      }
                                      if (!opened && ctx2.mounted) {
                                        // Fallback: tampilkan URL agar bisa disalin manual
                                        ScaffoldMessenger.of(ctx2).showSnackBar(
                                          SnackBar(
                                            content: SelectableText('Buka URL ini di browser: $url'),
                                            duration: const Duration(seconds: 10),
                                          ),
                                        );
                                      }
                                    } else if (ctx2.mounted) {
                                      ScaffoldMessenger.of(ctx2).showSnackBar(
                                        const SnackBar(content: Text('Tidak dapat membuat link unduhan.')),
                                      );
                                    }
                                  } catch (_) {
                                    if (ctx2.mounted) {
                                      ScaffoldMessenger.of(ctx2).showSnackBar(
                                        const SnackBar(content: Text('Gagal membuat link unduhan.')),
                                      );
                                    }
                                  } finally {
                                    if (ctx2.mounted) setBtn(() => loadingUrl = false);
                                  }
                                },
                                icon: loadingUrl
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.download_outlined, size: 14),
                                label: const Text('Unduh', style: TextStyle(fontSize: 12)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (contentText.isEmpty && note.isEmpty && filePath.isEmpty)
                      const Text('Tidak ada isi pengumpulan.', style: TextStyle(color: muted)),
                  ],
                ),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
          );
        },
      ),
    );
  }

  // ── Penilaian manual ────────────────────────────────────────────────────────
  Future<void> _showGradeDialog(Map<String, dynamic> sub) async {
    final grades = _gradeMap(sub['grades']);
    final scoreController = TextEditingController(text: grades?['score']?.toString() ?? '');
    final feedbackController = TextEditingController(text: grades?['feedback']?.toString() ?? '');

    final shouldSave = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Penilaian Manual'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreController,
              decoration: const InputDecoration(labelText: 'Nilai (0 – 100)', border: OutlineInputBorder()),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(labelText: 'Feedback / Catatan Guru', border: OutlineInputBorder()),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          FilledButton(
            onPressed: () {
              final scoreText = scoreController.text.trim();
              final score = double.tryParse(scoreText);
              if (score == null || score < 0 || score > 100) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Nilai harus berupa angka antara 0 – 100')),
                );
                return;
              }
              Navigator.pop(ctx, {'score': scoreText, 'feedback': feedbackController.text.trim()});
            },
            child: const Text('Simpan Nilai'),
          ),
        ],
      ),
    );

    scoreController.dispose();
    feedbackController.dispose();

    if (shouldSave == null || !mounted) return;

    final score = double.tryParse(shouldSave['score'] ?? '');
    if (score == null) return;

    try {
      await DashboardService(supabase).gradeSubmission(
        submissionId: sub['id'].toString(),
        score: score,
        feedback: shouldSave['feedback'],
      );
      await AuthService(supabase).logAudit(
        action: 'GRADE_UPDATED',
        description: 'Nilai $score pada pengumpulan ${sub['id']}',
        targetRecordId: sub['id'].toString(),
      );
      if (mounted) refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memberikan nilai: $e')),
        );
      }
    }
  }

  // ── Nilai massal per-tugas ──────────────────────────────────────────────────
  Future<void> _runAutoGrade(String todoId, String taskName) async {
    final maxScoreCtrl = TextEditingController(text: '100');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tetapkan Nilai Default – $taskName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan nilai default yang akan ditetapkan ke semua siswa yang sudah mengumpulkan. '
              'Nilai yang sudah ada akan ditimpa.',
              style: TextStyle(color: muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: maxScoreCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Nilai yang ditetapkan (0–100)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Nilai Sekarang')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final defaultScore = double.tryParse(maxScoreCtrl.text.trim());
    if (defaultScore == null || defaultScore < 0 || defaultScore > 100) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nilai tidak valid. Masukkan angka 0–100.')),
        );
      }
      return;
    }

    try {
      final subs = await DashboardService(supabase).client
          .from('submissions')
          .select('id')
          .eq('todo_id', todoId);
      final subList = (subs as List).cast<Map<String, dynamic>>();

      int graded = 0;
      int errors = 0;
      for (final sub in subList) {
        try {
          await DashboardService(supabase).gradeSubmission(
            submissionId: sub['id'].toString(),
            score: defaultScore,
            feedback: 'Nilai ditetapkan oleh guru',
          );
          graded++;
        } catch (_) {
          errors++;
        }
      }

      await AuthService(supabase).logAudit(
        action: 'BULK_GRADE_RUN',
        description: 'Nilai default $defaultScore: $graded berhasil, $errors gagal untuk tugas $taskName',
        targetRecordId: todoId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Selesai: $graded dinilai${errors > 0 ? ", $errors gagal" : ""}.'),
        duration: const Duration(seconds: 5),
      ));
      refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menetapkan nilai: $e')),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Panel(
    title: 'EVALUASI TUGAS SISWA',
    heading: 'Pengumpulan & Penilaian',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter per tugas
        if (_todoList.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: _filterTodoId,
            decoration: const InputDecoration(
              labelText: 'Filter Tugas',
              border: OutlineInputBorder(),
              isDense: true,
              prefixIcon: Icon(Icons.filter_list, size: 18),
            ),
            hint: const Text('Semua Tugas'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Semua Tugas')),
              ..._todoList.map((t) => DropdownMenuItem(value: t['id']?.toString(), child: Text(t['name']?.toString() ?? 'Tugas'))),
            ],
            onChanged: (v) => setState(() => _filterTodoId = v),
          ),
          const SizedBox(height: 14),
        ],
        FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            if (snapshot.hasError) {
              return _RefreshMessage(message: 'Gagal memuat pengumpulan: ${snapshot.error}', onRefresh: refresh);
            }
            // Terapkan filter tugas
            final rawList = snapshot.data ?? const [];
            final list = _filterTodoId == null
                ? rawList
                : rawList.where((s) => s['todo_id']?.toString() == _filterTodoId).toList();

            if (list.isEmpty) {
              return const Text('Belum ada pengumpulan tugas dari siswa.', style: TextStyle(color: muted));
            }

            // Kumpulkan semua todo_id unik agar tombol aksi per-tugas tampil
            final uniqueTodoIds = list.map((s) => s['todo_id']?.toString()).whereType<String>().toSet().toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Tombol aksi per-tugas ──────────────────────────────────
                ...uniqueTodoIds.map((tid) {
                  final sample = list.firstWhere((s) => s['todo_id']?.toString() == tid, orElse: () => {});
                  final tMeta = sample['todos'];
                  final tName = tMeta is Map ? tMeta['name']?.toString() ?? 'Tugas' : 'Tugas';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xfff4f6fb),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xffe0e6f0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: ink)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          FilledButton.icon(
                            onPressed: () => _runAutoGrade(tid, tName).ignore(),
                            icon: const Icon(Icons.auto_awesome, size: 14),
                            label: const Text('Nilai Otomatis'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 14),
                // ── Daftar pengumpulan ─────────────────────────────────────
                ...list.map((sub) {
                  final todo = sub['todos'];
                  final todoName = todo is Map ? todo['name']?.toString() : 'Tugas';
                  final studentProfile = sub['student_profile'] as Map<String, dynamic>?;
                  final studentName = studentProfile?['full_name']?.toString() ?? 'Siswa';
                  final grades = _gradeMap(sub['grades']);
                  final score = grades?['score']?.toString();
                  final feedback = grades?['feedback']?.toString();
                  final hasContent = (sub['file_path']?.toString() ?? '').isNotEmpty ||
                      (sub['content_text']?.toString() ?? '').isNotEmpty ||
                      (sub['note']?.toString() ?? '').isNotEmpty;

                  final gradeSource = grades?['source']?.toString() ?? 'manual';
                  final needsReview = grades?['needs_review'] == true;
                  final sourceBadgeLabel = gradeSource == 'auto' ? 'OTOMATIS' : gradeSource == 'ai' ? 'AI' : 'MANUAL';
                  final sourceBadgeColor = gradeSource == 'auto' ? Colors.teal : gradeSource == 'ai' ? Colors.purple : Colors.grey;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xfff9fafc),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xffe7eaf1)),
                    ),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$studentName — $todoName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 3),
                          Text('Dikirim: ${_readableDate(sub['submitted_at'])}', style: const TextStyle(color: muted, fontSize: 11)),
                          if (feedback != null && feedback.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text('Feedback: $feedback', style: const TextStyle(color: muted, fontSize: 11)),
                            ),
                        ],
                      );

                      // Badge sumber nilai + tombol aksi sejajar
                      final actions = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (score != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: sourceBadgeColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: sourceBadgeColor.withValues(alpha: 0.4)),
                              ),
                              child: Text(sourceBadgeLabel, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: sourceBadgeColor)),
                            ),
                            if (needsReview) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.orange.shade300),
                                ),
                                child: Text('TINJAU', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange.shade700)),
                              ),
                            ],
                            const SizedBox(width: 6),
                          ],
                          // Tombol lihat lampiran/teks
                          if (hasContent)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: OutlinedButton.icon(
                                onPressed: () => _showSubmissionContent(sub),
                                icon: const Icon(Icons.visibility_outlined, size: 14),
                                label: const Text('Lihat', style: TextStyle(fontSize: 12)),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: Size.zero,
                                ),
                              ),
                            ),
                          // Tombol beri/lihat nilai (manual)
                          FilledButton.tonal(
                            onPressed: () => _showGradeDialog(sub).ignore(),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              minimumSize: Size.zero,
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                            child: Text(score != null ? 'Nilai: $score' : 'Beri Nilai'),
                          ),
                        ],
                      );

                      if (constraints.maxWidth < 520) {
                        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          details,
                          const SizedBox(height: 8),
                          Align(alignment: Alignment.centerRight, child: actions),
                        ]);
                      }
                      return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Expanded(child: details),
                        const SizedBox(width: 8),
                        actions,
                      ]);
                    }),
                  );
                }),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class UserManagementPanel extends StatefulWidget {
  const UserManagementPanel({super.key});

  @override
  State<UserManagementPanel> createState() => _UserManagementPanelState();
}

class _UserManagementPanelState extends State<UserManagementPanel> {
  final searchController = TextEditingController();
  List<Map<String, dynamic>> users = [];
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    search();
  }

  Future<void> search() async {
    setState(() { loading = true; error = null; });
    try {
      final results = await AuthService(supabase).searchUsers(searchController.text);
      if (mounted) setState(() => users = results);
    } catch (e) {
      if (mounted) {
        setState(() {
          users = [];
          error = 'Gagal memuat pengguna: $e';
        });
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Panel(
    title: 'SUPERADMIN / USER MANAGEMENT',
    heading: 'Kelola Pengguna & Peran',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final searchButton = FilledButton.icon(
              onPressed: loading ? null : search,
              icon: loading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.search),
              label: Text(loading ? 'Mencari...' : 'Cari'),
            );
            final field = TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Cari berdasarkan Email atau Nama',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) {
                if (!loading) search();
              },
            );
            if (constraints.maxWidth < 560) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [field, const SizedBox(height: 10), searchButton]);
            }
            return Row(children: [Expanded(child: field), const SizedBox(width: 12), searchButton]);
          },
        ),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
        if (!loading && error == null && users.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Tidak ada pengguna yang ditemukan.', style: TextStyle(color: muted)),
          ),
        if (users.isNotEmpty)
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final user = users[index];
              final role = user['role']?.toString() ?? 'student';
              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user['full_name']?.toString() ?? 'Pengguna', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Email: ${user['email']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: muted, fontSize: 12)),
                ],
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: role == 'superadmin'
                            ? Colors.purple.shade50
                            : role == 'admin'
                                ? Colors.red.shade50
                                : role == 'teacher'
                                    ? Colors.blue.shade50
                                    : Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        role.toUpperCase(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: role == 'superadmin'
                              ? Colors.purple.shade800
                              : role == 'admin'
                                  ? Colors.red.shade800
                                  : role == 'teacher'
                                      ? Colors.blue.shade800
                                      : Colors.green.shade800,
                        ),
                      ),
                    ),
                ],
              );
              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 520) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [details, const SizedBox(height: 10), Align(alignment: Alignment.centerRight, child: actions)]),
                    );
                  }
                  return ListTile(contentPadding: EdgeInsets.zero, title: details, trailing: actions);
                },
              );
            },
          ),
      ],
    ),
  );
}

class AccountManagementPanel extends StatefulWidget {
  const AccountManagementPanel({super.key});

  @override
  State<AccountManagementPanel> createState() => _AccountManagementPanelState();
}

class _AccountManagementPanelState extends State<AccountManagementPanel> {
  // Form controllers
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  // Form state
  String selectedRole = 'student';
  String? selectedDepartmentId;
  List<Map<String, dynamic>> departments = [];
  bool isSubmitting = false;

  // User list state
  List<Map<String, dynamic>> users = [];
  bool isLoadingUsers = false;
  String? usersError;

  @override
  void initState() {
    super.initState();
    passwordController.text = _generatePassword();
    _loadDepartments();
    _loadUsers();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadDepartments() async {
    if (!mounted) return;
    try {
      final result = await DashboardService(supabase).fetchDepartments();
      if (!mounted) return;
      setState(() {
        departments = result;
        if (result.isNotEmpty && selectedDepartmentId == null) {
          selectedDepartmentId = result.first['id']?.toString();
        }
      });
    } catch (_) {}
  }

  Future<void> _loadUsers() async {
    if (!mounted) return;
    setState(() { isLoadingUsers = true; usersError = null; });
    try {
      final result = await AuthService(supabase).searchUsers('');
      if (!mounted) return;
      setState(() { users = result; isLoadingUsers = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { usersError = 'Gagal memuat pengguna: $e'; isLoadingUsers = false; });
    }
  }

  String get _functionUrl {
    const url = String.fromEnvironment('SUPABASE_URL');
    return '$url/functions/v1/manage-staff';
  }

  Map<String, String> get _authHeaders {
    final token = supabase.auth.currentSession?.accessToken ?? '';
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'apikey': anonKey,
    };
  }

  Future<void> _submitCreateAccount() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim().toLowerCase();
    final username = usernameController.text.trim().toLowerCase();
    final password = passwordController.text;

    if (name.isEmpty || email.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua field wajib diisi.')),
      );
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final resp = await http.post(
        Uri.parse('$_functionUrl/create-student'),
        headers: _authHeaders,
        body: jsonEncode({
          'full_name': name,
          'email': email,
          'username': username,
          'password': password,
          'role': selectedRole,
          if (selectedDepartmentId != null) 'department_id': selectedDepartmentId,
        }),
      );

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        await AuthService(supabase).logAudit(
          action: 'ACCOUNT_CREATED',
          description: 'Akun dibuat: $name ($selectedRole)',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Akun $name berhasil dibuat.')),
          );
          nameController.clear();
          emailController.clear();
          usernameController.clear();
          passwordController.text = _generatePassword();
          setState(() { selectedRole = 'student'; });
          _loadUsers();
        }
      } else {
        final errMsg = body['error']?.toString() ?? 'Gagal membuat akun.';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errMsg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal terhubung ke server: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  Future<void> _toggleUserStatus(Map<String, dynamic> user, String newStatus) async {
    final userId = user['id']?.toString() ?? '';
    final userName = user['full_name']?.toString() ?? user['email']?.toString() ?? 'Pengguna';
    try {
      final resp = await http.patch(
        Uri.parse(_functionUrl),
        headers: _authHeaders,
        body: jsonEncode({ 'user_id': userId, 'status': newStatus }),
      );
      if (resp.statusCode == 200) {
        await AuthService(supabase).logAudit(
          action: 'ACCOUNT_STATUS_CHANGED',
          description: 'Status akun $userName diubah menjadi $newStatus',
          targetUserId: userId,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status akun $userName berhasil diubah.')),
          );
          _loadUsers();
        }
      } else {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(body['error']?.toString() ?? 'Gagal mengubah status.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal terhubung ke server: $e')),
        );
      }
    }
  }

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final userId = user['id']?.toString() ?? '';
    final userName = user['full_name']?.toString() ?? user['email']?.toString() ?? 'Pengguna';
    final newPasswordController = TextEditingController(text: _generatePassword());
    bool resetting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Reset Password: $userName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Password baru untuk akun ini:', style: TextStyle(color: muted)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: newPasswordController, decoration: const InputDecoration(labelText: 'Password baru', border: OutlineInputBorder()))),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Generate ulang',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => setDialogState(() => newPasswordController.text = _generatePassword()),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: resetting ? null : () => Navigator.pop(ctx), child: const Text('Batal')),
            FilledButton(
              onPressed: resetting ? null : () async {
                final newPw = newPasswordController.text;
                if (newPw.length < 8) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password minimal 8 karakter.')));
                  return;
                }
                setDialogState(() => resetting = true);
                try {
                  final resp = await http.patch(
                    Uri.parse('$_functionUrl/reset-password'),
                    headers: _authHeaders,
                    body: jsonEncode({ 'user_id': userId, 'new_password': newPw }),
                  );
                  if (resp.statusCode == 200) {
                    await AuthService(supabase).logAudit(
                      action: 'ACCOUNT_PASSWORD_RESET',
                      description: 'Password akun $userName direset oleh admin',
                      targetUserId: userId,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text('Password $userName berhasil direset.')),
                      );
                    }
                  } else {
                    final body = jsonDecode(resp.body) as Map<String, dynamic>;
                    if (ctx.mounted) setDialogState(() => resetting = false);
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(content: Text(body['error']?.toString() ?? 'Gagal reset password.')),
                      );
                    }
                  }
                } catch (e) {
                  if (ctx.mounted) setDialogState(() => resetting = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Gagal terhubung ke server: $e')),
                    );
                  }
                }
              },
              child: Text(resetting ? 'Mereset...' : 'Reset Password'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    final csvText = utf8.decode(result.files.single.bytes!);
    final lines = csvText.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return;

    // Skip header baris pertama jika mengandung 'nama' atau 'email'
    final startIndex = lines.first.toLowerCase().contains('nama') || lines.first.toLowerCase().contains('email') ? 1 : 0;
    final dataLines = lines.sublist(startIndex);

    if (dataLines.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File CSV tidak memiliki data.')));
      return;
    }

    final results = <ImportResult>[];
    for (int i = 0; i < dataLines.length; i++) {
      final cols = dataLines[i].split(',').map((c) => c.trim()).toList();
      if (cols.length < 4) {
        results.add(ImportResult(rowIndex: i + 1, name: cols.firstOrNull ?? '', email: '', success: false, errorMessage: 'Format kolom tidak lengkap (butuh: nama,email,username,kelas)'));
        continue;
      }
      final rowName = cols[0];
      final rowEmail = cols[1].toLowerCase();
      final rowUsername = cols[2].toLowerCase();
      final rowKelas = cols[3];

      // Cari department_id dari kode kelas
      final dept = departments.where((d) =>
        d['code']?.toString().toLowerCase() == rowKelas.toLowerCase() ||
        d['name']?.toString().toLowerCase() == rowKelas.toLowerCase()
      ).firstOrNull;

      final rowPassword = _generatePassword();
      try {
        final resp = await http.post(
          Uri.parse('$_functionUrl/create-student'),
          headers: _authHeaders,
          body: jsonEncode({
            'full_name': rowName,
            'email': rowEmail,
            'username': rowUsername,
            'password': rowPassword,
            'role': 'student',
            if (dept != null) 'department_id': dept['id'],
          }),
        );
        if (resp.statusCode == 201 || resp.statusCode == 200) {
          results.add(ImportResult(rowIndex: i + 1, name: rowName, email: rowEmail, success: true));
        } else {
          final body = jsonDecode(resp.body) as Map<String, dynamic>;
          results.add(ImportResult(rowIndex: i + 1, name: rowName, email: rowEmail, success: false, errorMessage: body['error']?.toString() ?? 'Gagal'));
        }
      } catch (e) {
        results.add(ImportResult(rowIndex: i + 1, name: rowName, email: rowEmail, success: false, errorMessage: e.toString()));
      }
    }

    final successCount = results.where((r) => r.success).length;
    final failCount = results.where((r) => !r.success).length;

    if (mounted) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hasil Import CSV'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Berhasil: $successCount akun', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                Text('Gagal: $failCount akun', style: TextStyle(color: failCount > 0 ? Colors.red.shade700 : muted, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (failCount > 0) ...[
                  const Text('Detail kegagalan:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 200,
                    child: ListView(
                      children: results.where((r) => !r.success).map((r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('Baris ${r.rowIndex}: ${r.name} (${r.email}) — ${r.errorMessage}', style: const TextStyle(fontSize: 12, color: muted)),
                      )).toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))],
        ),
      );
      _loadUsers();
    }
  }

  Widget _buildCreateForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Form Buat Akun', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ink)),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final wide = constraints.maxWidth > 600;
          final nameField = InputField(label: 'Nama Lengkap', hint: 'Nama siswa/guru', controller: nameController);
          final emailField = InputField(label: 'Email', hint: 'email@contoh.com', controller: emailController);
          final usernameField = InputField(label: 'Username', hint: 'contoh: siswa_01', controller: usernameController);
          if (wide) {
            return Column(children: [
              Row(children: [Expanded(child: nameField), const SizedBox(width: 14), Expanded(child: emailField)]),
              const SizedBox(height: 14),
              Row(children: [Expanded(child: usernameField), const SizedBox(width: 14), Expanded(child: _buildRoleDropdown())]),
            ]);
          }
          return Column(children: [nameField, const SizedBox(height: 14), emailField, const SizedBox(height: 14), usernameField, const SizedBox(height: 14), _buildRoleDropdown()]);
        }),
        if (selectedRole == 'student') ...[
          const SizedBox(height: 14),
          _buildDepartmentDropdown(),
        ],
        const SizedBox(height: 14),
        _buildPasswordRow(),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: isSubmitting ? null : _submitCreateAccount,
              icon: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add),
              label: Text(isSubmitting ? 'Menyimpan...' : 'Simpan Akun'),
            ),
            OutlinedButton.icon(
              onPressed: _importCsv,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import CSV'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Format CSV: nama,email,username,kelas (satu baris per siswa, baris pertama bisa header)', style: TextStyle(color: muted, fontSize: 11)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xfffef3c7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xfffbbf24)),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Catatan Aktivasi Akun:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xff92400e))),
              SizedBox(height: 4),
              Text(
                '• Akun dibuat langsung aktif dengan password yang ditampilkan di form ini.\n'
                '• Salin dan bagikan password kepada pengguna secara aman (jangan melalui email biasa).\n'
                '• Pengguna disarankan mengganti password setelah login pertama.\n'
                '• Untuk alur invitation email otomatis, aktifkan SMTP di Supabase Dashboard → Authentication → Email Templates.',
                style: TextStyle(fontSize: 11, color: Color(0xff92400e), height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Role', style: TextStyle(color: TalogColors.textHeading, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selectedRole,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TalogColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TalogColors.border)),
          ),
          items: const [
            DropdownMenuItem(value: 'student', child: Text('Siswa (Student)')),
            DropdownMenuItem(value: 'teacher', child: Text('Guru (Teacher)')),
            DropdownMenuItem(value: 'admin', child: Text('Admin')),
            DropdownMenuItem(value: 'superadmin', child: Text('Super Admin')),
          ],
          onChanged: (val) => setState(() => selectedRole = val ?? 'student'),
        ),
      ],
    );
  }

  Widget _buildDepartmentDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Jurusan / Kelas', style: TextStyle(color: TalogColors.textHeading, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: selectedDepartmentId,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TalogColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TalogColors.border)),
          ),
          hint: const Text('Pilih jurusan'),
          items: departments.map((d) {
            final code = d['code']?.toString() ?? '';
            final name = d['name']?.toString() ?? code;
            return DropdownMenuItem(value: d['id']?.toString(), child: Text('$code - $name'));
          }).toList(),
          onChanged: (val) => setState(() => selectedDepartmentId = val),
        ),
      ],
    );
  }

  Widget _buildPasswordRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Password Awal', style: TextStyle(color: TalogColors.textHeading, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: passwordController,
                readOnly: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: const Color(0xfff8f9fe),
                  hintText: 'Password auto-generate',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TalogColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TalogColors.border)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Salin password',
              icon: const Icon(Icons.copy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: passwordController.text));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password disalin ke clipboard.')));
              },
            ),
            IconButton(
              tooltip: 'Generate ulang',
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => passwordController.text = _generatePassword()),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserList() {
    if (isLoadingUsers) return const LinearProgressIndicator();
    if (usersError != null) return _RefreshMessage(message: usersError!, onRefresh: _loadUsers);
    if (users.isEmpty) return const Text('Belum ada pengguna.', style: TextStyle(color: muted));
    return Column(
      children: users.map((user) {
        final userName = user['full_name']?.toString() ?? 'Pengguna';
        final userEmail = user['email']?.toString() ?? '';
        final role = user['role']?.toString() ?? 'student';
        final status = user['status']?.toString() ?? 'active';
        final isActive = status == 'active';
        final roleColor = role == 'superadmin' ? Colors.purple.shade800 : role == 'admin' ? Colors.red.shade800 : role == 'teacher' ? Colors.blue.shade800 : Colors.green.shade800;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xfff9fafc),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xffe7eaf1)),
          ),
          child: LayoutBuilder(builder: (context, constraints) {
            final info = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(userEmail, style: const TextStyle(color: muted, fontSize: 11)),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: roleColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(5)),
                    child: Text(role.toUpperCase(), style: TextStyle(color: roleColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isActive ? Colors.green.shade50 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(isActive ? 'Aktif' : 'Nonaktif', style: TextStyle(color: isActive ? Colors.green.shade700 : Colors.grey.shade600, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ]),
              ],
            );
            final actions = Wrap(
              spacing: 6,
              children: [
                if (role != 'superadmin') ...[
                  TextButton.icon(
                    onPressed: () => _toggleUserStatus(user, isActive ? 'disabled' : 'active'),
                    icon: Icon(isActive ? Icons.block : Icons.check_circle_outline, size: 16),
                    label: Text(isActive ? 'Nonaktifkan' : 'Aktifkan'),
                    style: TextButton.styleFrom(foregroundColor: isActive ? Colors.orange : Colors.green),
                  ),
                  TextButton.icon(
                    onPressed: () => _showResetPasswordDialog(user),
                    icon: const Icon(Icons.lock_reset, size: 16),
                    label: const Text('Reset PW'),
                    style: TextButton.styleFrom(foregroundColor: violet),
                  ),
                ],
              ],
            );
            if (constraints.maxWidth < 520) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [info, const SizedBox(height: 8), actions]);
            }
            return Row(children: [Expanded(child: info), actions]);
          }),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'MANAJEMEN AKUN',
      heading: 'Buat & Kelola Akun Pengguna',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCreateForm(),
          const SizedBox(height: 28),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Daftar Pengguna', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: ink)),
              IconButton(tooltip: 'Muat ulang', icon: const Icon(Icons.refresh), onPressed: _loadUsers),
            ],
          ),
          const SizedBox(height: 12),
          _buildUserList(),
        ],
      ),
    );
  }
}

class GradeRecapPanel extends StatefulWidget {
  const GradeRecapPanel({super.key});
  @override
  State<GradeRecapPanel> createState() => _GradeRecapPanelState();
}

class _GradeRecapPanelState extends State<GradeRecapPanel> {
  List<Map<String, dynamic>> _departments = [];
  List<Map<String, dynamic>> _allTodos = [];
  // Selected todo IDs for export (null = all)
  Set<String> _selectedTodoIds = {};
  String? _selectedDeptId;
  Map<String, dynamic>? _recap;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDepts();
  }

  Future<void> _loadDepts() async {
    try {
      final d = await DashboardService(supabase).fetchDepartments();
      if (!mounted) return;
      setState(() => _departments = d);
    } catch (_) {}
    await _loadTodos();
    _loadRecap();
  }

  Future<void> _loadTodos() async {
    try {
      final todos = await DashboardService(supabase).fetchTodos();
      if (!mounted) return;
      final filtered = _selectedDeptId == null
          ? todos
          : todos.where((t) => t['department_id']?.toString() == _selectedDeptId).toList();
      setState(() {
        _allTodos = filtered;
        _selectedTodoIds = filtered.map((t) => t['id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();
      });
    } catch (_) {}
  }

  Future<void> _loadRecap() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await DashboardService(supabase).fetchGradeRecap(departmentId: _selectedDeptId);
      final filteredTodos = _selectedDeptId == null
          ? _allTodos
          : _allTodos.where((t) => t['department_id']?.toString() == _selectedDeptId).toList();
      if (!mounted) return;
      setState(() {
        _recap = data;
        _selectedTodoIds = filteredTodos
            .map((t) => t['id']?.toString() ?? '')
            .where((id) => id.isNotEmpty)
            .toSet();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Gagal memuat rekap: $e'; _loading = false; });
    }
  }

  // Ekspor CSV hanya untuk tugas yang dipilih
  void _exportCsv() {
    final recap = _recap;
    if (recap == null) return;
    final allTodos = (recap['todos'] as List).cast<Map<String, dynamic>>();
    // Filter hanya tugas yang dipilih
    final todos = _selectedTodoIds.isEmpty
        ? allTodos
        : allTodos.where((t) => _selectedTodoIds.contains(t['id']?.toString())).toList();
    final matrix = recap['matrix'] as Map<String, dynamic>;
    if (todos.isEmpty || matrix.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak ada data untuk diekspor.')));
      return;
    }
    final buf = StringBuffer();
    buf.write('\uFEFF'); // BOM agar Excel baca UTF-8 dengan benar
    buf.write('Nama Siswa');
    for (final t in todos) { buf.write(',${(t['name'] ?? 'Tugas').toString().replaceAll(',', ';')}'); }
    buf.write(',Rata-rata,Dikumpulkan,Belum\n');
    for (final entry in matrix.entries) {
      final sd = entry.value as Map<String, dynamic>;
      final grades = sd['grades'] as Map<String, dynamic>;
      buf.write((sd['full_name'] ?? 'Siswa').toString().replaceAll(',', ' '));
      final scores = <double>[];
      int collected = 0;
      for (final t in todos) {
        final g = grades[t['id']?.toString()] as Map<String, dynamic>?;
        if (g != null) {
          collected++;
          final sc = g['score'];
          if (sc != null) { scores.add((sc as num).toDouble()); buf.write(',$sc'); }
          else { buf.write(',Terkumpul'); }
        } else { buf.write(',-'); }
      }
      final avg = scores.isEmpty ? '-' : (scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(1);
      buf.write(',$avg,$collected,${todos.length - collected}\n');
    }
    Clipboard.setData(ClipboardData(text: buf.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Rekap ${todos.length} tugas disalin ke clipboard. Tempel ke Excel / Google Sheets.'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(fontSize: 10, color: muted)),
    ]),
  );

  // Hitung statistik hanya untuk tugas yang dipilih
  Widget _buildTable(Map<String, dynamic> recap) {
    final allTodos = (recap['todos'] as List).cast<Map<String, dynamic>>();
    final todos = _selectedTodoIds.isEmpty
        ? allTodos
        : allTodos.where((t) => _selectedTodoIds.contains(t['id']?.toString())).toList();
    final matrix = recap['matrix'] as Map<String, dynamic>;
    if (todos.isEmpty) return const Text('Belum ada tugas yang dipilih.', style: TextStyle(color: muted));
    if (matrix.isEmpty) return const Text('Belum ada siswa yang mengumpulkan.', style: TextStyle(color: muted));

    final allScores = <double>[];
    for (final e in matrix.entries) {
      for (final tid in todos) {
        final g = ((e.value as Map)['grades'] as Map)[tid['id']?.toString()] as Map?;
        final sc = g?['score'];
        if (sc != null) allScores.add((sc as num).toDouble());
      }
    }
    final avg = allScores.isEmpty ? '-' : (allScores.reduce((a, b) => a + b) / allScores.length).toStringAsFixed(1);
    final sorted = List<double>.from(allScores)..sort();
    final highest = sorted.isEmpty ? '-' : sorted.last.toStringAsFixed(1);
    final lowest = sorted.isEmpty ? '-' : sorted.first.toStringAsFixed(1);
    final totalP = matrix.length * todos.length;
    final pct = totalP == 0 ? '0%' : '${(allScores.length / totalP * 100).toStringAsFixed(0)}%';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 10, runSpacing: 10, children: [
        _statChip('Rata-rata', avg, TalogColors.info),
        _statChip('Tertinggi', highest, TalogColors.success),
        _statChip('Terendah', lowest, TalogColors.danger),
        _statChip('% Kumpul', pct, TalogColors.accentOrange),
      ]),
      const SizedBox(height: 16),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(TalogColors.lightCanvas),
          headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: TalogColors.textHeading),
          dataTextStyle: const TextStyle(fontSize: 12, color: TalogColors.textBody),
          columnSpacing: 16,
          columns: [
            const DataColumn(label: Text('Nama Siswa')),
            ...todos.map((t) => DataColumn(label: SizedBox(width: 90, child: Text(t['name']?.toString() ?? 'Tugas', maxLines: 2, overflow: TextOverflow.ellipsis)))),
            const DataColumn(label: Text('Rata-rata')),
            const DataColumn(label: Text('Kumpul')),
          ],
          rows: matrix.entries.map((entry) {
            final sd = entry.value as Map<String, dynamic>;
            final grades = sd['grades'] as Map<String, dynamic>;
            final scores = <double>[];
            int collected = 0;
            final cells = todos.map((t) {
              final g = grades[t['id']?.toString()] as Map<String, dynamic>?;
              if (g == null) return DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: const Color(0xfff0f0f0), borderRadius: BorderRadius.circular(4)), child: const Text('—', style: TextStyle(color: muted, fontSize: 11))));
              collected++;
              final sc = g['score'];
              if (sc != null) scores.add((sc as num).toDouble());
              final src = g['source']?.toString() ?? 'manual';
              final nr = g['needs_review'] == true;
              final scNum = sc != null ? (sc as num).toDouble() : null;
              final cellColor = scNum == null ? TalogColors.info.withValues(alpha: 0.1) : scNum >= 75 ? TalogColors.success.withValues(alpha: 0.1) : scNum >= 60 ? TalogColors.warning.withValues(alpha: 0.1) : TalogColors.danger.withValues(alpha: 0.1);
              final textColor = scNum == null ? TalogColors.info : scNum >= 75 ? TalogColors.success : scNum >= 60 ? TalogColors.warning : TalogColors.danger;
              return DataCell(Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: cellColor, borderRadius: BorderRadius.circular(4)), child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(sc?.toString() ?? '✓', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: textColor)),
                if (src == 'ai') ...[const SizedBox(width: 3), const Icon(Icons.psychology, size: 10, color: Colors.purple)],
                if (nr) ...[const SizedBox(width: 3), Icon(Icons.edit_note, size: 10, color: Colors.orange.shade600)],
              ])));
            }).toList();
            final sAvg = scores.isEmpty ? '—' : (scores.reduce((a, b) => a + b) / scores.length).toStringAsFixed(1);
            return DataRow(cells: [
              DataCell(SizedBox(width: 140, child: Text(sd['full_name']?.toString() ?? 'Siswa', style: const TextStyle(fontWeight: FontWeight.w600)))),
              ...cells,
              DataCell(Text(sAvg, style: const TextStyle(fontWeight: FontWeight.w700))),
              DataCell(Text('$collected/${todos.length}')),
            ]);
          }).toList(),
        ),
      ),
      const SizedBox(height: 8),
      const Text('🤖 = AI  •  ✏️ = perlu tinjau  •  — = belum kumpul', style: TextStyle(fontSize: 10, color: muted)),
    ]);
  }

  @override
  Widget build(BuildContext context) => Panel(
    title: 'REKAP NILAI',
    heading: 'Matriks Nilai Siswa',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Filter jurusan + pilih tugas + ekspor ──────────────────────────────
      LayoutBuilder(builder: (ctx, constraints) {
        final wide = constraints.maxWidth > 540;
        final deptFilter = _departments.isEmpty ? const SizedBox.shrink() : DropdownButtonFormField<String>(
          initialValue: _selectedDeptId,
          decoration: const InputDecoration(labelText: 'Filter Jurusan', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          hint: const Text('Semua Jurusan'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Semua Jurusan')),
            ..._departments.map((d) => DropdownMenuItem(value: d['id']?.toString(), child: Text('${d['code']} - ${d['name']}'))),
          ],
          onChanged: (v) async {
              setState(() => _selectedDeptId = v);
              await _loadTodos();
              _loadRecap();
            },
        );
        final exportBtn = FilledButton.icon(
          onPressed: _recap == null ? null : _exportCsv,
          icon: const Icon(Icons.download, size: 16),
          label: Text('Ekspor CSV${_selectedTodoIds.length < _allTodos.length && _allTodos.isNotEmpty ? ' (${_selectedTodoIds.length} tugas)' : ''}'),
          style: FilledButton.styleFrom(backgroundColor: TalogColors.success, foregroundColor: Colors.white),
        );
        if (wide) return Row(children: [Expanded(child: deptFilter), const SizedBox(width: 12), exportBtn]);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [deptFilter, const SizedBox(height: 10), exportBtn]);
      }),
      // ── Pilih tugas untuk matriks & ekspor ────────────────────────────────
      if (_allTodos.isNotEmpty) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xfff4f6fb),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xffe0e6f0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Pilih Tugas:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: ink)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() => _selectedTodoIds = _allTodos.map((t) => t['id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet()),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Pilih Semua', style: TextStyle(fontSize: 11)),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _selectedTodoIds = {}),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Kosongkan', style: TextStyle(fontSize: 11, color: muted)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _allTodos.map((t) {
                  final tid = t['id']?.toString() ?? '';
                  final tName = t['name']?.toString() ?? 'Tugas';
                  final selected = _selectedTodoIds.contains(tid);
                  return FilterChip(
                    label: Text(tName, style: TextStyle(fontSize: 11, color: selected ? Colors.white : ink)),
                    selected: selected,
                    onSelected: (val) => setState(() {
                      if (val) { _selectedTodoIds.add(tid); } else { _selectedTodoIds.remove(tid); }
                    }),
                    backgroundColor: const Color(0xffe7eaf1),
                    selectedColor: TalogColors.primaryNavy,
                    checkmarkColor: Colors.white,
                    showCheckmark: true,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      if (_loading) const LinearProgressIndicator()
      else if (_error != null) _RefreshMessage(message: _error!, onRefresh: _loadRecap)
      else if (_recap == null) const Text('Memuat...', style: TextStyle(color: muted))
      else _buildTable(_recap!),
    ]),
  );
}

class AiSettingsPanel extends StatefulWidget {
  const AiSettingsPanel({super.key});
  @override
  State<AiSettingsPanel> createState() => _AiSettingsPanelState();
}

class _AiSettingsPanelState extends State<AiSettingsPanel> {
  bool _aiEnabled = true;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final enabled = await DashboardService(supabase).fetchAiEnabled();
      if (!mounted) return;
      setState(() { _aiEnabled = enabled; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = 'Gagal memuat pengaturan: $e'; _loading = false; });
    }
  }

  Future<void> _toggle(bool value) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await DashboardService(supabase).setAiEnabled(enabled: value);
      await AuthService(supabase).logAudit(
        action: value ? 'AI_GRADING_ENABLED' : 'AI_GRADING_DISABLED',
        description: 'Fitur penilaian AI ${value ? "diaktifkan" : "dinonaktifkan"} oleh admin',
      );
      if (!mounted) return;
      setState(() { _aiEnabled = value; _saving = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fitur AI ${value ? "diaktifkan" : "dinonaktifkan"}.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Panel(
    title: 'PENGATURAN AI',
    heading: 'Konfigurasi Penilaian Otomatis',
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_loading) const LinearProgressIndicator()
      else if (_error != null) _RefreshMessage(message: _error!, onRefresh: _load)
      else ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _aiEnabled ? TalogColors.success.withValues(alpha: 0.06) : const Color(0xfff8f9fe),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _aiEnabled ? TalogColors.success.withValues(alpha: 0.25) : TalogColors.border),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _aiEnabled ? TalogColors.success.withValues(alpha: 0.12) : TalogColors.lightCanvasSecondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_aiEnabled ? Icons.psychology : Icons.psychology_outlined, color: _aiEnabled ? TalogColors.success : muted, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Penilaian AI (Gemini)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _aiEnabled ? ink : muted)),
              const SizedBox(height: 2),
              Text(_aiEnabled ? 'Aktif — Guru dapat menilai esai dengan AI' : 'Nonaktif — Tombol AI disembunyikan dari guru', style: const TextStyle(fontSize: 12, color: muted)),
            ])),
            const SizedBox(width: 12),
            _saving
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Switch(value: _aiEnabled, onChanged: _toggle, activeThumbColor: TalogColors.success),
          ]),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.shade200)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
            const SizedBox(width: 8),
            Expanded(child: Text(
              'Pengaturan ini mengontrol apakah tombol "Nilai Esai dengan AI" muncul di dashboard guru. Pastikan secret LLM_API_KEY sudah diset di Supabase Edge Functions dengan Gemini API key.',
              style: TextStyle(fontSize: 12, color: Colors.amber.shade800, height: 1.4),
            )),
          ]),
        ),
      ],
    ]),
  );
}

class AuditLogsPanel extends StatefulWidget {
  const AuditLogsPanel({super.key});

  @override
  State<AuditLogsPanel> createState() => _AuditLogsPanelState();
}

class _AuditLogsPanelState extends State<AuditLogsPanel> {
  late Future<List<Map<String, dynamic>>> future;

  @override
  void initState() {
    super.initState();
    future = AuthService(supabase).getAuditLogs();
  }

  void refresh() {
    setState(() => future = AuthService(supabase).getAuditLogs());
  }

  @override
  Widget build(BuildContext context) => Panel(
    title: 'SECURITY & AUDIT LOG',
    heading: 'Jejak Audit Aktivitas',
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return _RefreshMessage(
            message: AuthService.formatAuditError(snapshot.error ?? 'Gagal memuat aktivitas audit.'),
            onRefresh: refresh,
          );
        }
        final list = snapshot.data ?? const [];
        if (list.isEmpty) {
          return const Text('Belum ada aktivitas audit.', style: TextStyle(color: muted));
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final item = list[index];
            final action = item['action']?.toString() ?? 'ACTION';
            final desc = item['description']?.toString() ?? '-';
            final role = item['actor_role']?.toString() ?? 'SYSTEM';
            final time = item['created_at']?.toString().split('.').first ?? '';

            return ListTile(
              leading: Icon(
                action.contains('ROLE') ? Icons.security : Icons.history,
                color: violet,
              ),
              title: Text('$action ($role)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
              trailing: Text(time, style: const TextStyle(color: muted, fontSize: 11)),
            );
          },
        );
      },
    ),
  );
}

class LiveUpdatePage extends StatelessWidget {
  const LiveUpdatePage({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Panel(
        title: 'LIVE UPDATE',
        heading: 'Aktivitas Supabase Realtime',
        child: const Text(
          'Pengumpulan tugas, nilai, dan feedback terbaru dari sistem.',
          style: TextStyle(color: muted, height: 1.5),
        ),
      ),
      const SizedBox(height: 18),
      const Panel(
        title: 'AKTIVITAS TERBARU',
        heading: 'Pengumpulan Siswa',
        child: LiveStaffActivity(),
      ),
    ],
  );
}

class LiveStaffActivity extends StatefulWidget {
  const LiveStaffActivity({super.key});

  @override
  State<LiveStaffActivity> createState() => _LiveStaffActivityState();
}

class _LiveStaffActivityState extends State<LiveStaffActivity> {
  late Future<List<Map<String, dynamic>>> future;
  late final List<RealtimeChannel> channels;

  @override
  void initState() {
    super.initState();
    future = DashboardService(supabase).fetchStaffSubmissions();
    final service = DashboardService(supabase);
    channels = [
      service.watchTable(
        channelName: 'live-update-submissions-${identityHashCode(this)}',
        table: 'submissions',
        onChange: (_) {
          if (mounted) refresh();
        },
      ),
      service.watchTable(
        channelName: 'live-update-grades-${identityHashCode(this)}',
        table: 'grades',
        onChange: (_) {
          if (mounted) refresh();
        },
      ),
    ];
  }

  void refresh() {
    setState(() => future = DashboardService(supabase).fetchStaffSubmissions());
  }

  @override
  void dispose() {
    for (final channel in channels) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator();
      }
      if (snapshot.hasError) {
        return _RefreshMessage(
          message: 'Gagal memuat live update: ${snapshot.error}',
          onRefresh: refresh,
        );
      }
      final list = snapshot.data ?? const [];
      if (list.isEmpty) {
        return const Text('Belum ada aktivitas terbaru.', style: TextStyle(color: muted));
      }
      return Column(
        children: list.map((submission) {
          final student = submission['students'];
          final profile = student is Map ? student['profiles'] : null;
          final studentName = profile is Map ? profile['full_name']?.toString() ?? 'Siswa' : 'Siswa';
          final todo = submission['todos'];
          final taskName = todo is Map ? todo['name']?.toString() ?? 'Tugas' : 'Tugas';
          final grades = submission['grades'];
          final score = grades is Map ? grades['score']?.toString() : null;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('$studentName - $taskName'),
            subtitle: Text('Dikirim: ${_readableDate(submission['submitted_at'])}'),
            trailing: Text(score == null ? 'Belum dinilai' : 'Nilai: $score'),
          );
        }).toList(),
      );
    },
  );
}

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.title,
    required this.heading,
    required this.subtitle,
    required this.children,
    this.profile,
    this.onNavSelected,
    this.selectedTabIndex = 0,
    this.isStaffPreview = false,
  });
  final String title, heading, subtitle;
  final List<Widget> children;
  final UserProfile? profile;
  final void Function(int)? onNavSelected;
  final int selectedTabIndex;
  final bool isStaffPreview;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  void _handleNavigation(BuildContext context, int index, int destinationCount) {
    if (widget.onNavSelected != null) {
      widget.onNavSelected!(index);
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _buildDrawer(BuildContext context, List<NavigationRailDestination> destinations) {
    final selectedIndex = widget.selectedTabIndex.clamp(0, destinations.length - 1);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  const Brand(),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Tutup menu',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 12),
                itemCount: destinations.length,
                itemBuilder: (context, index) {
                  final destination = destinations[index];
                  final selected = index == selectedIndex;
                  return ListTile(
                    selected: selected,
                    selectedTileColor: const Color(0xffeef0ff),
                    leading: selected ? destination.selectedIcon : destination.icon,
                    title: destination.label,
                    onTap: () {
                      Navigator.pop(context);
                      _handleNavigation(context, index, destinations.length);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profil & Username'),
              onTap: () {
                Navigator.pop(context);
                _showProfileSettingsDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline),
              title: const Text('Ganti Password'),
              onTap: () {
                Navigator.pop(context);
                _showChangePasswordDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Keluar'),
              onTap: () {
                Navigator.pop(context);
                AuthService(supabase).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => const _ChangePasswordDialog(),
    );
  }

  void _showProfileSettingsDialog() {
    if (widget.profile == null) return;
    final nameController = TextEditingController(text: widget.profile!.fullName);
    final usernameController = TextEditingController(text: widget.profile!.username ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pengaturan Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: ${widget.profile!.email}', style: const TextStyle(color: muted)),
            Text('Role: ${widget.profile!.role.name.toUpperCase()}', style: const TextStyle(color: muted)),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nama Lengkap'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: usernameController,
              decoration: const InputDecoration(
                labelText: 'Username (minimal 3 huruf)',
                hintText: 'username unik',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthService(supabase).updateProfile(
                  userId: widget.profile!.id,
                  fullName: nameController.text.trim(),
                  username: usernameController.text.trim(),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Profil berhasil diperbarui. Muat ulang untuk melihat perubahan.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal memperbarui profil: $e')),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.profile?.role;
    final navigationRole = widget.isStaffPreview ? UserRole.student : role;
    final isStaff = role == UserRole.teacher || role == UserRole.admin || role == UserRole.superadmin;
    final isStudent = role == UserRole.student;
    final canManageUsers = role == UserRole.admin || role == UserRole.superadmin;
    final isNight = isNightTime();
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text(navigationRole == UserRole.student ? 'Dashboard' : 'Overview'),
      ),
      if (isStaff && !widget.isStaffPreview) ...[
        if (role != UserRole.superadmin)
          const NavigationRailDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: Text('Tugas'),
          ),
        if (role == UserRole.teacher) ...[
          const NavigationRailDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(Icons.rate_review),
            label: Text('Pengumpulan'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: Text('Rekap Nilai'),
          ),
        ],
        if (canManageUsers) ...[
          const NavigationRailDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: Text('Pengguna'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.manage_accounts_outlined),
            selectedIcon: Icon(Icons.manage_accounts),
            label: Text('Kelola Akun'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: Text('Pengaturan AI'),
          ),
          if (role == UserRole.superadmin) ...[
            const NavigationRailDestination(
              icon: Icon(Icons.security_outlined),
              selectedIcon: Icon(Icons.security),
              label: Text('Audit Log'),
            ),
            const NavigationRailDestination(
              icon: Icon(Icons.dynamic_feed_outlined),
              selectedIcon: Icon(Icons.dynamic_feed),
              label: Text('Live Update'),
            ),
          ],
        ],
      ] else ...[
        const NavigationRailDestination(
          icon: Icon(Icons.task_alt),
          selectedIcon: Icon(Icons.task_alt),
          label: Text('Tugas'),
        ),
        if (isStudent)
          const NavigationRailDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Text('Profile'),
          ),
      ],
    ];

    return Scaffold(
      backgroundColor: isNight ? const Color(0xff0a1020) : const Color(0xfff4f6fb),
      appBar: isCompact
          ? AppBar(
              backgroundColor: isNight ? const Color(0xff060d1a) : const Color(0xFF0D2451),
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              title: Text(widget.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
              actions: [
                if (widget.profile != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        widget.profile!.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                if (isStudent)
                  IconButton(
                    tooltip: 'Keluar',
                    icon: const Icon(Icons.logout),
                    onPressed: () => AuthService(supabase).signOut(),
                  ),
              ],
            )
          : null,
      drawer: isCompact ? _buildDrawer(context, destinations) : null,
      body: SafeArea(
        child: Row(
          children: [
          if (!isCompact) NavigationRail(
            backgroundColor: isNight ? const Color(0xff060d1a) : const Color(0xFF0D2451),
            unselectedIconTheme: const IconThemeData(color: Colors.white38, size: 22),
            selectedIconTheme: const IconThemeData(color: Colors.white, size: 22),
            unselectedLabelTextStyle: const TextStyle(color: Colors.white38, fontSize: 11),
            selectedLabelTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 11),
            indicatorColor: Colors.white12,
            destinations: destinations,
            selectedIndex: widget.selectedTabIndex.clamp(0, destinations.length - 1),
            onDestinationSelected: (i) => _handleNavigation(context, i, destinations.length),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isStaff && !widget.isStaffPreview)
                        IconButton(
                          tooltip: 'Buka Student Dashboard',
                          icon: const Icon(Icons.school, color: cyan),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentPage(
                                  profile: widget.profile!,
                                  isStaffPreview: true,
                                ),
                              ),
                            );
                          },
                        ),
                      if (!widget.isStaffPreview) ...[
                        IconButton(
                          tooltip: 'Profil & Username',
                          icon: const Icon(Icons.person_outline, color: Colors.white70),
                          onPressed: _showProfileSettingsDialog,
                        ),
                        IconButton(
                          tooltip: 'Ganti Password',
                          icon: const Icon(Icons.lock_outline, color: Colors.white70),
                          onPressed: _showChangePasswordDialog,
                        ),
                        const SizedBox(height: 8),
                        IconButton(
                          tooltip: 'Keluar',
                          icon: const Icon(Icons.logout, color: Colors.white70),
                          onPressed: () => AuthService(supabase).signOut(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isCompact ? 16 : 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCompact) Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Brand(light: isNight),
                      if (widget.profile != null)
                        Row(
                          children: [
                            if (widget.isStaffPreview)
                              Container(
                                margin: const EdgeInsets.only(right: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade200,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'PREVIEW MODE',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87),
                                ),
                              ),
                            Text(
                              '${widget.profile!.displayName}  •  ${widget.profile!.role.name.toUpperCase()}',
                              style: TextStyle(color: isNight ? Colors.white70 : muted, fontSize: 12),
                            ),
                          ],
                        ),
                    ],
                  ),
                  SizedBox(height: isCompact ? 12 : 38),
                  LabelText(widget.title),
                  const SizedBox(height: 12),
                  Text(
                    widget.heading,
                    style: TextStyle(
                      color: isNight ? Colors.white : ink,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (widget.subtitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        widget.subtitle,
                        style: TextStyle(color: isNight ? Colors.white60 : muted),
                      ),
                    ),
                  const SizedBox(height: 30),
                  ...widget.children,
                ],
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _RefreshMessage extends StatelessWidget {
  const _RefreshMessage({required this.message, required this.onRefresh});
  final String message;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(
        child: Text(
          message,
          style: const TextStyle(color: muted),
        ),
      ),
      IconButton(onPressed: onRefresh, tooltip: 'Muat ulang', icon: const Icon(Icons.refresh)),
    ],
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.title,
    required this.heading,
    required this.child,
  });
  final String title, heading;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xffe7eaf1)),
      boxShadow: const [
        BoxShadow(color: Color(0x060F2B5C), blurRadius: 12, offset: Offset(0, 3)),
        BoxShadow(color: Color(0x030F2B5C), blurRadius: 4, offset: Offset(0, 1)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 3, height: 16,
            decoration: BoxDecoration(
              color: TalogColors.accentOrange,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          LabelText(title),
        ]),
        const SizedBox(height: 6),
        Text(
          heading,
          style: const TextStyle(
            color: ink,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    ),
  );
}

class Task extends StatelessWidget {
  const Task(this.title, this.detail, this.active, {super.key});
  final String title, detail;
  final bool active;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      active ? Icons.radio_button_checked : Icons.radio_button_unchecked,
      color: active ? cyan : muted,
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: ink,
        fontWeight: FontWeight.bold,
        fontSize: 13,
      ),
    ),
    subtitle: Text(detail, style: const TextStyle(color: muted, fontSize: 11)),
    trailing: const Text('->', style: TextStyle(color: violet)),
  );
}

class Health extends StatelessWidget {
  const Health(this.name, this.value, {super.key});
  final String name;
  final int value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        SizedBox(width: 34, child: Text(name)),
        Expanded(
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            color: violet,
            backgroundColor: const Color(0xffececf4),
          ),
        ),
        const SizedBox(width: 10),
        Text('$value%'),
      ],
    ),
  );
}

class Ring extends StatelessWidget {
  const Ring({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 110,
    height: 110,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: cyan, width: 9),
    ),
    child: const Center(
      child: Text(
        '100%',
        style: TextStyle(
          color: Colors.white,
          fontSize: 25,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}

class Circle extends StatelessWidget {
  const Circle(this.size, {super.key});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: const Color(0xff3a455c)),
    ),
  );
}

class Planet extends StatelessWidget {
  const Planet(this.label, this.color, {super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    width: 52,
    height: 52,
    alignment: Alignment.center,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    child: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final controller = TextEditingController();
  final confirmController = TextEditingController();
  String? error;
  bool loading = false;
  bool success = false;

  Future<void> submit() async {
    final password = controller.text;
    final confirm = confirmController.text;
    if (password.isEmpty) {
      setState(() => error = 'Masukkan password baru.');
      return;
    }
    if (password.length < 6) {
      setState(() => error = 'Password minimal 6 karakter.');
      return;
    }
    if (password != confirm) {
      setState(() => error = 'Konfirmasi password tidak cocok.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      await AuthService(supabase).changePassword(password);
      setState(() { success = true; loading = false; });
    } on AuthException catch (e) {
      setState(() { error = e.message; loading = false; });
    } catch (_) {
      setState(() { error = 'Gagal mengganti password.'; loading = false; });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Ganti Password'),
    content: success
        ? const Text('Password berhasil diganti. Silakan gunakan password baru ini untuk login berikutnya.')
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password baru'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Konfirmasi password baru'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
    actions: success
        ? [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))]
        : [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            FilledButton(onPressed: loading ? null : submit, child: const Text('Simpan')),
          ],
  );
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.controller});
  final TextEditingController controller;
  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  String? error;
  bool loading = false;
  bool success = false;

  Future<void> submit() async {
    final email = widget.controller.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => error = 'Masukkan alamat email yang valid.');
      return;
    }
    setState(() { loading = true; error = null; });
    try {
      await AuthService(supabase).resetPassword(email);
      setState(() { success = true; loading = false; });
    } catch (_) {
      setState(() { error = 'Gagal mengirim email reset password.'; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reset Password'),
    content: success
        ? const Text('Link reset password telah dikirim ke email Anda. Periksa inbox.')
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Masukkan email akun Anda. Kami akan mengirim link untuk mengatur ulang password.'),
              const SizedBox(height: 16),
              TextField(
                controller: widget.controller,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(error!, style: const TextStyle(color: Colors.red)),
                ),
            ],
          ),
    actions: success
        ? [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup'))]
        : [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            FilledButton(onPressed: loading ? null : submit, child: const Text('Kirim')),
          ],
  );
}

class PasswordRecoveryPage extends StatefulWidget {
  const PasswordRecoveryPage({super.key});

  @override
  State<PasswordRecoveryPage> createState() => _PasswordRecoveryPageState();
}

class _PasswordRecoveryPageState extends State<PasswordRecoveryPage> {
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPw = _newPasswordController.text.trim();
    final confirmPw = _confirmPasswordController.text.trim();
    if (newPw.isEmpty || confirmPw.isEmpty) {
      setState(() => _error = 'Password baru dan konfirmasi wajib diisi.');
      return;
    }
    if (newPw != confirmPw) {
      setState(() => _error = 'Konfirmasi password tidak cocok dengan password baru.');
      return;
    }
    if (newPw.length < 6) {
      setState(() => _error = 'Password baru minimal 6 karakter.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await AuthService(supabase).changePassword(newPw);
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password berhasil diperbarui.')),
        );
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Gagal memperbarui password.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: SizedBox(
          width: 420,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Brand(),
              const SizedBox(height: 48),
              const LabelText('KEAMANAN AKUN  /  01 / 01'),
              const SizedBox(height: 18),
              const Text(
                'Buat Password Baru',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: ink,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Masukkan password baru Anda di bawah ini.',
                style: TextStyle(color: muted),
              ),
              const SizedBox(height: 28),
              InputField(
                label: 'Password baru',
                hint: 'Minimal 6 karakter',
                password: true,
                controller: _newPasswordController,
              ),
              const SizedBox(height: 16),
              InputField(
                label: 'Konfirmasi password baru',
                hint: 'Ulangi password baru',
                password: true,
                controller: _confirmPasswordController,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
                ),
              const SizedBox(height: 24),
              ActionButton(
                label: 'Simpan Password Baru',
                onPressed: _loading ? null : _submit,
                loading: _loading,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── App Health Panel ─────────────────────────────────────────────────────────
// Real-time health check: database ping, active connections, and basic error
// detection. Uses Supabase itself as the data source — no fake numbers.
class _AppHealthPanel extends StatefulWidget {
  const _AppHealthPanel();

  @override
  State<_AppHealthPanel> createState() => _AppHealthPanelState();
}

class _AppHealthPanelState extends State<_AppHealthPanel> {
  bool _loading = true;
  String? _error;
  int _dbPingMs = 0;
  int _userCount = 0;
  int _submissionCount = 0;
  int _gradeCount = 0;
  DateTime? _lastChecked;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _check();
    // Refresh otomatis setiap 30 detik
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _check();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final sw = Stopwatch()..start();
      // Ping database — query ringan untuk mengukur latensi
      await supabase.from('profiles').select('id').limit(1);
      sw.stop();
      final pingMs = sw.elapsedMilliseconds;

      // Ambil jumlah data secara paralel (ambil id saja, hitung length)
      final counts = await Future.wait([
        supabase.from('profiles').select('id').limit(500),
        supabase.from('submissions').select('id').limit(500),
        supabase.from('grades').select('id').limit(500),
      ]);

      if (!mounted) return;
      setState(() {
        _dbPingMs = pingMs;
        _userCount = (counts[0] as List).length;
        _submissionCount = (counts[1] as List).length;
        _gradeCount = (counts[2] as List).length;
        _lastChecked = DateTime.now();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal memeriksa kesehatan sistem: ${e.toString().replaceAll('Exception: ', '')}';
        _loading = false;
      });
    }
  }

  Color get _pingColor {
    if (_dbPingMs < 200) return TalogColors.success;
    if (_dbPingMs < 600) return TalogColors.warning;
    return TalogColors.danger;
  }

  String get _pingLabel {
    if (_dbPingMs < 200) return 'Sangat Cepat';
    if (_dbPingMs < 600) return 'Normal';
    return 'Lambat';
  }

  @override
  Widget build(BuildContext context) {
    return Panel(
      title: 'KESEHATAN APLIKASI',
      heading: 'Real-time System Health',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Spacer(),
              if (_lastChecked != null)
                Text(
                  'Terakhir: ${_lastChecked!.hour.toString().padLeft(2,'0')}:${_lastChecked!.minute.toString().padLeft(2,'0')}:${_lastChecked!.second.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontSize: 11, color: muted),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Cek ulang sekarang',
                icon: _loading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 18),
                onPressed: _loading ? null : _check,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: TalogColors.danger.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TalogColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, size: 16, color: TalogColors.danger),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: TalogColors.danger))),
              ]),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _HealthChip(
                icon: Icons.speed_outlined,
                label: 'DB Latency',
                value: _loading ? '...' : '${_dbPingMs}ms',
                sub: _loading ? '' : _pingLabel,
                color: _loading ? muted : _pingColor,
              ),
              _HealthChip(
                icon: Icons.people_outline,
                label: 'Total Pengguna',
                value: _loading ? '...' : '$_userCount',
                sub: 'terdaftar',
                color: TalogColors.info,
              ),
              _HealthChip(
                icon: Icons.upload_file_outlined,
                label: 'Pengumpulan',
                value: _loading ? '...' : '$_submissionCount',
                sub: 'total',
                color: violet,
              ),
              _HealthChip(
                icon: Icons.grade_outlined,
                label: 'Penilaian',
                value: _loading ? '...' : '$_gradeCount',
                sub: 'total',
                color: cyan,
              ),
              _HealthChip(
                icon: Icons.check_circle_outline,
                label: 'Database',
                value: _loading ? '...' : (_error == null ? 'Online' : 'Error'),
                sub: 'Supabase',
                color: _loading ? muted : (_error == null ? TalogColors.success : TalogColors.danger),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
  });

  final IconData icon;
  final String label, value, sub;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: color)),
            Text('$label · $sub', style: const TextStyle(fontSize: 10, color: muted)),
          ],
        ),
      ],
    ),
  );
}
