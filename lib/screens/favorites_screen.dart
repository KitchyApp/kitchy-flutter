import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/favorites_service.dart';
import 'recipe_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() =>
      _FavoritesScreenState();
}

class _FavoritesScreenState
    extends State<FavoritesScreen> {

  List<Recipe> favorites = [];

  @override
  void initState() {
    super.initState();

    loadFavorites();
  }

  Future<void> loadFavorites() async {
    final result =
    await FavoritesService.getFavorites();

    setState(() {
      favorites = result;
    });
  }

  Future<void> removeFavorite(Recipe recipe) async {
    if (recipe.favoriteId != null) {
      await FavoritesService.removeFavorite(
        recipe.favoriteId!,
      );
    }
    await loadFavorites();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Favoritos ❤️"),
      ),

      body: favorites.isEmpty
          ? const Center(
        child: Text(
          "Ainda não tens favoritos.",
          style: TextStyle(fontSize: 18),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),

        itemCount: favorites.length,

        itemBuilder: (context, index) {
          final recipe = favorites[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 16),

            shape: RoundedRectangleBorder(
              borderRadius:
              BorderRadius.circular(18),
            ),

            child: ListTile(
              contentPadding:
              const EdgeInsets.all(16),

              title: Text(
                recipe.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              subtitle: Padding(
                padding:
                const EdgeInsets.only(top: 8),

                child: Text(
                  "${recipe.calories} kcal • "
                      "${recipe.timeMinutes} min",
                ),
              ),

              leading: const Icon(
                Icons.favorite,
                color: Colors.red,
              ),

              trailing: IconButton(
                onPressed: () =>
                    removeFavorite(recipe),

                icon: const Icon(
                  Icons.delete_outline,
                ),
              ),

              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RecipeDetailScreen(
                          recipe: recipe,
                        ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}