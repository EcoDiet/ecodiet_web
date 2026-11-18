import 'package:flutter/material.dart';

import '../models/taste_profile.dart';
import '../services/ecodiet_api.dart';
import '../services/favorites_service.dart';
import '../utils/responsive.dart';
import 'home/home_models.dart';
import 'taste/swipe_card.dart';
import 'taste/taste_logic.dart';
import 'taste/taste_recommendation.dart';
import 'taste/taste_summary.dart';
import 'taste/taste_swipe_deck.dart';

/// Cartes à swiper et catalogue complet (pour relire les recettes votées).
class SwipeSession {
  final List<RecipeDisplayModel> deck;
  final List<RecipeDisplayModel> catalog;
  const SwipeSession(this.deck, this.catalog);
}

/// Charge les recettes et choisit les cartes selon les contraintes. Les
/// recettes déjà swipées (`alreadySwiped`) ne reviennent pas, pour que
/// « Affiner » apporte de nouvelles informations.
Future<SwipeSession> loadSwipeSession(
  EcoDietApi api,
  SwipeConstraints constraints, {
  Set<String> alreadySwiped = const {},
}) async {
  final previews = await api.getAllRecettesPreview();
  final catalog = previews
      .map((p) => RecipeDisplayModel.fromPreview(p, const {}))
      .toList();
  var deck = selectSwipeDeck(
    catalog.where((r) => !alreadySwiped.contains(r.id)).toList(),
    constraints: constraints,
  );
  // Presque tout a déjà été swipé : on repropose aussi les anciennes.
  if (deck.length < kSwipeDeckSize ~/ 2) {
    deck = selectSwipeDeck(catalog, constraints: constraints);
  }
  return SwipeSession(deck, catalog);
}

/// Construit le profil à partir des votes de la session, ajoutés à
/// l'historique (`previous`), et l'enregistre (appareil + serveur).
/// Connecté, les coups de cœur rejoignent les favoris tout de suite ; à
/// l'inscription (`email` fourni), ils restent en attente jusqu'à la
/// première connexion.
Future<TasteProfile> saveSwipeResult(
  EcoDietApi api,
  List<RecipeDisplayModel> catalog,
  List<SwipeVote> votes, {
  TasteProfile? previous,
  String? email,
  String? userId,
  String source = 'swipe',
}) async {
  final session = buildTasteProfile(catalog, votes);
  final allVotes = mergeVotes(previous?.votes ?? const [], session.votes);
  final full = buildTasteProfile(catalog, allVotes);
  var toSave = full.copyWith(
    votes: allVotes,
    pendingFavoriteIds: {
      ...?previous?.pendingFavoriteIds,
      ...session.pendingFavoriteIds,
    },
  );
  if (api.isLoggedIn && email == null) {
    final byId = {for (final r in catalog) r.id: r};
    for (final id in session.pendingFavoriteIds) {
      final recipe = byId[id];
      if (recipe == null || FavoritesService().isFavorite(id)) continue;
      FavoritesService().addFavorite(FavoriteRecipe(
        id: recipe.id,
        title: recipe.title,
        category: recipe.category,
        duration: recipe.duration,
        imageUrl: recipe.imageUrl,
      ));
      await api.addToFavorites(id);
    }
    toSave = toSave.copyWith(pendingFavoriteIds: const {});
  }
  return api.saveTasteProfile(toSave,
      email: email, userId: userId, source: source);
}

/// Page « Mes goûts » (route `/taste`), ouverte depuis l'accueil ou le
/// profil. Renvoie `true` à la fermeture si un profil a été enregistré.
class TasteSwipePage extends StatefulWidget {
  const TasteSwipePage({super.key});

  @override
  State<TasteSwipePage> createState() => _TasteSwipePageState();
}

class _TasteSwipePageState extends State<TasteSwipePage> {
  final EcoDietApi _api = EcoDietApi();
  List<RecipeDisplayModel>? _deck;
  List<RecipeDisplayModel> _catalog = const [];
  TasteProfile? _previous;
  TasteProfile? _profile;
  String? _error;
  int _deckGeneration = 0;
  int _superLikeCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _deck = null;
      _profile = null;
      _error = null;
    });
    try {
      final prefs = await _api.getUserPreferences();
      _previous = await _api.getTasteProfile();
      final session = await loadSwipeSession(
        _api,
        constraintsFromPreferences(prefs),
        alreadySwiped: {...?_previous?.votes.map((v) => v.recipeId)},
      );
      final deck = session.deck;
      if (!mounted) return;
      setState(() {
        _catalog = session.catalog;
        _deck = deck;
        _deckGeneration++;
        if (deck.isEmpty) _error = 'Aucune recette à proposer pour le moment.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Impossible de charger les recettes. Réessayez.');
    }
  }

  Future<void> _onFinished(List<SwipeVote> votes) async {
    _superLikeCount =
        votes.where((v) => v.verdict == SwipeVerdict.superLike).length;
    final profile = await saveSwipeResult(_api, _catalog, votes,
        previous: _previous, source: 'swipe_page');
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Scaffold(
      backgroundColor: SwipeColors.beige,
      appBar: AppBar(
        title: const Text('Mes goûts'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(_profile != null),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, desktop ? 12 : 4, 20, 16),
              child: _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      );
    }
    final deck = _deck;
    if (deck == null) {
      return Center(
        child: Semantics(
          label: 'Chargement des recettes',
          child: const CircularProgressIndicator(color: SwipeColors.green),
        ),
      );
    }
    final profile = _profile;
    if (profile != null) {
      return TasteSummary(
        profile: profile,
        ingredients: topIngredients(ingredientPreferences(
            profile.votes, {for (final r in _catalog) r.id: r})),
        note: superLikeNote(
          _superLikeCount,
          pending: profile.pendingFavoriteIds.isNotEmpty,
        ),
        primaryLabel: 'Voir mes recommandations',
        onPrimary: () => Navigator.of(context).pop(true),
        onRestart: _load,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TasteSwipeIntro(),
        const SizedBox(height: 16),
        Expanded(
          child: TasteSwipeDeck(
            key: ValueKey(_deckGeneration),
            deck: deck,
            onFinished: _onFinished,
          ),
        ),
      ],
    );
  }
}

/// Titre et consigne affichés au-dessus des cartes.
class TasteSwipeIntro extends StatelessWidget {
  const TasteSwipeIntro({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Qu\'est-ce qui vous fait envie ?',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: SwipeColors.text,
              ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Glissez à droite si ça vous tente, à gauche sinon. '
          'Le cœur ajoute la recette à vos favoris. '
          'Touchez une carte pour voir la recette en détail.',
          style: TextStyle(fontSize: 13, color: SwipeColors.muted),
        ),
      ],
    );
  }
}
