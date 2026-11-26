import 'package:equatable/equatable.dart';

enum QuizStatus {
  draft,
  published;

  static QuizStatus parse(String? value) =>
      value == 'published' ? QuizStatus.published : QuizStatus.draft;
}

class Quiz extends Equatable {
  const Quiz({
    required this.id,
    required this.courseId,
    required this.title,
    required this.durationMinutes,
    required this.status,
    required this.questionCount,
    this.opensAt,
    this.closesAt,
  });

  final String id;
  final String courseId;
  final String title;
  final int durationMinutes;
  final QuizStatus status;
  final int questionCount;
  final DateTime? opensAt;
  final DateTime? closesAt;

  /// Indication d'affichage uniquement : le serveur reste l'autorité pour
  /// l'ouverture, la durée et l'éligibilité.
  bool isOpenAt(DateTime now) {
    if (status != QuizStatus.published) return false;
    final opens = opensAt;
    final closes = closesAt;
    if (opens != null && now.isBefore(opens)) return false;
    if (closes != null && !now.isBefore(closes)) return false;
    return true;
  }

  Quiz copyWith({int? questionCount}) {
    return Quiz(
      id: id,
      courseId: courseId,
      title: title,
      durationMinutes: durationMinutes,
      status: status,
      questionCount: questionCount ?? this.questionCount,
      opensAt: opensAt,
      closesAt: closesAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        courseId,
        title,
        durationMinutes,
        status,
        questionCount,
        opensAt,
        closesAt,
      ];
}

/// Données saisies par l'enseignant pour créer ou modifier un quiz.
class QuizDraft extends Equatable {
  const QuizDraft({
    required this.title,
    required this.durationMinutes,
    required this.status,
    this.opensAt,
    this.closesAt,
  });

  final String title;
  final int durationMinutes;
  final QuizStatus status;
  final DateTime? opensAt;
  final DateTime? closesAt;

  @override
  List<Object?> get props =>
      [title, durationMinutes, status, opensAt, closesAt];
}
