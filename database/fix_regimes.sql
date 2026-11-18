-- Corrections des régimes de référence (fact_recette_regime), issues de la
-- relecture des désaccords entre régime fourni et ingrédients.
-- regime_id : 1 carnivore, 2 pescetarian, 3 vegan, 4 vegetarian.
-- Supabase : à exécuter tel quel. BigQuery : préfixer la table par le dataset.

-- « La pâte à galettes de blé noir traditionnelle » : farine, oeuf, sel, eau.
update fact_recette_regime set regime_id = 4
where recette_id = '14591e4d815f6c24ca726cd97ea96014' and regime_id = 1;

-- « Pomme de terre au four » : pommes de terre seules.
update fact_recette_regime set regime_id = 3
where recette_id = 'd9724deb7bc8ea27c6c6213513e09e10' and regime_id = 4;
