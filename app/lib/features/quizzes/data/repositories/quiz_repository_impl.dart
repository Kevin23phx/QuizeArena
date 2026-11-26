import 'package:dio/dio.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/error/result.dart';
import 'package:quizarena/core/network/failure_mapper.dart';
import 'package:quizarena/core/network/paginated.dart';

import '../../domain/entities/question.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/repositories/quiz_repository.dart';
import '../datasources/quiz_remote_datasource.dart';
import '../models/quiz_json.dart';

class QuizRepositoryImpl implements QuizRepository {
  QuizRepositoryImpl(this._remote);

  final QuizRemoteDataSource _remote;

  /// Convertit toute erreur en `Failure` : le domaine ne voit jamais Dio.
  Future<Result<T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Ok<T>(await action());
    } on DioException catch (e) {
      return Err<T>(mapDioException(e));
    } on Object {
      // Réponse mal formée (champ manquant, mauvais type) : on ne plante pas l'UI.
      return Err<T>(const UnknownFailure('Réponse du serveur inattendue.'));
    }
  }

  @override
  Future<Result<Paginated<Quiz>>> listQuizzes({
    required String courseId,
    required int page,
    required int limit,
    String? query,
  }) {
    return _guard(() async {
      final json = await _remote.list(
        courseId: courseId,
        page: page,
        limit: limit,
        query: query,
      );
      return Paginated<Quiz>.fromEnvelope(json, quizFromJson);
    });
  }

  @override
  Future<Result<Quiz>> getQuiz(String quizId) =>
      _guard(() async => quizFromJson(await _remote.get(quizId)));

  @override
  Future<Result<Quiz>> createQuiz({
    required String courseId,
    required QuizDraft draft,
  }) {
    return _guard(() async {
      return quizFromJson(
        await _remote.create(courseId, quizDraftToJson(draft)),
      );
    });
  }

  @override
  Future<Result<Quiz>> updateQuiz(String quizId, QuizDraft draft) {
    return _guard(() async {
      return quizFromJson(
        await _remote.update(quizId, quizDraftToJson(draft)),
      );
    });
  }

  @override
  Future<Result<void>> deleteQuiz(String quizId) =>
      _guard<void>(() => _remote.delete(quizId));

  @override
  Future<Result<List<Question>>> listQuestions(String quizId) {
    return _guard(() async {
      final items = await _remote.listQuestions(quizId);
      return [for (final json in items) questionFromJson(json)];
    });
  }

  @override
  Future<Result<Question>> createQuestion({
    required String quizId,
    required QuestionDraft draft,
  }) {
    return _guard(() async {
      return questionFromJson(
        await _remote.createQuestion(quizId, questionDraftToJson(draft)),
      );
    });
  }

  @override
  Future<Result<Question>> updateQuestion(
    String questionId,
    QuestionDraft draft,
  ) {
    return _guard(() async {
      return questionFromJson(
        await _remote.updateQuestion(questionId, questionDraftToJson(draft)),
      );
    });
  }

  @override
  Future<Result<void>> deleteQuestion(String questionId) =>
      _guard<void>(() => _remote.deleteQuestion(questionId));
}
