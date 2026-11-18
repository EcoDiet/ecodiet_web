import 'package:eco_diet_v0/models/recette.dart';
import 'package:eco_diet_v0/pages/folder/folder_controller.dart';
import 'package:eco_diet_v0/pages/folder_page.dart';
import 'package:eco_diet_v0/services/ecodiet_api.dart';
import 'package:eco_diet_v0/services/favorites_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Recette _r(String id, {int minutes = 20, String photo = ''}) => Recette(
    recetteId: id,
    titre: 'Recette $id',
    photo: photo,
    dureeMinute: minutes,
    tempsBinId: 0);

/// Fausse API : seules les méthodes utilisées par la page dossier sont simulées.
class _FakeApi implements EcoDietApi {
  _FakeApi({this.failLoad = false});

  final bool failLoad;
  final List<String> calls = [];

  @override
  Future<List<Recette>> getFavorites() async {
    calls.add('favorites');
    if (failLoad) throw Exception('panne');
    return [_r('f1'), _r('f2', minutes: 90)];
  }

  @override
  Future<List<Recette>> getRecipesInFolder(int folderId) async {
    calls.add('folder $folderId');
    return [_r('d1')];
  }

  @override
  Future<bool> removeFromFavorites(String recetteId) async {
    calls.add('unfav $recetteId');
    return true;
  }

  @override
  Future<bool> addToFavorites(String recetteId) async {
    calls.add('fav $recetteId');
    return true;
  }

  @override
  Future<bool> addRecipeToFolder(int folderId, String recetteId) async {
    calls.add('file $folderId $recetteId');
    return true;
  }

  @override
  Future<bool> removeRecipeFromFolder(int folderId, String recetteId) async {
    calls.add('unfile $folderId $recetteId');
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  test('formatShortDuration', () {
    expect(formatShortDuration(45), "45'");
    expect(formatShortDuration(60), '1h');
    expect(formatShortDuration(90), "1h30'");
  });

  test('libellés de compte', () {
    expect(recipeCountShort(2), '2 recette(s)');
    expect(recipeCountLong(0), 'Aucune recette');
    expect(recipeCountLong(1), '1 recette');
    expect(recipeCountLong(3), '3 recettes');
  });

  test('favoriteRecipeFrom : sans photo, pas d image', () {
    final f = favoriteRecipeFrom(_r('x', minutes: 75));
    expect(f.id, 'x');
    expect(f.duration, "1h15'");
    expect(f.imageUrl, isNull);
  });

  setUp(() => FavoritesService().clear());

  test('favoris : retrait puis annulation, côté données et à sa place',
      () async {
    final api = _FakeApi();
    final c = FolderController(folderId: favoritesFolderId, api: api);
    expect(c.isLoading, isTrue);

    await c.load();
    expect(c.isLoading, isFalse);
    expect(c.recipes.map((r) => r.id), ['f1', 'f2']);

    final first = c.recipes.first;
    FavoritesService().addFavorite(first);
    c.remove(first);
    expect(c.recipes.map((r) => r.id), ['f2']);
    expect(FavoritesService().isFavorite('f1'), isFalse);

    c.restore(first);
    expect(c.recipes.map((r) => r.id), ['f1', 'f2']);
    expect(FavoritesService().isFavorite('f1'), isTrue);
    expect(api.calls, ['favorites', 'unfav f1', 'fav f1']);

    c.restore(first); // double annulation : sans effet
    expect(c.recipes, hasLength(2));
    expect(api.calls, hasLength(3));
  });

  test('dossier numérique : recettes du dossier et retrait du dossier',
      () async {
    final api = _FakeApi();
    final c = FolderController(folderId: '7', api: api);
    await c.load();
    final recipe = c.recipes.single;
    c.remove(recipe);
    c.restore(recipe);

    expect(api.calls, ['folder 7', 'unfile 7 d1', 'file 7 d1']);
    expect(c.recipes.single.id, 'd1');
  });

  test('identifiant absent ou invalide : vide, sans appel', () async {
    for (final id in [null, 'abc']) {
      final api = _FakeApi();
      final c = FolderController(folderId: id, api: api);
      await c.load();
      expect(c.isLoading, isFalse);
      expect(c.recipes, isEmpty);
      expect(api.calls, isEmpty);
    }
  });

  test('un échec de chargement termine le chargement', () async {
    final c = FolderController(
        folderId: favoritesFolderId, api: _FakeApi(failLoad: true));
    await c.load();
    expect(c.isLoading, isFalse);
    expect(c.recipes, isEmpty);
  });

  group('FolderPage', () {
    Future<_FakeApi> pump(WidgetTester tester, Size size,
        {String id = favoritesFolderId, bool back = true}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _FakeApi();
      await tester.pumpWidget(MaterialApp(
        home: FolderPage(
          label: 'Favoris',
          showBackButton: back,
          controller: FolderController(folderId: id, api: api),
        ),
      ));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('desktop : grille et retrait par le bouton', (tester) async {
      final api = await pump(tester, const Size(1400, 900));

      expect(find.text('2 recette(s)'), findsOneWidget);
      expect(find.text('Recette f1'), findsOneWidget);

      await tester.tap(find.byTooltip('Retirer de la liste').first);
      await tester.pumpAndSettle();

      expect(find.text('Recette f1'), findsNothing);
      expect(find.text('1 recette(s)'), findsOneWidget);
      expect(api.calls.last, 'unfav f1');
    });

    testWidgets('mobile : balayage, puis annulation', (tester) async {
      final api = await pump(tester, const Size(400, 860), back: false);
      expect(find.text('2 recettes'), findsOneWidget);

      await tester.drag(find.text('Recette f1'), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('1 recette'), findsOneWidget);
      expect(find.textContaining('retiré'), findsOneWidget);

      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(find.text('2 recettes'), findsOneWidget);
      expect(api.calls, ['favorites', 'unfav f1', 'fav f1']);
    });

    testWidgets('dossier vide : message dédié', (tester) async {
      await pump(tester, const Size(400, 860), id: 'abc');
      expect(find.text('Dossier vide'), findsOneWidget);
    });
  });
}
