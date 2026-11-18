import { BigQuery } from '@google-cloud/bigquery';

import { createBigQueryStore } from '../src/bigquery_store.js';
import { bigQueryTableLoader, createCatalog } from '../src/catalog.js';
import { createAuthHandler } from '../src/handler.js';
import { createResendMailer } from '../src/mailers.js';

const env = process.env;

for (const name of ['AUTH_SECRET', 'USERS_TABLE']) {
  if (!env[name]) {
    throw new Error(`Variable d'environnement manquante : ${name}`);
  }
}

const credentials = env.GOOGLE_SERVICE_ACCOUNT_JSON
  ? JSON.parse(env.GOOGLE_SERVICE_ACCOUNT_JSON)
  : undefined;

const bigquery = new BigQuery(
  credentials
    ? { credentials, projectId: credentials.project_id }
    : undefined,
);

const store = createBigQueryStore({
  bigquery,
  table: env.USERS_TABLE,
  passwordColumn: env.PASSWORD_COLUMN || 'mdp',
  idColumn: env.USER_ID_COLUMN || 'user_id',
  idType: env.USER_ID_TYPE === 'int' ? 'int' : 'string',
  location: env.BQ_LOCATION || undefined,
  stateTable: env.USER_STATE_TABLE || undefined,
});

const handleAuth = createAuthHandler({
  store,
  secret: env.AUTH_SECRET,
  allowedOrigins: (env.ALLOWED_ORIGINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
  resetUrl: env.RESET_URL || '',
  catalog: env.CATALOG_DATASET
    ? createCatalog({
        loadTable: bigQueryTableLoader({
          bigquery,
          dataset: env.CATALOG_DATASET,
          location: env.BQ_LOCATION || undefined,
        }),
      })
    : undefined,
  mailer: env.RESEND_API_KEY
    ? createResendMailer({ apiKey: env.RESEND_API_KEY, from: env.MAIL_FROM })
    : undefined,
});

export default async function handler(req, res) {
  // Vercel reçoit /api/auth/login ; le routeur attend /auth/login.
  const originalUrl = req.url;
  req.url = (req.url || '/').replace(/^\/api(?=\/|$)/, '') || '/';

  try {
    if (await handleAuth(req, res)) return;

    res.statusCode = 404;
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.end(JSON.stringify({ error: 'Route inconnue.' }));
  } finally {
    req.url = originalUrl;
  }
}