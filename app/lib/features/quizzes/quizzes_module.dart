import 'package:get_it/get_it.dart';

/// Enregistrement DI de la feature `quizzes` (propriétaire : Membre 3).
///
/// Ordre conseillé : datasource -> repository (type du contrat domain) ->
/// usecases -> BLoC/Cubit en `registerFactory` (un état neuf par écran).
/// Dio, TokenStorage et SessionCubit sont déjà disponibles via `sl`.
void registerQuizzesModule(GetIt sl) {
  // TODO(Membre 3): sl.registerLazySingleton<...Repository>(() => ...RepositoryImpl(sl()));
  // TODO(Membre 3): sl.registerFactory(() => ...Bloc(sl()));
}
