import { app } from './app.js';
import { connectToDatabase, disconnectFromDatabase } from './config/database.js';
import { env } from './config/env.js';

async function startServer(): Promise<void> {
  await connectToDatabase();

  const server = app.listen(env.PORT, () => {
    console.info(`QuizArena API listening on port ${env.PORT}.`);
  });

  const shutdown = (signal: string): void => {
    console.info(`${signal} received; closing the API.`);
    server.close(() => {
      void disconnectFromDatabase().finally(() => process.exit(0));
    });
  };

  process.on('SIGINT', () => shutdown('SIGINT'));
  process.on('SIGTERM', () => shutdown('SIGTERM'));
}

startServer().catch((error: unknown) => {
  console.error('API startup failed:', error);
  process.exit(1);
});
