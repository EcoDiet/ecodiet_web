-- =============================================================================
-- EcoDiet Database Schema
-- Base de données SQLite pour l'application EcoDiet
-- =============================================================================

-- Suppression des tables existantes (si elles existent)
DROP TABLE IF EXISTS fact_recette_type_plat;
DROP TABLE IF EXISTS fact_recette_regime;
DROP TABLE IF EXISTS fact_recette_occasion;
DROP TABLE IF EXISTS fact_recette_equipement;
DROP TABLE IF EXISTS fact_recette_allergene;
DROP TABLE IF EXISTS fact_ingredients_recette;
DROP TABLE IF EXISTS fact_recette_base;
DROP TABLE IF EXISTS dim_temps_bin;
DROP TABLE IF EXISTS dim_type_plat;
DROP TABLE IF EXISTS dim_regime;
DROP TABLE IF EXISTS dim_occasion;
DROP TABLE IF EXISTS dim_ingredient;
DROP TABLE IF EXISTS dim_equipement;
DROP TABLE IF EXISTS dim_allergene;

-- =============================================================================
-- TABLES DE DIMENSIONS
-- =============================================================================

-- Table des allergènes
CREATE TABLE dim_allergene (
    allergene_id INTEGER PRIMARY KEY,
    libelle TEXT NOT NULL
);

-- Table des équipements de cuisine
CREATE TABLE dim_equipement (
    equipement_id INTEGER PRIMARY KEY,
    nom_equipement TEXT NOT NULL
);

-- Table des ingrédients
CREATE TABLE dim_ingredient (
    ingredient_id INTEGER PRIMARY KEY,
    nom_ingredient TEXT NOT NULL
);

-- Table des occasions
CREATE TABLE dim_occasion (
    occasion_id INTEGER PRIMARY KEY,
    libelle TEXT NOT NULL
);

-- Table des régimes alimentaires
CREATE TABLE dim_regime (
    regime_id INTEGER PRIMARY KEY,
    libelle TEXT NOT NULL
);

-- Table des types de plat
CREATE TABLE dim_type_plat (
    type_plat_id INTEGER PRIMARY KEY,
    libelle TEXT NOT NULL
);

-- Table des plages de temps de préparation
CREATE TABLE dim_temps_bin (
    temps_bin_id INTEGER PRIMARY KEY,
    libelle TEXT NOT NULL,
    min_minutes INTEGER NOT NULL,
    max_minutes INTEGER NOT NULL
);

-- =============================================================================
-- TABLE DE FAITS PRINCIPALE
-- =============================================================================

-- Table des recettes (fait principal)
CREATE TABLE fact_recette_base (
    recette_id TEXT PRIMARY KEY,
    titre TEXT NOT NULL,
    photo TEXT,
    duree_minute INTEGER NOT NULL,
    temps_bin_id INTEGER,
    FOREIGN KEY (temps_bin_id) REFERENCES dim_temps_bin(temps_bin_id)
);

-- =============================================================================
-- TABLES DE FAITS (RELATIONS MANY-TO-MANY)
-- =============================================================================

-- Relation recette-ingrédients
CREATE TABLE fact_ingredients_recette (
    recette_id TEXT NOT NULL,
    ingredient_id INTEGER NOT NULL,
    PRIMARY KEY (recette_id, ingredient_id),
    FOREIGN KEY (recette_id) REFERENCES fact_recette_base(recette_id),
    FOREIGN KEY (ingredient_id) REFERENCES dim_ingredient(ingredient_id)
);

-- Relation recette-allergènes
CREATE TABLE fact_recette_allergene (
    recette_id TEXT NOT NULL,
    allergene_id INTEGER NOT NULL,
    PRIMARY KEY (recette_id, allergene_id),
    FOREIGN KEY (recette_id) REFERENCES fact_recette_base(recette_id),
    FOREIGN KEY (allergene_id) REFERENCES dim_allergene(allergene_id)
);

-- Relation recette-équipements
CREATE TABLE fact_recette_equipement (
    recette_id TEXT NOT NULL,
    equipement_id INTEGER NOT NULL,
    PRIMARY KEY (recette_id, equipement_id),
    FOREIGN KEY (recette_id) REFERENCES fact_recette_base(recette_id),
    FOREIGN KEY (equipement_id) REFERENCES dim_equipement(equipement_id)
);

-- Relation recette-occasions
CREATE TABLE fact_recette_occasion (
    recette_id TEXT NOT NULL,
    occasion_id INTEGER NOT NULL,
    PRIMARY KEY (recette_id, occasion_id),
    FOREIGN KEY (recette_id) REFERENCES fact_recette_base(recette_id),
    FOREIGN KEY (occasion_id) REFERENCES dim_occasion(occasion_id)
);

-- Relation recette-régimes
CREATE TABLE fact_recette_regime (
    recette_id TEXT NOT NULL,
    regime_id INTEGER NOT NULL,
    PRIMARY KEY (recette_id, regime_id),
    FOREIGN KEY (recette_id) REFERENCES fact_recette_base(recette_id),
    FOREIGN KEY (regime_id) REFERENCES dim_regime(regime_id)
);

-- Relation recette-type de plat
CREATE TABLE fact_recette_type_plat (
    recette_id TEXT NOT NULL,
    type_plat_id INTEGER NOT NULL,
    PRIMARY KEY (recette_id, type_plat_id),
    FOREIGN KEY (recette_id) REFERENCES fact_recette_base(recette_id),
    FOREIGN KEY (type_plat_id) REFERENCES dim_type_plat(type_plat_id)
);

