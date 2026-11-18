import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../models/user.dart';
import '../../services/ecodiet_api.dart';
import '../create_account/onboarding_options.dart';
import '../home/home_controller.dart';

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

/// Libellé d'un code de régime ou d'allergie des options d'inscription
/// (`vegetarian` → « Végétarien ») ; le texte brut sinon.
String preferenceValueLabel(UserPreference pref) {
  final label = pref.label.toLowerCase();
  final codes = pref.value
      .split(RegExp(r'[,;/|]'))
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty);
  String labelOf(String code) {
    for (final o in dietOptions) {
      if (o.value == code) return o.label;
    }
    for (final o in allergyOptions) {
      if (o.value == code) return o.label;
    }
    return code;
  }

  if (label.contains('régime') ||
      label.contains('regime') ||
      label.contains('allerg')) {
    return codes.map(labelOf).join(', ');
  }
  return pref.value;
}

/// Saisie de la boîte « Modifier le profil ».
typedef ProfileEdit = ({
  String prenom,
  String nom,
  String? regime,
  Set<String> allergies,
});

/// État et actions de la page profil. L'API est injectable pour les tests.
class ProfileController extends ChangeNotifier {
  ProfileController({EcoDietApi? api}) : _api = api ?? EcoDietApi();

  final EcoDietApi _api;
  final Logger _log = Logger();
  bool _disposed = false;

  List<UserFolder> _folders = [];
  List<UserPreference> _preferences = [];
  int _favoriteCount = 0;
  bool _hasTasteProfile = false;

  List<UserFolder> get folders => _folders;
  List<UserPreference> get preferences => _preferences;
  int get favoriteCount => _favoriteCount;

  /// L'utilisateur a déjà fait le swipe de goûts.
  bool get hasTasteProfile => _hasTasteProfile;

  String get displayName => profileDisplayName(_api.currentUser);
  String get displayEmail => profileDisplayEmail(_api.currentUser);
  String get avatar => avatarLetter(displayName);
  String get profileTag => _preferences.isNotEmpty
      ? preferenceValueLabel(_preferences.first)
      : 'Aucune préférence';

  /// Préférences avec des libellés lisibles (« Végétarien », « Gluten »).
  List<UserPreference> get displayPreferences => [
        for (final p in _preferences)
          UserPreference(label: p.label, value: preferenceValueLabel(p)),
      ];

  /// Valeurs actuelles, pour pré-remplir la boîte de modification.
  ProfileEdit get currentEdit {
    String? regime;
    final allergies = <String>{};
    for (final p in _preferences) {
      final label = p.label.toLowerCase();
      final values = p.value
          .split(RegExp(r'[,;/|]'))
          .map((v) => v.trim())
          .where((v) => v.isNotEmpty);
      if (label.contains('allerg')) {
        allergies.addAll(values);
      } else if (label.contains('régime') || label.contains('regime')) {
        regime ??= values.isEmpty ? null : values.first;
      }
    }
    final user = _api.currentUser;
    return (
      prenom: (user?.prenom ?? '').trim(),
      nom: (user?.nom ?? '').trim(),
      regime: regime,
      allergies: allergies,
    );
  }

  /// Enregistre nom, régime et allergies, puis recharge le profil. Les
  /// recommandations de l'accueil sont recalculées au prochain affichage.
  Future<bool> saveProfile(ProfileEdit edit) async {
    final before = currentEdit;
    if (edit.prenom != before.prenom || edit.nom != before.nom) {
      final result =
          await _api.updateProfile(prenom: edit.prenom, nom: edit.nom);
      if (!result.isSuccess) return false;
    }
    final saved = await _api.saveUserPreferences(
      regime: edit.regime,
      allergies: edit.allergies,
    );
    HomeController.invalidateCache();
    await load();
    return saved;
  }

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
    // À part : un profil de goûts illisible ne doit pas vider le profil.
    try {
      final taste = await _api.getTasteProfile();
      _hasTasteProfile = taste != null && !taste.isEmpty;
      _notify();
    } catch (error, stack) {
      _log.w('Profil de goûts illisible', error: error, stackTrace: stack);
    }
  }

  /// Après un swipe enregistré depuis le profil.
  void markTasteProfileSaved() {
    _hasTasteProfile = true;
    _notify();
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
    super.dispose();
  }
}
