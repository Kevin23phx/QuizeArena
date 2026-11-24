import 'dart:async';

import 'package:dio/dio.dart';

import '../storage/token_storage.dart';

/// Appelé quand le refresh échoue : la session est perdue.
typedef SessionExpiredCallback = Future<void> Function();

/// Ajoute le Bearer et renouvelle le jeton sur 401 de façon concurrent-safe :
/// si plusieurs requêtes échouent en même temps, UN SEUL refresh est lancé,
/// les autres attendent son résultat (single-flight) puis sont rejouées.
///
/// Hypothèse de contrat (à valider avec le Membre 1 / l'API) :
///   POST /auth/refresh  { "refreshToken": "..." }
///   -> 200 { "accessToken": "...", "refreshToken": "..." }  (refresh rotatif)
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor({
    required Dio dio,
    required Dio refreshDio,
    required TokenStorage storage,
    required SessionExpiredCallback onSessionExpired,
  })  : _dio = dio,
        _refreshDio = refreshDio,
        _storage = storage,
        _onSessionExpired = onSessionExpired;

  final Dio _dio;
  final Dio _refreshDio; // Dio SANS cet intercepteur, pour éviter les boucles.
  final TokenStorage _storage;
  final SessionExpiredCallback _onSessionExpired;

  static const _publicPaths = ['/auth/login', '/auth/register', '/auth/refresh'];
  static const _retriedKey = 'auth_retried';

  Future<bool>? _refreshing;

  bool _isPublic(RequestOptions o) =>
      _publicPaths.any((p) => o.path.endsWith(p));

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options)) {
      final token = await _storage.readAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final req = err.requestOptions;
    final is401 = err.response?.statusCode == 401;

    if (!is401 || _isPublic(req) || req.extra[_retriedKey] == true) {
      return handler.next(err);
    }

    final refreshed = await (_refreshing ??= _refresh().whenComplete(() {
      _refreshing = null;
    }));

    if (!refreshed) return handler.next(err);

    try {
      req.extra[_retriedKey] = true;
      final token = await _storage.readAccessToken();
      req.headers['Authorization'] = 'Bearer $token';
      handler.resolve(await _dio.fetch<dynamic>(req));
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<bool> _refresh() async {
    try {
      final refreshToken = await _storage.readRefreshToken();
      if (refreshToken == null) throw StateError('no refresh token');

      final res = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );
      final data = res.data!;
      await _storage.saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      await _onSessionExpired();
      return false;
    }
  }
}
