import { AppError } from '../../core/errors/app-error.js';
import mongoose, { type HydratedDocument } from 'mongoose';
import { CourseMembershipModel } from '../courses/course-membership.model.js';
import { QuestionModel } from '../quizzes/question.model.js';
import { QuizModel } from '../quizzes/quiz.model.js';
import { AttemptModel, type AttemptDocument } from './attempt.model.js';
import type { SubmitAnswerInput } from './attempt.schemas.js';

function isDuplicateKeyError(error: unknown): boolean {
  return typeof error === 'object' && error !== null && 'code' in error && error.code === 11000;
}

export async function startAttempt(quizId: string, studentId: string) {
  const quiz = await QuizModel.findOne({ _id: quizId, status: 'published' });
  if (!quiz) throw new AppError(404, 'QUIZ_NOT_FOUND', 'Quiz not found.');

  const membership = await CourseMembershipModel.exists({ courseId: quiz.courseId, studentId });
  if (!membership) throw new AppError(404, 'QUIZ_NOT_FOUND', 'Quiz not found.');

  const existing = await AttemptModel.findOne({ quizId, studentId });
  if (existing) {
    await advanceExpiredQuestions(existing, new Date(), quiz.timePerQuestionSeconds);
    return { created: false, data: await toAttemptView(existing, quiz.timePerQuestionSeconds) };
  }

  const questions = await QuestionModel.find({ quizId }).sort({ position: 1 }).select('_id points');
  if (questions.length === 0) throw new AppError(409, 'QUIZ_HAS_NO_QUESTIONS', 'This quiz has no questions.');

  const now = new Date();
  try {
    const attempt = await AttemptModel.create({
      quizId,
      studentId,
      questionIds: questions.map((question) => question._id),
      currentQuestionIndex: 0,
      currentQuestionStartedAt: now,
      startedAt: now,
      status: 'in_progress',
      totalPoints: questions.reduce((sum, question) => sum + question.points, 0),
    });
    return { created: true, data: await toAttemptView(attempt, quiz.timePerQuestionSeconds) };
  } catch (error: unknown) {
    if (!isDuplicateKeyError(error)) throw error;
    const concurrentAttempt = await AttemptModel.findOne({ quizId, studentId });
    if (!concurrentAttempt) throw error;
    return { created: false, data: await toAttemptView(concurrentAttempt, quiz.timePerQuestionSeconds) };
  }
}

export async function getAttempt(attemptId: string, studentId: string) {
  const attempt = await AttemptModel.findOne({ _id: attemptId, studentId });
  if (!attempt) throw new AppError(404, 'ATTEMPT_NOT_FOUND', 'Attempt not found.');
  const quiz = await QuizModel.findById(attempt.quizId).select('timePerQuestionSeconds');
  if (!quiz) throw new AppError(404, 'ATTEMPT_NOT_FOUND', 'Attempt not found.');
  await advanceExpiredQuestions(attempt, new Date(), quiz.timePerQuestionSeconds);
  return { data: await toAttemptView(attempt, quiz.timePerQuestionSeconds) };
}

export async function submitAnswer(attemptId: string, studentId: string, input: SubmitAnswerInput) {
  const attempt = await AttemptModel.findOne({ _id: attemptId, studentId });
  if (!attempt) throw new AppError(404, 'ATTEMPT_NOT_FOUND', 'Attempt not found.');
  const quiz = await QuizModel.findById(attempt.quizId).select('timePerQuestionSeconds');
  if (!quiz) throw new AppError(404, 'ATTEMPT_NOT_FOUND', 'Attempt not found.');

  if (attempt.status === 'completed') {
    const alreadyAnswered = attempt.answers.some((answer) => answer.questionId.toString() === input.questionId);
    if (alreadyAnswered) return { data: await toAttemptView(attempt, quiz.timePerQuestionSeconds) };
    throw new AppError(409, 'ATTEMPT_COMPLETED', 'This attempt is already completed.');
  }

  const indexBeforeExpiryCheck = attempt.currentQuestionIndex;
  const expired = await advanceExpiredQuestions(attempt, new Date(), quiz.timePerQuestionSeconds);
  if (expired && attempt.currentQuestionIndex !== indexBeforeExpiryCheck) {
    throw new AppError(409, 'QUESTION_TIME_EXPIRED', 'The time for this question has expired.');
  }

  const previousAnswer = attempt.answers.find((answer) => answer.questionId.toString() === input.questionId);
  if (previousAnswer) return { data: await toAttemptView(attempt, quiz.timePerQuestionSeconds) };

  const currentQuestionId = attempt.questionIds[attempt.currentQuestionIndex]?.toString();
  if (!currentQuestionId || currentQuestionId !== input.questionId) {
    throw new AppError(409, 'QUESTION_NOT_CURRENT', 'The submitted question is not the current question.');
  }

  const question = await QuestionModel.findById(currentQuestionId).select('+correctOptionIndex');
  if (!question || input.selectedOptionIndex >= question.options.length) {
    throw new AppError(422, 'INVALID_OPTION', 'The selected option does not exist.');
  }

  const now = new Date();
  const isCorrect = input.selectedOptionIndex === question.correctOptionIndex;
  attempt.answers.push({
    questionId: question._id,
    selectedOptionIndex: input.selectedOptionIndex,
    isCorrect,
    pointsEarned: isCorrect ? question.points : 0,
    answeredAt: now,
  });
  if (isCorrect) attempt.score += question.points;

  attempt.currentQuestionIndex += 1;
  if (attempt.currentQuestionIndex >= attempt.questionIds.length) {
    attempt.status = 'completed';
    attempt.submittedAt = now;
  } else {
    attempt.currentQuestionStartedAt = now;
  }
  await saveAttempt(attempt);
  return { data: await toAttemptView(attempt, quiz.timePerQuestionSeconds) };
}

