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

  factory Recipe.fromJson(Map<String, dynamic> json) {
    // _int() coerces any numeric type (int, double, String) to int safely.
    // The OpenAI response occasionally returns numbers as doubles (e.g. 25.0)
    // or even numeric strings. Using a hard cast like `as int` crashes in
    // AOT release mode — num.tryParse + toInt() never does.
    int _int(dynamic v, [int fallback = 0]) {
      if (v == null) return fallback;
      if (v is int) return v;
      if (v is double) return v.toInt();
      return int.tryParse(v.toString()) ?? fallback;
    }

    return Recipe(
      favoriteId: json['id'] is int ? json['id'] as int : null,

      title: (json['title'] as String?) ?? '',

      calories: _int(json['calories']),

      // Backend may send 'protein' OR 'protein_g' depending on endpoint version.
      protein: _int(json['protein'] ?? json['protein_g']),

      // Backend may send 'carbs' OR 'carbs_g'.
      carbs: _int(json['carbs'] ?? json['carbs_g']),

      // Backend may send 'fat' OR 'fat_g'.
      fat: _int(json['fat'] ?? json['fat_g']),

      timeMinutes: _int(json['time_minutes']),

      steps: (json['steps'] as List?)
              ?.map((e) => e?.toString() ?? '')
              .toList() ??
          [],

      optionalIngredients:
          (json['optional_ingredients'] as List?)
                  ?.map((e) => e?.toString() ?? '')
                  .toList() ??
              [],

      vitamins: json['vitamins'] is Map
          ? Map<String, dynamic>.from(json['vitamins'] as Map)
          : null,

      isPremium: json['is_premium'] == true,
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

  // Returns true if [query] (already lowercased) is found in any searchable
  // field of this recipe. Checked in order of relevance:
  //   1. title              — exact recipe name
  //   2. optionalIngredients — explicit ingredient list stored in the favorite
  //   3. steps              — cooking instructions that mention ingredient names
  //
  // An empty query always returns true (show everything).
  bool matchesQuery(String query) {
    if (query.isEmpty) return true;

    if (title.toLowerCase().contains(query)) return true;

    if (optionalIngredients.any(
      (ing) => ing.toLowerCase().contains(query),
    )) return true;

    if (steps.any((step) => step.toLowerCase().contains(query))) return true;

    return false;
  }

  // Formats the recipe as a human-readable share text.
  // Used by both RecipeCardPremium and RecipeDetailScreen via share_plus.
  String toShareText() {
    final numberedSteps = steps
        .asMap()
        .entries
        .map((e) => '${e.key + 1}. ${e.value}')
        .join('\n');

    return '🍽️ $title\n\n'
        '⏱️ $timeMinutes min  •  🔥 $calories kcal\n'
        '💪 P: ${protein}g  |  🌾 C: ${carbs}g  |  🥑 G: ${fat}g\n\n'
        '📋 Modo de Preparo:\n$numberedSteps\n\n'
        'Gerado com Kitchy 🤖';
  }
}
