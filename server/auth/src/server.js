// Service autonome : `npm start`. Variables d'environnement :
//   AUTH_SECRET       secret de signature des jetons (32 caractères min.)
//   USERS_TABLE       table BigQuery des utilisateurs (projet.dataset.table)
//   PASSWORD_COLUMN   colonne du hachage (défaut : mdp)
//   USER_ID_COLUMN    colonne identifiant (défaut : user_id)
//   USER_ID_TYPE      string (UUID, défaut) ou int
//   BQ_LOCATION       région BigQuery (ex. EU)
//   ALLOWED_ORIGINS   origines autorisées, séparées par des virgules
//   USER_STATE_TABLE  table des données du compte (sql/user_state.sql)
//   CATALOG_DATASET   dataset des tables recettes (projet.dataset) pour
//                     /catalog/previews ; absent : route désactivée
//   RESET_URL         page de l'app pour le nouveau mot de passe, ex.
//                     https://gdemerges.github.io/ecodiet_web/#/reset_password
//   RESEND_API_KEY    clé Resend pour envoyer les e-mails (Secret Manager)
//   MAIL_FROM         expéditeur, ex. EcoDiet <noreply@domaine-verifie.fr>
//   PORT              port d'écoute (défaut : 8080, fourni par Cloud Run)

import http from 'node:http';

import { createBigQueryStore } from './bigquery_store.js';
import { bigQueryTableLoader, createCatalog } from './catalog.js';
import { createAuthHandler } from './handler.js';
import { createResendMailer } from './mailers.js';

const env = process.env;
for (const name of ['AUTH_SECRET', 'USERS_TABLE']) {
  if (!env[name]) {
    console.error(`Variable d'environnement manquante : ${name}`);
    process.exit(1);
  }
}

const { BigQuery } = await import('@google-cloud/bigquery');
const bigquery = new BigQuery();
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

const port = Number(env.PORT || 8080);
http
  .createServer(async (req, res) => {
    if (await handleAuth(req, res)) return;
    res.statusCode = 404;
    res.end();
  })
  .listen(port, () => console.log(`ecodiet-auth : port ${port}`));
