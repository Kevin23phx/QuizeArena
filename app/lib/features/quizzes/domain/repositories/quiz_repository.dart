import 'package:quizarena/core/error/result.dart';
import 'package:quizarena/core/network/paginated.dart';

import '../entities/question.dart';
import '../entities/quiz.dart';

/// Contrat du domaine : aucune dépendance à Flutter ni à Dio.
/// L'implémentation (data) convertit les erreurs réseau en `Failure`.
abstract interface class QuizRepository {
  Future<Result<Paginated<Quiz>>> listQuizzes({
    required String courseId,
    required int page,
    required int limit,
    String? query,
  });

  Future<Result<Quiz>> getQuiz(String quizId);

  Future<Result<Quiz>> createQuiz({
    required String courseId,
    required QuizDraft draft,
  });

  Future<Result<Quiz>> updateQuiz(String quizId, QuizDraft draft);

  Future<Result<void>> deleteQuiz(String quizId);

  /// Réservé à l'enseignant propriétaire (contient la bonne réponse).
  Future<Result<List<Question>>> listQuestions(String quizId);

  Future<Result<Question>> createQuestion({
    required String quizId,
    required QuestionDraft draft,
  });

  Future<Result<Question>> updateQuestion(
    String questionId,
    QuestionDraft draft,
  );

  Future<Result<void>> deleteQuestion(String questionId);
}
