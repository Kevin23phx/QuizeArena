import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quizarena/core/di/service_locator.dart';
import 'package:quizarena/core/router/navigation.dart';
import 'package:quizarena/core/theme/app_theme.dart';
import 'package:quizarena/core/widgets/app_card.dart';
import 'package:quizarena/core/widgets/app_header.dart';
import 'package:quizarena/core/widgets/state_view.dart';
import 'package:quizarena/core/widgets/status_chip.dart';

import '../../domain/entities/attempt.dart';
import '../bloc/attempt_bloc.dart';

class AttemptResultPage extends StatelessWidget {
  const AttemptResultPage({super.key, required this.attemptId});

  final String attemptId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AttemptBloc>(
      create: (_) => sl<AttemptBloc>()..add(AttemptReloaded(attemptId)),
      child: Scaffold(
        body: Column(
          children: [
            AppHeader(title: 'Résultat du quiz', onBack: () => goBack(context)),
            Expanded(
              child: BlocBuilder<AttemptBloc, AttemptState>(
                builder: (context, state) => StateView(
                  status: state.status,
                  failure: state.failure,
                  onRetry: () => context
                      .read<AttemptBloc>()
                      .add(AttemptReloaded(attemptId)),
                  contentBuilder: (_) => _ResultContent(state: state),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({required this.state});

  final AttemptState state;

  @override
  Widget build(BuildContext context) {
    final attempt = state.attempt!;
    if (!attempt.isCompleted) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: AppCard(child: Text("La tentative n'est pas terminée.")),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppCard(
            color: AppColors.primarySoft,
            child: Column(
              children: [
                const StatusChip.success('Terminée'),
                const SizedBox(height: 12),
                Text(
                  'Note : ${attempt.finalScore} / ${attempt.totalPoints}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < attempt.answers.length; index++) ...[
            _AnswerCard(
              number: index + 1,
              answer: attempt.answers[index],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({required this.number, required this.answer});

  final int number;
  final AttemptAnswer answer;

  @override
  Widget build(BuildContext context) {
    final label = answer.wasSkipped
        ? 'Sans réponse'
        : answer.isCorrect
            ? 'Juste'
            : 'Faux';
    final chip = answer.wasSkipped || !answer.isCorrect
        ? StatusChip.neutral(label)
        : StatusChip.success(label);

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Question $number',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Text('${answer.pointsEarned} pt'),
          const SizedBox(width: 12),
          chip,
        ],
      ),
    );
  }
}
