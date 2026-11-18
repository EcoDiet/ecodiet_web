import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import http from 'node:http';
import test from 'node:test';

import { createAuthHandler, createLoginLimiter } from '../src/handler.js';
import { createMemoryStore } from '../src/memory_store.js';

const secret = 's'.repeat(40);

async function startServer(store, options = {}) {
  const handle = createAuthHandler({ store, secret, allowedOrigins: ['http://localhost:5000'], ...options });
  const server = http.createServer(async (req, res) => {
    if (!(await handle(req, res))) {
      res.statusCode = 418;
      res.end();
    }
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (method, path, body, headers = {}) => {
    const response = await fetch(base + path, {
      method,
      headers: { 'Content-Type': 'application/json', ...headers },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await response.text();
    return { status: response.status, headers: response.headers, body: text ? JSON.parse(text) : null };
  };
  return { call, close: () => new Promise((resolve) => {
    server.close(resolve);
    server.closeAllConnections();
  }) };
}

const newUser = {
  email: ' Ana@Exemple.fr ',
  password: 'motdepasse-solide',
  nom: 'Lopez',
  prenom: 'Ana',
  pseudo: 'ana',
  regime: 'vegetarian',
  allergies: 'gluten',
  role: 'admin', // champ non autorisé : ignoré
};

test('inscription, connexion et /auth/me', async (t) => {
  const store = createMemoryStore();
  const api = await startServer(store);
  t.after(api.close);

  const created = await api.call('POST', '/auth/register', newUser);
  assert.equal(created.status, 201);
  assert.equal(created.body.user.email, 'ana@exemple.fr');
  assert.ok(created.body.token);
  assert.equal(created.body.user.mdp, undefined, 'le hachage ne sort jamais');
  assert.match(store.rows[0].mdp, /^scrypt\$/);
  assert.equal(store.rows[0].role, undefined);

  assert.equal((await api.call('POST', '/auth/register', newUser)).status, 409);

  const login = await api.call('POST', '/auth/login', { email: 'ANA@exemple.fr', password: newUser.password });
  assert.equal(login.status, 200);
  assert.equal(login.body.user.prenom, 'Ana');

  const me = await api.call('GET', '/auth/me', undefined, { Authorization: `Bearer ${login.body.token}` });
  assert.equal(me.status, 200);
  assert.deepEqual(me.body.preferences, { regime: 'vegetarian', allergies: 'gluten', intolerances: '' });

  assert.equal((await api.call('GET', '/auth/me')).status, 401);
  assert.equal((await api.call('GET', '/auth/me', undefined, { Authorization: 'Bearer faux' })).status, 401);
});

test('mauvais mot de passe et e-mail inconnu : même réponse', async (t) => {
  const api = await startServer(createMemoryStore());
  t.after(api.close);
  await api.call('POST', '/auth/register', newUser);

  const wrong = await api.call('POST', '/auth/login', { email: newUser.email, password: 'mauvais-mdp' });
  const unknown = await api.call('POST', '/auth/login', { email: 'inconnu@exemple.fr', password: 'mauvais-mdp' });
  assert.equal(wrong.status, 401);
  assert.deepEqual(wrong.body, unknown.body);
});

test('ancien compte SHA-256 : connexion puis re-hachage en scrypt', async (t) => {
  const legacy = createHash('sha256').update('ancien-mdp').digest('hex');
  const store = createMemoryStore([{ user_id: 7, email: 'old@exemple.fr', mdp: legacy, prenom: 'Old' }]);
  const api = await startServer(store);
  t.after(api.close);

  const login = await api.call('POST', '/auth/login', { email: 'old@exemple.fr', password: 'ancien-mdp' });
  assert.equal(login.status, 200);
  assert.equal(login.body.user.user_id, '7');
  assert.match(store.rows[0].mdp, /^scrypt\$/);

  const again = await api.call('POST', '/auth/login', { email: 'old@exemple.fr', password: 'ancien-mdp' });
  assert.equal(again.status, 200);
});

test('re-hachage en échec : la connexion réussit quand même', async (t) => {
  const legacy = createHash('sha256').update('ancien-mdp').digest('hex');
  const store = createMemoryStore([{ user_id: 8, email: 'buf@exemple.fr', mdp: legacy }]);
  store.updatePasswordHash = async () => {
    throw new Error('streaming buffer');
  };
  const api = await startServer(store);
  t.after(api.close);
  const warn = t.mock.method(console, 'warn', () => {});

  const login = await api.call('POST', '/auth/login', { email: 'buf@exemple.fr', password: 'ancien-mdp' });
  assert.equal(login.status, 200);
  assert.equal(warn.mock.callCount(), 1);
});

test('trop d échecs : 429, même avec le bon mot de passe', async (t) => {
  const api = await startServer(createMemoryStore(), {
    limiter: createLoginLimiter({ maxFailures: 3, windowMs: 60_000 }),
  });
  t.after(api.close);
  await api.call('POST', '/auth/register', newUser);

  for (let i = 0; i < 3; i++) {
    assert.equal((await api.call('POST', '/auth/login', { email: newUser.email, password: 'x' })).status, 401);
  }
  const blocked = await api.call('POST', '/auth/login', { email: newUser.email, password: newUser.password });
  assert.equal(blocked.status, 429);
});

test('validation de l inscription', async (t) => {
  const api = await startServer(createMemoryStore());
  t.after(api.close);
  const cases = [
    { ...newUser, email: 'pas-un-email' },
    { ...newUser, password: 'court' },
    { ...newUser, pseudo: '  ' },
  ];
  for (const body of cases) {
    assert.equal((await api.call('POST', '/auth/register', body)).status, 400);
  }
});

test('disponibilité d un e-mail, CORS et routes hors /auth', async (t) => {
  const api = await startServer(createMemoryStore());
  t.after(api.close);
  await api.call('POST', '/auth/register', newUser);

  assert.deepEqual((await api.call('POST', '/auth/email-available', { email: 'ana@exemple.fr' })).body, { available: false });
  assert.deepEqual((await api.call('POST', '/auth/email-available', { email: 'new@exemple.fr' })).body, { available: true });

  assert.deepEqual((await api.call('POST', '/auth/pseudo-available', { pseudo: ' ANA ' })).body, { available: false });
  assert.deepEqual((await api.call('POST', '/auth/pseudo-available', { pseudo: 'bob' })).body, { available: true });
  assert.equal((await api.call('POST', '/auth/pseudo-available', {})).status, 400);

  const preflight = await api.call('OPTIONS', '/auth/login', undefined, { Origin: 'http://localhost:5000' });
  assert.equal(preflight.status, 204);
  assert.equal(preflight.headers.get('access-control-allow-origin'), 'http://localhost:5000');
  const foreign = await api.call('OPTIONS', '/auth/login', undefined, { Origin: 'https://pirate.example' });
  assert.equal(foreign.headers.get('access-control-allow-origin'), null);

  assert.equal((await api.call('GET', '/autre')).status, 418, 'laissé au service existant');
  assert.equal((await api.call('GET', '/auth/inconnue')).status, 404);
});

test('secret trop court refusé au démarrage', () => {
  assert.throws(() => createAuthHandler({ store: createMemoryStore(), secret: 'court' }));
});
