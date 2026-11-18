# EcoDiet Web

Application web Flutter de recommandation de recettes saines et de quiz nutritionnels.

## Apercu

EcoDiet est une application responsive (desktop et mobile) permettant aux utilisateurs de :
- Parcourir et rechercher des recettes healthy
- Ajouter des recettes en favoris et les organiser en dossiers
- Repondre a des quiz nutritionnels
- Gerer leur profil avec objectifs alimentaires et allergies

---

## Stack technique

| Technologie | Version |
|-------------|---------|
| Flutter | 3.44 en CI (3.38.1 minimum, cf. `pubspec.lock`) |
| Dart | >= 3.0.0 < 4.0.0 |
| Données | Service Cloud Run « GCP bridge » (BigQuery) |
| Supabase | `supabase_flutter` ^2.12 (code présent, désactivé au démarrage) |
| font_awesome_flutter | ^11.0.0 |
| flutter_svg | ^2.0.0 |
| google_fonts | ^6.3.0 |
| shared_preferences | ^2.5.5 |
| logger | ^2.0.2 |

---

## Structure du projet

```
lib/
├── main.dart                       # Point d'entree, config, routes, navigation (sidebar desktop / bottom nav mobile)
├── assets/logo/                    # Logos EcoDiet
├── models/                         # Recette, Quiz, Utilisateur...
├── pages/
│   ├── home_page.dart              # Accueil : etat, chargement, mise en page
│   ├── home/
│   │   ├── home_models.dart        # RecipeDisplayModel, Quiz, RecipeFilters, RecipeSortMode
│   │   ├── recipe_filtering.dart   # Recherche / filtres / tri / recommandations (fonctions pures)
│   │   ├── filter_panel.dart       # Panneau de filtres (drawer desktop, bottom sheet mobile)
│   │   ├── recipe_card.dart
│   │   └── quiz_card.dart
│   ├── recipe_infos_page.dart      # Detail d'une recette (layout 2 colonnes desktop)
│   ├── recipe_infos/
│   │   ├── recipe_text.dart        # Nettoyage texte, etapes, duree, difficulte (fonctions pures)
│   │   └── recipe_info_widgets.dart
│   ├── create_account_page.dart    # Inscription en 5 etapes (PageView)
│   ├── create_account/
│   │   ├── onboarding_options.dart # Objectifs, regimes, allergies proposes
│   │   └── onboarding_widgets.dart # Puces, cartes, boutons, force du mot de passe
│   ├── all_recipes_page.dart       # Liste complete « Voir tout »
│   ├── quiz_page.dart              # Quiz nutritionnel avec progression
│   ├── folder_page.dart            # Vue dossier / favoris
│   ├── profile_page.dart           # Profil utilisateur, dossiers, preferences
│   ├── taste_swipe_page.dart       # Swipe de gouts « Mes gouts » (route /taste)
│   ├── taste/
│   │   ├── taste_logic.dart        # Choix des cartes, profil, score (fonctions pures)
│   │   ├── taste_recommendation.dart # % par ingredient et classement des recos (fonctions pures)
│   │   ├── taste_swipe_deck.dart   # Pile de cartes : gestes, boutons, clavier, annuler
│   │   ├── swipe_card.dart         # Carte recette du swipe + couleurs
│   │   ├── swipe_recipe_details.dart # Fiche deroulee de la recette pendant le swipe
│   │   ├── taste_summary.dart      # Ecran de fin « Votre profil gourmand »
│   │   └── taste_entry.dart        # Banniere accueil + ligne profil
│   └── login_page.dart             # Connexion
├── services/
│   ├── ecodiet_api.dart            # Acces aux donnees (bridge Cloud Run ; branche Supabase dormante)
│   └── favorites_service.dart      # Singleton ChangeNotifier pour les favoris partages
├── widgets/
│   └── favorite_button.dart
└── utils/
    └── responsive.dart             # Helper isDesktop(context), breakpoint 768px
```

Regle : une page garde l'etat et la mise en page ; la logique sans widget va dans un fichier de fonctions pures (teste dans `test/`), les blocs d'UI reutilisables dans des widgets dedies.

---

## Architecture

