import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'data/datasources/attempt_remote_data_source.dart';
import 'data/repositories/attempt_repository_impl.dart';
import 'domain/repositories/attempt_repository.dart';
import 'domain/usecases/get_attempt_use_case.dart';
import 'domain/usecases/start_attempt_use_case.dart';
import 'domain/usecases/submit_attempt_answer_use_case.dart';
import 'presentation/bloc/attempt_bloc.dart';

/// Enregistrement DI de la feature `attempts` (propriétaire : Membre 4).
///
/// Ordre conseillé : datasource -> repository (type du contrat domain) ->
/// usecases -> BLoC/Cubit en `registerFactory` (un état neuf par écran).
/// Dio, TokenStorage et SessionCubit sont déjà disponibles via `sl`.
void registerAttemptsModule(GetIt sl) {
  sl.registerLazySingleton<AttemptRemoteDataSource>(
    () => AttemptRemoteDataSource(sl<Dio>()),
  );
  sl.registerLazySingleton<AttemptRepository>(
    () => AttemptRepositoryImpl(sl<AttemptRemoteDataSource>()),
  );
  sl.registerLazySingleton<StartAttemptUseCase>(
    () => StartAttemptUseCase(sl<AttemptRepository>()),
  );
  sl.registerLazySingleton<GetAttemptUseCase>(
    () => GetAttemptUseCase(sl<AttemptRepository>()),
  );
  sl.registerLazySingleton<SubmitAttemptAnswerUseCase>(
    () => SubmitAttemptAnswerUseCase(sl<AttemptRepository>()),
  );
  sl.registerFactory<AttemptBloc>(
    () => AttemptBloc(
      sl<StartAttemptUseCase>(),
      sl<GetAttemptUseCase>(),
      sl<SubmitAttemptAnswerUseCase>(),
    ),
  );
}
