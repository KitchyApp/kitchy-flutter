import 'package:flutter/material.dart';
import '../models/recipe.dart';

class RecipeDetailScreen extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // TÍTULO
            Text(
              recipe.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // TEMPO
            Row(
              children: [
                const Icon(Icons.timer, color: Colors.orange),
                const SizedBox(width: 8),
                Text("${recipe.timeMinutes} minutos"),
              ],
            ),

            const SizedBox(height: 20),

            // MACROS
            Text("🔥 ${recipe.calories} kcal"),
            Text("💪 Proteína: ${recipe.protein}g"),
            Text("🍞 Carbs: ${recipe.carbs}g"),
            Text("🥑 Gordura: ${recipe.fat}g"),

            const SizedBox(height: 30),

            const Text(
              "Passos",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // 🔥 LISTA DE STEPS SCROLLÁVEL
            Expanded(
              child: ListView.builder(
                itemCount: recipe.steps.length,
                itemBuilder: (context, index) {
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Text("${index + 1}"),
                      ),
                      title: Text(recipe.steps[index]),
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