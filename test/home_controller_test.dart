import 'package:eco_diet_v0/models/recette.dart';
import 'package:eco_diet_v0/models/taste_profile.dart';
import 'package:eco_diet_v0/models/user.dart' as models;
import 'package:eco_diet_v0/pages/home/home_controller.dart';
import 'package:eco_diet_v0/pages/home/home_models.dart';
import 'package:eco_diet_v0/pages/home_page.dart' show HomePage;
import 'package:eco_diet_v0/services/ecodiet_api.dart';
import 'package:eco_diet_v0/services/favorites_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fausse API : seules les méthodes utilisées par l'accueil sont simulées.
class _FakeApi implements EcoDietApi {
  _FakeApi(this.previews, {this.failLoad = false});

  final List<RecettePreview> previews;
  final bool failLoad;
  bool loggedIn = false;
  bool syncSucceeds = false;
  int previewCalls = 0;
  final List<String> toggled = [];
  final List<String> added = [];
  TasteProfile? taste;
  TasteProfile? savedTaste;
  List<models.UserPreference> prefs = [];

  @override
  bool get isBridgeMode => true;
  @override
  bool get isLoggedIn => loggedIn;
  models.User? user;
  @override
  models.User? get currentUser => user;

  @override
  Future<List<RecettePreview>> getAllRecettesPreview(
      {int pageSize = 1000}) async {
    previewCalls++;
    if (failLoad) throw Exception('panne');
    return previews;
  }

  @override
  Future<Set<String>> getFavoriteIds() async => {};
  @override
  Future<List<models.Quiz>> getAllQuizzes() async =>
      [models.Quiz(quizId: 7, title: 'Saisons')];
  @override
  Future<List<Ingredient>> getAllIngredients() async => [];
  @override
  Future<List<Equipement>> getAllEquipements() async => [];
  @override
  Future<List<Regime>> getAllRegimes() async => [];
  @override
  Future<List<TypePlat>> getAllTypesPlat() async => [];
  @override
  Future<List<Allergene>> getAllAllergenes() async => [];
  @override
  Future<List<models.UserPreference>> getUserPreferences() async => prefs;

  @override
  Future<TasteProfile?> getTasteProfile() async => taste;
  @override
  Future<TasteProfile> saveTasteProfile(TasteProfile profile,
      {String? email, String? userId, String source = 'swipe'}) async {
    savedTaste = profile;
    taste = profile;
    return profile;
  }

  @override
  Future<bool> addToFavorites(String recetteId) async {
    added.add(recetteId);
    return true;
  }

