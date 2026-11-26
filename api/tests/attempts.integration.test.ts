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

// ---------- Types used only to read responses in a typed way ----------

interface AttemptView {
  id: string;
  status: 'in_progress' | 'completed';
  score: number;
  totalPoints: number;
  currentQuestion?: { id: string; position: number };
  answers?: Array<{ selectedOptionIndex: number | null; isCorrect: boolean; pointsEarned: number }>;
}

interface ApiResult<T> {
  status: number;
  body: T;
  raw: string;
}

interface Page<T> {
  data: T[];
  meta: { page: number; limit: number; total: number };
}

interface ResultRow {
  studentName: string;
  score: number;
}

interface LeaderboardRow {
  rank: number;
  studentName: string;
  score: number;
}

type AttemptModelType = typeof import('../src/features/attempts/attempt.model.js').AttemptModel;

// ---------- Shared state, filled in by before() ----------

let server: import('node:http').Server;
let baseUrl: string;
let AttemptModel: AttemptModelType;
let teacherToken: string;
let otherTeacherToken: string;
let studentAToken: string;
let studentBToken: string;
let outsiderToken: string;
let courseId: string;

// Every quiz created by these tests has two questions.
// Question 1: correct option is index 1. Question 2: correct option is index 0.
const QUESTIONS = [
  { prompt: 'Which protocol is used for secure web traffic?', options: ['HTTP', 'HTTPS'], correctOptionIndex: 1 },
  { prompt: 'Which method retrieves data?', options: ['GET', 'POST'], correctOptionIndex: 0 },
];
const CORRECT = [1, 0];
const WRONG = [0, 1];
const QUESTION_SECONDS = 10;

// ---------- Small helpers ----------

async function call<T = Record<string, unknown>>(
  path: string,
  token?: string,
  init: { method?: string; body?: unknown } = {},
): Promise<ApiResult<T>> {
  const headers: Record<string, string> = {};
  if (token) headers.authorization = `Bearer ${token}`;
  if (init.body !== undefined) headers['content-type'] = 'application/json';

  const response = await fetch(`${baseUrl}/api/v1${path}`, {
    method: init.method ?? 'GET',
    headers,
    body: init.body === undefined ? undefined : JSON.stringify(init.body),
  });
  const raw = await response.text();
  return { status: response.status, body: (raw ? JSON.parse(raw) : null) as T, raw };
}

function startAttempt(quizId: string, token?: string) {
  return call<{ data: AttemptView }>(`/quizzes/${quizId}/attempts`, token, { method: 'POST' });
}

function getAttempt(attemptId: string, token?: string) {
  return call<{ data: AttemptView }>(`/attempts/${attemptId}`, token);
}

function sendAnswer(
  attemptId: string,
  token: string | undefined,
  questionId: string,
  selectedOptionIndex: number,
  extraFields: Record<string, unknown> = {},
) {
  return call<{ data: AttemptView }>(`/attempts/${attemptId}/answers`, token, {
    method: 'POST',
    body: { questionId, selectedOptionIndex, ...extraFields },
  });
}

// The teacher creates a quiz with the two questions above and publishes it.
async function createPublishedQuiz(title: string): Promise<string> {
  const quiz = await call<{ data: { id: string } }>(`/courses/${courseId}/quizzes`, teacherToken, {
    method: 'POST',
    body: { title },
  });
  assert.equal(quiz.status, 201);
  const quizId = quiz.body.data.id;

  for (const question of QUESTIONS) {
    const created = await call(`/quizzes/${quizId}/questions`, teacherToken, { method: 'POST', body: question });
    assert.equal(created.status, 201);
  }

  const published = await call(`/quizzes/${quizId}/publish`, teacherToken, { method: 'POST' });
  assert.equal(published.status, 200);
  return quizId;
}

