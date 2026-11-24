import 'package:get_it/get_it.dart';

/// Enregistrement DI de la feature `courses` (propriétaire : Membre 2).
///
/// Ordre conseillé : datasource -> repository (type du contrat domain) ->
/// usecases -> BLoC/Cubit en `registerFactory` (un état neuf par écran).
/// Dio, TokenStorage et SessionCubit sont déjà disponibles via `sl`.
void registerCoursesModule(GetIt sl) {
  // TODO(Membre 2): sl.registerLazySingleton<...Repository>(() => ...RepositoryImpl(sl()));
  // TODO(Membre 2): sl.registerFactory(() => ...Bloc(sl()));
}
