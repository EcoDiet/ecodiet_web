// Serveur de développement : stockage en mémoire, toutes origines acceptées.
// `npm run dev` (PORT, défaut 8790). Ne jamais déployer.

import { randomBytes } from 'node:crypto';
import http from 'node:http';

import { createAuthHandler } from './handler.js';
import { createConsoleMailer } from './mailers.js';
import { createMemoryStore } from './memory_store.js';

const handleAuth = createAuthHandler({
  store: createMemoryStore(),
  secret: randomBytes(32).toString('hex'),
  allowedOrigins: ['*'],
  mailer: createConsoleMailer(),
  resetUrl: process.env.RESET_URL || 'http://127.0.0.1:8788/#/reset_password',
});

const port = Number(process.env.PORT || 8790);
http
  .createServer(async (req, res) => {
    if (await handleAuth(req, res)) return;
    res.statusCode = 404;
    res.end();
  })
  .listen(port, '127.0.0.1', () => console.log(`ecodiet-auth (dev, mémoire) : http://127.0.0.1:${port}`));
