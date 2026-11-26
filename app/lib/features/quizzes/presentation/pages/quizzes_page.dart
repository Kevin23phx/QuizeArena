import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quizarena/core/router/navigation.dart';
import 'package:quizarena/core/session/session_cubit.dart';
import 'package:quizarena/core/widgets/app_header.dart';

import 'quiz_list_view.dart';

/// Page autonome « Quiz du cours » (route /courses/:courseId/quizzes).
/// Le rôle vient de la session ; le serveur reste l'autorité sur les droits.
class QuizzesPage extends StatelessWidget {
  const QuizzesPage({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;

    return Scaffold(
      body: Column(
        children: [
          AppHeader(title: 'Quiz du cours', onBack: () => goBack(context)),
          Expanded(
            child: session is SessionAuthenticated
                ? QuizListView(courseId: courseId, role: session.role)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
