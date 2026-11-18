import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';

import { createBigQueryStore } from '../src/bigquery_store.js';
import { createAuthHandler } from '../src/handler.js';
import { createMemoryStore } from '../src/memory_store.js';

const secret = 'e'.repeat(40);

async function start(store = createMemoryStore()) {
  const handle = createAuthHandler({ store, secret, allowedOrigins: ['*'] });
  const server = http.createServer(async (req, res) => {
    if (!(await handle(req, res))) res.end();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const base = `http://127.0.0.1:${server.address().port}`;
  const call = async (method, path, body, token) => {
    const response = await fetch(base + path, {
      method,
      headers: {
        'Content-Type': 'application/json',
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    return { status: response.status, body: await response.json() };
  };
  return {
    store,
    call,
    close: () => new Promise((resolve) => {
      server.close(resolve);
      server.closeAllConnections();
    }),
  };
}

const account = { email: 'ana@exemple.fr', password: 'mot-de-passe-1', nom: 'Lopez', prenom: 'Ana', pseudo: 'ana', regime: 'omnivore' };

test('état du compte : vide, enregistré, relu ; clés inconnues ignorées', async (t) => {
  const api = await start();
  t.after(api.close);
  const { token } = (await api.call('POST', '/auth/register', account)).body;

  assert.deepEqual((await api.call('GET', '/me/state', undefined, token)).body, { state: {}, updated_at: null });

  const state = {
    favorites: ['r1', 'r2'],
    folders: [{ folder_id: 1, label: 'Favoris', color: 4293212469 }],
    folder_recipes: { 1: ['r1'] },
    preferences: { regime: 'vegan', allergies: ['gluten', 'soy'] },
    identity: { prenom: 'Anna', nom: 'Lopez' },
    admin: true,
  };
  const saved = await api.call('PUT', '/me/state', { state }, token);
  assert.equal(saved.status, 200);
  const read = (await api.call('GET', '/me/state', undefined, token)).body;
  assert.equal(read.state.admin, undefined);
  assert.deepEqual(read.state.favorites, ['r1', 'r2']);
  assert.equal(read.updated_at, saved.body.updated_at);

  // Nom et préférences enregistrés prioritaires dans /auth/me et /auth/login.
  const me = (await api.call('GET', '/auth/me', undefined, token)).body;
  assert.equal(me.user.prenom, 'Anna');
  assert.deepEqual(me.preferences, { regime: 'vegan', allergies: 'gluten,soy', intolerances: '' });
  const login = (await api.call('POST', '/auth/login', { email: account.email, password: account.password })).body;
  assert.equal(login.user.prenom, 'Anna');
});

test('état : session requise, taille et forme contrôlées, isolé par compte', async (t) => {
  const api = await start();
  t.after(api.close);
  const ana = (await api.call('POST', '/auth/register', account)).body.token;
  const bob = (await api.call('POST', '/auth/register', { ...account, email: 'bob@exemple.fr', pseudo: 'bob' })).body.token;

  assert.equal((await api.call('GET', '/me/state')).status, 401);
  assert.equal((await api.call('PUT', '/me/state', { state: [] }, ana)).status, 400);
  const huge = { favorites: Array.from({ length: 8000 }, (_, i) => `recette-${i}`) };
  assert.equal((await api.call('PUT', '/me/state', { state: huge }, ana)).status, 413);

  await api.call('PUT', '/me/state', { state: { favorites: ['r9'] } }, ana);
  assert.deepEqual((await api.call('GET', '/me/state', undefined, bob)).body.state, {});
});

test('stockage sans état : 501', async (t) => {
  const store = createMemoryStore();
  delete store.getState;
  delete store.saveState;
  const api = await start(store);
  t.after(api.close);
  const { token } = (await api.call('POST', '/auth/register', account)).body;
  assert.equal((await api.call('GET', '/me/state', undefined, token)).status, 501);
  assert.equal((await api.call('GET', '/auth/me', undefined, token)).status, 200);
});

test('BigQuery : requêtes paramétrées, MERGE pour l enregistrement', async () => {
  const queries = [];
  const bigquery = {
    async query(options) {
      queries.push(options);
      if (options.query.startsWith('SELECT state')) {
        return [[{ state: '{"favorites":["r1"]}', updated_at: { value: '2026-11-18T10:00:00Z' } }]];
      }
      return [[]];
    },
  };
  const store = createBigQueryStore({
    bigquery,
    table: 'p.d.dim_utilisateur',
    stateTable: 'p.d.user_state',
    location: 'EU',
  });

  assert.deepEqual(await store.getState('ana@exemple.fr'), {
    state: { favorites: ['r1'] },
    updated_at: '2026-11-18T10:00:00Z',
  });
  await store.saveState('ana@exemple.fr', '{}', '2026-11-18T10:00:00.000Z');
  assert.match(queries[1].query, /^MERGE `p\.d\.user_state`/);
  assert.deepEqual(queries[1].params, { email: 'ana@exemple.fr', state: '{}', updatedAt: '2026-11-18T10:00:00.000Z' });
  assert.equal(queries[1].location, 'EU');

  assert.throws(() => createBigQueryStore({ bigquery, table: 'p.d.t', stateTable: 'x; DROP' }));
  assert.equal(createBigQueryStore({ bigquery, table: 'p.d.t' }).getState, undefined);
});
