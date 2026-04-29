import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recette.dart';
import '../models/user.dart' as app_models;
import '../models/user.dart' hide User;

const String kMarmitonImageBaseUrl = 'https://assets.afcdn.com/recipe/';

/// Retourne l'URL complète d'une image recette à partir du nom de fichier stocké en BDD.
String recetteImageUrl(String photo) {
  if (photo.isEmpty) return '';
  if (photo.startsWith('http')) return photo;
  return '$kMarmitonImageBaseUrl$photo';
}

/// Service API principal pour EcoDiet
/// Centralise toutes les opérations entre le front-end et la base de données
class EcoDietApi {
  static final EcoDietApi _instance = EcoDietApi._internal();
  final SupabaseClient _supabase = Supabase.instance.client;

  // Session utilisateur courante
  app_models.User? _currentUser;

  // Test mode — no Supabase needed
  Regime?        _testRegime;
  List<Allergene> _testAllergenes = [];

  factory EcoDietApi() => _instance;
  EcoDietApi._internal();

  bool get isTestMode => _testRegime != null || _currentUser?.userId?.startsWith('test_') == true;

  /// Load a local test profile — bypasses Supabase entirely.
  void setTestProfile({
    required String prenom,
    required String regime,        // e.g. "vegan"
    required List<String> allergies, // e.g. ["lactose", "gluten"]
  }) {
    const regimeIds = {
      'carnivore': 1, 'pescetarian': 2, 'vegan': 3, 'vegetarian': 4,
    };
    const allergenIds = {
      'arachide': 1, 'celeri': 2, 'crustaces': 3, 'fruits_a_coque': 4,
      'gluten': 5,   'lactose': 6,  'mollusques': 7, 'moutarde': 8,
      'oeuf': 9,     'poisson': 10, 'sesame': 11,    'soja': 12,
      'sulfites': 13,
    };

    _testRegime = regime.isNotEmpty
        ? Regime(regimeId: regimeIds[regime] ?? 1, libelle: regime)
        : null;

    _testAllergenes = allergies
        .map((a) => Allergene(allergeneId: allergenIds[a] ?? 0, libelle: a))
        .toList();

    _currentUser = app_models.User(
      userId: 'test_${prenom.toLowerCase()}',
      email:  '${prenom.toLowerCase()}@test.local',
      prenom: prenom,
      nom:    null,
    );
  }

  void clearTestProfile() {
    _testRegime     = null;
    _testAllergenes = [];
    _currentUser    = null;
  }

  /// Obtient l'utilisateur actuellement connecté
  app_models.User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  // ============================================================================
  // AUTHENTIFICATION
  // ============================================================================

  /// Inscription d'un nouvel utilisateur
  Future<ApiResult<app_models.User>> register({
    required String email,
    required String password,
    String? nom,
    String? prenom,
  }) async {
    try {
      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'nom': nom ?? '', 'prenom': prenom ?? ''},
      );

