import 'package:flutter/material.dart';

/// Modèle représentant un utilisateur
class User {
  final String? userId;
  final String email;
  final String? passwordHash;
  final String? nom;
  final String? prenom;
  final String? photoUrl;
  final DateTime? createdAt;

  User({
    this.userId,
    required this.email,
    this.passwordHash,
    this.nom,
    this.prenom,
    this.photoUrl,
    this.createdAt,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      userId: map['id']?.toString(),
      email: map['email'] as String,
      passwordHash: map['mot_de_passe'] as String?,
      nom: map['nom'] as String?,
      prenom: map['prenom'] as String?,
      photoUrl: null, // Plus de colonne photo dans cette table
      createdAt: map['date_creation'] != null 
          ? DateTime.parse(map['date_creation'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (userId != null && int.tryParse(userId!) != null) 'id': int.parse(userId!),
      'email': email,
      if (passwordHash != null) 'mot_de_passe': passwordHash,
      if (nom != null) 'nom': nom,
      if (prenom != null) 'prenom': prenom,
    };
  }

  String get fullName => '${prenom ?? ''} ${nom ?? ''}'.trim();
}

/// Modèle représentant un dossier utilisateur
class UserFolder {
  final int? folderId;
  final String userId;
  final String label;
  final Color color;
  final DateTime? createdAt;
  int recipeCount;

  UserFolder({
    this.folderId,
    required this.userId,
    required this.label,
    required this.color,
    this.createdAt,
    this.recipeCount = 0,
  });

  factory UserFolder.fromMap(Map<String, dynamic> map) {
    return UserFolder(
      folderId: map['folder_id'] as int?,
      userId: map['user_id'].toString(),
      label: map['label'] as String,
      color: Color(map['color'] as int),
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : null,
      recipeCount: map['recipe_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (folderId != null) 'folder_id': folderId,
      'user_id': userId,
      'label': label,
      'color': color.toARGB32(),
    };
  }
}

/// Modèle représentant un quiz
class Quiz {
  final int? quizId;
  final String title;
  final String? description;
  final String? imageUrl;
  final int difficulty;

  Quiz({
    this.quizId,
    required this.title,
    this.description,
    this.imageUrl,
    this.difficulty = 1,
  });

  factory Quiz.fromMap(Map<String, dynamic> map) {
    return Quiz(
      quizId: map['quiz_id'] as int?,
      title: map['title'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      difficulty: map['difficulty'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (quizId != null) 'quiz_id': quizId,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'difficulty': difficulty,
    };
  }
}

/// Modèle représentant une question de quiz
class QuizQuestion {
  final int? questionId;
  final int quizId;
  final String questionText;
  final String? explanation;
  final int orderIndex;
  List<QuizOption> options;

  QuizQuestion({
    this.questionId,
    required this.quizId,
    required this.questionText,
    this.explanation,
    this.orderIndex = 0,
    this.options = const [],
  });

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    return QuizQuestion(
      questionId: map['question_id'] as int?,
      quizId: map['quiz_id'] as int,
      questionText: map['question_text'] as String,
      explanation: map['explanation'] as String?,
      orderIndex: map['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (questionId != null) 'question_id': questionId,
      'quiz_id': quizId,
      'question_text': questionText,
      'explanation': explanation,
      'order_index': orderIndex,
    };
  }

  int? get correctAnswerIndex {
    for (int i = 0; i < options.length; i++) {
      if (options[i].isCorrect) return i;
    }
    return null;
  }
}

/// Modèle représentant une option de réponse
class QuizOption {
  final int? optionId;
  final int questionId;
  final String optionText;
  final bool isCorrect;
  final int orderIndex;

  QuizOption({
    this.optionId,
    required this.questionId,
    required this.optionText,
    this.isCorrect = false,
    this.orderIndex = 0,
  });

  factory QuizOption.fromMap(Map<String, dynamic> map) {
    return QuizOption(
      optionId: map['option_id'] as int?,
      questionId: map['question_id'] as int,
      optionText: map['option_text'] as String,
      isCorrect: (map['is_correct'] as int?) == 1,
      orderIndex: map['order_index'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (optionId != null) 'option_id': optionId,
      'question_id': questionId,
      'option_text': optionText,
      'is_correct': isCorrect ? 1 : 0,
      'order_index': orderIndex,
    };
  }
}

/// Modèle représentant un score de quiz
class QuizScore {
  final String userId;
  final int quizId;
  final int score;
  final int totalQuestions;
  final DateTime completedAt;

  QuizScore({
    required this.userId,
    required this.quizId,
    required this.score,
    required this.totalQuestions,
    required this.completedAt,
  });

  factory QuizScore.fromMap(Map<String, dynamic> map) {
    return QuizScore(
      userId: map['user_id'].toString(),
      quizId: map['quiz_id'] as int,
      score: map['score'] as int,
      totalQuestions: map['total_questions'] as int,
      completedAt: DateTime.parse(map['completed_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'quiz_id': quizId,
      'score': score,
      'total_questions': totalQuestions,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  double get percentage => totalQuestions > 0 ? score / totalQuestions * 100 : 0;
}

/// Modèle pour l'historique de consultation
class RecipeHistory {
  final int historyId;
  final String userId;
  final String recetteId;
  final DateTime viewedAt;

  RecipeHistory({
    required this.historyId,
    required this.userId,
    required this.recetteId,
    required this.viewedAt,
  });

  factory RecipeHistory.fromMap(Map<String, dynamic> map) {
    return RecipeHistory(
      historyId: map['history_id'] as int,
      userId: map['user_id'].toString(),
      recetteId: map['recette_id'] as String,
      viewedAt: DateTime.parse(map['viewed_at'] as String),
    );
  }
}

/// Préférence utilisateur
class UserPreference {
  final String label;
  final String value;

  UserPreference({
    required this.label,
    required this.value,
  });
}
