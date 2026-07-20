import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../main.dart' show appApi, billingService;
import '../models/recipe.dart';
import '../services/favorites_service.dart';
import 'hands_free_screen.dart';
import 'paywall_screen.dart';
class RecipeDetailScreen extends StatefulWidget {
  const RecipeDetailScreen({
    super.key,
    required this.recipe,
  });

  final Recipe recipe;

  @override
  State<RecipeDetailScreen> createState() =>
      _RecipeDetailScreenState();
}

class _RecipeDetailScreenState
    extends State<RecipeDetailScreen> {

  bool isFavorite = false;

  @override
  void initState() {
    super.initState();

    loadFavoriteStatus();
  }

  Future<void> shareRecipe() async {
    final recipe = widget.recipe;

    final text = """
  🍳 ${recipe.title}

   ⏱ Tempo: ${recipe.timeMinutes} min

  🔥 ${recipe.calories} kcal
  💪 Proteína: ${recipe.protein}g
  🍞 Carbs: ${recipe.carbs}g
  🥑 Gordura: ${recipe.fat}g

  📋 Passos:
  ${recipe.steps.map((e) => "- $e").join("\n")}

  Criado com Kitchy 🚀
  """;

    await Share.share(text);
  }

  Future<void> loadFavoriteStatus() async {
    final result =
    await FavoritesService.isFavorite(widget.recipe);

    setState(() {
      isFavorite = result;
    });
  }

  Future<void> toggleFavorite() async {
    if (isFavorite) {
      final favorite =
      await FavoritesService.findFavoriteByTitle(
        widget.recipe.title,
      );

      if (favorite != null &&
          favorite.favoriteId != null) {
        await FavoritesService.removeFavorite(
          favorite.favoriteId!,
        );
      }
    } else {
      await FavoritesService.addFavorite(
        widget.recipe,
      );
    }

    await loadFavoriteStatus();

    setState(() {});
  }

  void _showPremiumVoiceDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.mic, color: Color(0xFFFF7043)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Modo Voz Premium',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Cozinha com as mãos livres usando comandos de voz — '
          '"Seguinte", "Repete" e "Anterior".\n\n'
          'Adere ao Plano Premium para desbloquear o Modo Voz completo.',
          style: TextStyle(height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Agora não'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7043),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PaywallScreen(
                    billingService: billingService,
                  ),
                ),
              );
            },
            child: const Text('Ver Premium ⭐'),
          ),
        ],
      ),
    );
  }

  Future<void> _openHandsFree() async {
    if (widget.recipe.steps.isEmpty) return;

    try {
      final status = await appApi.getUserStatus();
      if (!mounted) return;

      final isPremium =
          status['is_premium'] == true || status['plan'] == 'premium';

      if (!isPremium) {
        _showPremiumVoiceDialog();
        return;
      }
    } catch (_) {
      if (!mounted) return;
      _showPremiumVoiceDialog();
      return;
    }

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HandsFreeScreen(
          recipe: widget.recipe,
          autoStartVoice: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.recipe.steps.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _openHandsFree,
              backgroundColor: const Color(0xFFFF7043),
              elevation: 4,
              icon: const Icon(Icons.mic, color: Colors.white),
              label: const Text(
                'Mãos Livres',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      appBar: AppBar(
        title: Text(widget.recipe.title),

        actions: [
          if (widget.recipe.steps.isNotEmpty)
            IconButton(
              onPressed: _openHandsFree,
              icon: const Icon(Icons.volume_up),
              tooltip: 'Modo Voz',
            ),
          IconButton(
            onPressed: toggleFavorite,
            icon: Icon(
              isFavorite
                  ? Icons.favorite
                  : Icons.favorite_border,
            ),
          ),
          IconButton(
            onPressed: shareRecipe,
            icon: const Icon(Icons.share)
          ),

        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            // TÍTULO
            Text(
              widget.recipe.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // TEMPO
            Row(
              children: [
                const Icon(
                  Icons.timer,
                  color: Colors.orange,
                ),

                const SizedBox(width: 8),

                Text(
                  "${widget.recipe.timeMinutes} minutos",
                ),
              ],
            ),

            const SizedBox(height: 20),

            // MACROS
            Text(
              "🔥 ${widget.recipe.calories} kcal",
            ),

            Text(
              "💪 Proteína: ${widget.recipe.protein}g",
            ),

            Text(
              "🍞 Carbs: ${widget.recipe.carbs}g",
            ),

            Text(
              "🥑 Gordura: ${widget.recipe.fat}g",
            ),

            const SizedBox(height: 30),

            // INGREDIENTES OPCIONAIS
            if (widget.recipe.optionalIngredients.isNotEmpty) ...[
              const SizedBox(height: 20),

              const Text(
                "Ingredientes opcionais",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,

                children: widget.recipe.optionalIngredients
                    .map((ingredient) {
                  return Chip(
                    label: Text(ingredient),
                    backgroundColor:
                    Colors.orange.shade100,
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: 20),

            // PASSOS
            const Text(
              "Passos",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // LISTA DE STEPS
            Expanded(
              child: ListView.builder(
                itemCount: widget.recipe.steps.length,

                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 6,
                    ),

                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange,

                        child: Text(
                          "${index + 1}",
                        ),
                      ),

                      title: Text(
                        widget.recipe.steps[index],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
