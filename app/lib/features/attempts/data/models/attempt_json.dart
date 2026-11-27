import '../../domain/entities/attempt.dart';

abstract final class AttemptJson {
  static Attempt fromJson(Map<String, dynamic> json) {
    final status = switch (_string(json, 'status')) {
      'in_progress' => AttemptStatus.inProgress,
      'completed' => AttemptStatus.completed,
      _ => throw const FormatException('Statut de tentative inconnu.'),
    };

    _date(json, 'startedAt');
    final currentQuestion = status == AttemptStatus.inProgress
        ? _question(_map(json, 'currentQuestion'))
        : null;
    final answers = status == AttemptStatus.completed
        ? _list(json, 'answers').map(_answer).toList(growable: false)
        : const <AttemptAnswer>[];

    if (status == AttemptStatus.inProgress) {
      _integer(json, 'timePerQuestionSeconds');
      _date(json, 'deadlineAt');
      _date(json, 'serverTime');
    } else {
      _date(json, 'submittedAt');
    }

    return Attempt(
      id: _string(json, 'id'),
      quizId: _string(json, 'quizId'),
      status: status,
      score: _integer(json, 'score'),
      totalPoints: _integer(json, 'totalPoints'),
      currentQuestion: currentQuestion,
      timePerQuestionSeconds: status == AttemptStatus.inProgress
          ? _integer(json, 'timePerQuestionSeconds')
          : null,
      deadlineAt:
          status == AttemptStatus.inProgress ? _date(json, 'deadlineAt') : null,
      serverTime:
          status == AttemptStatus.inProgress ? _date(json, 'serverTime') : null,
      answers: answers,
    );
  }

  static AttemptQuestion _question(Map<String, dynamic> json) {
    final options = _list(json, 'options');
    if (options.any((option) => option is! String)) {
      throw const FormatException('Options de question invalides.');
    }
    return AttemptQuestion(
      id: _string(json, 'id'),
      prompt: _string(json, 'prompt'),
      options: options.cast<String>(),
      points: _integer(json, 'points'),
      position: _integer(json, 'position'),
      totalQuestions: _integer(json, 'totalQuestions'),
    );
  }

  static AttemptAnswer _answer(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Réponse de tentative invalide.');
    }
    final selectedOptionIndex = value['selectedOptionIndex'];
    if (selectedOptionIndex != null && selectedOptionIndex is! int) {
      throw const FormatException('Index de réponse invalide.');
    }
    _date(value, 'answeredAt');
    return AttemptAnswer(
      questionId: _string(value, 'questionId'),
      selectedOptionIndex: selectedOptionIndex as int?,
      isCorrect: _boolean(value, 'isCorrect'),
      pointsEarned: _integer(value, 'pointsEarned'),
    );
  }

  static Map<String, dynamic> _map(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    if (value is Map<String, dynamic>) return value;
    throw FormatException('Champ $key invalide.');
  }

  static List<dynamic> _list(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is List<dynamic>) return value;
    throw FormatException('Champ $key invalide.');
  }

  static String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return value;
    throw FormatException('Champ $key invalide.');
  }

  static int _integer(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is int) return value;
    throw FormatException('Champ $key invalide.');
  }

  static bool _boolean(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is bool) return value;
    throw FormatException('Champ $key invalide.');
  }

  static DateTime _date(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String) return DateTime.parse(value);
    throw FormatException('Champ $key invalide.');
  }
}
