import '../../../../core/error/result.dart';
import '../entities/attempt.dart';
import '../repositories/attempt_repository.dart';

class StartAttemptUseCase {
  const StartAttemptUseCase(this._repository);

  final AttemptRepository _repository;

  Future<Result<Attempt>> call(String quizId) =>
      _repository.startAttempt(quizId);
}
