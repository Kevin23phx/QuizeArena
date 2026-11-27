import 'package:flutter_test/flutter_test.dart';
import 'package:quizarena/features/attempts/domain/entities/attempt.dart';

Attempt _attempt({
  AttemptStatus status = AttemptStatus.inProgress,
  int score = 0,
  DateTime? deadlineAt,
  DateTime? serverTime,
  List<AttemptAnswer> answers = const [],
}) {
  return Attempt(
    id: 'attempt-1',
    quizId: 'quiz-1',
    status: status,
    score: score,
    totalPoints: 2,
    deadlineAt: deadlineAt,
    serverTime: serverTime,
    answers: answers,
  );
}

void main() {
  group('Attempt.remainingWhenReceived', () {
    test('utilise les deux heures du serveur', () {
      final attempt = _attempt(
        deadlineAt: DateTime.utc(2026, 11, 26, 10, 0, 10),
        serverTime: DateTime.utc(2026, 11, 26, 10, 0, 3),
      );
      expect(attempt.remainingWhenReceived, const Duration(seconds: 7));
    });

    test('ne devient jamais négatif', () {
      final attempt = _attempt(
        deadlineAt: DateTime.utc(2026, 11, 26, 10, 0, 3),
        serverTime: DateTime.utc(2026, 11, 26, 10, 0, 10),
      );
      expect(attempt.remainingWhenReceived, Duration.zero);
    });

    test('est absent sans heure limite', () {
      expect(_attempt().remainingWhenReceived, isNull);
    });
  });

  group('Attempt.finalScore', () {
    test('est absent tant que la tentative est en cours', () {
      expect(_attempt(score: 1).finalScore, isNull);
    });

    test('est celui du serveur quand la tentative est terminée', () {
      final attempt = _attempt(status: AttemptStatus.completed, score: 1);
      expect(attempt.finalScore, 1);
    });
  });

  group('Attempt.correctAnswersCount', () {
    test('compte les bonnes réponses', () {
      final attempt = _attempt(
        status: AttemptStatus.completed,
        answers: const [
          AttemptAnswer(
            questionId: 'q1',
            selectedOptionIndex: 1,
            isCorrect: true,
            pointsEarned: 1,
          ),
          AttemptAnswer(
            questionId: 'q2',
            selectedOptionIndex: null,
            isCorrect: false,
            pointsEarned: 0,
          ),
        ],
      );
      expect(attempt.correctAnswersCount, 1);
      expect(attempt.answers[1].wasSkipped, isTrue);
    });
  });
}
