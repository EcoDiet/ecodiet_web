import 'package:eco_diet_v0/models/recette.dart';
import 'package:eco_diet_v0/models/user.dart';
import 'package:eco_diet_v0/pages/profile/profile_controller.dart';
import 'package:eco_diet_v0/pages/profile_page.dart';
import 'package:eco_diet_v0/services/ecodiet_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fausse API : seules les méthodes utilisées par le profil sont simulées.
class _FakeApi implements EcoDietApi {
  _FakeApi({this.user, this.failLoad = false});

  User? user;
  final bool failLoad;
  final List<UserFolder> folders = [
    UserFolder(folderId: 1, userId: 'u', label: 'Favoris', color: Colors.red),
    UserFolder(
        folderId: 2,
        userId: 'u',
        label: 'Rapides',
        color: Colors.blue,
        recipeCount: 3),
  ];
  final List<String> calls = [];
  int loads = 0;

  @override
  User? get currentUser => user;

  @override
  Future<List<UserFolder>> getFolders() async {
    loads++;
    if (failLoad) throw Exception('panne');
    return List.of(folders);
  }

  @override
  Future<List<UserPreference>> getUserPreferences() async =>
      [UserPreference(label: 'Régime', value: 'Végétarien')];

  @override
  Future<List<Recette>> getFavorites() async => [
        for (var i = 0; i < 5; i++)
          Recette(
              recetteId: '$i',
              titre: 'R$i',
              photo: '',
              dureeMinute: 10,
              tempsBinId: 0),
      ];

  @override
  Future<ApiResult<UserFolder>> createFolder(
      {required String label, int colorValue = 0xFFF4A259}) async {
    calls.add('create $label');
    final folder = UserFolder(
        folderId: 3, userId: 'u', label: label, color: Color(colorValue));
    folders.add(folder);
    return ApiResult.success(folder);
  }

  @override
  Future<bool> updateFolder(int folderId,
      {String? newLabel, int? colorValue}) async {
    calls.add('update $folderId $newLabel');
    return true;
  }

  @override
  Future<bool> deleteFolder(int folderId) async {
    calls.add('delete $folderId');
    folders.removeWhere((f) => f.folderId == folderId);
    return true;
  }

  @override
  Future<void> logout() async => calls.add('logout');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  group('affichage du profil', () {
    test('nom : prénom et nom, sinon début de l e-mail', () {
      expect(profileDisplayName(null), 'Utilisateur');
      expect(
          profileDisplayName(
              User(email: 'a@b.fr', prenom: ' Ana ', nom: 'Lopez')),
          'Ana Lopez');
      expect(profileDisplayName(User(email: 'jean.d@b.fr')), 'jean.d');
      expect(profileDisplayName(User(email: '  ')), 'Utilisateur');
    });

    test('e-mail et initiale par défaut', () {
      expect(profileDisplayEmail(null), 'utilisateur@ecodiet.fr');
      expect(avatarLetter('ana'), 'A');
      expect(avatarLetter(''), 'U');
    });

    test('accord des compteurs', () {
      expect(countLabel(1, 'recette'), '1 recette');
      expect(countLabel(0, 'dossier'), '0 dossier');
      expect(countLabel(3, 'favori'), '3 favoris');
    });
  });

  test('charge dossiers, préférences et nombre de favoris', () async {
    final c = ProfileController(api: _FakeApi(user: User(email: 'ana@b.fr')));
    await c.load();

    expect(c.folders, hasLength(2));
    expect(c.favoriteCount, 5);
    expect(c.profileTag, 'Végétarien');
    expect(c.displayName, 'ana');
    expect(c.avatar, 'A');
    // Le dossier Favoris affiche le nombre de favoris.
    expect(c.recipeCountOf(c.folders[0]), 5);
    expect(c.recipeCountOf(c.folders[1]), 3);
    c.dispose();
  });

  test('un échec de chargement garde l état précédent', () async {
    final c = ProfileController(api: _FakeApi(failLoad: true));
    await c.load();

    expect(c.folders, isEmpty);
    expect(c.profileTag, 'Aucune preference');
    c.dispose();
  });

  test('créer, modifier, supprimer : appel API puis rechargement', () async {
    final api = _FakeApi();
    final c = ProfileController(api: api);
    await c.load();

    await c.createFolder('Desserts', Colors.pink.toARGB32());
    expect(c.folders.map((f) => f.label), contains('Desserts'));

    await c.updateFolder(c.folders[1], 'Express', Colors.green.toARGB32());
    await c.deleteFolder(c.folders[1]);

    expect(api.calls, ['create Desserts', 'update 2 Express', 'delete 2']);
    expect(api.loads, 4);
    expect(c.folders.map((f) => f.folderId), isNot(contains(2)));
    c.dispose();
  });

  group('ProfilePage', () {
    Future<_FakeApi> pumpPage(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final api = _FakeApi(user: User(email: 'ana@b.fr', prenom: 'Ana'));
      await tester.pumpWidget(MaterialApp(
        home: ProfilePage(controller: ProfileController(api: api)),
        routes: {'/login': (_) => const Text('page login')},
      ));
      await tester.pumpAndSettle();
      return api;
    }

    testWidgets('desktop : bannière, dossiers et préférences', (tester) async {
      await pumpPage(tester, const Size(1400, 900));

      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('5 favoris'), findsOneWidget);
      expect(find.text('2 dossiers'), findsOneWidget);
      expect(find.text('5 recettes'), findsOneWidget);
      expect(find.text('3 recettes'), findsOneWidget);
      expect(find.text('Régime'), findsOneWidget);
    });

    testWidgets('desktop : création d un dossier via la boîte de dialogue',
        (tester) async {
      final api = await pumpPage(tester, const Size(1400, 900));

      await tester.tap(find.text('Nouveau dossier'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();
      expect(find.text('Créer un nouveau dossier'), findsOneWidget,
          reason: 'nom vide : la boîte reste ouverte');

      await tester.enterText(find.byType(TextField), 'Desserts');
      await tester.tap(find.text('Créer'));
      await tester.pumpAndSettle();

      expect(api.calls, ['create Desserts']);
      expect(find.text('Desserts'), findsOneWidget);
    });

    testWidgets('mobile : suppression confirmée depuis le menu',
        (tester) async {
      final api = await pumpPage(tester, const Size(400, 900));

      await tester.tap(find.byIcon(Icons.more_horiz));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Supprimer').last);
      await tester.pumpAndSettle();

      expect(api.calls, ['delete 2']);
      expect(find.text('Rapides'), findsNothing);
    });

    testWidgets('déconnexion puis retour à la page de connexion',
        (tester) async {
      final api = await pumpPage(tester, const Size(1400, 900));

      await tester.tap(find.text('Déconnexion'));
      await tester.pumpAndSettle();

      expect(api.calls, ['logout']);
      expect(find.text('page login'), findsOneWidget);
    });
  });
}
