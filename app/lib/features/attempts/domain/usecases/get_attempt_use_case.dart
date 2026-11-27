import '../../../../core/error/result.dart';
import '../entities/attempt.dart';
import '../repositories/attempt_repository.dart';

class GetAttemptUseCase {
  const GetAttemptUseCase(this._repository);

  final AttemptRepository _repository;

  Future<Result<Attempt>> call(String attemptId) =>
      _repository.getAttempt(attemptId);
}