      if (res.user != null) {
        // Auto-confirm the email using the service key so the user can log in
        // immediately without waiting for a confirmation email.
        await _adminConfirmEmail(res.user!.id);

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

        // Creer le dossier Favoris par defaut
        await createFolder(label: 'Favoris', colorValue: 0xFFE53935);

        return ApiResult.success(user);
      }
      return ApiResult.error('Erreur lors de l\'inscription');
    } catch (e) {
      return ApiResult.error('Erreur lors de l\'inscription: $e');
    }
  }

  /// Connexion d'un utilisateur
  Future<ApiResult<app_models.User>> login({
    required String email,
    required String password,
  }) async {
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
        return ApiResult.success(user);
      }
      return ApiResult.error('Email ou mot de passe incorrect');
    } catch (e) {
      return ApiResult.error('Erreur lors de la connexion: $e');
    }
  }

  /// Déconnexion
  void logout() {
    clearTestProfile();
    _currentUser = null;
    _supabase.auth.signOut();
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
        await _supabase.from('utilisateurs').update(updates).eq('email', _currentUser!.email);
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

  /// Confirms a user's email via the Supabase Admin API using the service key.
  /// This lets users log in immediately after registering, while keeping the
  /// "email confirmation required" setting active for external sign-ups.
  Future<void> _adminConfirmEmail(String userId) async {
    try {
      final serviceKey = dotenv.env['SUPABASE_SERVICE_KEY'] ?? '';
      final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
      if (serviceKey.isEmpty || supabaseUrl.isEmpty) return;

      await http.patch(
        Uri.parse('$supabaseUrl/auth/v1/admin/users/$userId'),
        headers: {
          'apikey':        serviceKey,
          'Authorization': 'Bearer $serviceKey',
          'Content-Type':  'application/json',
        },
        body: jsonEncode({'email_confirm': true}),
      );
    } catch (_) {
      // Non-blocking — worst case the user gets a confirmation email
    }
  }

  /// Saves extra profile fields (gender, height, weight, goal, etc.) into
  /// Supabase Auth user_metadata. Silently ignores errors.
  Future<void> updateUserMetadata(Map<String, dynamic> data) async {
    if (data.isEmpty) return;
    try {
      await _supabase.auth.updateUser(UserAttributes(data: data));
    } catch (_) {
      // Non-blocking — metadata is supplementary
    }
  }

  // ============================================================================
  // RECETTES
  // ============================================================================

  Future<List<Recette>> getAllRecettes() async {
    try {
      final res = await _supabase.from('fact_recette_base').select();
      return (res as List).map((m) => Recette.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Retourne les recettes avec leur type de plat en une seule requête
  Future<List<RecettePreview>> getRecettesPreview({int limit = 20, int offset = 0}) async {
    try {
      final res = await _supabase
          .from('fact_recette_base')
          .select('recette_id, titre, photo, duree_minute, temps_bin_id, fact_recette_type_plat(dim_type_plat(libelle))')
          .range(offset, offset + limit - 1);
      return (res as List).map((m) => RecettePreview.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  /// Retourne les IDs des recettes favorites de l'utilisateur courant
  Future<Set<String>> getFavoriteIds() async {
    if (_currentUser == null) return {};
    try {
      final res = await _supabase
          .from('user_favorite')
          .select('recette_id')
          .eq('user_id', _currentUser!.userId!);
      return (res as List).map<String>((r) => r['recette_id'] as String).toSet();
    } catch (e) {
      return {};
    }
  }

  Future<Recette?> getRecetteById(String recetteId) async {
    try {
      final res = await _supabase.from('fact_recette_base').select().eq('recette_id', recetteId).limit(1).single();
      return Recette.fromMap(res);
    } catch (e) {
      return null;
    }
  }

  Future<RecetteComplete?> getRecetteComplete(String recetteId) async {
    if (_currentUser != null) {
      await _addToHistory(recetteId);
    }
    
    try {
      // Base recette
      final rMap = await _supabase.from('fact_recette_base').select().eq('recette_id', recetteId).limit(1).maybeSingle();
      if (rMap == null) return null;
      final recette = Recette.fromMap(rMap);

      // Temps bin
      TempsBin? tempsBin;
      if (rMap['temps_bin_id'] != null) {
        try {
          final tMap = await _supabase.from('dim_temps_bin').select().eq('temps_bin_id', rMap['temps_bin_id']).limit(1).maybeSingle();
          if (tMap != null) tempsBin = TempsBin.fromMap(tMap);
        } catch (ignore) { /* ignore */ }
      }

      // Allergenes
      List<Allergene> allergenes = [];
      try {
        final aRes = await _supabase.from('fact_recette_allergene')
            .select('dim_allergene!inner(allergene_id, libelle)')
            .eq('recette_id', recetteId);
        for (var row in aRes) {
          if (row['dim_allergene'] != null) allergenes.add(Allergene.fromMap(row['dim_allergene']));
        }
      } catch (ignore) { /* ignore */ }

      // Equipements
      List<Equipement> equipements = [];
      try {
        final eRes = await _supabase.from('fact_recette_equipements')
            .select('dim_equipement!inner(equipement_id, nom_equipement)')
            .eq('recette_id', recetteId);
        for (var row in eRes) {
          if (row['dim_equipement'] != null) equipements.add(Equipement.fromMap(row['dim_equipement']));
        }
      } catch (ignore) { /* ignore */ }

      // Ingredients
      List<Ingredient> ingredients = [];
      try {
        final iRes = await _supabase.from('fact_ingredients_recette')
            .select('dim_ingredients!inner(ingredient_id, nom_ingredient)')
            .eq('recette_id', recetteId);
        for (var row in iRes) {
          if (row['dim_ingredients'] != null) ingredients.add(Ingredient.fromMap(row['dim_ingredients']));
        }
      } catch (ignore) { /* ignore */ }

      // Occasions
      List<Occasion> occasions = [];
      try {
        final oRes = await _supabase.from('fact_recette_occasion')
            .select('dim_occasion!inner(occasion_id, libelle)')
            .eq('recette_id', recetteId);
        for (var row in oRes) {
          if (row['dim_occasion'] != null) occasions.add(Occasion.fromMap(row['dim_occasion']));
        }
      } catch (ignore) { /* ignore */ }

      // Type Plat
      TypePlat? typePlat;
      try {
        final tpRes = await _supabase.from('fact_recette_type_plat')
            .select('dim_type_plat!inner(type_plat_id, libelle)')
            .eq('recette_id', recetteId).limit(1).maybeSingle();
        if (tpRes != null && tpRes['dim_type_plat'] != null) {
          typePlat = TypePlat.fromMap(tpRes['dim_type_plat']);
        }
      } catch (ignore) { /* ignore */ }

      // Regime
      Regime? regime;
      try {
        final regRes = await _supabase.from('fact_recette_regime')
            .select('dim_regime!inner(regime_id, libelle)')
            .eq('recette_id', recetteId).limit(1).maybeSingle();
        if (regRes != null && regRes['dim_regime'] != null) {
          regime = Regime.fromMap(regRes['dim_regime']);
        }
      } catch (ignore) { /* ignore */ }

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

  Future<List<Recette>> searchRecettes(String query) async {
    try {
      final res = await _supabase.from('fact_recette_base').select().ilike('titre', '%$query%');
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
      final userRegimes = await _supabase.from('user_regime').select('regime_id').eq('user_id', _currentUser!.userId!);
      
      final userAllergenes = await _supabase.from('user_allergene').select('allergene_id').eq('user_id', _currentUser!.userId!);
      final List<dynamic> uAllergenes = userAllergenes as List;
      final allergeneIds = uAllergenes.map((a) => a['allergene_id']).toList();

      List<Recette> recettes = [];
      if ((userRegimes as List).isNotEmpty) {
         final regimeId = userRegimes.first['regime_id'];
         final res = await _supabase.from('fact_recette_regime').select('recette_id').eq('regime_id', regimeId);
         final ids = (res as List).map((r) => r['recette_id']).toList();
         if (ids.isNotEmpty) {
            final fRes = await _supabase.from('fact_recette_base').select().inFilter('recette_id', ids);
            recettes = (fRes as List).map((m) => Recette.fromMap(m)).toList();
         }
      } else {
        recettes = await getAllRecettes();
      }

      if (allergeneIds.isNotEmpty) {
         final filtered = <Recette>[];
         for (var rec in recettes) {
            final aRes = await _supabase.from('fact_recette_allergene').select('allergene_id').eq('recette_id', rec.recetteId);
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
      List<Recette> recettes = (res as List).map((m) => Recette.fromMap(m)).toList();

      if (regimeId != null) {
        final bRes = await _supabase.from('fact_recette_regime').select('recette_id').eq('regime_id', regimeId);
         final ids = (bRes as List).map((r) => r['recette_id']).toSet();
         recettes = recettes.where((r) => ids.contains(r.recetteId)).toList();
      }

      if (typePlatId != null) {
        final bRes = await _supabase.from('fact_recette_type_plat').select('recette_id').eq('type_plat_id', typePlatId);
         final ids = (bRes as List).map((r) => r['recette_id']).toSet();
         recettes = recettes.where((r) => ids.contains(r.recetteId)).toList();
      }

      if (occasionId != null) {
        final bRes = await _supabase.from('fact_recette_occasion').select('recette_id').eq('occasion_id', occasionId);
         final ids = (bRes as List).map((r) => r['recette_id']).toSet();
         recettes = recettes.where((r) => ids.contains(r.recetteId)).toList();
      }

      if (excludeAllergenes != null && excludeAllergenes.isNotEmpty) {
        final filtered = <Recette>[];
        for (var rec in recettes) {
          final aRes = await _supabase.from('fact_recette_allergene').select('allergene_id').eq('recette_id', rec.recetteId);
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
    try {
      final res = await _supabase.from('user_favorite')
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
    try {
      await _supabase.from('user_favorite')
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
    try {
      final res = await _supabase.from('user_favorite')
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
    if (_currentUser == null) return ApiResult.error('Non connecté');
    try {
      final res = await _supabase.from('user_folder').insert({
        'user_id': _currentUser!.userId,
        'label': label,
        'color': colorValue,
      }).select().single();
      
      return ApiResult.success(UserFolder.fromMap(res));
    } catch (e) {
      return ApiResult.error('Erreur: $e');
    }
  }

  Future<List<UserFolder>> getFolders() async {
    if (_currentUser == null) return [];
    try {
      final res = await _supabase.from('user_folder')
        .select()
        .eq('user_id', _currentUser!.userId!)
        .order('created_at', ascending: true);
      
      List<UserFolder> folders = [];
      for (var f in (res as List)) {
        final folder = UserFolder.fromMap(f);
        // Get count
        try {
          final countRes = await _supabase.from('folder_recette')
            .select('recette_id')
            .eq('folder_id', folder.folderId!)
            .count(CountOption.exact);
          folder.recipeCount = countRes.count;
        } catch (_) { /* ignore */ }
        folders.add(folder);
      }
      return folders;
    } catch (e) {
      return [];
    }
  }

  Future<bool> deleteFolder(int folderId) async {
    if (_currentUser == null) return false;
    try {
      await _supabase.from('user_folder')
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
    try {
      await _supabase.from('user_folder')
        .update({'label': newLabel})
        .eq('folder_id', folderId)
        .eq('user_id', _currentUser!.userId!);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addRecipeToFolder(int folderId, String recetteId) async {
    if (_currentUser == null) return false;
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
    try {
      await _supabase.from('folder_recette')
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
    try {
      final res = await _supabase.from('folder_recette')
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

  // ============================================================================
  // PRÉFÉRENCES UTILISATEUR
  // ============================================================================

  Future<bool> setUserRegime(int regimeId) async {
    if (_currentUser == null) return false;
    try {
      await _supabase.from('user_regime').delete().eq('user_id', _currentUser!.userId!);
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
    if (isTestMode) return _testRegime;
    if (_currentUser == null) return null;
    try {
      final res = await _supabase.from('user_regime')
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
      await _supabase.from('user_allergene')
        .delete()
        .eq('user_id', _currentUser!.userId!)
        .eq('allergene_id', allergeneId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<Allergene>> getUserAllergenes() async {
    if (isTestMode) return _testAllergenes;
    if (_currentUser == null) return [];
    try {
      final res = await _supabase.from('user_allergene')
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
    } catch (ignore) { /* ignore */ }
  }

  Future<List<Recette>> getHistory({int limit = 20}) async {
    if (_currentUser == null) return [];
    try {
      final res = await _supabase.from('user_history')
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
      await _supabase.from('user_history').delete().eq('user_id', _currentUser!.userId!);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ============================================================================
  // QUIZ
  // ============================================================================

  Future<List<Quiz>> getAllQuizzes() async {
    try {
      final res = await _supabase.from('quiz').select().order('quiz_id');
      return (res as List).map((m) => Quiz.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Quiz?> getQuizById(int quizId) async {
    try {
      final res = await _supabase.from('quiz').select().eq('quiz_id', quizId).limit(1).maybeSingle();
      if (res == null) return null;
      return Quiz.fromMap(res);
    } catch (e) {
      return null;
    }
  }

  Future<List<QuizQuestion>> getQuizQuestions(int quizId) async {
    try {
      final qRes = await _supabase.from('quiz_question')
        .select()
        .eq('quiz_id', quizId)
        .order('order_index');
      
      final questions = <QuizQuestion>[];
      for (final qMap in (qRes as List)) {
        final question = QuizQuestion.fromMap(qMap);
        final oRes = await _supabase.from('quiz_option')
          .select()
          .eq('question_id', question.questionId!)
          .order('order_index');
        
        question.options = (oRes as List).map((o) => QuizOption.fromMap(o)).toList();
        questions.add(question);
      }
      return questions;
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveQuizScore(int quizId, int score, int totalQuestions) async {
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
    if (_currentUser == null) return [];
    try {
      final res = await _supabase.from('user_quiz_score')
        .select()
        .eq('user_id', _currentUser!.userId!)
        .order('completed_at', ascending: false);
      return (res as List).map((m) => QuizScore.fromMap(m)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<QuizScore?> getBestQuizScore(int quizId) async {
    if (_currentUser == null) return null;
    try {
      final res = await _supabase.from('user_quiz_score')
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
    try {
      final res = await _supabase.from('dim_allergene').select();
      return (res as List).map((m) => Allergene.fromMap(m)).toList();
    } catch (e) { return []; }
  }

  Future<List<Regime>> getAllRegimes() async {
    try {
      final res = await _supabase.from('dim_regime').select();
      return (res as List).map((m) => Regime.fromMap(m)).toList();
    } catch (e) { return []; }
  }

  Future<List<TypePlat>> getAllTypesPlat() async {
    try {
      final res = await _supabase.from('dim_type_plat').select();
      return (res as List).map((m) => TypePlat.fromMap(m)).toList();
    } catch (e) { return []; }
  }

  Future<List<Occasion>> getAllOccasions() async {
    try {
      final res = await _supabase.from('dim_occasion').select();
      return (res as List).map((m) => Occasion.fromMap(m)).toList();
    } catch (e) { return []; }
  }

  Future<List<Equipement>> getAllEquipements() async {
    try {
      final res = await _supabase.from('dim_equipement').select();
      return (res as List).map((m) => Equipement.fromMap(m)).toList();
    } catch (e) { return []; }
  }

  Future<List<TempsBin>> getAllTempsBins() async {
    try {
      final res = await _supabase.from('dim_temps_bin').select();
      return (res as List).map((m) => TempsBin.fromMap(m)).toList();
    } catch (e) { return []; }
  }
}

/// Classe représentant le résultat d'une opération API
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResult._({this.data, this.error, required this.isSuccess});

  factory ApiResult.success(T data) => ApiResult._(data: data, isSuccess: true);
  factory ApiResult.error(String error) => ApiResult._(error: error, isSuccess: false);
}
