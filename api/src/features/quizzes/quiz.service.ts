import { AppError } from '../../core/errors/app-error.js';
import { CourseMembershipModel } from '../courses/course-membership.model.js';
import { CourseModel } from '../courses/course.model.js';
import type { UserRole } from '../auth/user.model.js';
import { QuestionModel } from './question.model.js';
import { QuizModel } from './quiz.model.js';
import type { CreateQuestionInput, CreateQuizInput } from './quiz.schemas.js';

export async function createQuiz(courseId: string, teacherId: string, input: CreateQuizInput) {
  const course = await CourseModel.findById(courseId).select('teacherId');
  if (!course || course.teacherId.toString() !== teacherId) {
    throw new AppError(404, 'COURSE_NOT_FOUND', 'Course not found.');
  }

  const quiz = await QuizModel.create({ ...input, courseId, teacherId, status: 'draft' });
  return toQuizDto(quiz);
}

export async function addQuestion(quizId: string, teacherId: string, input: CreateQuestionInput) {
  const quiz = await QuizModel.findOne({ _id: quizId, teacherId });
  if (!quiz) throw new AppError(404, 'QUIZ_NOT_FOUND', 'Quiz not found.');
  if (quiz.status !== 'draft') {
    throw new AppError(409, 'QUIZ_NOT_EDITABLE', 'Only draft quizzes can be edited.');
  }

  const position = input.position ?? await QuestionModel.countDocuments({ quizId });
  const question = await QuestionModel.create({ ...input, position, quizId });
  return toQuestionDto(question, true);
}

export async function publishQuiz(quizId: string, teacherId: string) {
  const quiz = await QuizModel.findOne({ _id: quizId, teacherId });
  if (!quiz) throw new AppError(404, 'QUIZ_NOT_FOUND', 'Quiz not found.');
  if (quiz.status !== 'draft') {
    throw new AppError(409, 'QUIZ_NOT_EDITABLE', 'Only draft quizzes can be published.');
  }
  const questionCount = await QuestionModel.countDocuments({ quizId });
  if (questionCount === 0) {
    throw new AppError(409, 'QUIZ_HAS_NO_QUESTIONS', 'Add at least one question before publishing.');
  }
  quiz.status = 'published';
  await quiz.save();
  return toQuizDto(quiz);
}

export async function listCourseQuizzes(courseId: string, userId: string, role: UserRole) {
  const course = await CourseModel.findById(courseId).select('teacherId');
  if (!course) throw new AppError(404, 'COURSE_NOT_FOUND', 'Course not found.');

  let filter: Record<string, unknown> = { courseId };
  if (role === 'teacher') {
    if (course.teacherId.toString() !== userId) throw new AppError(404, 'COURSE_NOT_FOUND', 'Course not found.');
  } else {
    const member = await CourseMembershipModel.exists({ courseId, studentId: userId });
    if (!member) throw new AppError(404, 'COURSE_NOT_FOUND', 'Course not found.');
    filter = { ...filter, status: 'published' };
  }

  const quizzes = await QuizModel.find(filter).sort({ createdAt: -1 });
  return { data: quizzes.map(toQuizDto) };
}

export async function getQuiz(quizId: string, userId: string, role: UserRole) {
  const quiz = await QuizModel.findById(quizId);
  if (!quiz) throw new AppError(404, 'QUIZ_NOT_FOUND', 'Quiz not found.');

  const isTeacher = role === 'teacher' && quiz.teacherId.toString() === userId;
  if (!isTeacher) {
    const member = role === 'student' && await CourseMembershipModel.exists({
      courseId: quiz.courseId,
      studentId: userId,
    });
    if (!member || quiz.status !== 'published') {
      throw new AppError(404, 'QUIZ_NOT_FOUND', 'Quiz not found.');
    }
  }

  let questionsQuery = QuestionModel.find({ quizId }).sort({ position: 1 });
  if (isTeacher) questionsQuery = questionsQuery.select('+correctOptionIndex');
  const questions = await questionsQuery;
  return {
    data: {
      ...toQuizDto(quiz),
      questions: questions.map((question) => toQuestionDto(question, isTeacher)),
    },
  };
}

function toQuizDto(quiz: { id?: string; _id: { toString(): string }; courseId: unknown; teacherId: unknown; title: string; description: string; timePerQuestionSeconds: number; status: string; createdAt: Date }) {
  return {
    id: quiz.id ?? quiz._id.toString(),
    courseId: String(quiz.courseId),
    teacherId: String(quiz.teacherId),
    title: quiz.title,
    description: quiz.description,
    timePerQuestionSeconds: quiz.timePerQuestionSeconds,
    status: quiz.status,
    createdAt: quiz.createdAt,
  };
}

function toQuestionDto(question: { id?: string; _id: { toString(): string }; prompt: string; options: string[]; correctOptionIndex?: number; points: number; position: number }, includeAnswer: boolean) {
  return {
    id: question.id ?? question._id.toString(),
    prompt: question.prompt,
    options: question.options,
    points: question.points,
    position: question.position,
    ...(includeAnswer ? { correctOptionIndex: question.correctOptionIndex } : {}),
  };
}
