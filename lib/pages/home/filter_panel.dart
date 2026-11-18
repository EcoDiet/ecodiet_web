import 'package:flutter/material.dart';

import 'home_models.dart';

class DesktopFilterDrawerContent extends StatelessWidget {
  final RecipeFilters initialFilters;
  final List<String> ingredientOptions;
  final List<String> utensilOptions;
  final List<String> dietOptions;
  final List<String> allergenOptions;
  final ValueChanged<RecipeFilters> onApply;

  const DesktopFilterDrawerContent({
    super.key,
    required this.initialFilters,
    required this.ingredientOptions,
    required this.utensilOptions,
    required this.dietOptions,
    required this.allergenOptions,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return _FilterPanel(
      desktop: true,
      initialFilters: initialFilters,
      ingredientOptions: ingredientOptions,
      utensilOptions: utensilOptions,
      dietOptions: dietOptions,
      allergenOptions: allergenOptions,
      onApply: onApply,
      onClose: () => Navigator.of(context).maybePop(),
    );
  }
}

class MobileFilterSheetContent extends StatelessWidget {
  final RecipeFilters initialFilters;
  final List<String> ingredientOptions;
  final List<String> utensilOptions;
  final List<String> dietOptions;
  final List<String> allergenOptions;
  final ValueChanged<RecipeFilters> onApply;

  const MobileFilterSheetContent({
    super.key,
    required this.initialFilters,
    required this.ingredientOptions,
    required this.utensilOptions,
    required this.dietOptions,
    required this.allergenOptions,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return _FilterPanel(
      desktop: false,
      initialFilters: initialFilters,
      ingredientOptions: ingredientOptions,
      utensilOptions: utensilOptions,
      dietOptions: dietOptions,
      allergenOptions: allergenOptions,
      onApply: onApply,
      onClose: () => Navigator.of(context).maybePop(),
    );
  }
}

class _FilterPanel extends StatefulWidget {
  final bool desktop;
  final RecipeFilters initialFilters;
  final List<String> ingredientOptions;
  final List<String> utensilOptions;
  final List<String> dietOptions;
  final List<String> allergenOptions;
  final ValueChanged<RecipeFilters> onApply;
  final VoidCallback onClose;

  const _FilterPanel({
    required this.desktop,
    required this.initialFilters,
    required this.ingredientOptions,
    required this.utensilOptions,
    required this.dietOptions,
    required this.allergenOptions,
    required this.onApply,
    required this.onClose,
  });

  @override
  State<_FilterPanel> createState() => _FilterPanelState();
}

class _FilterPanelState extends State<_FilterPanel> {
  late RecipeFilters _draft;
  late TextEditingController _minTimeController;
  late TextEditingController _maxTimeController;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialFilters.copy();
    _minTimeController = TextEditingController(
      text: _draft.minTimeMinutes?.toString() ?? '',
    );
    _maxTimeController = TextEditingController(
      text: _draft.maxTimeMinutes?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minTimeController.dispose();
    _maxTimeController.dispose();
    super.dispose();
  }

  void _reset() {
    setState(() {
      _draft.reset();
      _minTimeController.text = '';
      _maxTimeController.text = '';
    });
  }

  void _setTimeRange(int? min, int? max) {
    setState(() {
      _draft.minTimeMinutes = min;
      _draft.maxTimeMinutes = max;
      _minTimeController.text = min?.toString() ?? '';
      _maxTimeController.text = max?.toString() ?? '';
    });
  }

  String _timeRangeLabel() {
    final min = _draft.minTimeMinutes;
    final max = _draft.maxTimeMinutes;
    if (min == null && max == null) return '';
    if (min == null) return '< ${max! + 1} min';
    if (max == null) return '> ${min - 1} min';
    if (min == 30 && max == 60) return '30-60 min';
    if (min == 61 && max == 120) return '1-2 h';
    return '$min-$max min';
  }

  bool _isSelectedTimeRange(int? min, int? max) {
    return _draft.minTimeMinutes == min && _draft.maxTimeMinutes == max;
  }

  Widget _activeFilterChip(String label, VoidCallback onDeleted) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: const Color(0xFFE9F2E6),
      side: BorderSide.none,
      deleteIconColor: const Color(0xFF2F6B3F),
      labelStyle: const TextStyle(
        color: Color(0xFF1F2E1F),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildActiveFilters() {
    if (_draft.activeCount == 0) return const SizedBox.shrink();

    final chips = <Widget>[
      ..._draft.ingredients.map(
        (value) => _activeFilterChip(value, () {
          setState(() => _draft.ingredients.remove(value));
        }),
      ),
      ..._draft.diets.map(
        (value) => _activeFilterChip(value, () {
          setState(() => _draft.diets.remove(value));
        }),
      ),
      ..._draft.allergens.map(
        (value) => _activeFilterChip('Sans $value', () {
          setState(() => _draft.allergens.remove(value));
        }),
      ),
      ..._draft.utensils.map(
        (value) => _activeFilterChip(value, () {
          setState(() => _draft.utensils.remove(value));
        }),
      ),
    ];

    if (_draft.minTimeMinutes != null || _draft.maxTimeMinutes != null) {
      chips.add(
        _activeFilterChip(_timeRangeLabel(), () => _setTimeRange(null, null)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: chips),
    );
  }

  Widget _buildTimeFilterCard() {
    return _FilterCard(
      title: 'Temps de cuisine',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _TimeFilterChip(
            label: 'Tous',
            selected: _isSelectedTimeRange(null, null),
            onSelected: () => _setTimeRange(null, null),
          ),
          _TimeFilterChip(
            label: '< 30 min',
            selected: _isSelectedTimeRange(null, 29),
            onSelected: () => _setTimeRange(null, 29),
          ),
          _TimeFilterChip(
            label: '30-60 min',
            selected: _isSelectedTimeRange(30, 60),
            onSelected: () => _setTimeRange(30, 60),
          ),
          _TimeFilterChip(
            label: '1-2 h',
            selected: _isSelectedTimeRange(61, 120),
            onSelected: () => _setTimeRange(61, 120),
          ),
          _TimeFilterChip(
            label: '> 2 h',
            selected: _isSelectedTimeRange(121, null),
            onSelected: () => _setTimeRange(121, null),
          ),
        ],
      ),
    );
  }

