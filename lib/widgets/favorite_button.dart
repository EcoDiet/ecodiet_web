import 'package:flutter/material.dart';

import '../services/favorites_service.dart';

class FavoriteButton extends StatefulWidget {
  final String recipeId;
  final VoidCallback onToggle;

  const FavoriteButton({
    super.key,
    required this.recipeId,
    required this.onToggle,
  });

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) setState(() {});
    };
    FavoritesService().addListener(_listener);
  }

  @override
  void dispose() {
    FavoritesService().removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFav = FavoritesService().isFavorite(widget.recipeId);
    return IconButton(
      onPressed: widget.onToggle,
      tooltip: isFav ? 'Retirer des favoris' : 'Ajouter aux favoris',
      style: IconButton.styleFrom(
        backgroundColor: Colors.red[50],
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(
        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        size: 20,
        color: Colors.red[400],
      ),
    );
  }
}
