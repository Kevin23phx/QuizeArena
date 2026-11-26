import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quizarena/core/error/failure.dart';
import 'package:quizarena/core/session/session_cubit.dart';
import 'package:quizarena/core/storage/token_storage.dart';
import 'package:quizarena/features/auth/domain/entities/auth_session.dart';
import 'package:quizarena/features/auth/domain/entities/auth_user.dart';
import 'package:quizarena/features/auth/domain/repositories/auth_repository.dart';
import 'package:quizarena/features/auth/domain/usecases/login_usecase.dart';
import 'package:quizarena/features/auth/domain/usecases/logout_usecase.dart';
import 'package:quizarena/features/auth/domain/usecases/register_usecase.dart';
import 'package:quizarena/features/auth/presentation/cubit/auth_cubit.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late MockAuthRepository repository;
  late SessionCubit sessionCubit;

  setUp(() {
    repository = MockAuthRepository();
    sessionCubit = SessionCubit(MockTokenStorage());
  });

  tearDown(() => sessionCubit.close());

  AuthCubit buildCubit() => AuthCubit(
        loginUseCase: LoginUseCase(repository),
        registerUseCase: RegisterUseCase(repository),
        logoutUseCase: LogoutUseCase(repository),
        sessionCubit: sessionCubit,
      );

  blocTest<AuthCubit, AuthState>(
    'login réussit et authentifie la session',
    build: () {
      when(
        () => repository.login(
          email: 'student@example.com',
          password: 'secret',
        ),
      ).thenAnswer(
        (_) async => const AuthSession(
          accessToken: 'access',
          refreshToken: 'refresh',
          user: AuthUser(
            id: 'u1',
            name: 'Student',
            email: 'student@example.com',
            role: UserRole.student,
          ),
        ),
      );
      return buildCubit();
    },
    act: (cubit) => cubit.login(
      email: 'student@example.com',
      password: 'secret',
    ),
    expect: () => [const AuthLoading(), const AuthSuccess()],
  );

  blocTest<AuthCubit, AuthState>(
    'login échoue avec une erreur métier',
    build: () {
      when(
        () => repository.login(
          email: 'bad@example.com',
          password: 'wrong',
        ),
      ).thenThrow(const UnauthorizedFailure('Identifiants invalides.'));
      return buildCubit();
    },
    act: (cubit) => cubit.login(
      email: 'bad@example.com',
      password: 'wrong',
    ),
    expect: () => [
      const AuthLoading(),
      const AuthFailure(
        UnauthorizedFailure('Identifiants invalides.'),
      ),
    ],
  );

  blocTest<AuthCubit, AuthState>(
    'register réussit',
    build: () {
      when(
        () => repository.register(
          name: 'Student',
          email: 'student@example.com',
          password: 'secret',
        ),
      ).thenAnswer((_) async {});
      return buildCubit();
    },
    act: (cubit) => cubit.register(
      name: 'Student',
      email: 'student@example.com',
      password: 'secret',
    ),
    expect: () => [const AuthLoading(), const AuthSuccess()],
  );
}
