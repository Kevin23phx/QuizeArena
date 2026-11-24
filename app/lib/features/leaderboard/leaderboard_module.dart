import 'package:get_it/get_it.dart';

/// Enregistrement DI de la feature `leaderboard` (propriétaire : Membre 4).
///
/// Ordre conseillé : datasource -> repository (type du contrat domain) ->
/// usecases -> BLoC/Cubit en `registerFactory` (un état neuf par écran).
/// Dio, TokenStorage et SessionCubit sont déjà disponibles via `sl`.
void registerLeaderboardModule(GetIt sl) {
  // TODO(Membre 4): sl.registerLazySingleton<...Repository>(() => ...RepositoryImpl(sl()));
  // TODO(Membre 4): sl.registerFactory(() => ...Bloc(sl()));
}
