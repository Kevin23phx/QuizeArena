abstract final class AttemptPaths {
  static String play(String quizId) => '/quizzes/$quizId/attempt';
  static String result(String attemptId) => '/attempts/$attemptId/result';

  static const playPattern = '/quizzes/:quizId/attempt';
  static const resultPattern = '/attempts/:attemptId/result';
}
