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
| `GET /catalog/previews` | public | vignettes des recettes, gzip, ETag, cache 10 min |
| `GET /me/state` | `Authorization: Bearer <jeton>` | `{state, updated_at}` : favoris, dossiers, préférences, nom |
| `PUT /me/state` | `Authorization: Bearer <jeton>`, `{state}` (64 Ko max) | `{updated_at}` |
| `POST /auth/password-reset/request` | `email` | `{ok}`, que le compte existe ou non. Au plus 3 e-mails par heure. |
| `POST /auth/password-reset/confirm` | `token, password` | `{ok}` · `400` lien invalide, expiré ou déjà utilisé |

Le catalogue remplace les 13 tables brutes que chaque navigateur
téléchargeait et joignait lui-même : 850 Ko en 13 requêtes deviennent 42 Ko
compressés en une seule (mesuré sur les 300 recettes actuelles). Les étapes
ne sont plus envoyées pour les vignettes.

Les données du compte sont un document JSON par utilisateur, stocké dans la
table `user_state` (`sql/user_state.sql`). L'app le récupère à la connexion,
l'envoie après chaque modification et en garde une copie hors connexion.
Le nom et les préférences de ce document priment sur `dim_utilisateur` dans
`/auth/login` et `/auth/me`.

Le lien de réinitialisation est valable une heure. Il ne sert qu'une fois,
car il devient caduc dès que le mot de passe change. Il n'ouvre pas de
session.

## Développement

```sh
npm test       # tests, sans dépendance installée
npm run dev    # serveur local en mémoire sur :8790, ne jamais déployer.
               # Les e-mails sont affichés dans la console.
               # BRIDGE_URL=<service Cloud Run> : catalogue construit à
               # partir de ses tables.
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
   | `CATALOG_DATASET` | `projet.dataset` des tables recettes. Absent : `/catalog/previews` répond 501 et l'app garde les tables. |
   | `USER_STATE_TABLE` | `projet.dataset.user_state`, à créer avec `sql/user_state.sql` |
   | `RESET_URL` | `https://gdemerges.github.io/ecodiet_web/#/reset_password` |
   | `RESEND_API_KEY`, `MAIL_FROM` | clé [Resend](https://resend.com) via Secret Manager, et expéditeur d'un domaine vérifié. Sans clé, « Mot de passe oublié » répond 503. |
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
