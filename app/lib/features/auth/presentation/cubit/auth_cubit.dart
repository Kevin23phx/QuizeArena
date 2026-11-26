import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/session/session_cubit.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/register_usecase.dart';

sealed class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

final class AuthInitial extends AuthState {
  const AuthInitial();
}

final class AuthLoading extends AuthState {
  const AuthLoading();
}

final class AuthSuccess extends AuthState {
  const AuthSuccess();
}

final class AuthFailure extends AuthState {
  const AuthFailure(this.failure);

  final Failure failure;

  @override
  List<Object?> get props => [failure];
}

final class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required LoginUseCase loginUseCase,
    required RegisterUseCase registerUseCase,
    required LogoutUseCase logoutUseCase,
    required SessionCubit sessionCubit,
  })  : _loginUseCase = loginUseCase,
        _registerUseCase = registerUseCase,
        _logoutUseCase = logoutUseCase,
        _sessionCubit = sessionCubit,
        super(const AuthInitial());

  final LoginUseCase _loginUseCase;
  final RegisterUseCase _registerUseCase;
  final LogoutUseCase _logoutUseCase;
  final SessionCubit _sessionCubit;

  Future<void> login({required String email, required String password}) async {
    emit(const AuthLoading());
    try {
      final session = await _loginUseCase(email: email, password: password);
      _sessionCubit.signedIn(session.user.role);
      emit(const AuthSuccess());
    } on Failure catch (failure) {
      emit(AuthFailure(failure));
    } catch (_) {
      emit(const AuthFailure(UnknownFailure()));
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    emit(const AuthLoading());
    try {
      await _registerUseCase(name: name, email: email, password: password);
      emit(const AuthSuccess());
    } on Failure catch (failure) {
      emit(AuthFailure(failure));
    } catch (_) {
      emit(const AuthFailure(UnknownFailure()));
    }
  }

  Future<void> logout() async {
    await _logoutUseCase();
    await _sessionCubit.signedOut();
  }
}
