import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/error/result.dart';
import 'package:quizarena/features/attempts/data/datasources/attempt_remote_data_source.dart';
import 'package:quizarena/features/attempts/data/repositories/attempt_repository_impl.dart';

class MockAttemptRemoteDataSource extends Mock
    implements AttemptRemoteDataSource {}

final _startedAt = DateTime.utc(2026, 11, 27, 10).toIso8601String();
final _serverTime = DateTime.utc(2026, 11, 27, 10).toIso8601String();
final _deadlineAt = DateTime.utc(2026, 11, 27, 10, 0, 10).toIso8601String();

Map<String, dynamic> _inProgressJson() => {
      'id': 'attempt-1',
      'quizId': 'quiz-1',
      'status': 'in_progress',
      'startedAt': _startedAt,
      'score': 0,
      'totalPoints': 2,
      'timePerQuestionSeconds': 10,
      'deadlineAt': _deadlineAt,
      'serverTime': _serverTime,
      'currentQuestion': {
        'id': 'question-1',
        'prompt': 'Prompt',
        'options': ['A', 'B'],
        'points': 2,
        'position': 0,
        'totalQuestions': 1,
      },
    };

Map<String, dynamic> _completedJson() => {
      'id': 'attempt-1',
      'quizId': 'quiz-1',
      'status': 'completed',
      'startedAt': _startedAt,
      'submittedAt': _deadlineAt,
      'score': 0,
      'totalPoints': 2,
      'answers': [
        {
          'questionId': 'question-1',
          'selectedOptionIndex': null,
          'isCorrect': false,
          'pointsEarned': 0,
          'answeredAt': _deadlineAt,
        },
      ],
    };

void main() {
  late MockAttemptRemoteDataSource remote;
  late AttemptRepositoryImpl repository;

  setUp(() {
    remote = MockAttemptRemoteDataSource();
    repository = AttemptRepositoryImpl(remote);
  });

  test('mappe la tentative en cours depuis les horaires serveur', () async {
    when(() => remote.startAttempt('quiz-1'))
        .thenAnswer((_) async => _inProgressJson());

    final result = await repository.startAttempt('quiz-1');

    switch (result) {
      case Ok(:final value):
        expect(value.id, 'attempt-1');
        expect(value.currentQuestion?.prompt, 'Prompt');
        expect(value.remainingWhenReceived, const Duration(seconds: 10));
        expect(value.finalScore, isNull);
      case Err():
        fail('La tentative valide doit être convertie.');
    }
  });

  test('mappe le résultat du serveur sans révéler le texte des questions',
      () async {
    when(() => remote.getAttempt('attempt-1'))
        .thenAnswer((_) async => _completedJson());

    final result = await repository.getAttempt('attempt-1');

    switch (result) {
      case Ok(:final value):
        expect(value.finalScore, 0);
        expect(value.answers.single.wasSkipped, isTrue);
        expect(value.currentQuestion, isNull);
      case Err():
        fail('Le résultat valide doit être converti.');
    }
  });

  test('convertit une erreur Dio 409 en ConflictFailure', () async {
    final request = RequestOptions(path: '/attempts/attempt-1');
    final exception = DioException(
      requestOptions: request,
      response: Response<Map<String, dynamic>>(
        requestOptions: request,
        statusCode: 409,
        data: {
          'error': {
            'code': 'ATTEMPT_UPDATED',
            'message': 'Reload the attempt.',
          },
        },
      ),
      type: DioExceptionType.badResponse,
    );
    when(() => remote.getAttempt('attempt-1')).thenThrow(exception);

    final result = await repository.getAttempt('attempt-1');

    switch (result) {
      case Err(:final failure):
        expect(failure, const ConflictFailure('Reload the attempt.'));
      case Ok():
        fail('Une erreur Dio doit devenir une Failure.');
    }
  });

  test('renvoie UnknownFailure pour une réponse mal formée', () async {
    when(() => remote.getAttempt('attempt-1'))
        .thenAnswer((_) async => {'id': 'attempt-1'});

    final result = await repository.getAttempt('attempt-1');

    switch (result) {
      case Err(:final failure):
        expect(
          failure,
          const UnknownFailure('Réponse du serveur inattendue.'),
        );
      case Ok():
        fail('Une réponse invalide ne doit pas devenir un succès.');
    }
  });
}
