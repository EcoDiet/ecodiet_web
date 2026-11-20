import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'favorites_service.dart';
import '../models/recette.dart';
import '../models/taste_profile.dart';
import '../models/user.dart' as app_models;
import '../models/user.dart' hide User;

const String kMarmitonImageBaseUrl = 'https://assets.afcdn.com/recipe/';
const String kGcpImageBaseUrl =
    'https://storage.googleapis.com/gcs_dataiku/dataiku/staging/node_7e227912/ECODIETYNOV/0RUJIdkr/';
bool kDisableNetworkImages = false;

/// Journal des erreurs récupérées (fallbacks) : visible en debug uniquement.
final Logger _log = Logger();

/// Trace une erreur volontairement absorbée. `expected` : fallback normal
/// (ex. tentative de décodage), journalisé au niveau trace.
void _logIgnored(
  String where,
  Object error,
  StackTrace stack, {
  bool expected = false,
}) {
  final message = '$where: erreur ignoree';
  if (expected) {
    _log.t(message, error: error, stackTrace: stack);
  } else {
    _log.w(message, error: error, stackTrace: stack);
  }
}

/// Retourne l'URL complète d'une image recette à partir du nom de fichier stocké en BDD.
String recetteImageUrl(String photo) {
  if (kDisableNetworkImages) return '';
  if (photo.isEmpty) return '';
  if (photo.startsWith('http')) return photo;
  if (photo.toLowerCase().endsWith('.jpg') ||
      photo.toLowerCase().endsWith('.jpeg') ||
      photo.toLowerCase().endsWith('.png') ||
      photo.toLowerCase().endsWith('.webp')) {
    return '$kGcpImageBaseUrl$photo';
  }
  return '$kMarmitonImageBaseUrl$photo';
}

/// Service API principal pour EcoDiet
/// Centralise toutes les opérations entre le front-end et la base de données
class EcoDietApi {
  static final EcoDietApi _instance = EcoDietApi._internal();

  // Session utilisateur courante
  app_models.User? _currentUser;
  bool _useGcpBridge = false;
  String _gcpBridgeBaseUrl = '';
  String? _gcpBridgeApiKey;
  // Service d'authentification (server/auth). Vide : ancienne connexion
  // côté navigateur via dim_utilisateur.
  String _authBaseUrl = '';
  String? _sessionToken;
  late http.Client _authHttp = http.Client();
  List<Map<String, dynamic>>? _bridgeRecettesCache;
  DateTime? _bridgeRecettesCacheAt;
  static const Duration _bridgeDataCacheTtl = Duration(minutes: 5);
  final Map<String, List<Map<String, dynamic>>> _bridgeTableCache = {};
  final Map<String, DateTime> _bridgeTableCacheAt = {};
  final Map<String, RecetteComplete> _bridgeRecetteCompleteCache = {};
  final Map<String, DateTime> _bridgeRecetteCompleteCacheAt = {};
  bool? _bridgeFavoritesEndpointAvailable = false;
  static const bool _debugFolders = kDebugMode;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const Duration _bridgeSessionInactivityLimit = Duration(hours: 2);
  static const String _bridgeSessionUserKey = 'bridge_session_user';
  static const String _bridgeSessionLastActivityKey =
      'bridge_session_last_activity';
  bool _localBridgeStateLoaded = false;
  Set<String> _localFavoriteIds = <String>{};
  Map<int, Set<String>> _localFolderRecipes = <int, Set<String>>{};
  List<Map<String, dynamic>> _localFolders = <Map<String, dynamic>>[];
  int _localNextFolderId = 1;

  factory EcoDietApi() => _instance;
  EcoDietApi._internal();
  bool get isBridgeMode => _useGcpBridge;

  /// Connexion via le service d'authentification (mots de passe vérifiés
  /// côté serveur) plutôt que via la table dim_utilisateur.
  bool get usesAuthService => _useGcpBridge && _authBaseUrl.isNotEmpty;

  /// Jeton de session délivré par le service d'authentification.
  String? get sessionToken => _sessionToken;

  @visibleForTesting
  set authHttpClient(http.Client client) => _authHttp = client;

  void configureDataBridge({
    required bool enabled,
    required String baseUrl,
    String? apiKey,
    String authUrl = '',
  }) {
    _authBaseUrl = authUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _useGcpBridge = enabled && baseUrl.trim().isNotEmpty;
    _gcpBridgeBaseUrl = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    _gcpBridgeApiKey = apiKey?.trim().isEmpty ?? true ? null : apiKey?.trim();
    _clearBridgeDataCaches();
  }

  void _clearBridgeDataCaches() {
    _bridgeRecettesCache = null;
    _bridgeRecettesCacheAt = null;
    _catalogCache = null;
    _catalogCacheAt = null;
    _bridgeTableCache.clear();
    _bridgeTableCacheAt.clear();
    _bridgeRecetteCompleteCache.clear();
    _bridgeRecetteCompleteCacheAt.clear();
    _bridgeFavoritesEndpointAvailable = false;
  }

  bool _isCacheValid(DateTime? at) {
    if (at == null) return false;
    return DateTime.now().difference(at) < _bridgeDataCacheTtl;
  }

  bool _isHttpBadRequestError(Object error) {
    final text = error.toString();
    return text.contains('Bridge HTTP 400');
  }

  Future<void> _saveBridgeSession(app_models.User user) async {
    try {
      await _storage.write(
        key: _bridgeSessionUserKey,
        value: jsonEncode({
          'user_id': user.userId,
          'email': user.email,
          'nom': user.nom,
          'prenom': user.prenom,
          if (_sessionToken != null) 'token': _sessionToken,
        }),
      );
      await _touchBridgeSessionActivity();
    } catch (error, stack) {
      _logIgnored('_saveBridgeSession', error, stack);
    }
  }

