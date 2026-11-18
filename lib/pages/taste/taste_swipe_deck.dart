import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../home/home_models.dart';
import 'swipe_card.dart';
import 'swipe_recipe_details.dart';
import 'taste_logic.dart';

/// Pile de cartes à swiper.
///
/// - Glisser à droite / bouton ✓ / flèche droite : « Ça me tente ».
/// - Glisser à gauche / bouton ✕ / flèche gauche : « Pas pour moi ».
/// - Glisser vers le haut / bouton cœur / flèche haut : « Coup de cœur ».
/// - Bouton « Annuler » / retour arrière : revient sur la carte précédente.
/// - Toucher la carte / « Voir la recette » / Entrée : déroule la fiche
///   détaillée (« Réduire » / Échap pour revenir). On peut voter depuis la
///   fiche.
///
/// Appelle `onFinished` avec tous les votes après la dernière carte.
class TasteSwipeDeck extends StatefulWidget {
  final List<RecipeDisplayModel> deck;
  final ValueChanged<List<SwipeVote>> onFinished;

  /// Chargement des étapes de la fiche détaillée (injectable en test).
  final StepsLoader loadSteps;

  const TasteSwipeDeck({
    super.key,
    required this.deck,
    required this.onFinished,
    this.loadSteps = loadRecipeSteps,
  });

  @override
  State<TasteSwipeDeck> createState() => TasteSwipeDeckState();
}

