import '../../../../core/error/result.dart';
import '../entities/attempt.dart';

abstract interface class AttemptRepository {
  Future<Result<Attempt>> startAttempt(String quizId);

  Future<Result<Attempt>> getAttempt(String attemptId);

  Future<Result<Attempt>> submitAnswer(
    String attemptId,
    String questionId,
    int selectedOptionIndex,
  );
}
