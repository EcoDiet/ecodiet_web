/// Modèle représentant une recette
class Recette {
  final String recetteId;
  final String titre;
  final String photo;
  final int dureeMinute;
  final int tempsBinId;

  Recette({
    required this.recetteId,
    required this.titre,
    required this.photo,
    required this.dureeMinute,
    required this.tempsBinId,
  });

  factory Recette.fromMap(Map<String, dynamic> map) {
    return Recette(
      recetteId: map['recette_id'] as String,
      titre: map['titre'] as String,
      photo: map['photo'] as String,
      dureeMinute: map['duree_minute'] as int,
      tempsBinId: map['temps_bin_id'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'recette_id': recetteId,
      'titre': titre,
      'photo': photo,
      'duree_minute': dureeMinute,
      'temps_bin_id': tempsBinId,
    };
  }
}

/// Modèle représentant un allergène
class Allergene {
  final int allergeneId;
  final String libelle;

  Allergene({required this.allergeneId, required this.libelle});

  factory Allergene.fromMap(Map<String, dynamic> map) {
    return Allergene(
      allergeneId: map['allergene_id'] as int,
      libelle: map['libelle'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'allergene_id': allergeneId,
      'libelle': libelle,
    };
  }
}

/// Modèle représentant un équipement
class Equipement {
  final int equipementId;
  final String nomEquipement;

  Equipement({required this.equipementId, required this.nomEquipement});

  factory Equipement.fromMap(Map<String, dynamic> map) {
    return Equipement(
      equipementId: map['equipement_id'] as int,
      nomEquipement: map['nom_equipement'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'equipement_id': equipementId,
      'nom_equipement': nomEquipement,
    };
  }
}

/// Modèle représentant un ingrédient
class Ingredient {
  final int ingredientId;
  final String nomIngredient;

  Ingredient({required this.ingredientId, required this.nomIngredient});

  factory Ingredient.fromMap(Map<String, dynamic> map) {
    return Ingredient(
      ingredientId: map['ingredient_id'] as int,
      nomIngredient: map['nom_ingredient'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ingredient_id': ingredientId,
      'nom_ingredient': nomIngredient,
    };
  }
}

/// Modèle représentant une occasion
class Occasion {
  final int occasionId;
  final String libelle;

  Occasion({required this.occasionId, required this.libelle});

  factory Occasion.fromMap(Map<String, dynamic> map) {
    return Occasion(
      occasionId: map['occasion_id'] as int,
      libelle: map['libelle'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'occasion_id': occasionId,
      'libelle': libelle,
    };
  }
}

/// Modèle représentant un régime alimentaire
class Regime {
  final int regimeId;
  final String libelle;

  Regime({required this.regimeId, required this.libelle});

  factory Regime.fromMap(Map<String, dynamic> map) {
    return Regime(
      regimeId: map['regime_id'] as int,
      libelle: map['libelle'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'regime_id': regimeId,
      'libelle': libelle,
    };
  }
}

/// Modèle représentant un type de plat
class TypePlat {
  final int typePlatId;
  final String libelle;

  TypePlat({required this.typePlatId, required this.libelle});

  factory TypePlat.fromMap(Map<String, dynamic> map) {
    return TypePlat(
      typePlatId: map['type_plat_id'] as int,
      libelle: map['libelle'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type_plat_id': typePlatId,
      'libelle': libelle,
    };
  }
}

/// Modèle représentant un bin de temps (plage de durée)
class TempsBin {
  final int tempsBinId;
  final String libelle;
  final int minMinutes;
  final int maxMinutes;

  TempsBin({
    required this.tempsBinId,
    required this.libelle,
    required this.minMinutes,
    required this.maxMinutes,
  });

  factory TempsBin.fromMap(Map<String, dynamic> map) {
    return TempsBin(
      tempsBinId: map['temps_bin_id'] as int,
      libelle: map['libelle'] as String,
      minMinutes: map['min_minutes'] as int,
      maxMinutes: map['max_minutes'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'temps_bin_id': tempsBinId,
      'libelle': libelle,
      'min_minutes': minMinutes,
      'max_minutes': maxMinutes,
    };
  }
}

/// Modèle représentant une recette complète avec toutes ses relations
class RecetteComplete {
  final Recette recette;
  final TempsBin? tempsBin;
  final List<Allergene> allergenes;
  final List<Equipement> equipements;
  final List<Ingredient> ingredients;
  final List<Occasion> occasions;
  final Regime? regime;
  final TypePlat? typePlat;

  RecetteComplete({
    required this.recette,
    this.tempsBin,
    this.allergenes = const [],
    this.equipements = const [],
    this.ingredients = const [],
    this.occasions = const [],
    this.regime,
    this.typePlat,
  });
}
