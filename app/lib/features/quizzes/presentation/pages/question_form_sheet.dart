import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:quizarena/core/theme/app_theme.dart';
import 'package:quizarena/core/widgets/app_input.dart';

import '../../domain/entities/question.dart';

/// Feuille de saisie d'une question à choix unique (2 à 4 choix).
/// Retourne le brouillon validé localement, ou null si annulé.
Future<QuestionDraft?> showQuestionSheet(
  BuildContext context, {
  Question? initial,
}) {
  return showModalBottomSheet<QuestionDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _QuestionSheet(initial: initial),
  );
}

class _QuestionSheet extends StatefulWidget {
  const _QuestionSheet({this.initial});

  final Question? initial;

  @override
  State<_QuestionSheet> createState() => _QuestionSheetState();
}

class _QuestionSheetState extends State<_QuestionSheet> {
  static const _maxChoices = 4;

  late final TextEditingController _text;
  late final TextEditingController _points;
  late final List<TextEditingController> _choices;
  late int _correct;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.initial;
    _text = TextEditingController(text: q?.text ?? '');
    _points = TextEditingController(text: (q?.points ?? 1).toString());
    _choices = [
      for (final c in q?.choices ?? const ['', ''])
        TextEditingController(text: c),
    ];
    _correct = q?.correctIndex ?? 0;
  }

  @override
  void dispose() {
    _text.dispose();
    _points.dispose();
    for (final c in _choices) {
      c.dispose();
    }
    super.dispose();
  }

  void _addChoice() {
    if (_choices.length >= _maxChoices) return;
    setState(() => _choices.add(TextEditingController()));
  }

  void _removeChoice(int index) {
    if (_choices.length <= 2) return;
    setState(() {
      _choices.removeAt(index).dispose();
      if (_correct == index) {
        _correct = 0;
      } else if (_correct > index) {
        _correct -= 1;
      }
    });
  }

  void _submit() {
    final text = _text.text.trim();
    final choices = [for (final c in _choices) c.text.trim()];
    final points = int.tryParse(_points.text.trim()) ?? 0;

    String? error;
    if (text.isEmpty) {
      error = 'Saisissez l\'énoncé de la question.';
    } else if (choices.any((c) => c.isEmpty)) {
      error = 'Renseignez ou retirez les choix vides.';
    } else if (points < 1) {
      error = 'Les points doivent être d\'au moins 1.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    Navigator.of(context).pop(
      QuestionDraft(
        text: text,
        choices: choices,
        correctIndex: _correct,
        points: points,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null
                  ? 'Nouvelle question'
                  : 'Modifier la question',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _text,
              minLines: 2,
              maxLines: 4,
              decoration: appInput('Énoncé'),
            ),
            const SizedBox(height: 14),
            const Text(
              'Choix · touchez le cercle pour désigner la bonne réponse',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < _choices.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Bonne réponse',
                      onPressed: () => setState(() => _correct = i),
                      icon: Icon(
                        _correct == i
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: _correct == i
                            ? AppColors.successInk
                            : AppColors.muted,
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _choices[i],
                        decoration: appInput('Choix ${i + 1}'),
                      ),
                    ),
                    if (_choices.length > 2)
                      IconButton(
                        tooltip: 'Retirer ce choix',
                        onPressed: () => _removeChoice(i),
                        icon: const Icon(Icons.close),
                      ),
                  ],
                ),
              ),
            if (_choices.length < _maxChoices)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _addChoice,
                  child: const Text('+ Ajouter un choix'),
                ),
              ),
            const SizedBox(height: 6),
            TextField(
              controller: _points,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: appInput('Points'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    child: const Text('Valider'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
