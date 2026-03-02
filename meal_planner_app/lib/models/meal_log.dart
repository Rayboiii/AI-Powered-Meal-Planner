class MealLog {
  final int? logId;
  final String mealDate;
  final String mealType;
  final String foodItems;
  final double calories;
  final double? protein;
  final double? carbs;
  final double? fats;
  
  MealLog({
    this.logId,
    required this.mealDate,
    required this.mealType,
    required this.foodItems,
    required this.calories,
    this.protein,
    this.carbs,
    this.fats,
  });
  
  factory MealLog.fromJson(Map<String, dynamic> json) {
    return MealLog(
      logId: json['log_id'],
      mealDate: json['meal_date'],
      mealType: json['meal_type'],
      foodItems: json['food_items'],
      calories: json['calories'].toDouble(),
      protein: json['protein']?.toDouble(),
      carbs: json['carbs']?.toDouble(),
      fats: json['fats']?.toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'meal_date': mealDate,
      'meal_type': mealType,
      'food_items': foodItems,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fats': fats,
    };
  }
}