  void _apply() {
    final min = int.tryParse(_minTimeController.text.trim());
    final max = int.tryParse(_maxTimeController.text.trim());
    _draft.minTimeMinutes = min;
    _draft.maxTimeMinutes = max;
    if (_draft.minTimeMinutes != null &&
        _draft.maxTimeMinutes != null &&
        _draft.minTimeMinutes! > _draft.maxTimeMinutes!) {
      final tmp = _draft.minTimeMinutes!;
      _draft.minTimeMinutes = _draft.maxTimeMinutes;
      _draft.maxTimeMinutes = tmp;
    }
    widget.onApply(_draft.copy());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            children: [
              const Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2E1F),
                ),
              ),
              const SizedBox(width: 10),
              if (_draft.activeCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F6B3F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_draft.activeCount} ${_draft.activeCount > 1 ? 'actifs' : 'actif'}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        _buildActiveFilters(),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              _FilterMultiSelectCard(
                title: 'Ingrédients',
                hintText: 'Ex: poulet, riz, tomate',
                options: widget.ingredientOptions,
                selected: _draft.ingredients,
                onChanged: (values) =>
                    setState(() => _draft.ingredients = values),
              ),
              const SizedBox(height: 12),
              _buildTimeFilterCard(),
              const SizedBox(height: 12),
              _FilterMultiSelectCard(
                title: 'Type de plat / régime',
                hintText: 'Plat principal, vegan, dessert...',
                options: widget.dietOptions,
                selected: _draft.diets,
                onChanged: (values) => setState(() => _draft.diets = values),
              ),
              const SizedBox(height: 12),
              _FilterMultiSelectCard(
                title: 'Allergènes à exclure',
                hintText: 'Gluten, lactose, soja...',
                options: widget.allergenOptions,
                selected: _draft.allergens,
                onChanged: (values) =>
                    setState(() => _draft.allergens = values),
              ),
              const SizedBox(height: 12),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                  childrenPadding: EdgeInsets.zero,
                  title: const Text(
                    'Plus de filtres',
                    style: TextStyle(
                      color: Color(0xFF1F2E1F),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  children: [
                    _FilterMultiSelectCard(
                      title: 'Ustensiles',
                      hintText: 'Four, poele, casserole...',
                      options: widget.utensilOptions,
                      selected: _draft.utensils,
                      onChanged: (values) =>
                          setState(() => _draft.utensils = values),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _reset,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2F6B3F)),
                    foregroundColor: const Color(0xFF2F6B3F),
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Réinitialiser'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _apply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2F6B3F),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(44),
                  ),
                  child: const Text('Appliquer'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterCard({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6DCC9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2E1F),
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _TimeFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _TimeFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: const Color(0xFF2F6B3F),
      labelStyle: TextStyle(
        color: selected ? Colors.white : const Color(0xFF1F2E1F),
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide(
        color: selected ? const Color(0xFF2F6B3F) : const Color(0xFFE6DCC9),
      ),
      backgroundColor: Colors.white,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _FilterMultiSelectCard extends StatefulWidget {
  final String title;
  final String hintText;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _FilterMultiSelectCard({
    required this.title,
    required this.hintText,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_FilterMultiSelectCard> createState() => _FilterMultiSelectCardState();
}

class _FilterMultiSelectCardState extends State<_FilterMultiSelectCard> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final visible = widget.options
        .where((o) =>
            !widget.selected.contains(o) &&
            (q.isEmpty || o.toLowerCase().contains(q)))
        .take(10)
        .toList();

    return _FilterCard(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Autocomplete<String>(
            optionsBuilder: (value) {
              final q = value.text.trim().toLowerCase();
              if (q.isEmpty) {
                return widget.options
                    .where((o) => !widget.selected.contains(o))
                    .take(6);
              }
              return widget.options
                  .where((o) =>
                      o.toLowerCase().contains(q) &&
                      !widget.selected.contains(o))
                  .take(6);
            },
            onSelected: (choice) {
              final next = {...widget.selected, choice};
              widget.onChanged(next);
              setState(() => _query = '');
            },
            fieldViewBuilder:
                (context, controller, focusNode, onFieldSubmitted) {
              return TextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              );
            },
          ),
          if (widget.selected.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.selected
                  .map((s) => InputChip(
                        label: Text(s),
                        onDeleted: () {
                          final next = {...widget.selected}..remove(s);
                          widget.onChanged(next);
                        },
                      ))
                  .toList(),
            ),
          ],
          if (visible.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: visible
                  .map(
                    (option) => ActionChip(
                      label: Text(option),
                      avatar: const Icon(Icons.add_rounded, size: 16),
                      onPressed: () {
                        final next = {...widget.selected, option};
                        widget.onChanged(next);
                      },
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
