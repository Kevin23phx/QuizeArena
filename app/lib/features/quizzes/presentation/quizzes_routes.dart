import 'package:go_router/go_router.dart';

import 'pages/quiz_detail_page.dart';
import 'pages/quiz_editor_page.dart';
import 'pages/quizzes_page.dart';
import 'quiz_paths.dart';

/// Routes de la feature quizzes, ajoutées dans app_router.dart (`...quizzesRoutes`).
/// Toutes sont protégées par la garde d'authentification du router.
final List<RouteBase> quizzesRoutes = [
  GoRoute(
    path: QuizPaths.listPattern,
    builder: (_, state) =>
        QuizzesPage(courseId: state.pathParameters['courseId']!),
  ),
  GoRoute(
    path: QuizPaths.createPattern,
    builder: (_, state) =>
        QuizEditorPage(courseId: state.pathParameters['courseId']),
  ),
  GoRoute(
    path: QuizPaths.detailPattern,
    builder: (_, state) =>
        QuizDetailPage(quizId: state.pathParameters['quizId']!),
  ),
  GoRoute(
    path: QuizPaths.editPattern,
    builder: (_, state) =>
        QuizEditorPage(quizId: state.pathParameters['quizId']),
  ),
];
