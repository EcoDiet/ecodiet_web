// Catalogue des vignettes de recettes : jointure des tables faite une fois
// côté serveur (au lieu de 13 tables brutes, ~850 Ko, téléchargées et jointes
// par chaque navigateur), sans les étapes, gardée en mémoire et servie
// compressée avec un ETag.

import { createHash } from 'node:crypto';
import { gzipSync } from 'node:zlib';

/** Tables lues (noms alternatifs dans l'ordre d'essai). */
export const CATALOG_TABLES = {
  base: ['fact_recette_base'],
  dimIngredient: ['dim_ingredients', 'dim_ingredient'],
  factIngredient: ['fact_ingredients_recette'],
  dimEquipement: ['dim_equipement'],
  factEquipement: ['fact_recette_equipements', 'fact_recette_equipement'],
  dimRegime: ['dim_regime'],
  factRegime: ['fact_recette_regime'],
  dimAllergene: ['dim_allergene'],
  factAllergene: ['fact_recette_allergene'],
  dimOccasion: ['dim_occasion'],
  factOccasion: ['fact_recette_occasion'],
  dimType: ['dim_type_plat'],
  factType: ['fact_recette_type_plat'],
};

const toInt = (value) => {
  const n = Number(value?.value ?? value);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
};
const text = (value) => String(value ?? '').trim();

/** Même jointure que l'app (ecodiet_api.dart, _bridgeBuildPreviewsFromBase). */
export function buildPreviews(t) {
  const index = (rows, idKey, labelKey) =>
    new Map((rows ?? []).map((r) => [toInt(r[idKey]), text(r[labelKey])]));
  const many = (facts, dim, idKey) => {
    const out = new Map();
    for (const r of facts ?? []) {
      const rid = text(r.recette_id);
      const label = dim.get(toInt(r[idKey])) ?? '';
      if (!rid || !label) continue;
      if (!out.has(rid)) out.set(rid, []);
      if (!out.get(rid).includes(label)) out.get(rid).push(label);
    }
    return out;
  };
  const one = (facts, dim, idKey) => {
    const out = new Map();
    for (const r of facts ?? []) {
      const rid = text(r.recette_id);
      const label = dim.get(toInt(r[idKey])) ?? '';
      if (rid && label) out.set(rid, label);
    }
    return out;
  };

  const ingredients = many(t.factIngredient, index(t.dimIngredient, 'ingredient_id', 'nom_ingredient'), 'ingredient_id');
  const equipements = many(t.factEquipement, index(t.dimEquipement, 'equipement_id', 'nom_equipement'), 'equipement_id');
  const allergenes = many(t.factAllergene, index(t.dimAllergene, 'allergene_id', 'libelle'), 'allergene_id');
  const occasions = many(t.factOccasion, index(t.dimOccasion, 'occasion_id', 'libelle'), 'occasion_id');
  const regimes = one(t.factRegime, index(t.dimRegime, 'regime_id', 'libelle'), 'regime_id');
  const types = one(t.factType, index(t.dimType, 'type_plat_id', 'libelle'), 'type_plat_id');

  return (t.base ?? []).map((r) => {
    const rid = text(r.recette_id);
    return {
      recette_id: rid,
      titre: text(r.titre),
      photo: text(r.photo),
      duree_minute: toInt(r.duree_minute),
      temps_bin_id: toInt(r.temps_bin_id),
      type_plat: types.get(rid) ?? null,
      regime: regimes.get(rid) ?? null,
      ingredients: ingredients.get(rid) ?? [],
      equipements: equipements.get(rid) ?? [],
      allergenes: allergenes.get(rid) ?? [],
      occasions: occasions.get(rid) ?? [],
    };
  });
}

/**
 * @param {object} options
 * @param {(name: string) => Promise<object[]>} options.loadTable lit une table
 * @param {number} [options.ttlMs] durée du cache (défaut 10 min)
 */
export function createCatalog({ loadTable, ttlMs = 10 * 60 * 1000, now = () => Date.now() }) {
  let cached = null;
  let pending = null;

  async function loadAny(names) {
    for (const name of names) {
      try {
        const rows = await loadTable(name);
        if (rows.length) return rows;
      } catch (error) {
        console.warn(`catalogue : table ${name} illisible :`, error.message);
      }
    }
    return [];
  }

  async function build() {
    const entries = await Promise.all(
      Object.entries(CATALOG_TABLES).map(async ([key, names]) => [key, await loadAny(names)]),
    );
    const previews = buildPreviews(Object.fromEntries(entries));
    if (!previews.length) throw new Error('Catalogue vide.');
    const json = Buffer.from(JSON.stringify(previews));
    return {
      json,
      gzip: gzipSync(json),
      etag: `"${createHash('sha1').update(json).digest('base64url')}"`,
      count: previews.length,
      at: now(),
    };
  }

  return {
    /** Catalogue en cache, reconstruit après expiration (un seul calcul à la fois). */
    async get() {
      if (cached && now() - cached.at < ttlMs) return cached;
      pending ??= build()
        .then((result) => (cached = result))
        .finally(() => {
          pending = null;
        });
      try {
        return await pending;
      } catch (error) {
        if (cached) return cached; // ancien catalogue plutôt qu'une erreur
        throw error;
      }
    },
  };
}

/** Lecture BigQuery d'une table du catalogue (dataset `projet.dataset`). */
export function bigQueryTableLoader({ bigquery, dataset, location }) {
  if (!/^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)?$/.test(dataset)) {
    throw new Error(`Dataset invalide : ${dataset}`);
  }
  const allowed = new Set(Object.values(CATALOG_TABLES).flat());
  return async (name) => {
    if (!allowed.has(name)) throw new Error(`Table non autorisée : ${name}`);
    const columns =
      name === 'fact_recette_base'
        ? 'recette_id, titre, photo, duree_minute, temps_bin_id'
        : '*';
    const [rows] = await bigquery.query({
      query: `SELECT ${columns} FROM \`${dataset}.${name}\``,
      location,
    });
    return rows;
  };
}
