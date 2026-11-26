import 'package:dio/dio.dart';

/// Appels HTTP bruts. Les chemins sont relatifs au préfixe /api/v1 du client Dio.
/// Les réponses suivent l'enveloppe { "data": ... } (liste : + "meta").
class QuizRemoteDataSource {
  QuizRemoteDataSource(this._dio);

  final Dio _dio;

  Map<String, dynamic> _data(Response<Map<String, dynamic>> res) =>
      res.data!['data'] as Map<String, dynamic>;

  /// Retourne l'enveloppe complète { data, meta } pour Paginated.fromEnvelope.
  Future<Map<String, dynamic>> list({
    required String courseId,
    required int page,
    required int limit,
    String? query,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/courses/$courseId/quizzes',
      queryParameters: {
        'page': page,
        'limit': limit,
        if (query != null && query.isNotEmpty) 'q': query,
      },
    );
    return res.data!;
  }

  Future<Map<String, dynamic>> get(String quizId) async =>
      _data(await _dio.get<Map<String, dynamic>>('/quizzes/$quizId'));

  Future<Map<String, dynamic>> create(
    String courseId,
    Map<String, dynamic> body,
  ) async =>
      _data(await _dio.post<Map<String, dynamic>>(
        '/courses/$courseId/quizzes',
        data: body,
      ));

  Future<Map<String, dynamic>> update(
    String quizId,
    Map<String, dynamic> body,
  ) async =>
      _data(await _dio.patch<Map<String, dynamic>>(
        '/quizzes/$quizId',
        data: body,
      ));

  Future<void> delete(String quizId) async {
    await _dio.delete<void>('/quizzes/$quizId');
  }

  Future<List<Map<String, dynamic>>> listQuestions(String quizId) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/quizzes/$quizId/questions',
    );
    return [
      for (final e in res.data!['data'] as List<dynamic>)
        e as Map<String, dynamic>,
    ];
  }

  Future<Map<String, dynamic>> createQuestion(
    String quizId,
    Map<String, dynamic> body,
  ) async =>
      _data(await _dio.post<Map<String, dynamic>>(
        '/quizzes/$quizId/questions',
        data: body,
      ));

  Future<Map<String, dynamic>> updateQuestion(
    String questionId,
    Map<String, dynamic> body,
  ) async =>
      _data(await _dio.patch<Map<String, dynamic>>(
        '/questions/$questionId',
        data: body,
      ));

  Future<void> deleteQuestion(String questionId) async {
    await _dio.delete<void>('/questions/$questionId');
  }
}
