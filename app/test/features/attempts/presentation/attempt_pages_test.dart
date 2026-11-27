import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quizarena/core/di/service_locator.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/widgets/state_view.dart';
import 'package:quizarena/features/attempts/domain/entities/attempt.dart';
import 'package:quizarena/features/attempts/presentation/bloc/attempt_bloc.dart';
import 'package:quizarena/features/attempts/presentation/pages/attempt_page.dart';
import 'package:quizarena/features/attempts/presentation/pages/attempt_result_page.dart';

class MockAttemptBloc extends MockBloc<AttemptEvent, AttemptState>
    implements AttemptBloc {}

Attempt _activeAttempt() {
  final serverTime = DateTime.utc(2026, 11, 27, 10);
  return Attempt(
    id: 'attempt-1',
    quizId: 'quiz-1',
    status: AttemptStatus.inProgress,
    score: 0,
    totalPoints: 2,
    currentQuestion: const AttemptQuestion(
      id: 'question-1',
      prompt: 'Quel est le résultat ?',
      options: ['A', 'B'],
      points: 1,
      position: 0,
      totalQuestions: 2,
    ),
    timePerQuestionSeconds: 10,
    deadlineAt: serverTime.add(const Duration(seconds: 10)),
    serverTime: serverTime,
  );
}

Attempt _completedAttempt() => const Attempt(
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
        AttemptAnswer(
          questionId: 'question-2',
          selectedOptionIndex: null,
          isCorrect: false,
          pointsEarned: 0,
        ),
      ],
    );

Future<MockAttemptBloc> _mountAttemptPage(
  WidgetTester tester,
  AttemptState state,
) async {
  final bloc = MockAttemptBloc();
  whenListen(
    bloc,
    const Stream<AttemptState>.empty(),
    initialState: state,
  );
  sl.registerFactory<AttemptBloc>(() => bloc);
  await tester.pumpWidget(
    const MaterialApp(home: AttemptPage(quizId: 'quiz-1')),
  );
  return bloc;
}

void main() {
  setUp(() async => sl.reset());
  tearDown(() async => sl.reset());

  testWidgets('AttemptPage affiche le chargement', (tester) async {
    await _mountAttemptPage(
      tester,
      const AttemptState(status: ViewStatus.loading),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AttemptPage affiche erreur et relance le démarrage',
      (tester) async {
    final bloc = await _mountAttemptPage(
      tester,
      const AttemptState(
        status: ViewStatus.error,
        failure: NetworkFailure(),
      ),
    );

    expect(find.text('Réessayer'), findsOneWidget);
    await tester.tap(find.text('Réessayer'));
    verify(() => bloc.add(const AttemptStarted('quiz-1'))).called(2);
  });

  testWidgets('AttemptPage affiche la question et ses options', (tester) async {
    await _mountAttemptPage(
      tester,
      AttemptState(
        status: ViewStatus.content,
        attempt: _activeAttempt(),
        countdownRemaining: const Duration(seconds: 10),
      ),
    );

    expect(find.text('Question 1 / 2'), findsOneWidget);
    expect(find.text('Quel est le résultat ?'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Valider la réponse'), findsOneWidget);
  });

  testWidgets('AttemptResultPage affiche uniquement le résultat terminé',
      (tester) async {
    final bloc = MockAttemptBloc();
    whenListen(
      bloc,
      const Stream<AttemptState>.empty(),
      initialState: AttemptState(
        status: ViewStatus.content,
        attempt: _completedAttempt(),
      ),
    );
    sl.registerFactory<AttemptBloc>(() => bloc);

    await tester.pumpWidget(
      const MaterialApp(home: AttemptResultPage(attemptId: 'attempt-1')),
    );

    expect(find.text('Note : 1 / 2'), findsOneWidget);
    expect(find.text('Question 1'), findsOneWidget);
    expect(find.text('Sans réponse'), findsOneWidget);
  });
}
