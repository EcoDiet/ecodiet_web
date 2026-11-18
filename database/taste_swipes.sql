-- =============================================================================
-- EcoDiet — Swipe de goûts et recommandations
-- =============================================================================
--
-- Donnée de référence : les swipes bruts (un vote par utilisateur et par
-- recette, le plus récent fait foi). Tout le reste — poids du profil,
-- pourcentages par ingrédient, classement des recettes — se recalcule à partir
-- de ces swipes et du catalogue. On peut donc faire évoluer la formule sans
-- migrer les données.
--
-- L'app (lib/pages/taste/taste_recommendation.dart) applique la même formule
-- côté client ; les vues ci-dessous servent à l'analyse, au calcul côté
-- serveur ou à un futur endpoint de recommandations.
--
-- Écriture : le bridge Cloud Run reçoit
--   POST /swipes {user_id, email, source, votes: [{recette_id, verdict, poids, voted_at}]}
-- et insère une ligne par vote dans fact_user_swipe (append-only).
-- Lecture : GET /v1/users/{user_id}/swipes (à partir de v_user_swipe_courant).
--
-- Deux variantes : BigQuery (production, via le bridge) puis PostgreSQL /
-- Supabase (branche dormante, mêmes conventions que supabase_schema.sql).
-- Remplacer `ecodiet` par le dataset BigQuery réel.


-- =============================================================================
-- 1. BIGQUERY
-- =============================================================================

-- Swipes bruts, en ajout seul : un nouveau vote sur une recette déjà swipée
-- crée une nouvelle ligne (historique conservé, le plus récent fait foi).
CREATE TABLE IF NOT EXISTS `ecodiet.fact_user_swipe` (
  user_id    STRING    NOT NULL,  -- dim_utilisateur.user_id
  recette_id STRING    NOT NULL,  -- fact_recette_base.recette_id
  verdict    STRING    NOT NULL,  -- 'dislike' | 'like' | 'super_like'
  poids      INT64     NOT NULL,  -- -1 | 1 | 2
  voted_at   TIMESTAMP NOT NULL,  -- horodatage côté appareil
  source     STRING,              -- 'onboarding' | 'swipe_page'
  ingested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP()
)
PARTITION BY DATE(voted_at)
CLUSTER BY user_id, recette_id
OPTIONS (description = 'Swipes du profil de goûts (source de vérité des recommandations)');

-- Dernier vote par (utilisateur, recette). Un même envoi peut être rejoué
-- par l'app (synchronisation hors ligne) : la déduplication se fait ici.
CREATE OR REPLACE VIEW `ecodiet.v_user_swipe_courant` AS
SELECT user_id, recette_id, verdict, poids, voted_at, source
FROM `ecodiet.fact_user_swipe`
WHERE verdict IN ('dislike', 'like', 'super_like')
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY user_id, recette_id
  ORDER BY voted_at DESC, ingested_at DESC
) = 1;

-- Clé normalisée des ingrédients. Dans les données brutes, chaque ligne de
-- dim_ingredients est un libellé complet (« 2 gousses d ail finement
-- hachées ») : il faut une clé commune (« ail ») pour compter les
-- préférences. L'implémentation de référence est `ingredientKey()` dans
-- lib/pages/taste/taste_logic.dart (testée sur tout le jeu de données, voir
-- test/taste_dataset_test.dart). Le pipeline (dbt) doit produire cette table ;
-- la requête ci-dessous en est une première approximation en SQL.
CREATE OR REPLACE TABLE `ecodiet.dim_ingredient_cle` AS
WITH nettoye AS (
  SELECT
    ingredient_id,
    TRIM(REGEXP_REPLACE(
      REGEXP_REPLACE(
        REGEXP_REPLACE(
          REGEXP_REPLACE(LOWER(REPLACE(nom_ingredient, '"', '')), r"['’]", ' '),
          -- quantités, unités et articles en tête
          r"^([\d½¼¾.,/ x-]+|(cuill[eè]res?|kg|g|gr|ml|cl|dl|l|verres?|bo[iî]tes?|sachets?|pinc[ée]es?|gousses?|tranches?|morceaux?|bouquets?|branches?|pots?|paquets?)( [àa] (soupe|caf[ée]))?\b ?|(de la|de l|des|du|de|d|un|une|le|la|les|l)\b ?)+",
          ''),
        -- précisions en fin de libellé
        r"(,|\(| ou | finement| coup[ée]| hach[ée]| [ée]minc[ée]| r[âa]p[ée]| en (d[ée]s|rondelles|morceaux|conserve)| \d).*$",
        ''),
      r"\s+", ' ')) AS libelle
  FROM `ecodiet.dim_ingredients`
)
SELECT
  ingredient_id,
  libelle AS ingredient_libelle,
  -- sans accents, pluriels simples ramenés au singulier
  REGEXP_REPLACE(
    REGEXP_REPLACE(NORMALIZE(libelle, NFD), r"\p{M}", ''),
    r"([a-z]{3,}[^sui])s\b", r"\1") AS ingredient_cle
