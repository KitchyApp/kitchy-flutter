class Recipe {
  final String title;
  final int calories;
  final int protein;
  final int carbs;
  final int fat;
  final int timeMinutes;
  final List<String> steps;
  final bool isPremium;

  Recipe({
    required this.title,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.timeMinutes,
    required this.steps,
    required this.isPremium,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      title: json['title'],
      calories: json['calories'],
      protein: json['protein'],
      carbs: json['carbs'],
      fat: json['fat'],
      timeMinutes: json['time_minutes'],
      steps: List<String>.from(json['steps']),
      isPremium: json['is_premium'],
    );
  }
}