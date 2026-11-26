import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import dotenv from 'dotenv';

dotenv.config({ path: '.env' });
dotenv.config({ path: '.env.test', override: true });
process.env.NODE_ENV = 'test';

const mongoUri = process.env.MONGODB_URI;
if (!mongoUri?.split('?')[0].endsWith('/quizarena_test')) {
  throw new Error('Tests require a separate MongoDB database named quizarena_test. Copy .env.test.example to .env.test first.');
}

let server: import('node:http').Server;
let baseUrl: string;
let teacherToken: string;
let memberToken: string;
let outsiderToken: string;
let strangerToken: string;
let courseId: string;
let joinCode: string;
let publishedQuizId = '';

before(async () => {
  const [{ app }, mongooseModule, userModule, courseModule, membershipModule, quizModule, questionModule, attemptModule, tokenModule] = await Promise.all([
    import('../src/app.js'),
    import('mongoose'),
    import('../src/features/auth/user.model.js'),
    import('../src/features/courses/course.model.js'),
    import('../src/features/courses/course-membership.model.js'),
    import('../src/features/quizzes/quiz.model.js'),
    import('../src/features/quizzes/question.model.js'),
    import('../src/features/attempts/attempt.model.js'),
    import('../src/features/auth/token.service.js'),
  ]);

  try {
    await mongooseModule.default.connect(mongoUri, { serverSelectionTimeoutMS: 5_000 });
  } catch (error: unknown) {
    throw new Error('Could not connect to the test MongoDB. Check that MongoDB is running and .env.test points to quizarena_test.', { cause: error });
  }
  await Promise.all([
    userModule.UserModel.init(),
    courseModule.CourseModel.init(),
    membershipModule.CourseMembershipModel.init(),
    quizModule.QuizModel.init(),
    questionModule.QuestionModel.init(),
    attemptModule.AttemptModel.init(),
  ]);
  await Promise.all([
    userModule.UserModel.deleteMany({}),
    courseModule.CourseModel.deleteMany({}),
    membershipModule.CourseMembershipModel.deleteMany({}),
    quizModule.QuizModel.deleteMany({}),
    questionModule.QuestionModel.deleteMany({}),
    attemptModule.AttemptModel.deleteMany({}),
  ]);

  const [teacher, member, outsider, stranger] = await userModule.UserModel.create([
    { name: 'Teacher Test', email: 'teacher@test.invalid', passwordHash: 'not-used', role: 'teacher' },
    { name: 'Student Test', email: 'student@test.invalid', passwordHash: 'not-used', role: 'student' },
    { name: 'Outsider Test', email: 'outsider@test.invalid', passwordHash: 'not-used', role: 'student' },
    { name: 'Stranger Test', email: 'stranger@test.invalid', passwordHash: 'not-used', role: 'student' },
  ]);

  const course = await courseModule.CourseModel.create({
    name: 'Integration Course',
    description: 'Course for access control tests',
    teacherId: teacher._id,
    joinCode: 'TESTCODE',
  });
  await courseModule.CourseModel.create({
    name: 'Algebra Practice',
    description: 'Second course for pagination tests',
    teacherId: teacher._id,
    joinCode: 'ALGEBRA2',
  });
  await membershipModule.CourseMembershipModel.create({ courseId: course._id, studentId: member._id });

  [teacherToken, memberToken, outsiderToken, strangerToken] = await Promise.all([
    tokenModule.createAccessToken(teacher.id, 'teacher'),
    tokenModule.createAccessToken(member.id, 'student'),
    tokenModule.createAccessToken(outsider.id, 'student'),
    tokenModule.createAccessToken(stranger.id, 'student'),
  ]);
  courseId = course.id;
  joinCode = course.joinCode;

  server = app.listen(0);
  await new Promise<void>((resolve, reject) => {
    server.once('listening', resolve);
    server.once('error', reject);
  });
  const address = server.address();
  if (!address || typeof address === 'string') throw new Error('Could not determine test server address.');
  baseUrl = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  if (server?.listening) {
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
  const mongooseModule = await import('mongoose');
  await mongooseModule.default.disconnect();
});

test('course detail enforces authentication and membership while hiding join codes', async (context) => {
  await context.test('returns the course and join code to its teacher', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses/${courseId}`, {
      headers: { authorization: `Bearer ${teacherToken}` },
    });
    const body = await response.json() as { data: { joinCode?: string } };
    assert.equal(response.status, 200);
    assert.equal(body.data.joinCode, 'TESTCODE');
  });

  await context.test('returns course details without join code to a member student', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses/${courseId}`, {
      headers: { authorization: `Bearer ${memberToken}` },
    });
    const body = await response.json() as { data: Record<string, unknown> };
    assert.equal(response.status, 200);
    assert.equal('joinCode' in body.data, false);
  });

  await context.test('hides the course from a student who is not a member', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses/${courseId}`, {
      headers: { authorization: `Bearer ${outsiderToken}` },
    });
    assert.equal(response.status, 404);
  });

  await context.test('requires an access token', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses/${courseId}`);
    assert.equal(response.status, 401);
  });

  await context.test('rejects a malformed course ID', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses/not-an-object-id`, {
      headers: { authorization: `Bearer ${teacherToken}` },
    });
    assert.equal(response.status, 422);
  });
});

test('course list respects ownership, membership, search, and pagination', async (context) => {
  await context.test('paginates teacher-owned courses and includes their join codes', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses?page=1&limit=1`, {
      headers: { authorization: `Bearer ${teacherToken}` },
    });
    const body = await response.json() as {
      data: Array<{ joinCode?: string }>;
      meta: { page: number; limit: number; total: number };
    };
    assert.equal(response.status, 200);
    assert.equal(body.data.length, 1);
    assert.equal(typeof body.data[0].joinCode, 'string');
    assert.deepEqual(body.meta, { page: 1, limit: 1, total: 2 });
  });

  await context.test('limits student results to joined courses and hides join codes', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses`, {
      headers: { authorization: `Bearer ${memberToken}` },
    });
    const body = await response.json() as {
      data: Array<Record<string, unknown>>;
      meta: { total: number };
    };
    assert.equal(response.status, 200);
    assert.equal(body.meta.total, 1);
    assert.equal(body.data.length, 1);
    assert.equal('joinCode' in body.data[0], false);
    assert.equal(body.data[0].id, courseId);
  });

  await context.test('filters course names with q', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses?q=Integration`, {
      headers: { authorization: `Bearer ${teacherToken}` },
    });
    const body = await response.json() as { data: Array<{ name: string }>; meta: { total: number } };
    assert.equal(response.status, 200);
    assert.equal(body.meta.total, 1);
    assert.equal(body.data[0].name, 'Integration Course');
  });

  await context.test('rejects an invalid page parameter', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses?page=0`, {
      headers: { authorization: `Bearer ${teacherToken}` },
    });
    assert.equal(response.status, 422);
  });
});

test('joining a course is idempotent for the same student', async (context) => {
  await context.test('creates the membership once and returns it on retry', async () => {
    const request = () => fetch(`${baseUrl}/api/v1/courses/join`, {
      method: 'POST',
      headers: {
        authorization: `Bearer ${outsiderToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify({ joinCode }),
    });

    const firstResponse = await request();
    const firstBody = await firstResponse.json() as { data: { courseId: string; studentId: string } };
    assert.equal(firstResponse.status, 201);
    assert.equal(firstBody.data.courseId, courseId);

    const retryResponse = await request();
    const retryBody = await retryResponse.json() as { data: { courseId: string; studentId: string } };
    assert.equal(retryResponse.status, 200);
    assert.deepEqual(retryBody.data, firstBody.data);

    const listResponse = await fetch(`${baseUrl}/api/v1/courses`, {
      headers: { authorization: `Bearer ${outsiderToken}` },
    });
    const listBody = await listResponse.json() as { meta: { total: number } };
    assert.equal(listBody.meta.total, 1);
  });
});

