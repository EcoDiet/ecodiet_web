import 'dart:convert';

import 'package:eco_diet_v0/services/ecodiet_api.dart';
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
    expect(requests.single.url.path, '/auth/login');
    expect(jsonDecode(requests.single.body),
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
}
