import '../../domain/entities/question.dart';
import '../../domain/entities/quiz.dart';

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

Quiz quizFromJson(Map<String, dynamic> json) {
  return Quiz(
    id: json['id'] as String,
    courseId: json['courseId'] as String,
    title: json['title'] as String,
    durationMinutes: json['durationMinutes'] as int,
    status: QuizStatus.parse(json['status'] as String?),
    questionCount: (json['questionCount'] as int?) ?? 0,
    opensAt: _date(json['opensAt']),
    closesAt: _date(json['closesAt']),
  );
}

/// Les deux dates sont toujours envoyées ; `null` signifie « pas de date ».
Map<String, dynamic> quizDraftToJson(QuizDraft draft) {
  return {
    'title': draft.title,
    'durationMinutes': draft.durationMinutes,
    'status': draft.status.name,
    'opensAt': draft.opensAt?.toUtc().toIso8601String(),
    'closesAt': draft.closesAt?.toUtc().toIso8601String(),
  };
}

Question questionFromJson(Map<String, dynamic> json) {
  return Question(
    id: json['id'] as String,
    quizId: json['quizId'] as String,
    text: json['text'] as String,
    choices: [for (final c in json['choices'] as List<dynamic>) c.toString()],
    correctIndex: json['correctIndex'] as int,
    points: (json['points'] as int?) ?? 1,
    order: (json['order'] as int?) ?? 0,
  );
}

Map<String, dynamic> questionDraftToJson(QuestionDraft draft) {
  return {
    'text': draft.text,
    'choices': draft.choices,
    'correctIndex': draft.correctIndex,
    'points': draft.points,
  };
}
