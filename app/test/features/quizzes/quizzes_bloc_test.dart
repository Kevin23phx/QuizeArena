import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/error/result.dart';
import 'package:quizarena/core/network/paginated.dart';
import 'package:quizarena/core/widgets/state_view.dart';
import 'package:quizarena/features/quizzes/domain/entities/quiz.dart';
import 'package:quizarena/features/quizzes/domain/repositories/quiz_repository.dart';
import 'package:quizarena/features/quizzes/presentation/bloc/quizzes_bloc.dart';

class MockQuizRepository extends Mock implements QuizRepository {}

const quiz1 = Quiz(
  id: '1',
  courseId: 'c1',
  title: 'Quiz 1',
  durationMinutes: 20,
  status: QuizStatus.published,
  questionCount: 2,
);

const quiz2 = Quiz(
  id: '2',
  courseId: 'c1',
  title: 'Quiz 2',
  durationMinutes: 15,
  status: QuizStatus.draft,
  questionCount: 0,
);

Paginated<Quiz> pageOf(
  List<Quiz> items, {
  int page = 1,
  int total = -1,
}) {
  return Paginated<Quiz>(
    items: items,
    page: page,
    limit: QuizzesBloc.pageSize,
    total: total < 0 ? items.length : total,
  );
}

void stubList(MockQuizRepository repo, Result<Paginated<Quiz>> result) {
  when(
    () => repo.listQuizzes(
      courseId: any(named: 'courseId'),
      page: any(named: 'page'),
      limit: any(named: 'limit'),
      query: any(named: 'query'),
    ),
  ).thenAnswer((_) async => result);
}

void main() {
  late MockQuizRepository repo;

  setUp(() => repo = MockQuizRepository());

  QuizzesBloc buildBloc() => QuizzesBloc(repo, courseId: 'c1');

  blocTest<QuizzesBloc, QuizzesState>(
    'chargement réussi -> contenu',
    setUp: () => stubList(repo, Ok(pageOf([quiz1, quiz2]))),
    build: buildBloc,
    act: (bloc) => bloc.add(const QuizzesStarted()),
    expect: () => [
      const QuizzesState(status: ViewStatus.loading),
      const QuizzesState(
        status: ViewStatus.content,
        quizzes: [quiz1, quiz2],
      ),
    ],
  );

  blocTest<QuizzesBloc, QuizzesState>(
    'liste vide -> état vide',
    setUp: () => stubList(repo, Ok(pageOf(const []))),
    build: buildBloc,
    act: (bloc) => bloc.add(const QuizzesStarted()),
    expect: () => [
      const QuizzesState(status: ViewStatus.loading),
      const QuizzesState(status: ViewStatus.empty),
    ],
  );

  blocTest<QuizzesBloc, QuizzesState>(
    'échec réseau -> état erreur avec la Failure',
    setUp: () => stubList(repo, const Err(NetworkFailure())),
    build: buildBloc,
    act: (bloc) => bloc.add(const QuizzesStarted()),
    expect: () => [
      const QuizzesState(status: ViewStatus.loading),
      const QuizzesState(
        status: ViewStatus.error,
        failure: NetworkFailure(),
      ),
    ],
  );

  blocTest<QuizzesBloc, QuizzesState>(
    'recherche : le debounce n\'envoie qu\'une requête, avec la dernière saisie',
    setUp: () => stubList(repo, Ok(pageOf([quiz1]))),
    build: buildBloc,
    act: (bloc) {
      bloc
        ..add(const QuizzesSearchChanged('a'))
        ..add(const QuizzesSearchChanged('ab'))
        ..add(const QuizzesSearchChanged('abc'));
    },
    wait: QuizzesBloc.searchDebounce + const Duration(milliseconds: 200),
    expect: () => [
      const QuizzesState(status: ViewStatus.loading, query: 'abc'),
      const QuizzesState(
        status: ViewStatus.content,
        quizzes: [quiz1],
        query: 'abc',
      ),
    ],
    verify: (_) {
      verify(
        () => repo.listQuizzes(
          courseId: 'c1',
          page: 1,
          limit: QuizzesBloc.pageSize,
          query: 'abc',
        ),
      ).called(1);
      verifyNever(
        () => repo.listQuizzes(
          courseId: 'c1',
          page: 1,
          limit: QuizzesBloc.pageSize,
          query: 'a',
        ),
      );
    },
  );

  blocTest<QuizzesBloc, QuizzesState>(
    'page suivante : ajoute les éléments à la liste existante',
    setUp: () => stubList(repo, Ok(pageOf([quiz2], page: 2, total: 30))),
    build: buildBloc,
    seed: () => const QuizzesState(
      status: ViewStatus.content,
      quizzes: [quiz1],
      hasMore: true,
    ),
    act: (bloc) => bloc.add(const QuizzesNextPageRequested()),
    expect: () => [
      const QuizzesState(
        status: ViewStatus.content,
        quizzes: [quiz1],
        hasMore: true,
        loadingMore: true,
      ),
      const QuizzesState(
        status: ViewStatus.content,
        quizzes: [quiz1, quiz2],
        page: 2,
      ),
    ],
  );
}
