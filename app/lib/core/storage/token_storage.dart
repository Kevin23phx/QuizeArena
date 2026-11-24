import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Rôle explicite du compte, défini par le serveur.
enum UserRole {
  teacher,
  student;

  static UserRole? parse(String? value) {
    for (final role in UserRole.values) {
      if (role.name == value) return role;
    }
    return null;
  }
}

/// Contrat de stockage des jetons (testable avec un faux).
abstract interface class TokenStorage {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<UserRole?> readRole();

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required UserRole role,
  });

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  });

  Future<void> clear();
}

/// Implémentation sécurisée (Keychain / Keystore).
class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _roleKey = 'user_role';

  @override
  Future<String?> readAccessToken() => _storage.read(key: _accessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshKey);

  @override
  Future<UserRole?> readRole() async =>
      UserRole.parse(await _storage.read(key: _roleKey));

  @override
  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    required UserRole role,
  }) async {
    await saveTokens(accessToken: accessToken, refreshToken: refreshToken);
    await _storage.write(key: _roleKey, value: role.name);
  }

  @override
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _roleKey);
  }
}
