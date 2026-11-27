import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quizarena/core/di/service_locator.dart';
import 'package:quizarena/core/router/navigation.dart';
import 'package:quizarena/core/theme/app_theme.dart';
import 'package:quizarena/core/widgets/app_card.dart';
import 'package:quizarena/core/widgets/app_header.dart';
import 'package:quizarena/core/widgets/state_view.dart';
import 'package:quizarena/core/widgets/status_chip.dart';

import '../../attempt_paths.dart';
import '../bloc/attempt_bloc.dart';

class AttemptPage extends StatelessWidget {
  const AttemptPage({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AttemptBloc>(
      create: (_) => sl<AttemptBloc>()..add(AttemptStarted(quizId)),
      child: BlocListener<AttemptBloc, AttemptState>(
        listenWhen: (previous, current) =>
            current.status == ViewStatus.content &&
            current.attempt?.isCompleted == true &&
            previous.attempt?.isCompleted != true,
        listener: (context, state) {
          final attempt = state.attempt;
          if (attempt != null) {
            context.go(AttemptPaths.result(attempt.id));
          }
        },
        child: Scaffold(
          body: Column(
            children: [
              AppHeader(
                title: 'Passation du quiz',
                onBack: () => goBack(context),
              ),
              Expanded(
                child: BlocBuilder<AttemptBloc, AttemptState>(
                  builder: (context, state) => StateView(
                    status: state.status,
                    failure: state.failure,
                    onRetry: () {
                      final bloc = context.read<AttemptBloc>();
                      if (state.attempt == null) {
                        bloc.add(AttemptStarted(quizId));
                      } else {
                        bloc.add(const AttemptReloaded());
                      }
                    },
                    contentBuilder: (_) => _AttemptContent(state: state),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AttemptContent extends StatefulWidget {
  const _AttemptContent({required this.state});

  final AttemptState state;

  @override
  State<_AttemptContent> createState() => _AttemptContentState();
}

class _AttemptContentState extends State<_AttemptContent> {
  int? _selectedOptionIndex;
  String? _questionId;

  @override
  void initState() {
    super.initState();
    _questionId = widget.state.attempt?.currentQuestion?.id;
  }

  @override
  void didUpdateWidget(covariant _AttemptContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final questionId = widget.state.attempt?.currentQuestion?.id;
    if (questionId != _questionId) {
      _questionId = questionId;
      _selectedOptionIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final attempt = widget.state.attempt!;
    final question = attempt.currentQuestion!;
    final remaining = widget.state.countdownRemaining;
    final seconds = remaining == null
        ? '--'
        : ((remaining.inMilliseconds + 999) ~/ 1000).toString();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${question.position + 1} / ${question.totalQuestions}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const StatusChip.neutral('En cours'),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.accent,
            child: Text(
              question.prompt,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.timer_outlined),
                const SizedBox(width: 8),
                Text(
                  '$seconds s',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < question.options.length; index++) ...[
            AppCard(
              onTap: widget.state.submitting
                  ? null
                  : () => setState(() => _selectedOptionIndex = index),
              child: Row(
                children: [
                  Icon(
                    _selectedOptionIndex == index
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(question.options[index])),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _selectedOptionIndex == null || widget.state.submitting
                ? null
                : () => context.read<AttemptBloc>().add(
                      AnswerSubmitted(
                        question.id,
                        _selectedOptionIndex!,
                      ),
                    ),
            child: widget.state.submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Valider la réponse'),
          ),
        ],
      ),
    );
  }
}