FROM nettoye
WHERE LENGTH(libelle) >= 2;

-- Préférences par ingrédient et par utilisateur, même formule que l'app :
--   liked_share    = Σ poids des recettes aimées contenant l'ingrédient
--                    / Σ poids des recettes aimées       (coup de cœur = 2)
--   disliked_share = nb de recettes rejetées contenant l'ingrédient
--                    / nb de recettes rejetées
--   score          = liked_share − disliked_share       (dans [−1, 1])
CREATE OR REPLACE VIEW `ecodiet.v_user_ingredient_preference` AS
WITH votes AS (
  SELECT * FROM `ecodiet.v_user_swipe_courant`
),
totaux AS (
  SELECT
    user_id,
    SUM(IF(poids > 0, poids, 0)) AS poids_aime_total,
    COUNTIF(poids < 0)          AS nb_rejet_total
  FROM votes
  GROUP BY user_id
),
par_ingredient AS (
  SELECT
    v.user_id,
    c.ingredient_cle,
    ANY_VALUE(c.ingredient_libelle) AS ingredient_libelle,
    SUM(IF(v.poids > 0, v.poids, 0)) AS poids_aime,
    COUNT(DISTINCT IF(v.poids > 0, v.recette_id, NULL)) AS nb_recettes_aimees,
    COUNT(DISTINCT IF(v.poids < 0, v.recette_id, NULL)) AS nb_recettes_rejetees
  FROM votes v
  JOIN (
    -- une recette compte une fois par ingrédient, même s'il apparaît
    -- dans plusieurs lignes (« 1 oignon », « oignon émincé »)
    SELECT DISTINCT f.recette_id, c.ingredient_cle, c.ingredient_libelle
    FROM `ecodiet.fact_ingredients_recette` f
    JOIN `ecodiet.dim_ingredient_cle` c USING (ingredient_id)
  ) c USING (recette_id)
  GROUP BY v.user_id, c.ingredient_cle
)
SELECT
  p.user_id,
  p.ingredient_cle,
  p.ingredient_libelle,
  p.nb_recettes_aimees,
  p.nb_recettes_rejetees,
  SAFE_DIVIDE(p.poids_aime, t.poids_aime_total)            AS liked_share,
  IFNULL(SAFE_DIVIDE(p.nb_recettes_rejetees, t.nb_rejet_total), 0) AS disliked_share,
  IFNULL(SAFE_DIVIDE(p.poids_aime, t.poids_aime_total), 0)
    - IFNULL(SAFE_DIVIDE(p.nb_recettes_rejetees, t.nb_rejet_total), 0) AS score,
  ROUND(100 * IFNULL(SAFE_DIVIDE(p.poids_aime, t.poids_aime_total), 0)) AS pourcentage
FROM par_ingredient p
JOIN totaux t USING (user_id);


-- =============================================================================
-- 2. POSTGRESQL / SUPABASE (branche dormante)
-- =============================================================================
-- À exécuter après supabase_schema.sql.

create table if not exists user_swipe (
  swipe_id   bigint generated by default as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  recette_id text not null references fact_recette_base(recette_id) on delete cascade,
  verdict    text not null check (verdict in ('dislike', 'like', 'super_like')),
  poids      smallint not null check (poids in (-1, 1, 2)),
  voted_at   timestamptz not null,
  source     text,
  ingested_at timestamptz not null default now()
);

create index if not exists idx_user_swipe_user_recette
  on user_swipe(user_id, recette_id, voted_at desc);

alter table user_swipe enable row level security;

create policy "own swipes" on user_swipe
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace view v_user_swipe_courant
with (security_invoker = true) as
select distinct on (user_id, recette_id)
  user_id, recette_id, verdict, poids, voted_at, source
from user_swipe
order by user_id, recette_id, voted_at desc, ingested_at desc;
