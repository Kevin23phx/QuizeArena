import { Router } from 'express';
import { isDatabaseReady } from '../../config/database.js';

export const healthRouter = Router();

healthRouter.get('/health', (_request, response) => {
  response.status(200).json({ status: 'ok' });
});

healthRouter.get('/ready', (_request, response) => {
  const ready = isDatabaseReady();
  response.status(ready ? 200 : 503).json({
    status: ready ? 'ready' : 'not_ready',
    database: ready ? 'connected' : 'disconnected',
  });
});
