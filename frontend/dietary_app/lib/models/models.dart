class UserProfile {
  String name;
  String dislikes;
  String preferences;
  String goal;
  int cycleDays;

  UserProfile({
    this.name = '',
    this.dislikes = '',
    this.preferences = '',
    this.goal = '',
    this.cycleDays = 7,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        name: j['name'] ?? '',
        dislikes: j['dislikes'] ?? '',
        preferences: j['preferences'] ?? '',
        goal: j['goal'] ?? '',
        cycleDays: j['cycle_days'] ?? 7,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'dislikes': dislikes,
        'preferences': preferences,
        'goal': goal,
        'cycle_days': cycleDays,
      };
}

class Ingredient {
  int? id;
  String name;
  String category;
  double quantity;
  String unit;

  Ingredient({this.id, required this.name, this.category = 'ingredient', this.quantity = 0, this.unit = ''});

  factory Ingredient.fromJson(Map<String, dynamic> j) => Ingredient(
        id: j['id'],
        name: j['name'] ?? '',
        category: j['category'] ?? 'ingredient',
        quantity: (j['quantity'] ?? 0).toDouble(),
        unit: j['unit'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'quantity': quantity,
        'unit': unit,
      };
}

class Recipe {
  String name;
  List<String> ingredients;
  List<String> steps;
  Map<String, dynamic> nutrition;
  int timeMinutes;
  String? category;
  String? previewImageUrl;

  Recipe({
    required this.name,
    required this.ingredients,
    required this.steps,
    required this.nutrition,
    this.timeMinutes = 0,
    this.category,
    this.previewImageUrl,
  });

  factory Recipe.fromJson(Map<String, dynamic> j) => Recipe(
        name: j['name'] ?? '',
        ingredients: List<String>.from(j['ingredients'] ?? []),
        steps: List<String>.from(j['steps'] ?? []),
        nutrition: Map<String, dynamic>.from(j['nutrition'] ?? {}),
        timeMinutes: j['time_minutes'] ?? 0,
        category: j['category'],
        previewImageUrl: j['preview_image_url'],
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'ingredients': ingredients,
        'steps': steps,
        'nutrition': nutrition,
        'time_minutes': timeMinutes,
        if (category != null) 'category': category,
        if (previewImageUrl != null) 'preview_image_url': previewImageUrl,
      };
}

class RecipeStep {
  String step;
  String resultDescription;
  String resultImagePrompt;
  String processDescription;
  String processImagePrompt;
  String? resultImageUrl;
  String? processImageUrl;

  RecipeStep({
    required this.step,
    this.resultDescription = '',
    this.resultImagePrompt = '',
    this.processDescription = '',
    this.processImagePrompt = '',
    this.resultImageUrl,
    this.processImageUrl,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> j) => RecipeStep(
        step: j['step'] ?? '',
        resultDescription: j['result_description'] ?? '',
        resultImagePrompt: j['result_image_prompt'] ?? '',
        processDescription: j['process_description'] ?? '',
        processImagePrompt: j['process_image_prompt'] ?? '',
        resultImageUrl: j['result_image_url'],
        processImageUrl: j['process_image_url'],
      );
}

class NutritionLog {
  int? id;
  String date;
  String mealType;
  String recipeName;
  double calories;
  double protein;
  double carbs;
  double fat;
  double fiber;

  NutritionLog({
    this.id,
    required this.date,
    this.mealType = 'lunch',
    this.recipeName = '',
    this.calories = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
  });

  factory NutritionLog.fromJson(Map<String, dynamic> j) => NutritionLog(
        id: j['id'],
        date: j['date'] ?? '',
        mealType: j['meal_type'] ?? 'lunch',
        recipeName: j['recipe_name'] ?? '',
        calories: (j['calories'] ?? 0).toDouble(),
        protein: (j['protein'] ?? 0).toDouble(),
        carbs: (j['carbs'] ?? 0).toDouble(),
        fat: (j['fat'] ?? 0).toDouble(),
        fiber: (j['fiber'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'meal_type': mealType,
        'recipe_name': recipeName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
      };
}
