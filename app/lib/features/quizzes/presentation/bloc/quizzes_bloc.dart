import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quizarena/core/bloc/transformers.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/error/result.dart';
import 'package:quizarena/core/widgets/state_view.dart';

import '../../domain/entities/quiz.dart';
import '../../domain/repositories/quiz_repository.dart';

// --- Événements ---

sealed class QuizzesEvent extends Equatable {
  const QuizzesEvent();

  @override
  List<Object?> get props => [];
}

/// Premier chargement de l'écran.
final class QuizzesStarted extends QuizzesEvent {
  const QuizzesStarted();
}

/// Rechargement explicite (bouton Réessayer, retour de l'éditeur).
final class QuizzesRefreshed extends QuizzesEvent {
  const QuizzesRefreshed();
}

final class QuizzesSearchChanged extends QuizzesEvent {
  const QuizzesSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

final class QuizzesNextPageRequested extends QuizzesEvent {
  const QuizzesNextPageRequested();
}

// --- État ---

class QuizzesState extends Equatable {
  const QuizzesState({
    this.status = ViewStatus.loading,
    this.quizzes = const [],
    this.query = '',
    this.page = 1,
    this.hasMore = false,
    this.loadingMore = false,
    this.failure,
  });

  final ViewStatus status;
  final List<Quiz> quizzes;
  final String query;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final Failure? failure;

  QuizzesState copyWith({
    ViewStatus? status,
    List<Quiz>? quizzes,
    String? query,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    Failure? failure,
    bool clearFailure = false,
  }) {
    return QuizzesState(
      status: status ?? this.status,
      quizzes: quizzes ?? this.quizzes,
      query: query ?? this.query,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props =>
      [status, quizzes, query, page, hasMore, loadingMore, failure];
}

// --- BLoC ---

/// Liste paginée des quiz d'un cours, avec recherche.
///
/// Transformers choisis :
/// - recherche : debounce 400 ms + switchMap (pas une requête par frappe ; une
///   réponse tardive ne remplace pas la plus récente) ;
/// - chargement / rafraîchissement : restartable (le dernier gagne) ;
/// - page suivante : droppable (un double appui ne charge pas deux fois).
class QuizzesBloc extends Bloc<QuizzesEvent, QuizzesState> {
  QuizzesBloc(this._repository, {required this.courseId})
      : super(const QuizzesState()) {
    on<QuizzesStarted>(_onReload, transformer: restartable());
    on<QuizzesRefreshed>(_onReload, transformer: restartable());
    on<QuizzesSearchChanged>(
      _onSearch,
      transformer: debounceRestartable(searchDebounce),
    );
    on<QuizzesNextPageRequested>(_onNextPage, transformer: droppable());
  }

  static const pageSize = 20;
  static const searchDebounce = Duration(milliseconds: 400);

  final QuizRepository _repository;
  final String courseId;

  Future<void> _onReload(QuizzesEvent event, Emitter<QuizzesState> emit) =>
      _fetchFirstPage(emit, query: state.query);

  Future<void> _onSearch(
    QuizzesSearchChanged event,
    Emitter<QuizzesState> emit,
  ) =>
      _fetchFirstPage(emit, query: event.query);

  Future<void> _fetchFirstPage(
    Emitter<QuizzesState> emit, {
    required String query,
  }) async {
    emit(
      state.copyWith(
        status: ViewStatus.loading,
        query: query,
        clearFailure: true,
      ),
    );

    final result = await _repository.listQuizzes(
      courseId: courseId,
      page: 1,
      limit: pageSize,
      query: query.isEmpty ? null : query,
    );

    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: value.items.isEmpty ? ViewStatus.empty : ViewStatus.content,
            quizzes: value.items,
            page: value.page,
            hasMore: value.hasMore,
            loadingMore: false,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(status: ViewStatus.error, failure: failure));
    }
  }

  Future<void> _onNextPage(
    QuizzesNextPageRequested event,
    Emitter<QuizzesState> emit,
  ) async {
    if (!state.hasMore ||
        state.loadingMore ||
        state.status != ViewStatus.content) {
      return;
    }
    emit(state.copyWith(loadingMore: true));

    final result = await _repository.listQuizzes(
      courseId: courseId,
      page: state.page + 1,
      limit: pageSize,
      query: state.query.isEmpty ? null : state.query,
    );

    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            quizzes: [...state.quizzes, ...value.items],
            page: value.page,
            hasMore: value.hasMore,
            loadingMore: false,
          ),
        );
      case Err():
        emit(state.copyWith(loadingMore: false));
    }
  }
}