// A student starts the quiz and answers every question in order with the given picks.
async function playQuiz(token: string, quizId: string, picks: number[]): Promise<AttemptView> {
  const started = await startAttempt(quizId, token);
  assert.ok(started.status === 200 || started.status === 201);
  let view = started.body.data;
  for (const pick of picks) {
    assert.ok(view.currentQuestion, 'the attempt should still have a current question');
    const response = await sendAnswer(view.id, token, view.currentQuestion.id, pick);
    assert.equal(response.status, 200);
    view = response.body.data;
  }
  return view;
}

// Moves the start time of the current question into the past, so the server sees it as expired.
async function makeCurrentQuestionOlder(attemptId: string, millisecondsAgo: number): Promise<void> {
  const attempt = await AttemptModel.findById(attemptId);
  assert.ok(attempt);
  attempt.currentQuestionStartedAt = new Date(Date.now() - millisecondsAgo);
  await attempt.save();
}

// "Denied" means the server refused, either with 403 (forbidden) or 404 (hidden).
function assertDenied(status: number): void {
  assert.ok(status === 403 || status === 404, `expected 403 or 404, got ${status}`);
}

// ---------- Test database setup ----------

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
  AttemptModel = attemptModule.AttemptModel;

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

  const [teacher, otherTeacher, studentA, studentB, outsider] = await userModule.UserModel.create([
    { name: 'Teacher Owner', email: 'attempts-teacher@test.invalid', passwordHash: 'not-used', role: 'teacher' },
    { name: 'Teacher Other', email: 'attempts-other-teacher@test.invalid', passwordHash: 'not-used', role: 'teacher' },
    { name: 'Student A', email: 'attempts-student-a@test.invalid', passwordHash: 'not-used', role: 'student' },
    { name: 'Student B', email: 'attempts-student-b@test.invalid', passwordHash: 'not-used', role: 'student' },
    { name: 'Student Outsider', email: 'attempts-outsider@test.invalid', passwordHash: 'not-used', role: 'student' },
  ]);

  // The course taught by "Teacher Owner". Students A and B are members, the outsider is not.
  const course = await courseModule.CourseModel.create({
    name: 'Attempts Course',
    description: 'Course for attempt tests',
    teacherId: teacher._id,
    joinCode: 'ATTEMPT1',
  });
  // A second course, taught by another teacher, to check that teachers cannot cross boundaries.
  await courseModule.CourseModel.create({
    name: 'Other Teacher Course',
    description: 'Course owned by another teacher',
    teacherId: otherTeacher._id,
    joinCode: 'ATTEMPT2',
  });
  await membershipModule.CourseMembershipModel.create({ courseId: course._id, studentId: studentA._id });
  await membershipModule.CourseMembershipModel.create({ courseId: course._id, studentId: studentB._id });

  [teacherToken, otherTeacherToken, studentAToken, studentBToken, outsiderToken] = await Promise.all([
    tokenModule.createAccessToken(teacher.id, 'teacher'),
    tokenModule.createAccessToken(otherTeacher.id, 'teacher'),
    tokenModule.createAccessToken(studentA.id, 'student'),
    tokenModule.createAccessToken(studentB.id, 'student'),
    tokenModule.createAccessToken(outsider.id, 'student'),
  ]);
  courseId = course.id;

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

// ---------- 1. Who may use the attempt routes ----------

test('attempt routes are reserved to logged-in students', async (context) => {
  const quizId = await createPublishedQuiz('Access control quiz');
  const started = await startAttempt(quizId, studentAToken);
  assert.equal(started.status, 201);
  const attemptId = started.body.data.id;
  const questionId = started.body.data.currentQuestion?.id ?? '';

  await context.test('refuses all three routes without an access token', async () => {
    const start = await startAttempt(quizId);
    const read = await getAttempt(attemptId);
    const answer = await sendAnswer(attemptId, undefined, questionId, 0);
    assert.deepEqual([start.status, read.status, answer.status], [401, 401, 401]);
  });

  await context.test('refuses a teacher on all three routes', async () => {
    const start = await startAttempt(quizId, teacherToken);
    const read = await getAttempt(attemptId, teacherToken);
    const answer = await sendAnswer(attemptId, teacherToken, questionId, 0);
    assert.deepEqual([start.status, read.status, answer.status], [403, 403, 403]);
  });
});

