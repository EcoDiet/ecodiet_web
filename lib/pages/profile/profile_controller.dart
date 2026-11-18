import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../models/user.dart';
import '../../services/ecodiet_api.dart';
import '../../services/favorites_service.dart';

/// Nom affiché : prénom et nom, sinon la partie locale de l'e-mail.
String profileDisplayName(User? user) {
  if (user == null) return 'Utilisateur';
  final fullName =
      '${(user.prenom ?? '').trim()} ${(user.nom ?? '').trim()}'.trim();
  if (fullName.isNotEmpty) return fullName;
  final email = user.email.trim();
  if (email.isNotEmpty) return email.split('@').first;
  return 'Utilisateur';
}

String profileDisplayEmail(User? user) {
  final email = (user?.email ?? '').trim();
  return email.isEmpty ? 'utilisateur@ecodiet.fr' : email;
}

String avatarLetter(String displayName) {
  final name = displayName.trim();
  return name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase();
}

bool isFavoritesFolder(UserFolder folder) =>
    folder.label.toLowerCase() == 'favoris';

/// « 1 recette », « 2 recettes ».
String countLabel(int count, String noun) =>
    '$count $noun${count > 1 ? 's' : ''}';

/// État et actions de la page profil. L'API est injectable pour les tests.
class ProfileController extends ChangeNotifier {
  ProfileController({EcoDietApi? api}) : _api = api ?? EcoDietApi() {
    FavoritesService().addListener(_notify);
  }

  final EcoDietApi _api;
  final Logger _log = Logger();
  bool _disposed = false;

  List<UserFolder> _folders = [];
  List<UserPreference> _preferences = [];
  int _favoriteCount = 0;

  List<UserFolder> get folders => _folders;
  List<UserPreference> get preferences => _preferences;
  int get favoriteCount => _favoriteCount;

  String get displayName => profileDisplayName(_api.currentUser);
  String get displayEmail => profileDisplayEmail(_api.currentUser);
  String get avatar => avatarLetter(displayName);
  String get profileTag =>
      _preferences.isNotEmpty ? _preferences.first.value : 'Aucune preference';

  /// Le dossier « Favoris » affiche le nombre de favoris, pas son compteur.
  int recipeCountOf(UserFolder folder) =>
      isFavoritesFolder(folder) ? _favoriteCount : folder.recipeCount;

  Future<void> load() async {
    try {
      final folders = await _api.getFolders();
      final preferences = await _api.getUserPreferences();
      final favorites = await _api.getFavorites();
      _folders = folders;
      _preferences = preferences;
      _favoriteCount = favorites.length;
      _notify();
    } catch (error, stack) {
      _log.w('Erreur chargement profil', error: error, stackTrace: stack);
    }
  }

  Future<void> createFolder(String label, int colorValue) async {
    final result =
        await _api.createFolder(label: label, colorValue: colorValue);
    if (result.isSuccess) await load();
  }

  Future<void> updateFolder(
      UserFolder folder, String label, int colorValue) async {
    if (folder.folderId == null) return;
    await _api.updateFolder(folder.folderId!,
        newLabel: label, colorValue: colorValue);
    await load();
  }

  Future<void> deleteFolder(UserFolder folder) async {
    if (folder.folderId != null) await _api.deleteFolder(folder.folderId!);
    await load();
  }

  Future<void> logout() => _api.logout();

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    FavoritesService().removeListener(_notify);
    super.dispose();
  }
}
