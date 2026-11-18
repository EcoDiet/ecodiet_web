# ecodiet-auth

Authentification EcoDiet côté serveur. Elle remplace la connexion actuelle,
où l'app téléchargeait toute la table `dim_utilisateur` (e-mails et empreintes
de mots de passe) dans le navigateur pour comparer les mots de passe.

- Mots de passe hachés avec **scrypt** salé (module `crypto` de Node, aucune
  dépendance native).
- Les anciennes empreintes SHA-256, MD5 et SHA-1 sont acceptées une dernière
  fois, puis re-hachées en scrypt à la connexion.
- Jeton de session JWT HS256, valable 7 jours.
- Limitation : 5 échecs par IP et par e-mail sur 15 minutes. Un e-mail inconnu
  prend autant de temps qu'un mauvais mot de passe.
- Le hachage n'est jamais renvoyé. Seuls les champs de profil connus sont
  acceptés à l'inscription.

## Routes

| Route | Corps | Réponse |
|---|---|---|
| `POST /auth/register` | `email, password, nom, prenom, pseudo`, profil (`regime`, `allergies`, …) | `201 {token, user}` · `409` déjà inscrit |
| `POST /auth/login` | `email, password` | `200 {token, user}` · `401` · `429` |
| `POST /auth/email-available` | `email` | `{available}` |
| `POST /auth/pseudo-available` | `pseudo` | `{available}` |
| `GET /auth/me` | en-tête `Authorization: Bearer <jeton>` | `{user, preferences}` |

## Développement

```sh
npm test       # 14 tests, sans dépendance installée
npm run dev    # serveur local en mémoire sur :8790, ne jamais déployer
```

Pour tester l'app contre ce serveur :

```sh
flutter run -d chrome --dart-define=AUTH_URL=http://127.0.0.1:8790
```

## Mise en production

1. **Déployer.** Deux options :
   - Brancher `createAuthHandler` dans le service Cloud Run existant
     (`recuperer-donnees-site`). Le mode d'emploi est en tête de
     `src/handler.js`.
   - Déployer ce dossier comme service à part :
     `gcloud run deploy ecodiet-auth --source . --region europe-west1`.

   Variables d'environnement :

   | Variable | Valeur |
   |---|---|
   | `AUTH_SECRET` | 32 caractères aléatoires ou plus, via Secret Manager. Jamais dans Git. |
   | `USERS_TABLE` | `projet.dataset.dim_utilisateur` |
   | `ALLOWED_ORIGINS` | `https://gdemerges.github.io,http://localhost:5000` |
   | `PASSWORD_COLUMN`, `USER_ID_COLUMN`, `USER_ID_TYPE`, `BQ_LOCATION` | à vérifier sur le schéma réel (défauts : `mdp`, `user_id`, `string`) |

   Le compte de service doit avoir `roles/bigquery.dataEditor` sur la table et
   `roles/bigquery.jobUser` sur le projet.

2. **Activer côté app.** Ajouter `AUTH_URL=https://…` dans
   `assets/env.production`, ou `--dart-define=AUTH_URL=…` dans
   `.github/workflows/deploy.yml`. Sans cette variable, l'app garde l'ancienne
   connexion.

3. **Fermer la fuite.** Retirer `dim_utilisateur` des tables servies par
   `GET ?table=`, et supprimer `POST /users`, qui écrivait l'empreinte calculée
   par le navigateur. Tant que ce n'est pas fait, la table reste lisible par
   tout le monde.

4. **Après coup.** Les anciennes empreintes ont pu être téléchargées. Elles
   sont sans sel, donc faciles à casser pour les mots de passe courants. Il
   faut prévenir les comptes existants ou forcer une réinitialisation.