// ---------- 2. A student only touches their own attempt ----------

test('a student cannot read or answer another student attempt', async (context) => {
  const quizId = await createPublishedQuiz('Ownership quiz');
  const started = await startAttempt(quizId, studentAToken);
  const attempt = started.body.data;
  const questionId = attempt.currentQuestion?.id ?? '';

  await context.test('hides the attempt from another member of the same course', async () => {
    const response = await getAttempt(attempt.id, studentBToken);
    assert.equal(response.status, 404);
  });

  await context.test('hides the attempt from a student outside the course', async () => {
    const response = await getAttempt(attempt.id, outsiderToken);
    assert.equal(response.status, 404);
  });

  await context.test('refuses an answer sent to someone else attempt and leaves it unchanged', async () => {
    const response = await sendAnswer(attempt.id, studentBToken, questionId, CORRECT[0]);
    assert.equal(response.status, 404);

    const own = await getAttempt(attempt.id, studentAToken);
    assert.equal(own.body.data.score, 0);
    assert.equal(own.body.data.currentQuestion?.position, 0);
  });

  await context.test('gives each student their own attempt on the same quiz', async () => {
    const response = await startAttempt(quizId, studentBToken);
    assert.equal(response.status, 201);
    assert.notEqual(response.body.data.id, attempt.id);
  });
});

// ---------- 3. The server grades and never reveals the answer key ----------

test('the server grades each answer and never reveals the answer key', async (context) => {
  const quizId = await createPublishedQuiz('Grading quiz');
  const started = await startAttempt(quizId, studentAToken);
  const attempt = started.body.data;
  const everythingTheStudentSaw: string[] = [started.raw];

  await context.test('a correct answer earns the points and moves to the next question', async () => {
    const response = await sendAnswer(attempt.id, studentAToken, attempt.currentQuestion?.id ?? '', CORRECT[0]);
    everythingTheStudentSaw.push(response.raw);
    assert.equal(response.status, 200);
    assert.equal(response.body.data.status, 'in_progress');
    assert.equal(response.body.data.score, 1);
    assert.equal(response.body.data.currentQuestion?.position, 1);
  });

  await context.test('a wrong answer earns nothing and the last answer completes the attempt', async () => {
    const current = await getAttempt(attempt.id, studentAToken);
    everythingTheStudentSaw.push(current.raw);
    const response = await sendAnswer(attempt.id, studentAToken, current.body.data.currentQuestion?.id ?? '', WRONG[1]);
    everythingTheStudentSaw.push(response.raw);
    assert.equal(response.status, 200);
    assert.equal(response.body.data.status, 'completed');
    assert.equal(response.body.data.score, 1);
    assert.equal(response.body.data.totalPoints, 2);
    assert.equal(response.body.data.answers?.[1].isCorrect, false);
    assert.equal(response.body.data.answers?.[1].pointsEarned, 0);
  });

  await context.test('no response shown to the student contains the answer key', async () => {
    for (const raw of everythingTheStudentSaw) {
      assert.equal(raw.includes('correctOptionIndex'), false);
    }
  });

  await context.test('the phone cannot choose its own score', async () => {
    const other = await startAttempt(quizId, studentBToken);
    const otherAttempt = other.body.data;
    // A wrong answer, together with fields that try to force a high score.
    const response = await sendAnswer(otherAttempt.id, studentBToken, otherAttempt.currentQuestion?.id ?? '', WRONG[0], {
      score: 999,
      isCorrect: true,
      pointsEarned: 999,
    });
    assert.ok(response.status === 200 || response.status === 422, `unexpected status ${response.status}`);

    const after = await getAttempt(otherAttempt.id, studentBToken);
    assert.equal(after.body.data.score, 0);
  });
});

