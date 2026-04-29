# Accessibilite -- EcoDiet Web

Ce document decrit les normes d'accessibilite ciblees et les corrections apportees a l'application Flutter Web EcoDiet.

---

## Normes de reference

| Norme | Description |
|-------|-------------|
| **WCAG 2.1 AA** | Web Content Accessibility Guidelines -- niveau AA (minimum requis) |
| **Section 508** | Norme federale americaine, alignee sur WCAG 2.1 |
| **EN 301 549** | Norme europeenne d'accessibilite numerique |

---

## Ce qui a ete corrige

### 1. Navigation au clavier (WCAG 2.1 -- Critere 2.1.1)

**Probleme** : Les elements interactifs utilisaient `GestureDetector`, qui ne repond pas aux evenements clavier (Tab, Entree, Espace). Les utilisateurs navigant sans souris ne pouvaient pas interagir avec l'application.

**Correction** : Remplacement systematique de `GestureDetector` par `InkWell` (ou `Material + InkWell`), qui gere nativement :
- La traversee au clavier via la touche **Tab**
- L'activation via **Entree** et **Espace**
- L'indicateur visuel de focus

**Fichiers modifies** :
- `lib/main.dart` -- items de navigation (sidebar desktop, barre mobile, bouton deconnexion)
- `lib/pages/home_page.dart` -- cartes recettes, cartes quiz
- `lib/pages/quiz_page.dart` -- options de reponse
- `lib/pages/login_page.dart` -- boutons reseaux sociaux, lien "Creer un compte"
- `lib/pages/create_account_page.dart` -- chips genre, objectif, regime, allergies, selecteur de date, lien "Se connecter"
- `lib/pages/folder_page.dart` -- cartes recettes (vue desktop)
- `lib/pages/profile_page.dart` -- bouton nouveau dossier, color picker

---

### 2. Lecteurs d'ecran -- Labels semantiques (WCAG 2.1 -- Criteres 1.1.1, 4.1.2)

**Probleme** : Les elements interactifs complexes (cartes, boutons icone, images) n'avaient pas de description textuelle pour les lecteurs d'ecran (VoiceOver, TalkBack, NVDA).

**Corrections apportees** :

#### Wrapper `Semantics` sur les elements interactifs

Chaque carte cliquable annonce maintenant son contenu complet :

```dart
// Carte recette
Semantics(
  label: 'Recette : Salade de quinoa, Entree, 15 min',
  button: true,
  child: InkWell(...)
)

// Option quiz (avec feedback apres reponse)
Semantics(
  label: 'Kiwi, bonne reponse',
  button: false, // desactive apres reponse
  child: InkWell(...)
)

// Chip de selection
Semantics(
  label: 'Vegetarien',
  selected: true,  // annonce comme "selectionne"
  button: true,
  child: InkWell(...)
)
```

#### `semanticLabel` sur les images

```dart
Image.asset(
  'lib/assets/logo/EcoDiet-Logo-beige.png',
  semanticLabel: 'Logo EcoDiet',
)
```

#### `tooltip` sur les boutons icone

Les `IconButton` sans texte visible ont maintenant un `tooltip` qui sert a la fois d'info-bulle et de label pour les lecteurs d'ecran :

```dart
IconButton(
  tooltip: 'Ajouter aux favoris',  // ou 'Retirer des favoris'
  icon: Icon(Icons.favorite_border_rounded),
  onPressed: _toggleFavorite,
)

IconButton(
  tooltip: 'Quitter le quiz',
  icon: Icon(Icons.close),
  onPressed: _showExitDialog,
)
```

#### Etat `selected` sur les elements de navigation

```dart
Semantics(
  button: true,
  selected: isSelected,  // annonce "selectionne" ou non
  label: 'Accueil',
  child: InkWell(...)
)
```

---

### 3. Formulaires accessibles (WCAG 2.1 -- Criteres 1.3.5, 3.3.2)

**Probleme** : Les champs de formulaire utilisaient uniquement `hintText`, qui disparait des que l'utilisateur commence a saisir. Le lecteur d'ecran ne peut plus lire le contexte du champ.

**Correction** : Ajout de `labelText` sur les champs critiques (email, mot de passe) pour un label persistant visible en permanence.

```dart
// Avant
decoration: InputDecoration(hintText: 'Email')

// Apres
decoration: InputDecoration(
  labelText: 'Email',
  hintText: 'votre@email.com',
)
```

Le bouton afficher/masquer le mot de passe est enveloppe dans un `Tooltip` pour annoncer son action aux lecteurs d'ecran.

---

### 4. Barre de progression -- Information d'etat (WCAG 2.1 -- Critere 4.1.3)

