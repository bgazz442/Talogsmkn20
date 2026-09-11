import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'dashboard_service.dart';
import 'talog_design_system.dart';

const ink = TalogColors.primaryNavy,
    muted = TalogColors.textMuted,
    cyan = TalogColors.deptBD,
    violet = TalogColors.deptRPL,
    orange = TalogColors.accentOrange;

String _readRuntimeConfigValue(String key) {
  final fromDefine = String.fromEnvironment(key);
  if (fromDefine.isNotEmpty) return fromDefine;

  final env = Platform.environment;
  if (env.containsKey(key) && (env[key] ?? '').trim().isNotEmpty) {
    return env[key]!.trim();
  }

  if (Platform.isWindows) {
    final appData = Platform.environment['APPDATA'] ??
        Platform.environment['LOCALAPPDATA'] ??
        Platform.environment['USERPROFILE'];
    if (appData != null && appData.isNotEmpty) {
      final configPath = '$appData\\Talog20\\supabase.env';
      final file = File(configPath);
      if (file.existsSync()) {
        for (final rawLine in file.readAsLinesSync()) {
          final line = rawLine.trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          final index = line.indexOf('=');
          if (index <= 0) continue;
          final name = line.substring(0, index).trim();
          final value = line.substring(index + 1).trim();
          if (name == key && value.isNotEmpty) {
            return value;
          }
        }
      }
    }
  }

  return '';
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final supabaseUrl = _readRuntimeConfigValue('SUPABASE_URL');
  final supabasePublishableKey = _readRuntimeConfigValue('SUPABASE_ANON_KEY');

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
                  'Jalankan Flutter dengan SUPABASE_URL dan SUPABASE_ANON_KEY, atau letakkan file supabase.env di %APPDATA%\\Talog20\\supabase.env.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                SelectableText(
                  'flutter run --dart-define=SUPABASE_URL=... '
                  '--dart-define=SUPABASE_ANON_KEY=...\n'
                  'Atau isi file:\n'
                  '%APPDATA%\\Talog20\\supabase.env\n'
                  'SUPABASE_URL=https://...\n'
                  'SUPABASE_ANON_KEY=...',
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

enum DashboardTimeCategory { morning, afternoon, evening, night }

class DashboardTimeThemeSpec {
  const DashboardTimeThemeSpec({
    required this.category,
    required this.background,
    required this.surface,
    required this.panel,
    required this.appBar,
    required this.accent,
    required this.text,
    required this.muted,
  });

  final DashboardTimeCategory category;
  final Color background;
  final Color surface;
  final Color panel;
  final Color appBar;
  final Color accent;
  final Color text;
  final Color muted;

  static DashboardTimeThemeSpec resolve(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 11) {
      return const DashboardTimeThemeSpec(
        category: DashboardTimeCategory.morning,
        background: Color(0xfffdf5ee),
        surface: Color(0xfffffaf6),
        panel: Color(0xffffffff),
        appBar: Color(0xfff3a864),
        accent: Color(0xfff4a261),
        text: Color(0xff1f1f24),
        muted: Color(0xff6b5a4a),
      );
    }
    if (hour >= 11 && hour < 16) {
      return const DashboardTimeThemeSpec(
        category: DashboardTimeCategory.afternoon,
        background: Color(0xfff3f8ff),
        surface: Color(0xfff9fbff),
        panel: Color(0xffffffff),
        appBar: Color(0xff7bb8ff),
        accent: Color(0xff4a90e2),
        text: Color(0xff162338),
        muted: Color(0xff5e6b7d),
      );
    }
    if (hour >= 16 && hour < 19) {
      return const DashboardTimeThemeSpec(
        category: DashboardTimeCategory.evening,
        background: Color(0xfff6efe8),
        surface: Color(0xfffdf6f0),
        panel: Color(0xffffffff),
        appBar: Color(0xffd98b4f),
        accent: Color(0xffd97706),
        text: Color(0xff1e1c1a),
        muted: Color(0xff6a4a3a),
      );
    }
    return const DashboardTimeThemeSpec(
      category: DashboardTimeCategory.night,
      background: Color(0xff0f172a),
      surface: Color(0xff111c2b),
      panel: Color(0xff182335),
      appBar: Color(0xff0b1220),
      accent: Color(0xff7dd3fc),
      text: Color(0xffedf6ff),
      muted: Color(0xff9bb2d1),
    );
  }
}

String getRealtimeGreeting({String? username}) {
  final hour = DateTime.now().hour;
  final name = (username ?? '').trim();
  final base = hour >= 5 && hour < 11
      ? 'Good Morning'
      : hour >= 11 && hour < 16
      ? 'Good Afternoon'
      : hour >= 16 && hour < 19
      ? 'Good Evening'
      : 'Good Night';
  return name.isEmpty ? base : '$base, $name';
}

