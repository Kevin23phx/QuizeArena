import 'package:dio/dio.dart';

import '../error/failure.dart';

/// Convertit une erreur Dio en `Failure`.
/// À appeler UNIQUEMENT depuis les implémentations de repository (couche data).
///
/// Format d'erreur API supposé (à confirmer avec le groupe) :
/// { "error": { "code": "...", "message": "...",
///              "details": [ { "field": "name", "message": "..." } ] } }
/// (ErrorResponse du contrat OpenAPI validé par le groupe)
Failure mapDioException(DioException e) {
  switch (e.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
      return const NetworkFailure();
    case DioExceptionType.badResponse:
      return _fromResponse(e.response);
    case DioExceptionType.cancel:
    case DioExceptionType.badCertificate:
    case DioExceptionType.unknown:
      return e.error is Failure ? e.error! as Failure : const UnknownFailure();
  }
}

Failure _fromResponse(Response<dynamic>? res) {
  final status = res?.statusCode ?? 0;
  final error = _errorBody(res?.data);
  final message =
      error?['message'] is String ? error!['message'] as String : null;

  switch (status) {
    case 401:
      return message == null
          ? const UnauthorizedFailure()
          : UnauthorizedFailure(message);
    case 403:
      return message == null
          ? const ForbiddenFailure()
          : ForbiddenFailure(message);
    case 404:
      return message == null
          ? const NotFoundFailure()
          : NotFoundFailure(message);
    case 409:
      return message == null
          ? const ConflictFailure()
          : ConflictFailure(message);
    case 400:
    case 422:
      return ValidationFailure(
        message: message ?? 'Données invalides.',
        fieldErrors: _fieldErrors(error?['details']),
      );
    default:
      if (status >= 500) {
        return message == null ? const ServerFailure() : ServerFailure(message);
      }
      return const UnknownFailure();
  }
}

Map<String, dynamic>? _errorBody(Object? data) {
  if (data is Map<String, dynamic>) {
    final inner = data['error'];
    if (inner is Map<String, dynamic>) return inner;
    return data;
  }
  return null;
}

Map<String, String> _fieldErrors(Object? details) {
  // Contrat API : details = [ { "field": "name", "message": "..." }, ... ]
  if (details is List) {
    final result = <String, String>{};
    for (final item in details) {
      if (item is Map && item['field'] != null) {
        result.putIfAbsent(
          item['field'].toString(),
          () => item['message']?.toString() ?? 'Valeur invalide.',
        );
      }
    }
    return result;
  }
  // Tolérance : ancien format { "champ": "message" }.
  if (details is Map) {
    return {
      for (final entry in details.entries)
        entry.key.toString(): entry.value.toString(),
    };
  }
  return const {};
}
