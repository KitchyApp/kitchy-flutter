import 'dart:convert';

import '../main.dart';
import '../models/recipe.dart';

class FavoritesService {
  // ==========================================================================
  // GET FAVORITES (CLOUD)
  // ==========================================================================

  static Future<List<Recipe>> getFavorites() async {
    final response = await apiClient.get(
      '/favorites',
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Erro ao carregar favoritos',
      );
    }

    final List data = jsonDecode(
      response.body,
    );

    return data.map<Recipe>((item) {
      return Recipe.fromJson({
        'id': item['id'],
        ...item['recipe_data'],
      });
    }).toList();
  }

  // ==========================================================================
  // ADD FAVORITE (CLOUD)
  // ==========================================================================

  static Future<void> addFavorite(
      Recipe recipe,
      ) async {
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
          "optional_ingredients":
          recipe.optionalIngredients,
          "vitamins": recipe.vitamins,
          "is_premium": recipe.isPremium,
        }
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Erro ao adicionar favorito",
      );
    }
  }

  // ==========================================================================
  // REMOVE FAVORITE (CLOUD)
  // ==========================================================================

  static Future<void> removeFavorite(
      int favoriteId,
      ) async {
    final response = await apiClient.delete(
      '/favorites/$favoriteId',
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Erro ao remover favorito",
      );
    }
  }

  // ==========================================================================
  // IS FAVORITE (CLOUD)
  // ==========================================================================

  static Future<bool> isFavorite(
      Recipe recipe,
      ) async {
    final favorites =
    await getFavorites();

    return favorites.any(
          (f) => f.title == recipe.title,
    );
  }

  // ==========================================================================
// FIND FAVORITE BY TITLE
// ==========================================================================

  static Future<Recipe?> findFavoriteByTitle(
      String title,
      ) async {
    final favorites =
    await getFavorites();

    try {
      return favorites.firstWhere(
            (f) => f.title == title,
      );
    } catch (_) {
      return null;
    }
  }
}