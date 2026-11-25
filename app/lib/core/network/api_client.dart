import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'auth_interceptor.dart';

/// URL de l'API injectée au build, jamais en dur dans Git :
///   flutter run --dart-define=API_URL=https://api.exemple.com
const apiBaseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://10.0.2.2:3000', // émulateur Android -> localhost
);

/// Préfixe de version commun à toutes les routes du contrat (/api/v1/...).
/// Les datasources utilisent donc des chemins relatifs : '/courses', '/courses/join'.
const apiPrefix = '/api/v1';

BaseOptions _baseOptions(String baseUrl) => BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Accept': 'application/json'},
    );

/// Construit le Dio de l'application (avec gestion des jetons).
Dio createApiClient({
  required TokenStorage storage,
  required SessionExpiredCallback onSessionExpired,
  String baseUrl = '$apiBaseUrl$apiPrefix',
}) {
  final dio = Dio(_baseOptions(baseUrl));
  final refreshDio = Dio(_baseOptions(baseUrl));

  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      storage: storage,
      onSessionExpired: onSessionExpired,
    ),
  );
  return dio;
}