  Future<void> _touchBridgeSessionActivity() async {
    try {
      await _storage.write(
        key: _bridgeSessionLastActivityKey,
        value: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (error, stack) {
      _logIgnored('_touchBridgeSessionActivity', error, stack);
    }
  }

  Future<void> _clearBridgeSession() async {
    try {
      _sessionToken = null;
      _lastSyncedState = null;
      await _storage.delete(key: _bridgeSessionUserKey);
      await _storage.delete(key: _bridgeSessionLastActivityKey);
    } catch (error, stack) {
      _logIgnored('_clearBridgeSession', error, stack);
    }
  }

  Future<bool> _restoreBridgeSession() async {
    try {
      final rawUser = await _storage.read(key: _bridgeSessionUserKey);
      final rawLast = await _storage.read(key: _bridgeSessionLastActivityKey);
      if (rawUser == null || rawUser.trim().isEmpty) return false;
      if (rawLast == null || rawLast.trim().isEmpty) {
        await _clearBridgeSession();
        return false;
      }

      final last = DateTime.tryParse(rawLast)?.toUtc();
      if (last == null) {
        await _clearBridgeSession();
        return false;
      }

      final now = DateTime.now().toUtc();
      if (now.difference(last) > _bridgeSessionInactivityLimit) {
        await _clearBridgeSession();
        _currentUser = null;
        FavoritesService().clear();
        _resetLocalBridgeStateCache();
        return false;
      }

      final decoded = jsonDecode(rawUser);
      if (decoded is! Map) return false;
      final map = Map<String, dynamic>.from(decoded);
      final email = (map['email'] ?? '').toString().trim();
      if (email.isEmpty) return false;
      if (usesAuthService) {
        // Session d'avant le service d'authentification, ou jeton expiré :
        // reconnexion obligatoire.
        final token = map['token']?.toString();
        if (token == null || !isSessionTokenValid(token)) {
          await _clearBridgeSession();
          return false;
        }
        _sessionToken = token;
      }

      _currentUser = app_models.User(
        userId: map['user_id']?.toString(),
        email: email,
        nom: map['nom']?.toString(),
        prenom: map['prenom']?.toString(),
        passwordHash: null,
      );
      await _touchBridgeSessionActivity();
      _resetLocalBridgeStateCache();
      await _pullServerState();
      return true;
    } catch (error, stack) {
      _logIgnored('_restoreBridgeSession', error, stack);
      return false;
    }
  }

  Map<String, String> _bridgeHeaders() {
    final headers = <String, String>{'Accept': 'application/json'};
    if (_gcpBridgeApiKey != null) {
      headers['x-api-key'] = _gcpBridgeApiKey!;
    }
    return headers;
  }

  /// Appel JSON au service d'authentification : (code HTTP, corps).
  Future<(int, Map<String, dynamic>)> _authCall(String path,
      {Map<String, dynamic>? body, bool put = false}) async {
    final uri = Uri.parse('$_authBaseUrl$path');
    final headers = {
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (_sessionToken != null) 'Authorization': 'Bearer $_sessionToken',
    };
    final response = body == null
        ? await _authHttp.get(uri, headers: headers)
        : put
            ? await _authHttp.put(uri, headers: headers, body: jsonEncode(body))
            : await _authHttp.post(uri,
                headers: headers, body: jsonEncode(body));
    Map<String, dynamic> decoded = {};
    try {
      final value = jsonDecode(utf8.decode(response.bodyBytes));
      if (value is Map) decoded = Map<String, dynamic>.from(value);
    } catch (error, stack) {
      _logIgnored('_authCall', error, stack, expected: true);
    }
    return (response.statusCode, decoded);
  }

  String _authErrorMessage(Map<String, dynamic> body, String fallback) {
    final message = body['error']?.toString().trim() ?? '';
    return message.isEmpty ? fallback : message;
  }

  app_models.User _userFromAuth(Map<String, dynamic> json, String email) {
    String? text(String key) {
      final value = json[key]?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    }

    return app_models.User(
      userId: text('user_id'),
      email: text('email') ?? email,
      nom: text('nom'),
      prenom: text('prenom'),
      passwordHash: null,
    );
  }

  Future<ApiResult<app_models.User>> _loginWithAuthService(
      String email, String password) async {
    try {
      final (status, body) = await _authCall('/auth/login',
          body: {'email': email, 'password': password});
      final user = body['user'];
      final token = body['token']?.toString();
      if (status != 200 || user is! Map || token == null) {
        return ApiResult.error(_authErrorMessage(
            body, 'Erreur lors de la connexion : identifiants invalides.'));
      }
      _sessionToken = token;
      _currentUser = _userFromAuth(Map<String, dynamic>.from(user), email);
      await _pullServerState();
      await _applyLocalIdentity();
      await _saveBridgeSession(_currentUser!);
      _resetLocalBridgeStateCache();
      return ApiResult.success(_currentUser!);
    } catch (e) {
      return ApiResult.error('Service de connexion injoignable : $e');
    }
  }

  /// Disponibilité d'un e-mail ou d'un pseudo ; `true` en cas de doute
  /// (l'inscription tranchera par un 409).
  Future<bool> _authAvailable(String route, String key, String value) async {
    try {
      final (status, body) = await _authCall(route, body: {key: value});
      if (status == 200 && body['available'] is bool) {
        return body['available'] as bool;
      }
    } catch (error, stack) {
      _logIgnored(route, error, stack);
    }
    return true;
  }

  // Données du compte (favoris, dossiers, préférences, nom) : enregistrées
  // sur le serveur (/me/state), l'appareil en garde une copie qui sert de
  // cache et de mode hors connexion.
  static const List<String> _stateKeys = [
    'favorites',
    'folders',
    'folder_recipes',
    'preferences',
    'identity',
  ];

  /// Dernier document échangé avec le serveur : évite les envois inutiles
  /// (une simple lecture réenregistre l'état local).
  String? _lastSyncedState;

  Future<Map<String, dynamic>> _localStateDocument() async {
    final doc = <String, dynamic>{};
    for (final key in _stateKeys) {
      final raw = await _storage.read(key: _storageKey(key));
      if (raw == null || raw.trim().isEmpty) continue;
      try {
        final value = jsonDecode(raw);
        // Collection vide = clé absente : même document des deux côtés.
        if ((value is List && value.isEmpty) || (value is Map && value.isEmpty)) {
          continue;
        }
        doc[key] = value;
      } catch (error, stack) {
        _logIgnored('_localStateDocument', error, stack, expected: true);
      }
    }
    return doc;
  }

  /// Récupère les données du compte depuis le serveur (connexion, reprise de
  /// session). Compte encore vide côté serveur : l'appareil y envoie ce
  /// qu'il a déjà.
  Future<void> _pullServerState() async {
    if (!usesAuthService || _sessionToken == null || _currentUser == null) {
      return;
    }
    try {
      final (status, body) = await _authCall('/me/state');
      final state = body['state'];
      if (status != 200 || state is! Map) return;
      if (state.isEmpty) {
        _lastSyncedState = jsonEncode(<String, dynamic>{});
        if ((await _localStateDocument()).isNotEmpty) await _pushServerState();
        return;
      }
      for (final key in _stateKeys) {
        final value = state[key];
        if (value == null) {
          await _storage.delete(key: _storageKey(key));
        } else {
          await _storage.write(key: _storageKey(key), value: jsonEncode(value));
        }
      }
      _resetLocalBridgeStateCache();
      _lastSyncedState = jsonEncode(await _localStateDocument());
    } catch (error, stack) {
      _logIgnored('_pullServerState', error, stack);
    }
  }

  /// Envoie les données du compte au serveur après une modification.
  Future<void> _pushServerState() async {
    if (!usesAuthService || _sessionToken == null || _currentUser == null) {
      return;
    }
    try {
      final doc = await _localStateDocument();
      final encoded = jsonEncode(doc);
      if (encoded == _lastSyncedState) return;
      final (status, body) =
          await _authCall('/me/state', body: {'state': doc}, put: true);
      if (status == 200) _lastSyncedState = encoded;
      if (status != 200) {
        _logIgnored('_pushServerState', 'HTTP $status ${body['error'] ?? ''}',
            StackTrace.current);
      }
    } catch (error, stack) {
      _logIgnored('_pushServerState', error, stack);
    }
  }

  /// Demande un lien de réinitialisation par e-mail. `null` si la demande
  /// est partie (le service répond pareil que le compte existe ou non),
  /// sinon le message d'erreur.
  Future<String?> requestPasswordReset(String email) async {
    if (!usesAuthService) return 'Réinitialisation indisponible pour le moment.';
    try {
      final (status, body) = await _authCall('/auth/password-reset/request',
          body: {'email': email.trim().toLowerCase()});
      if (status == 200) return null;
      return _authErrorMessage(body, 'Demande impossible pour le moment.');
    } catch (e) {
      return 'Service injoignable : $e';
    }
  }

  /// Enregistre le nouveau mot de passe choisi depuis le lien reçu par e-mail.
  /// `null` si c'est fait, sinon le message d'erreur.
  Future<String?> confirmPasswordReset(String token, String password) async {
    if (!usesAuthService) return 'Réinitialisation indisponible pour le moment.';
    try {
      final (status, body) = await _authCall('/auth/password-reset/confirm',
          body: {'token': token, 'password': password});
      if (status == 200) return null;
      return _authErrorMessage(body, 'Lien invalide ou expiré.');
    } catch (e) {
      return 'Service injoignable : $e';
    }
  }

  /// Ligne de préférences de l'utilisateur connecté, lue via /auth/me.
  Future<Map<String, dynamic>?> _authPreferencesRow() async {
    if (_sessionToken == null) return null;
    final (status, body) = await _authCall('/auth/me');
    final prefs = body['preferences'];
    if (status != 200 || prefs is! Map) return null;
    return Map<String, dynamic>.from(prefs);
  }

  Future<dynamic> _bridgeGet(String path, {Map<String, String>? query}) async {
    if (_currentUser != null) {
      await _touchBridgeSessionActivity();
    }
    final uri = Uri.parse('$_gcpBridgeBaseUrl$path').replace(
      queryParameters: query?.isEmpty ?? true ? null : query,
    );
    final response = await http.get(uri, headers: _bridgeHeaders());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Bridge HTTP ${response.statusCode} ${response.reasonPhrase ?? ''}',
      );
    }
    if (response.body.isEmpty) return null;
    return _decodeBridgeBody(response.body);
  }

