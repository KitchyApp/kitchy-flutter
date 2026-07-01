import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/recipe.dart';
import '../services/favorites_service.dart';
import '../widgets/recipe_card.dart';
import 'recipe_detail_screen.dart';

// =============================================================================
// FAVORITES SCREEN
// =============================================================================
// Loads the authenticated user's saved recipes from the backend on open.
// Supports pull-to-refresh, error recovery, per-card share and remove actions.
// =============================================================================

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Recipe> _favorites = [];
  bool _isLoading = true;
  String? _error;

  // ── Init ────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

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
    } catch (e) {
      debugPrint('[FavoritesScreen] Erro ao carregar favoritos: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Não foi possível carregar os favoritos.\nVerifica a ligação e tenta novamente.';
        _isLoading = false;
      });
    }
  }

  // ── Remove ───────────────────────────────────────────────────────────────────

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
      // Refresh from the server so the list stays in sync.
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

  // ── Build ────────────────────────────────────────────────────────────────────

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
    // ── Loading ────────────────────────────────────────────────────────────────
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF7043)),
      );
    }

    // ── Error ──────────────────────────────────────────────────────────────────
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

    // ── Empty ──────────────────────────────────────────────────────────────────
    if (_favorites.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_border, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Ainda não tens favoritos.\nAbre uma receita e guarda-a com ❤️!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // ── List ───────────────────────────────────────────────────────────────────
    // RefreshIndicator gives pull-to-refresh without extra buttons.
    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: const Color(0xFFFF7043),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _favorites.length,
        itemBuilder: (context, index) {
          final recipe = _favorites[index];
          return _FavoriteItem(
            recipe: recipe,
            onRemove: () => _removeFavorite(recipe),
          );
        },
      ),
    );
  }
}

// =============================================================================
// _FAVORITE ITEM
// =============================================================================
// RecipeCard handles the tap → detail navigation.
// Action bar below provides share (share_plus) and remove buttons.
// Kept as a private widget so the action callbacks are wired in one place.
// =============================================================================

class _FavoriteItem extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onRemove;

  const _FavoriteItem({required this.recipe, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Recipe card (tap → RecipeDetailScreen) ────────────────────────────
        RecipeCard(
          recipe: recipe,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => RecipeDetailScreen(recipe: recipe),
            ),
          ),
        ),

        // ── Action bar (share + remove) ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => SharePlus.instance.share(
                  ShareParams(text: recipe.toShareText()),
                ),
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Partilhar'),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[700],
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