// ---------- 4. Idempotence and order of answers ----------

test('answers are counted once and must follow the question order', async (context) => {
  const quizId = await createPublishedQuiz('Order quiz');
  const a = (await startAttempt(quizId, studentAToken)).body.data;
  const b = (await startAttempt(quizId, studentBToken)).body.data;
  const firstQuestionId = a.currentQuestion?.id ?? '';
  let secondQuestionId = '';

  await context.test('counts the same answer once when it is sent twice', async () => {
    const first = await sendAnswer(a.id, studentAToken, firstQuestionId, CORRECT[0]);
    const second = await sendAnswer(a.id, studentAToken, firstQuestionId, CORRECT[0]);
    assert.equal(first.status, 200);
    assert.equal(second.status, 200);
    assert.equal(second.body.data.score, 1);
    assert.equal(second.body.data.currentQuestion?.position, 1);
    secondQuestionId = second.body.data.currentQuestion?.id ?? '';
  });

  await context.test('refuses an answer for a question that is not the current one', async () => {
    const response = await sendAnswer(b.id, studentBToken, secondQuestionId, CORRECT[1]);
    assert.equal(response.status, 409);

    const unchanged = await getAttempt(b.id, studentBToken);
    assert.equal(unchanged.body.data.score, 0);
    assert.equal(unchanged.body.data.currentQuestion?.position, 0);
  });

  await context.test('refuses an option that does not exist', async () => {
    const response = await sendAnswer(b.id, studentBToken, b.currentQuestion?.id ?? '', 5);
    assert.equal(response.status, 422);
  });

  await context.test('ignores an answer sent again after the attempt is completed', async () => {
    const finish = await sendAnswer(a.id, studentAToken, secondQuestionId, CORRECT[1]);
    assert.equal(finish.status, 200);
    assert.equal(finish.body.data.status, 'completed');
    assert.equal(finish.body.data.score, 2);

    const again = await sendAnswer(a.id, studentAToken, secondQuestionId, WRONG[1]);
    assert.equal(again.status, 200);
    assert.equal(again.body.data.score, 2);
  });
});

// ---------- 5. Simultaneous requests ----------

test('simultaneous starts create exactly one attempt', async () => {
  const quizId = await createPublishedQuiz('Concurrent start quiz');
  const responses = await Promise.all(Array.from({ length: 5 }, () => startAttempt(quizId, studentAToken)));

  const created = responses.filter((response) => response.status === 201).length;
  const reused = responses.filter((response) => response.status === 200).length;
  assert.equal(created, 1);
  assert.equal(created + reused, 5);
  assert.equal(new Set(responses.map((response) => response.body.data.id)).size, 1);
  assert.equal(await AttemptModel.countDocuments({ quizId }), 1);
});

test('the same answer sent three times at once is counted once', async () => {
  const quizId = await createPublishedQuiz('Concurrent answer quiz');
  const started = (await startAttempt(quizId, studentAToken)).body.data;
  const questionId = started.currentQuestion?.id ?? '';

  const responses = await Promise.all(
    Array.from({ length: 3 }, () => sendAnswer(started.id, studentAToken, questionId, CORRECT[0])),
  );
  for (const response of responses) {
    // 200 = answer accepted or already known, 409 = "reload the attempt" after a clash.
    assert.ok(response.status === 200 || response.status === 409, `unexpected status ${response.status}`);
  }

  const after = await getAttempt(started.id, studentAToken);
  assert.equal(after.body.data.score, 1);
  assert.equal(after.body.data.currentQuestion?.position, 1);
});

// ---------- 6. The server owns the clock ----------

