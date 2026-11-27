import '../../../../core/error/result.dart';
import '../entities/attempt.dart';
import '../repositories/attempt_repository.dart';

class SubmitAttemptAnswerUseCase {
  const SubmitAttemptAnswerUseCase(this._repository);

  final AttemptRepository _repository;

  Future<Result<Attempt>> call({
    required String attemptId,
    required String questionId,
    required int selectedOptionIndex,
  }) =>
      _repository.submitAnswer(
        attemptId,
        questionId,
        selectedOptionIndex,
      );
}
