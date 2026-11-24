import 'package:flutter/material.dart';

import '../error/failure.dart';

enum ViewStatus { loading, empty, error, content }

/// Widget commun pour TOUT écran qui charge des données : il impose les
/// 4 états exigés (chargement, vide, erreur avec reprise, contenu).
///
/// Usage typique dans un BlocBuilder :
///   StateView(
///     status: state.status,
///     failure: state.failure,
///     onRetry: () => bloc.add(QuizzesRequested()),
///     emptyMessage: 'Aucun quiz pour le moment',
///     contentBuilder: (_) => QuizList(quizzes: state.quizzes),
///   )
class StateView extends StatelessWidget {
  const StateView({
    super.key,
    required this.status,
    required this.contentBuilder,
    this.failure,
    this.onRetry,
    this.emptyMessage = 'Rien à afficher pour le moment.',
  });

  final ViewStatus status;
  final WidgetBuilder contentBuilder;
  final Failure? failure;
  final VoidCallback? onRetry;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ViewStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case ViewStatus.empty:
        return Center(child: Text(emptyMessage, textAlign: TextAlign.center));
      case ViewStatus.error:
        return _ErrorView(
          message: failure?.message ?? 'Une erreur est survenue.',
          onRetry: onRetry,
        );
      case ViewStatus.content:
        return contentBuilder(context);
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
