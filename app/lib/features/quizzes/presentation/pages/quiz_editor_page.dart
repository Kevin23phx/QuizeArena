import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quizarena/core/di/service_locator.dart';
import 'package:quizarena/core/format.dart';
import 'package:quizarena/core/router/navigation.dart';
import 'package:quizarena/core/session/session_cubit.dart';
import 'package:quizarena/core/storage/token_storage.dart';
import 'package:quizarena/core/theme/app_theme.dart';
import 'package:quizarena/core/widgets/app_card.dart';
import 'package:quizarena/core/widgets/app_header.dart';
import 'package:quizarena/core/widgets/app_input.dart';
import 'package:quizarena/core/widgets/state_view.dart';

import '../../domain/entities/question.dart';
import '../../domain/entities/quiz.dart';
import '../bloc/quiz_editor_cubit.dart';
import 'question_form_sheet.dart';

/// Éditeur de quiz (enseignant) : création si `quizId` est nul, sinon modification.
class QuizEditorPage extends StatelessWidget {
  const QuizEditorPage({super.key, this.courseId, this.quizId});

  final String? courseId;
  final String? quizId;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionCubit>().state;
    final isTeacher =
        session is SessionAuthenticated && session.role == UserRole.teacher;

    // Confort d'interface seulement : le serveur refuse (403) tout non-enseignant.
    if (!isTeacher) {
      return Scaffold(
        body: Column(
          children: [
            AppHeader(title: 'Accès refusé', onBack: () => goBack(context)),
            const Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Cet écran est réservé aux enseignants.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return BlocProvider<QuizEditorCubit>(
      create: (_) => sl<QuizEditorCubit>(
        param1: QuizEditorArgs(courseId: courseId, quizId: quizId),
      )..load(),
      child: _EditorView(isEdit: quizId != null),
    );
  }
}

class _EditorView extends StatefulWidget {
  const _EditorView({required this.isEdit});

  final bool isEdit;

  @override
  State<_EditorView> createState() => _EditorViewState();
}

class _EditorViewState extends State<_EditorView> {
  final _title = TextEditingController();
  final _duration = TextEditingController(text: '20');
  DateTime? _opensAt;
  DateTime? _closesAt;

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    super.dispose();
  }

  /// Recopie le quiz renvoyé par le serveur dans le formulaire.
  void _fill(Quiz quiz) {
    if (_title.text != quiz.title) _title.text = quiz.title;
    final duration = quiz.durationMinutes.toString();
    if (_duration.text != duration) _duration.text = duration;
    setState(() {
      _opensAt = quiz.opensAt;
      _closesAt = quiz.closesAt;
    });
  }

  QuizDraft _draft(QuizStatus status) {
    return QuizDraft(
      title: _title.text.trim(),
      durationMinutes: int.tryParse(_duration.text.trim()) ?? 0,
      status: status,
      opensAt: _opensAt,
      closesAt: _closesAt,
    );
  }

  Future<void> _save(QuizEditorCubit cubit, {required bool publish}) async {
    final status = publish
        ? QuizStatus.published
        : (cubit.state.quiz?.status ?? QuizStatus.draft);
    final ok = await cubit.save(_draft(status));
    if (!mounted || !ok) return;

    if (publish) {
      goBack(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quiz enregistré.')),
      );
    }
  }

  Future<void> _delete(QuizEditorCubit cubit) async {
    final confirmed = await _confirm(
      'Supprimer ce quiz ?',
      'Le quiz et ses questions seront supprimés.',
    );
    if (confirmed != true) return;
    final ok = await cubit.deleteQuiz();
    if (!mounted || !ok) return;
    goBack(context);
  }

  Future<void> _addQuestion(QuizEditorCubit cubit) async {
    final draft = await showQuestionSheet(context);
    if (draft == null) return;
    await cubit.addQuestion(draft);
  }

  Future<void> _editQuestion(QuizEditorCubit cubit, Question q) async {
    final draft = await showQuestionSheet(context, initial: q);
    if (draft == null) return;
    await cubit.editQuestion(q.id, draft);
  }

  Future<void> _removeQuestion(QuizEditorCubit cubit, Question q) async {
    final confirmed = await _confirm(
      'Supprimer cette question ?',
      q.text,
    );
    if (confirmed != true) return;
    await cubit.removeQuestion(q.id);
  }

  Future<bool?> _confirm(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _pick({required bool opens}) async {
    final value = await _pickDateTime(opens ? _opensAt : _closesAt);
    if (value == null || !mounted) return;
    setState(() {
      if (opens) {
        _opensAt = value;
      } else {
        _closesAt = value;
      }
    });
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? now),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: widget.isEdit ? 'Modifier le quiz' : 'Nouveau quiz',
            onBack: () => goBack(context),
          ),
          Expanded(
            child: BlocListener<QuizEditorCubit, QuizEditorState>(
              listenWhen: (previous, current) =>
                  current.quiz != null && previous.quiz != current.quiz,
              listener: (context, state) => _fill(state.quiz!),
              child: BlocConsumer<QuizEditorCubit, QuizEditorState>(
                listenWhen: (previous, current) =>
                    current.status == EditorStatus.ready &&
                    current.failure != null &&
                    current.failure != previous.failure,
                listener: (context, state) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(state.failure!.message)),
                  );
                },
                builder: (context, state) {
                  switch (state.status) {
                    case EditorStatus.loading:
                      return const Center(child: CircularProgressIndicator());
                    case EditorStatus.loadFailed:
                      return StateView(
                        status: ViewStatus.error,
                        failure: state.failure,
                        onRetry: () => context.read<QuizEditorCubit>().load(),
                        contentBuilder: (_) => const SizedBox.shrink(),
                      );
                    case EditorStatus.ready:
                      return _buildForm(context, state);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context, QuizEditorState state) {
    final cubit = context.read<QuizEditorCubit>();
    final saving = state.saving;
    final quiz = state.quiz;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            children: [
              TextField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration:
                    appInput('Titre', errorText: state.fieldErrors['title']),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _duration,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: appInput(
                  'Durée (minutes)',
                  errorText: state.fieldErrors['durationMinutes'],
                ),
              ),
              const SizedBox(height: 12),
              _DateTimeField(
                label: 'Ouvre le',
                value: _opensAt,
                onPick: () => _pick(opens: true),
                onClear: () => setState(() => _opensAt = null),
              ),
              const SizedBox(height: 12),
              _DateTimeField(
                label: 'Ferme le (facultatif)',
                value: _closesAt,
                onPick: () => _pick(opens: false),
                onClear: () => setState(() => _closesAt = null),
              ),
              const SizedBox(height: 20),
              Text(
                'Questions (${state.questions.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (quiz == null)
                const AppCard(
                  child: Text(
                    'Enregistrez le quiz pour pouvoir ajouter des questions.',
                  ),
                )
              else ...[
                for (final (index, q) in state.questions.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _QuestionTile(
                      number: index + 1,
                      question: q,
                      onEdit: saving ? null : () => _editQuestion(cubit, q),
                      onDelete: saving ? null : () => _removeQuestion(cubit, q),
                    ),
                  ),
                OutlinedButton(
                  onPressed: saving ? null : () => _addQuestion(cubit),
                  child: const Text('+ Ajouter une question'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: saving ? null : () => _delete(cubit),
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Supprimer le quiz'),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: saving ? null : () => _save(cubit, publish: false),
                  child: const Text('Enregistrer'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: saving ? null : () => _save(cubit, publish: true),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Publier'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final current = value;
    return AppCard(
      onTap: onPick,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 2),
                Text(
                  current == null ? 'Non défini' : formatDateTime(current),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          if (current != null)
            IconButton(
              tooltip: 'Effacer',
              onPressed: onClear,
              icon: const Icon(Icons.close),
            )
          else
            const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.event, color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.number,
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  final int number;
  final Question question;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$number. ${question.text}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Modifier la question',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Supprimer la question',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          for (final (i, choice) in question.choices.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Icon(
                    i == question.correctIndex
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 20,
                    color: i == question.correctIndex
                        ? AppColors.successInk
                        : AppColors.border,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      choice,
                      style: TextStyle(
                        fontWeight: i == question.correctIndex
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            '${question.points} point${question.points > 1 ? 's' : ''}',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
