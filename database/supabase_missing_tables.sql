-- ==============================================================================
-- TABLES DES UTILISATEURS (Pour aller avec vos tables de recettes)
-- A EXÉCUTER DANS LE SQL EDITOR DE SUPABASE
-- ==============================================================================

-- 1. Table des Favoris
CREATE TABLE user_favoris (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    recette_id VARCHAR(50) REFERENCES fact_recette_base(recette_id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()),
    PRIMARY KEY (user_id, recette_id)
);

-- 2. Table des Dossiers
CREATE TABLE user_folder (
    folder_id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    label VARCHAR(255) NOT NULL,
    color INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- 3. Table de l'association (Dossiers <-> Recettes)
CREATE TABLE folder_recette (
    folder_id INT REFERENCES user_folder(folder_id) ON DELETE CASCADE,
    recette_id VARCHAR(50) REFERENCES fact_recette_base(recette_id) ON DELETE CASCADE,
    PRIMARY KEY (folder_id, recette_id)
);

-- 4. Table des régimes sélectionnés par les utilisateurs
CREATE TABLE user_regime (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    regime_id INT REFERENCES dim_regime(regime_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, regime_id)
);

-- 5. Table des allergènes sélectionnés par les utilisateurs (à éviter)
CREATE TABLE user_allergene (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    allergene_id INT REFERENCES dim_allergene(allergene_id) ON DELETE CASCADE,
    PRIMARY KEY (user_id, allergene_id)
);

-- 6. Table de l'historique de consultation des recettes
CREATE TABLE user_history (
    history_id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    recette_id VARCHAR(50) REFERENCES fact_recette_base(recette_id) ON DELETE CASCADE,
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- RLS (Row Level Security) : Sécurise les tables pour que chaque utilisateur 
-- ne puisse lire/modifier que ses propres données.
ALTER TABLE user_favoris ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_folder ENABLE ROW LEVEL SECURITY;
ALTER TABLE folder_recette ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_regime ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_allergene ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE fact_recette_base ENABLE ROW LEVEL SECURITY;

-- Autoriser la lecture du catalogue de recettes par tout le monde
CREATE POLICY "Recettes visibles par tous" ON fact_recette_base FOR SELECT USING (true);

-- Politiques de sécurité (L'utilisateur connecté 'auth.uid()' peut accéder à ses données)
CREATE POLICY "Fav owner" ON user_favoris FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Folder owner" ON user_folder FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Regime owner" ON user_regime FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "Allergene owner" ON user_allergene FOR ALL USING (auth.uid() = user_id);
CREATE POLICY "History owner" ON user_history FOR ALL USING (auth.uid() = user_id);

-- Pour folder_recette, l'utilisateur a accès si le dossier lui appartient
CREATE POLICY "Folder recette access" ON folder_recette FOR ALL USING (
  EXISTS (SELECT 1 FROM user_folder WHERE user_folder.folder_id = folder_recette.folder_id AND user_folder.user_id = auth.uid())
);
