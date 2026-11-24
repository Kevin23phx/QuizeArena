import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';

import '../../features/attempts/attempts_module.dart';
import '../../features/auth/auth_module.dart';
import '../../features/courses/courses_module.dart';
import '../../features/leaderboard/leaderboard_module.dart';
import '../../features/quizzes/quizzes_module.dart';
import '../network/api_client.dart';
import '../router/app_router.dart';
import '../session/session_cubit.dart';
import '../storage/token_storage.dart';

final GetIt sl = GetIt.instance;

/// COMPOSITION ROOT UNIQUE de l'application.
///
/// Règle : c'est le SEUL endroit qui sait quelle implémentation concrète
/// satisfait chaque contrat. Les features ne s'enregistrent que dans leur
/// propre `<feature>_module.dart` (pas de conflit de merge ici).
///
/// `overrides` permet aux tests de remplacer des dépendances (ex. faux storage).
Future<void> configureDependencies({
  TokenStorage? tokenStorage,
  Dio? dio,
}) async {
  // --- core ---
  sl.registerLazySingleton<TokenStorage>(() => tokenStorage ?? SecureTokenStorage());

  sl.registerLazySingleton<SessionCubit>(() => SessionCubit(sl<TokenStorage>()));

  sl.registerLazySingleton<Dio>(
    () =>
        dio ??
        createApiClient(
          storage: sl<TokenStorage>(),
          onSessionExpired: () => sl<SessionCubit>().signedOut(),
        ),
  );

  sl.registerLazySingleton<GoRouter>(() => createRouter(sl<SessionCubit>()));

  // --- features (une ligne chacune, le contenu appartient au propriétaire) ---
  registerAuthModule(sl);
  registerCoursesModule(sl);
  registerQuizzesModule(sl);
  registerAttemptsModule(sl);
  registerLeaderboardModule(sl);
}

Future<void> resetDependencies() => sl.reset();