  @override
  Future<bool> toggleFavorite(String recetteId, {bool? favorite}) async {
    toggled.add(recetteId);
    return syncSucceeds;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

RecettePreview _preview(int i,
        {String titre = 'Recette',
        int duree = 20,
        String type = 'Plat principal'}) =>
    RecettePreview(
      recetteId: 'r$i',
      titre: '$titre $i',
      photo: '',
      dureeMinute: duree,
      tempsBinId: 0,
      typePlatLibelle: type,
      regimeLibelle: 'vegetarian',
      ingredients: const ['tomate'],
    );

void main() {
  setUp(() {
    HomeController.resetCache();
    FavoritesService().clear();
  });

  test('charge les recettes, les quiz et pagine par 25', () async {
    final api = _FakeApi(List.generate(30, (i) => _preview(i)));
    final c = HomeController(api: api);

    await c.load();

    expect(c.isLoading, isFalse);
    expect(c.loadWarning, isNull);
    expect(c.filteredRecipeCount, 30);
    expect(c.visibleRecipes, hasLength(25));
    expect(c.totalRecipePages, 2);
    expect(c.canGoNext, isTrue);
    expect(c.quizzes.single.id, '7');

    c.goToPage(1);
    expect(c.visibleRecipes, hasLength(5));
    expect(c.canGoNext, isFalse);
  });

  test('la recherche filtre, masque les recommandations et revient page 1',
      () async {
    final c = HomeController(
      api: _FakeApi([
        ...List.generate(26, (i) => _preview(i)),
        _preview(99, titre: 'Curry'),
      ]),
    );
    await c.load();
    c.goToPage(1);
    expect(c.recommendedRecipes, isNotEmpty);

    c.setSearchQuery('  CURRY ');

    expect(c.recipePage, 0);
    expect(c.visibleRecipes.map((r) => r.id), ['r99']);
    expect(c.recommendedRecipes, isEmpty);
  });

  test('le tri par temps décroissant est appliqué', () async {
    final c = HomeController(
      api: _FakeApi([_preview(1, duree: 10), _preview(2, duree: 60)]),
    );
    await c.load();

    c.setSortMode(RecipeSortMode.tempsDesc);

    expect(c.visibleRecipes.first.id, 'r2');
  });

  test('les filtres actifs sont comptés et appliqués', () async {
    final c = HomeController(
      api: _FakeApi([_preview(1, duree: 10), _preview(2, duree: 90)]),
    );
    await c.load();

    c.applyFilters(RecipeFilters.empty()..maxTimeMinutes = 30);

    expect(c.activeFiltersCount, 1);
    expect(c.visibleRecipes.map((r) => r.id), ['r1']);
  });

  test('les régimes des recettes sont proposés dans les filtres', () async {
    final c = HomeController(api: _FakeApi([_preview(1)]));
    await c.load();

    expect(c.dietOptions, containsAll(['vegetarian', 'plat principal']));
  });

  test('un échec de chargement produit un avertissement', () async {
    final c = HomeController(api: _FakeApi([], failLoad: true));
    await c.load();

    expect(c.isLoading, isFalse);
    expect(c.hasRecipes, isFalse);
    expect(c.loadWarning, contains('panne'));
  });

  test('le cache évite un second appel réseau, sauf rafraîchissement forcé',
      () async {
    final api = _FakeApi([_preview(1)]);
    await HomeController(api: api).load();
    await HomeController(api: api).load();
    expect(api.previewCalls, 1);

    await HomeController(api: api).load(forceRefresh: true);
    expect(api.previewCalls, 2);
  });

  test('favori hors session : bascule locale et invitation à se connecter',
      () async {
    final api = _FakeApi([_preview(1)]);
    final c = HomeController(api: api);
    await c.load();
    final recipe = c.visibleRecipes.single;

    final hint = await c.toggleFavorite(recipe);

    expect(hint, isTrue);
    expect(FavoritesService().isFavorite('r1'), isTrue);
    expect(api.toggled, ['r1']);

    final hintOnRemove = await c.toggleFavorite(recipe);
    expect(hintOnRemove, isFalse);
    expect(FavoritesService().isFavorite('r1'), isFalse);
  });

  test('favori avec session : pas d invitation même si la synchro échoue',
      () async {
    final api = _FakeApi([_preview(1)])..loggedIn = true;
    final c = HomeController(api: api);
    await c.load();

    expect(await c.toggleFavorite(c.visibleRecipes.single), isFalse);
  });

  test('le profil de goûts trie « Juste pour vous »', () async {
    final api = _FakeApi([
      _preview(1, type: 'Plat principal'),
      _preview(2, type: 'Dessert'),
    ])
      ..taste = const TasteProfile(weights: {'type:dessert': 1.0});
    final c = HomeController(api: api);

    await c.load();

    expect(c.hasTasteProfile, isTrue);
    expect(c.recommendedRecipes.first.id, 'r2');
  });

  test('allergie au lactose : recette au fromage écartée même sans étiquette',
      () async {
    final api = _FakeApi([
      RecettePreview(
        recetteId: 'mac',
        titre: 'Mac and cheese',
        photo: '',
        dureeMinute: 15,
        tempsBinId: 0,
        typePlatLibelle: 'Plat principal',
        regimeLibelle: 'vegetarian',
        ingredients: const ['300 g de macaroni', '150 g de cheddar'],
        allergenes: const ['gluten'],
      ),
      _preview(2),
    ])
      ..prefs = [models.UserPreference(label: 'Allergènes', value: 'lactose')];
    final c = HomeController(api: api);
    await c.load();

    expect(c.recommendedRecipes.map((r) => r.id), ['r2']);
    // La recette reste visible dans « Nos recettes » (navigation libre).
    expect(c.visibleRecipes.map((r) => r.id), contains('mac'));
  });

  test('sans profil de goûts, l ordre des recommandations est inchangé',
      () async {
    final c = HomeController(
      api: _FakeApi([_preview(1), _preview(2, type: 'Dessert')]),
    );
    await c.load();

    expect(c.hasTasteProfile, isFalse);
    expect(c.recommendedRecipes.map((r) => r.id), ['r1', 'r2']);
  });

  test('les coups de cœur de l inscription rejoignent les favoris une fois connecté',
      () async {
    final api = _FakeApi([_preview(1), _preview(2)])
      ..loggedIn = true
      ..taste = const TasteProfile(
        weights: {'type:plat principal': 1.0},
        pendingFavoriteIds: {'r2'},
      );
    final c = HomeController(api: api);

    await c.load();

    expect(api.added, ['r2']);
    expect(FavoritesService().isFavorite('r2'), isTrue);
    expect(api.savedTaste!.pendingFavoriteIds, isEmpty);
    expect(api.savedTaste!.weights, {'type:plat principal': 1.0});
  });

  test('hors session, les coups de cœur restent en attente', () async {
    final api = _FakeApi([_preview(1)])
      ..taste = const TasteProfile(
        weights: {'type:plat principal': 1.0},
        pendingFavoriteIds: {'r1'},
      );
    await HomeController(api: api).load();

    expect(api.added, isEmpty);
    expect(api.savedTaste, isNull);
  });

  testWidgets('HomePage branchée sur le contrôleur : recherche avec délai',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final c = HomeController(
      api: _FakeApi([_preview(1, titre: 'Curry'), _preview(2, titre: 'Soupe')]),
    );
    await tester.pumpWidget(MaterialApp(home: HomePage(controller: c)));
    await tester.pumpAndSettle();

    expect(find.text('Nos recettes (2)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'soupe');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Nos recettes (2)'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Nos recettes (1)'), findsOneWidget);
    expect(find.text('Soupe 2'), findsOneWidget);
    expect(find.text('Curry 1'), findsNothing);
  });

  testWidgets('Voir tout : le cœur enregistre le favori via l API',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final api = _FakeApi([_preview(1, titre: 'Curry')]);
    final c = HomeController(api: api);
    await tester.pumpWidget(MaterialApp(home: HomePage(controller: c)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Voir tout'));
    await tester.pumpAndSettle();
    expect(find.text('Juste pour vous'), findsOneWidget);

    await tester.tap(find.byTooltip('Ajouter aux favoris'));
    await tester.pumpAndSettle();

    expect(api.toggled, ['r1']);
    expect(FavoritesService().isFavorite('r1'), isTrue);
    expect(find.byTooltip('Retirer des favoris'), findsOneWidget);
    // Hors session : invitation à se connecter, comme depuis l'accueil.
    expect(find.textContaining('Connecte-toi'), findsOneWidget);
  });

  test('salutation avec le prénom une fois connecté', () {
    final api = _FakeApi([]);
    expect(HomeController(api: api).greeting, 'Bonjour 👋');
    api.user = models.User(email: 'ana@b.fr', prenom: ' Ana ');
    expect(HomeController(api: api).greeting, 'Bonjour Ana 👋');
  });
}
