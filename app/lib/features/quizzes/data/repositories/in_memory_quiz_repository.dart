import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/error/result.dart';
import 'package:quizarena/core/network/paginated.dart';

import '../../domain/entities/question.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/repositories/quiz_repository.dart';

/// Implémentation de DÉMONSTRATION, sans réseau, pour tester les écrans avant
/// que l'API quiz soit prête. Activée avec :
///   flutter run --dart-define=USE_FAKE_DATA=true
/// Elle respecte le même contrat que la vraie implémentation.
class InMemoryQuizRepository implements QuizRepository {
  final Map<String, List<Quiz>> _quizzesByCourse = {};
  final Map<String, List<Question>> _questionsByQuiz = {};
  int _next = 100;

  Future<void> _latency() =>
      Future<void>.delayed(const Duration(milliseconds: 300));

  List<Quiz> _forCourse(String courseId) {
    return _quizzesByCourse.putIfAbsent(courseId, () {
      final published = Quiz(
        id: 'quiz-$courseId-1',
        courseId: courseId,
        title: 'Quiz 1 · Flutter et BLoC',
        durationMinutes: 20,
        status: QuizStatus.published,
        questionCount: 2,
        closesAt: DateTime.now().add(const Duration(days: 3)),
      );
      final draft = Quiz(
        id: 'quiz-$courseId-2',
        courseId: courseId,
        title: 'Quiz 2 · Navigation',
        durationMinutes: 15,
        status: QuizStatus.draft,
        questionCount: 0,
      );
      _questionsByQuiz[published.id] = [
        Question(
          id: 'q-${published.id}-1',
          quizId: published.id,
          text: 'Que gère un BLoC ?',
          choices: const [
            'L\'état et ses transitions',
            'Le style des widgets',
            'Le routage'
          ],
          correctIndex: 0,
          points: 2,
          order: 1,
        ),
        Question(
          id: 'q-${published.id}-2',
          quizId: published.id,
          text: 'Quelle couche ne dépend ni de Flutter ni de Dio ?',
          choices: const ['presentation', 'domain', 'data', 'core'],
          correctIndex: 1,
          points: 2,
          order: 2,
        ),
      ];
      return [published, draft];
    });
  }

  Quiz? _find(String quizId) {
    for (final quizzes in _quizzesByCourse.values) {
      for (final quiz in quizzes) {
        if (quiz.id == quizId) return quiz;
      }
    }
    return null;
  }

  void _replace(Quiz updated) {
    final list = _quizzesByCourse[updated.courseId];
    if (list == null) return;
    final index = list.indexWhere((q) => q.id == updated.id);
    if (index >= 0) list[index] = updated;
  }

  void _syncCount(String quizId) {
    final quiz = _find(quizId);
    if (quiz == null) return;
    _replace(
        quiz.copyWith(questionCount: _questionsByQuiz[quizId]?.length ?? 0));
  }

  Quiz _fromDraft(String id, String courseId, QuizDraft draft, int count) {
    return Quiz(
      id: id,
      courseId: courseId,
      title: draft.title,
      durationMinutes: draft.durationMinutes,
      status: draft.status,
      questionCount: count,
      opensAt: draft.opensAt,
      closesAt: draft.closesAt,
    );
  }

  ValidationFailure? _validateQuiz(QuizDraft draft) {
    final errors = <String, String>{};
    if (draft.title.trim().isEmpty) errors['title'] = 'Le titre est requis.';
    if (draft.durationMinutes < 1) {
      errors['durationMinutes'] = 'La durée doit être d\'au moins 1 minute.';
    }
    return errors.isEmpty ? null : ValidationFailure(fieldErrors: errors);
  }

  @override
  Future<Result<Paginated<Quiz>>> listQuizzes({
    required String courseId,
    required int page,
    required int limit,
    String? query,
  }) async {
    await _latency();
    final needle = (query ?? '').toLowerCase();
    final all = [
      for (final q in _forCourse(courseId))
        if (needle.isEmpty || q.title.toLowerCase().contains(needle)) q,
    ];
    final start = ((page - 1) * limit).clamp(0, all.length);
    final end = (start + limit).clamp(0, all.length);
    return Ok(Paginated<Quiz>(
      items: all.sublist(start, end),
      page: page,
      limit: limit,
      total: all.length,
    ));
  }

