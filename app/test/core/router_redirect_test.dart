import 'package:flutter_test/flutter_test.dart';
import 'package:quizarena/core/router/app_router.dart';
import 'package:quizarena/core/session/session_cubit.dart';
import 'package:quizarena/core/storage/token_storage.dart';

void main() {
  group('redirectFor (garde d\'authentification)', () {
    test('session inconnue -> splash', () {
      expect(
        redirectFor(const SessionUnknown(), AppRoutes.home),
        AppRoutes.splash,
      );
      expect(redirectFor(const SessionUnknown(), AppRoutes.splash), isNull);
    });

    test('non connecté : route protégée -> login', () {
      expect(
        redirectFor(const SessionUnauthenticated(), AppRoutes.home),
        AppRoutes.login,
      );
      expect(
        redirectFor(const SessionUnauthenticated(), AppRoutes.login),
        isNull,
      );
      expect(
        redirectFor(const SessionUnauthenticated(), AppRoutes.register),
        isNull,
      );
    });

    test('connecté : pages publiques -> home, routes protégées autorisées', () {
      const session = SessionAuthenticated(UserRole.student);
      expect(redirectFor(session, AppRoutes.login), AppRoutes.home);
      expect(redirectFor(session, AppRoutes.register), AppRoutes.home);
      expect(redirectFor(session, AppRoutes.splash), AppRoutes.home);
      expect(redirectFor(session, AppRoutes.home), isNull);
    });
  });
}
