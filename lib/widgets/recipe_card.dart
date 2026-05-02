import 'package:flutter/material.dart';
import '../models/recipe.dart';

class RecipeCard extends StatelessWidget {
  final Recipe recipe;
  final VoidCallback onTap;

  const RecipeCard({required this.recipe, required this.onTap, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      margin: EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // 🔥 IMAGEM
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.network(
                "https://source.unsplash.com/600x400/?food",
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.title,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

                  SizedBox(height: 8),

                  Row(
                    children: [
                      Icon(Icons.timer, size: 16),
                      SizedBox(width: 4),
                      Text('${recipe.timeMinutes} min'),

                      SizedBox(width: 16),

                      Icon(Icons.local_fire_department, size: 16),
                      SizedBox(width: 4),
                      Text('${recipe.calories} kcal'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
