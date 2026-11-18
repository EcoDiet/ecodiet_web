// Routes d'authentification EcoDiet, utilisables seules (src/server.js) ou
// branchées dans le service Cloud Run existant :
//
//   const auth = createAuthHandler({ store, secret, allowedOrigins });
//   http.createServer(async (req, res) => {
//     if (await auth(req, res)) return;   // route /auth/* traitée
//     ...routes existantes...
//   });
//
// Routes (JSON) :
//   POST /auth/register        {email, password, nom, prenom, pseudo, ...profil}
//   POST /auth/login           {email, password}            -> {token, user}
//   POST /auth/email-available {email}                      -> {available}
//   POST /auth/pseudo-available {pseudo}                    -> {available}
//   GET  /auth/me              Authorization: Bearer <jeton> -> {user, preferences}
//   POST /auth/password-reset/request {email}               -> {ok} (toujours)
//   POST /auth/password-reset/confirm {token, password}     -> {ok}

import { createHash } from 'node:crypto';

import { burnTime, hashPassword, verifyPassword } from './passwords.js';
import { createToken, verifyToken } from './tokens.js';

const MAX_BODY_BYTES = 16 * 1024;
const MIN_PASSWORD_LENGTH = 8;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** Champs de profil acceptés à l'inscription (les autres sont ignorés). */
export const PROFILE_FIELDS = [
  'nom',
  'prenom',
  'pseudo',
  'regime',
  'allergies',
  'objectif',
  'genre',
  'age',
  'taille',
  'poids',
  'niveau_activite',
  'budget_par_repas',
  'tolerance_epice',
  'cuisine_preferee',
  'fenetre_temps_soir_min',
];

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

const normalizeEmail = (value) =>
  typeof value === 'string' ? value.trim().toLowerCase() : '';

/** Données d'un utilisateur renvoyées à l'app : jamais le hachage. */
export function publicUser(row) {
  return {
    user_id: String(row.user_id ?? row.id ?? ''),
    email: row.email,
    nom: row.nom ?? null,
    prenom: row.prenom ?? null,
    pseudo: row.pseudo ?? null,
  };
}

function preferencesOf(row) {
  const first = (...keys) => {
    for (const key of keys) {
      const value = String(row[key] ?? '').trim();
      if (value) return value;
    }
    return '';
  };
  return {
    regime: first('regime_alimentaire', 'regime', 'diet'),
    allergies: first('allergies', 'allergenes'),
    intolerances: first('intolerances', 'intolerance'),
  };
}

/**
 * Limite les échecs de connexion par adresse IP et e-mail. En mémoire : sur
 * Cloud Run, la limite vaut par instance.
 */
export function createLoginLimiter({ maxFailures = 5, windowMs = 15 * 60 * 1000 } = {}) {
  const failures = new Map();
  const recent = (key, now) =>
    (failures.get(key) ?? []).filter((time) => now - time < windowMs);
  return {
    isBlocked(key, now = Date.now()) {
      return recent(key, now).length >= maxFailures;
    },
    fail(key, now = Date.now()) {
      failures.set(key, [...recent(key, now), now]);
    },
    reset(key) {
      failures.delete(key);
    },
  };
}

async function readJson(req) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) throw new HttpError(413, 'Requête trop volumineuse.');
    chunks.push(chunk);
  }
  if (!chunks.length) return {};
  try {
    const body = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (body && typeof body === 'object' && !Array.isArray(body)) return body;
  } catch {
    // traité ci-dessous
  }
  throw new HttpError(400, 'Corps JSON invalide.');
}

function clientIp(req) {
  const forwarded = String(req.headers['x-forwarded-for'] ?? '').split(',')[0].trim();
  return forwarded || req.socket?.remoteAddress || 'inconnue';
}

/**
 * @param {object} options
 * @param {{findByEmail: Function, findByPseudo: Function, createUser: Function, updatePasswordHash: Function, passwordHashOf: Function}} options.store
 * @param {string} options.secret secret de signature des jetons (32 caractères minimum)
 * @param {string[]} [options.allowedOrigins] origines autorisées (CORS), `*` pour toutes
 * @param {number} [options.ttlSeconds] durée de validité du jeton
 * @param {{send: Function}} [options.mailer] envoi des e-mails ; sans lui, la
 *   réinitialisation du mot de passe répond 503
 * @param {string} [options.resetUrl] page de l'app qui reçoit `?token=`
 * @returns {(req, res) => Promise<boolean>} vrai si la requête a été traitée
 */
