import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/error/result.dart';

import '../../domain/entities/question.dart';
import '../../domain/entities/quiz.dart';
import '../../domain/repositories/quiz_repository.dart';

/// Paramètres de l'éditeur : création (courseId) ou modification (quizId).
class QuizEditorArgs extends Equatable {
  const QuizEditorArgs({this.courseId, this.quizId});

  final String? courseId;
  final String? quizId;

  @override
  List<Object?> get props => [courseId, quizId];
}

enum EditorStatus { loading, ready, loadFailed }

class QuizEditorState extends Equatable {
  const QuizEditorState({
    this.status = EditorStatus.loading,
    this.quiz,
    this.questions = const [],
    this.saving = false,
    this.fieldErrors = const {},
    this.failure,
  });

  final EditorStatus status;

  /// Null tant que le quiz n'a pas été enregistré une première fois.
  final Quiz? quiz;
  final List<Question> questions;
  final bool saving;

  /// Erreurs 422 du serveur, par champ du formulaire du quiz.
  final Map<String, String> fieldErrors;
  final Failure? failure;

  QuizEditorState copyWith({
    EditorStatus? status,
    Quiz? quiz,
    List<Question>? questions,
    bool? saving,
    Map<String, String>? fieldErrors,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return QuizEditorState(
      status: status ?? this.status,
      quiz: quiz ?? this.quiz,
      questions: questions ?? this.questions,
      saving: saving ?? this.saving,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props =>
      [status, quiz, questions, saving, fieldErrors, failure];
}

/// Logique de l'éditeur de quiz (enseignant). Les widgets n'ont aucune règle
/// métier : ils lisent l'état et appellent ces méthodes.
class QuizEditorCubit extends Cubit<QuizEditorState> {
  QuizEditorCubit(this._repository, this._args)
      : super(const QuizEditorState());

  final QuizRepository _repository;
  final QuizEditorArgs _args;

  Future<void> load() async {
    final quizId = _args.quizId;
    if (quizId == null) {
      emit(state.copyWith(status: EditorStatus.ready));
      return;
    }

    emit(state.copyWith(status: EditorStatus.loading, clearFailure: true));

    final quizResult = await _repository.getQuiz(quizId);
    switch (quizResult) {
      case Err(:final failure):
        emit(state.copyWith(status: EditorStatus.loadFailed, failure: failure));
      case Ok(value: final quiz):
        final questionsResult = await _repository.listQuestions(quizId);
        switch (questionsResult) {
          case Err(:final failure):
            emit(
              state.copyWith(
                status: EditorStatus.loadFailed,
                failure: failure,
              ),
            );
          case Ok(value: final questions):
            emit(
              state.copyWith(
                status: EditorStatus.ready,
                quiz: quiz,
                questions: questions,
              ),
            );
        }
    }
  }

  /// Crée ou met à jour le quiz. Retourne true si le serveur a accepté.
  Future<bool> save(QuizDraft draft) async {
    final existing = state.quiz;
    final courseId = existing?.courseId ?? _args.courseId;
    if (courseId == null) {
      emit(
        state.copyWith(
          failure: const UnknownFailure('Cours introuvable pour ce quiz.'),
        ),
      );
      return false;
    }

    emit(
      state.copyWith(
        saving: true,
        fieldErrors: const {},
        clearFailure: true,
      ),
    );

    final result = existing == null
        ? await _repository.createQuiz(courseId: courseId, draft: draft)
        : await _repository.updateQuiz(existing.id, draft);

    switch (result) {
      case Ok(:final value):
        emit(state.copyWith(saving: false, quiz: value));
        return true;
      case Err(:final failure):
        _emitFailure(failure, fieldLevel: true);
        return false;
    }
  }

  Future<bool> deleteQuiz() async {
    final quiz = state.quiz;
    if (quiz == null) return false;

    emit(state.copyWith(saving: true, clearFailure: true));
    final result = await _repository.deleteQuiz(quiz.id);
    switch (result) {
      case Ok():
        emit(state.copyWith(saving: false));
        return true;
      case Err(:final failure):
        _emitFailure(failure);
        return false;
    }
  }

  Future<bool> addQuestion(QuestionDraft draft) async {
    final quiz = state.quiz;
    if (quiz == null) return false; // il faut enregistrer le quiz d'abord

    emit(state.copyWith(saving: true, clearFailure: true));
    final result =
        await _repository.createQuestion(quizId: quiz.id, draft: draft);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            saving: false,
            questions: [...state.questions, value],
          ),
        );
        return true;
      case Err(:final failure):
        _emitFailure(failure);
        return false;
    }
  }

  Future<bool> editQuestion(String questionId, QuestionDraft draft) async {
    emit(state.copyWith(saving: true, clearFailure: true));
    final result = await _repository.updateQuestion(questionId, draft);
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            saving: false,
            questions: [
              for (final q in state.questions) q.id == questionId ? value : q,
            ],
          ),
        );
        return true;
      case Err(:final failure):
        _emitFailure(failure);
        return false;
    }
  }

  Future<bool> removeQuestion(String questionId) async {
    emit(state.copyWith(saving: true, clearFailure: true));
    final result = await _repository.deleteQuestion(questionId);
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            saving: false,
            questions: [
              for (final q in state.questions)
                if (q.id != questionId) q,
            ],
          ),
        );
        return true;
      case Err(:final failure):
        _emitFailure(failure);
        return false;
    }
  }

  /// Une erreur 422 avec détails par champ s'affiche sous les champs du quiz ;
  /// toute autre erreur est exposée comme message général.
  void _emitFailure(Failure failure, {bool fieldLevel = false}) {
    if (fieldLevel &&
        failure is ValidationFailure &&
        failure.fieldErrors.isNotEmpty) {
      emit(state.copyWith(saving: false, fieldErrors: failure.fieldErrors));
    } else {
      emit(state.copyWith(saving: false, failure: failure));
    }
  }
}