### Responsive design

Breakpoint unique a **768px** via `isDesktop(context)` (`lib/utils/responsive.dart`).
Chaque page branche le layout desktop ou mobile selon ce helper.

```dart
if (isDesktop(context)) {
  // Layout 2 colonnes, sidebar, etc.
} else {
  // Layout mobile compact
}
```

### Source de donnees

Au demarrage, `main.dart` lit `GCP_BRIDGE_URL` (via `--dart-define`, sinon `assets/env.development` en debug / `assets/env.production` en release sur le web). **Cette variable est obligatoire** : sans elle l'application affiche une erreur de configuration. Le mode est donc toujours `gcp_bridge` ; Supabase n'est pas initialise.

Les erreurs reseau recuperees (fallbacks) sont journalisees via `logger` et visibles dans la console en mode debug.

### Gestion des favoris

`FavoritesService` est un singleton `ChangeNotifier` centralise. Toutes les pages lisent `FavoritesService().isFavorite(id)` directement dans `build()` et s'abonnent via `addListener`.

### Navigation / Routes

| Route | Page | Arguments |
|-------|------|-----------|
| `/login` | LoginPage | — |
| `/create_account` | CreateAccountPage | — |
| `/home` | HomePage | — |
| `/profile` | ProfilePage | — |
| `/recipe` | RecipeInfosPage | id, title, description, duration |
| `/quiz` | QuizPage | id, title, description |
| `/folder` | FolderPage | id, label, color |
| `/taste` | TasteSwipePage | — (renvoie `true` si un profil a ete enregistre) |

---

## Fonctionnalites

- **Inscription en 6 etapes** : compte, profil, objectif, regime alimentaire, allergies, gouts
- **Swipe de gouts** : 12 recettes variees (compatibles allergies/regime) a swiper. Droite = ca me tente, gauche = pas pour moi, haut / coeur = coup de coeur (ajoute aux favoris). Le profil obtenu trie « Juste pour vous » apres les filtres stricts. Les coups de coeur donnes a l'inscription rejoignent les favoris a la premiere connexion. Accessible aussi depuis l'accueil et le profil. Toucher une carte (ou « Voir la recette », Entree) deroule sa fiche : chiffres cles, ingredients avec quantites, preparation, ustensiles, allergenes, occasions ; on peut voter depuis la fiche (« Reduire » / Echap pour revenir).
- **Favoris partages** : ajout depuis la page d'accueil, la page recette, visible dans le profil et les dossiers
- **Layouts desktop** pour toutes les pages
- **Quiz** avec barre de progression et feedback visuel des reponses
- **Dossiers personnalises** avec choix de couleur

---

## Design

| Role | Couleur |
|------|---------|
| Fond panneau sombre | `#1F3A24` |
| Vert principal | `#2F6B3F` |
| Vert clair | `#8FBF97` / `#63A96E` |
| Accent orange | `#F4A259` / `#EA853D` |
| Fond beige | `#F5ECD9` |

### Profil de gouts et recommandations

- **Source de verite : les swipes bruts** (utilisateur, recette, verdict `dislike`/`like`/`super_like`, poids -1/1/2, date), table `fact_user_swipe` (`database/taste_swipes.sql`, BigQuery + variante Supabase). Poids du profil et pourcentages se recalculent depuis ces swipes et le catalogue : la formule peut evoluer sans migration.
- **Preference par ingredient** : part des recettes aimees qui le contiennent (coup de coeur = 2), moins la part des recettes rejetees qui le contiennent. Les ingredients sont ramenes a une cle commune (`ingredientKey`, « 2 gousses d ail hachees » → `ail`).
- **Classement « Juste pour vous »** : filtres stricts (allergies, regime ; les allergies sont aussi verifiees sur les ingredients car les etiquettes d'allergenes des donnees sont incompletes, ex. « Mac and cheese » marque seulement gluten) puis score = 65 % ingredients (somme des affinites / racine du nombre d'ingredients) + 35 % type de plat, regime, duree, occasions ; les recettes jamais swipees qui correspondent aux gouts sont entrecoupees de recettes deja aimees (1 sur 3, « Deja aimee »), les rejetees passent en dernier. Chaque carte indique pourquoi elle est proposee.
- **Hors ligne d'abord** : copie locale par email (`taste_profile_<email>`), envoi au bridge `POST /swipes` retente tant qu'il n'a pas reussi ; a la lecture, fusion appareil / serveur (`GET /v1/users/{id}/swipes`, repli `GET /?table=fact_user_swipe`), le vote le plus recent par recette l'emporte.
- **A faire cote bridge pour la mise en ligne** : creer `fact_user_swipe`, exposer `POST /swipes` (insertion en ajout seul) et `GET /v1/users/{id}/swipes` (lecture de `v_user_swipe_courant`).

