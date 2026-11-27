import 'package:dio/dio.dart';

/// Appels HTTP bruts, relatifs au préfixe /api/v1 configuré dans Dio.
class AttemptRemoteDataSource {
  AttemptRemoteDataSource(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> startAttempt(String quizId) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/quizzes/$quizId/attempts',
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> getAttempt(String attemptId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/attempts/$attemptId',
    );
    return _data(response);
  }

  Future<Map<String, dynamic>> submitAnswer({
    required String attemptId,
    required String questionId,
    required int selectedOptionIndex,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/attempts/$attemptId/answers',
      data: {
        'questionId': questionId,
        'selectedOptionIndex': selectedOptionIndex,
      },
    );
    return _data(response);
  }

  Map<String, dynamic> _data(Response<Map<String, dynamic>> response) {
    final data = response.data?['data'];
    if (data is Map<String, dynamic>) return data;
    throw const FormatException('Réponse de tentative invalide.');
  }
}