bool isNightTime() {
  final hour = DateTime.now().hour;
  return hour >= 19 || hour < 5;
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
    return isLogin
        ? 'Akun tidak ditemukan. Periksa email atau username Anda.'
        : 'Akun tidak ditemukan.';
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
    debugPrint(
      'AuthGate accepting authenticated session for user id=${nextSession.user.id}',
    );
    setState(() {
      session = nextSession;
      profileFuture = AuthService(authClient)
          .getActiveProfile(nextSession.user.id)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'Profile timeout: profile tidak merespons dalam 15 detik.',
            ),
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
    if (authClient == null ||
        activeSession == null ||
        activeProfileFuture == null) {
      return const LoginPage();
    }
    return FutureBuilder<UserProfile>(
      future: activeProfileFuture,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
        debugPrint(
          'AuthGate profile ready. role=${profileSnapshot.data!.role.name}',
        );
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
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: muted),
              ),
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
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await AuthService(
        supabase,
      ).signIn(loginInput: loginInput, password: password);
    } on AuthException catch (exception) {
      setState(
        () => error = readableAuthError(exception.message, isLogin: true),
      );
    } on PostgrestException catch (_) {
      setState(
        () => error =
            'Login berhasil, tetapi profile pengguna belum dapat dibaca.',
      );
    } catch (e) {
      setState(() => error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showResetPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: loginController.text,
    );
    showDialog(
      context: context,
      builder: (context) =>
          _ResetPasswordDialog(controller: resetEmailController),
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
                'Gunakan email atau username serta password Anda.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 28),
              InputField(
                label: 'Email atau Username',
                hint: 'nama@sekolah.sch.id atau username',
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
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
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
              const SizedBox(height: 22),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  child: const Text(
                    'Belum punya akun siswa?  Daftar sekarang ->',
                  ),
                ),
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
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final attendance = int.tryParse(attendanceController.text.trim());
      if (nameController.text.trim().isEmpty ||
          attendance == null ||
          attendance <= 0) {
        throw const AuthException(
          'Nama lengkap dan nomor absen wajib diisi dengan benar.',
        );
      }
      await AuthService(supabase).registerStudent(
        fullName: nameController.text,
        email: email,
        departmentCode: codeController.text,
        attendanceNumber: attendance,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun dibuat. Silakan login dengan password absen x3.'),
        ),
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
              InputField(
                label: 'Email pribadi',
                hint: 'nama@gmail.com',
                controller: emailController,
              ),
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
                    child: InputField(
                      label: 'Nomor absen',
                      hint: 'Absen Anda',
                      controller: attendanceController,
                    ),
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
              if (error != null)
                Text(error!, style: const TextStyle(color: Colors.red)),
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
        keyboardType: widget.password
            ? TextInputType.visiblePassword
            : TextInputType.text,
        textInputAction: TextInputAction.next,
        autocorrect: false,
        enableSuggestions: !widget.password,
        autofillHints: widget.password ? const [AutofillHints.password] : null,
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: const TextStyle(
            color: TalogColors.textMuted,
            fontSize: 13,
          ),
          suffixIcon: widget.password
              ? IconButton(
                  tooltip: obscured
                      ? 'Tampilkan password'
                      : 'Sembunyikan password',
                  icon: Icon(
                    obscured ? Icons.visibility : Icons.visibility_off,
                    color: TalogColors.textMuted,
                  ),
                  onPressed: () => setState(() => obscured = !obscured),
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
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
            borderSide: const BorderSide(
              color: TalogColors.primaryNavy,
              width: 1.5,
            ),
          ),
        ),
      ),
    ],
  );
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });
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
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              '$label  ->',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
    ),
  );
}

// Student Page with Modern UI, Realtime Updates, Submissions, Grades, and Profile
class StudentPage extends StatefulWidget {
  const StudentPage({
    super.key,
    required this.profile,
    this.isStaffPreview = false,
  });
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
    _greeting = getRealtimeGreeting(username: _profile.displayName);
    _timeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final newGreeting = getRealtimeGreeting(username: _profile.displayName);
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
    int? selectedFileSize;
    String? selectedMimeType;
    String? uploadError;
    var sending = false;
    var uploading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickAndUploadFile() async {
            debugPrint('UPLOAD CLICKED');
            try {
              final result = await FilePicker.platform.pickFiles(
                withData: true,
                type: FileType.any,
              );
              final file = result?.files.single;
              if (file == null) {
                debugPrint('FILE PICKED: no file selected');
                return;
              }

              debugPrint('FILE PICKED: ${file.name}');

              final fileValidation = DashboardService.validateSubmissionFile(
                fileName: file.name,
                fileSize: file.size,
              );
              if (fileValidation != null) {
                debugPrint('UPLOAD VALIDATION FAILED: $fileValidation');
                setDialogState(() {
                  uploadError = fileValidation;
                  selectedFilePath = null;
                  selectedFileName = null;
                  selectedFileSize = null;
                  selectedMimeType = null;
                });
                return;
              }

              setDialogState(() {
                uploading = true;
                uploadError = null;
                selectedFileName = file.name;
                selectedFileSize = file.size;
                selectedMimeType = DashboardService.detectMimeType(
                  filePath: file.path ?? file.name,
                  fileName: file.name,
                );
              });

              debugPrint('UPLOAD FUNCTION CALLED');
              final path = await DashboardService(supabase)
                  .uploadSubmissionFile(
                    assignmentId: todo['id'].toString(),
                    studentId: _profile.id,
                    fileName: file.name,
                    bytes: file.bytes ?? Uint8List(0),
                    contentType: selectedMimeType,
                    filePath: file.path ?? file.name,
                  );
              if (!ctx.mounted) {
                debugPrint('UPLOAD CONTEXT UNMOUNTED AFTER SUCCESS');
                return;
              }
              debugPrint('UPLOAD SUCCESS');
              setDialogState(() {
                selectedFilePath = path;
                uploading = false;
                uploadError = null;
              });
            } catch (error, stackTrace) {
              debugPrint('UPLOAD ERROR: $error');
              debugPrint('UPLOAD STACKTRACE: $stackTrace');
              if (ctx.mounted) {
                setDialogState(() {
                  uploading = false;
                  uploadError = error.toString().replaceAll('Exception: ', '');
                  selectedFilePath = null;
                  selectedFileName = selectedFileName;
                });
              }
            }
          }

          final canSubmit =
              !sending &&
              !uploading &&
              ((selectedFilePath != null && selectedFilePath!.isNotEmpty) ||
                  noteController.text.trim().isNotEmpty);

