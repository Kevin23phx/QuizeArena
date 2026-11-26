/// Chemins des écrans de la feature quizzes (utilisés par les pages et le router).
abstract final class QuizPaths {
  static String list(String courseId) => '/courses/$courseId/quizzes';
  static String create(String courseId) => '/courses/$courseId/quizzes/new';
  static String detail(String quizId) => '/quizzes/$quizId';
  static String edit(String quizId) => '/quizzes/$quizId/edit';

  // Patrons go_router
  static const listPattern = '/courses/:courseId/quizzes';
  static const createPattern = '/courses/:courseId/quizzes/new';
  static const detailPattern = '/quizzes/:quizId';
  static const editPattern = '/quizzes/:quizId/edit';
}