export function createAuthHandler({
  store,
  secret,
  allowedOrigins = [],
  ttlSeconds = 7 * 24 * 3600,
  limiter = createLoginLimiter(),
  resetLimiter = createLoginLimiter({ maxFailures: 3, windowMs: 60 * 60 * 1000 }),
  mailer,
  resetUrl = '',
  resetTtlSeconds = 3600,
  now = () => Date.now(),
}) {
  if (!secret || secret.length < 32) {
    throw new Error('AUTH_SECRET doit contenir au moins 32 caractères.');
  }

  const issue = (row) => ({
    token: createToken(
      { sub: String(row.user_id ?? row.id ?? ''), email: row.email },
      { secret, ttlSeconds, now: now() },
    ),
    user: publicUser(row),
  });

  // Empreinte courte du hachage actuel : un lien de réinitialisation devient
  // caduc dès que le mot de passe change (usage unique).
  const passwordStamp = (row) =>
    createHash('sha256').update(store.passwordHashOf(row)).digest('base64url').slice(0, 16);

  /** Jeton de session valide (pas un jeton de réinitialisation). */
  const sessionClaims = (req) => {
    const header = String(req.headers.authorization ?? '');
    const token = header.startsWith('Bearer ') ? header.slice(7) : '';
    const claims = verifyToken(token, { secret, now: now() });
    return claims && !claims.purpose ? claims : null;
  };

  const routes = {
    'POST /auth/register': async (req) => {
      const body = await readJson(req);
      const email = normalizeEmail(body.email);
      const password = typeof body.password === 'string' ? body.password : '';
      if (!EMAIL_PATTERN.test(email)) throw new HttpError(400, 'E-mail invalide.');
      if (password.length < MIN_PASSWORD_LENGTH) {
        throw new HttpError(
          400,
          `Le mot de passe doit contenir au moins ${MIN_PASSWORD_LENGTH} caractères.`,
        );
      }
      for (const field of ['nom', 'prenom', 'pseudo']) {
        if (!String(body[field] ?? '').trim()) {
          throw new HttpError(400, 'Nom, prénom et pseudo sont requis.');
        }
      }
      if (await store.findByEmail(email)) {
        throw new HttpError(409, 'Cet e-mail est déjà inscrit.');
      }
      const profile = {};
      for (const field of PROFILE_FIELDS) {
        if (body[field] !== undefined && body[field] !== null) profile[field] = body[field];
      }
      const row = await store.createUser({
        ...profile,
        email,
        passwordHash: await hashPassword(password),
      });
      return [201, issue(row)];
    },

    'POST /auth/login': async (req) => {
      const body = await readJson(req);
      const email = normalizeEmail(body.email);
      const password = typeof body.password === 'string' ? body.password : '';
      const key = `${clientIp(req)}|${email}`;
      if (limiter.isBlocked(key, now())) {
        throw new HttpError(429, 'Trop de tentatives. Réessaie dans quelques minutes.');
      }
      const row = email ? await store.findByEmail(email) : null;
      const stored = row ? store.passwordHashOf(row) : '';
      let check = { ok: false, needsRehash: false };
      if (stored) {
        check = await verifyPassword(password, stored);
      } else {
        await burnTime(password); // même durée qu'un e-mail existant
      }
      if (!check.ok) {
        limiter.fail(key, now());
        throw new HttpError(401, 'Identifiants invalides.');
      }
      limiter.reset(key);
      if (check.needsRehash) {
        try {
          await store.updatePasswordHash(row, await hashPassword(password));
        } catch (error) {
          // Ex. BigQuery : UPDATE impossible sur une ligne encore dans le
          // tampon de streaming. Nouvel essai à la prochaine connexion.
          console.warn('auth: re-hachage reporté :', error.message);
        }
      }
      return [200, issue(row)];
    },

    'POST /auth/email-available': async (req) => {
      const body = await readJson(req);
      const email = normalizeEmail(body.email);
      if (!EMAIL_PATTERN.test(email)) throw new HttpError(400, 'E-mail invalide.');
      return [200, { available: !(await store.findByEmail(email)) }];
    },

    'POST /auth/pseudo-available': async (req) => {
      const body = await readJson(req);
      const pseudo = typeof body.pseudo === 'string' ? body.pseudo.trim().toLowerCase() : '';
      if (!pseudo || pseudo.length > 64) throw new HttpError(400, 'Pseudo invalide.');
      return [200, { available: !(await store.findByPseudo(pseudo)) }];
    },

    'GET /auth/me': async (req) => {
      const claims = sessionClaims(req);
      if (!claims) throw new HttpError(401, 'Session expirée ou invalide.');
      const row = await store.findByEmail(claims.email);
      if (!row) throw new HttpError(401, 'Session expirée ou invalide.');
      return [200, { user: publicUser(row), preferences: preferencesOf(row) }];
    },

    'POST /auth/password-reset/request': async (req) => {
      if (!mailer || !resetUrl) {
        throw new HttpError(503, 'Réinitialisation du mot de passe indisponible.');
      }
      const body = await readJson(req);
      const email = normalizeEmail(body.email);
      if (!EMAIL_PATTERN.test(email)) throw new HttpError(400, 'E-mail invalide.');
      // Même réponse que le compte existe ou non (pas d'énumération).
      const key = `reset|${email}`;
      if (resetLimiter.isBlocked(key, now())) return [200, { ok: true }];
      resetLimiter.fail(key, now());
      const row = await store.findByEmail(email);
      if (row && store.passwordHashOf(row)) {
        const token = createToken(
          { email, purpose: 'reset', stamp: passwordStamp(row) },
          { secret, ttlSeconds: resetTtlSeconds, now: now() },
        );
        const link = `${resetUrl}${resetUrl.includes('?') ? '&' : '?'}token=${token}`;
        try {
          await mailer.send({
            to: email,
            subject: 'EcoDiet : réinitialiser ton mot de passe',
            text:
              `Bonjour,\n\nPour choisir un nouveau mot de passe, ouvre ce lien ` +
              `(valable ${Math.round(resetTtlSeconds / 60)} minutes) :\n${link}\n\n` +
              `Si tu n'as rien demandé, ignore cet e-mail.`,
          });
        } catch (error) {
          console.error('auth: e-mail de réinitialisation non envoyé :', error.message);
        }
      }
      return [200, { ok: true }];
    },

    'POST /auth/password-reset/confirm': async (req) => {
      const body = await readJson(req);
      const password = typeof body.password === 'string' ? body.password : '';
      const claims = verifyToken(body.token, { secret, now: now() });
      const invalid = new HttpError(400, 'Lien invalide ou expiré. Refais une demande.');
      if (!claims || claims.purpose !== 'reset') throw invalid;
      if (password.length < MIN_PASSWORD_LENGTH) {
        throw new HttpError(
          400,
          `Le mot de passe doit contenir au moins ${MIN_PASSWORD_LENGTH} caractères.`,
        );
      }
      const row = await store.findByEmail(claims.email);
      if (!row || passwordStamp(row) !== claims.stamp) throw invalid;
      await store.updatePasswordHash(row, await hashPassword(password));
      limiter.reset(`${clientIp(req)}|${claims.email}`);
      return [200, { ok: true }];
    },
  };

  function applyCors(req, res) {
    const origin = req.headers.origin;
    if (!origin) return;
    if (allowedOrigins.includes('*') || allowedOrigins.includes(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin);
      res.setHeader('Vary', 'Origin');
      res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
      res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      res.setHeader('Access-Control-Max-Age', '3600');
    }
  }

  function send(res, status, payload) {
    res.statusCode = status;
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.setHeader('Cache-Control', 'no-store');
    res.end(JSON.stringify(payload));
  }

  return async function handleAuth(req, res) {
    const path = new URL(req.url ?? '/', 'http://localhost').pathname.replace(/\/+$/, '');
    if (!path.startsWith('/auth/')) return false;
    applyCors(req, res);
    if (req.method === 'OPTIONS') {
      res.statusCode = 204;
      res.end();
      return true;
    }
    const route = routes[`${req.method} ${path}`];
    if (!route) {
      send(res, 404, { error: 'Route inconnue.' });
      return true;
    }
    try {
      const [status, payload] = await route(req);
      send(res, status, payload);
    } catch (error) {
      if (error instanceof HttpError) {
        send(res, error.status, { error: error.message });
      } else {
        console.error('auth:', error);
        send(res, 500, { error: 'Erreur interne.' });
      }
    }
    return true;
  };
}
