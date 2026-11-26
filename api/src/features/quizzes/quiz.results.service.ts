import { AppError } from '../../core/errors/app-error.js';
import { AttemptModel } from '../attempts/attempt.model.js';
import { CourseMembershipModel } from '../courses/course-membership.model.js';
import { UserModel } from '../auth/user.model.js';
import type { UserRole } from '../auth/user.model.js';
import { QuestionModel } from './question.model.js';
import { QuizModel } from './quiz.model.js';
import type { QuizResultsQuery } from './quiz.schemas.js';

async function ensureQuizAccess(quizId: string, userId: string, role: UserRole) {
  const quiz = await QuizModel.findById(quizId).select('courseId teacherId status');
  if (!quiz) throw new AppError(404, 'QUIZ_NOT_FOUND', 'Quiz not found.');

  if (role === 'teacher') {
    if (quiz.teacherId.toString() !== userId) throw new AppError(404, 'QUIZ_NOT_FOUND', 'Quiz not found.');
  } else {
    if (quiz.status !== 'published') throw new AppError(404, 'QUIZ_NOT_FOUND', 'Quiz not found.');
    const membership = await CourseMembershipModel.exists({ courseId: quiz.courseId, studentId: userId });
    if (!membership) throw new AppError(404, 'QUIZ_NOT_FOUND', 'Quiz not found.');
  }

  return quiz;
}

export async function getQuizResults(quizId: string, teacherId: string, query: QuizResultsQuery) {
  const quiz = await ensureQuizAccess(quizId, teacherId, 'teacher');
  const filter = { quizId, status: 'completed' };
  const skip = (query.page - 1) * query.limit;
  const [attempts, total, questions] = await Promise.all([
    AttemptModel.find(filter).sort({ score: -1, submittedAt: 1, _id: 1 }).skip(skip).limit(query.limit),
    AttemptModel.countDocuments(filter),
    QuestionModel.find({ quizId }).sort({ position: 1 }),
  ]);
  const students = await UserModel.find({ _id: { $in: attempts.map((attempt) => attempt.studentId) } }).select('name');
  const studentNames = new Map(students.map((student) => [student.id, student.name]));
  const questionById = new Map(questions.map((question) => [question.id, question]));

  return {
    data: attempts.map((attempt) => ({
      attemptId: attempt.id,
      studentId: attempt.studentId.toString(),
      studentName: studentNames.get(attempt.studentId.toString()) ?? 'Unknown student',
      score: attempt.score,
      totalPoints: attempt.totalPoints,
      startedAt: attempt.startedAt,
      submittedAt: attempt.submittedAt,
      answers: attempt.answers.map((answer) => {
        const question = questionById.get(answer.questionId.toString());
        return {
          questionId: answer.questionId.toString(),
          prompt: question?.prompt ?? '',
          options: question?.options ?? [],
          selectedOptionIndex: answer.selectedOptionIndex,
          isCorrect: answer.isCorrect,
          pointsEarned: answer.pointsEarned,
          maxPoints: question?.points ?? 0,
        };
      }),
    })),
    meta: { page: query.page, limit: query.limit, total },
    quizId: quiz.id,
  };
}

export async function getQuizLeaderboard(quizId: string, userId: string, role: UserRole, query: QuizResultsQuery) {
  await ensureQuizAccess(quizId, userId, role);
  const filter = { quizId, status: 'completed' };
  const skip = (query.page - 1) * query.limit;
  const [attempts, total] = await Promise.all([
    AttemptModel.find(filter).sort({ score: -1, submittedAt: 1, _id: 1 }).skip(skip).limit(query.limit),
    AttemptModel.countDocuments(filter),
  ]);
  const students = await UserModel.find({ _id: { $in: attempts.map((attempt) => attempt.studentId) } }).select('name');
  const studentNames = new Map(students.map((student) => [student.id, student.name]));

  return {
    data: attempts.map((attempt, index) => ({
      rank: skip + index + 1,
      studentId: attempt.studentId.toString(),
      studentName: studentNames.get(attempt.studentId.toString()) ?? 'Unknown student',
      score: attempt.score,
      totalPoints: attempt.totalPoints,
      submittedAt: attempt.submittedAt,
    })),
    meta: { page: query.page, limit: query.limit, total },
  };
}
