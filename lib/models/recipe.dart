class Recipe {
  final int? favoriteId;

  final String title;

  final int calories;
  final int protein;
  final int carbs;
  final int fat;

  final int timeMinutes;

  final List<String> steps;

  final List<String> optionalIngredients;

  final Map<String, dynamic>? vitamins;

  final bool isPremium;

  Recipe({
    this.favoriteId,
    required this.title,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.timeMinutes,
    required this.steps,
    required this.optionalIngredients,
    required this.vitamins,
    required this.isPremium,
  });

  factory Recipe.fromJson(
      Map<String, dynamic> json,
      ) {
    return Recipe(
      favoriteId: json['id'],

      title: json['title'] ?? '',

      calories: json['calories'] ?? 0,

      protein:
      json['protein'] ??
          json['protein_g'] ??
          0,

      carbs:
      json['carbs'] ??
          json['carbs_g'] ??
          0,

      fat:
      json['fat'] ??
          json['fat_g'] ??
          0,

      timeMinutes:
      json['time_minutes'] ?? 0,

      steps: List<String>.from(
        json['steps'] ?? [],
      ),

      optionalIngredients:
      List<String>.from(
        json['optional_ingredients'] ?? [],
      ),

      vitamins: json['vitamins'],

      isPremium:
      json['is_premium'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'time_minutes': timeMinutes,
      'steps': steps,
      'optional_ingredients':
      optionalIngredients,
      'vitamins': vitamins,
      'is_premium': isPremium,
    };
  }
}
