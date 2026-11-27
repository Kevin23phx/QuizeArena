import 'package:dio/dio.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/failure_mapper.dart';
import '../../domain/entities/attempt.dart';
import '../../domain/repositories/attempt_repository.dart';
import '../datasources/attempt_remote_data_source.dart';
import '../models/attempt_json.dart';

class AttemptRepositoryImpl implements AttemptRepository {
  AttemptRepositoryImpl(this._remote);

  final AttemptRemoteDataSource _remote;

  Future<Result<Attempt>> _guard(Future<Attempt> Function() action) async {
    try {
      return Ok<Attempt>(await action());
    } on DioException catch (error) {
      return Err<Attempt>(mapDioException(error));
    } on Object {
      return const Err<Attempt>(
        UnknownFailure('Réponse du serveur inattendue.'),
      );
    }
  }

  @override
  Future<Result<Attempt>> startAttempt(String quizId) => _guard(
        () async => AttemptJson.fromJson(await _remote.startAttempt(quizId)),
      );

  @override
  Future<Result<Attempt>> getAttempt(String attemptId) => _guard(
        () async => AttemptJson.fromJson(await _remote.getAttempt(attemptId)),
      );

  @override
  Future<Result<Attempt>> submitAnswer(
    String attemptId,
    String questionId,
    int selectedOptionIndex,
  ) =>
      _guard(
        () async => AttemptJson.fromJson(
          await _remote.submitAnswer(
            attemptId: attemptId,
            questionId: questionId,
            selectedOptionIndex: selectedOptionIndex,
          ),
        ),
      );
}
