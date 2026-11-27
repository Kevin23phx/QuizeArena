import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/error/result.dart';
import 'package:quizarena/core/widgets/state_view.dart';
import 'package:quizarena/features/attempts/domain/entities/attempt.dart';
import 'package:quizarena/features/attempts/domain/repositories/attempt_repository.dart';
import 'package:quizarena/features/attempts/domain/usecases/get_attempt_use_case.dart';
import 'package:quizarena/features/attempts/domain/usecases/start_attempt_use_case.dart';
import 'package:quizarena/features/attempts/domain/usecases/submit_attempt_answer_use_case.dart';
import 'package:quizarena/features/attempts/presentation/bloc/attempt_bloc.dart';

class MockAttemptRepository extends Mock implements AttemptRepository {}

Attempt activeAttempt({String questionId = 'question-1', int position = 0}) {
  final serverTime = DateTime.utc(2026, 11, 27, 10);
  return Attempt(
    id: 'attempt-1',
    quizId: 'quiz-1',
    status: AttemptStatus.inProgress,
    score: 0,
    totalPoints: 2,
    currentQuestion: AttemptQuestion(
      id: questionId,
      prompt: 'Question $position',
      options: const ['A', 'B'],
      points: 1,
      position: position,
      totalQuestions: 2,
    ),
    timePerQuestionSeconds: 10,
    deadlineAt: serverTime.add(const Duration(seconds: 10)),
    serverTime: serverTime,
  );
}

Attempt completedAttempt() => const Attempt(
      id: 'attempt-1',
      quizId: 'quiz-1',
      status: AttemptStatus.completed,
      score: 1,
      totalPoints: 2,
      answers: [
        AttemptAnswer(
          questionId: 'question-1',
          selectedOptionIndex: 1,
          isCorrect: true,
          pointsEarned: 1,
        ),
      ],
    );

AttemptBloc buildBloc(MockAttemptRepository repository) => AttemptBloc(
      StartAttemptUseCase(repository),
      GetAttemptUseCase(repository),
      SubmitAttemptAnswerUseCase(repository),
    );

AttemptState activeState() => AttemptState(
      status: ViewStatus.content,
      attempt: activeAttempt(),
      countdownRemaining: const Duration(seconds: 10),
    );

