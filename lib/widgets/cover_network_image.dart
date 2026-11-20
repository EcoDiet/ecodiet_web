import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// Photo réseau en `BoxFit.cover`, décodée à la taille affichée plutôt qu'en
/// pleine résolution (mémoire et temps de décodage, surtout pour les cartes).
///
/// Doit recevoir des contraintes fixes (Stack en `StackFit.expand`…).
class CoverNetworkImage extends StatelessWidget {
  const CoverNetworkImage({super.key, required this.imageUrl});

  final String imageUrl;

  /// Les photos de recettes sont au plus ~3:2 en paysage : pour couvrir une
  /// boîte haute, la largeur décodée doit valoir 1,5 × sa hauteur.
  static const double _maxImageAspect = 1.5;

  /// Paliers de largeur : un redimensionnement de fenêtre ne redécode pas
  /// l'image à chaque pixel.
  static const int _step = 128;

  /// Largeur de décodage en pixels physiques, `null` si inconnue.
  static int? cacheWidthFor(BoxConstraints constraints, double pixelRatio) {
    final w = constraints.maxWidth;
    final h = constraints.maxHeight;
    if (!w.isFinite || !h.isFinite || w <= 0) return null;
    final logical = math.max(w, h * _maxImageAspect);
    final physical = (logical * pixelRatio).ceil();
    return ((physical + _step - 1) ~/ _step) * _step;
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return LayoutBuilder(
      builder: (context, constraints) => CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        memCacheWidth: cacheWidthFor(constraints, pixelRatio),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
        placeholder: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}