test('quiz authoring is restricted and student responses hide answer keys', async (context) => {
  let quizId = '';

  await context.test('allows the course teacher to create a draft quiz', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses/${courseId}/quizzes`, {
      method: 'POST',
      headers: { authorization: `Bearer ${teacherToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ title: 'HTTP Basics' }),
    });
    const body = await response.json() as { data: { id: string; status: string; timePerQuestionSeconds: number } };
    assert.equal(response.status, 201);
    assert.equal(body.data.status, 'draft');
    assert.equal(body.data.timePerQuestionSeconds, 10);
    quizId = body.data.id;
    publishedQuizId = quizId;
  });

  await context.test('lists drafts for the teacher but hides them from students', async () => {
    const teacherResponse = await fetch(`${baseUrl}/api/v1/courses/${courseId}/quizzes`, {
      headers: { authorization: `Bearer ${teacherToken}` },
    });
    const teacherBody = await teacherResponse.json() as { data: Array<{ status: string }> };
    assert.equal(teacherResponse.status, 200);
    assert.equal(teacherBody.data.length, 1);
    assert.equal(teacherBody.data[0].status, 'draft');

    const studentResponse = await fetch(`${baseUrl}/api/v1/courses/${courseId}/quizzes`, {
      headers: { authorization: `Bearer ${memberToken}` },
    });
    const studentBody = await studentResponse.json() as { data: unknown[] };
    assert.equal(studentResponse.status, 200);
    assert.equal(studentBody.data.length, 0);
  });

  await context.test('does not expose the leaderboard for a draft quiz to students', async () => {
    const response = await fetch(`${baseUrl}/api/v1/quizzes/${quizId}/leaderboard`, {
      headers: { authorization: `Bearer ${memberToken}` },
    });
    assert.equal(response.status, 404);
  });

  await context.test('does not let a student create a quiz', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses/${courseId}/quizzes`, {
      method: 'POST',
      headers: { authorization: `Bearer ${memberToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ title: 'Unauthorized quiz' }),
    });
    assert.equal(response.status, 403);
  });

  await context.test('does not let the client override the fixed question timer', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses/${courseId}/quizzes`, {
      method: 'POST',
      headers: { authorization: `Bearer ${teacherToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ title: 'Custom timer', timePerQuestionSeconds: 60 }),
    });
    assert.equal(response.status, 422);
  });

  await context.test('requires at least one question before publishing', async () => {
    const response = await fetch(`${baseUrl}/api/v1/quizzes/${quizId}/publish`, {
      method: 'POST',
      headers: { authorization: `Bearer ${teacherToken}` },
    });
    assert.equal(response.status, 409);
  });

  await context.test('rejects a correct option index outside the options array', async () => {
    const response = await fetch(`${baseUrl}/api/v1/quizzes/${quizId}/questions`, {
      method: 'POST',
      headers: { authorization: `Bearer ${teacherToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ prompt: 'Which protocol?', options: ['HTTP', 'FTP'], correctOptionIndex: 2 }),
    });
    assert.equal(response.status, 422);
  });

  await context.test('lets the teacher add a question and publish the quiz', async () => {
    const questionResponse = await fetch(`${baseUrl}/api/v1/quizzes/${quizId}/questions`, {
      method: 'POST',
      headers: { authorization: `Bearer ${teacherToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ prompt: 'Which protocol is used for secure web traffic?', options: ['HTTP', 'HTTPS'], correctOptionIndex: 1 }),
    });
    assert.equal(questionResponse.status, 201);

    const secondQuestionResponse = await fetch(`${baseUrl}/api/v1/quizzes/${quizId}/questions`, {
      method: 'POST',
      headers: { authorization: `Bearer ${teacherToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ prompt: 'Which method retrieves data?', options: ['GET', 'POST'], correctOptionIndex: 0 }),
    });
    assert.equal(secondQuestionResponse.status, 201);

    const publishResponse = await fetch(`${baseUrl}/api/v1/quizzes/${quizId}/publish`, {
      method: 'POST',
      headers: { authorization: `Bearer ${teacherToken}` },
    });
    const body = await publishResponse.json() as { data: { status: string } };
    assert.equal(publishResponse.status, 200);
    assert.equal(body.data.status, 'published');
  });

  await context.test('shows the answer key to the teacher but not the student', async () => {
    const teacherResponse = await fetch(`${baseUrl}/api/v1/quizzes/${quizId}`, {
      headers: { authorization: `Bearer ${teacherToken}` },
    });
    const teacherBody = await teacherResponse.json() as { data: { questions: Array<Record<string, unknown>> } };
    assert.equal(teacherResponse.status, 200);
    assert.equal(teacherBody.data.questions[0].correctOptionIndex, 1);

    const studentResponse = await fetch(`${baseUrl}/api/v1/quizzes/${quizId}`, {
      headers: { authorization: `Bearer ${memberToken}` },
    });
    const studentBody = await studentResponse.json() as { data: { questions: Array<Record<string, unknown>> } };
    assert.equal(studentResponse.status, 200);
    assert.equal('correctOptionIndex' in studentBody.data.questions[0], false);
  });

  await context.test('makes the published quiz visible in the student course list', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses/${courseId}/quizzes`, {
      headers: { authorization: `Bearer ${memberToken}` },
    });
    const body = await response.json() as { data: Array<{ id: string; status: string }> };
    assert.equal(response.status, 200);
    assert.equal(body.data.length, 1);
    assert.equal(body.data[0].id, quizId);
    assert.equal(body.data[0].status, 'published');
  });

  await context.test('only course members can read a published quiz', async () => {
    const response = await fetch(`${baseUrl}/api/v1/quizzes/${quizId}`, {
      headers: { authorization: `Bearer ${strangerToken}` },
    });
    assert.equal(response.status, 404);
  });
});

