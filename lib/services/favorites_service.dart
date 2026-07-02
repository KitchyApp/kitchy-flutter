import 'dart:convert';

import '../main.dart';
import '../models/recipe.dart';

class FavoritesService {
  // ==========================================================================
  // GET FAVORITES  →  GET /favorites
  // ==========================================================================
  // Returns the authenticated user's saved recipes, newest first.
  //
  // SAFETY:
  //  - Checks statusCode before parsing — avoids JSONDecodeError on error bodies
  //  - Validates decoded value is a List — survives unexpected server shapes
  //  - Per-item try/catch — one corrupted row never crashes the whole list
  // ==========================================================================

  /// Alias for [getFavorites] — preferred name in new callers.
  static Future<List<Recipe>> fetchSavedRecipes() => getFavorites();

  static Future<List<Recipe>> getFavorites() async {
    final response = await apiClient.get('/favorites');

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao carregar favoritos: HTTP ${response.statusCode}',
      );
    }

    final dynamic decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('Resposta inesperada do servidor ao carregar favoritos.');
    }

    final List<Recipe> result = [];

    for (final item in decoded) {
      try {
        final recipeData =
            (item['recipe_data'] as Map<String, dynamic>?) ?? {};

        result.add(Recipe.fromJson({
          'id': item['id'],
          ...recipeData,
        }));
      } catch (_) {
        // Skip malformed rows rather than crashing the whole list.
      }
    }

    return result;
  }

  // ==========================================================================
  // ADD FAVORITE  →  POST /favorites
  // ==========================================================================

  static Future<void> addFavorite(Recipe recipe) async {
    final response = await apiClient.post(
      '/favorites',
      {
        "recipe_title": recipe.title,
        "recipe_data": {
          "title": recipe.title,
          "calories": recipe.calories,
          "protein": recipe.protein,
          "carbs": recipe.carbs,
          "fat": recipe.fat,
          "time_minutes": recipe.timeMinutes,
          "steps": recipe.steps,
          "optional_ingredients": recipe.optionalIngredients,
          "vitamins": recipe.vitamins,
          "is_premium": recipe.isPremium,
        },
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao adicionar favorito: HTTP ${response.statusCode}',
      );
    }
  }

  // ==========================================================================
  // REMOVE FAVORITE  →  DELETE /favorites/{id}
  // ==========================================================================

  static Future<void> removeFavorite(int favoriteId) async {
    final response = await apiClient.delete('/favorites/$favoriteId');

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao remover favorito: HTTP ${response.statusCode}',
      );
    }
  }

  // ==========================================================================
  // IS FAVORITE  (checks by title against the user's saved list)
  // ==========================================================================

  static Future<bool> isFavorite(Recipe recipe) async {
    final favorites = await getFavorites();
    return favorites.any((f) => f.title == recipe.title);
  }

  // ==========================================================================
  // FIND FAVORITE BY TITLE
  // ==========================================================================

  static Future<Recipe?> findFavoriteByTitle(String title) async {
    final favorites = await getFavorites();
    try {
      return favorites.firstWhere((f) => f.title == title);
    } catch (_) {
      return null;
    }
  }
}
