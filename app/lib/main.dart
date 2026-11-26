import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'core/di/injection.dart';
import 'core/session/session_cubit.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  // Lit le stockage sécurisé puis débloque le router (SessionUnknown -> ...).
  await sl<SessionCubit>().restore();
  runApp(const QuizArenaApp());
}

class QuizArenaApp extends StatelessWidget {
  const QuizArenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SessionCubit>.value(
      value: sl<SessionCubit>(),
      child: MaterialApp.router(
        title: 'QuizArena',
        theme: buildAppTheme(),
        routerConfig: sl<GoRouter>(),
      ),
    );
  }
}
