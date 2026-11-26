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

interface UserView {
  id: string;
  name: string;
  email: string;
  role: 'student' | 'teacher';
  createdAt: string;
}

interface LoginData {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  accessTokenExpiresInSeconds: number;
  user: UserView;
}

interface RefreshData {
  accessToken: string;
  refreshToken: string;
  tokenType: string;
  accessTokenExpiresInSeconds: number;
}

interface ApiResult<T> {
  status: number;
  body: T;
  raw: string;
}

interface ErrorBody {
  error: {
    code: string;
    message: string;
    details: unknown[];
  };
}

// ---------- Shared state, filled in by before() ----------

let server: import('node:http').Server;
let baseUrl: string;

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

function register(body: { name?: unknown; email?: unknown; password?: unknown }) {
  return call<{ data: UserView }>('/auth/register', undefined, { method: 'POST', body });
}

function login(body: { email?: unknown; password?: unknown }) {
  return call<{ data: LoginData }>('/auth/login', undefined, { method: 'POST', body });
}

function refresh(body: { refreshToken?: unknown }) {
  return call<{ data: RefreshData }>('/auth/refresh', undefined, { method: 'POST', body });
}

function logout(body: { refreshToken?: unknown }) {
  return call('/auth/logout', undefined, { method: 'POST', body });
}

// Unique email generator to avoid collisions between tests.
let emailCounter = 0;
function uniqueEmail(prefix = 'auth'): string {
  return `${prefix}-${Date.now()}-${++emailCounter}@test.invalid`;
}

// ---------- Test database setup ----------

