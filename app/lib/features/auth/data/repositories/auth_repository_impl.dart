import 'package:dio/dio.dart';

import '../../../../core/network/failure_mapper.dart';
import '../../../../core/storage/token_storage.dart';
import '../../domain/entities/auth_session.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

final class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._storage);

  final AuthRemoteDataSource _remote;
  final TokenStorage _storage;

  @override
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    try {
      final session = await _remote.login(email: email, password: password);
      await _storage.saveSession(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
        role: session.user.role,
      );
      return session;
    } on DioException catch (error) {
      throw mapDioException(error);
    } catch (_) {
      rethrow;
    }
  }

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      await _remote.register(name: name, email: email, password: password);
    } on DioException catch (error) {
      throw mapDioException(error);
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken != null) {
      try {
        await _remote.logout(refreshToken);
      } on DioException {
        // La session locale doit être fermée même si l'API est indisponible.
      }
    }
    await _storage.clear();
  }
}
