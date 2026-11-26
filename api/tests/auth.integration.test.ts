import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import dotenv from 'dotenv';

dotenv.config({ path: '.env' });
dotenv.config({ path: '.env.test', override: true });
process.env.NODE_ENV = 'test';

const mongoUri = process.env.MONGODB_URI;
if (!mongoUri?.split('?')[0].endsWith('/quizarena_test')) {
  throw new Error('Tests require a separate MongoDB database named quizarena_test.');
}

let server: import('node:http').Server;
let baseUrl: string;

before(async () => {
  const [{ app }, mongooseModule, userModule, sessionModule] = await Promise.all([
    import('../src/app.js'),
    import('mongoose'),
    import('../src/features/auth/user.model.js'),
    import('../src/features/auth/session.model.js'),
  ]);

  await mongooseModule.default.connect(mongoUri, { serverSelectionTimeoutMS: 5_000 });
  await Promise.all([userModule.UserModel.init(), sessionModule.SessionModel.init()]);
  await Promise.all([userModule.UserModel.deleteMany({}), sessionModule.SessionModel.deleteMany({})]);

  server = app.listen(0);
  await new Promise<void>((resolve, reject) => {
    server.once('listening', resolve);
    server.once('error', reject);
  });
  const address = server.address();
  if (!address || typeof address === 'string') {
    throw new Error('Could not determine test server address.');
  }
  baseUrl = `http://127.0.0.1:${address.port}`;
});

after(async () => {
  if (server?.listening) {
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
  }
  const mongooseModule = await import('mongoose');
  await mongooseModule.default.disconnect();
});

test('register validates, rejects duplicates, and creates a student', async (context) => {
  await context.test('creates a student with 201', async () => {
    const response = await fetch(`${baseUrl}/api/v1/auth/register`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        name: 'Auth Student',
        email: 'auth@example.com',
        password: 'StrongPass123',
      }),
    });
    const body = await response.json() as { data: { role: string } };

    assert.equal(response.status, 201);
    assert.equal(body.data.role, 'student');
  });

  await context.test('rejects unknown fields and invalid values with 422', async () => {
    const response = await fetch(`${baseUrl}/api/v1/auth/register`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        name: '',
        email: 'invalid',
        password: 'toolongpassword12345',
        role: 'teacher',
      }),
    });
    assert.equal(response.status, 422);
  });

  await context.test('rejects a duplicate email with 409', async () => {
    const response = await fetch(`${baseUrl}/api/v1/auth/register`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        name: 'Another Student',
        email: 'auth@example.com',
        password: 'StrongPass123',
      }),
    });
    assert.equal(response.status, 409);
  });
});

test('login, refresh, reuse detection, logout, and protected route', async (context) => {
  await context.test('logs in and receives a token pair', async () => {
    const response = await fetch(`${baseUrl}/api/v1/auth/login`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        email: 'auth@example.com',
        password: 'StrongPass123',
      }),
    });
    const body = await response.json() as {
      data: { accessToken: string; refreshToken: string; user: { role: string } };
    };

    assert.equal(response.status, 200);
    assert.equal(typeof body.data.accessToken, 'string');
    assert.equal(typeof body.data.refreshToken, 'string');
    assert.equal(body.data.user.role, 'student');

    await context.test('rejects bad credentials with 401', async () => {
      const badResponse = await fetch(`${baseUrl}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          email: 'auth@example.com',
          password: 'wrong-password',
        }),
      });
      assert.equal(badResponse.status, 401);
    });

    const refreshResponse = await fetch(`${baseUrl}/api/v1/auth/refresh`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refreshToken: body.data.refreshToken }),
    });
    const refreshBody = await refreshResponse.json() as {
      data: { accessToken: string; refreshToken: string };
    };

    assert.equal(refreshResponse.status, 200);
    assert.notEqual(refreshBody.data.refreshToken, body.data.refreshToken);

    await context.test('rejects reuse and revokes the session', async () => {
      const reusedResponse = await fetch(`${baseUrl}/api/v1/auth/refresh`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ refreshToken: body.data.refreshToken }),
      });
      assert.equal(reusedResponse.status, 401);
    });

    await context.test('accesses a protected route with the new access token', async () => {
      const response = await fetch(`${baseUrl}/api/v1/courses`, {
        headers: { authorization: `Bearer ${refreshBody.data.accessToken}` },
      });
      assert.equal(response.status, 200);
    });

    await context.test('logs out with 204 and invalidates subsequent refresh', async () => {
      const logoutResponse = await fetch(`${baseUrl}/api/v1/auth/logout`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ refreshToken: refreshBody.data.refreshToken }),
      });
      assert.equal(logoutResponse.status, 204);

      const refreshAfterLogout = await fetch(`${baseUrl}/api/v1/auth/refresh`, {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ refreshToken: refreshBody.data.refreshToken }),
      });
      assert.equal(refreshAfterLogout.status, 401);
    });
  });

  await context.test('rejects protected routes without a token', async () => {
    const response = await fetch(`${baseUrl}/api/v1/courses`);
    assert.equal(response.status, 401);
  });
});
