import 'package:flutter_test/flutter_test.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/error/result.dart';
import 'package:quizarena/features/quizzes/data/models/quiz_json.dart';
import 'package:quizarena/features/quizzes/data/repositories/in_memory_quiz_repository.dart';
import 'package:quizarena/features/quizzes/domain/entities/quiz.dart';

void main() {
  group('quizFromJson / quizDraftToJson', () {
    test('lit un quiz du contrat proposé', () {
      final quiz = quizFromJson({
        'id': 'q1',
        'courseId': 'c1',
        'title': 'Quiz 1',
        'durationMinutes': 20,
        'status': 'published',
        'questionCount': 3,
        'opensAt': '2026-11-26T08:00:00.000Z',
        'closesAt': null,
      });

      expect(quiz.status, QuizStatus.published);
      expect(quiz.questionCount, 3);
      expect(quiz.opensAt, DateTime.utc(2026, 11, 26, 8));
      expect(quiz.closesAt, isNull);
    });

    test('un quiz brouillon n\'est jamais ouvert', () {
      final quiz = quizFromJson({
        'id': 'q1',
        'courseId': 'c1',
        'title': 'Quiz 1',
        'durationMinutes': 20,
        'status': 'draft',
      });
      expect(quiz.isOpenAt(DateTime.now()), isFalse);
    });

    test('le brouillon envoyé au serveur contient toujours les deux dates', () {
      final json = quizDraftToJson(const QuizDraft(
        title: 'Quiz 1',
        durationMinutes: 20,
        status: QuizStatus.draft,
      ));

      expect(json.containsKey('opensAt'), isTrue);
      expect(json['opensAt'], isNull);
      expect(json['status'], 'draft');
    });
  });

  group('InMemoryQuizRepository', () {
    test('liste paginée et filtrée par recherche', () async {
      final repo = InMemoryQuizRepository();

      final all = await repo.listQuizzes(courseId: 'c1', page: 1, limit: 1);
      expect(all, isA<Ok<dynamic>>());
      final page = (all as Ok).value;
      expect(page.items.length, 1);
      expect(page.total, 2);
      expect(page.hasMore, isTrue);

      final found = await repo.listQuizzes(
        courseId: 'c1',
        page: 1,
        limit: 20,
        query: 'navigation',
      );
      expect((found as Ok).value.items.length, 1);
    });

    test('titre vide -> ValidationFailure avec erreur sur le champ', () async {
      final repo = InMemoryQuizRepository();

      final result = await repo.createQuiz(
        courseId: 'c1',
        draft: const QuizDraft(
          title: '  ',
          durationMinutes: 20,
          status: QuizStatus.draft,
        ),
      );

      expect(result, isA<Err<dynamic>>());
      final failure = (result as Err).failure;
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).fieldErrors.containsKey('title'),
          isTrue);
    });
  });
}