---

## Accessibilite

L'application cible le niveau **WCAG 2.1 AA**. Les corrections apportees incluent :

- Navigation complete au clavier (remplacement de `GestureDetector` par `InkWell`)
- Labels semantiques pour les lecteurs d'ecran (VoiceOver, TalkBack, NVDA)
- Formulaires avec `labelText` persistant
- Barre de progression et indicateurs de chargement annonces
- Contraste des couleurs conforme (ratio >= 4.5:1)
- Tailles minimales des cibles tactiles (44x44 dp)
- Color picker accessible sans dependance a la couleur seule

Voir [ACCESSIBILITE.md](./ACCESSIBILITE.md) pour le detail complet.

---

## Lancer le projet

### Configuration (obligatoire)

Renseigner les fichiers `assets/env.development` et `assets/env.production` (ou passer les valeurs via `--dart-define`) :

- `GCP_BRIDGE_URL=https://<votre-service>.a.run.app` (obligatoire)
- `GCP_BRIDGE_API_KEY=<cle_api_optionnelle>`
- `DATA_PROVIDER=gcp_bridge` (informatif : le mode est determine par la presence de `GCP_BRIDGE_URL`)

Ces fichiers sont embarques dans le build web : ils ne doivent contenir **aucun secret serveur**.

Endpoints attendus par le front :

- `GET /v1/recettes`
- `GET /v1/recettes/preview?limit=<n>&offset=<n>`
- `GET /v1/recettes/{recetteId}`
- `GET /v1/recettes/{recetteId}/complete`
- `GET /v1/quizzes`
- `GET /v1/quizzes/{quizId}`
- `GET /v1/quizzes/{quizId}/questions`
- `GET /v1/references/allergenes`
- `GET /v1/references/regimes`
- `GET /v1/references/types-plat`
- `GET /v1/references/occasions`
- `GET /v1/references/equipements`
- `GET /v1/references/temps-bins`

Compatibilite endpoint unique : si le service expose uniquement `GET /` avec un JSON contenant `donneesBigQuery`, l'app l'accepte aussi.

En-tete transmis par le front vers le bridge : `x-api-key` (si configure).

### Supabase (branche dormante)

Le code Supabase (`supabase_flutter`, scripts `database/`) est toujours present mais n'est pas active par `main.dart`. Pour la reactiver il faudrait initialiser Supabase au demarrage. Dans tous les cas, ne jamais mettre `SUPABASE_SERVICE_KEY` dans Flutter, dans un fichier `env`, dans l'hebergeur ou dans Git : cette cle donne des droits serveur.

Import des donnees DIM/FACT dans Supabase : executer `database/supabase_schema.sql` puis `database/supabase_seed_data.sql`. Pour regenerer le seed depuis les CSV (Windows) :

```powershell
powershell -ExecutionPolicy Bypass -File scripts\generate_supabase_seed.ps1 -CsvDir "C:\chemin\vers\csv" -Output database\supabase_seed_data.sql
```

### Commandes

```bash
flutter pub get
flutter run -d chrome     # mode web
flutter build web         # build de production dans build/web
```

### Deploy web public

Le deploiement de reference est **GitHub Pages**, automatique a chaque push sur `main` (`.github/workflows/deploy.yml` : analyse, tests, build, publication).

Le depot contient aussi `netlify.toml`, `web/_redirects` et `firebase.json` pour Netlify / Firebase Hosting.

---

## Tests

```bash
flutter analyze   # ou `dart analyze` si l'outil Flutter plante localement
flutter test
```
