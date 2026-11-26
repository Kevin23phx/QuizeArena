import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/error/result.dart';
import 'package:quizarena/features/quizzes/domain/entities/question.dart';
import 'package:quizarena/features/quizzes/domain/entities/quiz.dart';
import 'package:quizarena/features/quizzes/domain/repositories/quiz_repository.dart';
import 'package:quizarena/features/quizzes/presentation/bloc/quiz_editor_cubit.dart';

class MockQuizRepository extends Mock implements QuizRepository {}

const draft = QuizDraft(
  title: 'Quiz 1',
  durationMinutes: 20,
  status: QuizStatus.draft,
);

const questionDraft = QuestionDraft(
  text: 'Que gère un BLoC ?',
  choices: ['L\'état', 'Le style'],
  correctIndex: 0,
  points: 2,
);

const savedQuiz = Quiz(
  id: 'quiz-1',
  courseId: 'c1',
  title: 'Quiz 1',
  durationMinutes: 20,
  status: QuizStatus.draft,
  questionCount: 0,
);

void main() {
  late MockQuizRepository repo;

  setUpAll(() {
    registerFallbackValue(draft);
    registerFallbackValue(questionDraft);
  });

  setUp(() => repo = MockQuizRepository());

  QuizEditorCubit buildCubit() =>
      QuizEditorCubit(repo, const QuizEditorArgs(courseId: 'c1'));

  group('save', () {
    blocTest<QuizEditorCubit, QuizEditorState>(
      '422 avec détails -> erreurs affichées par champ',
      setUp: () {
        when(
          () => repo.createQuiz(
            courseId: any(named: 'courseId'),
            draft: any(named: 'draft'),
          ),
        ).thenAnswer(
          (_) async => const Err(
            ValidationFailure(fieldErrors: {'title': 'Le titre est requis'}),
          ),
        );
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.save(draft);
      },
      expect: () => [
        const QuizEditorState(status: EditorStatus.ready),
        const QuizEditorState(status: EditorStatus.ready, saving: true),
        const QuizEditorState(
          status: EditorStatus.ready,
          fieldErrors: {'title': 'Le titre est requis'},
        ),
      ],
    );

    blocTest<QuizEditorCubit, QuizEditorState>(
      'succès -> le quiz créé est conservé dans l\'état',
      setUp: () {
        when(
          () => repo.createQuiz(
            courseId: any(named: 'courseId'),
            draft: any(named: 'draft'),
          ),
        ).thenAnswer((_) async => const Ok(savedQuiz));
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.save(draft);
      },
      expect: () => [
        const QuizEditorState(status: EditorStatus.ready),
        const QuizEditorState(status: EditorStatus.ready, saving: true),
        const QuizEditorState(status: EditorStatus.ready, quiz: savedQuiz),
      ],
    );

    blocTest<QuizEditorCubit, QuizEditorState>(
      'erreur réseau -> message général, pas d\'erreur de champ',
      setUp: () {
        when(
          () => repo.createQuiz(
            courseId: any(named: 'courseId'),
            draft: any(named: 'draft'),
          ),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
      },
      build: buildCubit,
      act: (cubit) async {
        await cubit.load();
        await cubit.save(draft);
      },
      expect: () => [
        const QuizEditorState(status: EditorStatus.ready),
        const QuizEditorState(status: EditorStatus.ready, saving: true),
        const QuizEditorState(
          status: EditorStatus.ready,
          failure: NetworkFailure(),
        ),
      ],
    );
  });

  group('questions', () {
    test('ajouter une question avant d\'enregistrer le quiz est refusé',
        () async {
      final cubit = buildCubit();
      await cubit.load();

      final ok = await cubit.addQuestion(questionDraft);

      expect(ok, isFalse);
      expect(cubit.state.questions, isEmpty);
      verifyNever(
        () => repo.createQuestion(
          quizId: any(named: 'quizId'),
          draft: any(named: 'draft'),
        ),
      );
      await cubit.close();
    });

    test('ajouter puis supprimer une question met la liste à jour', () async {
      const question = Question(
        id: 'q-1',
        quizId: 'quiz-1',
        text: 'Que gère un BLoC ?',
        choices: ['L\'état', 'Le style'],
        correctIndex: 0,
        points: 2,
        order: 1,
      );
      when(
        () => repo.createQuiz(
          courseId: any(named: 'courseId'),
          draft: any(named: 'draft'),
        ),
      ).thenAnswer((_) async => const Ok(savedQuiz));
      when(
        () => repo.createQuestion(
          quizId: any(named: 'quizId'),
          draft: any(named: 'draft'),
        ),
      ).thenAnswer((_) async => const Ok(question));
      when(() => repo.deleteQuestion('q-1'))
          .thenAnswer((_) async => const Ok<void>(null));

      final cubit = buildCubit();
      await cubit.load();
      await cubit.save(draft);

      expect(await cubit.addQuestion(questionDraft), isTrue);
      expect(cubit.state.questions, [question]);

      expect(await cubit.removeQuestion('q-1'), isTrue);
      expect(cubit.state.questions, isEmpty);
      await cubit.close();
    });
  });
}
