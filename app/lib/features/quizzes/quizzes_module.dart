import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';

import 'data/datasources/quiz_remote_datasource.dart';
import 'data/repositories/in_memory_quiz_repository.dart';
import 'data/repositories/quiz_repository_impl.dart';
import 'domain/repositories/quiz_repository.dart';
import 'presentation/bloc/quiz_detail_cubit.dart';
import 'presentation/bloc/quiz_editor_cubit.dart';
import 'presentation/bloc/quizzes_bloc.dart';

/// Données de démonstration, sans API :
///   flutter run --dart-define=USE_FAKE_DATA=true
const _useFakeData = bool.fromEnvironment('USE_FAKE_DATA');

/// Enregistrement DI de la feature `quizzes` (propriétaire : Membre 3).
void registerQuizzesModule(GetIt sl) {
  // Le type enregistré est le CONTRAT du domaine, jamais l'implémentation.
  sl.registerLazySingleton<QuizRepository>(
    () => _useFakeData
        ? InMemoryQuizRepository()
        : QuizRepositoryImpl(QuizRemoteDataSource(sl<Dio>())),
  );

  // BLoC / Cubit en factory : un état neuf à chaque écran.
  sl.registerFactoryParam<QuizzesBloc, String, void>(
    (courseId, _) => QuizzesBloc(sl<QuizRepository>(), courseId: courseId),
  );
  sl.registerFactoryParam<QuizDetailCubit, String, void>(
    (quizId, _) => QuizDetailCubit(sl<QuizRepository>(), quizId),
  );
  sl.registerFactoryParam<QuizEditorCubit, QuizEditorArgs, void>(
    (args, _) => QuizEditorCubit(sl<QuizRepository>(), args),
  );
}