-- =============================================================================
-- INDEX POUR AMÉLIORER LES PERFORMANCES
-- =============================================================================

CREATE INDEX idx_recette_temps ON fact_recette_base(temps_bin_id);
CREATE INDEX idx_recette_duree ON fact_recette_base(duree_minute);
CREATE INDEX idx_ingredients_recette_id ON fact_ingredients_recette(recette_id);
CREATE INDEX idx_ingredients_ingredient_id ON fact_ingredients_recette(ingredient_id);
CREATE INDEX idx_allergene_recette_id ON fact_recette_allergene(recette_id);
CREATE INDEX idx_allergene_allergene_id ON fact_recette_allergene(allergene_id);
CREATE INDEX idx_equipement_recette_id ON fact_recette_equipement(recette_id);
CREATE INDEX idx_occasion_recette_id ON fact_recette_occasion(recette_id);
CREATE INDEX idx_regime_recette_id ON fact_recette_regime(recette_id);
CREATE INDEX idx_type_plat_recette_id ON fact_recette_type_plat(recette_id);

-- =============================================================================
-- DONNÉES DES DIMENSIONS
-- =============================================================================

-- Allergènes
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (1, 'arachide');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (2, 'celeri');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (3, 'crustaces');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (4, 'fruits_a_coque');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (5, 'gluten');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (6, 'lactose');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (7, 'mollusques');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (8, 'moutarde');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (9, 'oeuf');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (10, 'poisson');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (11, 'sesame');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (12, 'soja');
INSERT INTO dim_allergene (allergene_id, libelle) VALUES (13, 'sulfites');

-- Régimes alimentaires
INSERT INTO dim_regime (regime_id, libelle) VALUES (1, 'carnivore');
INSERT INTO dim_regime (regime_id, libelle) VALUES (2, 'pescetarian');
INSERT INTO dim_regime (regime_id, libelle) VALUES (3, 'vegan');
INSERT INTO dim_regime (regime_id, libelle) VALUES (4, 'vegetarian');

-- Occasions
INSERT INTO dim_occasion (occasion_id, libelle) VALUES (1, 'barbecue');
INSERT INTO dim_occasion (occasion_id, libelle) VALUES (2, 'ete');
INSERT INTO dim_occasion (occasion_id, libelle) VALUES (3, 'familial');
INSERT INTO dim_occasion (occasion_id, libelle) VALUES (4, 'festif');
INSERT INTO dim_occasion (occasion_id, libelle) VALUES (5, 'hiver');
INSERT INTO dim_occasion (occasion_id, libelle) VALUES (6, 'noel');
INSERT INTO dim_occasion (occasion_id, libelle) VALUES (7, 'paques');
INSERT INTO dim_occasion (occasion_id, libelle) VALUES (8, 'quotidien');
INSERT INTO dim_occasion (occasion_id, libelle) VALUES (9, 'rapide');

-- Types de plat
INSERT INTO dim_type_plat (type_plat_id, libelle) VALUES (1, 'aperitif');
INSERT INTO dim_type_plat (type_plat_id, libelle) VALUES (2, 'dessert');
INSERT INTO dim_type_plat (type_plat_id, libelle) VALUES (3, 'entree');
INSERT INTO dim_type_plat (type_plat_id, libelle) VALUES (4, 'petit_dejeuner');
INSERT INTO dim_type_plat (type_plat_id, libelle) VALUES (5, 'plat_principal');
INSERT INTO dim_type_plat (type_plat_id, libelle) VALUES (6, 'snack');

-- Plages de temps
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (1, '<30min', 0, 29);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (2, '30-60min', 30, 60);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (3, '60-90min', 61, 90);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (4, '90-120min', 91, 120);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (5, '120-150min', 121, 150);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (6, '150-180min', 151, 180);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (7, '180-210min', 181, 210);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (8, '210-240min', 211, 240);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (9, '240-270min', 241, 270);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (10, '270-300min', 271, 300);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (11, '300-330min', 301, 330);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (12, '330-360min', 331, 360);
INSERT INTO dim_temps_bin (temps_bin_id, libelle, min_minutes, max_minutes) VALUES (13, '>360min', 361, 99999);

-- =============================================================================
-- REQUÊTES UTILES (EXEMPLES)
-- =============================================================================

-- Obtenir toutes les recettes végétariennes
-- SELECT r.* FROM fact_recette_base r
-- INNER JOIN fact_recette_regime frr ON r.recette_id = frr.recette_id
-- WHERE frr.regime_id = 4;

-- Obtenir les recettes sans gluten
-- SELECT r.* FROM fact_recette_base r
-- WHERE r.recette_id NOT IN (
--     SELECT fra.recette_id FROM fact_recette_allergene fra WHERE fra.allergene_id = 5
-- );

-- Obtenir les recettes rapides (moins de 30 min)
-- SELECT * FROM fact_recette_base WHERE temps_bin_id = 1;

-- Obtenir une recette avec tous ses ingrédients
-- SELECT r.titre, i.nom_ingredient 
-- FROM fact_recette_base r
-- INNER JOIN fact_ingredients_recette fir ON r.recette_id = fir.recette_id
-- INNER JOIN dim_ingredient i ON fir.ingredient_id = i.ingredient_id
-- WHERE r.recette_id = 'votre_recette_id';