  Future<dynamic> _bridgePost(String path, Map<String, dynamic> body) async {
    if (_currentUser != null) {
      await _touchBridgeSessionActivity();
    }
    final uri = Uri.parse('$_gcpBridgeBaseUrl$path');
    final headers = <String, String>{
      ..._bridgeHeaders(),
      'Content-Type': 'application/json',
    };
    final response =
        await http.post(uri, headers: headers, body: jsonEncode(body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final bodyPreview = response.body.trim().isEmpty
          ? '(empty body)'
          : response.body.trim();
      throw Exception(
        'Bridge HTTP ${response.statusCode} ${response.reasonPhrase ?? ''} - $bodyPreview',
      );
    }
    if (response.body.isEmpty) return null;
    return _decodeBridgeBody(response.body);
  }

  Map<String, dynamic> _stripNulls(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    input.forEach((key, value) {
      if (value == null) return;
      if (value is Map<String, dynamic>) {
        final nested = _stripNulls(value);
        if (nested.isNotEmpty) out[key] = nested;
        return;
      }
      out[key] = value;
    });
    return out;
  }

  String _storageKey(String suffix) {
    final userKey =
        (_currentUser?.userId ?? _currentUser?.email ?? 'anon').toString();
    return 'bridge_local_${userKey}_$suffix';
  }

  Future<void> _ensureLocalBridgeStateLoaded() async {
    if (_localBridgeStateLoaded) return;
    try {
      final favRaw = await _storage.read(key: _storageKey('favorites'));
      if (favRaw != null && favRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(favRaw);
        if (decoded is List) {
          _localFavoriteIds = decoded.map((e) => '$e').toSet();
        }
      }

      final foldersRaw = await _storage.read(key: _storageKey('folders'));
      if (foldersRaw != null && foldersRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(foldersRaw);
        if (decoded is List) {
          _localFolders = decoded
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList();
          for (final f in _localFolders) {
            final fid = _toInt(f['folder_id'] ?? f['id']);
            if (fid >= _localNextFolderId) _localNextFolderId = fid + 1;
          }
        }
      }

      final folderRecipesRaw =
          await _storage.read(key: _storageKey('folder_recipes'));
      if (folderRecipesRaw != null && folderRecipesRaw.trim().isNotEmpty) {
        final decoded = jsonDecode(folderRecipesRaw);
        if (decoded is Map) {
          final map = <int, Set<String>>{};
          decoded.forEach((k, v) {
            final id = int.tryParse('$k');
            if (id == null) return;
            if (v is List) {
              map[id] = v.map((e) => '$e').toSet();
            }
          });
          _localFolderRecipes = map;
        }
      }
    } catch (error, stack) {
      _logIgnored('_ensureLocalBridgeStateLoaded', error, stack);
      _localFavoriteIds = <String>{};
      _localFolderRecipes = <int, Set<String>>{};
      _localFolders = <Map<String, dynamic>>[];
      _localNextFolderId = 1;
    } finally {
      _localBridgeStateLoaded = true;
      if (_debugFolders) {
        debugPrint(
          '[FOLDER_DEBUG][LOAD] loaded=$_localBridgeStateLoaded folders=${_localFolders.length} links=${_localFolderRecipes.length} nextId=$_localNextFolderId user=${_currentUser?.email}',
        );
      }
    }
  }

  Future<void> _saveLocalBridgeState() async {
    try {
      await _storage.write(
        key: _storageKey('favorites'),
        value: jsonEncode(_localFavoriteIds.toList()),
      );
      await _storage.write(
        key: _storageKey('folders'),
        value: jsonEncode(_localFolders),
      );
      final serializable = <String, List<String>>{};
      _localFolderRecipes.forEach((k, v) {
        serializable['$k'] = v.toList();
      });
      await _storage.write(
        key: _storageKey('folder_recipes'),
        value: jsonEncode(serializable),
      );
      await _pushServerState();
      if (_debugFolders) {
        debugPrint(
          '[FOLDER_DEBUG][SAVE] folders=${_localFolders.length} links=${serializable.length} data=$serializable',
        );
      }
    } catch (error, stack) {
      _logIgnored('_saveLocalBridgeState', error, stack);
    }
  }

  void _resetLocalBridgeStateCache() {
    _localBridgeStateLoaded = false;
    _localFavoriteIds = <String>{};
    _localFolderRecipes = <int, Set<String>>{};
    _localFolders = <Map<String, dynamic>>[];
    _localNextFolderId = 1;
    _clearBridgeDataCaches();
  }

  String _hashPassword(String plainPassword) {
    final bytes = utf8.encode(plainPassword);
    return sha256.convert(bytes).toString();
  }

  String _hashPasswordMd5(String plainPassword) {
    final bytes = utf8.encode(plainPassword);
    return md5.convert(bytes).toString();
  }

  String _hashPasswordSha1(String plainPassword) {
    final bytes = utf8.encode(plainPassword);
    return sha1.convert(bytes).toString();
  }

  bool _matchesStoredPasswordHash({
    required String plainPassword,
    required String storedHash,
  }) {
    final normalizedStored = storedHash.trim().toLowerCase();
    if (normalizedStored.isEmpty) return false;

    final sha256Hash = _hashPassword(plainPassword).toLowerCase();
    if (normalizedStored == sha256Hash) return true;

    // Compat legacy: certains jeux de donnees historiques utilisaient md5/sha1.
    final md5Hash = _hashPasswordMd5(plainPassword).toLowerCase();
    if (normalizedStored == md5Hash) return true;

    final sha1Hash = _hashPasswordSha1(plainPassword).toLowerCase();
    if (normalizedStored == sha1Hash) return true;

    return false;
  }

  dynamic _decodeBridgeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;

    try {
      return jsonDecode(trimmed);
    } catch (error, stack) {
      _logIgnored('_decodeBridgeBody', error, stack, expected: true);
      // Some bridge implementations return concatenated JSON objects
      // without an outer array. Try lenient decoding.
      if (!trimmed.startsWith('[') && trimmed.contains('},{')) {
        try {
          return jsonDecode('[$trimmed]');
        } catch (error, stack) {
          _logIgnored('_decodeBridgeBody', error, stack, expected: true);
        }
      }

      // NDJSON / one object per line fallback.
      final lines = trimmed
          .split(RegExp(r'\r?\n'))
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty)
          .toList();
      if (lines.isNotEmpty && lines.every((l) => l.startsWith('{') && l.endsWith('}'))) {
        try {
          return lines.map((l) => jsonDecode(l)).toList();
        } catch (error, stack) {
          _logIgnored('_decodeBridgeBody', error, stack, expected: true);
        }
      }

      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _bridgeGetRecettesFromRoot() async {
    if (_bridgeRecettesCache != null && _isCacheValid(_bridgeRecettesCacheAt)) {
      return _bridgeRecettesCache!;
    }

    final root = await _bridgeGet('', query: {'table': 'fact_recette_base'});
    List rawRows;
    if (root is List) {
      rawRows = root;
    } else if (root is Map) {
      final payload = Map<String, dynamic>.from(root);
      final fromWrapper = payload['donneesBigQuery'];
      if (fromWrapper is! List) {
        throw Exception('Format bridge invalide: donneesBigQuery[] manquant');
      }
      rawRows = fromWrapper;
    } else {
      throw Exception('Format bridge invalide: liste ou objet JSON attendu');
    }

    final normalized = rawRows
        .whereType<Map>()
        .map((row) => _normalizeBridgeRecetteRow(Map<String, dynamic>.from(row)))
        .toList();
    _bridgeRecettesCache = normalized;
    _bridgeRecettesCacheAt = DateTime.now();
    return normalized;
  }

  Future<List<Map<String, dynamic>>> _bridgeGetTable(String table) async {
    final cached = _bridgeTableCache[table];
    if (cached != null && _isCacheValid(_bridgeTableCacheAt[table])) {
      return cached;
    }
    final res = await _bridgeGet('', query: {'table': table});
    List<Map<String, dynamic>> rows = [];
    if (res is List) {
      rows = res
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } else if (res is Map) {
      final wrappedRows = res['donneesBigQuery'];
      if (wrappedRows is List) {
        rows = wrappedRows
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    }
    _bridgeTableCache[table] = rows;
    _bridgeTableCacheAt[table] = DateTime.now();
    return rows;
  }

  Future<List<Map<String, dynamic>>> _bridgeGetTableAny(
      List<String> tableNames) async {
    for (final name in tableNames) {
      try {
        final rows = await _bridgeGetTable(name);
        if (rows.isNotEmpty) return rows;
      } catch (error, stack) {
        _logIgnored('_bridgeGetTableAny', error, stack);
      }
    }
    return [];
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  Future<List<RecettePreview>> _bridgeBuildPreviewsFromBase(
    List<Map<String, dynamic>> baseRows,
  ) async {
    final parts = await Future.wait([
      _bridgeGetTableAny(['dim_ingredients', 'dim_ingredient']),
      _bridgeGetTableAny(['fact_ingredients_recette']),
      _bridgeGetTableAny(['dim_equipement']),
      _bridgeGetTableAny(['fact_recette_equipements', 'fact_recette_equipement']),
      _bridgeGetTableAny(['dim_regime']),
      _bridgeGetTableAny(['fact_recette_regime']),
      _bridgeGetTableAny(['dim_allergene']),
      _bridgeGetTableAny(['fact_recette_allergene']),
      _bridgeGetTableAny(['dim_occasion']),
      _bridgeGetTableAny(['fact_recette_occasion']),
      _bridgeGetTableAny(['dim_type_plat']),
      _bridgeGetTableAny(['fact_recette_type_plat']),
    ]);
    final dimIng = parts[0];
    final factIng = parts[1];
    final dimEq = parts[2];
    final factEq = parts[3];
    final dimReg = parts[4];
    final factReg = parts[5];
    final dimAll = parts[6];
    final factAll = parts[7];
    final dimOcc = parts[8];
    final factOcc = parts[9];
    final dimType = parts[10];
    final factType = parts[11];

    final ingById = {for (final r in dimIng) _toInt(r['ingredient_id']): '${r['nom_ingredient'] ?? ''}'};
    final eqById = {for (final r in dimEq) _toInt(r['equipement_id']): '${r['nom_equipement'] ?? ''}'};
    final regById = {for (final r in dimReg) _toInt(r['regime_id']): '${r['libelle'] ?? ''}'};
    final allById = {for (final r in dimAll) _toInt(r['allergene_id']): '${r['libelle'] ?? ''}'};
    final occById = {for (final r in dimOcc) _toInt(r['occasion_id']): '${r['libelle'] ?? ''}'};
    final typeById = {for (final r in dimType) _toInt(r['type_plat_id']): '${r['libelle'] ?? ''}'};

    final ingsByRecette = <String, List<String>>{};
    for (final r in factIng) {
      final id = '${r['recette_id'] ?? ''}';
      final v = ingById[_toInt(r['ingredient_id'])] ?? '';
      if (id.isNotEmpty && v.trim().isNotEmpty) {
        (ingsByRecette[id] ??= []).add(v);
      }
    }
    final eqsByRecette = <String, List<String>>{};
    for (final r in factEq) {
      final id = '${r['recette_id'] ?? ''}';
      final v = eqById[_toInt(r['equipement_id'])] ?? '';
      if (id.isNotEmpty && v.trim().isNotEmpty) {
        (eqsByRecette[id] ??= []).add(v);
      }
    }
    final allsByRecette = <String, List<String>>{};
    for (final r in factAll) {
      final id = '${r['recette_id'] ?? ''}';
      final v = allById[_toInt(r['allergene_id'])] ?? '';
      if (id.isNotEmpty && v.trim().isNotEmpty) {
        (allsByRecette[id] ??= []).add(v);
      }
    }
    final occsByRecette = <String, List<String>>{};
    for (final r in factOcc) {
      final id = '${r['recette_id'] ?? ''}';
      final v = occById[_toInt(r['occasion_id'])] ?? '';
      if (id.isNotEmpty && v.trim().isNotEmpty) {
        (occsByRecette[id] ??= []).add(v);
      }
    }
    final regByRecette = <String, String>{};
    for (final r in factReg) {
      final id = '${r['recette_id'] ?? ''}';
      final v = regById[_toInt(r['regime_id'])] ?? '';
      if (id.isNotEmpty && v.trim().isNotEmpty) regByRecette[id] = v;
    }
    final typeByRecette = <String, String>{};
    for (final r in factType) {
      final id = '${r['recette_id'] ?? ''}';
      final v = typeById[_toInt(r['type_plat_id'])] ?? '';
      if (id.isNotEmpty && v.trim().isNotEmpty) typeByRecette[id] = v;
    }

    return baseRows.map((m) {
      final rid = '${m['recette_id'] ?? ''}';
      return RecettePreview(
        recetteId: rid,
        titre: '${m['titre'] ?? ''}',
        photo: '${m['photo'] ?? ''}',
        dureeMinute: _toInt(m['duree_minute']),
        tempsBinId: _toInt(m['temps_bin_id']),
        typePlatLibelle: typeByRecette[rid],
        ingredients: (ingsByRecette[rid] ?? const []).toSet().toList(),
        equipements: (eqsByRecette[rid] ?? const []).toSet().toList(),
        allergenes: (allsByRecette[rid] ?? const []).toSet().toList(),
        occasions: (occsByRecette[rid] ?? const []).toSet().toList(),
        regimeLibelle: regByRecette[rid],
      );
    }).toList();
  }

  List<String> _splitRawListText(String raw) {
    var text = raw.trim();
    if (text.isEmpty) return const [];
    if (text.startsWith('[') && text.endsWith(']')) {
      text = text.substring(1, text.length - 1);
    }
    return text
        .split(RegExp(r'''['"]\s*,\s*['"]|,\s*'''))
        .map((s) => s.replaceAll(RegExp(r'''^['"]+|['"]+$'''), '').trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> _normalizeBridgeRecetteRow(Map<String, dynamic> row) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    String pick(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = row[key];
        if (value != null && '$value'.trim().isNotEmpty) return '$value';
      }
      return fallback;
    }

    return {
      'recette_id': pick(['recette_id', 'id', 'recipe_id', 'recetteId']),
      'titre': pick(['titre', 'title', 'nom', 'name']),
      'photo': pick(['photo', 'image_url', 'image', 'photo_url']),
      'etapes': pick(['etapes', 'steps', 'description']),
      'duree_minute': toInt(
        row['duree_minute'] ??
            row['duration'] ??
            row['duree'] ??
            row['duration_minutes'],
      ),
      'temps_bin_id': toInt(row['temps_bin_id'] ?? row['tempsBinId']),
    };
  }

  RecetteComplete _recetteCompleteFromBridgeMap(Map<String, dynamic> map) {
    final recette = Recette.fromMap(
      (map['recette'] ?? map) as Map<String, dynamic>,
    );

    TempsBin? tempsBin;
    if (map['temps_bin'] is Map<String, dynamic>) {
      tempsBin = TempsBin.fromMap(map['temps_bin'] as Map<String, dynamic>);
    }

    final allergenes = (map['allergenes'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Allergene.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    final equipements = (map['equipements'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Equipement.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    final ingredients = (map['ingredients'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Ingredient.fromMap(Map<String, dynamic>.from(m)))
        .toList();
    final occasions = (map['occasions'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Occasion.fromMap(Map<String, dynamic>.from(m)))
        .toList();

    Regime? regime;
    if (map['regime'] is Map<String, dynamic>) {
      regime = Regime.fromMap(map['regime'] as Map<String, dynamic>);
    }
    TypePlat? typePlat;
    if (map['type_plat'] is Map<String, dynamic>) {
      typePlat = TypePlat.fromMap(map['type_plat'] as Map<String, dynamic>);
    }

    return RecetteComplete(
      recette: recette,
      tempsBin: tempsBin,
      allergenes: allergenes,
      equipements: equipements,
      ingredients: ingredients,
      occasions: occasions,
      regime: regime,
      typePlat: typePlat,
    );
  }

  /// Obtient l'utilisateur actuellement connecté
  app_models.User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<bool> restoreSession() async {
    return _restoreBridgeSession();
  }

  // ============================================================================
  // AUTHENTIFICATION
  // ============================================================================

  /// Inscription d'un nouvel utilisateur
  Future<ApiResult<app_models.User>> register({
    required String email,
    required String password,
    String? nom,
    String? prenom,
    String? pseudo,
    Map<String, dynamic>? profile,
  }) async {
    final normalizedEmail = email.toLowerCase().trim();
    final safeNom = (nom ?? '').trim();
    final safePrenom = (prenom ?? '').trim();
    final safePassword = password.trim();
    final safePseudo = (pseudo ?? '').trim();
    if (normalizedEmail.isEmpty ||
        safePassword.isEmpty ||
        safeNom.isEmpty ||
        safePrenom.isEmpty ||
        safePseudo.isEmpty) {
      return ApiResult.error(
        'Nom, prénom, pseudo, e-mail et mot de passe sont requis.',
      );
    }
    if (usesAuthService) {
      try {
        final (status, body) = await _authCall('/auth/register', body: {
          if (profile != null) ...profile,
          'email': normalizedEmail,
          'password': safePassword,
          'nom': safeNom,
          'prenom': safePrenom,
          'pseudo': safePseudo,
        });
        final user = body['user'];
        if (status != 201 || user is! Map) {
          return ApiResult.error(
              _authErrorMessage(body, 'Inscription impossible.'));
        }
        // Comme avant : l'inscription ne connecte pas, l'app enchaîne
        // avec login().
        _currentUser = null;
        _resetLocalBridgeStateCache();
        return ApiResult.success(
            _userFromAuth(Map<String, dynamic>.from(user), normalizedEmail));
      } catch (e) {
        return ApiResult.error('Service d\'inscription injoignable : $e');
      }
    }

    final emailAvailable = await isEmailAvailable(normalizedEmail);
    if (!emailAvailable) {
      return ApiResult.error('Cet e-mail est déjà inscrit.');
    }

    final hashedPassword = _hashPassword(safePassword);

    final richPayload = _stripNulls(<String, dynamic>{
      'email': normalizedEmail,
      'password': hashedPassword,
      'mdp': hashedPassword,
      'mot_de_passe': hashedPassword,
      'nom': safeNom,
      'prenom': safePrenom,
      'pseudo': safePseudo,
      if (profile != null) ...profile,
      // Defaults to avoid null-typed BigQuery parameters on fragile backends.
      'budget_par_repas': profile?['budget_par_repas'] ?? 0.0,
      'tolerance_epice': profile?['tolerance_epice'] ?? 0,
      'cuisine_preferee': profile?['cuisine_preferee'] ?? '',
      'fenetre_temps_soir_min': profile?['fenetre_temps_soir_min'] ?? 0,
    });

    String userId = 'bridge_${DateTime.now().microsecondsSinceEpoch}';
    try {
      final res = await _bridgePost('/users', richPayload);
      if (res is Map && res['user_id'] != null) {
        userId = '${res['user_id']}';
      }
    } catch (e) {
      return ApiResult.error(
        'Inscription impossible via Cloud Run : $e',
      );
    }

    final user = app_models.User(
      userId: userId,
      email: normalizedEmail,
      nom: safeNom,
      prenom: safePrenom,
      passwordHash: null,
    );
    _currentUser = null;
    _resetLocalBridgeStateCache();
    return ApiResult.success(user);
  }

  /// Connexion d'un utilisateur
  Future<ApiResult<app_models.User>> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.toLowerCase().trim();
    final rawPassword = password.trim();
    if (usesAuthService) {
      return _loginWithAuthService(normalizedEmail, rawPassword);
    }
    try {
      final rows = await _bridgeGetTableAny(['dim_utilisateur']);
      final row = rows.cast<Map<String, dynamic>?>().firstWhere(
            (r) {
              if (r == null) return false;
              final rowEmail =
                  (r['email'] ?? '').toString().trim().toLowerCase();
              final rowPassword = (r['mdp'] ??
                      r['mot_de_passe'] ??
                      r['password'] ??
                      '')
                  .toString()
                  .trim();
              return rowEmail == normalizedEmail &&
                  rowPassword.isNotEmpty &&
                  _matchesStoredPasswordHash(
                    plainPassword: rawPassword,
                    storedHash: rowPassword,
                  );
            },
            orElse: () => null,
          );

      if (row == null) {
        return ApiResult.error(
          'Erreur lors de la connexion : identifiants invalides.',
        );
      }

      final user = app_models.User(
        userId: (row['user_id'] ?? row['id'] ?? '').toString().isEmpty
            ? null
            : (row['user_id'] ?? row['id']).toString(),
        email: normalizedEmail,
        nom: row['nom']?.toString(),
        prenom: row['prenom']?.toString(),
        passwordHash: null,
      );
      _currentUser = user;
      await _applyLocalIdentity();
      await _saveBridgeSession(_currentUser!);
      _resetLocalBridgeStateCache();
      return ApiResult.success(_currentUser!);
    } catch (e) {
      return ApiResult.error(
        'Erreur lors de la connexion : $e',
      );
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    _currentUser = null;
    await _clearBridgeSession();
    FavoritesService().clear();
    _resetLocalBridgeStateCache();
    return;
  }

  /// Met à jour le profil utilisateur
  Future<ApiResult<app_models.User>> updateProfile({
    String? nom,
    String? prenom,
    String? photoUrl,
  }) async {
    if (_currentUser == null) {
      return ApiResult.error('Non connecté');
    }

    // Nom conservé sur l'appareil et, avec le service d'authentification,
    // dans les données du compte (/me/state).
    _currentUser = app_models.User(
      userId: _currentUser!.userId,
      email: _currentUser!.email,
      nom: nom ?? _currentUser!.nom,
      prenom: prenom ?? _currentUser!.prenom,
      photoUrl: photoUrl ?? _currentUser!.photoUrl,
    );
    await _saveBridgeSession(_currentUser!);
    try {
      await _storage.write(
        key: _storageKey('identity'),
        value: jsonEncode(
            {'nom': _currentUser!.nom, 'prenom': _currentUser!.prenom}),
      );
      await _pushServerState();
    } catch (error, stack) {
      _logIgnored('updateProfile', error, stack);
    }
    return ApiResult.success(_currentUser!);
  }

  // ============================================================================
  // RECETTES
  // ============================================================================

  Future<List<Recette>> getAllRecettes() async {
    try {
      final res = await _bridgeGet('/v1/recettes');
      return (res as List).map((m) => Recette.fromMap(m)).toList();
    } catch (error, stack) {
      _logIgnored('getAllRecettes', error, stack);
    }
    try {
      final rows = await _bridgeGetRecettesFromRoot();
      return rows.map(Recette.fromMap).toList();
    } catch (error, stack) {
      _logIgnored('getAllRecettes', error, stack);
    }
    throw Exception(
      'Mode gcp_bridge actif, mais impossible de recuperer les recettes depuis Cloud Run.',
    );
  }

  /// Retourne les recettes avec leur type de plat en une seule requête
  Future<List<RecettePreview>> getRecettesPreview(
      {int limit = 20, int offset = 0}) async {
    final catalog = await _catalogPreviews();
    if (catalog != null) {
      if (offset >= catalog.length) return [];
      return catalog.sublist(offset, (offset + limit).clamp(0, catalog.length));
    }
    try {
      final rows = await _bridgeGetRecettesFromRoot();
      if (offset >= rows.length) return [];
      final end = (offset + limit) > rows.length ? rows.length : offset + limit;
      final page = rows.sublist(offset, end);
      return await _bridgeBuildPreviewsFromBase(page);
    } catch (error, stack) {
      _logIgnored('getRecettesPreview', error, stack);
    }
    try {
      final res = await _bridgeGet(
        '/v1/recettes/preview',
        query: {'limit': '$limit', 'offset': '$offset'},
      );
      return (res as List).map((m) => RecettePreview.fromMap(m)).toList();
    } catch (error, stack) {
      _logIgnored('getRecettesPreview', error, stack);
    }
    throw Exception(
      'Mode gcp_bridge actif, mais impossible de recuperer les previews recettes depuis Cloud Run.',
    );
  }

  List<RecettePreview>? _catalogCache;
  DateTime? _catalogCacheAt;
  Future<List<RecettePreview>?>? _catalogPending;

  /// Vignettes jointes côté serveur (/catalog/previews) : une requête
  /// compressée au lieu des 13 tables brutes. `null` si indisponible.
  Future<List<RecettePreview>?> _catalogPreviews() async {
    if (!usesAuthService) return null;
    if (_catalogCache != null && _isCacheValid(_catalogCacheAt)) {
      return _catalogCache;
    }
    // Appels simultanés (accueil : vignettes et filtres) : une seule requête.
    return _catalogPending ??=
        _fetchCatalog().whenComplete(() => _catalogPending = null);
  }

  Future<List<RecettePreview>?> _fetchCatalog() async {
    try {
      final response = await _authHttp.get(
        Uri.parse('$_authBaseUrl/catalog/previews'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List || decoded.isEmpty) return null;
      List<String> strings(dynamic v) =>
          v is List ? v.map((e) => '$e').where((e) => e.isNotEmpty).toList() : [];
      String? optional(dynamic v) {
        final s = v?.toString().trim() ?? '';
        return s.isEmpty ? null : s;
      }

      final previews = [
        for (final raw in decoded.whereType<Map>())
          RecettePreview(
            recetteId: '${raw['recette_id'] ?? ''}',
            titre: '${raw['titre'] ?? ''}',
            photo: '${raw['photo'] ?? ''}',
            dureeMinute: _toInt(raw['duree_minute']),
            tempsBinId: _toInt(raw['temps_bin_id']),
            typePlatLibelle: optional(raw['type_plat']),
            regimeLibelle: optional(raw['regime']),
            ingredients: strings(raw['ingredients']),
            equipements: strings(raw['equipements']),
            allergenes: strings(raw['allergenes']),
            occasions: strings(raw['occasions']),
          ),
      ];
      _catalogCache = previews;
      _catalogCacheAt = DateTime.now();
      return previews;
    } catch (error, stack) {
      _logIgnored('_catalogPreviews', error, stack);
      return null;
    }
  }

  /// Fiche complète jointe côté serveur (/catalog/recettes/:id) : une petite
  /// requête au lieu de 13 tables brutes. `null` si indisponible.
  Future<RecetteComplete?> _catalogRecette(String recetteId) async {
    if (!usesAuthService) return null;
    try {
      final response = await _authHttp.get(
        Uri.parse(
            '$_authBaseUrl/catalog/recettes/${Uri.encodeComponent(recetteId)}'),
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) return null;
      final complete = _recetteCompleteFromBridgeMap(decoded);
      // Recettes sans table de liaison : textes bruts de stg_recettes.
      List<String> raw(String key) =>
          _splitRawListText('${decoded[key] ?? ''}');
      final ingredients = complete.ingredients.isNotEmpty
          ? complete.ingredients
          : [
              for (final (i, nom) in raw('ingredients_texte').indexed)
                Ingredient(ingredientId: -(i + 1), nomIngredient: nom),
            ];
      final equipements = complete.equipements.isNotEmpty
          ? complete.equipements
          : [
              for (final (i, nom) in raw('ustensiles_texte').indexed)
                Equipement(equipementId: -(i + 1), nomEquipement: nom),
            ];
      return RecetteComplete(
        recette: complete.recette,
        tempsBin: complete.tempsBin,
        allergenes: complete.allergenes,
        equipements: equipements,
        ingredients: ingredients,
        occasions: complete.occasions,
        regime: complete.regime,
        typePlat: complete.typePlat,
      );
    } catch (error, stack) {
      _logIgnored('_catalogRecette', error, stack);
      return null;
    }
  }

  /// Recettes (sans étapes) de [ids], dans l'ordre du catalogue : vignettes
  /// du service si disponibles (déjà en cache), sinon table brute.
  Future<List<Recette>> _recettesByIds(Set<String> ids) async {
    final catalog = await _catalogPreviews();
    if (catalog != null) {
      return [
        for (final p in catalog)
          if (ids.contains(p.recetteId))
            Recette(
              recetteId: p.recetteId,
              titre: p.titre,
              photo: p.photo,
              dureeMinute: p.dureeMinute,
              tempsBinId: p.tempsBinId,
            ),
      ];
    }
    final base = await _bridgeGetRecettesFromRoot();
    return base
        .where((r) => ids.contains('${r['recette_id'] ?? ''}'))
        .map((r) => Recette.fromMap(r))
        .toList();
  }

  Future<List<RecettePreview>> getAllRecettesPreview(
      {int pageSize = 1000}) async {
    final catalog = await _catalogPreviews();
    if (catalog != null) return List.of(catalog);

    final recettes = <RecettePreview>[];
    var offset = 0;

    while (true) {
      final page = await getRecettesPreview(limit: pageSize, offset: offset);
      recettes.addAll(page);
      if (page.length < pageSize) break;
      offset += pageSize;
    }

    return recettes;
  }

  /// Retourne les IDs des recettes favorites de l'utilisateur courant
  Future<Set<String>> getFavoriteIds() async {
    if (_currentUser == null) return {};
    await _ensureLocalBridgeStateLoaded();
    final ids = <String>{..._localFavoriteIds};
    try {
      final rows = await _bridgeGetFavoritesRows();
      ids.addAll(
        rows
            .map((r) => '${r['recette_id'] ?? r['recipe_id'] ?? ''}')
            .where((id) => id.isNotEmpty),
      );
    } catch (error, stack) {
      _logIgnored('getFavoriteIds', error, stack);
    }
    _localFavoriteIds = ids;
    await _saveLocalBridgeState();
    return ids;
  }

  /// Enregistre pour le compte les favoris ajoutés hors-ligne (stockés en mémoire
  /// via [FavoritesService]). Appelé après connexion / restauration de session
  /// pour que rien ne soit perdu. Ne supprime jamais côté serveur.
  Future<void> syncLocalFavorites() async {
    if (_currentUser == null) return;
    final local = FavoritesService().favorites;
    if (local.isEmpty) return;

    final existing = await getFavoriteIds();
    for (final fav in local) {
      if (!existing.contains(fav.id)) {
        await addToFavorites(fav.id);
      }
    }
  }

  Future<Recette?> getRecetteById(String recetteId) async {
    try {
      final rows = await _bridgeGetRecettesFromRoot();
      final match = rows.where((row) => row['recette_id'] == recetteId);
      if (match.isNotEmpty) return Recette.fromMap(match.first);
    } catch (error, stack) {
      _logIgnored('getRecetteById', error, stack);
    }
    try {
      final res = await _bridgeGet('/v1/recettes/$recetteId');
      return Recette.fromMap(res as Map<String, dynamic>);
    } catch (error, stack) {
      _logIgnored('getRecetteById', error, stack);
    }    return null;
  }

  Future<RecetteComplete?> getRecetteComplete(String recetteId) async {
    final cached = _bridgeRecetteCompleteCache[recetteId];
    if (cached != null &&
        _isCacheValid(_bridgeRecetteCompleteCacheAt[recetteId])) {
      return cached;
    }
    final fromCatalog = await _catalogRecette(recetteId);
    if (fromCatalog != null) {
      _bridgeRecetteCompleteCache[recetteId] = fromCatalog;
      _bridgeRecetteCompleteCacheAt[recetteId] = DateTime.now();
      return fromCatalog;
    }
    try {
      final recette = await getRecetteById(recetteId);
      if (recette == null) return null;

      final detailParts = await Future.wait([
        _bridgeGetTable('stg_recettes'),
        _bridgeGetTableAny(['fact_ingredients_recette']),
        _bridgeGetTableAny(['dim_ingredients', 'dim_ingredient']),
        _bridgeGetTableAny(
            ['fact_recette_equipements', 'fact_recette_equipement']),
        _bridgeGetTable('dim_equipement'),
        _bridgeGetTableAny(['fact_recette_allergene']),
        _bridgeGetTableAny(['dim_allergene']),
        _bridgeGetTableAny(['fact_recette_occasion']),
        _bridgeGetTableAny(['dim_occasion']),
        _bridgeGetTableAny(['fact_recette_regime']),
        _bridgeGetTableAny(['dim_regime']),
        _bridgeGetTableAny(['fact_recette_type_plat']),
        _bridgeGetTableAny(['dim_type_plat']),
      ]);
      final stgRows = detailParts[0];
      final stg = stgRows.cast<Map<String, dynamic>?>().firstWhere(
            (r) => r?['recette_id'] == recetteId,
            orElse: () => null,
          );

      final enrichedRecette = Recette(
        recetteId: recette.recetteId,
        titre: recette.titre,
        photo: recette.photo,
        etapes: (recette.etapes.trim().isNotEmpty
                ? recette.etapes
                : (stg?['etapes'] ?? ''))
            .toString(),
        dureeMinute: recette.dureeMinute,
        tempsBinId: recette.tempsBinId,
      );

      final factIng = detailParts[1];
      final dimIng = detailParts[2];
      final ingById = <int, String>{
        for (final d in dimIng)
          ((d['ingredient_id'] as num?)?.toInt() ?? -1):
              (d['nom_ingredient'] ?? '').toString()
      };
      final ingredientIds = factIng
          .where((r) => r['recette_id'] == recetteId)
          .map((r) => (r['ingredient_id'] as num?)?.toInt())
          .whereType<int>()
          .toSet()
          .toList();
      final ingredients = ingredientIds
          .where((id) => ingById.containsKey(id) && ingById[id]!.isNotEmpty)
          .map((id) => Ingredient(ingredientId: id, nomIngredient: ingById[id]!))
          .toList();

      if (ingredients.isEmpty) {
        final rawIngredients = (stg?['ingredients'] ?? '').toString();
        final parsed = _splitRawListText(rawIngredients);
        for (var i = 0; i < parsed.length; i++) {
          ingredients.add(
            Ingredient(ingredientId: -(i + 1), nomIngredient: parsed[i]),
          );
        }
      }

      final factEq = detailParts[3];
      final dimEq = detailParts[4];
      final eqById = <int, String>{
        for (final d in dimEq)
          ((d['equipement_id'] as num?)?.toInt() ?? -1):
              (d['nom_equipement'] ?? '').toString()
      };
      final equipementIds = factEq
          .where((r) => r['recette_id'] == recetteId)
          .map((r) => (r['equipement_id'] as num?)?.toInt())
          .whereType<int>()
          .toSet()
          .toList();
      final equipements = equipementIds
          .where((id) => eqById.containsKey(id) && eqById[id]!.isNotEmpty)
          .map((id) => Equipement(equipementId: id, nomEquipement: eqById[id]!))
          .toList();

      if (equipements.isEmpty) {
        final rawUstensiles = (stg?['ustensiles'] ?? '').toString();
        final parsed = _splitRawListText(rawUstensiles);
        for (var i = 0; i < parsed.length; i++) {
          equipements.add(
            Equipement(equipementId: -(i + 1), nomEquipement: parsed[i]),
          );
        }
      }

      final factAll = detailParts[5];
      final dimAll = detailParts[6];
      final allergeneById = <int, String>{
        for (final d in dimAll)
          ((d['allergene_id'] as num?)?.toInt() ?? -1):
              (d['libelle'] ?? '').toString()
      };
      final allergeneIds = factAll
          .where((r) => r['recette_id'] == recetteId)
          .map((r) => (r['allergene_id'] as num?)?.toInt())
          .whereType<int>()
          .toSet()
          .toList();
      final allergenes = allergeneIds
          .where((id) =>
              allergeneById.containsKey(id) && allergeneById[id]!.isNotEmpty)
          .map((id) => Allergene(allergeneId: id, libelle: allergeneById[id]!))
          .toList();

      final factOcc = detailParts[7];
      final dimOcc = detailParts[8];
      final occasionById = <int, String>{
        for (final d in dimOcc)
          ((d['occasion_id'] as num?)?.toInt() ?? -1):
              (d['libelle'] ?? '').toString()
      };
      final occasionIds = factOcc
          .where((r) => r['recette_id'] == recetteId)
          .map((r) => (r['occasion_id'] as num?)?.toInt())
          .whereType<int>()
          .toSet()
          .toList();
      final occasions = occasionIds
          .where((id) =>
              occasionById.containsKey(id) && occasionById[id]!.isNotEmpty)
          .map((id) => Occasion(occasionId: id, libelle: occasionById[id]!))
          .toList();

      final factReg = detailParts[9];
      final dimReg = detailParts[10];
      final regimeById = <int, String>{
        for (final d in dimReg)
          ((d['regime_id'] as num?)?.toInt() ?? -1):
              (d['libelle'] ?? '').toString()
      };
      final regimeId = factReg
          .where((r) => r['recette_id'] == recetteId)
          .map((r) => (r['regime_id'] as num?)?.toInt())
          .whereType<int>()
          .cast<int?>()
          .firstWhere((_) => true, orElse: () => null);
      final regime = (regimeId != null &&
              regimeById.containsKey(regimeId) &&
              regimeById[regimeId]!.isNotEmpty)
          ? Regime(regimeId: regimeId, libelle: regimeById[regimeId]!)
          : null;

      final factType = detailParts[11];
      final dimType = detailParts[12];
      final typeById = <int, String>{
        for (final d in dimType)
          ((d['type_plat_id'] as num?)?.toInt() ?? -1):
              (d['libelle'] ?? '').toString()
      };
      final typePlatId = factType
          .where((r) => r['recette_id'] == recetteId)
          .map((r) => (r['type_plat_id'] as num?)?.toInt())
          .whereType<int>()
          .cast<int?>()
          .firstWhere((_) => true, orElse: () => null);
      final typePlat = (typePlatId != null &&
              typeById.containsKey(typePlatId) &&
              typeById[typePlatId]!.isNotEmpty)
          ? TypePlat(typePlatId: typePlatId, libelle: typeById[typePlatId]!)
          : null;

      final complete = RecetteComplete(
        recette: enrichedRecette,
        ingredients: ingredients,
        equipements: equipements,
        allergenes: allergenes,
        occasions: occasions,
        regime: regime,
        typePlat: typePlat,
      );
      _bridgeRecetteCompleteCache[recetteId] = complete;
      _bridgeRecetteCompleteCacheAt[recetteId] = DateTime.now();
      return complete;
    } catch (error, stack) {
      _logIgnored('getRecetteComplete', error, stack);
    }
    try {
      final res = await _bridgeGet('/v1/recettes/$recetteId/complete');
      final complete =
          _recetteCompleteFromBridgeMap(res as Map<String, dynamic>);
      _bridgeRecetteCompleteCache[recetteId] = complete;
      _bridgeRecetteCompleteCacheAt[recetteId] = DateTime.now();
      return complete;
    } catch (error, stack) {
      _logIgnored('getRecetteComplete', error, stack);
    }
    return null;
  }

  // ============================================================================
  // FAVORIS
  // ============================================================================

  Future<bool> isFavorite(String recetteId) async {
    if (_currentUser == null) return false;
    await _ensureLocalBridgeStateLoaded();
    if (_localFavoriteIds.contains(recetteId)) return true;
    try {
      final rows = await _bridgeGetFavoritesRows();
      return rows.any(
        (r) => '${r['recette_id'] ?? r['recipe_id'] ?? ''}' == recetteId,
      );
    } catch (error, stack) {
      _logIgnored('isFavorite', error, stack);
      return FavoritesService().isFavorite(recetteId);
    }
  }

  Future<bool> addToFavorites(String recetteId) async {
    if (_currentUser == null) return false;
    await _ensureLocalBridgeStateLoaded();
    _localFavoriteIds.add(recetteId);
    await _saveLocalBridgeState();
    try {
      await _bridgePost('/favorites', _stripNulls({
        'action': 'add',
        'user_id': _currentUser!.userId,
        'email': _currentUser!.email,
        'recette_id': recetteId,
      }));
      return true;
    } catch (error, stack) {
      _logIgnored('addToFavorites', error, stack);
      try {
        await _bridgePost('/favorites', _stripNulls({
          'user_id': _currentUser!.userId,
          'recette_id': recetteId,
        }));
        return true;
      } catch (error, stack) {
        _logIgnored('addToFavorites', error, stack);
        return true;
      }
    }
  }

  Future<bool> removeFromFavorites(String recetteId) async {
    if (_currentUser == null) return false;
    await _ensureLocalBridgeStateLoaded();
    _localFavoriteIds.remove(recetteId);
    await _saveLocalBridgeState();
    try {
      await _bridgePost('/favorites', _stripNulls({
        'action': 'remove',
        'user_id': _currentUser!.userId,
        'email': _currentUser!.email,
        'recette_id': recetteId,
      }));
      return true;
    } catch (error, stack) {
      _logIgnored('removeFromFavorites', error, stack);
      return true;
    }
  }

  Future<bool> toggleFavorite(String recetteId) async {
    final isFav = await isFavorite(recetteId);
    if (isFav) {
      return await removeFromFavorites(recetteId);
    } else {
      return await addToFavorites(recetteId);
    }
  }

  Future<List<Recette>> getFavorites() async {
    if (_currentUser == null) return [];
    await _ensureLocalBridgeStateLoaded();
    try {
      final rows = await _bridgeGetFavoritesRows();
      final ids = rows
          .map((r) => '${r['recette_id'] ?? r['recipe_id'] ?? ''}')
          .where((id) => id.isNotEmpty)
          .toSet();
      _localFavoriteIds = {..._localFavoriteIds, ...ids};
      await _saveLocalBridgeState();
      final allIds = _localFavoriteIds;
      if (allIds.isEmpty) return [];
      return await _recettesByIds(allIds);
    } catch (error, stack) {
      _logIgnored('getFavorites', error, stack);
      if (_localFavoriteIds.isEmpty) return [];
      try {
        return await _recettesByIds(_localFavoriteIds);
      } catch (error, stack) {
        _logIgnored('getFavorites', error, stack);
        return [];
      }
    }
  }

  // ============================================================================
  // DOSSIERS
  // ============================================================================

  Future<ApiResult<UserFolder>> createFolder({
    required String label,
    int colorValue = 0xFFF4A259,
  }) async {
    if (_currentUser == null) return ApiResult.error('Non connecté');
    await _ensureLocalBridgeStateLoaded();
    final localFolder = <String, dynamic>{
      'folder_id': _localNextFolderId++,
      'user_id': _currentUser!.userId ?? _currentUser!.email,
      'label': label,
      'color': colorValue,
      'recipe_count': 0,
    };
    _localFolders.add(localFolder);
    await _saveLocalBridgeState();
    if (_debugFolders) {
      debugPrint(
        '[FOLDER_DEBUG][CREATE] folderId=${localFolder['folder_id']} label="$label" user=${_currentUser?.email}',
      );
    }
    return ApiResult.success(UserFolder.fromMap(localFolder));
  }

  Future<List<UserFolder>> getFolders() async {
    if (_currentUser == null) return [];
    await _ensureLocalBridgeStateLoaded();
    final folders = _localFolders.map((f) {
      final map = Map<String, dynamic>.from(f);
      final fid = _toInt(map['folder_id'] ?? map['id']);
      map['recipe_count'] = (_localFolderRecipes[fid] ?? <String>{}).length;
      return UserFolder.fromMap(map);
    }).toList();
    if (_debugFolders) {
      debugPrint(
        '[FOLDER_DEBUG][GET_FOLDERS] count=${folders.length} values=${folders.map((e) => '${e.folderId}:${e.recipeCount}').toList()}',
      );
    }
    return folders;
  }

  Future<bool> deleteFolder(int folderId) async {
    if (_currentUser == null) return false;
    await _ensureLocalBridgeStateLoaded();
    _localFolders.removeWhere((f) => _toInt(f['folder_id']) == folderId);
    _localFolderRecipes.remove(folderId);
    await _saveLocalBridgeState();
    return true;
  }

  Future<bool> renameFolder(int folderId, String newLabel) async {
    if (_currentUser == null) return false;
    await _ensureLocalBridgeStateLoaded();
    for (final f in _localFolders) {
      if (_toInt(f['folder_id']) == folderId) {
        f['label'] = newLabel;
        break;
      }
    }
    await _saveLocalBridgeState();
    return true;
  }

  Future<bool> updateFolder(
    int folderId, {
    String? newLabel,
    int? colorValue,
  }) async {
    if (_currentUser == null) return false;
    if (newLabel == null && colorValue == null) return true;

    await _ensureLocalBridgeStateLoaded();
    for (final f in _localFolders) {
      if (_toInt(f['folder_id']) == folderId) {
        if (newLabel != null) f['label'] = newLabel;
        if (colorValue != null) f['color'] = colorValue;
        break;
      }
    }
    await _saveLocalBridgeState();
    return true;
  }

  Future<bool> addRecipeToFolder(int folderId, String recetteId) async {
    if (_currentUser == null) return false;
    await _ensureLocalBridgeStateLoaded();
    final folderExists =
        _localFolders.any((f) => _toInt(f['folder_id']) == folderId);
    if (!folderExists) {
      if (_debugFolders) {
        debugPrint(
          '[FOLDER_DEBUG][ADD] folderId=$folderId not found. existingFolders=$_localFolders',
        );
      }
      return false;
    }
    (_localFolderRecipes[folderId] ??= <String>{}).add(recetteId);
    await _saveLocalBridgeState();
    if (_debugFolders) {
      debugPrint(
        '[FOLDER_DEBUG][ADD] folderId=$folderId recetteId=$recetteId links=${_localFolderRecipes[folderId]}',
      );
    }
    return true;
  }

  Future<bool> removeRecipeFromFolder(int folderId, String recetteId) async {
    if (_currentUser == null) return false;
    await _ensureLocalBridgeStateLoaded();
    _localFolderRecipes[folderId]?.remove(recetteId);
    await _saveLocalBridgeState();
    if (_debugFolders) {
      debugPrint(
        '[FOLDER_DEBUG][REMOVE] folderId=$folderId recetteId=$recetteId links=${_localFolderRecipes[folderId]}',
      );
    }
    return true;
  }

  Future<List<Recette>> getRecipesInFolder(int folderId) async {
    if (_currentUser == null) return [];
    await _ensureLocalBridgeStateLoaded();
    final localIds = _localFolderRecipes[folderId] ?? <String>{};
    if (_debugFolders) {
      debugPrint(
        '[FOLDER_DEBUG][GET_RECIPES] folderId=$folderId localIds=$localIds',
      );
    }
    if (localIds.isEmpty) return [];
    try {
      return await _recettesByIds(localIds);
    } catch (error, stack) {
      _logIgnored('getRecipesInFolder', error, stack);
      if (_debugFolders) {
        debugPrint('[FOLDER_DEBUG][GET_RECIPES] bridge base fetch failed');
      }
      return [];
    }
  }
  Future<List<Map<String, dynamic>>> _bridgeGetFavoritesRows() async {
    if (_bridgeFavoritesEndpointAvailable == false) return [];
    final q = <String, String>{
      if (_currentUser?.userId != null && _currentUser!.userId!.isNotEmpty)
        'user_id': _currentUser!.userId!
      else
        'email': _currentUser?.email ?? '',
    };
    try {
      final res = await _bridgeGet('/favorites', query: q);
      _bridgeFavoritesEndpointAvailable = true;
      if (res is List) {
        return res
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
      }
    } catch (e) {
      if (_isHttpBadRequestError(e)) {
        _bridgeFavoritesEndpointAvailable = false;
      }
    }
    return [];
  }

  Future<List<UserPreference>> getUserPreferences() async {
    var regime = '';
    var allergies = '';
    var intolerances = '';
    try {
      final email = _currentUser?.email.toLowerCase().trim();
      Map<String, dynamic>? row;
      if (usesAuthService) {
        row = await _authPreferencesRow();
      } else if (email != null && email.isNotEmpty) {
        final rows = await _bridgeGetTableAny(['dim_utilisateur']);
        row = rows.cast<Map<String, dynamic>?>().firstWhere(
              (r) =>
                  r != null &&
                  (r['email'] ?? '').toString().toLowerCase().trim() ==
                      email,
              orElse: () => null,
            );
      }
      if (row != null) {
        String readFirstNonEmpty(List<String> keys) {
          for (final k in keys) {
            final v = (row![k] ?? '').toString().trim();
            if (v.isNotEmpty) return v;
          }
          return '';
        }

        regime = readFirstNonEmpty(['regime_alimentaire', 'regime', 'diet']);
        allergies = readFirstNonEmpty(['allergies', 'allergenes']);
        intolerances = readFirstNonEmpty(['intolerances', 'intolerance']);
      }
    } catch (error, stack) {
      _logIgnored('getUserPreferences', error, stack);
    }

    // Préférences modifiées dans le profil : prioritaires sur la base, qui
    // n'expose pas encore de route de mise à jour.
    final local = await _readLocalPreferences();
    if (local != null) {
      regime = local.regime ?? '';
      allergies = local.allergies.join(',');
    }

    return [
      if (regime.isNotEmpty) UserPreference(label: 'Régime', value: regime),
      if (intolerances.isNotEmpty)
        UserPreference(label: 'Intolérances', value: intolerances),
      if (allergies.isNotEmpty)
        UserPreference(label: 'Allergènes', value: allergies),
    ];
  }

  /// Enregistre le régime et les allergies (codes des options d'inscription,
  /// ex. `vegetarian`, `gluten`) pour l'utilisateur connecté : sur l'appareil,
  /// et sur le serveur avec le service d'authentification (/me/state).
  Future<bool> saveUserPreferences({
    required String? regime,
    required Set<String> allergies,
  }) async {
    if (_currentUser == null || !_useGcpBridge) return false;
    try {
      await _storage.write(
        key: _storageKey('preferences'),
        value: jsonEncode({
          'regime': regime,
          'allergies': (allergies.toList()..sort()),
        }),
      );
      await _pushServerState();
      return true;
    } catch (error, stack) {
      _logIgnored('saveUserPreferences', error, stack);
      return false;
    }
  }

  /// Nom et prénom modifiés dans le profil (mode bridge), prioritaires sur
  /// ceux de la base à la connexion.
  Future<void> _applyLocalIdentity() async {
    final user = _currentUser;
    if (user == null) return;
    try {
      final raw = await _storage.read(key: _storageKey('identity'));
      if (raw == null || raw.trim().isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      _currentUser = app_models.User(
        userId: user.userId,
        email: user.email,
        nom: decoded['nom']?.toString() ?? user.nom,
        prenom: decoded['prenom']?.toString() ?? user.prenom,
        photoUrl: user.photoUrl,
      );
    } catch (error, stack) {
      _logIgnored('_applyLocalIdentity', error, stack);
    }
  }

  Future<({String? regime, List<String> allergies})?>
      _readLocalPreferences() async {
    if (_currentUser == null) return null;
    try {
      final raw = await _storage.read(key: _storageKey('preferences'));
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final regime = decoded['regime']?.toString();
      final allergies = decoded['allergies'];
      return (
        regime: (regime == null || regime.isEmpty) ? null : regime,
        allergies:
            allergies is List ? allergies.map((e) => '$e').toList() : <String>[],
      );
    } catch (error, stack) {
      _logIgnored('_readLocalPreferences', error, stack);
      return null;
    }
  }

  // ============================================================================
  // PROFIL DE GOÛTS (swipe)
  // ============================================================================
  //
  // Source de vérité : les swipes bruts, table `fact_user_swipe` (voir
  // database/taste_swipes.sql). L'appareil garde une copie (hors ligne,
  // inscription avant connexion) ; l'envoi au serveur est retenté tant
  // qu'il n'a pas réussi (`TasteProfile.needsSync`).
  //
  // Contrat du bridge :
  //   POST /swipes  {user_id, email, source, votes: [{recette_id, verdict,
  //                  poids, voted_at}]}  → 2xx
  //   GET  /v1/users/{user_id}/swipes    → [{recette_id, verdict, voted_at}]
  //   (repli : GET /?table=fact_user_swipe, filtré ici par utilisateur)

  static const String _swipeTable = 'fact_user_swipe';

  /// Clé de stockage local par email : l'inscription enregistre le profil
  /// avant la première connexion.
  String? _tasteStorageKey(String? email) {
    final normalized = (email ?? _currentUser?.email ?? '').toLowerCase().trim();
    if (normalized.isEmpty) return null;
    return 'taste_profile_$normalized';
  }

  Future<TasteProfile?> _readLocalTaste(String key) async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return TasteProfile.fromJson(Map<String, dynamic>.from(decoded));
    } catch (error, stack) {
      _logIgnored('getTasteProfile', error, stack);
      return null;
    }
  }

  Future<bool> _writeLocalTaste(String key, TasteProfile profile) async {
    try {
      await _storage.write(key: key, value: jsonEncode(profile.toJson()));
      return true;
    } catch (error, stack) {
      _logIgnored('saveTasteProfile', error, stack);
      return false;
    }
  }

  /// Swipes de l'utilisateur côté serveur ; `null` si le serveur est
  /// injoignable (on garde alors la copie locale).
  Future<List<SwipeVote>?> _fetchRemoteSwipes(app_models.User user) async {
    if (!_useGcpBridge) return null;
    List rows;
    try {
      final res = await _bridgeGet('/v1/users/${user.userId}/swipes');
      rows = res is List ? res : const [];
    } catch (error, stack) {
      _logIgnored('_fetchRemoteSwipes', error, stack, expected: true);
      try {
        final email = user.email.toLowerCase().trim();
        rows = (await _bridgeGetTable(_swipeTable))
            .where((r) =>
                '${r['user_id'] ?? ''}' == '${user.userId}' ||
                '${r['email'] ?? ''}'.toLowerCase().trim() == email)
            .toList();
      } catch (error, stack) {
        _logIgnored('_fetchRemoteSwipes', error, stack);
        return null;
      }
    }
    return rows
        .whereType<Map>()
        .map((m) => SwipeVote.fromJson(Map<String, dynamic>.from(m)))
        .whereType<SwipeVote>()
        .toList();
  }

  /// Envoie les swipes au serveur. Vrai si le serveur les a acceptés.
  Future<bool> _pushSwipes(
    List<SwipeVote> votes, {
    required String userId,
    required String email,
    String source = 'swipe',
  }) async {
    if (!_useGcpBridge || votes.isEmpty) return false;
    try {
      await _bridgePost('/swipes', _stripNulls({
        'user_id': userId,
        'email': email.toLowerCase().trim(),
        'source': source,
        'votes': votes.map((v) => v.toJson()).toList(),
      }));
      _bridgeTableCache.remove(_swipeTable);
      return true;
    } catch (error, stack) {
      _logIgnored('_pushSwipes', error, stack);
      return false;
    }
  }

  /// Profil de goûts de l'utilisateur connecté (`null` s'il n'a pas swipé).
  /// Fusionne la copie locale et les swipes du serveur, et renvoie au
  /// serveur ce qui n'y est pas encore.
  Future<TasteProfile?> getTasteProfile() async {
    final key = _tasteStorageKey(null);
    if (key == null) return null;
    var profile = await _readLocalTaste(key);
    final user = _currentUser;
    if (user == null || user.userId == null) return profile;

    final remote = await _fetchRemoteSwipes(user);
    if (remote != null && remote.isNotEmpty) {
      final local = profile ?? const TasteProfile();
      final merged = mergeVotes(remote, local.votes);
      // Synchronisé si le serveur a déjà tout ce que l'appareil connaît.
      final serverHasAll = local.votes.every((v) => remote.any((r) =>
          r.recipeId == v.recipeId && r.verdict == v.verdict));
      profile = local.copyWith(
        votes: merged,
        syncedAt: serverHasAll ? (local.syncedAt ?? DateTime.now()) : null,
        clearSyncedAt: !serverHasAll,
      );
    }

    if (profile != null && profile.needsSync) {
      final ok = await _pushSwipes(profile.votes,
          userId: user.userId!, email: user.email);
      if (ok) profile = profile.copyWith(syncedAt: DateTime.now());
    }
    if (profile != null) await _writeLocalTaste(key, profile);
    return profile;
  }

  /// Enregistre le profil : sur l'appareil, puis ses swipes sur le serveur
  /// si l'utilisateur est connu. `email` / `userId` servent à l'inscription,
  /// avant la première connexion. Renvoie le profil tel qu'enregistré
  /// (`syncedAt` renseigné si le serveur a accepté).
  Future<TasteProfile> saveTasteProfile(
    TasteProfile profile, {
    String? email,
    String? userId,
    String source = 'swipe',
  }) async {
    final key = _tasteStorageKey(email);
    final mail = (email ?? _currentUser?.email ?? '').trim();
    final uid = userId ?? _currentUser?.userId;
    var saved = profile;
    if (saved.needsSync && uid != null && mail.isNotEmpty) {
      final ok =
          await _pushSwipes(saved.votes, userId: uid, email: mail, source: source);
      if (ok) saved = saved.copyWith(syncedAt: DateTime.now());
    }
    if (key != null) await _writeLocalTaste(key, saved);
    return saved;
  }

  // ============================================================================
  // QUIZ
  // ============================================================================

  Future<List<Quiz>> getAllQuizzes() async {
    return [];
  }

  Future<Quiz?> getQuizById(int quizId) async {
    return null;
  }

  Future<List<QuizQuestion>> getQuizQuestions(int quizId) async {
    return [];
  }

  Future<bool> saveQuizScore(int quizId, int score, int totalQuestions) async {
    return false;
  }

  Future<List<QuizScore>> getUserQuizScores() async {
    return [];
  }

  Future<QuizScore?> getBestQuizScore(int quizId) async {
    return null;
  }

  // ============================================================================
  // DONNÉES DE RÉFÉRENCE
  // ============================================================================

  Future<List<Allergene>> getAllAllergenes() async {
    return [];
  }

  Future<List<Ingredient>> getAllIngredients() async {
    // Avec le catalogue, les noms y sont déjà (même colonne nom_ingredient) :
    // inutile de télécharger dim_ingredients (~120 Ko) pour les filtres.
    final catalog = await _catalogPreviews();
    if (catalog != null) {
      final names = <String>{
        for (final r in catalog) ...r.ingredients.where((n) => n.trim().isNotEmpty)
      }.toList()
        ..sort();
      return [
        for (var i = 0; i < names.length; i++)
          Ingredient(ingredientId: i + 1, nomIngredient: names[i]),
      ];
    }
    try {
      final rows = await _bridgeGetTableAny(
        ['dim_ingredients', 'dim_ingredient'],
      );
      return rows.map((m) => Ingredient.fromMap(m)).toList();
    } catch (error, stack) {
      _logIgnored('getAllIngredients', error, stack);
      return [];
    }
  }

  Future<bool> isPseudoAvailable(String pseudo) async {
    final normalized = pseudo.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    if (usesAuthService) {
      return _authAvailable('/auth/pseudo-available', 'pseudo', normalized);
    }

    try {
      final rows = await _bridgeGetTableAny(['dim_utilisateur']);
      final exists = rows.any((row) {
        final value = (row['pseudo'] ?? '').toString().trim().toLowerCase();
        return value.isNotEmpty && value == normalized;
      });
      return !exists;
    } catch (error, stack) {
      _logIgnored('isPseudoAvailable', error, stack);
      // En cas d'erreur backend, on reste permissif pour ne pas bloquer l'UX.
      return true;
    }
  }

  Future<bool> isEmailAvailable(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    if (usesAuthService) {
      return _authAvailable('/auth/email-available', 'email', normalized);
    }

    try {
      final rows = await _bridgeGetTableAny(['dim_utilisateur']);
      final exists = rows.any((row) {
        final value = (row['email'] ?? '').toString().trim().toLowerCase();
        return value.isNotEmpty && value == normalized;
      });
      return !exists;
    } catch (error, stack) {
      _logIgnored('isEmailAvailable', error, stack);
      return true;
    }
  }

  Future<List<Regime>> getAllRegimes() async {
    return [];
  }

  Future<List<TypePlat>> getAllTypesPlat() async {
    return [];
  }

  Future<List<Occasion>> getAllOccasions() async {
    return [];
  }

  Future<List<Equipement>> getAllEquipements() async {
    return [];
  }

  Future<List<TempsBin>> getAllTempsBins() async {
    return [];
  }

}

/// Classe représentant le résultat d'une opération API
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResult._({this.data, this.error, required this.isSuccess});

  factory ApiResult.success(T data) => ApiResult._(data: data, isSuccess: true);
  factory ApiResult.error(String error) =>
      ApiResult._(error: error, isSuccess: false);
}

/// Jeton JWT lisible et non expiré (la signature est vérifiée par le serveur).
@visibleForTesting
bool isSessionTokenValid(String token, {DateTime? now}) {
  final parts = token.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
    final exp = payload is Map ? payload['exp'] : null;
    if (exp is! num) return false;
    final expiry =
        DateTime.fromMillisecondsSinceEpoch((exp * 1000).toInt(), isUtc: true);
    return expiry.isAfter(now ?? DateTime.now().toUtc());
  } catch (_) {
    return false;
  }
}
