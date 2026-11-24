import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import '../session/session_cubit.dart';
import 'placeholder_pages.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const login = '/login';
  static const home = '/home';
}

/// Garde d'authentification : fonction PURE, donc testable sans widget.
/// Retourne la route vers laquelle rediriger, ou null pour laisser passer.
String? redirectFor(SessionState session, String location) {
  switch (session) {
    case SessionUnknown():
      return location == AppRoutes.splash ? null : AppRoutes.splash;
    case SessionUnauthenticated():
      // Seules les pages publiques sont accessibles sans session.
      return location == AppRoutes.login ? null : AppRoutes.login;
    case SessionAuthenticated():
      final onPublicPage =
          location == AppRoutes.login || location == AppRoutes.splash;
      return onPublicPage ? AppRoutes.home : null;
  }
}

GoRouter createRouter(SessionCubit session) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _CubitListenable(session),
    redirect: (context, state) => redirectFor(session.state, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, __) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginPlaceholderPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomePlaceholderPage(),
      ),
      // Chaque membre ajoute ici les routes de SA feature (une ligne par route)
      // ex. /courses, /courses/:id, /quizzes/:id ...
    ],
  );
}

/// Adapte le flux d'un Cubit en Listenable pour `refreshListenable`.
class _CubitListenable extends ChangeNotifier {
  _CubitListenable(SessionCubit cubit) {
    _sub = cubit.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<SessionState> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}
