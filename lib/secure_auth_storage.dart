import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedLoginCredentials {
  const SavedLoginCredentials({
    required this.loginInput,
    required this.password,
  });

  final String loginInput;
  final String password;
}

class SecureAuthStorage {
  SecureAuthStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              wOptions: WindowsOptions(),
            );

  final FlutterSecureStorage _storage;

  static const String _keyLoginInput = 'saved_login_input';
  static const String _keyPassword = 'saved_login_password';
  static const String _keyRememberMe = 'remember_me_active';

  Future<SavedLoginCredentials?> loadCredentials() async {
    try {
      final rememberMe = await _storage.read(key: _keyRememberMe);
      if (rememberMe != 'true') return null;

      final loginInput = await _storage.read(key: _keyLoginInput);
      final password = await _storage.read(key: _keyPassword);

      if (loginInput == null ||
          loginInput.isEmpty ||
          password == null ||
          password.isEmpty) {
        return null;
      }

      return SavedLoginCredentials(
        loginInput: loginInput,
        password: password,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> saveCredentials({
    required String loginInput,
    required String password,
  }) async {
    try {
      await _storage.write(key: _keyRememberMe, value: 'true');
      await _storage.write(key: _keyLoginInput, value: loginInput.trim());
      await _storage.write(key: _keyPassword, value: password);
    } catch (_) {}
  }

  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _keyRememberMe);
      await _storage.delete(key: _keyLoginInput);
      await _storage.delete(key: _keyPassword);
    } catch (_) {}
  }

  Future<bool> isRememberMeEnabled() async {
    try {
      final value = await _storage.read(key: _keyRememberMe);
      return value == 'true';
    } catch (_) {
      return false;
    }
  }
}
