import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quizarena/core/di/service_locator.dart';
import 'package:quizarena/core/format.dart';
import 'package:quizarena/core/router/navigation.dart';
import 'package:quizarena/core/theme/app_theme.dart';
import 'package:quizarena/core/widgets/app_card.dart';
import 'package:quizarena/core/widgets/app_header.dart';
import 'package:quizarena/core/widgets/state_view.dart';

import '../../domain/entities/quiz.dart';
import '../bloc/quiz_detail_cubit.dart';

/// Détail d'un quiz côté étudiant. Aucune question ni bonne réponse ici.
class QuizDetailPage extends StatelessWidget {
  const QuizDetailPage({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<QuizDetailCubit>(
      create: (_) => sl<QuizDetailCubit>(param1: quizId)..load(),
      child: Scaffold(
        body: Column(
          children: [
            AppHeader(title: 'Détail du quiz', onBack: () => goBack(context)),
            Expanded(
              child: BlocBuilder<QuizDetailCubit, QuizDetailState>(
                builder: (context, state) {
                  return StateView(
                    status: state.status,
                    failure: state.failure,
                    onRetry: () => context.read<QuizDetailCubit>().load(),
                    contentBuilder: (_) => _Content(quiz: state.quiz!),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.quiz});

  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    final opens = quiz.opensAt;
    final closes = quiz.closesAt;
    final open = quiz.isOpenAt(DateTime.now());

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: AppColors.accent,
            padding: const EdgeInsets.all(20),
            child: Text(
              quiz.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Column(
              children: [
                _Row('Questions', '${quiz.questionCount}'),
                _Row('Durée', '${quiz.durationMinutes} min'),
                if (opens != null) _Row('Ouvre le', formatDateTime(opens)),
                if (closes != null) _Row('Ferme le', formatDateTime(closes)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const AppCard(
            color: AppColors.primarySoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.schedule, color: AppColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Une fois démarré, le minuteur tourne côté serveur. '
                    'Fermer l\'application ne l\'arrête pas.',
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton(
            // Désactivé hors fenêtre d'ouverture : simple confort d'affichage,
            // le serveur refusera de toute façon un démarrage non autorisé.
            onPressed: open ? () => _start(context) : null,
            child: Text(open ? 'Démarrer le quiz' : 'Quiz non disponible'),
          ),
        ],
      ),
    );
  }

  void _start(BuildContext context) {
    // TODO(Membre 4): ouvrir l'écran de passation de la feature `attempts`.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('La passation sera branchée avec la feature attempts.'),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