class TasteSwipeDeckState extends State<TasteSwipeDeck>
    with SingleTickerProviderStateMixin {
  static const double _swipeThreshold = 100;
  static const double _velocityThreshold = 800;

  late final AnimationController _ctrl;
  Animation<Offset>? _anim;
  Offset _drag = Offset.zero;
  final List<SwipeVote> _votes = [];
  final FocusNode _focusNode = FocusNode(debugLabel: 'swipe-deck');
  /// Taille de la pile, mesurée au rendu (distance de sortie des cartes).
  Size _cardSize = const Size(400, 520);

  /// Fiche détaillée de la carte du dessus ouverte.
  bool _expanded = false;

  int get _index => _votes.length;
  bool get _done => _index >= widget.deck.length;
  Offset get _offset => _anim?.value ?? _drag;

  /// Votes déjà donnés (lecture seule, utile en test).
  List<SwipeVote> get votes => List.unmodifiable(_votes);

  @override
  void initState() {
    super.initState();
    // Créé ici et non paresseusement : sinon un deck fermé sans aucun swipe
    // créerait son contrôleur dans dispose().
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _animateTo(Offset target, {SwipeVerdict? verdict}) {
    _anim = Tween<Offset>(begin: _offset, end: target).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward(from: 0).whenComplete(() {
      if (!mounted) return;
      setState(() {
        if (verdict != null && !_done) {
          _votes.add(SwipeVote(widget.deck[_index].id, verdict));
        }
        _drag = Offset.zero;
        _anim = null;
      });
      if (verdict != null && _done) widget.onFinished(List.of(_votes));
    });
  }

  /// Vote pour la carte du dessus (boutons, clavier ou fin de glissement).
  void vote(SwipeVerdict verdict) {
    if (_ctrl.isAnimating || _done) return;
    // Depuis la fiche : on revient à la carte, qui part aussitôt.
    if (_expanded) setState(() => _expanded = false);
    final size = _cardSize;
    final current = _offset;
    final Offset target;
    switch (verdict) {
      case SwipeVerdict.dislike:
        target = Offset(-size.width * 1.6, current.dy);
        break;
      case SwipeVerdict.like:
        target = Offset(size.width * 1.6, current.dy);
        break;
      case SwipeVerdict.superLike:
        target = Offset(current.dx, -size.height * 1.6);
        break;
    }
    _animateTo(target, verdict: verdict);
  }

  void undo() {
    if (_ctrl.isAnimating || _votes.isEmpty) return;
    setState(() {
      _votes.removeLast();
      _drag = Offset.zero;
      _expanded = false;
    });
  }

  void _setExpanded(bool value) {
    if (_ctrl.isAnimating || _done || value == _expanded) return;
    setState(() => _expanded = value);
    _focusNode.requestFocus();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_ctrl.isAnimating || _expanded) return;
    setState(() => _drag += d.delta);
  }

  void _onPanEnd(DragEndDetails d) {
    if (_ctrl.isAnimating || _expanded) return;
    final v = d.velocity.pixelsPerSecond;
    final up = -_drag.dy > _swipeThreshold * 1.2 && -_drag.dy > _drag.dx.abs();
    if (up || (v.dy < -_velocityThreshold && v.dy.abs() > v.dx.abs())) {
      vote(SwipeVerdict.superLike);
    } else if (_drag.dx > _swipeThreshold || v.dx > _velocityThreshold) {
      vote(SwipeVerdict.like);
    } else if (_drag.dx < -_swipeThreshold || v.dx < -_velocityThreshold) {
      vote(SwipeVerdict.dislike);
    } else {
      _animateTo(Offset.zero);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowRight) {
      vote(SwipeVerdict.like);
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      vote(SwipeVerdict.dislike);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      vote(SwipeVerdict.superLike);
    } else if (key == LogicalKeyboardKey.backspace) {
      undo();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _setExpanded(!_expanded);
    } else if (key == LogicalKeyboardKey.escape && _expanded) {
      _setExpanded(false);
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.deck.length;
    final shown = min(_index + 1, total);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        children: [
          // Progression
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: total == 0 ? 0 : _index / total),
                    duration: const Duration(milliseconds: 250),
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value,
                      minHeight: 7,
                      backgroundColor: const Color(0xFFE3D8C2),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          SwipeColors.green),
                      semanticsLabel: 'Progression du swipe',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$shown / $total',
                style: const TextStyle(
                  fontSize: 12,
                  color: SwipeColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Pile de cartes, ou fiche détaillée de la carte du dessus
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.04),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: _expanded && !_done
                    ? ConstrainedBox(
                        key: const ValueKey('details'),
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: LayoutBuilder(
                          builder: (context, box) => SwipeRecipeDetails(
                            key: ValueKey('details-${widget.deck[_index].id}'),
                            recipe: widget.deck[_index],
                            loadSteps: widget.loadSteps,
                            availableHeight: box.hasBoundedHeight
                                ? box.maxHeight
                                : 560,
                            onCollapse: () => _setExpanded(false),
                          ),
                        ),
                      )
                    : ConstrainedBox(
                        key: const ValueKey('stack'),
                        constraints:
                            const BoxConstraints(maxWidth: 400, maxHeight: 560),
                        child: LayoutBuilder(builder: (context, box) {
                          if (box.hasBoundedWidth && box.hasBoundedHeight) {
                            _cardSize = box.biggest;
                          }
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (_index + 1 < total)
                                _buildNextCard(widget.deck[_index + 1]),
                              if (!_done)
                                _buildTopCard(
                                    widget.deck[_index], shown, total),
                            ],
                          );
                        }),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // Boutons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _RoundAction(
                icon: Icons.close_rounded,
                color: SwipeColors.nope,
                size: 58,
                label: 'Pas pour moi',
                onPressed: () => vote(SwipeVerdict.dislike),
              ),
              const SizedBox(width: 22),
              _RoundAction(
                icon: Icons.favorite_rounded,
                color: SwipeColors.heart,
                size: 68,
                label: 'Coup de cœur, ajouter aux favoris',
                onPressed: () => vote(SwipeVerdict.superLike),
              ),
              const SizedBox(width: 22),
              _RoundAction(
                icon: Icons.check_rounded,
                color: SwipeColors.green,
                size: 58,
                label: 'Ça me tente',
                onPressed: () => vote(SwipeVerdict.like),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: _votes.isEmpty ? null : undo,
            icon: const Icon(Icons.undo_rounded, size: 18),
            label: const Text('Annuler'),
            style: TextButton.styleFrom(
              foregroundColor: SwipeColors.muted,
              minimumSize: const Size(44, 44),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextCard(RecipeDisplayModel recipe) {
    // La carte suivante grandit à mesure que celle du dessus s'éloigne.
    final progress =
        (_offset.distance / (_swipeThreshold * 1.5)).clamp(0.0, 1.0);
    final scale = 0.94 + 0.06 * progress;
    return Positioned.fill(
      child: ExcludeSemantics(
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - progress)),
          child: Transform.scale(
            scale: scale,
            child: SwipeRecipeCard(key: ValueKey('next-${recipe.id}'), recipe: recipe),
          ),
        ),
      ),
    );
  }

  Widget _buildTopCard(RecipeDisplayModel recipe, int shown, int total) {
    final o = _offset;
    final vertical = -o.dy > o.dx.abs();
    return Positioned.fill(
      child: Semantics(
        liveRegion: true,
        label: 'Carte $shown sur $total : ${recipe.title}. '
            'Utilisez les boutons Pas pour moi, Coup de cœur ou Ça me tente, '
            'ou Voir la recette pour le détail.',
        child: GestureDetector(
          onTap: () => _setExpanded(true),
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: MouseRegion(
            cursor: SystemMouseCursors.grab,
            child: Transform.translate(
              offset: o,
              child: Transform.rotate(
                angle: (o.dx / 900).clamp(-0.4, 0.4),
                child: SwipeRecipeCard(
                  key: ValueKey('top-${recipe.id}'),
                  recipe: recipe,
                  onShowDetails: () => _setExpanded(true),
                  likeOpacity: vertical ? 0 : o.dx / _swipeThreshold,
                  nopeOpacity: vertical ? 0 : -o.dx / _swipeThreshold,
                  loveOpacity: vertical ? -o.dy / (_swipeThreshold * 1.2) : 0,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton rond blanc à icône colorée (cible ≥ 44 px, libellé accessible).
class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final String label;
  final VoidCallback onPressed;

  const _RoundAction({
    required this.icon,
    required this.color,
    required this.size,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          elevation: 3,
          shadowColor: Colors.black.withValues(alpha: 0.25),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(icon, color: color, size: size * 0.46),
            ),
          ),
        ),
      ),
    );
  }
}
