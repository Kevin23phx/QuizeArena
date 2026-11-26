import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/error/result.dart';
import 'package:quizarena/core/widgets/state_view.dart';

import '../../domain/entities/quiz.dart';
import '../../domain/repositories/quiz_repository.dart';

class QuizDetailState extends Equatable {
  const QuizDetailState({
    this.status = ViewStatus.loading,
    this.quiz,
    this.failure,
  });

  final ViewStatus status;
  final Quiz? quiz;
  final Failure? failure;

  @override
  List<Object?> get props => [status, quiz, failure];
}

/// Détail d'un quiz côté étudiant. Ne charge jamais les questions : elles
/// n'arrivent qu'au démarrage d'une tentative (feature `attempts`).
class QuizDetailCubit extends Cubit<QuizDetailState> {
  QuizDetailCubit(this._repository, this._quizId)
      : super(const QuizDetailState());

  final QuizRepository _repository;
  final String _quizId;

  Future<void> load() async {
    emit(const QuizDetailState());
    final result = await _repository.getQuiz(_quizId);
    switch (result) {
      case Ok(:final value):
        emit(QuizDetailState(status: ViewStatus.content, quiz: value));
      case Err(:final failure):
        emit(QuizDetailState(status: ViewStatus.error, failure: failure));
    }
  }
}
