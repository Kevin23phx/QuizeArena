import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quizarena/core/session/session_cubit.dart';
import 'package:quizarena/core/storage/token_storage.dart';

class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late MockTokenStorage storage;

  setUp(() => storage = MockTokenStorage());

  blocTest<SessionCubit, SessionState>(
    'restore : jetons + rôle présents -> authentifié',
    build: () {
      when(() => storage.readRefreshToken()).thenAnswer((_) async => 'r');
      when(() => storage.readRole()).thenAnswer((_) async => UserRole.teacher);
      return SessionCubit(storage);
    },
    act: (c) => c.restore(),
    expect: () => [const SessionAuthenticated(UserRole.teacher)],
  );

  blocTest<SessionCubit, SessionState>(
    'restore : rien en stockage -> non authentifié',
    build: () {
      when(() => storage.readRefreshToken()).thenAnswer((_) async => null);
      when(() => storage.readRole()).thenAnswer((_) async => null);
      return SessionCubit(storage);
    },
    act: (c) => c.restore(),
    expect: () => [const SessionUnauthenticated()],
  );

  blocTest<SessionCubit, SessionState>(
    'signedOut : vide le stockage puis non authentifié',
    build: () {
      when(() => storage.clear()).thenAnswer((_) async {});
      return SessionCubit(storage);
    },
    act: (c) => c.signedOut(),
    expect: () => [const SessionUnauthenticated()],
    verify: (_) => verify(() => storage.clear()).called(1),
  );
}
