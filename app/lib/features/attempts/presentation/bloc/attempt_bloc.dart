import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/widgets/state_view.dart';
import '../../domain/entities/attempt.dart';
import '../../domain/usecases/get_attempt_use_case.dart';
import '../../domain/usecases/start_attempt_use_case.dart';
import '../../domain/usecases/submit_attempt_answer_use_case.dart';

class AttemptState extends Equatable {
  const AttemptState({
    this.status = ViewStatus.loading,
    this.submitting = false,
    this.attempt,
    this.failure,
    this.countdownRemaining,
  });

  final ViewStatus status;
  final bool submitting;
  final Attempt? attempt;
  final Failure? failure;
  final Duration? countdownRemaining;

  @override
  List<Object?> get props => [
        status,
        submitting,
        attempt,
        failure,
        countdownRemaining,
      ];
}

sealed class AttemptEvent extends Equatable {
  const AttemptEvent();

  @override
  List<Object?> get props => [];
}

final class AttemptStarted extends AttemptEvent {
  const AttemptStarted(this.quizId);

  final String quizId;

  @override
  List<Object?> get props => [quizId];
}

final class AnswerSubmitted extends AttemptEvent {
  const AnswerSubmitted(this.questionId, this.selectedOptionIndex);

  final String questionId;
  final int selectedOptionIndex;

  @override
  List<Object?> get props => [questionId, selectedOptionIndex];
}

final class TimeElapsed extends AttemptEvent {
  const TimeElapsed();
}

final class AttemptReloaded extends AttemptEvent {
  const AttemptReloaded([this.attemptId]);

  final String? attemptId;

  @override
  List<Object?> get props => [attemptId];
}

final class _CountdownTick extends AttemptEvent {
  const _CountdownTick(this.remaining);

  final Duration remaining;

  @override
  List<Object?> get props => [remaining];
}

class AttemptBloc extends Bloc<AttemptEvent, AttemptState> {
  AttemptBloc(
    this._startAttempt,
    this._getAttempt,
    this._submitAttemptAnswer,
  ) : super(const AttemptState()) {
    on<AttemptStarted>(_onStarted);
    on<AnswerSubmitted>(
      _onAnswerSubmitted,
      transformer: droppable(),
    );
    on<TimeElapsed>(_onTimeElapsed);
    on<AttemptReloaded>(_onReloaded);
    on<_CountdownTick>(_onCountdownTick);
  }

  final StartAttemptUseCase _startAttempt;
  final GetAttemptUseCase _getAttempt;
  final SubmitAttemptAnswerUseCase _submitAttemptAnswer;

  Timer? _countdownTimer;
  Stopwatch? _stopwatch;
  Duration? _remainingAtReceipt;
  String? _activeAttemptId;
  bool _expirationSent = false;
  bool _expirationReloadInProgress = false;

  Future<void> _onStarted(
    AttemptStarted event,
    Emitter<AttemptState> emit,
  ) async {
    _stopCountdown();
    _activeAttemptId = null;
    emit(const AttemptState(status: ViewStatus.loading));
    final result = await _startAttempt.call(event.quizId);
    switch (result) {
      case Ok(:final value):
        _publishAttempt(value, emit);
      case Err(:final failure):
        emit(AttemptState(status: ViewStatus.error, failure: failure));
    }
  }

  Future<void> _onAnswerSubmitted(
    AnswerSubmitted event,
    Emitter<AttemptState> emit,
  ) async {
    final attempt = state.attempt;
    if (attempt == null || !attempt.isInProgress || state.submitting) return;

    _stopCountdown();
    emit(
      AttemptState(
        status: ViewStatus.content,
        submitting: true,
        attempt: attempt,
        countdownRemaining: state.countdownRemaining,
      ),
    );

    final result = await _submitAttemptAnswer.call(
      attemptId: attempt.id,
      questionId: event.questionId,
      selectedOptionIndex: event.selectedOptionIndex,
    );
    switch (result) {
      case Ok(:final value):
        _publishAttempt(value, emit);
      case Err(failure: ConflictFailure()):
        await _fetchAttempt(attempt.id, emit);
      case Err(:final failure):
        emit(
          AttemptState(
            status: ViewStatus.error,
            attempt: attempt,
            failure: failure,
          ),
        );
    }
  }

  Future<void> _onTimeElapsed(
    TimeElapsed event,
    Emitter<AttemptState> emit,
  ) async {
    final attempt = state.attempt;
    if (attempt == null || state.submitting || _expirationReloadInProgress) {
      return;
    }
    _expirationReloadInProgress = true;
    try {
      await _fetchAttempt(attempt.id, emit);
    } finally {
      _expirationReloadInProgress = false;
    }
  }

  Future<void> _onReloaded(
    AttemptReloaded event,
    Emitter<AttemptState> emit,
  ) async {
    final attemptId = event.attemptId ?? state.attempt?.id ?? _activeAttemptId;
    if (attemptId == null) {
      emit(
        const AttemptState(
          status: ViewStatus.error,
          failure: NotFoundFailure('Tentative introuvable.'),
        ),
      );
      return;
    }
    await _fetchAttempt(attemptId, emit);
  }

  Future<void> _fetchAttempt(
    String attemptId,
    Emitter<AttemptState> emit,
  ) async {
    _stopCountdown();
    emit(const AttemptState(status: ViewStatus.loading));
    final result = await _getAttempt.call(attemptId);
    switch (result) {
      case Ok(:final value):
        _publishAttempt(value, emit);
      case Err(:final failure):
        emit(AttemptState(status: ViewStatus.error, failure: failure));
    }
  }

  void _publishAttempt(Attempt attempt, Emitter<AttemptState> emit) {
    _stopCountdown();
    _activeAttemptId = attempt.id;
    _expirationSent = false;
    final remaining =
        attempt.isInProgress ? attempt.remainingWhenReceived : null;
    emit(
      AttemptState(
        status: ViewStatus.content,
        attempt: attempt,
        countdownRemaining: remaining,
      ),
    );
    if (remaining != null) _startCountdown(remaining);
  }

  void _startCountdown(Duration remaining) {
    _remainingAtReceipt = remaining;
    _stopwatch = Stopwatch()..start();
    if (remaining <= Duration.zero) {
      _expireOnce();
      return;
    }
    _countdownTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        final stopwatch = _stopwatch;
        final receivedRemaining = _remainingAtReceipt;
        if (stopwatch == null || receivedRemaining == null) return;
        final current = receivedRemaining - stopwatch.elapsed;
        if (current <= Duration.zero) {
          _expireOnce();
        } else {
          add(_CountdownTick(current));
        }
      },
    );
  }

  void _expireOnce() {
    if (_expirationSent) return;
    _expirationSent = true;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _stopwatch?.stop();
    add(const TimeElapsed());
  }

  void _onCountdownTick(
    _CountdownTick event,
    Emitter<AttemptState> emit,
  ) {
    if (state.status != ViewStatus.content ||
        state.submitting ||
        state.attempt?.isInProgress != true) {
      return;
    }
    emit(
      AttemptState(
        status: state.status,
        submitting: state.submitting,
        attempt: state.attempt,
        failure: state.failure,
        countdownRemaining: event.remaining,
      ),
    );
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _stopwatch?.stop();
    _stopwatch = null;
    _remainingAtReceipt = null;
  }

  @override
  Future<void> close() {
    _stopCountdown();
    return super.close();
  }
}
