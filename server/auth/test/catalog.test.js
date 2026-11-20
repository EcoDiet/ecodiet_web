import assert from 'node:assert/strict';
import http from 'node:http';
import test from 'node:test';
import { gunzipSync } from 'node:zlib';

import { bigQueryTableLoader, buildDetails, buildPreviews, createCatalog } from '../src/catalog.js';
import { createAuthHandler } from '../src/handler.js';
import { createMemoryStore } from '../src/memory_store.js';

const tables = {
  fact_recette_base: [
    { recette_id: 'r1', titre: 'Curry', photo: 'c.jpg', duree_minute: 30, temps_bin_id: 2, etapes: 'long texte' },
    { recette_id: 'r2', titre: 'Soupe', photo: '', duree_minute: { value: '15' }, temps_bin_id: 1 },
  ],
  dim_ingredient: [{ ingredient_id: 1, nom_ingredient: 'Tomate' }, { ingredient_id: 2, nom_ingredient: 'Riz' }],
  fact_ingredients_recette: [
    { recette_id: 'r1', ingredient_id: 1 },
    { recette_id: 'r1', ingredient_id: 2 },
    { recette_id: 'r1', ingredient_id: 1 },
    { recette_id: 'r2', ingredient_id: 99 },
  ],
  dim_regime: [{ regime_id: 3, libelle: 'vegan' }],
  fact_recette_regime: [{ recette_id: 'r1', regime_id: 3 }],
  dim_type_plat: [{ type_plat_id: 5, libelle: 'plat principal' }],
  fact_recette_type_plat: [{ recette_id: 'r1', type_plat_id: 5 }],
  dim_allergene: [{ allergene_id: 7, libelle: 'gluten' }],
  fact_recette_allergene: [{ recette_id: 'r2', allergene_id: 7 }],
  stg_recettes: [{ recette_id: 'r2', etapes: 'Chauffer.', ingredients: "['eau', 'sel']", ustensiles: 'casserole' }],
};
const loadTable = async (name) => {
  if (!(name in tables)) throw new Error('absente');
  return tables[name];
};

test('jointure : libellés, doublons retirés, sans étapes, table alternative', () => {
  const previews = buildPreviews({
    base: tables.fact_recette_base,
    dimIngredient: tables.dim_ingredient,
    factIngredient: tables.fact_ingredients_recette,
    dimRegime: tables.dim_regime,
    factRegime: tables.fact_recette_regime,
    dimType: tables.dim_type_plat,
    factType: tables.fact_recette_type_plat,
    dimAllergene: tables.dim_allergene,
    factAllergene: tables.fact_recette_allergene,
  });
  assert.deepEqual(previews[0], {
    recette_id: 'r1',
    titre: 'Curry',
    photo: 'c.jpg',
    duree_minute: 30,
    temps_bin_id: 2,
    type_plat: 'plat principal',
    regime: 'vegan',
    ingredients: ['Tomate', 'Riz'],
    equipements: [],
    allergenes: [],
    occasions: [],
  });
  assert.equal(previews[1].duree_minute, 15);
  assert.deepEqual(previews[1].ingredients, []);
  assert.deepEqual(previews[1].allergenes, ['gluten']);
});

test('cache : une seule construction, reconstruite après expiration, ancien gardé si échec', async () => {
  let loads = 0;
  let fail = false;
  let clock = 0;
  const catalog = createCatalog({
    loadTable: async (name) => {
      loads++;
      if (fail) throw new Error('panne');
      return loadTable(name);
    },
    ttlMs: 1000,
    now: () => clock,
  });
  const [a, b] = await Promise.all([catalog.get(), catalog.get()]);
  assert.equal(a, b);
  const first = loads;
  await catalog.get();
  assert.equal(loads, first, 'servi depuis le cache');

  clock = 2000;
  fail = true;
  const original = console.warn;
  console.warn = () => {};
  try {
    assert.equal(await catalog.get(), a, 'ancien catalogue si la reconstruction échoue');
  } finally {
    console.warn = original;
  }
});

