-- Données du compte enregistrées par l'app (favoris, dossiers, préférences,
-- nom modifié) : un document JSON par utilisateur. Remplacer projet.dataset.
CREATE TABLE IF NOT EXISTS `projet.dataset.user_state` (
  email STRING NOT NULL,
  state STRING NOT NULL,      -- document JSON (64 Ko max, contrôlé par le service)
  updated_at TIMESTAMP NOT NULL
);
