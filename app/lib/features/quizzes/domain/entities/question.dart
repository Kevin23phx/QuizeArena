import 'package:equatable/equatable.dart';

/// Question telle que la voit l'ENSEIGNANT propriétaire, bonne réponse comprise.
/// Un étudiant ne reçoit jamais cette entité : sa lecture des questions passe
/// par la feature `attempts`, avec un DTO sans `correctIndex`.
class Question extends Equatable {
  const Question({
    required this.id,
    required this.quizId,
    required this.text,
    required this.choices,
    required this.correctIndex,
    required this.points,
    required this.order,
  });

  final String id;
  final String quizId;
  final String text;
  final List<String> choices;
  final int correctIndex;
  final int points;
  final int order;

  @override
  List<Object?> get props =>
      [id, quizId, text, choices, correctIndex, points, order];
}

/// Données saisies pour créer ou modifier une question (choix unique).
class QuestionDraft extends Equatable {
  const QuestionDraft({
    required this.text,
    required this.choices,
    required this.correctIndex,
    required this.points,
  });

  final String text;
  final List<String> choices;
  final int correctIndex;
  final int points;

  @override
  List<Object?> get props => [text, choices, correctIndex, points];
}