async function advanceExpiredQuestions(
  attempt: HydratedDocument<AttemptDocument>,
  now: Date,
  timePerQuestionSeconds: number,
): Promise<boolean> {
  if (!attempt || attempt.status !== 'in_progress') return false;
  let advanced = false;

  while (attempt.currentQuestionIndex < attempt.questionIds.length) {
    const deadlineMs = attempt.currentQuestionStartedAt.getTime() + timePerQuestionSeconds * 1000;
    if (now.getTime() < deadlineMs) break;

    const questionId = attempt.questionIds[attempt.currentQuestionIndex];
    attempt.answers.push({
      questionId,
      selectedOptionIndex: null,
      isCorrect: false,
      pointsEarned: 0,
      answeredAt: new Date(deadlineMs),
    });
    attempt.currentQuestionIndex += 1;
    attempt.currentQuestionStartedAt = new Date(deadlineMs);
    advanced = true;

    if (attempt.currentQuestionIndex >= attempt.questionIds.length) {
      attempt.status = 'completed';
      attempt.submittedAt = new Date(deadlineMs);
      break;
    }
  }

  if (advanced) await saveAttempt(attempt);
  return advanced;
}

async function saveAttempt(attempt: HydratedDocument<AttemptDocument>): Promise<void> {
  try {
    await attempt.save();
  } catch (error: unknown) {
    if (error instanceof mongoose.Error.VersionError) {
      throw new AppError(409, 'ATTEMPT_UPDATED', 'The attempt changed; reload its current state.');
    }
    throw error;
  }
}

async function toAttemptView(attempt: HydratedDocument<AttemptDocument>, timePerQuestionSeconds: number) {
  const base = {
    id: attempt.id,
    quizId: attempt.quizId.toString(),
    status: attempt.status,
    startedAt: attempt.startedAt,
    score: attempt.score,
    totalPoints: attempt.totalPoints,
  };

  if (attempt.status === 'completed') {
    return {
      ...base,
      submittedAt: attempt.submittedAt,
      answers: attempt.answers.map((answer) => ({
        questionId: answer.questionId.toString(),
        selectedOptionIndex: answer.selectedOptionIndex,
        isCorrect: answer.isCorrect,
        pointsEarned: answer.pointsEarned,
        answeredAt: answer.answeredAt,
      })),
    };
  }

  const questionId = attempt.questionIds[attempt.currentQuestionIndex];
  const question = await QuestionModel.findById(questionId).select('prompt options points');
  if (!question) throw new AppError(500, 'ATTEMPT_QUESTION_MISSING', 'The current attempt question is unavailable.');

  const deadlineAt = new Date(attempt.currentQuestionStartedAt.getTime() + timePerQuestionSeconds * 1000);
  return {
    ...base,
    currentQuestion: {
      id: question.id,
      prompt: question.prompt,
      options: question.options,
      points: question.points,
      position: attempt.currentQuestionIndex,
      totalQuestions: attempt.questionIds.length,
    },
    timePerQuestionSeconds,
    deadlineAt,
    serverTime: new Date(),
  };
}