void main() {
  late MockAttemptRepository repository;

  setUp(() => repository = MockAttemptRepository());

  blocTest<AttemptBloc, AttemptState>(
    'AttemptStarted succès -> contenu',
    setUp: () {
      when(() => repository.startAttempt('quiz-1'))
          .thenAnswer((_) async => Ok(activeAttempt()));
    },
    build: () => buildBloc(repository),
    act: (bloc) => bloc.add(const AttemptStarted('quiz-1')),
    expect: () => [
      const AttemptState(status: ViewStatus.loading),
      isA<AttemptState>()
          .having((state) => state.status, 'status', ViewStatus.content)
          .having((state) => state.attempt, 'attempt', activeAttempt()),
    ],
  );

  blocTest<AttemptBloc, AttemptState>(
    'AttemptStarted échec -> Failure',
    setUp: () {
      when(() => repository.startAttempt('quiz-1'))
          .thenAnswer((_) async => const Err(NetworkFailure()));
    },
    build: () => buildBloc(repository),
    act: (bloc) => bloc.add(const AttemptStarted('quiz-1')),
    expect: () => [
      const AttemptState(status: ViewStatus.loading),
      const AttemptState(
        status: ViewStatus.error,
        failure: NetworkFailure(),
      ),
    ],
  );

  blocTest<AttemptBloc, AttemptState>(
    'AnswerSubmitted succès -> tentative actualisée',
    setUp: () {
      when(
        () => repository.submitAnswer('attempt-1', 'question-1', 1),
      ).thenAnswer(
        (_) async => Ok(
          activeAttempt(
            questionId: 'question-2',
            position: 1,
          ),
        ),
      );
    },
    build: () => buildBloc(repository),
    seed: activeState,
    act: (bloc) => bloc.add(const AnswerSubmitted('question-1', 1)),
    expect: () => [
      AttemptState(
        status: ViewStatus.content,
        submitting: true,
        attempt: activeAttempt(),
        countdownRemaining: const Duration(seconds: 10),
      ),
      AttemptState(
        status: ViewStatus.content,
        attempt: activeAttempt(
          questionId: 'question-2',
          position: 1,
        ),
        countdownRemaining: const Duration(seconds: 10),
      ),
    ],
  );

  blocTest<AttemptBloc, AttemptState>(
    'AnswerSubmitted échec -> Failure visible',
    setUp: () {
      when(
        () => repository.submitAnswer('attempt-1', 'question-1', 1),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
    },
    build: () => buildBloc(repository),
    seed: activeState,
    act: (bloc) => bloc.add(const AnswerSubmitted('question-1', 1)),
    expect: () => [
      AttemptState(
        status: ViewStatus.content,
        submitting: true,
        attempt: activeAttempt(),
        countdownRemaining: const Duration(seconds: 10),
      ),
      AttemptState(
        status: ViewStatus.error,
        attempt: activeAttempt(),
        failure: const NetworkFailure(),
      ),
    ],
  );

  blocTest<AttemptBloc, AttemptState>(
    'TimeElapsed succès -> recharge l’état',
    setUp: () {
      when(() => repository.getAttempt('attempt-1'))
          .thenAnswer((_) async => Ok(activeAttempt(position: 1)));
    },
    build: () => buildBloc(repository),
    seed: activeState,
    act: (bloc) => bloc.add(const TimeElapsed()),
    expect: () => [
      const AttemptState(status: ViewStatus.loading),
      AttemptState(
        status: ViewStatus.content,
        attempt: activeAttempt(position: 1),
        countdownRemaining: const Duration(seconds: 10),
      ),
    ],
  );

  blocTest<AttemptBloc, AttemptState>(
    'TimeElapsed échec -> Failure',
    setUp: () {
      when(() => repository.getAttempt('attempt-1'))
          .thenAnswer((_) async => const Err(NetworkFailure()));
    },
    build: () => buildBloc(repository),
    seed: activeState,
    act: (bloc) => bloc.add(const TimeElapsed()),
    expect: () => [
      const AttemptState(status: ViewStatus.loading),
      const AttemptState(
        status: ViewStatus.error,
        failure: NetworkFailure(),
      ),
    ],
  );

  blocTest<AttemptBloc, AttemptState>(
    'AttemptReloaded succès -> contenu du serveur',
    setUp: () {
      when(() => repository.getAttempt('attempt-1'))
          .thenAnswer((_) async => Ok(completedAttempt()));
    },
    build: () => buildBloc(repository),
    seed: activeState,
    act: (bloc) => bloc.add(const AttemptReloaded()),
    expect: () => [
      const AttemptState(status: ViewStatus.loading),
      AttemptState(
        status: ViewStatus.content,
        attempt: completedAttempt(),
      ),
    ],
  );

  blocTest<AttemptBloc, AttemptState>(
    'AttemptReloaded échec -> Failure',
    setUp: () {
      when(() => repository.getAttempt('attempt-1'))
          .thenAnswer((_) async => const Err(NetworkFailure()));
    },
    build: () => buildBloc(repository),
    seed: activeState,
    act: (bloc) => bloc.add(const AttemptReloaded()),
    expect: () => [
      const AttemptState(status: ViewStatus.loading),
      const AttemptState(
        status: ViewStatus.error,
        failure: NetworkFailure(),
      ),
    ],
  );

  blocTest<AttemptBloc, AttemptState>(
    'une réponse 409 recharge l’état serveur',
    setUp: () {
      when(
        () => repository.submitAnswer('attempt-1', 'question-1', 1),
      ).thenAnswer((_) async => const Err(ConflictFailure()));
      when(() => repository.getAttempt('attempt-1'))
          .thenAnswer((_) async => Ok(activeAttempt(position: 1)));
    },
    build: () => buildBloc(repository),
    seed: activeState,
    act: (bloc) => bloc.add(const AnswerSubmitted('question-1', 1)),
    expect: () => [
      AttemptState(
        status: ViewStatus.content,
        submitting: true,
        attempt: activeAttempt(),
        countdownRemaining: const Duration(seconds: 10),
      ),
      const AttemptState(status: ViewStatus.loading),
      AttemptState(
        status: ViewStatus.content,
        attempt: activeAttempt(position: 1),
        countdownRemaining: const Duration(seconds: 10),
      ),
    ],
    verify: (_) {
      verify(() => repository.getAttempt('attempt-1')).called(1);
    },
  );

  blocTest<AttemptBloc, AttemptState>(
    'droppable ignore les soumissions pendant une réponse en cours',
    setUp: () {
      when(
        () => repository.submitAnswer('attempt-1', 'question-1', 1),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        return Ok(completedAttempt());
      });
    },
    build: () => buildBloc(repository),
    seed: activeState,
    act: (bloc) async {
      bloc.add(const AnswerSubmitted('question-1', 1));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      bloc.add(const AnswerSubmitted('question-1', 0));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    },
    expect: () => [
      AttemptState(
        status: ViewStatus.content,
        submitting: true,
        attempt: activeAttempt(),
        countdownRemaining: const Duration(seconds: 10),
      ),
      AttemptState(
        status: ViewStatus.content,
        attempt: completedAttempt(),
      ),
    ],
    verify: (_) {
      verify(
        () => repository.submitAnswer('attempt-1', 'question-1', 1),
      ).called(1);
      verifyNever(
        () => repository.submitAnswer('attempt-1', 'question-1', 0),
      );
    },
  );
}
