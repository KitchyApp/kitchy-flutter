import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart' show appApi;
import '../models/recipe.dart';
import '../services/favorites_service.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

// =============================================================================
// FAVORITES SCREEN
// =============================================================================
// Loads the authenticated user's saved recipes from the backend on open.
// Supports:
//   • Pull-to-refresh
//   • Inline search bar — filters by title, ingredients, and step text
//   • Per-card share (share_plus) and remove actions
//   • Error recovery with retry button
// =============================================================================

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  // ── Source list (always the full server response) ────────────────────────────
  List<Recipe> _favorites = [];

  // ── Filtered list (rendered by the ListView) ─────────────────────────────────
  // Kept in sync with _favorites and _searchQuery via _applyFilter().
  // Never modified directly — always derived from _favorites.
  List<Recipe> _filteredRecipes = [];

  bool _isLoading = true;
  String? _error;

  // ── Search state ─────────────────────────────────────────────────────────────
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // ============================================================================
  // LIFECYCLE
  // ============================================================================

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================================
  // DATA LOADING
  // ============================================================================

  Future<void> _loadFavorites() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await FavoritesService.getFavorites();
      if (!mounted) return;
      setState(() {
        _favorites = result;
        _isLoading = false;
      });
      // Re-apply the current search query to the fresh list so any pending
      // filter is not silently dropped after a pull-to-refresh.
      _applyFilter();
    } catch (e) {
      debugPrint('[FavoritesScreen] Erro ao carregar favoritos: $e');
      if (!mounted) return;
      setState(() {
        _error =
            'Não foi possível carregar os favoritos.\nVerifica a ligação e tenta novamente.';
        _isLoading = false;
      });
    }
  }

  // ============================================================================
  // SEARCH / FILTER
  // ============================================================================

  // Called on every keystroke via TextField.onChanged.
  // Updates _searchQuery and rebuilds _filteredRecipes in one setState call
  // so the list reacts in real-time without a separate Future or debounce.
  void _onSearchChanged(String value) {
    _searchQuery = value.trim().toLowerCase();
    _applyFilter();
  }

  // Derives _filteredRecipes from the current _favorites + _searchQuery.
  // Must be called whenever either changes (after load, after remove, on type).
  void _applyFilter() {
    setState(() {
      _filteredRecipes = _searchQuery.isEmpty
          ? List.from(_favorites)
          : _favorites.where((r) => r.matchesQuery(_searchQuery)).toList();
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  // ============================================================================
  // REMOVE
  // ============================================================================

  Future<void> _removeFavorite(Recipe recipe) async {
    if (recipe.favoriteId == null) return;

    try {
      await FavoritesService.removeFavorite(recipe.favoriteId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receita removida dos favoritos.'),
          backgroundColor: Color(0xFFFF7043),
          duration: Duration(seconds: 2),
        ),
      );
      await _loadFavorites();
    } catch (e) {
      debugPrint('[FavoritesScreen] Erro ao remover favorito: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao remover: $e'),
          backgroundColor: Colors.red[700],
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos ❤️'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    // ── Loading ──────────────────────────────────────────────────────────────
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF7043)),
      );
    }

    // ── Error ────────────────────────────────────────────────────────────────
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadFavorites,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    // ── Empty (no saved recipes at all) ──────────────────────────────────────
    // The search bar is intentionally NOT shown here: searching an empty list
    // would always yield zero results and creates a confusing UX.
    if (_favorites.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.85, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (_, scale, child) =>
                    Transform.scale(scale: scale, child: child),
                child: const Text('🍳', style: TextStyle(fontSize: 72)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Ainda não guardaste\nnenhuma receita.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Começa a cozinhar e guarda\nas tuas favoritas com ❤️',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Ir gerar receitas'),
              ),
            ],
          ),
        ),
      );
    }

    // ── Has favorites → search bar + list ────────────────────────────────────
    return Column(
      children: [
        // ── Search bar (sticky — does not scroll with the list) ────────────
        _SearchBar(
          controller: _searchController,
          onChanged: _onSearchChanged,
          onClear: _clearSearch,
          hasText: _searchQuery.isNotEmpty,
        ),

        // ── List area (scrollable, supports pull-to-refresh) ───────────────
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadFavorites,
            color: const Color(0xFFFF7043),
            child: _filteredRecipes.isEmpty
                ? _buildNoResults()
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 16),
                    itemCount: _filteredRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = _filteredRecipes[index];
                      return _FavoriteItem(
                        recipe: recipe,
                        onRemove: () => _removeFavorite(recipe),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ── No results state (search active but no matches) ───────────────────────
  // Uses a ListView so RefreshIndicator's pull-to-refresh still works even
  // when showing the empty-search message (the scroll target must be scrollable).
  Widget _buildNoResults() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Nenhuma receita encontrada\ncom esse ingrediente.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: _clearSearch,
                icon: const Icon(Icons.clear),
                label: const Text('Limpar pesquisa'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// SEARCH BAR WIDGET
// =============================================================================

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool hasText;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.hasText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF8F3),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        autofocus: false,
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.search,
        enableSuggestions: false,
        autocorrect: false,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          hintText: 'Pesquisa por ingredientes (ex: frango, bife)...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          // ── Search icon (left) ────────────────────────────────────────────
          prefixIcon: const Icon(Icons.search, color: Color(0xFFFF7043)),
          // ── Clear button (right) — only visible when field is not empty ──
          suffixIcon: hasText
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  color: Colors.grey[500],
                  tooltip: 'Limpar pesquisa',
                  onPressed: onClear,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFFF7043), width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }
}

// =============================================================================
// _FAVORITE ITEM
// =============================================================================

class _FavoriteItem extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onRemove;

  const _FavoriteItem({required this.recipe, required this.onRemove});

  void _share() {
    appApi.logEvent(
      'share_triggered',
      metadata: {
        'source': 'favorites_screen',
        'recipe_title': recipe.title,
      },
    );
    SharePlus.instance.share(
      ShareParams(text: recipe.toShareText()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RecipeCard(
          recipe: recipe,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: recipe),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _share,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF7043),
                    side: const BorderSide(color: Color(0xFFFF7043)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.share_outlined, size: 16),
                  label: const Text('Partilhar'),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onRemove,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remover'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
