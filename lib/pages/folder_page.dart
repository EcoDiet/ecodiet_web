import 'package:flutter/material.dart';

import '../utils/responsive.dart';
import 'folder/folder_controller.dart';
import 'folder/folder_widgets.dart';

class FolderPage extends StatefulWidget {
  final String? id;
  final String? label;
  final Color? color;
  final bool showBackButton;

  /// Injectable pour les tests ; sinon créé à partir de [id].
  final FolderController? controller;

  const FolderPage({
    super.key,
    this.id,
    this.label,
    this.color,
    this.showBackButton = true,
    this.controller,
  });

  @override
  State<FolderPage> createState() => _FolderPageState();
}

class _FolderPageState extends State<FolderPage> {
  late final FolderController _c =
      widget.controller ?? FolderController(folderId: widget.id);

  String get _label => widget.label ?? 'Dossier';
  Color get _folderColor => widget.color ?? const Color(0xFFF4A259);

  @override
  void initState() {
    super.initState();
    _c.addListener(_onChanged);
    _c.load();
  }

  @override
  void dispose() {
    _c.removeListener(_onChanged);
    if (widget.controller == null) _c.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return isDesktop(context) ? _buildDesktop() : _buildMobile();
  }

  Widget _buildDesktop() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                FolderDesktopHeader(
                  label: _label,
                  folderColor: _folderColor,
                  isFavorites: _c.isFavorites,
                  recipeCount: _c.recipes.length,
                  showBackButton: widget.showBackButton,
                ),
                Expanded(
                  child: _c.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _c.recipes.isEmpty
                          ? FolderEmptyState(isFavorites: _c.isFavorites)
                          : FolderRecipesGrid(
                              recipes: _c.recipes,
                              onRemove: _c.remove,
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobile() {
    final recipes = _c.recipes;
    return Scaffold(
      backgroundColor: const Color(0xFFF5ECD9),
      body: _c.isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: widget.showBackButton
                      ? FolderMobileHeaderWithBack(
                          label: _label,
                          folderColor: _folderColor,
                          isFavorites: _c.isFavorites,
                          recipeCount: recipes.length,
                        )
                      : FolderMobileHero(
                          label: _label,
                          isFavorites: _c.isFavorites,
                          recipeCount: recipes.length,
                        ),
                ),
                if (recipes.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: FolderEmptyState(isFavorites: _c.isFavorites),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DismissibleFolderCard(
                            recipe: recipes[index],
                            onRemove: () => _c.remove(recipes[index]),
                            onRestore: () => _c.restore(recipes[index]),
                          ),
                        ),
                        childCount: recipes.length,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