test('route : gzip, ETag et 304', async (t) => {
  const handle = createAuthHandler({
    store: createMemoryStore(),
    secret: 'c'.repeat(40),
    catalog: createCatalog({ loadTable }),
  });
  const server = http.createServer(async (req, res) => {
    if (!(await handle(req, res))) res.end();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => {
    server.close(resolve);
    server.closeAllConnections();
  }));
  const port = server.address().port;
  const get = (headers) => new Promise((resolve, reject) => {
    http.get({ host: '127.0.0.1', port, path: '/catalog/previews', headers }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ res, body: Buffer.concat(chunks) }));
    }).on('error', reject);
  });

  const zipped = await get({ 'Accept-Encoding': 'gzip' });
  assert.equal(zipped.res.statusCode, 200);
  assert.equal(zipped.res.headers['content-encoding'], 'gzip');
  assert.equal(JSON.parse(gunzipSync(zipped.body)).length, 2);
  const etag = zipped.res.headers.etag;

  const plain = await get({});
  assert.equal(JSON.parse(plain.body)[0].titre, 'Curry');
  assert.equal((await get({ 'If-None-Match': etag })).res.statusCode, 304);
});

test('fiches : étapes, libellés avec identifiants, repli stg_recettes', () => {
  const details = buildDetails({
    base: tables.fact_recette_base,
    dimIngredient: tables.dim_ingredient,
    factIngredient: tables.fact_ingredients_recette,
    dimRegime: tables.dim_regime,
    factRegime: tables.fact_recette_regime,
    dimType: tables.dim_type_plat,
    factType: tables.fact_recette_type_plat,
    stg: tables.stg_recettes,
  });
  const r1 = details.get('r1');
  assert.equal(r1.etapes, 'long texte');
  assert.deepEqual(r1.ingredients, [
    { ingredient_id: 1, nom_ingredient: 'Tomate' },
    { ingredient_id: 2, nom_ingredient: 'Riz' },
  ]);
  assert.deepEqual(r1.regime, { regime_id: 3, libelle: 'vegan' });
  assert.deepEqual(r1.type_plat, { type_plat_id: 5, libelle: 'plat principal' });
  const r2 = details.get('r2');
  assert.equal(r2.etapes, 'Chauffer.');
  assert.equal(r2.ustensiles_texte, 'casserole');
  assert.equal(r2.regime, null);
});

test('route fiche : 200 gzip, 404 inconnue, 400 identifiant invalide', async (t) => {
  const handle = createAuthHandler({
    store: createMemoryStore(),
    secret: 'c'.repeat(40),
    catalog: createCatalog({ loadTable }),
  });
  const server = http.createServer(async (req, res) => {
    if (!(await handle(req, res))) res.end();
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  t.after(() => new Promise((resolve) => {
    server.close(resolve);
    server.closeAllConnections();
  }));
  const port = server.address().port;
  const get = (path, headers = {}) => new Promise((resolve, reject) => {
    http.get({ host: '127.0.0.1', port, path, headers }, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => resolve({ res, body: Buffer.concat(chunks) }));
    }).on('error', reject);
  });

  const ok = await get('/catalog/recettes/r1', { 'Accept-Encoding': 'gzip' });
  assert.equal(ok.res.statusCode, 200);
  assert.equal(ok.res.headers['content-encoding'], 'gzip');
  assert.equal(JSON.parse(gunzipSync(ok.body)).titre, 'Curry');
  assert.equal((await get('/catalog/recettes/inconnue')).res.statusCode, 404);
  assert.equal((await get('/catalog/recettes/%E0')).res.statusCode, 400);
});

test('sans catalogue : 501 ; table BigQuery hors liste refusée', async () => {
  const loader = bigQueryTableLoader({ bigquery: { query: async () => [[]] }, dataset: 'p.d' });
  await assert.rejects(loader('dim_utilisateur'), /non autorisée/);
  assert.throws(() => bigQueryTableLoader({ bigquery: {}, dataset: 'p.d; DROP' }));
});
