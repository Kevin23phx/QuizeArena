import 'package:equatable/equatable.dart';

enum AttemptStatus { inProgress, completed }

/// Question affichée à l'étudiant pendant une tentative.
/// Elle ne contient JAMAIS la bonne réponse : le serveur ne l'envoie pas.
class AttemptQuestion extends Equatable {
  const AttemptQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.points,
    required this.position,
    required this.totalQuestions,
  });

  final String id;
  final String prompt;
  final List<String> options;
  final int points;

  /// Position de la question, en partant de 0 (comme le serveur).
  final int position;
  final int totalQuestions;

  @override
  List<Object?> get props => [
        id,
        prompt,
        options,
        points,
        position,
        totalQuestions,
      ];
}

/// Réponse enregistrée par le serveur pour une question.
class AttemptAnswer extends Equatable {
  const AttemptAnswer({
    required this.questionId,
    required this.selectedOptionIndex,
    required this.isCorrect,
    required this.pointsEarned,
  });

  final String questionId;

  /// null quand l'étudiant n'a pas répondu à temps.
  final int? selectedOptionIndex;
  final bool isCorrect;
  final int pointsEarned;

  bool get wasSkipped => selectedOptionIndex == null;

  @override
  List<Object?> get props => [
        questionId,
        selectedOptionIndex,
        isCorrect,
        pointsEarned,
      ];
}

/// Tentative d'un étudiant sur un quiz, telle que le serveur la décrit.
/// L'application ne calcule jamais de note elle-même.
class Attempt extends Equatable {
  const Attempt({
    required this.id,
    required this.quizId,
    required this.status,
    required this.score,
    required this.totalPoints,
    this.currentQuestion,
    this.timePerQuestionSeconds,
    this.deadlineAt,
    this.serverTime,
    this.answers = const [],
  });

  final String id;
  final String quizId;
  final AttemptStatus status;
  final int score;
  final int totalPoints;

  /// Présente seulement tant que la tentative est en cours.
  final AttemptQuestion? currentQuestion;
  final int? timePerQuestionSeconds;

  /// Heure limite de la question en cours, et heure du serveur au moment
  /// où il a répondu. Les deux viennent du serveur.
  final DateTime? deadlineAt;
  final DateTime? serverTime;

  /// Présentes seulement quand la tentative est terminée.
  final List<AttemptAnswer> answers;

  bool get isCompleted => status == AttemptStatus.completed;
  bool get isInProgress => status == AttemptStatus.inProgress;

  /// La note n'est définitive que lorsque la tentative est terminée.
  int? get finalScore => isCompleted ? score : null;

  int get correctAnswersCount => answers.where((a) => a.isCorrect).length;

  /// Temps restant au moment où le serveur a répondu.
  /// Calculé avec les deux heures du serveur, jamais avec l'horloge du
  /// téléphone. L'écran fait ensuite décompter ce temps avec un chronomètre.
  Duration? get remainingWhenReceived {
    final deadline = deadlineAt;
    final now = serverTime;
    if (deadline == null || now == null) return null;
    final remaining = deadline.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  @override
  List<Object?> get props => [
        id,
        quizId,
        status,
        score,
        totalPoints,
        currentQuestion,
        timePerQuestionSeconds,
        deadlineAt,
        serverTime,
        answers,
      ];
}