**Probleme** : La `LinearProgressIndicator` du quiz etait invisible pour les lecteurs d'ecran.

**Correction** :

```dart
Semantics(
  label: 'Progression : question 2 sur 5',
  child: LinearProgressIndicator(value: progress),
)
```

Le compteur de question est egalement enrichi :

```dart
Semantics(
  label: 'Question 2 sur 5',  // "sur" au lieu de "/" pour une meilleure lecture
  child: Text('Question 2/5'),
)
```

---

### 5. Indicateur de chargement (WCAG 2.1 -- Critere 4.1.3)

**Probleme** : Le `CircularProgressIndicator` ne communiquait rien aux lecteurs d'ecran.

**Correction** :

```dart
Semantics(
  label: 'Chargement en cours',
  child: const CircularProgressIndicator(),
)
```

---

### 6. Contraste des couleurs (WCAG 2.1 -- Critere 1.4.3)

**Exigence WCAG AA** : ratio minimum de **4.5:1** pour le texte normal, **3:1** pour le texte large (>= 18pt ou >= 14pt gras).

**Probleme** : Les textes secondaires utilisaient `Colors.grey[500]` (`#9E9E9E`), qui donne un ratio de seulement **2.85:1** sur fond blanc -- insuffisant.

**Correction** : Remplacement par `Colors.grey[700]` (`#616161`), ratio **5.9:1**.

| Couleur | Valeur hex | Ratio sur blanc | Resultat |
|---------|-----------|----------------|---------|
| `grey[500]` (avant) | `#9E9E9E` | 2.85:1 | Echec WCAG AA |
| `grey[700]` (apres) | `#616161` | 5.90:1 | Conforme WCAG AA |

**Fichiers modifies** : `home_page.dart`, `quiz_page.dart`, `folder_page.dart`, `profile_page.dart`, `recipe_infos_page.dart`, `create_account_page.dart`

---

### 7. Color picker accessible (WCAG 2.1 -- Criteres 1.3.3, 1.4.1)

**Probleme** : Le selecteur de couleur du dialog "Creer un dossier" n'utilisait que la couleur comme identifiant -- inaccessible pour les utilisateurs daltoniens ou avec lecteur d'ecran.

**Correction** : Chaque cercle colore est maintenant nomme et annonce son etat de selection :

```dart
Semantics(
  label: 'Rouge, selectionne',  // ou simplement 'Bleu'
  button: true,
  child: InkWell(...)
)
```

---

### 8. Taille minimale des cibles tactiles (WCAG 2.1 -- Critere 2.5.5)

**Exigence** : Les cibles interactives doivent faire au minimum **44 x 44 dp**.

**Correction** sur le bouton favori des cartes recettes :

```dart
// Avant
minimumSize: const Size(40, 40)

// Apres
minimumSize: const Size(44, 44)
```

---

## Ce qui reste a faire (backlog)

Ces points n'ont pas ete corriges dans cette iteration mais sont recommandes :

| Priorite | Probleme | Critere WCAG |
|----------|---------|-------------|
| Moyenne | Contraste du badge duree sur image (texte blanc sur overlay semi-transparent) | 1.4.3 |
| Moyenne | Ordre de focus explicite sur les formulaires multi-etapes | 2.4.3 |
| Faible | `ExcludeSemantics` sur les icones purement decoratives | 1.1.1 |
| Faible | `SemanticsService.announce` pour les messages de succes/erreur dynamiques | 4.1.3 |
| Faible | Respect de la taille de police systeme (`textScaleFactor`) | 1.4.4 |

---

## Outils de test recommandes

| Outil | Plateforme | Usage |
|-------|-----------|-------|
| **VoiceOver** | macOS / iOS | Lecteur d'ecran natif Apple |
| **TalkBack** | Android | Lecteur d'ecran natif Google |
| **NVDA** | Windows | Lecteur d'ecran open source (gratuit) |
| **axe DevTools** | Chrome/Firefox | Audit automatique WCAG |
| **Colour Contrast Analyser** | macOS/Windows | Verification des ratios de contraste |
| `flutter test --accessibility` | CI/CD | Tests d'accessibilite automatises |

---

## Ressources

- [WCAG 2.1 -- W3C](https://www.w3.org/TR/WCAG21/)
- [Flutter Accessibility Guide](https://docs.flutter.dev/development/accessibility-and-localization/accessibility)
- [Semantics widget -- Flutter API](https://api.flutter.dev/flutter/widgets/Semantics-class.html)
- [RGAA 4.1 -- Referentiel General d'Amelioration de l'Accessibilite](https://www.numerique.gouv.fr/publications/rgaa-accessibilite/)
