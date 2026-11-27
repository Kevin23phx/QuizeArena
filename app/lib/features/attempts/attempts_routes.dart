import 'package:go_router/go_router.dart';

import 'attempt_paths.dart';
import 'presentation/pages/attempt_page.dart';
import 'presentation/pages/attempt_result_page.dart';

final List<RouteBase> attemptsRoutes = [
  GoRoute(
    path: AttemptPaths.playPattern,
    builder: (_, state) => AttemptPage(quizId: state.pathParameters['quizId']!),
  ),
  GoRoute(
    path: AttemptPaths.resultPattern,
    builder: (_, state) =>
        AttemptResultPage(attemptId: state.pathParameters['attemptId']!),
  ),
];