test('attempts enforce one try and the server-side ten-second question timer', async (context) => {
  let attemptId = '';
  let firstQuestionId = '';

  await context.test('starts one attempt and returns only the public current question', async () => {
    const response = await fetch(`${baseUrl}/api/v1/quizzes/${publishedQuizId}/attempts`, {
      method: 'POST',
      headers: { authorization: `Bearer ${memberToken}` },
    });
    const body = await response.json() as {
      data: { id: string; status: string; timePerQuestionSeconds: number; currentQuestion: { id: string; correctOptionIndex?: number } };
    };
    assert.equal(response.status, 201);
    assert.equal(body.data.status, 'in_progress');
    assert.equal(body.data.timePerQuestionSeconds, 10);
    assert.equal('correctOptionIndex' in body.data.currentQuestion, false);
    attemptId = body.data.id;
    firstQuestionId = body.data.currentQuestion.id;
  });

  await context.test('returns the existing attempt instead of creating another', async () => {
    const response = await fetch(`${baseUrl}/api/v1/quizzes/${publishedQuizId}/attempts`, {
      method: 'POST',
      headers: { authorization: `Bearer ${memberToken}` },
    });
    const body = await response.json() as { data: { id: string } };
    assert.equal(response.status, 200);
    assert.equal(body.data.id, attemptId);
  });

  await context.test('skips an expired question and accepts the next answer', async () => {
    const { AttemptModel } = await import('../src/features/attempts/attempt.model.js');
    const startedAttempt = await AttemptModel.findById(attemptId);
    assert.ok(startedAttempt);
    startedAttempt.currentQuestionStartedAt = new Date(Date.now() - 10_500);
    await startedAttempt.save();

    const lateResponse = await fetch(`${baseUrl}/api/v1/attempts/${attemptId}/answers`, {
      method: 'POST',
      headers: { authorization: `Bearer ${memberToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ questionId: firstQuestionId, selectedOptionIndex: 1 }),
    });
    assert.equal(lateResponse.status, 409);

    const currentResponse = await fetch(`${baseUrl}/api/v1/attempts/${attemptId}`, {
      headers: { authorization: `Bearer ${memberToken}` },
    });
    const currentBody = await currentResponse.json() as { data: { currentQuestion: { position: number; id: string } } };
    assert.equal(currentResponse.status, 200);
    assert.equal(currentBody.data.currentQuestion.position, 1);

    const answerResponse = await fetch(`${baseUrl}/api/v1/attempts/${attemptId}/answers`, {
      method: 'POST',
      headers: { authorization: `Bearer ${memberToken}`, 'content-type': 'application/json' },
      body: JSON.stringify({ questionId: currentBody.data.currentQuestion.id, selectedOptionIndex: 0 }),
    });
    const answerBody = await answerResponse.json() as { data: { status: string; score: number; totalPoints: number } };
    assert.equal(answerResponse.status, 200);
    assert.equal(answerBody.data.status, 'completed');
    assert.equal(answerBody.data.score, 1);
    assert.equal(answerBody.data.totalPoints, 2);
  });

  await context.test('does not allow another attempt after completion', async () => {
    const response = await fetch(`${baseUrl}/api/v1/quizzes/${publishedQuizId}/attempts`, {
      method: 'POST',
      headers: { authorization: `Bearer ${memberToken}` },
    });
    const body = await response.json() as { data: { id: string; status: string } };
    assert.equal(response.status, 200);
    assert.equal(body.data.id, attemptId);
    assert.equal(body.data.status, 'completed');
  });

  await context.test('returns per-question results only to the course teacher', async () => {
    const teacherResponse = await fetch(`${baseUrl}/api/v1/quizzes/${publishedQuizId}/results`, {
      headers: { authorization: `Bearer ${teacherToken}` },
    });
    const teacherBody = await teacherResponse.json() as {
      data: Array<{ studentName: string; score: number; answers: Array<{ isCorrect: boolean; maxPoints: number }> }>;
      meta: { total: number };
    };
    assert.equal(teacherResponse.status, 200);
    assert.equal(teacherBody.meta.total, 1);
    assert.equal(teacherBody.data[0].studentName, 'Student Test');
    assert.equal(teacherBody.data[0].score, 1);
    assert.equal(teacherBody.data[0].answers.length, 2);
    assert.equal(teacherBody.data[0].answers[0].isCorrect, false);
    assert.equal(teacherBody.data[0].answers[1].maxPoints, 1);

    const studentResponse = await fetch(`${baseUrl}/api/v1/quizzes/${publishedQuizId}/results`, {
      headers: { authorization: `Bearer ${memberToken}` },
    });
    assert.equal(studentResponse.status, 403);
  });

  await context.test('shows a paginated leaderboard to course members', async () => {
    const response = await fetch(`${baseUrl}/api/v1/quizzes/${publishedQuizId}/leaderboard?page=1&limit=10`, {
      headers: { authorization: `Bearer ${memberToken}` },
    });
    const body = await response.json() as {
      data: Array<{ rank: number; studentName: string; score: number }>;
      meta: { page: number; limit: number; total: number };
    };
    assert.equal(response.status, 200);
    assert.equal(body.data[0].rank, 1);
    assert.equal(body.data[0].studentName, 'Student Test');
    assert.equal(body.data[0].score, 1);
    assert.deepEqual(body.meta, { page: 1, limit: 10, total: 1 });
  });

  await context.test('does not allow a non-member to start the quiz', async () => {
    const response = await fetch(`${baseUrl}/api/v1/quizzes/${publishedQuizId}/attempts`, {
      method: 'POST',
      headers: { authorization: `Bearer ${strangerToken}` },
    });
    assert.equal(response.status, 404);
  });
});
