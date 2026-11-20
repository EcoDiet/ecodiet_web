// Catalogue des vignettes de recettes : jointure des tables faite une fois
// côté serveur (au lieu de 13 tables brutes, ~850 Ko, téléchargées et jointes
// par chaque navigateur), sans les étapes, gardée en mémoire et servie
// compressée avec un ETag. Les fiches complètes (étapes, libellés avec leurs
// identifiants) sont gardées à côté pour /catalog/recettes/:id.

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
  // Repli des fiches : étapes, ingrédients et ustensiles en texte brut.
  stg: ['stg_recettes'],
};

const toInt = (value) => {
  const n = Number(value?.value ?? value);
  return Number.isFinite(n) ? Math.trunc(n) : 0;
};
const text = (value) => String(value ?? '').trim();

/** Jointure commune : pour chaque recette, les libellés avec leur identifiant. */
function joinTables(t) {
  const index = (rows, idKey, labelKey) =>
    new Map((rows ?? []).map((r) => [toInt(r[idKey]), text(r[labelKey])]));
  const many = (facts, dim, idKey) => {
    const out = new Map();
    for (const r of facts ?? []) {
      const rid = text(r.recette_id);
      const id = toInt(r[idKey]);
      const label = dim.get(id) ?? '';
      if (!rid || !label) continue;
      if (!out.has(rid)) out.set(rid, []);
      if (!out.get(rid).some((e) => e.id === id)) out.get(rid).push({ id, label });
    }
    return out;
  };
  const one = (facts, dim, idKey) => {
    const out = new Map();
    for (const r of facts ?? []) {
      const rid = text(r.recette_id);
      const id = toInt(r[idKey]);
      const label = dim.get(id) ?? '';
      if (rid && label) out.set(rid, { id, label });
    }
    return out;
  };

  return {
    ingredients: many(t.factIngredient, index(t.dimIngredient, 'ingredient_id', 'nom_ingredient'), 'ingredient_id'),
    equipements: many(t.factEquipement, index(t.dimEquipement, 'equipement_id', 'nom_equipement'), 'equipement_id'),
    allergenes: many(t.factAllergene, index(t.dimAllergene, 'allergene_id', 'libelle'), 'allergene_id'),
    occasions: many(t.factOccasion, index(t.dimOccasion, 'occasion_id', 'libelle'), 'occasion_id'),
    regimes: one(t.factRegime, index(t.dimRegime, 'regime_id', 'libelle'), 'regime_id'),
    types: one(t.factType, index(t.dimType, 'type_plat_id', 'libelle'), 'type_plat_id'),
  };
}

const labels = (entries) => [...new Set((entries ?? []).map((e) => e.label))];

/** Même jointure que l'app (ecodiet_api.dart, _bridgeBuildPreviewsFromBase). */
export function buildPreviews(t, joined = joinTables(t)) {
  const j = joined;
  // Doublons de libellés (identifiants différents) retirés, comme avant.
  return (t.base ?? []).map((r) => {
    const rid = text(r.recette_id);
    return {
      recette_id: rid,
      titre: text(r.titre),
      photo: text(r.photo),
      duree_minute: toInt(r.duree_minute),
      temps_bin_id: toInt(r.temps_bin_id),
      type_plat: j.types.get(rid)?.label ?? null,
      regime: j.regimes.get(rid)?.label ?? null,
      ingredients: labels(j.ingredients.get(rid)),
      equipements: labels(j.equipements.get(rid)),
      allergenes: labels(j.allergenes.get(rid)),
      occasions: labels(j.occasions.get(rid)),
    };
  });
}

/**
 * Fiches complètes par recette_id, au format de l'app (getRecetteComplete) :
 * étapes de la base ou, à défaut, de stg_recettes ; textes bruts de
 * stg_recettes pour les ingrédients et ustensiles sans table de liaison.
 */
export function buildDetails(t, joined = joinTables(t)) {
  const j = joined;
  const stg = new Map((t.stg ?? []).map((r) => [text(r.recette_id), r]));
  const named = (entries, idKey, labelKey) =>
    (entries ?? []).map((e) => ({ [idKey]: e.id, [labelKey]: e.label }));
  const details = new Map();
  for (const r of t.base ?? []) {
    const rid = text(r.recette_id);
    if (!rid) continue;
    const raw = stg.get(rid);
    const regime = j.regimes.get(rid);
    const type = j.types.get(rid);
    details.set(rid, {
      recette_id: rid,
      titre: text(r.titre),
      photo: text(r.photo),
      etapes: text(r.etapes) || text(raw?.etapes),
      duree_minute: toInt(r.duree_minute),
      temps_bin_id: toInt(r.temps_bin_id),
      ingredients: named(j.ingredients.get(rid), 'ingredient_id', 'nom_ingredient'),
      equipements: named(j.equipements.get(rid), 'equipement_id', 'nom_equipement'),
      allergenes: named(j.allergenes.get(rid), 'allergene_id', 'libelle'),
      occasions: named(j.occasions.get(rid), 'occasion_id', 'libelle'),
      regime: regime ? { regime_id: regime.id, libelle: regime.label } : null,
      type_plat: type ? { type_plat_id: type.id, libelle: type.label } : null,
      ingredients_texte: text(raw?.ingredients),
      ustensiles_texte: text(raw?.ustensiles),
    });
  }
  return details;
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
    const tables = Object.fromEntries(entries);
    const joined = joinTables(tables);
    const previews = buildPreviews(tables, joined);
    if (!previews.length) throw new Error('Catalogue vide.');
    const json = Buffer.from(JSON.stringify(previews));
    return {
      json,
      gzip: gzipSync(json),
      etag: `"${createHash('sha1').update(json).digest('base64url')}"`,
      count: previews.length,
      details: buildDetails(tables, joined),
      at: now(),
    };
  }

  const catalog = {
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

    /** Fiche complète d'une recette, `null` si inconnue. */
    async recette(id) {
      const data = await catalog.get();
      return data.details?.get(String(id)) ?? null;
    },
  };
  return catalog;
}

/** Lecture BigQuery d'une table du catalogue (dataset `projet.dataset`). */
export function bigQueryTableLoader({ bigquery, dataset, location }) {
  if (!/^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)?$/.test(dataset)) {
    throw new Error(`Dataset invalide : ${dataset}`);
  }
  const allowed = new Set(Object.values(CATALOG_TABLES).flat());
  return async (name) => {
    if (!allowed.has(name)) throw new Error(`Table non autorisée : ${name}`);
    const columns = {
      fact_recette_base: 'recette_id, titre, photo, etapes, duree_minute, temps_bin_id',
      stg_recettes: 'recette_id, etapes, ingredients, ustensiles',
    }[name] ?? '*';
    const [rows] = await bigquery.query({
      query: `SELECT ${columns} FROM \`${dataset}.${name}\``,
      location,
    });
    return rows;
  };
}
