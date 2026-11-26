import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quizarena/core/di/service_locator.dart';
import 'package:quizarena/core/format.dart';
import 'package:quizarena/core/storage/token_storage.dart';
import 'package:quizarena/core/theme/app_theme.dart';
import 'package:quizarena/core/widgets/app_card.dart';
import 'package:quizarena/core/widgets/app_input.dart';
import 'package:quizarena/core/widgets/state_view.dart';
import 'package:quizarena/core/widgets/status_chip.dart';

import '../../domain/entities/quiz.dart';
import '../bloc/quizzes_bloc.dart';
import '../quiz_paths.dart';

/// Liste des quiz d'un cours, sans Scaffold : le membre 2 peut l'intégrer
/// telle quelle dans l'onglet « Quiz » du détail d'un cours.
///   QuizListView(courseId: course.id, role: role)
class QuizListView extends StatelessWidget {
  const QuizListView({super.key, required this.courseId, required this.role});

  final String courseId;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<QuizzesBloc>(
      create: (_) =>
          sl<QuizzesBloc>(param1: courseId)..add(const QuizzesStarted()),
      child: _Body(courseId: courseId, role: role),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.courseId, required this.role});

  final String courseId;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<QuizzesBloc>();
    final isTeacher = role == UserRole.teacher;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          TextField(
            textInputAction: TextInputAction.search,
            decoration: appInput('Rechercher un quiz')
                .copyWith(prefixIcon: const Icon(Icons.search)),
            onChanged: (value) => bloc.add(QuizzesSearchChanged(value.trim())),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BlocBuilder<QuizzesBloc, QuizzesState>(
              builder: (context, state) {
                return StateView(
                  status: state.status,
                  failure: state.failure,
                  onRetry: () => bloc.add(const QuizzesRefreshed()),
                  emptyMessage: state.query.isNotEmpty
                      ? 'Aucun résultat pour « ${state.query} ».'
                      : isTeacher
                          ? 'Aucun quiz. Créez le premier.'
                          : 'Aucun quiz disponible pour le moment.',
                  contentBuilder: (_) => _QuizList(state: state, role: role),
                );
              },
            ),
          ),
          if (isTeacher)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    await context.push<bool>(QuizPaths.create(courseId));
                    bloc.add(const QuizzesRefreshed());
                  },
                  child: const Text('+ Nouveau quiz'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuizList extends StatelessWidget {
  const _QuizList({required this.state, required this.role});

  final QuizzesState state;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<QuizzesBloc>();
    final extra = state.hasMore ? 1 : 0;

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: state.quizzes.length + extra,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index >= state.quizzes.length) {
          return Center(
            child: state.loadingMore
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  )
                : TextButton(
                    onPressed: () => bloc.add(const QuizzesNextPageRequested()),
                    child: const Text('Charger plus'),
                  ),
          );
        }
        return _QuizCard(quiz: state.quizzes[index], role: role);
      },
    );
  }
}

class _QuizCard extends StatelessWidget {
  const _QuizCard({required this.quiz, required this.role});

  final Quiz quiz;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final isTeacher = role == UserRole.teacher;
    final bloc = context.read<QuizzesBloc>();
    final closes = quiz.closesAt;

    return AppCard(
      onTap: () async {
        if (isTeacher) {
          await context.push<bool>(QuizPaths.edit(quiz.id));
          bloc.add(const QuizzesRefreshed());
        } else {
          await context.push<void>(QuizPaths.detail(quiz.id));
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  quiz.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
              if (isTeacher) ...[
                const SizedBox(width: 8),
                quiz.status == QuizStatus.published
                    ? const StatusChip.success('Publié')
                    : const StatusChip.neutral('Brouillon'),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${quiz.questionCount} questions · ${quiz.durationMinutes} min',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          if (closes != null) ...[
            const SizedBox(height: 2),
            Text(
              'Ouvert jusqu\'au ${formatDateTime(closes)}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }
}
