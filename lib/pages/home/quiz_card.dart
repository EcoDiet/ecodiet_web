import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'home_models.dart';

/// Carte quiz : horizontale compacte sur desktop, verticale avec bannière sur mobile.
class QuizCard extends StatelessWidget {
  final Quiz quiz;
  final bool desktop;

  const QuizCard({super.key, required this.quiz, this.desktop = false});

  @override
  Widget build(BuildContext context) {
    void onTap() => Navigator.pushNamed(
          context,
          '/quiz',
          arguments: {
            'id': quiz.id,
            'title': quiz.title,
            'description': quiz.description,
          },
        );

    if (desktop) {
      // Carte horizontale compacte : pas de bannière image, hauteur libre
      return Semantics(
        label: 'Quiz : ${quiz.title}',
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Icône colorée à gauche
                Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF4A259), Color(0xFFEA853D)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(quiz.icon, size: 28, color: Colors.white),
                ),
                // Texte
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quiz.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2E1F),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          quiz.description,
                          style:
                              TextStyle(fontSize: 11, color: Colors.grey[700]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                // Bouton jouer
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4A259),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Jouer',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile : carte verticale avec bannière
    return Semantics(
      label: 'Quiz : ${quiz.title}',
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  gradient: quiz.imageUrl == null
                      ? const LinearGradient(
                          colors: [Color(0xFFF4A259), Color(0xFFEA853D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  image: quiz.imageUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(quiz.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: quiz.imageUrl == null
                    ? Center(
                        child: Icon(quiz.icon,
                            size: 36,
                            color: Colors.white.withValues(alpha: 0.7)),
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quiz.title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2E1F),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            quiz.description,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600]),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4A259),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Jouer',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