before(async () => {
  const [{ app }, mongooseModule, userModule, sessionModule] = await Promise.all([
    import('../src/app.js'),
    import('mongoose'),
    import('../src/features/auth/user.model.js'),
    import('../src/features/auth/session.model.js'),
  ]);

  try {
    await mongooseModule.default.connect(mongoUri, { serverSelectionTimeoutMS: 5_000 });
  } catch (error: unknown) {
    throw new Error('Could not connect to the test MongoDB. Check that MongoDB is running and .env.test points to quizarena_test.', { cause: error });
  }

  await Promise.all([
    userModule.UserModel.init(),
    sessionModule.SessionModel.init(),
  ]);
  await Promise.all([
    userModule.UserModel.deleteMany({}),
    sessionModule.SessionModel.deleteMany({}),
  ]);

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

// ================================================================
// 1. INSCRIPTION (POST /auth/register)
// ================================================================

test('register creates a student account', async (context) => {
  const email = uniqueEmail('register');

  await context.test('succeeds with valid fields and returns the user without the password', async () => {
    const response = await register({ name: 'Gloria Test', email, password: 'Secret123' });
    assert.equal(response.status, 201);

    const user = response.body.data;
    assert.equal(user.name, 'Gloria Test');
    assert.equal(user.email, email);
    assert.equal(user.role, 'student');
    assert.ok(user.id, 'user should have an id');
    assert.ok(user.createdAt, 'user should have a createdAt timestamp');

    // The password hash must NEVER be in the response.
    assert.equal(response.raw.includes('passwordHash'), false, 'passwordHash must not leak');
    assert.equal(response.raw.includes('Secret123'), false, 'plain password must not leak');
  });

  await context.test('rejects a duplicate email with 409', async () => {
    const response = await register({ name: 'Another', email, password: 'Secret123' });
    assert.equal(response.status, 409);
    assert.equal((response.body as unknown as ErrorBody).error.code, 'EMAIL_ALREADY_EXISTS');
  });

  await context.test('always assigns the student role, even if teacher is requested', async () => {
    const response = await register({
      name: 'Sneaky',
      email: uniqueEmail('sneaky'),
      password: 'Secret123',
      role: 'teacher',   // should be ignored by strictObject or service
    } as any);
    // strictObject should reject the extra field with 422
    assert.ok(response.status === 422 || response.status === 201,
      `expected 422 (strict) or 201 (ignored), got ${response.status}`);
    if (response.status === 201) {
      assert.equal((response.body as { data: UserView }).data.role, 'student');
    }
  });
});

test('register validates input with Zod', async (context) => {
  await context.test('rejects missing name', async () => {
    const response = await register({ email: uniqueEmail(), password: 'Secret123' });
    assert.equal(response.status, 422);
  });

  await context.test('rejects missing email', async () => {
    const response = await register({ name: 'NoEmail', password: 'Secret123' });
    assert.equal(response.status, 422);
  });

  await context.test('rejects missing password', async () => {
    const response = await register({ name: 'NoPass', email: uniqueEmail() });
    assert.equal(response.status, 422);
  });

  await context.test('rejects an invalid email format', async () => {
    const response = await register({ name: 'Bad', email: 'not-an-email', password: 'Secret123' });
    assert.equal(response.status, 422);
  });

  await context.test('rejects an empty body', async () => {
    const response = await call('/auth/register', undefined, { method: 'POST', body: {} });
    assert.equal(response.status, 422);
  });

  await context.test('rejects a name that exceeds 50 characters', async () => {
    const response = await register({ name: 'A'.repeat(51), email: uniqueEmail(), password: 'Secret123' });
    assert.equal(response.status, 422);
  });

  await context.test('rejects a password that exceeds 20 characters', async () => {
    const response = await register({ name: 'Long', email: uniqueEmail(), password: 'A'.repeat(21) });
    assert.equal(response.status, 422);
  });
});

// ================================================================
// 2. CONNEXION (POST /auth/login)
// ================================================================

test('login returns tokens for valid credentials', async (context) => {
  const email = uniqueEmail('login');
  const password = 'MyPassword1';
  await register({ name: 'Login User', email, password });

  await context.test('succeeds and returns accessToken, refreshToken and user', async () => {
    const response = await login({ email, password });
    assert.equal(response.status, 200);

    const data = response.body.data;
    assert.ok(data.accessToken, 'should have accessToken');
    assert.ok(data.refreshToken, 'should have refreshToken');
    assert.equal(data.tokenType, 'Bearer');
    assert.equal(typeof data.accessTokenExpiresInSeconds, 'number');
    assert.equal(data.user.email, email);
    assert.equal(data.user.role, 'student');

    // The password hash must NEVER be in the response.
    assert.equal(response.raw.includes('passwordHash'), false);
  });

  await context.test('rejects a wrong password with 401', async () => {
    const response = await login({ email, password: 'WrongPassword' });
    assert.equal(response.status, 401);
    assert.equal((response.body as unknown as ErrorBody).error.code, 'INVALID_CREDENTIALS');
  });

  await context.test('rejects an unknown email with 401 (same error, no information leak)', async () => {
    const response = await login({ email: 'nobody@test.invalid', password: 'Whatever1' });
    assert.equal(response.status, 401);
    assert.equal((response.body as unknown as ErrorBody).error.code, 'INVALID_CREDENTIALS');
  });

  await context.test('validates the body with Zod', async () => {
    const empty = await login({});
    assert.equal(empty.status, 422);

    const noPassword = await login({ email });
    assert.equal(noPassword.status, 422);
  });
});

// ================================================================
// 3. REFRESH TOKEN ROTATIF (POST /auth/refresh)
// ================================================================

test('refresh rotates the token and detects replay', async (context) => {
  const email = uniqueEmail('refresh');
  await register({ name: 'Refresh User', email, password: 'RefreshPwd1' });
  const loginResponse = await login({ email, password: 'RefreshPwd1' });
  assert.equal(loginResponse.status, 200);
  const firstRefreshToken = loginResponse.body.data.refreshToken;

  let secondRefreshToken: string;

  await context.test('returns a new accessToken and a new refreshToken', async () => {
    const response = await refresh({ refreshToken: firstRefreshToken });
    assert.equal(response.status, 200);

    const data = response.body.data;
    assert.ok(data.accessToken, 'should return a new accessToken');
    assert.ok(data.refreshToken, 'should return a new refreshToken');
    assert.notEqual(data.refreshToken, firstRefreshToken, 'refreshToken must rotate');
    assert.equal(data.tokenType, 'Bearer');
    secondRefreshToken = data.refreshToken;
  });

  await context.test('the old refresh token no longer works after rotation', async () => {
    const response = await refresh({ refreshToken: firstRefreshToken });
    assert.equal(response.status, 401);
    assert.equal((response.body as unknown as ErrorBody).error.code, 'INVALID_REFRESH_TOKEN');
  });

  await context.test('replay of old token revokes the whole session (the new token stops working too)', async () => {
    // The session should have been revoked by the previous replay detection.
    const response = await refresh({ refreshToken: secondRefreshToken! });
    assert.equal(response.status, 401);
  });

  await context.test('rejects a completely fabricated token', async () => {
    const response = await refresh({ refreshToken: 'this-is-not-a-real-token' });
    assert.equal(response.status, 401);
  });

  await context.test('validates the body with Zod', async () => {
    const empty = await refresh({});
    assert.equal(empty.status, 422);
  });
});

// ================================================================
// 4. DÉCONNEXION (POST /auth/logout)
// ================================================================

test('logout revokes the session', async (context) => {
  const email = uniqueEmail('logout');
  await register({ name: 'Logout User', email, password: 'LogoutPwd1' });
  const loginResponse = await login({ email, password: 'LogoutPwd1' });
  assert.equal(loginResponse.status, 200);
  const refreshToken = loginResponse.body.data.refreshToken;

  await context.test('returns 204 on success', async () => {
    const response = await logout({ refreshToken });
    assert.equal(response.status, 204);
  });

  await context.test('the refresh token no longer works after logout', async () => {
    const response = await refresh({ refreshToken });
    assert.equal(response.status, 401);
  });

  await context.test('logout is idempotent (calling twice does not crash)', async () => {
    const response = await logout({ refreshToken });
    // 204 whether the token is already revoked or unknown.
    assert.equal(response.status, 204);
  });

  await context.test('validates the body with Zod', async () => {
    const empty = await logout({});
    assert.equal(empty.status, 422);
  });
});

// ================================================================
// 5. ACCÈS À UNE ROUTE PROTÉGÉE SANS / AVEC TOKEN INVALIDE
// ================================================================

test('a protected route rejects invalid or missing tokens', async (context) => {
  // We use GET /courses as a known protected route.

  await context.test('returns 401 without an Authorization header', async () => {
    const response = await call('/courses');
    assert.equal(response.status, 401);
  });

  await context.test('returns 401 with a malformed Authorization header', async () => {
    const response = await call('/courses', 'not-a-jwt');
    assert.equal(response.status, 401);
  });

  await context.test('returns 401 with a completely fabricated JWT', async () => {
    const fakeJwt = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U';
    const response = await call('/courses', fakeJwt);
    assert.equal(response.status, 401);
  });

  await context.test('allows access with a valid token', async () => {
    const email = uniqueEmail('protected');
    await register({ name: 'Protected User', email, password: 'ProtPwd1' });
    const loginResponse = await login({ email, password: 'ProtPwd1' });
    assert.equal(loginResponse.status, 200);

    const response = await call('/courses', loginResponse.body.data.accessToken);
    // Should be 200 (empty list) — not 401.
    assert.ok(response.status === 200, `expected 200, got ${response.status}`);
  });
});

// ================================================================
// 6. COHÉRENCE DES SESSIONS MULTIPLES
// ================================================================

test('multiple logins create independent sessions', async (context) => {
  const email = uniqueEmail('multi-session');
  await register({ name: 'MultiSession', email, password: 'MultiPwd1' });

  const session1 = await login({ email, password: 'MultiPwd1' });
  const session2 = await login({ email, password: 'MultiPwd1' });
  assert.equal(session1.status, 200);
  assert.equal(session2.status, 200);
  assert.notEqual(session1.body.data.refreshToken, session2.body.data.refreshToken);

  await context.test('logging out of session 1 does not affect session 2', async () => {
    await logout({ refreshToken: session1.body.data.refreshToken });

    // Session 1 is dead.
    const r1 = await refresh({ refreshToken: session1.body.data.refreshToken });
    assert.equal(r1.status, 401);

    // Session 2 is still alive.
    const r2 = await refresh({ refreshToken: session2.body.data.refreshToken });
    assert.equal(r2.status, 200);
  });
});

