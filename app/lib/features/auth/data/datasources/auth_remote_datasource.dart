import 'package:dio/dio.dart';

import '../../domain/entities/auth_session.dart';
import '../../domain/entities/auth_user.dart';
import '../../../../core/storage/token_storage.dart';

final class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._dio);

  final Dio _dio;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    final user = data['user'] as Map<String, dynamic>;
    final role = UserRole.parse(user['role'] as String?);
    if (role == null) {
      throw StateError('Rôle utilisateur inconnu.');
    }

    return AuthSession(
      accessToken: data['accessToken'] as String,
      refreshToken: data['refreshToken'] as String,
      user: AuthUser(
        id: user['id'] as String,
        name: user['name'] as String,
        email: user['email'] as String,
        role: role,
      ),
    );
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) =>
      _dio.post<void>(
        '/auth/register',
        data: {'name': name, 'email': email, 'password': password},
      );

  Future<void> logout(String refreshToken) =>
      _dio.post<void>('/auth/logout', data: {'refreshToken': refreshToken});
}