          return AlertDialog(
            title: Text(todo['name']?.toString() ?? 'Detail tugas'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo['description']?.toString() ?? 'Tidak ada deskripsi.',
                    style: const TextStyle(color: muted, height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Deadline: ${_readableDate(todo['due_at'])}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pilih salah satu atau gabungkan jawaban teks dan file.',
                    style: TextStyle(fontSize: 13, color: muted),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: sending || uploading ? null : pickAndUploadFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(selectedFileName ?? 'Pilih file tugas'),
                  ),
                  if (selectedFileName != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Nama file: $selectedFileName',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                    ),
                    if (selectedFileSize != null)
                      Text(
                        'Ukuran: ${selectedFileSize! ~/ 1024} KB',
                        style: const TextStyle(fontSize: 11, color: muted),
                      ),
                    if (selectedFilePath != null &&
                        selectedFilePath!.isNotEmpty)
                      Text(
                        'Status upload: Berhasil diunggah',
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  ],
                  if (uploading) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Mengunggah file...',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  if (uploadError != null && uploadError!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      uploadError!,
                      style: const TextStyle(color: Colors.red, fontSize: 11),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    enabled: !sending && !uploading,
                    decoration: const InputDecoration(
                      labelText: 'Jawaban teks (opsional)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: sending || uploading
                    ? null
                    : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton.icon(
                onPressed: sending || uploading || !canSubmit
                    ? null
                    : () async {
                        final hasText = noteController.text.trim().isNotEmpty;
                        final hasFile =
                            selectedFilePath != null &&
                            selectedFilePath!.isNotEmpty;
                        if (!hasText && !hasFile) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Tambahkan jawaban teks atau pilih file tugas terlebih dahulu.',
                              ),
                            ),
                          );
                          return;
                        }
                        setDialogState(() => sending = true);
                        try {
                          await DashboardService(supabase).submitAssignment(
                            todoId: todo['id'].toString(),
                            filePath: selectedFilePath,
                            fileName: selectedFileName,
                            fileSize: selectedFileSize,
                            mimeType: selectedMimeType,
                            submissionType: hasText && hasFile
                                ? 'text_and_file'
                                : hasFile
                                ? 'file'
                                : 'text',
                            contentText: hasText
                                ? noteController.text.trim()
                                : null,
                          );
                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tugas berhasil dikumpulkan!'),
                              ),
                            );
                            setState(() {});
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            setDialogState(() => sending = false);
                          }
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal mengumpulkan tugas: $e'),
                              ),
                            );
                          }
                        }
                      },
                icon: sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
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
            final submission = snapshot.data
                ?.cast<Map<String, dynamic>>()
                .where(
                  (item) =>
                      item['todo_id']?.toString() == todo['id']?.toString(),
                )
                .firstOrNull;
            final grade = _gradeMap(submission?['grades']);
            final score = grade?['score']?.toString();
            final feedback = grade?['feedback']?.toString();
            final attachment =
                todo['attachment_url'] ??
                todo['attachment'] ??
                todo['file_url'];
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo['description']?.toString() ?? 'Tidak ada deskripsi.',
                    style: const TextStyle(color: muted, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Deadline: ${_readableDate(todo['due_at'])}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (todo['departments'] is Map) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Jurusan: ${(todo['departments'] as Map)['name'] ?? '-'}',
                    ),
                  ],
                  if (attachment != null &&
                      attachment.toString().trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    SelectableText('Lampiran: $attachment'),
                  ],
                  const SizedBox(height: 12),
                  Text(
                    'Status: ${submission == null ? 'Belum dikumpulkan' : 'Sudah dikumpulkan'}',
                  ),
                  if (snapshot.hasError) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Status submission belum dapat dimuat: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
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
      onProfileUpdated: (updatedProfile) {
        setState(() {
          _profile = updatedProfile;
          _greeting = getRealtimeGreeting(username: updatedProfile.displayName);
        });
      },
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
              setState(() {
                _profile = updatedProfile;
                _greeting = getRealtimeGreeting(
                  username: updatedProfile.displayName,
                );
              });
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
    usernameController = TextEditingController(
      text: widget.profile.username ?? '',
    );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validation)));
      }
      return;
    }

    try {
      await AuthService(
        supabase,
      ).updateProfile(userId: widget.profile.id, username: username);
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
        final message = e is AuthException
            ? e.message
            : 'Gagal memperbarui username. Silakan coba lagi.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
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
              Text(
                'Nama lengkap: ${widget.profile.fullName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Email: ${widget.profile.email}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 8),
              Text(
                'Role saat ini: ${widget.profile.role.name.toUpperCase()}',
                style: const TextStyle(color: muted),
              ),
              const SizedBox(height: 8),
              Text(
                'Username saat ini: ${widget.profile.username ?? '-'}',
                style: const TextStyle(color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Ganti Username',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
            const Expanded(
              child: Text(
                'Password akun',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
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

    setState(() {
      loading = true;
      error = null;
    });
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
        setState(() {
          error = e.message;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Gagal memperbarui password. Silakan coba lagi.';
          loading = false;
        });
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
                icon: Icon(
                  showCurrent ? Icons.visibility_off : Icons.visibility,
                ),
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
                icon: Icon(
                  showConfirm ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () => setState(() => showConfirm = !showConfirm),
              ),
            ),
          ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                error!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: loading ? null : () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: loading ? null : _submit,
        child: Text(loading ? 'Memproses...' : 'Ubah Password'),
      ),
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
    future = DashboardService(supabase).fetchMyTaskProgress();
    channel = DashboardService(supabase).watchTable(
      channelName: 'student-todos-${identityHashCode(this)}',
      table: 'todos',
      onChange: (_) {
        if (mounted) refresh();
      },
    );
  }

  Future<void> refresh() async {
    final nextFuture = DashboardService(supabase).fetchMyTaskProgress();
    if (!mounted) return;
    setState(() {
      future = nextFuture;
    });
  }

  @override
  void dispose() {
    supabase.removeChannel(channel);
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) => FutureBuilder<List<Map<String, dynamic>>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.all(12),
          child: LinearProgressIndicator(),
        );
      }
      if (snapshot.hasError) {
        return _RefreshMessage(
          message: 'Tugas tidak dapat dimuat: ${snapshot.error}',
          onRefresh: refresh,
        );
      }
      final rows = snapshot.data ?? const [];
      if (rows.isEmpty) {
        return const Text(
          'Belum ada tugas yang diberikan.',
          style: TextStyle(color: muted),
        );
      }
      return Column(
        children: rows.map((todo) {
          final name = todo['name']?.toString() ?? 'Tugas tanpa nama';
          final desc = todo['description']?.toString() ?? '-';
          final submission = todo['submission'] is Map
              ? todo['submission'] as Map<String, dynamic>
              : null;
          final submitted = submission != null;
          final department = todo['departments'];
          final departmentName = department is Map
              ? department['name']?.toString()
              : null;
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
                    Icon(
                      submitted ? Icons.check_circle : Icons.pending_actions,
                      color: submitted ? Colors.green : violet,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            desc,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: muted, fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 4,
                            children: [
                              Text(
                                'Deadline: ${_readableDate(todo['due_at'])}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                              if (departmentName != null)
                                Text(
                                  departmentName,
                                  style: const TextStyle(
                                    color: muted,
                                    fontSize: 11,
                                  ),
                                ),
                              Text(
                                submitted ? 'Sudah dikumpulkan' : 'Aktif',
                                style: TextStyle(
                                  color: submitted
                                      ? Colors.green.shade700
                                      : violet,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final action = FilledButton.tonal(
                  onPressed: () => widget.onOpenTask(todo),
                  child: const Text('Lihat Detail'),
                );
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      details,
                      const SizedBox(height: 12),
                      Align(alignment: Alignment.centerRight, child: action),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: details),
                    const SizedBox(width: 12),
                    action,
                  ],
                );
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

  Future<void> refresh() async {
    final nextFuture = DashboardService(supabase).fetchMySubmissions();
    if (!mounted) return;
    setState(() {
      future = nextFuture;
    });
  }

  @override
  void dispose() {
    for (final channel in channels) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _RefreshMessage(
              message: 'Gagal memuat status pengumpulan: ${snapshot.error}',
              onRefresh: refresh,
            );
          }
          final rows = snapshot.data ?? const [];
          if (rows.isEmpty) {
            return const Text(
              'Belum ada tugas yang dikumpulkan.',
              style: TextStyle(color: muted),
            );
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
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: score != null
                                ? Colors.green.shade50
                                : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            score != null ? 'Nilai: $score' : 'Terkirim',
                            style: TextStyle(
                              color: score != null
                                  ? Colors.green.shade800
                                  : Colors.blue.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (feedback != null && feedback.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Catatan: $feedback',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              );
            }).toList(),
          );
        },
      );
}

class RoleDashboard extends StatefulWidget {
  RoleDashboard({Key? key, required this.profile})
      : assert(profile.id.isNotEmpty),
        super(key: key ?? ValueKey(profile.id));
  final UserProfile profile;

  @override
  State<RoleDashboard> createState() => _RoleDashboardState();
}

class _RoleDashboardState extends State<RoleDashboard> {
  int currentTab = 0;
  Timer? _timeTimer;
  String _greeting = getRealtimeGreeting();
  late UserProfile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    debugPrint('[ROLE TRACE] role=teacher');
    debugPrint('[TEACHER TRACE] initState: RoleDashboard');
    debugPrint('MOUNT RoleDashboard instance=${identityHashCode(this)}');
    _greeting = getRealtimeGreeting(username: _profile.displayName);
    _timeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final newGreeting = getRealtimeGreeting(username: _profile.displayName);
      debugPrint('[TEACHER TRACE] timer-callback: RoleDashboard');
      if (newGreeting != _greeting && mounted) {
        debugPrint('[TEACHER TRACE] setState: RoleDashboard');
        setState(() => _greeting = newGreeting);
      }
    });
  }

  @override
  void dispose() {
    debugPrint('[TEACHER TRACE] dispose: RoleDashboard');
    debugPrint(
      'DISPOSE RoleDashboard instance=${identityHashCode(this)} currentTab=$currentTab',
    );
    _timeTimer?.cancel();
    super.dispose();
  }

  UserRole get role => widget.profile.role;

  bool get canManageTasks => role == UserRole.teacher || role == UserRole.admin;
  bool get canManageUsers =>
      role == UserRole.admin || role == UserRole.superadmin;
  bool get canReadAuditLog => role == UserRole.superadmin;
  bool get canViewLiveUpdate => role == UserRole.superadmin;
  bool get canViewSubmissions =>
      role == UserRole.teacher ||
      role == UserRole.admin ||
      role == UserRole.superadmin;

  int get liveUpdateTab => role == UserRole.superadmin ? 4 : -1;

  String get title => switch (role) {
    UserRole.teacher => 'ADMIN DASHBOARD',
    UserRole.admin => 'ADMIN DASHBOARD',
    UserRole.superadmin => 'ADMIN DASHBOARD',
    UserRole.student => 'STUDENT DASHBOARD',
  };

  @override
  Widget build(BuildContext context) {
    final name = _profile.displayName;
    debugPrint('[TEACHER TRACE] build: RoleDashboard');
    debugPrint(
      'BUILD RoleDashboard instance=${identityHashCode(this)} tab=$currentTab role=${widget.profile.role.name}',
    );
    return Shell(
      title: title,
      heading: '$_greeting, $name.',
      onProfileUpdated: (updatedProfile) {
        setState(() {
          _profile = updatedProfile;
          _greeting = getRealtimeGreeting(username: updatedProfile.displayName);
        });
      },
      subtitle: switch (role) {
        UserRole.teacher => 'Ruang bimbingan, tugas, dan penilaian siswa.',
        UserRole.admin => 'Kelola operasional data, tugas, dan audit TALog20.',
        UserRole.superadmin =>
          'Kendali penuh sistem, manajemen akun pengguna, dan audit integritas.',
        UserRole.student => 'Ruang kerja tugas Anda.',
      },
      profile: _profile,
      onNavSelected: (i) {
        setState(() => currentTab = i);
      },
      selectedTabIndex: currentTab,
      children: [_buildContentForTab(currentTab)],
    );
  }

  Widget _buildContentForTab(int tab) {
    if (tab == 0) {
      return _buildOverview();
    }
    if (tab == 1 && canManageTasks) {
      return StaffTasksPanel(profile: _profile);
    }
    if (tab == 1 && canManageUsers) {
      return const UserManagementPanel();
    }
    if (tab == 2 && role == UserRole.teacher) {
      return StaffSubmissionsPanel(profile: _profile);
    }
    if (tab == 2 && role == UserRole.admin) {
      return StaffSubmissionsPanel(profile: _profile);
    }
    if (tab == 1 && role == UserRole.superadmin) {
      return const UserManagementPanel();
    }
    if (tab == 2 && canReadAuditLog) {
      return const AuditLogsPanel();
    }
    if (tab == 3 && role == UserRole.admin) {
      return const UserManagementPanel();
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
            : 'Ringkasan Aktivitas',
        child: Text(
          role == UserRole.superadmin
              ? 'Anda memiliki hak istimewa untuk mengelola role pengguna, memantau tugas, pengumpulan, penilaian, serta jejak audit sistem.'
              : role == UserRole.admin
              ? 'Pantau seluruh operasional tugas, pengumpulan, siswa, dan audit sistem.'
              : 'Kelola penugasan kelas Anda, evaluasi pengumpulan siswa, dan berikan nilai secara real-time.',
          style: const TextStyle(color: muted, height: 1.5),
        ),
      ),
      const SizedBox(height: 18),
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
    refresh();
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
    if (!mounted) return;
    final nextFuture = DashboardService(supabase).fetchTodos();
    if (!mounted) return;
    setState(() {
      future = nextFuture;
    });
  }

  Future<void> _toggleTaskArchive(
    Map<String, dynamic> task, {
    required bool archived,
  }) async {
    final todoId = task['id']?.toString();
    if (todoId == null || todoId.isEmpty) return;
    try {
      await DashboardService(supabase).archiveTodo(todoId, archived: archived);
      await AuthService(supabase).logAudit(
        action: archived ? 'TASK_ARCHIVED' : 'TASK_RESTORED',
        description: archived
            ? 'Tugas diarsipkan: ${task['name']}'
            : 'Tugas dipulihkan: ${task['name']}',
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

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Hapus tugas permanen?'),
          content: Text(
            submissionCount > 0 || gradeCount > 0
                ? 'Tugas "$taskName" sudah memiliki $submissionCount pengumpulan dan $gradeCount penilaian. Menghapus permanen akan menghapus data terkait. Lanjutkan?'
                : 'Apakah Anda yakin ingin menghapus tugas "$taskName" secara permanen? Tindakan ini tidak dapat dibatalkan.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
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
          SnackBar(content: Text('Gagal menghapus tugas permanen: $e')),
        );
      }
    }
  }

  Future<void> _showCreateTaskDialog() async {
    late final List<Map<String, dynamic>> departments;
    try {
      final allDepartments = await DashboardService(
        supabase,
      ).fetchDepartments();
      departments = DashboardService.filterTeacherTaskDepartments(
        allDepartments,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal memuat jurusan: $e')));
      }
      return;
    }
    if (!mounted) return;
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String? selectedDepartmentId = departments.isEmpty
        ? null
        : departments.first['id']?.toString();
    DateTime? dueAt;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Buat Tugas Baru'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nama Tugas'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi / Instruksi',
                ),
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
                  return DropdownMenuItem(
                    value: id,
                    child: Text('$code - $name'),
                  );
                }).toList(),
                onChanged: departments.isEmpty
                    ? null
                    : (value) =>
                          setDialogState(() => selectedDepartmentId = value),
              ),
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
                  label: Text(
                    dueAt == null
                        ? 'Pilih Deadline'
                        : 'Deadline: ${_readableDate(dueAt)}',
                  ),
                ),
              ),
              if (departments.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Belum ada jurusan di database.',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: selectedDepartmentId == null
                  ? null
                  : () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) return;
                      Navigator.pop(ctx);
                      try {
                        await DashboardService(supabase).createTodo(
                          name: name,
                          description: descController.text.trim(),
                          departmentId: selectedDepartmentId!,
                          dueAt: dueAt,
                        );
                        await AuthService(supabase).logAudit(
                          action: 'TASK_CREATED',
                          description: 'Tugas baru dibuat: $name',
                        );
                        if (mounted) refresh();
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal membuat tugas: $e')),
                          );
                        }
                      }
                    },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Tugas yang terdaftar dalam sistem:',
                    style: TextStyle(color: muted),
                  ),
                  const SizedBox(height: 10),
                  action,
                ],
              );
            }
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Tugas yang terdaftar dalam sistem:',
                    style: TextStyle(color: muted),
                  ),
                ),
                action,
              ],
            );
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
              return _RefreshMessage(
                message: 'Gagal memuat tugas: ${snapshot.error}',
                onRefresh: refresh,
              );
            }
            final list = snapshot.data ?? const [];
            if (list.isEmpty) {
              return const Text(
                'Belum ada tugas.',
                style: TextStyle(color: muted),
              );
            }
            return Column(
              children: list.map((t) {
                final isArchived = t['is_complete'] == true;
                return ListTile(
                  title: Text(
                    t['name'] ?? 'Tugas',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(t['description'] ?? '-'),
                  trailing: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        isArchived ? 'Arsip' : 'Aktif',
                        style: TextStyle(
                          color: isArchived ? cyan : violet,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            _toggleTaskArchive(t, archived: !isArchived),
                        icon: Icon(
                          isArchived ? Icons.unarchive : Icons.archive_outlined,
                        ),
                        label: Text(isArchived ? 'Pulihkan' : 'Arsipkan'),
                      ),
                      TextButton.icon(
                        onPressed: () => _deleteTask(t),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Hapus',
                          style: TextStyle(color: Colors.red),
                        ),
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

  @override
  void initState() {
    super.initState();
    refresh();
    final service = DashboardService(supabase);
    channels = [
      service.watchTable(
        channelName: 'staff-submissions-${identityHashCode(this)}',
        table: 'submissions',
        onChange: (_) {
          if (mounted) refresh();
        },
      ),
      service.watchTable(
        channelName: 'staff-grades-${identityHashCode(this)}',
        table: 'grades',
        onChange: (_) {
          if (mounted) refresh();
        },
      ),
    ];
  }

  @override
  void dispose() {
    for (final channel in channels) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }

  Future<void> refresh() async {
    final nextFuture = DashboardService(supabase).fetchStaffSubmissions();
    if (!mounted) return;
    setState(() {
      future = nextFuture;
    });
  }

  Future<void> _openSubmissionFile(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return;
    final url = await DashboardService(
      supabase,
    ).submissionDownloadUrl(filePath);
    if (url == null || url.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('URL unduhan file tidak tersedia.')),
      );
      return;
    }
    final launchable = Uri.tryParse(url);
    if (launchable == null) return;
    if (!await launchUrl(launchable, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak dapat membuka file yang dipilih.')),
      );
    }
  }

  void _showGradeDialog(Map<String, dynamic> sub) {
    final grades = _gradeMap(sub['grades']);
    final existingScore = grades?['score']?.toString() ?? '';
    final existingFeedback = grades?['feedback']?.toString() ?? '';
    final scoreController = TextEditingController(text: existingScore);
    final feedbackController = TextEditingController(text: existingFeedback);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Penilaian Tugas'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: scoreController,
              decoration: const InputDecoration(labelText: 'Nilai (0 - 100)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(
                labelText: 'Feedback / Catatan Guru',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final score = double.tryParse(scoreController.text.trim());
              if (score == null || score < 0 || score > 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nilai harus berupa angka antara 0 - 100'),
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await DashboardService(supabase).gradeSubmission(
                  submissionId: sub['id'].toString(),
                  score: score,
                  feedback: feedbackController.text.trim(),
                );
                await AuthService(supabase).logAudit(
                  action: 'GRADE_UPDATED',
                  description:
                      'Pemberian nilai $score pada pengumpulan ${sub['id']}',
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
            },
            child: const Text('Simpan Nilai'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Panel(
    title: 'PENGUMPULAN & PENILAIAN',
    heading: 'Evaluasi Tugas Siswa',
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return _RefreshMessage(
            message: 'Gagal memuat pengumpulan: ${snapshot.error}',
            onRefresh: refresh,
          );
        }
        final list = snapshot.data ?? const [];
        if (list.isEmpty) {
          return const Text(
            'Belum ada pengumpulan tugas dari siswa.',
            style: TextStyle(color: muted),
          );
        }
        return Column(
          children: list.map((sub) {
            final todo = sub['todos'];
            final todoName = todo is Map ? todo['name']?.toString() : 'Tugas';
            final studentRecord = sub['students'];
            final studentProfile = studentRecord is Map
                ? studentRecord['profiles']
                : null;
            final studentName = studentProfile is Map
                ? studentProfile['full_name']?.toString()
                : 'Siswa';
            final grades = _gradeMap(sub['grades']);
            final score = grades?['score']?.toString();
            final feedback = grades?['feedback']?.toString();
            final filePath = sub['file_path']?.toString();
            final fileName = sub['file_name']?.toString();

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xfff9fafc),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xffe7eaf1)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final details = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$studentName — $todoName',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      if (filePath != null && filePath.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                'File: ${fileName ?? filePath}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _openSubmissionFile(filePath),
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 16,
                              ),
                              label: const Text('Buka'),
                            ),
                          ],
                        ),
                      ] else if (sub['file_url'] != null &&
                          sub['file_url'].toString().trim().isNotEmpty) ...[
                        SelectableText(
                          'File: ${sub['file_url']}',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                      Text(
                        'Dikirim: ${_readableDate(sub['submitted_at'])}',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                      if (sub['note'] != null &&
                          sub['note'].toString().isNotEmpty)
                        Text(
                          'Catatan: ${sub['note']}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                      if (feedback != null && feedback.isNotEmpty)
                        Text(
                          'Feedback: $feedback',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                    ],
                  );
                  final action = FilledButton.tonal(
                    onPressed: () => _showGradeDialog(sub),
                    child: Text(score != null ? 'Nilai: $score' : 'Beri Nilai'),
                  );
                  if (constraints.maxWidth < 560) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        details,
                        const SizedBox(height: 10),
                        Align(alignment: Alignment.centerRight, child: action),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: details),
                      const SizedBox(width: 8),
                      action,
                    ],
                  );
                },
              ),
            );
          }).toList(),
        );
      },
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
    debugPrint('MOUNT UserManagementPanel instance=${identityHashCode(this)}');
    search();
  }

  @override
  void dispose() {
    debugPrint(
      'DISPOSE UserManagementPanel instance=${identityHashCode(this)}',
    );
    searchController.dispose();
    super.dispose();
  }

  Future<void> search() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await AuthService(
        supabase,
      ).searchUsers(searchController.text);
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

  void _showChangeRoleDialog(Map<String, dynamic> user) {
    final currentRole = user['role']?.toString() ?? 'student';
    String selectedRole = currentRole;
    debugPrint(
      'OPEN change role dialog instance=${identityHashCode(this)} target=${user['email']} currentRole=$currentRole',
    );
    if (currentRole == 'superadmin') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Role superadmin tidak boleh diubah.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Ubah Role: ${user['full_name'] ?? user['email']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Email: ${user['email']}'),
              const SizedBox(height: 16),
              const Text(
                'Pilih role baru:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                value: selectedRole,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'student',
                    child: Text('Student (Siswa)'),
                  ),
                  DropdownMenuItem(
                    value: 'teacher',
                    child: Text('Teacher (Guru)'),
                  ),
                  DropdownMenuItem(
                    value: 'admin',
                    child: Text('Admin (Staf Operasional)'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => selectedRole = val);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedRole.trim().isEmpty) return;

                final messenger = ScaffoldMessenger.maybeOf(context);
                try {
                  final currentUserId = user['id']?.toString() ?? '';
                  await AuthService(supabase).updateUserRole(
                    userId: currentUserId,
                    newRole: selectedRole,
                  );
                  if (!ctx.mounted) return;
                  debugPrint(
                    'CLOSE change role dialog instance=${identityHashCode(this)} target=${user['email']} selectedRole=$selectedRole',
                  );
                  Navigator.pop(ctx);
                  if (messenger != null) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Role berhasil diubah menjadi $selectedRole',
                        ),
                      ),
                    );
                  }
                  if (mounted) {
                    search();
                  }
                } catch (e) {
                  if (!ctx.mounted) return;
                  debugPrint(
                    'User role update failed: type=${e.runtimeType} value=$e',
                  );
                  final message = switch (e) {
                    AuthException() => e.message,
                    PostgrestException() =>
                      'Supabase error ${e.code}: ${e.message}',
                    _ =>
                      'Gagal memperbarui role user. ${e.toString().replaceAll('Exception: ', '')}',
                  };
                  if (messenger != null) {
                    messenger.showSnackBar(SnackBar(content: Text(message)));
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    debugPrint(
      'BUILD UserManagementPanel instance=${identityHashCode(this)} loading=$loading users=${users.length}',
    );
    return Panel(
      title: 'SUPERADMIN / USER MANAGEMENT',
      heading: 'Kelola Pengguna & Peran',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final searchButton = FilledButton.icon(
                onPressed: loading ? null : search,
                icon: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [field, const SizedBox(height: 10), searchButton],
                );
              }
              return Row(
                children: [
                  Expanded(child: field),
                  const SizedBox(width: 12),
                  searchButton,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Text(error!, style: const TextStyle(color: Colors.red)),
          if (!loading && error == null && users.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Tidak ada pengguna yang ditemukan.',
                style: TextStyle(color: muted),
              ),
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
                    Text(
                      user['full_name']?.toString() ?? 'Pengguna',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Email: ${user['email']}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                );

                final actions = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
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
                    const SizedBox(width: 12),
                    if (role != 'superadmin')
                      OutlinedButton(
                        onPressed: () => _showChangeRoleDialog(user),
                        child: const Text('Ubah Role'),
                      ),
                  ],
                );

                return LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 520) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            details,
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerRight,
                              child: actions,
                            ),
                          ],
                        ),
                      );
                    }
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: details,
                      trailing: actions,
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class AuditLogsPanel extends StatefulWidget {
  const AuditLogsPanel({super.key});

  @override
  State<AuditLogsPanel> createState() => _AuditLogsPanelState();
}