  @override
  Future<Result<Quiz>> getQuiz(String quizId) async {
    await _latency();
    final quiz = _find(quizId);
    if (quiz == null) return const Err(NotFoundFailure('Quiz introuvable.'));
    return Ok(quiz);
  }

  @override
  Future<Result<Quiz>> createQuiz({
    required String courseId,
    required QuizDraft draft,
  }) async {
    await _latency();
    final invalid = _validateQuiz(draft);
    if (invalid != null) return Err(invalid);
    final quiz = _fromDraft('quiz-${_next++}', courseId, draft, 0);
    _forCourse(courseId).add(quiz);
    _questionsByQuiz[quiz.id] = [];
    return Ok(quiz);
  }

  @override
  Future<Result<Quiz>> updateQuiz(String quizId, QuizDraft draft) async {
    await _latency();
    final existing = _find(quizId);
    if (existing == null)
      return const Err(NotFoundFailure('Quiz introuvable.'));
    final invalid = _validateQuiz(draft);
    if (invalid != null) return Err(invalid);
    final count = _questionsByQuiz[quizId]?.length ?? 0;
    if (draft.status == QuizStatus.published && count == 0) {
      return const Err(ValidationFailure(
        message: 'Ajoutez au moins une question avant de publier.',
      ));
    }
    final updated = _fromDraft(quizId, existing.courseId, draft, count);
    _replace(updated);
    return Ok(updated);
  }

  @override
  Future<Result<void>> deleteQuiz(String quizId) async {
    await _latency();
    for (final list in _quizzesByCourse.values) {
      list.removeWhere((q) => q.id == quizId);
    }
    _questionsByQuiz.remove(quizId);
    return const Ok<void>(null);
  }

  @override
  Future<Result<List<Question>>> listQuestions(String quizId) async {
    await _latency();
    return Ok(List<Question>.of(_questionsByQuiz[quizId] ?? const []));
  }

  ValidationFailure? _validateQuestion(QuestionDraft draft) {
    final errors = <String, String>{};
    if (draft.text.trim().isEmpty) errors['text'] = 'L\'énoncé est requis.';
    if (draft.choices.length < 2) errors['choices'] = 'Au moins 2 choix.';
    if (draft.correctIndex < 0 || draft.correctIndex >= draft.choices.length) {
      errors['correctIndex'] = 'Bonne réponse invalide.';
    }
    return errors.isEmpty ? null : ValidationFailure(fieldErrors: errors);
  }

  @override
  Future<Result<Question>> createQuestion({
    required String quizId,
    required QuestionDraft draft,
  }) async {
    await _latency();
    final invalid = _validateQuestion(draft);
    if (invalid != null) return Err(invalid);
    final list = _questionsByQuiz.putIfAbsent(quizId, () => []);
    final question = Question(
      id: 'q-${_next++}',
      quizId: quizId,
      text: draft.text,
      choices: draft.choices,
      correctIndex: draft.correctIndex,
      points: draft.points,
      order: list.length + 1,
    );
    list.add(question);
    _syncCount(quizId);
    return Ok(question);
  }

  @override
  Future<Result<Question>> updateQuestion(
    String questionId,
    QuestionDraft draft,
  ) async {
    await _latency();
    final invalid = _validateQuestion(draft);
    if (invalid != null) return Err(invalid);
    for (final list in _questionsByQuiz.values) {
      final index = list.indexWhere((q) => q.id == questionId);
      if (index >= 0) {
        final old = list[index];
        final updated = Question(
          id: old.id,
          quizId: old.quizId,
          text: draft.text,
          choices: draft.choices,
          correctIndex: draft.correctIndex,
          points: draft.points,
          order: old.order,
        );
        list[index] = updated;
        return Ok(updated);
      }
    }
    return const Err(NotFoundFailure('Question introuvable.'));
  }

  @override
  Future<Result<void>> deleteQuestion(String questionId) async {
    await _latency();
    for (final entry in _questionsByQuiz.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((q) => q.id == questionId);
      if (entry.value.length != before) {
        _syncCount(entry.key);
        break;
      }
    }
    return const Ok<void>(null);
  }
}