test('an abandoned attempt closes itself with zero points', async (context) => {
  const quizId = await createPublishedQuiz('Abandoned quiz');
  const started = (await startAttempt(quizId, studentAToken)).body.data;

  await context.test('closes with no answers once every question has run out of time', async () => {
    // Two questions of 10 seconds each: 25 seconds ago is long enough for both to expire.
    await makeCurrentQuestionOlder(started.id, QUESTIONS.length * QUESTION_SECONDS * 1000 + 5_000);

    const response = await getAttempt(started.id, studentAToken);
    assert.equal(response.status, 200);
    assert.equal(response.body.data.status, 'completed');
    assert.equal(response.body.data.score, 0);
    assert.equal(response.body.data.answers?.length, QUESTIONS.length);
    assert.deepEqual(
      response.body.data.answers?.map((answer) => answer.selectedOptionIndex),
      [null, null],
    );
  });

  await context.test('does not offer a new attempt afterwards', async () => {
    const response = await startAttempt(quizId, studentAToken);
    assert.equal(response.status, 200);
    assert.equal(response.body.data.id, started.id);
    assert.equal(response.body.data.status, 'completed');
  });
});

// ---------- 7. Results and leaderboard stay inside the course ----------

test('results and leaderboard stay inside the course', async (context) => {
  const quizId = await createPublishedQuiz('Results quiz');
  const best = await playQuiz(studentAToken, quizId, CORRECT); // 2 points
  const partial = await playQuiz(studentBToken, quizId, [CORRECT[0], WRONG[1]]); // 1 point
  assert.equal(best.score, 2);
  assert.equal(partial.score, 1);

  await context.test('the teacher of the course sees both students', async () => {
    const response = await call<Page<ResultRow>>(`/quizzes/${quizId}/results`, teacherToken);
    assert.equal(response.status, 200);
    assert.equal(response.body.meta.total, 2);
    assert.deepEqual(response.body.data.map((row) => row.studentName).sort(), ['Student A', 'Student B']);
  });

  await context.test('a teacher from another course is refused', async () => {
    const response = await call(`/quizzes/${quizId}/results`, otherTeacherToken);
    assertDenied(response.status);
    assert.equal(response.raw.includes('Student A'), false);
  });

  await context.test('a student cannot read the teacher results', async () => {
    const response = await call(`/quizzes/${quizId}/results`, studentAToken);
    assert.equal(response.status, 403);
  });

  await context.test('a student outside the course cannot read the leaderboard', async () => {
    const response = await call(`/quizzes/${quizId}/leaderboard`, outsiderToken);
    assertDenied(response.status);
    assert.equal(response.raw.includes('Student A'), false);
  });

  await context.test('the leaderboard puts the best score first', async () => {
    const response = await call<Page<LeaderboardRow>>(`/quizzes/${quizId}/leaderboard`, studentBToken);
    assert.equal(response.status, 200);
    assert.equal(response.body.data[0].rank, 1);
    assert.equal(response.body.data[0].studentName, 'Student A');
    assert.equal(response.body.data[0].score, 2);
    assert.equal(response.body.data[1].rank, 2);
    assert.equal(response.body.data[1].score, 1);
  });

  await context.test('the leaderboard is paginated and the page size is bounded', async () => {
    const onePerPage = await call<Page<LeaderboardRow>>(`/quizzes/${quizId}/leaderboard?page=1&limit=1`, studentAToken);
    assert.equal(onePerPage.status, 200);
    assert.equal(onePerPage.body.data.length, 1);
    assert.deepEqual(onePerPage.body.meta, { page: 1, limit: 1, total: 2 });

    // The server may refuse a huge page size (422) or lower it; it must not accept it as is.
    const huge = await call<Page<LeaderboardRow>>(`/quizzes/${quizId}/leaderboard?page=1&limit=100000`, studentAToken);
    assert.ok(
      huge.status === 422 || (huge.status === 200 && huge.body.meta.limit <= 100),
      `page size was not bounded (status ${huge.status})`,
    );
  });
});