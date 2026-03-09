class UserProfile {
  final String? name;
  final int? age;
  final double? weight;
  final double? height;
  final String? gender;
  final String? dietaryPreferences;
  final String? allergies;
  final String? healthGoals;
  final String? activityLevel;

  // Computed daily nutritional targets — returned by the backend profile endpoint
  final int? dailyCalorieTarget;
  final int? dailyCalorieTargetMin;
  final int? dailyCalorieTargetMax;
  final double? dailyProteinTarget;
  final double? dailyCarbsTarget;
  final double? dailyFatsTarget;

  UserProfile({
    this.name,
    this.age,
    this.weight,
    this.height,
    this.gender,
    this.dietaryPreferences,
    this.allergies,
    this.healthGoals,
    this.activityLevel,
    this.dailyCalorieTarget,
    this.dailyCalorieTargetMin,
    this.dailyCalorieTargetMax,
    this.dailyProteinTarget,
    this.dailyCarbsTarget,
    this.dailyFatsTarget,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'],
      age: json['age'],
      weight: json['weight']?.toDouble(),
      height: json['height']?.toDouble(),
      gender: json['gender'],
      dietaryPreferences: json['dietary_preferences'],
      allergies: json['allergies'],
      healthGoals: json['health_goals'],
      activityLevel: json['activity_level'],
      dailyCalorieTarget:    json['daily_calorie_target'],
      dailyCalorieTargetMin: json['daily_calorie_target_min'],
      dailyCalorieTargetMax: json['daily_calorie_target_max'],
      dailyProteinTarget: json['daily_protein_target']?.toDouble(),
      dailyCarbsTarget:   json['daily_carbs_target']?.toDouble(),
      dailyFatsTarget:    json['daily_fats_target']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'age': age,
      'weight': weight,
      'height': height,
      'gender': gender,
      'dietary_preferences': dietaryPreferences,
      'allergies': allergies,
      'health_goals': healthGoals,
      'activity_level': activityLevel,
      // Target fields are computed by backend — not sent on PUT
    };
  }

  bool get isComplete {
    return weight != null &&
        height != null &&
        activityLevel != null &&
        healthGoals != null;
  }
}
