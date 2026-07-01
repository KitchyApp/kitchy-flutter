import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import 'dart:ui';

class RecipeCardPremium extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;
  final bool isUnlocked;

  const RecipeCardPremium({
    super.key,
    required this.recipe,
    required this.onTap,
    this.isUnlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          // Card base
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 8,
                  offset: Offset(0, 4),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "${recipe.calories} kcal | P:${recipe.protein} C:${recipe.carbs} F:${recipe.fat}",
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    IconButton(
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: recipe.toShareText()),
                      ),
                      icon: const Icon(
                        Icons.share,
                        color: Color(0xFFFF7043),
                        size: 20,
                      ),
                      tooltip: "Partilhar receita",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 🔒 Blur overlay para premium bloqueadas
          if (recipe.isPremium && !isUnlocked)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock, size: 40, color: Colors.white),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            onTap();
                          },
                          icon: const Icon(Icons.monetization_on),
                          label: const Text("Desbloquear"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}