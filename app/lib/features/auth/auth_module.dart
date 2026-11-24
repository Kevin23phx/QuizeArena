import 'package:get_it/get_it.dart';

/// Enregistrement DI de la feature `auth` (propriétaire : Membre 1).
///
/// Ordre conseillé : datasource -> repository (type du contrat domain) ->
/// usecases -> BLoC/Cubit en `registerFactory` (un état neuf par écran).
/// Dio, TokenStorage et SessionCubit sont déjà disponibles via `sl`.
void registerAuthModule(GetIt sl) {
  // TODO(Membre 1): sl.registerLazySingleton<...Repository>(() => ...RepositoryImpl(sl()));
  // TODO(Membre 1): sl.registerFactory(() => ...Bloc(sl()));
}
