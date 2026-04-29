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
| Flutter | SDK >= 2.19.4 |
| Dart | >= 2.19.4 < 4.0.0 |
| mongo_dart | ^0.10.5 |
| font_awesome_flutter | ^10.7.0 |
| flutter_svg | ^2.0.0 |
| email_validator | ^2.1.17 |
| crypto | ^3.0.3 |

---

## Structure du projet

```
lib/
├── main.dart                    # Point d'entree, routes, navigation (sidebar desktop / bottom nav mobile)
├── assets/
│   └── logo/                    # Logos EcoDiet
├── pages/
│   ├── home_page.dart           # Cartes recettes, quiz, recherche, favoris
│   ├── recipe_infos_page.dart   # Detail d'une recette (layout 2 colonnes desktop)
│   ├── quiz_page.dart           # Quiz nutritionnel avec progression
│   ├── folder_page.dart         # Vue dossier / favoris
│   ├── profile_page.dart        # Profil utilisateur, dossiers, preferences
│   ├── login_page.dart          # Connexion avec boutons reseaux sociaux
│   └── create_account_page.dart # Inscription en 5 etapes (PageView)
├── services/
│   └── favorites_service.dart   # Singleton ChangeNotifier pour les favoris partages
└── utils/
    └── responsive.dart          # Helper isDesktop(context), breakpoint 768px
```

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

---

## Fonctionnalites

- **Inscription en 5 etapes** : compte, profil, objectif, regime alimentaire, allergies
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

```bash
# Installer les dependances
flutter pub get

# Lancer en mode web
flutter run -d chrome

# Build de production
flutter build web
```

---

## Tests

```bash
flutter test
```