class _AuditLogsPanelState extends State<AuditLogsPanel> {
  late Future<List<Map<String, dynamic>>> future;
  bool _cleared = false;

  @override
  void initState() {
    super.initState();
    debugPrint('MOUNT AuditLogsPanel instance=${identityHashCode(this)}');
    refresh();
  }

  @override
  void dispose() {
    debugPrint('DISPOSE AuditLogsPanel instance=${identityHashCode(this)}');
    super.dispose();
  }

  Future<void> refresh() async {
    if (!mounted) return;
    debugPrint(
      'REFRESH AuditLogsPanel instance=${identityHashCode(this)} start',
    );

    final nextFuture = AuthService(supabase).getAuditLogs(limit: 50);

    if (!mounted) return;

    setState(() {
      _cleared = false;
      future = nextFuture;
    });
  }

  Future<void> clearLocalLogs() async {
    if (!mounted) return;
    setState(() {
      _cleared = true;
      future = Future.value(const <Map<String, dynamic>>[]);
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('BUILD AuditLogsPanel instance=${identityHashCode(this)}');
    return Panel(
      title: 'SECURITY & AUDIT LOG',
      heading: 'Jejak Audit Aktivitas',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _cleared ? 'Daftar audit dibersihkan dari tampilan.' : 'Jejak aktivitas terbaru',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
              TextButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
              TextButton.icon(
                onPressed: clearLocalLogs,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Bersihkan'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return _RefreshMessage(
              message: AuthService.formatAuditError(
                snapshot.error ?? 'Gagal memuat aktivitas audit.',
              ),
              onRefresh: refresh,
            );
          }
          final list = snapshot.data ?? const [];
          if (list.isEmpty) {
            return const Text(
              'Belum ada aktivitas audit.',
              style: TextStyle(color: muted),
            );
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
              final time =
                  item['created_at']?.toString().split('.').first ?? '';

              return ListTile(
                leading: Icon(
                  action.contains('ROLE') ? Icons.security : Icons.history,
                  color: violet,
                ),
                title: Text(
                  '$action ($role)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                subtitle: Text(desc, style: const TextStyle(fontSize: 12)),
                trailing: Text(
                  time,
                  style: const TextStyle(color: muted, fontSize: 11),
                ),
              );
            },
          );
        },
      ),
    ]),
    );
  }
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
  bool _cleared = false;

  @override
  void initState() {
    super.initState();
    refresh();
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

  Future<void> refresh() async {
    final nextFuture = DashboardService(supabase).fetchStaffSubmissions();
    if (!mounted) return;
    setState(() {
      _cleared = false;
      future = nextFuture;
    });
  }

  Future<void> clearLocalUpdates() async {
    if (!mounted) return;
    setState(() {
      _cleared = true;
      future = Future.value(const <Map<String, dynamic>>[]);
    });
  }

  @override
  void dispose() {
    for (final channel in channels) {
      supabase.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _cleared ? 'Daftar aktivitas dibersihkan dari tampilan.' : 'Aktivitas terbaru',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ),
              TextButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
              TextButton.icon(
                onPressed: clearLocalUpdates,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Bersihkan'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
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
                return const Text(
                  'Belum ada aktivitas terbaru.',
                  style: TextStyle(color: muted),
                );
              }
              return Column(
                children: list.map((submission) {
                  final student = submission['students'];
                  final profile = student is Map ? student['profiles'] : null;
                  final studentName = profile is Map
                      ? profile['full_name']?.toString()
                      : 'Siswa';
                  final todo = submission['todos'];
                  final taskName = todo is Map ? todo['name']?.toString() : 'Tugas';
                  final grades = submission['grades'];
                  final score = grades is Map ? grades['score']?.toString() : null;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('$studentName - $taskName'),
                    subtitle: Text(
                      'Dikirim: ${_readableDate(submission['submitted_at'])}',
                    ),
                    trailing: Text(
                      score == null ? 'Belum dinilai' : 'Nilai: $score',
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
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
    this.onProfileUpdated,
  });
  final String title, heading, subtitle;
  final List<Widget> children;
  final UserProfile? profile;
  final void Function(int)? onNavSelected;
  final int selectedTabIndex;
  final bool isStaffPreview;
  final void Function(UserProfile updatedProfile)? onProfileUpdated;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late UserProfile _profile;
  Timer? _themeTimer;

  @override
  void initState() {
    super.initState();
    _profile =
        widget.profile ??
        const UserProfile(
          id: '',
          fullName: '',
          email: '',
          role: UserRole.student,
          status: 'active',
        );
    _themeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _themeTimer?.cancel();
    super.dispose();
  }

  void _handleNavigation(
    BuildContext context,
    int index,
    int destinationCount,
  ) {
    if (widget.onNavSelected != null) {
      widget.onNavSelected!(index);
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Widget _buildDrawer(
    BuildContext context,
    List<NavigationRailDestination> destinations,
  ) {
    final selectedIndex = widget.selectedTabIndex.clamp(
      0,
      destinations.length - 1,
    );
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
                    leading: selected
                        ? destination.selectedIcon
                        : destination.icon,
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
            if (!widget.isStaffPreview) ...[
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
            ] else ...[
              ListTile(
                leading: const Icon(Icons.arrow_back),
                title: const Text('Kembali ke Dashboard Admin'),
                onTap: () {
                  Navigator.pop(context);
                },
              ),
            ],
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
    final nameController = TextEditingController(text: _profile.fullName);
    final usernameController = TextEditingController(
      text: _profile.username ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pengaturan Profil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Email: ${_profile.email}',
              style: const TextStyle(color: muted),
            ),
            Text(
              'Role: ${_profile.role.name.toUpperCase()}',
              style: const TextStyle(color: muted),
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await AuthService(supabase).updateProfile(
                  userId: _profile.id,
                  fullName: nameController.text.trim(),
                  username: usernameController.text.trim(),
                );
                if (!mounted) return;
                final updatedProfile = UserProfile(
                  id: _profile.id,
                  fullName: nameController.text.trim().isNotEmpty
                      ? nameController.text.trim()
                      : _profile.fullName,
                  email: _profile.email,
                  role: _profile.role,
                  status: _profile.status,
                  username: usernameController.text.trim().isNotEmpty
                      ? usernameController.text.trim()
                      : _profile.username,
                );
                setState(() {
                  _profile = updatedProfile;
                });
                widget.onProfileUpdated?.call(updatedProfile);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profil berhasil diperbarui.')),
                );
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
    final role = _profile.role;
    debugPrint('[ROLE TRACE] Shell mounted role=${role.name}');
    debugPrint('[TEACHER TRACE] build: Shell');
    final navigationRole = widget.isStaffPreview ? UserRole.student : role;
    final isStaff =
        role == UserRole.teacher ||
        role == UserRole.admin ||
        role == UserRole.superadmin;
    final isStudent = role == UserRole.student;
    final canManageTasks = role == UserRole.teacher || role == UserRole.admin;
    final canManageUsers =
        role == UserRole.admin || role == UserRole.superadmin;
    final timeTheme = DashboardTimeThemeSpec.resolve(DateTime.now());
    final isCompact = MediaQuery.sizeOf(context).width < 700;

    final destinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: Icon(Icons.dashboard_outlined),
        selectedIcon: Icon(Icons.dashboard),
        label: Text(
          navigationRole == UserRole.student ? 'Dashboard' : 'Overview',
        ),
      ),
      if (isStaff && !widget.isStaffPreview) ...[
        if (canManageTasks)
          const NavigationRailDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: Text('Tugas'),
          ),
        if (role == UserRole.teacher || role == UserRole.admin)
          const NavigationRailDestination(
            icon: Icon(Icons.rate_review_outlined),
            selectedIcon: Icon(Icons.rate_review),
            label: Text('Pengumpulan'),
          ),
        if (canManageUsers)
          const NavigationRailDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: Text('Pengguna'),
          ),
        if (role == UserRole.superadmin)
          const NavigationRailDestination(
            icon: Icon(Icons.security_outlined),
            selectedIcon: Icon(Icons.security),
            label: Text('Audit Log'),
          ),
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
      backgroundColor: timeTheme.background,
      appBar: isCompact
          ? AppBar(
              backgroundColor: timeTheme.appBar,
              foregroundColor: Colors.white,
              title: Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              actions: [
                if (widget.profile != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Text(
                        _profile.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                if (isStudent && !widget.isStaffPreview)
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
            if (!isCompact)
              NavigationRail(
                backgroundColor: timeTheme.appBar,
                unselectedIconTheme: const IconThemeData(color: Colors.white60),
                selectedIconTheme: const IconThemeData(color: Colors.white),
                unselectedLabelTextStyle: const TextStyle(
                  color: Colors.white60,
                ),
                selectedLabelTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                destinations: destinations,
                selectedIndex: widget.selectedTabIndex.clamp(
                  0,
                  destinations.length - 1,
                ),
                onDestinationSelected: (i) =>
                    _handleNavigation(context, i, destinations.length),
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
                              icon: const Icon(
                                Icons.person_outline,
                                color: Colors.white70,
                              ),
                              onPressed: _showProfileSettingsDialog,
                            ),
                            IconButton(
                              tooltip: 'Ganti Password',
                              icon: const Icon(
                                Icons.lock_outline,
                                color: Colors.white70,
                              ),
                              onPressed: _showChangePasswordDialog,
                            ),
                            const SizedBox(height: 8),
                            IconButton(
                              tooltip: 'Keluar',
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.white70,
                              ),
                              onPressed: () => AuthService(supabase).signOut(),
                            ),
                          ] else ...[
                            const SizedBox(height: 8),
                            IconButton(
                              tooltip: 'Kembali ke Dashboard Admin',
                              icon: const Icon(
                                Icons.arrow_back,
                                color: Colors.white70,
                              ),
                              onPressed: () => Navigator.pop(context),
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
                    if (!isCompact)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Brand(
                            light:
                                timeTheme.category ==
                                DashboardTimeCategory.night,
                          ),
                          if (widget.profile != null)
                            Row(
                              children: [
                                if (widget.isStaffPreview)
                                  Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'PREVIEW MODE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                Text(
                                  '${_profile.displayName}  •  ${_profile.role.name.toUpperCase()}',
                                  style: TextStyle(
                                    color: timeTheme.muted,
                                    fontSize: 12,
                                  ),
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
                        color: timeTheme.text,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (widget.subtitle.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.subtitle,
                          style: TextStyle(color: timeTheme.muted),
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
        child: Text(message, style: const TextStyle(color: muted)),
      ),
      IconButton(
        onPressed: onRefresh,
        tooltip: 'Muat ulang',
        icon: const Icon(Icons.refresh),
      ),
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
  Widget build(BuildContext context) {
    final timeTheme = DashboardTimeThemeSpec.resolve(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: timeTheme.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: timeTheme.category == DashboardTimeCategory.night
              ? const Color(0xff2e4668)
              : const Color(0xffe7eaf1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LabelText(title),
          const SizedBox(height: 8),
          Text(
            heading,
            style: TextStyle(
              color: timeTheme.text,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
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
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await AuthService(supabase).changePassword(password);
      setState(() {
        success = true;
        loading = false;
      });
    } on AuthException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    } catch (_) {
      setState(() {
        error = 'Gagal mengganti password.';
        loading = false;
      });
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
        ? const Text(
            'Password berhasil diganti. Silakan gunakan password baru ini untuk login berikutnya.',
          )
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
                decoration: const InputDecoration(
                  labelText: 'Konfirmasi password baru',
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
    actions: success
        ? [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ]
        : [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: loading ? null : submit,
              child: const Text('Simpan'),
            ),
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
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await AuthService(supabase).resetPassword(email);
      setState(() {
        success = true;
        loading = false;
      });
    } catch (_) {
      setState(() {
        error = 'Gagal mengirim email reset password.';
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Reset Password'),
    content: success
        ? const Text(
            'Link reset password telah dikirim ke email Anda. Periksa inbox.',
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan email akun Anda. Kami akan mengirim link untuk mengatur ulang password.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: widget.controller,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
    actions: success
        ? [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Tutup'),
            ),
          ]
        : [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: loading ? null : submit,
              child: const Text('Kirim'),
            ),
          ],
  );
}
