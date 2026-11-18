/// Réponse de l'utilisateur à une carte du swipe.
///
/// Le nom stocké en base (`dbValue`) est figé : ne pas renommer sans
/// migration de `fact_user_swipe.verdict`.
enum SwipeVerdict { dislike, like, superLike }

extension SwipeVerdictWeight on SwipeVerdict {
  /// Poids du vote : −1 (pas pour moi), 1 (ça me tente), 2 (coup de cœur).
  double get weight {
    switch (this) {
      case SwipeVerdict.dislike:
        return -1;
      case SwipeVerdict.like:
        return 1;
      case SwipeVerdict.superLike:
        return 2;
    }
  }

  /// Valeur de la colonne `verdict` en base.
  String get dbValue {
    switch (this) {
      case SwipeVerdict.dislike:
        return 'dislike';
      case SwipeVerdict.like:
        return 'like';
      case SwipeVerdict.superLike:
        return 'super_like';
    }
  }

  static SwipeVerdict? fromDb(Object? raw) {
    final value = '$raw'.trim().toLowerCase();
    for (final v in SwipeVerdict.values) {
      if (v.dbValue == value || v.name.toLowerCase() == value) return v;
    }
    return null;
  }
}

/// Un swipe : la donnée brute, source de vérité du profil de goûts.
/// Correspond à une ligne de `fact_user_swipe`.
class SwipeVote {
  final String recipeId;
  final SwipeVerdict verdict;
  final DateTime? votedAt;

  const SwipeVote(this.recipeId, this.verdict, {this.votedAt});

  SwipeVote stamped(DateTime at) =>
      SwipeVote(recipeId, verdict, votedAt: votedAt ?? at);

  Map<String, dynamic> toJson() => {
        'recette_id': recipeId,
        'verdict': verdict.dbValue,
        'poids': verdict.weight.toInt(),
        if (votedAt != null) 'voted_at': votedAt!.toUtc().toIso8601String(),
      };

  static SwipeVote? fromJson(Map<String, dynamic> json) {
    final id = '${json['recette_id'] ?? json['recipe_id'] ?? ''}'.trim();
    final verdict = SwipeVerdictWeight.fromDb(json['verdict']);
    if (id.isEmpty || verdict == null) return null;
    return SwipeVote(
      id,
      verdict,
      votedAt: DateTime.tryParse('${json['voted_at'] ?? ''}'),
    );
  }
}

/// Fusionne deux historiques de swipes (appareil et serveur) : un seul vote
/// par recette, le plus récent gagne ; à date égale ou inconnue, `b`.
List<SwipeVote> mergeVotes(List<SwipeVote> a, List<SwipeVote> b) {
  final byRecipe = <String, SwipeVote>{};
  for (final vote in [...a, ...b]) {
    final current = byRecipe[vote.recipeId];
    if (current == null) {
      byRecipe[vote.recipeId] = vote;
      continue;
    }
    final cAt = current.votedAt;
    final vAt = vote.votedAt;
    if (cAt == null || vAt == null || !vAt.isBefore(cAt)) {
      byRecipe[vote.recipeId] = vote;
    }
  }
  return byRecipe.values.toList();
}

/// Profil de goûts construit par le swipe de recettes.
///
/// `votes` est la donnée de référence (stockée en base, table
/// `fact_user_swipe`) : poids et pourcentages par ingrédient en sont
/// recalculés avec le catalogue de recettes. `weights` et `labels` sont un
/// cache pour l'écran de fin. Le tout est aussi gardé sur l'appareil.
class TasteProfile {
  /// Caractéristique de recette (`type:plat`, `ing:lentille`, `duree:rapide`…)
  /// → poids dans [−1, 1] : positif si l'utilisateur aime.
  final Map<String, double> weights;

  /// Libellés lisibles des caractéristiques dont la clé perd les accents
  /// (`ing:huile d olive` → « Huile d'olive »).
  final Map<String, String> labels;

  /// Swipes bruts, un par recette.
  final List<SwipeVote> votes;

  /// Recettes « coup de cœur » à ajouter aux favoris dès qu'une session est
  /// ouverte (cas de l'inscription, où l'utilisateur n'est pas encore
  /// connecté).
  final Set<String> pendingFavoriteIds;

  /// Dernier envoi réussi des swipes au serveur (`null` : à envoyer).
  final DateTime? syncedAt;

  final DateTime? updatedAt;

  const TasteProfile({
    this.weights = const {},
    this.labels = const {},
    this.votes = const [],
    this.pendingFavoriteIds = const {},
    this.syncedAt,
    this.updatedAt,
  });

  bool get isEmpty => weights.isEmpty && votes.isEmpty;
  int get voteCount => votes.length;

  /// Des swipes n'ont pas encore été envoyés au serveur.
  bool get needsSync => votes.isNotEmpty && syncedAt == null;

  TasteProfile copyWith({
    Map<String, double>? weights,
    Map<String, String>? labels,
    List<SwipeVote>? votes,
    Set<String>? pendingFavoriteIds,
    DateTime? syncedAt,
    bool clearSyncedAt = false,
  }) =>
      TasteProfile(
        weights: weights ?? this.weights,
        labels: labels ?? this.labels,
        votes: votes ?? this.votes,
        pendingFavoriteIds: pendingFavoriteIds ?? this.pendingFavoriteIds,
        syncedAt: clearSyncedAt ? null : (syncedAt ?? this.syncedAt),
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'weights': weights,
        'labels': labels,
        'votes': votes.map((v) => v.toJson()).toList(),
        'pending_favorites': pendingFavoriteIds.toList(),
        if (syncedAt != null) 'synced_at': syncedAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  factory TasteProfile.fromJson(Map<String, dynamic> json) {
    final rawWeights = json['weights'];
    final weights = <String, double>{};
    if (rawWeights is Map) {
      rawWeights.forEach((k, v) {
        if (v is num) weights['$k'] = v.toDouble();
      });
    }
    final rawLabels = json['labels'];
    final rawVotes = json['votes'];
    final rawPending = json['pending_favorites'];
    return TasteProfile(
      weights: weights,
      labels: rawLabels is Map
          ? rawLabels.map((k, v) => MapEntry('$k', '$v'))
          : const {},
      votes: rawVotes is List
          ? rawVotes
              .whereType<Map>()
              .map((m) => SwipeVote.fromJson(Map<String, dynamic>.from(m)))
              .whereType<SwipeVote>()
              .toList()
          : const [],
      pendingFavoriteIds:
          rawPending is List ? rawPending.map((e) => '$e').toSet() : {},
      syncedAt: DateTime.tryParse('${json['synced_at'] ?? ''}'),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}'),
    );
  }
}
