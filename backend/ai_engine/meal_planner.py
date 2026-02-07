import json
from datetime import datetime, timedelta
from typing import Dict, Any

def calculate_bmr(age: int, weight: float, height: float, gender: str = "male") -> float:
    """Calculate Basal Metabolic Rate using Mifflin-St Jeor Equation"""
    if gender.lower() == "male":
        bmr = (10 * weight) + (6.25 * height) - (5 * age) + 5
    else:
        bmr = (10 * weight) + (6.25 * height) - (5 * age) - 161
    return bmr

def calculate_tdee(bmr: float, activity_level: str) -> float:
    """Calculate Total Daily Energy Expenditure"""
    activity_multipliers = {
        "sedentary": 1.2,
        "lightly_active": 1.375,
        "moderately_active": 1.55,
        "very_active": 1.725,
        "extra_active": 1.9
    }
    multiplier = activity_multipliers.get(activity_level.lower(), 1.2)
    return bmr * multiplier

def adjust_calories_for_goal(tdee: float, goal: str) -> float:
    """Adjust calories based on health goals"""
    if "lose" in goal.lower() or "weight loss" in goal.lower():
        return tdee - 500  # 500 calorie deficit
    elif "gain" in goal.lower() or "muscle" in goal.lower():
        return tdee + 300  # 300 calorie surplus
    else:
        return tdee  # Maintenance

def calculate_macros(calories: float, goal: str) -> Dict[str, float]:
    """Calculate macronutrient distribution"""
    if "muscle" in goal.lower() or "gain" in goal.lower():
        protein_ratio = 0.30
        carb_ratio = 0.40
        fat_ratio = 0.30
    elif "lose" in goal.lower():
        protein_ratio = 0.35
        carb_ratio = 0.35
        fat_ratio = 0.30
    else:
        protein_ratio = 0.25
        carb_ratio = 0.45
        fat_ratio = 0.30
    
    return {
        "protein": (calories * protein_ratio) / 4,  # 4 cal per gram
        "carbs": (calories * carb_ratio) / 4,
        "fats": (calories * fat_ratio) / 9  # 9 cal per gram
    }

# Sample meal database (you can expand this or use an API)
MEAL_DATABASE = {
    "breakfast": [
        {"name": "Oatmeal with Berries", "calories": 350, "protein": 12, "carbs": 55, "fats": 8},
        {"name": "Greek Yogurt Parfait", "calories": 300, "protein": 20, "carbs": 35, "fats": 8},
        {"name": "Scrambled Eggs with Toast", "calories": 400, "protein": 25, "carbs": 30, "fats": 18},
        {"name": "Protein Smoothie", "calories": 320, "protein": 28, "carbs": 40, "fats": 6},
    ],
    "lunch": [
        {"name": "Grilled Chicken Salad", "calories": 450, "protein": 40, "carbs": 25, "fats": 20},
        {"name": "Quinoa Buddha Bowl", "calories": 500, "protein": 18, "carbs": 65, "fats": 15},
        {"name": "Turkey Sandwich", "calories": 420, "protein": 30, "carbs": 45, "fats": 12},
        {"name": "Salmon with Vegetables", "calories": 480, "protein": 35, "carbs": 30, "fats": 22},
    ],
    "dinner": [
        {"name": "Grilled Steak with Sweet Potato", "calories": 550, "protein": 45, "carbs": 40, "fats": 20},
        {"name": "Chicken Stir Fry", "calories": 500, "protein": 38, "carbs": 50, "fats": 15},
        {"name": "Baked Fish with Rice", "calories": 480, "protein": 40, "carbs": 45, "fats": 14},
        {"name": "Vegetarian Pasta", "calories": 520, "protein": 20, "carbs": 70, "fats": 16},
    ],
    "snack": [
        {"name": "Apple with Almond Butter", "calories": 200, "protein": 6, "carbs": 20, "fats": 10},
        {"name": "Protein Bar", "calories": 180, "protein": 15, "carbs": 20, "fats": 6},
        {"name": "Mixed Nuts", "calories": 170, "protein": 6, "carbs": 8, "fats": 14},
    ]
}

def generate_meal_plan(user_profile: Dict[str, Any], duration_days: int = 7) -> Dict[str, Any]:
    """Generate AI-powered meal plan based on user profile"""
    
    # Calculate nutritional needs
    bmr = calculate_bmr(
        user_profile.get('age', 30),
        user_profile.get('weight', 70),
        user_profile.get('height', 170)
    )
    
    tdee = calculate_tdee(bmr, user_profile.get('activity_level', 'moderately_active'))
    target_calories = adjust_calories_for_goal(tdee, user_profile.get('health_goals', 'maintain'))
    macros = calculate_macros(target_calories, user_profile.get('health_goals', 'maintain'))
    
    # Generate meal plan
    meal_plan = {
        "nutritional_target": {
            "daily_calories": round(target_calories, 0),
            "protein_g": round(macros['protein'], 1),
            "carbs_g": round(macros['carbs'], 1),
            "fats_g": round(macros['fats'], 1)
        },
        "meals": {}
    }
    
    # Generate meals for each day
    import random
    for day in range(duration_days):
        date_key = (datetime.now() + timedelta(days=day)).strftime("%Y-%m-%d")
        
        daily_meals = {
            "breakfast": random.choice(MEAL_DATABASE["breakfast"]),
            "lunch": random.choice(MEAL_DATABASE["lunch"]),
            "dinner": random.choice(MEAL_DATABASE["dinner"]),
            "snack": random.choice(MEAL_DATABASE["snack"])
        }
        
        meal_plan["meals"][date_key] = daily_meals
    
    return meal_plan