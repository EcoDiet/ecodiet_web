import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'favorites_service.dart';
import '../models/recette.dart';
import '../models/user.dart' as app_models;
import '../models/user.dart' hide User;

const String kMarmitonImageBaseUrl = 'https://assets.afcdn.com/recipe/';
const String kGcpImageBaseUrl =
    'https://storage.googleapis.com/gcs_dataiku/dataiku/staging/node_7e227912/ECODIETYNOV/0RUJIdkr/';
bool kDisableNetworkImages = false;

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

  /// Résolu paresseusement : permet d'instancier EcoDietApi (ex. en test)
  /// sans exiger que Supabase soit déjà initialisé.
  SupabaseClient get _supabase {
    if (_useGcpBridge) {
      throw StateError('Supabase desactive en mode gcp_bridge');
    }
    return Supabase.instance.client;
  }
  
  // Session utilisateur courante
  app_models.User? _currentUser;
  bool _useGcpBridge = false;
  String _gcpBridgeBaseUrl = '';
  String? _gcpBridgeApiKey;
  List<Map<String, dynamic>>? _bridgeRecettesCache;
  DateTime? _bridgeRecettesCacheAt;
  static const Duration _bridgeDataCacheTtl = Duration(minutes: 5);
  final Map<String, List<Map<String, dynamic>>> _bridgeTableCache = {};
  final Map<String, DateTime> _bridgeTableCacheAt = {};
  final Map<String, RecetteComplete> _bridgeRecetteCompleteCache = {};
  final Map<String, DateTime> _bridgeRecetteCompleteCacheAt = {};
  bool? _bridgeFavoritesEndpointAvailable = false;
  bool? _bridgeFoldersEndpointAvailable = false;
  bool? _bridgeFolderRecetteEndpointAvailable = false;
  static const bool _debugFolders = true;
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

  void configureDataBridge({
    required bool enabled,
    required String baseUrl,
    String? apiKey,
  }) {
    _useGcpBridge = enabled && baseUrl.trim().isNotEmpty;
    _gcpBridgeBaseUrl = baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    _gcpBridgeApiKey = apiKey?.trim().isEmpty ?? true ? null : apiKey?.trim();
    _clearBridgeDataCaches();
  }

  void _clearBridgeDataCaches() {
    _bridgeRecettesCache = null;
    _bridgeRecettesCacheAt = null;
    _bridgeTableCache.clear();
    _bridgeTableCacheAt.clear();
    _bridgeRecetteCompleteCache.clear();
    _bridgeRecetteCompleteCacheAt.clear();
    _bridgeFavoritesEndpointAvailable = false;
    _bridgeFoldersEndpointAvailable = false;
    _bridgeFolderRecetteEndpointAvailable = false;
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
        }),
      );
      await _touchBridgeSessionActivity();
    } catch (_) {}
  }

  Future<void> _touchBridgeSessionActivity() async {
    try {
      await _storage.write(
        key: _bridgeSessionLastActivityKey,
        value: DateTime.now().toUtc().toIso8601String(),
      );
    } catch (_) {}
  }

  Future<void> _clearBridgeSession() async {
    try {
      await _storage.delete(key: _bridgeSessionUserKey);
      await _storage.delete(key: _bridgeSessionLastActivityKey);
    } catch (_) {}
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

      _currentUser = app_models.User(
        userId: map['user_id']?.toString(),
        email: email,
        nom: map['nom']?.toString(),
        prenom: map['prenom']?.toString(),
        passwordHash: null,
      );
      await _touchBridgeSessionActivity();
      _resetLocalBridgeStateCache();
      return true;
    } catch (_) {
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
    } catch (_) {
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
      if (_debugFolders) {
        debugPrint(
          '[FOLDER_DEBUG][SAVE] folders=${_localFolders.length} links=${serializable.length} data=$serializable',
        );
      }
    } catch (_) {}
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
    } catch (_) {
      // Some bridge implementations return concatenated JSON objects
      // without an outer array. Try lenient decoding.
      if (!trimmed.startsWith('[') && trimmed.contains('},{')) {
        try {
          return jsonDecode('[$trimmed]');
        } catch (_) {}
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
        } catch (_) {}
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
      } catch (_) {}
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

  String _friendlyError(Object error, String action) {
    final message = error.toString();
    if (message.contains('Failed to fetch') ||
        message.contains('ClientException')) {
      return '$action: impossible de joindre Supabase. Verifiez SUPABASE_URL, SUPABASE_ANON_KEY, la connexion internet et que le projet Supabase existe toujours.';
    }
    if (message.contains('Invalid login credentials')) {
      return '$action: email ou mot de passe incorrect.';
    }
    if (message.contains('User already registered')) {
      return '$action: cet email est deja inscrit.';
    }
    return '$action: $error';
  }

  /// Obtient l'utilisateur actuellement connecté
  app_models.User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  Future<bool> restoreSession() async {
    if (_useGcpBridge) {
      return _restoreBridgeSession();
    }

    final authUser = _supabase.auth.currentUser;
    if (authUser == null) {
      _currentUser = null;
      _resetLocalBridgeStateCache();
      return false;
    }

    _currentUser = await _buildCurrentUser(authUser);
    _resetLocalBridgeStateCache();
    await syncLocalFavorites();
    await _ensureDefaultFolder();
    return true;
  }

  Future<app_models.User> _buildCurrentUser(User authUser) async {
    final metadata = authUser.userMetadata ?? {};
    String? nom = metadata['nom'] as String?;
    String? prenom = metadata['prenom'] as String?;

    try {
      final userData = await _supabase
          .from('utilisateurs')
          .select()
          .eq('user_id', authUser.id)
          .maybeSingle();
      if (userData != null) {
        nom = userData['nom'] as String? ?? nom;
        prenom = userData['prenom'] as String? ?? prenom;
      }
    } catch (_) {
      // Table profil absente/inaccessible: les metadata Auth suffisent.
    }

    return app_models.User(
      userId: authUser.id,
      email: authUser.email ?? '',
      nom: nom,
      prenom: prenom,
      passwordHash: null,
    );
  }

  Future<void> _ensureUserProfile({
    required User authUser,
    String? nom,
    String? prenom,
  }) async {
    try {
      final existing = await _supabase
          .from('utilisateurs')
          .select('user_id')
          .eq('user_id', authUser.id)
          .maybeSingle();
      if (existing == null) {
        await _supabase.from('utilisateurs').insert({
          'user_id': authUser.id,
          'email': (authUser.email ?? '').toLowerCase(),
          'nom': nom,
          'prenom': prenom,
        });
      }
    } catch (_) {
      // Ne bloque pas l'auth si la table profil/RLS n'est pas encore prete.
    }
  }

  Future<void> _ensureDefaultFolder() async {
    if (_currentUser == null) return;

    try {
      final existing = await _supabase
          .from('user_folder')
          .select('folder_id')
          .eq('user_id', _currentUser!.userId!)
          .eq('label', 'Favoris')
          .maybeSingle();
      if (existing == null) {
        await createFolder(label: 'Favoris', colorValue: 0xFFE53935);
      }
    } catch (_) {
      // Les dossiers ne sont pas critiques pour laisser entrer l'utilisateur.
    }
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
    if (_useGcpBridge) {
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
          'Nom, prenom, pseudo, email et mot de passe sont requis.',
        );
      }
      final emailAvailable = await isEmailAvailable(normalizedEmail);
      if (!emailAvailable) {
        return ApiResult.error('Cet email est deja inscrit.');
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
          'Inscription en base impossible via Cloud Run: $e',
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

    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'nom': nom ?? '', 'prenom': prenom ?? ''},
      );

      if (res.user != null) {
        if (res.session == null) {
          return ApiResult.error(
            'Compte cree. Verifiez votre email pour confirmer le compte, ou desactivez la confirmation email dans Supabase pour la demo.',
          );
        }
        await _ensureUserProfile(authUser: res.user!, nom: nom, prenom: prenom);
        // Essaie d'insérer dans utilisateurs, mais ne bloque pas si RLS l'interdit
        try {
          final existing = await _supabase
              .from('utilisateurs')
              .select()
              .eq('email', email.toLowerCase())
              .maybeSingle();
          if (existing == null) {
            await _supabase.from('utilisateurs').insert({
              'email': email.toLowerCase(),
              'nom': nom,
              'prenom': prenom,
            });
          }
        } catch (_) {
          // RLS ou table inaccessible — l'auth Supabase suffit
        }

        final user = app_models.User(
          userId: res.user!.id,
          email: res.user!.email ?? email.toLowerCase(),
          nom: nom,
          prenom: prenom,
          passwordHash: null,
        );

        _currentUser = user;
        _resetLocalBridgeStateCache();

        // Creer le dossier Favoris par defaut
        await createFolder(label: 'Favoris', colorValue: 0xFFE53935);

        await syncLocalFavorites();
        return ApiResult.success(user);
      }
      return ApiResult.error('Erreur lors de l\'inscription');
    } catch (e) {
      return ApiResult.error(
          _friendlyError(e, 'Erreur lors de l\'inscription'));
    }
  }

  /// Connexion d'un utilisateur
  Future<ApiResult<app_models.User>> login({
    required String email,
    required String password,
  }) async {
    if (_useGcpBridge) {
      final normalizedEmail = email.toLowerCase().trim();
      final rawPassword = password.trim();
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
            'Erreur lors de la connexion: identifiants invalides.',
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
        await _saveBridgeSession(user);
        _resetLocalBridgeStateCache();
        return ApiResult.success(user);
      } catch (e) {
        return ApiResult.error(
          'Erreur lors de la connexion bridge: $e',
        );
      }
    }

    try {
      final res = await _supabase.auth.signInWithPassword(
        email: email.toLowerCase(),
        password: password,
      );

      if (res.user != null) {
        final metadata = res.user!.userMetadata ?? {};
        // Essaie de lire la table utilisateurs, mais ne bloque pas si RLS l'interdit
        String? nom = metadata['nom'] as String?;
        String? prenom = metadata['prenom'] as String?;
        try {
          final userData = await _supabase
              .from('utilisateurs')
              .select()
              .eq('email', email.toLowerCase())
              .limit(1)
              .maybeSingle();
          if (userData != null) {
            nom = userData['nom'] ?? nom;
            prenom = userData['prenom'] ?? prenom;
          }
        } catch (_) {
          // RLS ou table inaccessible — on continue avec les metadata Auth
        }

        final user = app_models.User(
          userId: res.user!.id,
          email: res.user!.email ?? email.toLowerCase(),
          nom: nom,
          prenom: prenom,
          passwordHash: null,
        );
        _currentUser = user;
        _resetLocalBridgeStateCache();
        await syncLocalFavorites();
        await _ensureDefaultFolder();
        return ApiResult.success(user);
      }
      return ApiResult.error('Email ou mot de passe incorrect');
    } catch (e) {
      return ApiResult.error(_friendlyError(e, 'Erreur lors de la connexion'));
    }
  }

  /// Déconnexion
  Future<void> logout() async {
    if (_useGcpBridge) {
      _currentUser = null;
      await _clearBridgeSession();
      FavoritesService().clear();
      _resetLocalBridgeStateCache();
      return;
    }
    _currentUser = null;
    _resetLocalBridgeStateCache();
    await _supabase.auth.signOut();
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

    try {
      final updates = <String, dynamic>{};
      if (nom != null) updates['nom'] = nom;
      if (prenom != null) updates['prenom'] = prenom;

      if (updates.isNotEmpty) {
        await _supabase
            .from('utilisateurs')
            .update(updates)
            .eq('email', _currentUser!.email);
      }

      _currentUser = app_models.User(
        userId: _currentUser!.userId,
        email: _currentUser!.email,
        nom: nom ?? _currentUser!.nom,
        prenom: prenom ?? _currentUser!.prenom,
        photoUrl: photoUrl ?? _currentUser!.photoUrl,
      );

      return ApiResult.success(_currentUser!);
    } catch (e) {
      return ApiResult.error('Erreur lors de la mise à jour: $e');
    }
  }

  // ============================================================================
  // RECETTES
  // ============================================================================

  Future<List<Recette>> getAllRecettes() async {
    if (_useGcpBridge) {
      try {
        final res = await _bridgeGet('/v1/recettes');
        return (res as List).map((m) => Recette.fromMap(m)).toList();
      } catch (_) {}
      try {
        final rows = await _bridgeGetRecettesFromRoot();
        return rows.map(Recette.fromMap).toList();
      } catch (_) {}
      throw Exception(
        'Mode gcp_bridge actif, mais impossible de recuperer les recettes depuis Cloud Run.',
      );
    }
    try {
      final res = await _supabase.from('fact_recette_base').select();
      return (res as List).map((m) => Recette.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Retourne les recettes avec leur type de plat en une seule requête
  Future<List<RecettePreview>> getRecettesPreview(
      {int limit = 20, int offset = 0}) async {
    if (_useGcpBridge) {
      try {
        final rows = await _bridgeGetRecettesFromRoot();
        if (offset >= rows.length) return [];
        final end = (offset + limit) > rows.length ? rows.length : offset + limit;
        final page = rows.sublist(offset, end);
        return await _bridgeBuildPreviewsFromBase(page);
      } catch (_) {}
      try {
        final res = await _bridgeGet(
          '/v1/recettes/preview',
          query: {'limit': '$limit', 'offset': '$offset'},
        );
        return (res as List).map((m) => RecettePreview.fromMap(m)).toList();
      } catch (_) {}
      throw Exception(
        'Mode gcp_bridge actif, mais impossible de recuperer les previews recettes depuis Cloud Run.',
      );
    }
    try {
      final res = await _supabase
          .from('fact_recette_base')
          .select(
              'recette_id, titre, photo, duree_minute, temps_bin_id, '
              'fact_recette_type_plat(dim_type_plat(libelle)), '
              'fact_ingredients_recette(dim_ingredient(nom_ingredient)), '
              'fact_recette_equipement(dim_equipement(nom_equipement)), '
              'fact_recette_regime(dim_regime(libelle)), '
              'fact_recette_allergene(dim_allergene(libelle)), '
              'fact_recette_occasion(dim_occasion(libelle))')
          .range(offset, offset + limit - 1);
      return (res as List).map((m) => RecettePreview.fromMap(m)).toList();
    } catch (e) {
      try {
        final res = await _supabase
            .from('fact_recette_base')
            .select(
                'recette_id, titre, photo, duree_minute, temps_bin_id, '
                'fact_recette_type_plat(dim_type_plat(libelle))')
            .range(offset, offset + limit - 1);
        return (res as List).map((m) => RecettePreview.fromMap(m)).toList();
      } catch (_) {
        return [];
      }
    }
  }

  Future<List<RecettePreview>> getAllRecettesPreview(
      {int pageSize = 1000}) async {
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
    if (_useGcpBridge) {
      await _ensureLocalBridgeStateLoaded();
      final ids = <String>{..._localFavoriteIds};
      try {
        final rows = await _bridgeGetFavoritesRows();
        ids.addAll(
          rows
              .map((r) => '${r['recette_id'] ?? r['recipe_id'] ?? ''}')
              .where((id) => id.isNotEmpty),
        );
      } catch (_) {}
      _localFavoriteIds = ids;
      await _saveLocalBridgeState();
      return ids;
    }
    try {
      final res = await _supabase
          .from('user_favorite')
          .select('recette_id')
          .eq('user_id', _currentUser!.userId!);
      return (res as List)
          .map<String>((r) => r['recette_id'] as String)
          .toSet();
    } catch (e) {
      return {};
    }
  }

  /// Pousse vers Supabase les favoris ajoutés hors-ligne (stockés en mémoire
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
    if (_useGcpBridge) {
      try {
        final rows = await _bridgeGetRecettesFromRoot();
        final match = rows.where((row) => row['recette_id'] == recetteId);
        if (match.isNotEmpty) return Recette.fromMap(match.first);
      } catch (_) {}
      try {
        final res = await _bridgeGet('/v1/recettes/$recetteId');
        return Recette.fromMap(res as Map<String, dynamic>);
      } catch (_) {}
    }
    try {
      final res = await _supabase
          .from('fact_recette_base')
          .select()
          .eq('recette_id', recetteId)
          .limit(1)
          .single();
      return Recette.fromMap(res);
    } catch (e) {
      return null;
    }
  }

  Future<RecetteComplete?> getRecetteComplete(String recetteId) async {
    if (_currentUser != null) {
      await _addToHistory(recetteId);
    }

    if (_useGcpBridge) {
      final cached = _bridgeRecetteCompleteCache[recetteId];
      if (cached != null &&
          _isCacheValid(_bridgeRecetteCompleteCacheAt[recetteId])) {
        return cached;
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
      } catch (_) {}
      try {
        final res = await _bridgeGet('/v1/recettes/$recetteId/complete');
        final complete =
            _recetteCompleteFromBridgeMap(res as Map<String, dynamic>);
        _bridgeRecetteCompleteCache[recetteId] = complete;
        _bridgeRecetteCompleteCacheAt[recetteId] = DateTime.now();
        return complete;
      } catch (_) {}
      return null;
    }

    try {
      // Base recette
      final rMap = await _supabase
          .from('fact_recette_base')
          .select()
          .eq('recette_id', recetteId)
          .limit(1)
          .maybeSingle();
      if (rMap == null) return null;
      final recette = Recette.fromMap(rMap);

      // Temps bin
      TempsBin? tempsBin;
      if (rMap['temps_bin_id'] != null) {
        try {
          final tMap = await _supabase
              .from('dim_temps_bin')
              .select()
              .eq('temps_bin_id', rMap['temps_bin_id'])
              .limit(1)
              .maybeSingle();
          if (tMap != null) tempsBin = TempsBin.fromMap(tMap);
        } catch (ignore) {/* ignore */}
      }

      // Allergenes
      List<Allergene> allergenes = [];
      try {
        final aRes = await _supabase
            .from('fact_recette_allergene')
            .select('dim_allergene!inner(allergene_id, libelle)')
            .eq('recette_id', recetteId);
        for (var row in aRes) {
          if (row['dim_allergene'] != null) {
            allergenes.add(Allergene.fromMap(row['dim_allergene']));
          }
        }
      } catch (ignore) {/* ignore */}

      // Equipements
      List<Equipement> equipements = [];
      try {
        final eRes = await _supabase
            .from('fact_recette_equipement')
            .select('dim_equipement!inner(equipement_id, nom_equipement)')
            .eq('recette_id', recetteId);
        for (var row in eRes) {
          if (row['dim_equipement'] != null) {
            equipements.add(Equipement.fromMap(row['dim_equipement']));
          }
        }
      } catch (ignore) {/* ignore */}

      final ingredients = await _getRecipeIngredients(recetteId);

      // Occasions
      List<Occasion> occasions = [];
      try {
        final oRes = await _supabase
            .from('fact_recette_occasion')
            .select('dim_occasion!inner(occasion_id, libelle)')
            .eq('recette_id', recetteId);
        for (var row in oRes) {
          if (row['dim_occasion'] != null) {
            occasions.add(Occasion.fromMap(row['dim_occasion']));
          }
        }
      } catch (ignore) {/* ignore */}

      // Type Plat
      TypePlat? typePlat;
      try {
        final tpRes = await _supabase
            .from('fact_recette_type_plat')
            .select('dim_type_plat!inner(type_plat_id, libelle)')
            .eq('recette_id', recetteId)
            .limit(1)
            .maybeSingle();
        if (tpRes != null && tpRes['dim_type_plat'] != null) {
          typePlat = TypePlat.fromMap(tpRes['dim_type_plat']);
        }
      } catch (ignore) {/* ignore */}

      // Regime
      Regime? regime;
      try {
        final regRes = await _supabase
            .from('fact_recette_regime')
            .select('dim_regime!inner(regime_id, libelle)')
            .eq('recette_id', recetteId)
            .limit(1)
            .maybeSingle();
        if (regRes != null && regRes['dim_regime'] != null) {
          regime = Regime.fromMap(regRes['dim_regime']);
        }
      } catch (ignore) {/* ignore */}

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
    } catch (e) {
      return null;
    }
  }

  Future<List<Ingredient>> _getRecipeIngredients(String recetteId) async {
    try {
      final rows = await _supabase
          .from('fact_ingredients_recette')
          .select('dim_ingredient!inner(ingredient_id, nom_ingredient)')
          .eq('recette_id', recetteId);
      final ingredients = _nestedObjects(rows, 'dim_ingredient')
          .map(Ingredient.fromMap)
          .toList();
      if (ingredients.isNotEmpty) return ingredients;
    } catch (_) {
      // Fallback below handles projects where PostgREST cannot infer nesting.
    }

    try {
      final linkRows = await _supabase
          .from('fact_ingredients_recette')
          .select('ingredient_id')
          .eq('recette_id', recetteId);
      final ids = (linkRows as List)
          .map((row) => row is Map ? (row['ingredient_id'] as num?)?.toInt() : null)
          .whereType<int>()
          .toSet()
          .toList();
      if (ids.isEmpty) return [];

      final ingredientRows = await _supabase
          .from('dim_ingredient')
          .select('ingredient_id, nom_ingredient')
          .inFilter('ingredient_id', ids);
      return (ingredientRows as List)
          .whereType<Map>()
          .map((row) => Ingredient.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<Map<String, dynamic>> _nestedObjects(dynamic rows, String key) {
    if (rows is! List) return const [];

    return rows
        .map((row) {
          if (row is! Map) return null;
          final value = row[key];
          if (value is Map<String, dynamic>) return value;
          if (value is Map) return Map<String, dynamic>.from(value);
          if (value is List && value.isNotEmpty) {
            final first = value.first;
            if (first is Map<String, dynamic>) return first;
            if (first is Map) return Map<String, dynamic>.from(first);
          }
          return null;
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Future<List<Recette>> searchRecettes(String query) async {
    try {
      final res = await _supabase
          .from('fact_recette_base')
          .select()
          .ilike('titre', '%$query%');
      return (res as List).map((m) => Recette.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Recette>> getRecommendedRecettes({int limit = 10}) async {
    if (_currentUser == null) {
      final all = await getAllRecettes();
      all.shuffle();
      return all.take(limit).toList();
    }

    try {
      // This is a naive implementation since complex recommendations require complex queries
      final userRegimes = await _supabase
          .from('user_regime')
          .select('regime_id')
          .eq('user_id', _currentUser!.userId!);

      final userAllergenes = await _supabase
          .from('user_allergene')
          .select('allergene_id')
          .eq('user_id', _currentUser!.userId!);
      final List<dynamic> uAllergenes = userAllergenes as List;
      final allergeneIds = uAllergenes.map((a) => a['allergene_id']).toList();

      List<Recette> recettes = [];
      if ((userRegimes as List).isNotEmpty) {
        final regimeId = userRegimes.first['regime_id'];
        final res = await _supabase
            .from('fact_recette_regime')
            .select('recette_id')
            .eq('regime_id', regimeId);
        final ids = (res as List).map((r) => r['recette_id']).toList();
        if (ids.isNotEmpty) {
          final fRes = await _supabase
              .from('fact_recette_base')
              .select()
              .inFilter('recette_id', ids);
          recettes = (fRes as List).map((m) => Recette.fromMap(m)).toList();
        }
      } else {
        recettes = await getAllRecettes();
      }

      if (allergeneIds.isNotEmpty) {
        final filtered = <Recette>[];
        for (var rec in recettes) {
          final aRes = await _supabase
              .from('fact_recette_allergene')
              .select('allergene_id')
              .eq('recette_id', rec.recetteId);
          final recA = (aRes as List).map((a) => a['allergene_id']).toList();
          bool hasAllergen = recA.any((id) => allergeneIds.contains(id));
          if (!hasAllergen) filtered.add(rec);
        }
        recettes = filtered;
      }

      recettes.shuffle();
      return recettes.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Recette>> filterRecettes({
    int? regimeId,
    int? typePlatId,
    int? occasionId,
    int? tempsBinId,
    List<int>? excludeAllergenes,
    int? maxDuration,
  }) async {
    try {
      var query = _supabase.from('fact_recette_base').select();

      if (tempsBinId != null) {
        query = query.eq('temps_bin_id', tempsBinId);
      }

      if (maxDuration != null) {
        query = query.lte('duree_minute', maxDuration);
      }

      final res = await query;
      List<Recette> recettes =
          (res as List).map((m) => Recette.fromMap(m)).toList();

      if (regimeId != null) {
        final bRes = await _supabase
            .from('fact_recette_regime')
            .select('recette_id')
            .eq('regime_id', regimeId);
        final ids = (bRes as List).map((r) => r['recette_id']).toSet();
        recettes = recettes.where((r) => ids.contains(r.recetteId)).toList();
      }

      if (typePlatId != null) {
        final bRes = await _supabase
            .from('fact_recette_type_plat')
            .select('recette_id')
            .eq('type_plat_id', typePlatId);
        final ids = (bRes as List).map((r) => r['recette_id']).toSet();
        recettes = recettes.where((r) => ids.contains(r.recetteId)).toList();
      }

      if (occasionId != null) {
        final bRes = await _supabase
            .from('fact_recette_occasion')
            .select('recette_id')
            .eq('occasion_id', occasionId);
        final ids = (bRes as List).map((r) => r['recette_id']).toSet();
        recettes = recettes.where((r) => ids.contains(r.recetteId)).toList();
      }

      if (excludeAllergenes != null && excludeAllergenes.isNotEmpty) {
        final filtered = <Recette>[];
        for (var rec in recettes) {
          final aRes = await _supabase
              .from('fact_recette_allergene')
              .select('allergene_id')
              .eq('recette_id', rec.recetteId);
          final recA = (aRes as List).map((a) => a['allergene_id']).toList();
          bool hasAllergen = recA.any((id) => excludeAllergenes.contains(id));
          if (!hasAllergen) filtered.add(rec);
        }
        recettes = filtered;
      }

      return recettes;
    } catch (e) {
      return [];
    }
  }

  // ============================================================================
  // FAVORIS
  // ============================================================================

  Future<bool> isFavorite(String recetteId) async {
    if (_currentUser == null) return false;
    if (_useGcpBridge) {
      await _ensureLocalBridgeStateLoaded();
      if (_localFavoriteIds.contains(recetteId)) return true;
      try {
        final rows = await _bridgeGetFavoritesRows();
        return rows.any(
          (r) => '${r['recette_id'] ?? r['recipe_id'] ?? ''}' == recetteId,
        );
      } catch (_) {
        return FavoritesService().isFavorite(recetteId);
      }
    }
    try {
      final res = await _supabase
          .from('user_favorite')
          .select()
          .eq('user_id', _currentUser!.userId!)
          .eq('recette_id', recetteId);
      return (res as List).isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addToFavorites(String recetteId) async {
    if (_currentUser == null) return false;
    if (_useGcpBridge) {
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
      } catch (_) {
        try {
          await _bridgePost('/favorites', _stripNulls({
            'user_id': _currentUser!.userId,
            'recette_id': recetteId,
          }));
          return true;
        } catch (_) {
          return true;
        }
      }
    }
    try {
      await _supabase.from('user_favorite').insert({
        'user_id': _currentUser!.userId!,
        'recette_id': recetteId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeFromFavorites(String recetteId) async {
    if (_currentUser == null) return false;
    if (_useGcpBridge) {
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
      } catch (_) {
        return true;
      }
    }
    try {
      await _supabase
          .from('user_favorite')
          .delete()
          .eq('user_id', _currentUser!.userId!)
          .eq('recette_id', recetteId);
      return true;
    } catch (e) {
      return false;
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
    if (_useGcpBridge) {
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
        final base = await _bridgeGetRecettesFromRoot();
        return base
            .where((r) => allIds.contains('${r['recette_id'] ?? ''}'))
            .map((r) => Recette.fromMap(r))
            .toList();
      } catch (_) {
        if (_localFavoriteIds.isEmpty) return [];
        try {
          final base = await _bridgeGetRecettesFromRoot();
          return base
              .where((r) => _localFavoriteIds.contains('${r['recette_id'] ?? ''}'))
              .map((r) => Recette.fromMap(r))
              .toList();
        } catch (_) {
          return [];
        }
      }
    }
    try {
      final res = await _supabase
          .from('user_favorite')
          .select('fact_recette_base(*)')
          .eq('user_id', _currentUser!.userId!)
          .order('added_at', ascending: false);

      List<Recette> list = [];
      for (var row in (res as List)) {
        if (row['fact_recette_base'] != null) {
          list.add(Recette.fromMap(row['fact_recette_base']));
        }
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  // ============================================================================
  // DOSSIERS
  // ============================================================================

  Future<ApiResult<UserFolder>> createFolder({
    required String label,
    int colorValue = 0xFFF4A259,
  }) async {
    if (_currentUser == null) return ApiResult.error('Non connecte');
    if (_useGcpBridge) {
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
    try {
      final res = await _supabase
          .from('user_folder')
          .insert({
            'user_id': _currentUser!.userId,
            'label': label,
            'color': colorValue,
          })
          .select()
          .single();

      return ApiResult.success(UserFolder.fromMap(res));
    } catch (e) {
      return ApiResult.error('Erreur: $e');
    }
  }

  Future<List<UserFolder>> getFolders() async {
    if (_currentUser == null) return [];
    if (_useGcpBridge) {
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
    try {
      final res = await _supabase
          .from('user_folder')
          .select()
          .eq('user_id', _currentUser!.userId!)
          .order('created_at', ascending: true);

      List<UserFolder> folders = [];
      for (var f in (res as List)) {
        final folder = UserFolder.fromMap(f);
        try {
          final countRes = await _supabase
              .from('folder_recette')
              .select('recette_id')
              .eq('folder_id', folder.folderId!)
              .count(CountOption.exact);
          folder.recipeCount = countRes.count;
        } catch (_) {}
        folders.add(folder);
      }
      return folders;
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteFolder(int folderId) async {
    if (_currentUser == null) return false;
    if (_useGcpBridge) {
      await _ensureLocalBridgeStateLoaded();
      _localFolders.removeWhere((f) => _toInt(f['folder_id']) == folderId);
      _localFolderRecipes.remove(folderId);
      await _saveLocalBridgeState();
      return true;
    }
    try {
      await _supabase
          .from('user_folder')
          .delete()
          .eq('folder_id', folderId)
          .eq('user_id', _currentUser!.userId!);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> renameFolder(int folderId, String newLabel) async {
    if (_currentUser == null) return false;
    if (_useGcpBridge) {
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
    try {
      await _supabase
          .from('user_folder')
          .update({'label': newLabel})
          .eq('folder_id', folderId)
          .eq('user_id', _currentUser!.userId!);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateFolder(
    int folderId, {
    String? newLabel,
    int? colorValue,
  }) async {
    if (_currentUser == null) return false;
    if (newLabel == null && colorValue == null) return true;

    if (_useGcpBridge) {
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

    try {
      final updates = <String, dynamic>{};
      if (newLabel != null) updates['label'] = newLabel;
      if (colorValue != null) updates['color'] = colorValue;
      await _supabase
          .from('user_folder')
          .update(updates)
          .eq('folder_id', folderId)
          .eq('user_id', _currentUser!.userId!);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addRecipeToFolder(int folderId, String recetteId) async {
    if (_currentUser == null) return false;
    if (_useGcpBridge) {
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
    try {
      await _supabase.from('folder_recette').insert({
        'folder_id': folderId,
        'recette_id': recetteId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeRecipeFromFolder(int folderId, String recetteId) async {
    if (_currentUser == null) return false;
    if (_useGcpBridge) {
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
    try {
      await _supabase
          .from('folder_recette')
          .delete()
          .eq('folder_id', folderId)
          .eq('recette_id', recetteId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Recette>> getRecipesInFolder(int folderId) async {
    if (_currentUser == null) return [];
    if (_useGcpBridge) {
      await _ensureLocalBridgeStateLoaded();
      final localIds = _localFolderRecipes[folderId] ?? <String>{};
      if (_debugFolders) {
        debugPrint(
          '[FOLDER_DEBUG][GET_RECIPES] folderId=$folderId localIds=$localIds',
        );
      }
      if (localIds.isEmpty) return [];
      try {
        final base = await _bridgeGetRecettesFromRoot();
        if (_debugFolders) {
          debugPrint(
            '[FOLDER_DEBUG][GET_RECIPES] baseCount=${base.length} for folderId=$folderId',
          );
        }
        return base
            .where((r) => localIds.contains('${r['recette_id'] ?? ''}'))
            .map((r) => Recette.fromMap(r))
            .toList();
      } catch (_) {
        if (_debugFolders) {
          debugPrint('[FOLDER_DEBUG][GET_RECIPES] bridge base fetch failed');
        }
        return [];
      }
    }
    try {
      final res = await _supabase
          .from('folder_recette')
          .select('fact_recette_base(*)')
          .eq('folder_id', folderId)
          .order('added_at', ascending: false);

      List<Recette> list = [];
      for (var row in (res as List)) {
        if (row['fact_recette_base'] != null) {
          list.add(Recette.fromMap(row['fact_recette_base']));
        }
      }
      return list;
    } catch (e) {
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

  Future<bool> setUserRegime(int regimeId) async {
    if (_currentUser == null) return false;
    try {
      await _supabase
          .from('user_regime')
          .delete()
          .eq('user_id', _currentUser!.userId!);
      await _supabase.from('user_regime').insert({
        'user_id': _currentUser!.userId!,
        'regime_id': regimeId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<Regime?> getUserRegime() async {
    if (_currentUser == null) return null;
    try {
      final res = await _supabase
          .from('user_regime')
          .select('dim_regime(*)')
          .eq('user_id', _currentUser!.userId!)
          .limit(1)
          .maybeSingle();

      if (res != null && res['dim_regime'] != null) {
        return Regime.fromMap(res['dim_regime']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> addUserAllergene(int allergeneId) async {
    if (_currentUser == null) return false;
    try {
      await _supabase.from('user_allergene').insert({
        'user_id': _currentUser!.userId!,
        'allergene_id': allergeneId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeUserAllergene(int allergeneId) async {
    if (_currentUser == null) return false;
    try {
      await _supabase
          .from('user_allergene')
          .delete()
          .eq('user_id', _currentUser!.userId!)
          .eq('allergene_id', allergeneId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Allergene>> getUserAllergenes() async {
    if (_currentUser == null) return [];
    try {
      final res = await _supabase
          .from('user_allergene')
          .select('dim_allergene(*)')
          .eq('user_id', _currentUser!.userId!);

      List<Allergene> list = [];
      for (var row in (res as List)) {
        if (row['dim_allergene'] != null) {
          list.add(Allergene.fromMap(row['dim_allergene']));
        }
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<List<UserPreference>> getUserPreferences() async {
    if (_useGcpBridge) {
      final prefs = <UserPreference>[];
      try {
        final rows = await _bridgeGetTableAny(['dim_utilisateur']);
        final email = _currentUser?.email.toLowerCase().trim();
        Map<String, dynamic>? row;
        if (email != null && email.isNotEmpty) {
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

          final regime = readFirstNonEmpty([
            'regime_alimentaire',
            'regime',
            'diet',
          ]);
          final allergies = readFirstNonEmpty([
            'allergies',
            'allergenes',
            'allergenes',
          ]);
          final intolerances = readFirstNonEmpty([
            'intolerances',
            'intolerance',
          ]);
          if (regime.isNotEmpty) {
            prefs.add(UserPreference(label: 'Régime', value: regime));
          }
          if (intolerances.isNotEmpty) {
            prefs.add(
                UserPreference(label: 'Intolérances', value: intolerances));
          }
          if (allergies.isNotEmpty) {
            prefs.add(UserPreference(label: 'Allergènes', value: allergies));
          }
        }
      } catch (_) {}
      return prefs;
    }
    final preferences = <UserPreference>[];
    final regime = await getUserRegime();
    if (regime != null) {
      preferences.add(UserPreference(label: 'Régime', value: regime.libelle));
    }
    final allergenes = await getUserAllergenes();
    if (allergenes.isNotEmpty) {
      preferences.add(UserPreference(
        label: 'Allergènes à éviter',
        value: allergenes.map((a) => a.libelle).join(', '),
      ));
    }
    return preferences;
  }

  // ============================================================================
  // HISTORIQUE
  // ============================================================================

  Future<void> _addToHistory(String recetteId) async {
    if (_currentUser == null) return;
    try {
      await _supabase.from('user_history').insert({
        'user_id': _currentUser!.userId!,
        'recette_id': recetteId,
      });
    } catch (ignore) {/* ignore */}
  }

  Future<List<Recette>> getHistory({int limit = 20}) async {
    if (_currentUser == null) return [];
    try {
      final res = await _supabase
          .from('user_history')
          .select('fact_recette_base(*)')
          .eq('user_id', _currentUser!.userId!)
          .order('viewed_at', ascending: false)
          .limit(limit);

      List<Recette> list = [];
      // To remove duplicates if any
      Set<String> seen = {};
      for (var row in (res as List)) {
        if (row['fact_recette_base'] != null) {
          final r = Recette.fromMap(row['fact_recette_base']);
          if (!seen.contains(r.recetteId)) {
            seen.add(r.recetteId);
            list.add(r);
          }
        }
      }
      return list;
    } catch (e) {
      return [];
    }
  }

  Future<bool> clearHistory() async {
    if (_currentUser == null) return false;
    try {
      await _supabase
          .from('user_history')
          .delete()
          .eq('user_id', _currentUser!.userId!);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // QUIZ
  // ============================================================================

  Future<List<Quiz>> getAllQuizzes() async {
    if (_useGcpBridge) {
      return [];
    }
    try {
      final res = await _supabase.from('quiz').select().order('quiz_id');
      return (res as List).map((m) => Quiz.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Quiz?> getQuizById(int quizId) async {
    if (_useGcpBridge) {
      return null;
    }
    try {
      final res = await _supabase
          .from('quiz')
          .select()
          .eq('quiz_id', quizId)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return Quiz.fromMap(res);
    } catch (e) {
      return null;
    }
  }

  Future<List<QuizQuestion>> getQuizQuestions(int quizId) async {
    if (_useGcpBridge) {
      return [];
    }
    try {
      final qRes = await _supabase
          .from('quiz_question')
          .select()
          .eq('quiz_id', quizId)
          .order('order_index');

      final questions = <QuizQuestion>[];
      for (final qMap in (qRes as List)) {
        final question = QuizQuestion.fromMap(qMap);
        final oRes = await _supabase
            .from('quiz_option')
            .select()
            .eq('question_id', question.questionId!)
            .order('order_index');

        question.options =
            (oRes as List).map((o) => QuizOption.fromMap(o)).toList();
        questions.add(question);
      }
      return questions;
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveQuizScore(int quizId, int score, int totalQuestions) async {
    if (_useGcpBridge) return false;
    if (_currentUser == null) return false;
    try {
      await _supabase.from('user_quiz_score').insert({
        'user_id': _currentUser!.userId!,
        'quiz_id': quizId,
        'score': score,
        'total_questions': totalQuestions,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<QuizScore>> getUserQuizScores() async {
    if (_useGcpBridge) return [];
    if (_currentUser == null) return [];
    try {
      final res = await _supabase
          .from('user_quiz_score')
          .select()
          .eq('user_id', _currentUser!.userId!)
          .order('completed_at', ascending: false);
      return (res as List).map((m) => QuizScore.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<QuizScore?> getBestQuizScore(int quizId) async {
    if (_useGcpBridge) return null;
    if (_currentUser == null) return null;
    try {
      final res = await _supabase
          .from('user_quiz_score')
          .select()
          .eq('user_id', _currentUser!.userId!)
          .eq('quiz_id', quizId)
          .order('score', ascending: false)
          .limit(1)
          .maybeSingle();
      if (res == null) return null;
      return QuizScore.fromMap(res);
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // DONNÉES DE RÉFÉRENCE
  // ============================================================================

  Future<List<Allergene>> getAllAllergenes() async {
    if (_useGcpBridge) {
      return [];
    }
    try {
      final res = await _supabase.from('dim_allergene').select();
      return (res as List).map((m) => Allergene.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Ingredient>> getAllIngredients() async {
    if (_useGcpBridge) {
      try {
        final rows = await _bridgeGetTableAny(
          ['dim_ingredients', 'dim_ingredient'],
        );
        return rows.map((m) => Ingredient.fromMap(m)).toList();
      } catch (_) {
        return [];
      }
    }
    try {
      final res = await _supabase.from('dim_ingredient').select();
      return (res as List).map((m) => Ingredient.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> isPseudoAvailable(String pseudo) async {
    final normalized = pseudo.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    if (_useGcpBridge) {
      try {
        final rows = await _bridgeGetTableAny(['dim_utilisateur']);
        final exists = rows.any((row) {
          final value = (row['pseudo'] ?? '').toString().trim().toLowerCase();
          return value.isNotEmpty && value == normalized;
        });
        return !exists;
      } catch (_) {
        // En cas d'erreur backend, on reste permissif pour ne pas bloquer l'UX.
        return true;
      }
    }

    try {
      final existing = await _supabase
          .from('utilisateurs')
          .select('email')
          .eq('pseudo', normalized)
          .limit(1)
          .maybeSingle();
      return existing == null;
    } catch (_) {
      return true;
    }
  }

  Future<bool> isEmailAvailable(String email) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    if (_useGcpBridge) {
      try {
        final rows = await _bridgeGetTableAny(['dim_utilisateur']);
        final exists = rows.any((row) {
          final value = (row['email'] ?? '').toString().trim().toLowerCase();
          return value.isNotEmpty && value == normalized;
        });
        return !exists;
      } catch (_) {
        return true;
      }
    }

    try {
      final existing = await _supabase
          .from('utilisateurs')
          .select('email')
          .eq('email', normalized)
          .limit(1)
          .maybeSingle();
      return existing == null;
    } catch (_) {
      return true;
    }
  }

  Future<List<Regime>> getAllRegimes() async {
    if (_useGcpBridge) {
      return [];
    }
    try {
      final res = await _supabase.from('dim_regime').select();
      return (res as List).map((m) => Regime.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TypePlat>> getAllTypesPlat() async {
    if (_useGcpBridge) {
      return [];
    }
    try {
      final res = await _supabase.from('dim_type_plat').select();
      return (res as List).map((m) => TypePlat.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Occasion>> getAllOccasions() async {
    if (_useGcpBridge) {
      return [];
    }
    try {
      final res = await _supabase.from('dim_occasion').select();
      return (res as List).map((m) => Occasion.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Equipement>> getAllEquipements() async {
    if (_useGcpBridge) {
      return [];
    }
    try {
      final res = await _supabase.from('dim_equipement').select();
      return (res as List).map((m) => Equipement.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<TempsBin>> getAllTempsBins() async {
    if (_useGcpBridge) {
      return [];
    }
    try {
      final res = await _supabase.from('dim_temps_bin').select();
      return (res as List).map((m) => TempsBin.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
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

