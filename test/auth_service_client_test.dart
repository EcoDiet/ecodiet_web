import 'dart:convert';

import 'package:eco_diet_v0/pages/login/password_reset_dialog.dart';
import 'package:eco_diet_v0/pages/login/reset_password_page.dart';
import 'package:eco_diet_v0/services/ecodiet_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String _token({required int exp}) {
  String part(Object v) =>
      base64Url.encode(utf8.encode(jsonEncode(v))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.${part({
        'sub': '7',
        'exp': exp
      })}.signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

  final api = EcoDietApi();
  late List<http.Request> requests;
  late Map<String, http.Response Function(http.Request)> routes;

  setUp(() {
    requests = [];
    routes = {};
    api.configureDataBridge(
      enabled: true,
      baseUrl: 'https://bridge.example.test',
      authUrl: 'https://auth.example.test/',
    );
    api.authHttpClient = MockClient((request) async {
      requests.add(request);
      final handler = routes['${request.method} ${request.url}'];
      if (handler != null) return handler(request);
      // Toute lecture de la table des utilisateurs serait une régression.
      return http.Response('{"error":"inattendu"}', 404);
    });
  });

  tearDown(() => api.logout());

  http.Response json(int status, Object body) => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  test('connexion : mot de passe envoyé au service, jeton conservé', () async {
    final token = _token(exp: 4102444800);
    routes['POST https://auth.example.test/auth/login'] = (_) => json(200, {
          'token': token,
          'user': {
            'user_id': '7',
            'email': 'ana@b.fr',
            'prenom': 'Ana',
            'nom': 'Lopez'
          },
        });

    final result =
        await api.login(email: ' Ana@B.fr ', password: ' secret123 ');

    expect(api.usesAuthService, isTrue);
    expect(result.isSuccess, isTrue);
    expect(api.currentUser!.prenom, 'Ana');
    expect(api.sessionToken, token);
    expect(requests.first.url.path, '/auth/login');
    expect(jsonDecode(requests.first.body),
        {'email': 'ana@b.fr', 'password': 'secret123'});
  });

  test('connexion refusée : message du service, pas de session', () async {
    routes['POST https://auth.example.test/auth/login'] =
        (_) => json(401, {'error': 'Identifiants invalides.'});

    final result = await api.login(email: 'ana@b.fr', password: 'faux');

    expect(result.isSuccess, isFalse);
    expect(result.error, 'Identifiants invalides.');
    expect(api.currentUser, isNull);
    expect(api.sessionToken, isNull);
  });

  test('inscription : profil et mot de passe en clair vers le service (TLS)',
      () async {
    routes['POST https://auth.example.test/auth/register'] = (_) => json(201, {
          'token': _token(exp: 4102444800),
          'user': {'user_id': 'u1', 'email': 'ana@b.fr'},
        });

    final result = await api.register(
      email: 'ana@b.fr',
      password: 'motdepasse',
      nom: 'Lopez',
      prenom: 'Ana',
      pseudo: 'ana',
      profile: {'regime': 'vegan'},
    );

    expect(result.isSuccess, isTrue);
    final sent = jsonDecode(requests.single.body) as Map;
    expect(sent['password'], 'motdepasse');
    expect(sent['regime'], 'vegan');
    expect(sent.containsKey('mdp'), isFalse,
        reason: 'plus de hachage côté client');
  });

  test('e-mail déjà inscrit : erreur 409 relayée', () async {
    routes['POST https://auth.example.test/auth/register'] =
        (_) => json(409, {'error': 'Cet e-mail est déjà inscrit.'});

    final result = await api.register(
        email: 'ana@b.fr',
        password: 'motdepasse',
        nom: 'L',
        prenom: 'A',
        pseudo: 'a');

    expect(result.error, 'Cet e-mail est déjà inscrit.');
  });

  test('disponibilité e-mail et pseudo via le service', () async {
    routes['POST https://auth.example.test/auth/email-available'] =
        (_) => json(200, {'available': false});
    routes['POST https://auth.example.test/auth/pseudo-available'] =
        (_) => json(200, {'available': true});

    expect(await api.isEmailAvailable('Ana@b.fr'), isFalse);
    expect(await api.isPseudoAvailable('Ana'), isTrue);
    expect(jsonDecode(requests.last.body), {'pseudo': 'ana'});
  });

  test('préférences lues via /auth/me avec le jeton', () async {
    final token = _token(exp: 4102444800);
    routes['POST https://auth.example.test/auth/login'] = (_) => json(200, {
          'token': token,
          'user': {'user_id': '7', 'email': 'ana@b.fr'},
        });
    routes['GET https://auth.example.test/auth/me'] = (_) => json(200, {
          'user': {'user_id': '7', 'email': 'ana@b.fr'},
          'preferences': {
            'regime': 'vegetarian',
            'allergies': 'gluten',
            'intolerances': ''
          },
        });
    await api.login(email: 'ana@b.fr', password: 'secret123');

    final prefs = await api.getUserPreferences();

    expect(requests.last.headers['Authorization'], 'Bearer $token');
    expect(prefs.firstWhere((p) => p.label == 'Régime').value, 'vegetarian');
    expect(prefs.firstWhere((p) => p.label == 'Allergènes').value, 'gluten');
  });

  test('validité du jeton : expiration lue dans la charge', () {
    final now = DateTime.utc(2026, 11, 18);
    final exp = now.millisecondsSinceEpoch ~/ 1000;
    expect(isSessionTokenValid(_token(exp: exp + 60), now: now), isTrue);
    expect(isSessionTokenValid(_token(exp: exp - 60), now: now), isFalse);
    expect(isSessionTokenValid('pas.un.jeton', now: now), isFalse);
    expect(isSessionTokenValid('abc', now: now), isFalse);
  });

  test('réinitialisation : demande et confirmation relayées au service',
      () async {
    routes['POST https://auth.example.test/auth/password-reset/request'] =
        (_) => json(200, {'ok': true});
    routes['POST https://auth.example.test/auth/password-reset/confirm'] =
        (r) => (jsonDecode(r.body) as Map)['token'] == 'bon'
            ? json(200, {'ok': true})
            : json(
                400, {'error': 'Lien invalide ou expiré. Refais une demande.'});

    expect(await api.requestPasswordReset(' Ana@B.fr '), isNull);
    expect(jsonDecode(requests.last.body), {'email': 'ana@b.fr'});
    expect(await api.confirmPasswordReset('bon', 'nouveau-mdp'), isNull);
    expect(await api.confirmPasswordReset('vieux', 'nouveau-mdp'),
        'Lien invalide ou expiré. Refais une demande.');
  });

  testWidgets('fenêtre « Mot de passe oublié » : envoi puis confirmation',
      (tester) async {
    routes['POST https://auth.example.test/auth/password-reset/request'] =
        (_) => json(200, {'ok': true});
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () =>
              showPasswordResetDialog(context, initialEmail: 'ana@b.fr'),
          child: const Text('ouvrir'),
        ),
      ),
    ));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envoyer le lien'));
    await tester.pumpAndSettle();

    expect(find.textContaining('un e-mail vient de partir'), findsOneWidget);
    expect(requests.single.url.path, '/auth/password-reset/request');
  });

  testWidgets('page du nouveau mot de passe : contrôles puis envoi',
      (tester) async {
    routes['POST https://auth.example.test/auth/password-reset/confirm'] =
        (_) => json(200, {'ok': true});
    await tester
        .pumpWidget(const MaterialApp(home: ResetPasswordPage(token: 'jeton')));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'court');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(find.text('Au moins 8 caractères.'), findsOneWidget);

    await tester.enterText(fields.at(0), 'nouveau-mdp');
    await tester.enterText(fields.at(1), 'autre-mdp');
    await tester.tap(find.text('Enregistrer'));
    await tester.pump();
    expect(
        find.text('Les deux mots de passe sont différents.'), findsOneWidget);
    expect(requests, isEmpty);

    await tester.enterText(fields.at(1), 'nouveau-mdp');
    await tester.tap(find.text('Enregistrer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Mot de passe enregistré'), findsOneWidget);
    expect(jsonDecode(requests.single.body),
        {'token': 'jeton', 'password': 'nouveau-mdp'});
  });

  group('données du compte sur le serveur', () {
    final token = _token(exp: 4102444800);
    late List<Map<String, dynamic>> pushed;

    setUp(() {
      pushed = [];
      routes['POST https://auth.example.test/auth/login'] = (_) => json(200, {
            'token': token,
            'user': {'user_id': 'u-sync', 'email': 'ana@b.fr', 'prenom': 'Ana'},
          });
      routes['PUT https://auth.example.test/me/state'] = (r) {
        expect(r.headers['Authorization'], 'Bearer $token');
        pushed
            .add((jsonDecode(r.body) as Map)['state'] as Map<String, dynamic>);
        return json(200, {'updated_at': '2026-11-18T10:00:00Z'});
      };
    });

    test('connexion : favoris, nom et préférences repris du serveur', () async {
      routes['GET https://auth.example.test/me/state'] = (_) => json(200, {
            'state': {
              'favorites': ['r1', 'r2'],
              'identity': {'prenom': 'Anna', 'nom': 'Lopez'},
              'preferences': {
                'regime': 'vegan',
                'allergies': ['soy']
              },
            },
          });
      routes['GET https://auth.example.test/auth/me'] = (_) => json(200, {
            'user': {'email': 'ana@b.fr'},
            'preferences': {'regime': '', 'allergies': ''},
          });

      await api.login(email: 'ana@b.fr', password: 'secret123');

      expect(api.currentUser!.prenom, 'Anna');
      expect(await api.getFavoriteIds(), {'r1', 'r2'});
      final prefs = await api.getUserPreferences();
      expect(prefs.firstWhere((p) => p.label == 'Régime').value, 'vegan');
      expect(pushed, isEmpty);
    });

    test('chaque modification est envoyée au serveur', () async {
      routes['GET https://auth.example.test/me/state'] = (_) => json(200, {
            'state': {
              'favorites': ['r1']
            }
          });
      await api.login(email: 'ana@b.fr', password: 'secret123');

      await api.toggleFavorite('r2');
      expect((pushed.last['favorites'] as List).toSet(), {'r1', 'r2'});

      await api
          .saveUserPreferences(regime: 'vegetarian', allergies: {'gluten'});
      expect(pushed.last['preferences'], {
        'regime': 'vegetarian',
        'allergies': ['gluten']
      });

      await api.updateProfile(prenom: 'Anna', nom: 'L');
      expect(pushed.last['identity'], {'nom': 'L', 'prenom': 'Anna'});
    });

    test('compte vide côté serveur : les données de l appareil y sont envoyées',
        () async {
      routes['GET https://auth.example.test/me/state'] =
          (_) => json(200, {'state': {}});
      await api.login(email: 'ana@b.fr', password: 'secret123');
      await api.saveUserPreferences(regime: 'vegan', allergies: {});
      await api.logout();
      pushed.clear();

      await api.login(email: 'ana@b.fr', password: 'secret123');

      expect(
          pushed.single['preferences'], {'regime': 'vegan', 'allergies': []});
    });

    test('serveur injoignable : la connexion réussit, cache local conservé',
        () async {
      routes['GET https://auth.example.test/me/state'] =
          (_) => http.Response('panne', 503);
      final result = await api.login(email: 'ana@b.fr', password: 'secret123');
      expect(result.isSuccess, isTrue);
    });
  });

  test('vignettes : catalogue du service en une requête, puis cache', () async {
    var calls = 0;
    routes['GET https://auth.example.test/catalog/previews'] = (_) {
      calls++;
      return json(200, [
        {
          'recette_id': 'r1',
          'titre': 'Curry',
          'photo': 'c.jpg',
          'duree_minute': 30,
          'temps_bin_id': 2,
          'type_plat': 'plat principal',
          'regime': 'vegan',
          'ingredients': ['Tomate', 'Riz'],
          'equipements': [],
          'allergenes': ['gluten'],
          'occasions': null,
        },
        {'recette_id': 'r2', 'titre': 'Soupe', 'type_plat': ''},
      ]);
    };

    final both = await Future.wait(
        [api.getAllRecettesPreview(), api.getRecettesPreview(limit: 1)]);
    expect(calls, 1, reason: 'appels simultanés regroupés');
    final all = both.first;
    expect(all.map((r) => r.recetteId), ['r1', 'r2']);
    expect(all.first.ingredients, ['Tomate', 'Riz']);
    expect(all.first.regimeLibelle, 'vegan');
    expect(all.last.typePlatLibelle, isNull);
    expect(all.last.occasions, isEmpty);

    final page = await api.getRecettesPreview(limit: 1, offset: 1);
    expect(page.single.titre, 'Soupe');
    expect(calls, 1, reason: 'servi depuis le cache');

    final ingredients = await api.getAllIngredients();
    expect(ingredients.map((i) => i.nomIngredient), ['Riz', 'Tomate']);
    expect(calls, 1);
  });
}
