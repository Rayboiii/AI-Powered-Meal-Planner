class MealPlan {
  final int planId;
  final int? userId;  // Make nullable
  final String createdAt;
  final String startDate;
  final String endDate;
  final Map<String, dynamic> planData;
  
  MealPlan({
    required this.planId,
    this.userId,  // No longer required
    required this.createdAt,
    required this.startDate,
    required this.endDate,
    required this.planData,
  });
  
  factory MealPlan.fromJson(Map<String, dynamic> json) {
    return MealPlan(
      planId: json['plan_id'] as int,
      userId: json['user_id'] as int?,  // Safe cast
      createdAt: json['created_at'] as String,
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      planData: json['plan_data'] as Map<String, dynamic>,
    );
  }
  
  static const _mealOrder = ['breakfast', 'lunch', 'dinner', 'snack'];

  Map<String, List<Meal>> get mealsByDate {
    final Map<String, List<Meal>> result = {};
    final meals = planData['meals'] as Map<String, dynamic>?;

    if (meals == null) return result;

    meals.forEach((date, dayMeals) {
      final dayMealsList = <Meal>[];
      if (dayMeals is Map<String, dynamic>) {
        dayMeals.forEach((mealType, mealData) {
          if (mealData is Map<String, dynamic>) {
            dayMealsList.add(Meal.fromJson(mealType, mealData));
          }
        });
      }
      dayMealsList.sort((a, b) {
        final ai = _mealOrder.indexOf(a.type.toLowerCase());
        final bi = _mealOrder.indexOf(b.type.toLowerCase());
        return (ai == -1 ? 99 : ai).compareTo(bi == -1 ? 99 : bi);
      });
      result[date] = dayMealsList;
    });

    return result;
  }
  
  Map<String, dynamic> get nutritionalTarget {
    return planData['nutritional_target'] as Map<String, dynamic>? ?? {};
  }
}

class Meal {
  final String type;
  final String name;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final String? serving;

  Meal({
    required this.type,
    required this.name,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.serving,
  });

  factory Meal.fromJson(String type, Map<String, dynamic> json) {
    return Meal(
      type: type,
      name: json['name'] as String? ?? 'Unknown',
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0.0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0.0,
      fats: (json['fats'] as num?)?.toDouble() ?? 0.0,
      serving: json['serving'] as String?,
    );
  }
}