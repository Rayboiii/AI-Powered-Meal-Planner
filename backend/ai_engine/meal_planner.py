"""
AI Meal Planner Engine
======================
Generates personalised, nutrition-aware meal plans based on a user's
body metrics, health goal, activity level, dietary preferences, and allergens.

Improvements over the original version:
  1. Expanded meal database – 50+ diverse meals across 4 categories,
     each tagged with dietary style and allergen information.
  2. Dietary preference filtering – vegetarian, vegan, keto, gluten-free,
     dairy-free, high-protein, low-carb, etc.
  3. Allergen exclusion – nuts, dairy, gluten, eggs, fish, shellfish, soy.
  4. Variety enforcement – a sliding 3-day window prevents the same meal
     from repeating within consecutive days.
  5. Calorie-aware selection – each meal is scored against its expected
     share of the daily calorie target (breakfast 25 %, lunch 35 %,
     dinner 30 %, snack 10 %).
  6. Macro alignment scoring – meals are chosen to reflect the user's
     target protein / carb / fat ratio.
  7. Graceful fallback – if no meals survive strict filtering, the engine
     relaxes to allergen-safe meals, then to all meals, so the plan never
     comes back empty.
  8. Ingredients & serving sizes – every meal entry includes a list of
     ingredients with standardised amounts, a serving size in grams, and a
     human-readable serving unit so portion guidance is always realistic.
  9. Calorie range – a ±5 % (min 100 kcal) window around the daily target
     is exposed so the UI can display a range instead of a single number.
"""

import random
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional, Set


# ─────────────────────────────────────────────────────────────────────────────
# Nutrition Calculations
# ─────────────────────────────────────────────────────────────────────────────

def calculate_bmr(age: int, weight: float, height: float,
                  gender: str = "male") -> float:
    """
    Basal Metabolic Rate via the Mifflin-St Jeor Equation.

    Args:
        age:    Years.
        weight: Kilograms.
        height: Centimetres.
        gender: 'male' (default) or 'female'.

    Returns:
        BMR in kcal/day.
    """
    base = (10 * weight) + (6.25 * height) - (5 * age)
    return base + 5 if gender.lower() != "female" else base - 161


def calculate_tdee(bmr: float, activity_level: str) -> float:
    """
    Total Daily Energy Expenditure = BMR × activity multiplier.

    Args:
        bmr:            Result of calculate_bmr().
        activity_level: One of sedentary / lightly_active /
                        moderately_active / very_active / extra_active.

    Returns:
        TDEE in kcal/day.
    """
    multipliers = {
        "sedentary":        1.200,
        "lightly_active":   1.375,
        "moderately_active":1.550,
        "very_active":      1.725,
        "extra_active":     1.900,
    }
    return bmr * multipliers.get(activity_level.lower(), 1.2)


def adjust_calories_for_goal(tdee: float, goal: str) -> float:
    """
    Shift the daily calorie target up or down based on the user's goal.

    - Lose weight  → −500 kcal deficit (≈ 0.45 kg/week loss)
    - Gain / Muscle→ +300 kcal surplus
    - Maintain     → TDEE unchanged
    """
    goal_lower = goal.lower()
    if "lose" in goal_lower:
        return tdee - 500
    if "gain" in goal_lower or "muscle" in goal_lower:
        return tdee + 300
    return tdee


def calorie_range(target: float) -> Dict[str, int]:
    """
    Return a realistic daily calorie range around the given target.

    Uses a ±5 % margin (minimum ±100 kcal) so that users are guided
    toward a healthy zone rather than a single rigid number.

    Returns:
        Dict with 'min', 'target', and 'max' keys (all integers).
    """
    margin = max(100, round(target * 0.05))
    return {
        "min":    round(target - margin),
        "target": round(target),
        "max":    round(target + margin),
    }


def calculate_macros(calories: float, goal: str) -> Dict[str, float]:
    """
    Daily macro targets in grams, derived from calorie target and goal.

    Macro split by goal:
        Muscle/Gain  → 30 % protein · 40 % carbs · 30 % fat
        Lose weight  → 35 % protein · 35 % carbs · 30 % fat
        Maintain     → 25 % protein · 45 % carbs · 30 % fat

    Returns:
        Dict with keys 'protein', 'carbs', 'fats' (all in grams).
    """
    goal_lower = goal.lower()
    if "muscle" in goal_lower or "gain" in goal_lower:
        p, c, f = 0.30, 0.40, 0.30
    elif "lose" in goal_lower:
        p, c, f = 0.35, 0.35, 0.30
    else:
        p, c, f = 0.25, 0.45, 0.30

    return {
        "protein": round((calories * p) / 4, 1),   # 4 kcal per gram
        "carbs":   round((calories * c) / 4, 1),
        "fats":    round((calories * f) / 9, 1),   # 9 kcal per gram
    }


# ─────────────────────────────────────────────────────────────────────────────
# Expanded Meal Database
# ─────────────────────────────────────────────────────────────────────────────
# Each meal entry:
#   name           – display name
#   calories       – kcal per 1 serving
#   protein        – grams per serving
#   carbs          – grams per serving
#   fats           – grams per serving
#   tags           – dietary-style flags (used for preference matching)
#   allergens      – common allergens present in this meal
#   serving_size_g – weight of one serving in grams (used for scaling)
#   serving_unit   – human-readable unit (e.g. "bowl", "plate", "wrap")
#   ingredients    – list of {name, amount, unit} dicts, standardised:
#                    solids → grams, liquids → ml, countable → pieces
# ─────────────────────────────────────────────────────────────────────────────

MEAL_DATABASE: Dict[str, List[Dict]] = {

    "breakfast": [
        {
            "name": "Oatmeal with Mixed Berries",
            "calories": 350, "protein": 12, "carbs": 55, "fats":  8,
            "tags": ["vegetarian", "vegan", "high-carb"],
            "allergens": ["gluten"],
            "serving_size_g": 380, "serving_unit": "bowl",
            "ingredients": [
                {"name": "rolled oats",   "amount": 80,  "unit": "g"},
                {"name": "mixed berries", "amount": 100, "unit": "g"},
                {"name": "almond milk",   "amount": 200, "unit": "ml"},
                {"name": "honey",         "amount": 15,  "unit": "g"},
            ],
        },
        {
            "name": "Greek Yogurt Parfait",
            "calories": 300, "protein": 20, "carbs": 35, "fats":  8,
            "tags": ["vegetarian", "high-protein"],
            "allergens": ["dairy"],
            "serving_size_g": 260, "serving_unit": "cup",
            "ingredients": [
                {"name": "Greek yogurt",  "amount": 150, "unit": "g"},
                {"name": "granola",       "amount": 40,  "unit": "g"},
                {"name": "mixed berries", "amount": 60,  "unit": "g"},
                {"name": "honey",         "amount": 10,  "unit": "g"},
            ],
        },
        {
            "name": "Scrambled Eggs with Toast",
            "calories": 400, "protein": 25, "carbs": 30, "fats": 18,
            "tags": ["vegetarian", "high-protein"],
            "allergens": ["eggs", "gluten", "dairy"],
            "serving_size_g": 280, "serving_unit": "plate",
            "ingredients": [
                {"name": "eggs",              "amount": 3,  "unit": "pieces"},
                {"name": "whole-grain bread", "amount": 70, "unit": "g"},
                {"name": "butter",            "amount": 10, "unit": "g"},
                {"name": "milk",              "amount": 30, "unit": "ml"},
            ],
        },
        {
            "name": "Protein Smoothie",
            "calories": 320, "protein": 28, "carbs": 40, "fats":  6,
            "tags": ["vegetarian", "vegan", "high-protein", "dairy-free"],
            "allergens": [],
            "serving_size_g": 400, "serving_unit": "glass",
            "ingredients": [
                {"name": "banana",          "amount": 120, "unit": "g"},
                {"name": "protein powder",  "amount": 30,  "unit": "g"},
                {"name": "almond milk",     "amount": 250, "unit": "ml"},
                {"name": "peanut butter",   "amount": 20,  "unit": "g"},
            ],
        },
        {
            "name": "Avocado Toast with Poached Eggs",
            "calories": 390, "protein": 18, "carbs": 32, "fats": 24,
            "tags": ["vegetarian", "high-fat"],
            "allergens": ["gluten", "eggs"],
            "serving_size_g": 280, "serving_unit": "plate",
            "ingredients": [
                {"name": "whole-grain bread", "amount": 70, "unit": "g"},
                {"name": "avocado",           "amount": 80, "unit": "g"},
                {"name": "eggs",              "amount": 2,  "unit": "pieces"},
                {"name": "lemon juice",       "amount": 5,  "unit": "ml"},
                {"name": "chili flakes",      "amount": 1,  "unit": "g"},
            ],
        },
        {
            "name": "Banana Pancakes",
            "calories": 420, "protein": 12, "carbs": 68, "fats": 10,
            "tags": ["vegetarian", "high-carb"],
            "allergens": ["gluten", "eggs", "dairy"],
            "serving_size_g": 350, "serving_unit": "plate (3 pancakes)",
            "ingredients": [
                {"name": "banana",      "amount": 120, "unit": "g"},
                {"name": "oat flour",   "amount": 80,  "unit": "g"},
                {"name": "eggs",        "amount": 2,   "unit": "pieces"},
                {"name": "milk",        "amount": 60,  "unit": "ml"},
                {"name": "maple syrup", "amount": 20,  "unit": "g"},
            ],
        },
        {
            "name": "Chia Seed Pudding",
            "calories": 280, "protein": 10, "carbs": 34, "fats": 13,
            "tags": ["vegetarian", "vegan", "dairy-free", "gluten-free"],
            "allergens": [],
            "serving_size_g": 250, "serving_unit": "jar",
            "ingredients": [
                {"name": "chia seeds",    "amount": 30,  "unit": "g"},
                {"name": "coconut milk",  "amount": 200, "unit": "ml"},
                {"name": "honey",         "amount": 15,  "unit": "g"},
                {"name": "vanilla extract","amount": 2,  "unit": "ml"},
            ],
        },
        {
            "name": "Veggie Omelette",
            "calories": 340, "protein": 22, "carbs": 12, "fats": 22,
            "tags": ["vegetarian", "keto", "low-carb", "gluten-free"],
            "allergens": ["eggs", "dairy"],
            "serving_size_g": 280, "serving_unit": "plate",
            "ingredients": [
                {"name": "eggs",        "amount": 3,  "unit": "pieces"},
                {"name": "bell pepper", "amount": 60, "unit": "g"},
                {"name": "spinach",     "amount": 30, "unit": "g"},
                {"name": "cheese",      "amount": 20, "unit": "g"},
                {"name": "olive oil",   "amount": 5,  "unit": "ml"},
            ],
        },
        {
            "name": "Peanut Butter Banana Toast",
            "calories": 360, "protein": 14, "carbs": 48, "fats": 13,
            "tags": ["vegetarian", "vegan"],
            "allergens": ["gluten", "nuts"],
            "serving_size_g": 230, "serving_unit": "plate",
            "ingredients": [
                {"name": "whole-grain bread", "amount": 70, "unit": "g"},
                {"name": "peanut butter",     "amount": 30, "unit": "g"},
                {"name": "banana",            "amount": 120,"unit": "g"},
                {"name": "honey",             "amount": 10, "unit": "g"},
            ],
        },
        {
            "name": "Rice Porridge with Soft-Boiled Egg",
            "calories": 300, "protein": 16, "carbs": 42, "fats":  7,
            "tags": ["gluten-free", "dairy-free"],
            "allergens": ["eggs"],
            "serving_size_g": 350, "serving_unit": "bowl",
            "ingredients": [
                {"name": "white rice", "amount": 80,  "unit": "g"},
                {"name": "water",      "amount": 400, "unit": "ml"},
                {"name": "egg",        "amount": 1,   "unit": "piece"},
                {"name": "soy sauce",  "amount": 10,  "unit": "ml"},
                {"name": "ginger",     "amount": 5,   "unit": "g"},
            ],
        },
        {
            "name": "Tofu Scramble with Spinach",
            "calories": 310, "protein": 20, "carbs": 18, "fats": 16,
            "tags": ["vegetarian", "vegan", "dairy-free", "gluten-free"],
            "allergens": ["soy"],
            "serving_size_g": 330, "serving_unit": "plate",
            "ingredients": [
                {"name": "firm tofu",  "amount": 200, "unit": "g"},
                {"name": "spinach",    "amount": 80,  "unit": "g"},
                {"name": "onion",      "amount": 40,  "unit": "g"},
                {"name": "olive oil",  "amount": 10,  "unit": "ml"},
                {"name": "turmeric",   "amount": 2,   "unit": "g"},
                {"name": "soy sauce",  "amount": 10,  "unit": "ml"},
            ],
        },
        {
            "name": "Overnight Oats with Banana",
            "calories": 370, "protein": 14, "carbs": 58, "fats":  9,
            "tags": ["vegetarian", "vegan", "high-carb"],
            "allergens": ["gluten"],
            "serving_size_g": 420, "serving_unit": "jar",
            "ingredients": [
                {"name": "rolled oats", "amount": 80,  "unit": "g"},
                {"name": "milk",        "amount": 200, "unit": "ml"},
                {"name": "banana",      "amount": 120, "unit": "g"},
                {"name": "chia seeds",  "amount": 10,  "unit": "g"},
                {"name": "honey",       "amount": 15,  "unit": "g"},
            ],
        },
        {
            "name": "Egg White Omelette",
            "calories": 250, "protein": 28, "carbs":  8, "fats":  8,
            "tags": ["vegetarian", "high-protein", "low-fat", "keto", "gluten-free"],
            "allergens": ["eggs"],
            "serving_size_g": 290, "serving_unit": "plate",
            "ingredients": [
                {"name": "egg whites", "amount": 200, "unit": "g"},
                {"name": "spinach",    "amount": 50,  "unit": "g"},
                {"name": "tomato",     "amount": 60,  "unit": "g"},
                {"name": "olive oil",  "amount": 5,   "unit": "ml"},
            ],
        },
        {
            "name": "Whole Grain Cereal with Milk",
            "calories": 290, "protein": 11, "carbs": 50, "fats":  5,
            "tags": ["vegetarian", "high-carb"],
            "allergens": ["gluten", "dairy"],
            "serving_size_g": 370, "serving_unit": "bowl",
            "ingredients": [
                {"name": "whole grain cereal", "amount": 60,  "unit": "g"},
                {"name": "low-fat milk",       "amount": 250, "unit": "ml"},
                {"name": "banana",             "amount": 60,  "unit": "g"},
            ],
        },
    ],

    "lunch": [
        {
            "name": "Grilled Chicken Salad",
            "calories": 450, "protein": 40, "carbs": 25, "fats": 20,
            "tags": ["high-protein", "low-carb", "gluten-free"],
            "allergens": [],
            "serving_size_g": 400, "serving_unit": "bowl",
            "ingredients": [
                {"name": "chicken breast",  "amount": 150, "unit": "g"},
                {"name": "mixed greens",    "amount": 80,  "unit": "g"},
                {"name": "cherry tomatoes", "amount": 80,  "unit": "g"},
                {"name": "cucumber",        "amount": 60,  "unit": "g"},
                {"name": "olive oil",       "amount": 15,  "unit": "ml"},
                {"name": "lemon juice",     "amount": 10,  "unit": "ml"},
            ],
        },
        {
            "name": "Quinoa Buddha Bowl",
            "calories": 500, "protein": 18, "carbs": 65, "fats": 15,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": [],
            "serving_size_g": 430, "serving_unit": "bowl",
            "ingredients": [
                {"name": "quinoa",         "amount": 100, "unit": "g"},
                {"name": "chickpeas",      "amount": 80,  "unit": "g"},
                {"name": "sweet potato",   "amount": 100, "unit": "g"},
                {"name": "avocado",        "amount": 60,  "unit": "g"},
                {"name": "tahini",         "amount": 20,  "unit": "g"},
                {"name": "lemon juice",    "amount": 10,  "unit": "ml"},
            ],
        },
        {
            "name": "Turkey Sandwich",
            "calories": 420, "protein": 30, "carbs": 45, "fats": 12,
            "tags": ["high-protein"],
            "allergens": ["gluten"],
            "serving_size_g": 280, "serving_unit": "sandwich",
            "ingredients": [
                {"name": "whole-grain bread", "amount": 70,  "unit": "g"},
                {"name": "turkey breast",     "amount": 100, "unit": "g"},
                {"name": "lettuce",           "amount": 20,  "unit": "g"},
                {"name": "tomato",            "amount": 40,  "unit": "g"},
                {"name": "mustard",           "amount": 10,  "unit": "g"},
            ],
        },
        {
            "name": "Salmon with Roasted Vegetables",
            "calories": 480, "protein": 35, "carbs": 30, "fats": 22,
            "tags": ["high-protein", "gluten-free"],
            "allergens": ["fish"],
            "serving_size_g": 360, "serving_unit": "plate",
            "ingredients": [
                {"name": "salmon fillet", "amount": 150, "unit": "g"},
                {"name": "broccoli",      "amount": 100, "unit": "g"},
                {"name": "carrot",        "amount": 80,  "unit": "g"},
                {"name": "olive oil",     "amount": 15,  "unit": "ml"},
                {"name": "lemon juice",   "amount": 10,  "unit": "ml"},
                {"name": "garlic",        "amount": 5,   "unit": "g"},
            ],
        },
        {
            "name": "Lentil Soup with Bread",
            "calories": 430, "protein": 22, "carbs": 60, "fats":  8,
            "tags": ["vegetarian", "vegan", "high-carb"],
            "allergens": ["gluten"],
            "serving_size_g": 450, "serving_unit": "bowl + bread",
            "ingredients": [
                {"name": "red lentils",      "amount": 100, "unit": "g"},
                {"name": "carrot",           "amount": 60,  "unit": "g"},
                {"name": "onion",            "amount": 40,  "unit": "g"},
                {"name": "garlic",           "amount": 5,   "unit": "g"},
                {"name": "cumin",            "amount": 2,   "unit": "g"},
                {"name": "whole-grain bread","amount": 35,  "unit": "g"},
            ],
        },
        {
            "name": "Chicken Caesar Wrap",
            "calories": 510, "protein": 35, "carbs": 40, "fats": 22,
            "tags": ["high-protein"],
            "allergens": ["gluten", "dairy", "eggs"],
            "serving_size_g": 340, "serving_unit": "wrap",
            "ingredients": [
                {"name": "flour tortilla",   "amount": 60,  "unit": "g"},
                {"name": "chicken breast",   "amount": 150, "unit": "g"},
                {"name": "romaine lettuce",  "amount": 60,  "unit": "g"},
                {"name": "Caesar dressing",  "amount": 30,  "unit": "g"},
                {"name": "Parmesan cheese",  "amount": 15,  "unit": "g"},
            ],
        },
        {
            "name": "Tuna Salad Sandwich",
            "calories": 400, "protein": 32, "carbs": 36, "fats": 14,
            "tags": ["high-protein"],
            "allergens": ["fish", "gluten", "eggs"],
            "serving_size_g": 270, "serving_unit": "sandwich",
            "ingredients": [
                {"name": "whole-grain bread", "amount": 70,  "unit": "g"},
                {"name": "canned tuna",       "amount": 100, "unit": "g"},
                {"name": "mayonnaise",        "amount": 20,  "unit": "g"},
                {"name": "celery",            "amount": 30,  "unit": "g"},
                {"name": "onion",             "amount": 20,  "unit": "g"},
            ],
        },
        {
            "name": "Chickpea and Veggie Stir Fry",
            "calories": 440, "protein": 18, "carbs": 58, "fats": 12,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": [],
            "serving_size_g": 380, "serving_unit": "plate",
            "ingredients": [
                {"name": "chickpeas",   "amount": 150, "unit": "g"},
                {"name": "bell pepper", "amount": 80,  "unit": "g"},
                {"name": "zucchini",    "amount": 80,  "unit": "g"},
                {"name": "onion",       "amount": 40,  "unit": "g"},
                {"name": "olive oil",   "amount": 15,  "unit": "ml"},
                {"name": "cumin",       "amount": 2,   "unit": "g"},
            ],
        },
        {
            "name": "Brown Rice Tofu Bowl",
            "calories": 450, "protein": 22, "carbs": 60, "fats": 12,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": ["soy"],
            "serving_size_g": 400, "serving_unit": "bowl",
            "ingredients": [
                {"name": "brown rice",   "amount": 100, "unit": "g"},
                {"name": "firm tofu",    "amount": 150, "unit": "g"},
                {"name": "edamame",      "amount": 60,  "unit": "g"},
                {"name": "soy sauce",    "amount": 15,  "unit": "ml"},
                {"name": "sesame oil",   "amount": 5,   "unit": "ml"},
                {"name": "ginger",       "amount": 5,   "unit": "g"},
            ],
        },
        {
            "name": "Greek Salad with Feta",
            "calories": 380, "protein": 14, "carbs": 22, "fats": 26,
            "tags": ["vegetarian", "gluten-free", "low-carb"],
            "allergens": ["dairy"],
            "serving_size_g": 370, "serving_unit": "bowl",
            "ingredients": [
                {"name": "cucumber",       "amount": 100, "unit": "g"},
                {"name": "tomato",         "amount": 100, "unit": "g"},
                {"name": "red onion",      "amount": 30,  "unit": "g"},
                {"name": "Kalamata olives","amount": 40,  "unit": "g"},
                {"name": "feta cheese",    "amount": 60,  "unit": "g"},
                {"name": "olive oil",      "amount": 20,  "unit": "ml"},
            ],
        },
        {
            "name": "Bean and Veggie Burrito",
            "calories": 490, "protein": 20, "carbs": 68, "fats": 14,
            "tags": ["vegetarian", "vegan", "high-carb"],
            "allergens": ["gluten"],
            "serving_size_g": 380, "serving_unit": "burrito",
            "ingredients": [
                {"name": "flour tortilla", "amount": 60,  "unit": "g"},
                {"name": "black beans",    "amount": 120, "unit": "g"},
                {"name": "cooked rice",    "amount": 60,  "unit": "g"},
                {"name": "bell pepper",    "amount": 60,  "unit": "g"},
                {"name": "salsa",          "amount": 40,  "unit": "g"},
                {"name": "sour cream",     "amount": 20,  "unit": "g"},
            ],
        },
        {
            "name": "Shrimp Fried Rice",
            "calories": 470, "protein": 28, "carbs": 58, "fats": 12,
            "tags": ["high-protein", "gluten-free"],
            "allergens": ["shellfish", "soy", "eggs"],
            "serving_size_g": 420, "serving_unit": "plate",
            "ingredients": [
                {"name": "cooked rice", "amount": 150, "unit": "g"},
                {"name": "shrimp",      "amount": 120, "unit": "g"},
                {"name": "egg",         "amount": 1,   "unit": "piece"},
                {"name": "carrot",      "amount": 40,  "unit": "g"},
                {"name": "peas",        "amount": 40,  "unit": "g"},
                {"name": "soy sauce",   "amount": 15,  "unit": "ml"},
                {"name": "sesame oil",  "amount": 5,   "unit": "ml"},
            ],
        },
        {
            "name": "Caprese Salad with Grilled Chicken",
            "calories": 420, "protein": 38, "carbs": 14, "fats": 22,
            "tags": ["high-protein", "gluten-free", "low-carb"],
            "allergens": ["dairy"],
            "serving_size_g": 370, "serving_unit": "plate",
            "ingredients": [
                {"name": "chicken breast",    "amount": 150, "unit": "g"},
                {"name": "fresh mozzarella",  "amount": 60,  "unit": "g"},
                {"name": "tomato",            "amount": 120, "unit": "g"},
                {"name": "basil",             "amount": 10,  "unit": "g"},
                {"name": "olive oil",         "amount": 15,  "unit": "ml"},
                {"name": "balsamic glaze",    "amount": 10,  "unit": "ml"},
            ],
        },
        {
            "name": "Spinach and Cheese Quesadilla",
            "calories": 440, "protein": 22, "carbs": 46, "fats": 18,
            "tags": ["vegetarian"],
            "allergens": ["gluten", "dairy"],
            "serving_size_g": 300, "serving_unit": "quesadilla (2 halves)",
            "ingredients": [
                {"name": "flour tortilla",    "amount": 120, "unit": "g"},
                {"name": "mozzarella cheese", "amount": 60,  "unit": "g"},
                {"name": "spinach",           "amount": 60,  "unit": "g"},
                {"name": "bell pepper",       "amount": 40,  "unit": "g"},
                {"name": "olive oil",         "amount": 5,   "unit": "ml"},
            ],
        },
    ],

    "dinner": [
        {
            "name": "Grilled Steak with Sweet Potato",
            "calories": 550, "protein": 45, "carbs": 40, "fats": 20,
            "tags": ["high-protein", "gluten-free"],
            "allergens": [],
            "serving_size_g": 370, "serving_unit": "plate",
            "ingredients": [
                {"name": "sirloin steak",  "amount": 200, "unit": "g"},
                {"name": "sweet potato",   "amount": 150, "unit": "g"},
                {"name": "olive oil",      "amount": 10,  "unit": "ml"},
                {"name": "rosemary",       "amount": 2,   "unit": "g"},
                {"name": "garlic",         "amount": 5,   "unit": "g"},
            ],
        },
        {
            "name": "Chicken Stir Fry with Noodles",
            "calories": 500, "protein": 38, "carbs": 50, "fats": 15,
            "tags": ["high-protein"],
            "allergens": ["soy", "gluten"],
            "serving_size_g": 420, "serving_unit": "plate",
            "ingredients": [
                {"name": "chicken breast", "amount": 150, "unit": "g"},
                {"name": "egg noodles",    "amount": 100, "unit": "g"},
                {"name": "broccoli",       "amount": 80,  "unit": "g"},
                {"name": "carrot",         "amount": 60,  "unit": "g"},
                {"name": "soy sauce",      "amount": 20,  "unit": "ml"},
                {"name": "sesame oil",     "amount": 5,   "unit": "ml"},
            ],
        },
        {
            "name": "Baked Fish with Brown Rice",
            "calories": 480, "protein": 40, "carbs": 45, "fats": 14,
            "tags": ["high-protein", "gluten-free"],
            "allergens": ["fish"],
            "serving_size_g": 380, "serving_unit": "plate",
            "ingredients": [
                {"name": "white fish fillet", "amount": 200, "unit": "g"},
                {"name": "brown rice",        "amount": 100, "unit": "g"},
                {"name": "lemon",             "amount": 20,  "unit": "g"},
                {"name": "olive oil",         "amount": 10,  "unit": "ml"},
                {"name": "mixed herbs",       "amount": 5,   "unit": "g"},
            ],
        },
        {
            "name": "Vegetarian Pasta Primavera",
            "calories": 520, "protein": 20, "carbs": 70, "fats": 16,
            "tags": ["vegetarian", "high-carb"],
            "allergens": ["gluten", "dairy"],
            "serving_size_g": 400, "serving_unit": "plate",
            "ingredients": [
                {"name": "pasta",           "amount": 100, "unit": "g"},
                {"name": "zucchini",        "amount": 80,  "unit": "g"},
                {"name": "cherry tomatoes", "amount": 80,  "unit": "g"},
                {"name": "bell pepper",     "amount": 60,  "unit": "g"},
                {"name": "olive oil",       "amount": 20,  "unit": "ml"},
                {"name": "Parmesan cheese", "amount": 20,  "unit": "g"},
            ],
        },
        {
            "name": "Beef and Broccoli",
            "calories": 530, "protein": 42, "carbs": 30, "fats": 24,
            "tags": ["high-protein", "low-carb"],
            "allergens": ["soy", "gluten"],
            "serving_size_g": 410, "serving_unit": "plate",
            "ingredients": [
                {"name": "beef strips",  "amount": 200, "unit": "g"},
                {"name": "broccoli",     "amount": 150, "unit": "g"},
                {"name": "soy sauce",    "amount": 20,  "unit": "ml"},
                {"name": "oyster sauce", "amount": 15,  "unit": "ml"},
                {"name": "garlic",       "amount": 5,   "unit": "g"},
                {"name": "cornstarch",   "amount": 10,  "unit": "g"},
            ],
        },
        {
            "name": "Baked Salmon with Asparagus",
            "calories": 490, "protein": 42, "carbs": 18, "fats": 26,
            "tags": ["high-protein", "keto", "low-carb", "gluten-free"],
            "allergens": ["fish"],
            "serving_size_g": 395, "serving_unit": "plate",
            "ingredients": [
                {"name": "salmon fillet", "amount": 200, "unit": "g"},
                {"name": "asparagus",     "amount": 150, "unit": "g"},
                {"name": "olive oil",     "amount": 15,  "unit": "ml"},
                {"name": "lemon",         "amount": 20,  "unit": "g"},
                {"name": "garlic",        "amount": 5,   "unit": "g"},
                {"name": "dill",          "amount": 5,   "unit": "g"},
            ],
        },
        {
            "name": "Lentil Dal with Basmati Rice",
            "calories": 480, "protein": 22, "carbs": 68, "fats":  9,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": [],
            "serving_size_g": 450, "serving_unit": "plate",
            "ingredients": [
                {"name": "red lentils",  "amount": 120, "unit": "g"},
                {"name": "basmati rice", "amount": 100, "unit": "g"},
                {"name": "onion",        "amount": 60,  "unit": "g"},
                {"name": "tomato",       "amount": 80,  "unit": "g"},
                {"name": "cumin",        "amount": 3,   "unit": "g"},
                {"name": "turmeric",     "amount": 2,   "unit": "g"},
                {"name": "coconut oil",  "amount": 10,  "unit": "ml"},
            ],
        },
        {
            "name": "Chicken Tikka Masala with Rice",
            "calories": 540, "protein": 40, "carbs": 38, "fats": 22,
            "tags": ["high-protein", "gluten-free"],
            "allergens": ["dairy"],
            "serving_size_g": 500, "serving_unit": "plate",
            "ingredients": [
                {"name": "chicken thigh",         "amount": 200, "unit": "g"},
                {"name": "basmati rice",           "amount": 100, "unit": "g"},
                {"name": "tomato sauce",           "amount": 120, "unit": "g"},
                {"name": "heavy cream",            "amount": 40,  "unit": "ml"},
                {"name": "onion",                  "amount": 60,  "unit": "g"},
                {"name": "tikka masala spice mix", "amount": 10,  "unit": "g"},
            ],
        },
        {
            "name": "Pork Tenderloin with Roasted Veg",
            "calories": 500, "protein": 44, "carbs": 22, "fats": 24,
            "tags": ["high-protein", "gluten-free"],
            "allergens": [],
            "serving_size_g": 410, "serving_unit": "plate",
            "ingredients": [
                {"name": "pork tenderloin", "amount": 200, "unit": "g"},
                {"name": "broccoli",        "amount": 100, "unit": "g"},
                {"name": "carrot",          "amount": 80,  "unit": "g"},
                {"name": "olive oil",       "amount": 15,  "unit": "ml"},
                {"name": "garlic",          "amount": 5,   "unit": "g"},
                {"name": "thyme",           "amount": 2,   "unit": "g"},
            ],
        },
        {
            "name": "Vegan Buddha Bowl",
            "calories": 460, "protein": 18, "carbs": 62, "fats": 14,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": [],
            "serving_size_g": 420, "serving_unit": "bowl",
            "ingredients": [
                {"name": "quinoa",          "amount": 80,  "unit": "g"},
                {"name": "roasted chickpeas","amount": 80, "unit": "g"},
                {"name": "avocado",         "amount": 80,  "unit": "g"},
                {"name": "spinach",         "amount": 60,  "unit": "g"},
                {"name": "cherry tomatoes", "amount": 60,  "unit": "g"},
                {"name": "tahini",          "amount": 20,  "unit": "g"},
                {"name": "lemon juice",     "amount": 10,  "unit": "ml"},
            ],
        },
        {
            "name": "Shrimp Pasta Aglio e Olio",
            "calories": 520, "protein": 30, "carbs": 60, "fats": 16,
            "tags": ["high-protein"],
            "allergens": ["shellfish", "gluten"],
            "serving_size_g": 400, "serving_unit": "plate",
            "ingredients": [
                {"name": "spaghetti",    "amount": 100, "unit": "g"},
                {"name": "shrimp",       "amount": 150, "unit": "g"},
                {"name": "olive oil",    "amount": 25,  "unit": "ml"},
                {"name": "garlic",       "amount": 10,  "unit": "g"},
                {"name": "chili flakes", "amount": 2,   "unit": "g"},
                {"name": "parsley",      "amount": 10,  "unit": "g"},
            ],
        },
        {
            "name": "Stuffed Bell Peppers with Quinoa",
            "calories": 470, "protein": 28, "carbs": 48, "fats": 16,
            "tags": ["gluten-free"],
            "allergens": ["dairy"],
            "serving_size_g": 500, "serving_unit": "2 stuffed peppers",
            "ingredients": [
                {"name": "bell peppers",   "amount": 240, "unit": "g"},
                {"name": "quinoa",         "amount": 80,  "unit": "g"},
                {"name": "ground beef",    "amount": 100, "unit": "g"},
                {"name": "tomato sauce",   "amount": 80,  "unit": "g"},
                {"name": "cheese",         "amount": 30,  "unit": "g"},
            ],
        },
        {
            "name": "Turkey Meatballs with Zucchini Noodles",
            "calories": 430, "protein": 38, "carbs": 18, "fats": 20,
            "tags": ["high-protein", "low-carb", "gluten-free"],
            "allergens": ["eggs"],
            "serving_size_g": 520, "serving_unit": "plate",
            "ingredients": [
                {"name": "ground turkey", "amount": 200, "unit": "g"},
                {"name": "zucchini",      "amount": 200, "unit": "g"},
                {"name": "egg",           "amount": 1,   "unit": "piece"},
                {"name": "tomato sauce",  "amount": 100, "unit": "g"},
                {"name": "Parmesan",      "amount": 15,  "unit": "g"},
                {"name": "garlic",        "amount": 5,   "unit": "g"},
            ],
        },
        {
            "name": "Black Bean Tacos",
            "calories": 490, "protein": 20, "carbs": 62, "fats": 16,
            "tags": ["vegetarian", "vegan", "high-carb"],
            "allergens": ["gluten"],
            "serving_size_g": 360, "serving_unit": "3 tacos",
            "ingredients": [
                {"name": "corn tortillas", "amount": 90,  "unit": "g"},
                {"name": "black beans",    "amount": 120, "unit": "g"},
                {"name": "avocado",        "amount": 80,  "unit": "g"},
                {"name": "salsa",          "amount": 40,  "unit": "g"},
                {"name": "lime juice",     "amount": 10,  "unit": "ml"},
                {"name": "cilantro",       "amount": 10,  "unit": "g"},
            ],
        },
    ],

    "snack": [
        {
            "name": "Apple with Almond Butter",
            "calories": 200, "protein":  6, "carbs": 22, "fats": 10,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": ["nuts"],
            "serving_size_g": 210, "serving_unit": "serving",
            "ingredients": [
                {"name": "apple",         "amount": 1,  "unit": "medium (180g)"},
                {"name": "almond butter", "amount": 30, "unit": "g"},
            ],
        },
        {
            "name": "Protein Bar",
            "calories": 200, "protein": 20, "carbs": 22, "fats":  7,
            "tags": ["high-protein"],
            "allergens": ["gluten", "dairy", "nuts"],
            "serving_size_g": 60, "serving_unit": "bar",
            "ingredients": [
                {"name": "protein bar", "amount": 1, "unit": "bar (60g)"},
            ],
        },
        {
            "name": "Mixed Nuts",
            "calories": 170, "protein":  6, "carbs":  8, "fats": 14,
            "tags": ["vegetarian", "vegan", "keto", "gluten-free"],
            "allergens": ["nuts"],
            "serving_size_g": 40, "serving_unit": "handful",
            "ingredients": [
                {"name": "mixed nuts (almonds, walnuts, cashews)", "amount": 40, "unit": "g"},
            ],
        },
        {
            "name": "Greek Yogurt with Honey",
            "calories": 160, "protein": 14, "carbs": 20, "fats":  3,
            "tags": ["vegetarian", "high-protein", "gluten-free"],
            "allergens": ["dairy"],
            "serving_size_g": 165, "serving_unit": "cup",
            "ingredients": [
                {"name": "Greek yogurt", "amount": 150, "unit": "g"},
                {"name": "honey",        "amount": 15,  "unit": "g"},
            ],
        },
        {
            "name": "Hummus with Carrot Sticks",
            "calories": 150, "protein":  6, "carbs": 18, "fats":  6,
            "tags": ["vegetarian", "vegan", "gluten-free", "dairy-free"],
            "allergens": [],
            "serving_size_g": 200, "serving_unit": "serving",
            "ingredients": [
                {"name": "hummus",  "amount": 80,  "unit": "g"},
                {"name": "carrots", "amount": 120, "unit": "g"},
            ],
        },
        {
            "name": "Boiled Eggs",
            "calories": 140, "protein": 12, "carbs":  1, "fats":  9,
            "tags": ["vegetarian", "keto", "gluten-free", "high-protein", "dairy-free"],
            "allergens": ["eggs"],
            "serving_size_g": 100, "serving_unit": "2 eggs",
            "ingredients": [
                {"name": "eggs", "amount": 2, "unit": "pieces"},
            ],
        },
        {
            "name": "Edamame",
            "calories": 150, "protein": 12, "carbs": 12, "fats":  5,
            "tags": ["vegetarian", "vegan", "gluten-free", "dairy-free"],
            "allergens": ["soy"],
            "serving_size_g": 150, "serving_unit": "bowl",
            "ingredients": [
                {"name": "edamame (shelled)", "amount": 150, "unit": "g"},
            ],
        },
        {
            "name": "Rice Cakes with Avocado",
            "calories": 160, "protein":  3, "carbs": 20, "fats":  7,
            "tags": ["vegetarian", "vegan", "gluten-free", "dairy-free"],
            "allergens": [],
            "serving_size_g": 120, "serving_unit": "serving",
            "ingredients": [
                {"name": "rice cakes", "amount": 30, "unit": "g"},
                {"name": "avocado",    "amount": 80, "unit": "g"},
                {"name": "lemon juice","amount": 5,  "unit": "ml"},
            ],
        },
        {
            "name": "Cottage Cheese with Pineapple",
            "calories": 180, "protein": 16, "carbs": 18, "fats":  4,
            "tags": ["vegetarian", "high-protein", "gluten-free"],
            "allergens": ["dairy"],
            "serving_size_g": 230, "serving_unit": "bowl",
            "ingredients": [
                {"name": "cottage cheese",    "amount": 150, "unit": "g"},
                {"name": "pineapple chunks",  "amount": 80,  "unit": "g"},
            ],
        },
        {
            "name": "Banana with Peanut Butter",
            "calories": 190, "protein":  6, "carbs": 28, "fats":  7,
            "tags": ["vegetarian", "vegan", "gluten-free", "dairy-free"],
            "allergens": ["nuts"],
            "serving_size_g": 150, "serving_unit": "serving",
            "ingredients": [
                {"name": "banana",        "amount": 1,  "unit": "medium (120g)"},
                {"name": "peanut butter", "amount": 30, "unit": "g"},
            ],
        },
    ],
}


# ─────────────────────────────────────────────────────────────────────────────
# Cooking Instructions
# ─────────────────────────────────────────────────────────────────────────────
# Step-by-step cooking instructions for every meal in MEAL_DATABASE.
# Stored separately so the database entries stay concise.
# ─────────────────────────────────────────────────────────────────────────────

MEAL_INSTRUCTIONS: Dict[str, List[str]] = {

    # ── Breakfast ─────────────────────────────────────────────────────────────
    "Oatmeal with Mixed Berries": [
        "Bring almond milk to a simmer in a saucepan over medium heat.",
        "Stir in rolled oats and cook for 5 minutes, stirring occasionally, until creamy.",
        "Remove from heat, pour into a bowl, and top with mixed berries.",
        "Drizzle with honey and serve warm.",
    ],
    "Greek Yogurt Parfait": [
        "Spoon Greek yogurt into a glass or bowl as the base layer.",
        "Add a layer of granola for crunch.",
        "Top with mixed berries and drizzle with honey.",
        "Serve immediately to keep the granola crispy.",
    ],
    "Scrambled Eggs with Toast": [
        "Crack eggs into a bowl, add milk and a pinch of salt, and whisk until combined.",
        "Melt butter in a non-stick pan over low-medium heat.",
        "Pour in the egg mixture and gently stir with a spatula until soft curds form. Remove from heat while still slightly underdone.",
        "Toast the bread and serve alongside the scrambled eggs.",
    ],
    "Protein Smoothie": [
        "Add almond milk, protein powder, and peanut butter to a blender.",
        "Add the banana (fresh or frozen) and blend on high for 60 seconds until smooth.",
        "Pour into a glass and serve immediately.",
    ],
    "Avocado Toast with Poached Eggs": [
        "Bring a small pot of water to a gentle simmer and add a splash of vinegar.",
        "Crack each egg into a cup, then slide into the simmering water. Poach for 3 minutes.",
        "Toast the bread until golden. Mash the avocado with lemon juice and a pinch of salt.",
        "Spread the avocado on the toast, top with poached eggs, and finish with chili flakes.",
    ],
    "Banana Pancakes": [
        "Mash the banana in a bowl until smooth. Mix in eggs, milk, and oat flour to form a batter.",
        "Heat a lightly oiled non-stick pan over medium heat.",
        "Pour small rounds of batter (about 3 tbsp each) into the pan. Cook 2 minutes until bubbles form, then flip and cook 1 minute more.",
        "Stack the pancakes and drizzle with maple syrup before serving.",
    ],
    "Chia Seed Pudding": [
        "Combine chia seeds, coconut milk, honey, and vanilla extract in a jar. Stir well.",
        "Let sit for 5 minutes, stir again to prevent clumping, then seal the jar.",
        "Refrigerate for at least 4 hours or overnight until thick and pudding-like.",
        "Stir before serving and add your favourite toppings.",
    ],
    "Veggie Omelette": [
        "Dice bell pepper and wilt spinach briefly in a pan over medium heat. Set aside.",
        "Whisk eggs with a pinch of salt. Heat olive oil in the same pan over medium heat.",
        "Pour in the eggs and let the edges set. Add the veggies and cheese on one half.",
        "Fold the omelette in half and cook for 1 more minute until set. Slide onto a plate.",
    ],
    "Peanut Butter Banana Toast": [
        "Toast the whole-grain bread to your preferred level of crispness.",
        "Spread peanut butter evenly over each slice.",
        "Slice the banana and layer on top of the peanut butter.",
        "Drizzle with honey and serve.",
    ],
    "Rice Porridge with Soft-Boiled Egg": [
        "Rinse rice and place in a pot with water and ginger. Bring to a boil.",
        "Reduce heat and simmer for 20-25 minutes, stirring occasionally, until the porridge is thick and creamy.",
        "Meanwhile, bring a small pot of water to a boil. Gently lower the egg in and cook for 7 minutes for a jammy yolk.",
        "Transfer the egg to ice water for 1 minute, then peel. Serve the porridge topped with the halved egg and a drizzle of soy sauce.",
    ],
    "Tofu Scramble with Spinach": [
        "Press the tofu with paper towels to remove excess moisture, then crumble into chunks.",
        "Heat olive oil in a pan over medium heat. Add onion and cook for 3 minutes until softened.",
        "Add crumbled tofu, turmeric, and soy sauce. Cook for 5 minutes, stirring frequently.",
        "Stir in spinach and cook for 2 more minutes until wilted. Season to taste and serve.",
    ],
    "Overnight Oats with Banana": [
        "Combine rolled oats, milk, chia seeds, and honey in a jar. Stir well.",
        "Seal the jar and refrigerate overnight (or for at least 6 hours).",
        "In the morning, stir and check consistency, adding more milk if needed.",
        "Top with sliced banana before serving.",
    ],
    "Egg White Omelette": [
        "Dice the tomato and wilt spinach in a pan over medium heat. Set aside.",
        "Whisk egg whites with a pinch of salt until slightly frothy.",
        "Heat olive oil in the same pan over medium heat. Pour in the egg whites and let the edges set.",
        "Add the tomato and spinach, fold the omelette in half, and cook for 30 more seconds. Serve.",
    ],
    "Whole Grain Cereal with Milk": [
        "Pour the cereal into a bowl.",
        "Add cold milk.",
        "Slice the banana on top and serve immediately.",
    ],

    # ── Lunch ─────────────────────────────────────────────────────────────────
    "Grilled Chicken Salad": [
        "Season chicken breast with salt, pepper, and a drizzle of olive oil.",
        "Grill over medium-high heat for 6-7 minutes per side until cooked through. Let rest 5 minutes, then slice.",
        "Combine mixed greens, cherry tomatoes, and cucumber in a bowl.",
        "Top with sliced chicken, drizzle with olive oil and lemon juice, and toss to combine.",
    ],
    "Quinoa Buddha Bowl": [
        "Rinse quinoa and cook in 2× water over medium heat for 15 minutes until fluffy.",
        "Dice sweet potato and toss with chickpeas in olive oil. Roast at 200°C for 25 minutes.",
        "Slice avocado. Whisk tahini with lemon juice and a splash of water to make a dressing.",
        "Assemble: quinoa base, roasted sweet potato and chickpeas, avocado, and tahini dressing.",
    ],
    "Turkey Sandwich": [
        "Lay the bread slices flat and spread mustard on one side of each.",
        "Layer turkey breast, lettuce, and tomato slices on one slice.",
        "Close the sandwich, cut diagonally, and serve.",
    ],
    "Salmon with Roasted Vegetables": [
        "Preheat oven to 200°C. Chop broccoli and carrot into bite-sized pieces.",
        "Toss vegetables with olive oil, minced garlic, salt, and pepper. Roast for 20 minutes.",
        "Season salmon with lemon juice, salt, and pepper. Pan-sear in a hot pan for 4 minutes per side until cooked through.",
        "Serve salmon over the roasted vegetables.",
    ],
    "Lentil Soup with Bread": [
        "Dice onion and carrot. Sauté in a pot with a little oil over medium heat for 5 minutes.",
        "Add minced garlic and cumin, cook for 1 minute. Add rinsed lentils and enough water to cover by 5 cm.",
        "Bring to a boil then simmer for 20-25 minutes until lentils are soft. Season to taste.",
        "Blend half the soup for a creamy texture, then stir back in. Serve with whole-grain bread.",
    ],
    "Chicken Caesar Wrap": [
        "Season and grill chicken breast for 6-7 minutes per side. Let rest, then slice.",
        "Lay the flour tortilla flat and spread Caesar dressing across the centre.",
        "Layer romaine lettuce, sliced chicken, and Parmesan cheese.",
        "Roll the tortilla tightly, folding in the sides. Cut in half and serve.",
    ],
    "Tuna Salad Sandwich": [
        "Drain the canned tuna and place in a bowl.",
        "Add diced celery, onion, and mayonnaise. Mix well and season with salt and pepper.",
        "Spread the tuna mixture over a slice of whole-grain bread.",
        "Top with the second slice, press gently, and cut in half.",
    ],
    "Chickpea and Veggie Stir Fry": [
        "Drain and rinse chickpeas. Dice bell pepper and zucchini.",
        "Heat olive oil in a wok over high heat. Add onion and cook for 2 minutes.",
        "Add bell pepper and zucchini. Stir fry for 4 minutes until tender-crisp.",
        "Add chickpeas and cumin. Toss for 2 more minutes, season to taste, and serve.",
    ],
    "Brown Rice Tofu Bowl": [
        "Cook brown rice according to package instructions.",
        "Press tofu with paper towels and cut into cubes. Pan-fry in sesame oil over medium-high heat for 5 minutes per side until golden.",
        "Add soy sauce and grated ginger to the pan. Toss tofu to coat.",
        "Assemble: brown rice topped with tofu, edamame, and a drizzle of remaining sauce.",
    ],
    "Greek Salad with Feta": [
        "Chop cucumber, tomato, and red onion into chunks.",
        "Combine vegetables in a bowl with Kalamata olives.",
        "Crumble feta cheese on top.",
        "Drizzle with olive oil and season with salt, pepper, and dried oregano.",
    ],
    "Bean and Veggie Burrito": [
        "Warm the flour tortilla in a dry pan for 30 seconds per side.",
        "Heat black beans in a pan with a pinch of cumin and salt. Mash lightly.",
        "Layer cooked rice, beans, diced bell pepper, salsa, and sour cream down the centre of the tortilla.",
        "Fold in the sides and roll tightly. Slice in half and serve.",
    ],
    "Shrimp Fried Rice": [
        "Cook rice ahead of time and let it cool (day-old rice works best).",
        "Heat sesame oil in a wok over high heat. Add shrimp and cook for 2 minutes per side until pink. Remove.",
        "Add carrot and peas to the wok. Push to one side and scramble the egg on the other.",
        "Add rice and soy sauce, toss everything together. Return shrimp and stir fry for 1 more minute.",
    ],
    "Caprese Salad with Grilled Chicken": [
        "Season chicken breast with salt, pepper, and olive oil. Grill for 6-7 minutes per side.",
        "Slice tomato and fresh mozzarella. Alternate slices on a plate.",
        "Slice the rested chicken and arrange alongside the caprese.",
        "Scatter basil leaves, then drizzle with olive oil and balsamic glaze.",
    ],
    "Spinach and Cheese Quesadilla": [
        "Lay a flour tortilla flat in a pan over medium heat.",
        "Scatter shredded mozzarella, fresh spinach, and diced bell pepper over one half.",
        "Fold the tortilla over to cover the filling and press gently.",
        "Cook for 2-3 minutes per side until golden and the cheese has melted. Slice into wedges.",
    ],

    # ── Dinner ────────────────────────────────────────────────────────────────
    "Grilled Steak with Sweet Potato": [
        "Pierce sweet potato all over and microwave for 5 minutes, or roast at 200°C for 45 minutes.",
        "Season steak with salt, pepper, rosemary, and minced garlic. Let rest 15 minutes at room temperature.",
        "Grill or pan-sear steak over high heat for 3-4 minutes per side for medium-rare. Rest 5 minutes before slicing.",
        "Serve steak alongside the sweet potato with a drizzle of olive oil.",
    ],
    "Chicken Stir Fry with Noodles": [
        "Cook egg noodles according to package instructions. Drain and set aside.",
        "Slice chicken breast thinly. Stir fry in a hot wok with a little oil for 5 minutes until cooked.",
        "Add broccoli and carrot. Stir fry for 3 more minutes.",
        "Add drained noodles, soy sauce, and sesame oil. Toss over high heat for 2 minutes and serve.",
    ],
    "Baked Fish with Brown Rice": [
        "Preheat oven to 200°C. Cook brown rice according to package instructions.",
        "Place fish fillet on a lined baking tray. Drizzle with olive oil and lemon juice. Season with mixed herbs, salt, and pepper.",
        "Bake for 15-18 minutes until the fish flakes easily with a fork.",
        "Serve fish on a bed of brown rice with extra lemon on the side.",
    ],
    "Vegetarian Pasta Primavera": [
        "Cook pasta according to package instructions until al dente. Reserve ½ cup pasta water before draining.",
        "Slice zucchini, cherry tomatoes, and bell pepper. Sauté in olive oil over medium-high heat for 5-6 minutes.",
        "Add drained pasta to the pan with a splash of pasta water and toss to combine.",
        "Plate and top with freshly grated Parmesan cheese.",
    ],
    "Beef and Broccoli": [
        "Slice beef thinly and toss with cornstarch and half the soy sauce. Marinate for 10 minutes.",
        "Cut broccoli into florets and blanch in boiling water for 2 minutes. Drain.",
        "Stir fry beef in a hot wok until browned, about 3 minutes. Remove and set aside.",
        "Stir fry broccoli with minced garlic for 2 minutes. Return beef and add remaining soy sauce and oyster sauce. Toss and serve.",
    ],
    "Baked Salmon with Asparagus": [
        "Preheat oven to 200°C. Line a baking tray with parchment paper.",
        "Place salmon fillet and asparagus spears on the tray. Drizzle with olive oil.",
        "Season with minced garlic, dill, salt, pepper, and lemon slices on top.",
        "Bake for 15-18 minutes until salmon is cooked through and asparagus is tender.",
    ],
    "Lentil Dal with Basmati Rice": [
        "Rinse lentils. Cook basmati rice according to package instructions.",
        "Sauté diced onion in coconut oil for 5 minutes. Add tomato, cumin, and turmeric. Cook 3 more minutes.",
        "Add lentils and water to cover. Simmer for 20-25 minutes until soft and the dal is thick.",
        "Season with salt and serve over basmati rice.",
    ],
    "Chicken Tikka Masala with Rice": [
        "Cut chicken thigh into cubes. Marinate in half the tikka masala spice mix with a splash of yogurt for at least 15 minutes.",
        "Cook basmati rice according to package instructions.",
        "Sauté diced onion in oil for 5 minutes. Add remaining spice mix and cook for 1 minute.",
        "Add marinated chicken and cook for 5 minutes. Stir in tomato sauce, simmer 10 minutes. Stir in heavy cream, season, and serve over rice.",
    ],
    "Pork Tenderloin with Roasted Veg": [
        "Preheat oven to 200°C. Chop broccoli and carrot. Toss with olive oil, garlic, thyme, salt, and pepper.",
        "Season pork tenderloin with salt, pepper, and thyme. Sear in an oven-proof pan over high heat for 2 minutes per side.",
        "Transfer pan to the oven. Add the vegetables around the pork. Roast for 20-25 minutes until pork reaches 63°C internally.",
        "Rest for 5 minutes before slicing. Serve with the roasted vegetables.",
    ],
    "Vegan Buddha Bowl": [
        "Preheat oven to 200°C. Toss chickpeas with oil and salt. Roast for 25 minutes until crispy.",
        "Cook quinoa: combine with 2× water, bring to a boil, reduce and simmer for 15 minutes.",
        "Halve cherry tomatoes and slice avocado. Whisk tahini with lemon juice and water for the dressing.",
        "Assemble: quinoa base, roasted chickpeas, fresh spinach, cherry tomatoes, and avocado. Drizzle with tahini dressing.",
    ],
    "Shrimp Pasta Aglio e Olio": [
        "Cook spaghetti in well-salted boiling water until al dente. Reserve 1 cup pasta water before draining.",
        "Thinly slice garlic. Heat olive oil in a large pan over medium heat. Add garlic and chili flakes. Cook 2 minutes until golden.",
        "Add shrimp to the pan and cook for 2-3 minutes until pink. Season with salt.",
        "Add drained pasta and a splash of pasta water. Toss to coat, scatter parsley on top, and serve.",
    ],
    "Stuffed Bell Peppers with Quinoa": [
        "Preheat oven to 190°C. Cook quinoa in 2× water for 15 minutes. Brown ground beef in a pan.",
        "Mix cooked quinoa, ground beef, and tomato sauce together. Season generously.",
        "Cut the tops off bell peppers and remove the seeds. Spoon the filling into each pepper.",
        "Place in a baking dish, top with shredded cheese, and bake for 30-35 minutes until peppers are tender.",
    ],
    "Turkey Meatballs with Zucchini Noodles": [
        "Preheat oven to 200°C. Combine ground turkey, egg, minced garlic, and Parmesan. Form into golf ball-sized meatballs.",
        "Bake meatballs for 20 minutes until cooked through.",
        "Spiralize zucchini into noodles. Heat tomato sauce in a pan and add the baked meatballs. Simmer for 5 minutes.",
        "Sauté zucchini noodles in a little oil for 2 minutes. Plate the noodles and spoon meatballs and sauce on top.",
    ],
    "Black Bean Tacos": [
        "Warm corn tortillas directly over a gas flame or in a dry pan for 30 seconds per side.",
        "Heat black beans in a pan with a pinch of cumin, salt, and lime juice for 3 minutes.",
        "Mash avocado with lime juice and a pinch of salt.",
        "Assemble tacos: beans, mashed avocado, salsa, and fresh cilantro. Serve with lime wedges.",
    ],

    # ── Snack ─────────────────────────────────────────────────────────────────
    "Apple with Almond Butter": [
        "Core and slice the apple into wedges.",
        "Portion almond butter into a small bowl.",
        "Dip apple slices into almond butter and enjoy.",
    ],
    "Protein Bar": [
        "Unwrap and enjoy as a convenient on-the-go snack.",
    ],
    "Mixed Nuts": [
        "Measure out a 40 g handful of mixed nuts.",
        "Enjoy as is, or lightly toast in a dry pan for 2 minutes for extra flavour.",
    ],
    "Greek Yogurt with Honey": [
        "Spoon Greek yogurt into a bowl.",
        "Drizzle honey over the top and serve.",
    ],
    "Hummus with Carrot Sticks": [
        "Peel and cut carrots into sticks.",
        "Spoon hummus into a small bowl.",
        "Serve carrot sticks alongside the hummus for dipping.",
    ],
    "Boiled Eggs": [
        "Place eggs in a small pot, cover with cold water, and bring to a boil.",
        "Reduce heat and simmer for 7 minutes for a jammy yolk, or 10 minutes for hard-boiled.",
        "Transfer to ice water for 1 minute to stop cooking, then peel and serve with a pinch of salt.",
    ],
    "Edamame": [
        "Bring a pot of salted water to a boil.",
        "Add edamame and cook for 5 minutes until tender.",
        "Drain and serve warm with a sprinkle of sea salt.",
    ],
    "Rice Cakes with Avocado": [
        "Mash the avocado in a bowl with lemon juice, salt, and pepper.",
        "Spread the mashed avocado generously over each rice cake.",
        "Serve immediately.",
    ],
    "Cottage Cheese with Pineapple": [
        "Spoon cottage cheese into a bowl.",
        "Top with pineapple chunks and serve chilled.",
    ],
    "Banana with Peanut Butter": [
        "Peel and slice the banana.",
        "Portion peanut butter into a small bowl.",
        "Dip banana slices into peanut butter and enjoy.",
    ],
}


# ─────────────────────────────────────────────────────────────────────────────
# Dietary Preference & Allergen Helpers
# ─────────────────────────────────────────────────────────────────────────────

# Map common user-supplied strings to internal tag names
_PREFERENCE_TAG_MAP: Dict[str, str] = {
    "vegetarian":   "vegetarian",
    "vegan":        "vegan",
    "keto":         "keto",
    "gluten-free":  "gluten-free",
    "gluten free":  "gluten-free",
    "dairy-free":   "dairy-free",
    "dairy free":   "dairy-free",
    "high-protein": "high-protein",
    "high protein": "high-protein",
    "low-carb":     "low-carb",
    "low carb":     "low-carb",
}


def _parse_csv(value: str) -> List[str]:
    """Split a comma/semicolon-separated string into a normalised list."""
    if not value or value.strip().lower() in ("none", "n/a", ""):
        return []
    return [token.strip().lower()
            for token in value.replace(";", ",").split(",")
            if token.strip()]


def _meal_matches_preferences(meal: Dict, preferences: List[str]) -> bool:
    """
    Return True if the meal satisfies every requested dietary style.

    Only tags that are present in the internal TAG_MAP are checked; unknown
    tokens are ignored so unexpected user input never breaks filtering.
    """
    meal_tags = meal.get("tags", [])
    for pref in preferences:
        tag = _PREFERENCE_TAG_MAP.get(pref)
        if tag and tag not in meal_tags:
            return False
    return True


def _meal_is_safe(meal: Dict, allergens: List[str]) -> bool:
    """Return True if the meal contains none of the user's allergens."""
    meal_allergens = {a.lower() for a in meal.get("allergens", [])}
    return not any(a in meal_allergens for a in allergens)


def _filter_meals(candidates: List[Dict],
                  preferences: List[str],
                  allergens: List[str]) -> List[Dict]:
    """
    Filter meal candidates applying two levels of strictness.

    Level 1 (strict)  – must match ALL preferences AND be allergen-safe.
    Level 2 (relaxed) – allergen-safe only (drop preference requirement).
    Fallback          – return all candidates (edge case: allergen not in DB).

    This ensures the plan is never empty even for unusual filter combinations.
    """
    strict = [m for m in candidates
              if _meal_matches_preferences(m, preferences)
              and _meal_is_safe(m, allergens)]
    if strict:
        return strict

    safe_only = [m for m in candidates if _meal_is_safe(m, allergens)]
    if safe_only:
        return safe_only

    return candidates   # last resort


# ─────────────────────────────────────────────────────────────────────────────
# Smart Meal Scoring & Selection
# ─────────────────────────────────────────────────────────────────────────────

# Ideal calorie share per meal type (must sum to 1.0)
_MEAL_CAL_SPLIT: Dict[str, float] = {
    "breakfast": 0.25,
    "lunch":     0.35,
    "dinner":    0.30,
    "snack":     0.10,
}


def _score_meal(meal: Dict,
                meal_type: str,
                daily_calorie_target: float,
                daily_macros: Dict[str, float],
                recently_used: Set[str]) -> float:
    """
    Score a candidate meal on three weighted criteria (higher = better).

    Calorie proximity (40 %)
        How close the meal's calories are to the expected allocation for
        this meal type (e.g., 25 % of daily target for breakfast).
        Score of 1.0 = perfect match; falls towards 0 as deviation grows.

    Macro alignment (40 %)
        How well the meal's protein/carb/fat calorie ratio mirrors the
        user's daily macro target ratios.
        Score of 1.0 = perfect ratio match; 0 = completely misaligned.

    Variety (20 %)
        1.0 if the meal has NOT been used in the recent tracking window,
        0.0 if it has (penalises repetition).
    """
    # ── 1. Calorie proximity ─────────────────────────────────────────────
    ideal = daily_calorie_target * _MEAL_CAL_SPLIT.get(meal_type, 0.25)
    calorie_score = max(0.0, 1.0 - abs(meal["calories"] - ideal) / max(ideal, 1))

    # ── 2. Macro alignment ───────────────────────────────────────────────
    total_macro_cal = (
        daily_macros["protein"] * 4
        + daily_macros["carbs"]   * 4
        + daily_macros["fats"]    * 9
    )
    if total_macro_cal == 0:
        macro_score = 0.5
    else:
        meal_cal = max(meal["calories"], 1)
        # Target ratios (fraction of total macro calories)
        tp = (daily_macros["protein"] * 4) / total_macro_cal
        tc = (daily_macros["carbs"]   * 4) / total_macro_cal
        tf = (daily_macros["fats"]    * 9) / total_macro_cal
        # Meal's own macro calorie ratios
        mp = (meal["protein"] * 4) / meal_cal
        mc = (meal["carbs"]   * 4) / meal_cal
        mf = (meal["fats"]    * 9) / meal_cal
        # Total absolute deviation across three macros, normalised to [0, 1]
        deviation = (abs(mp - tp) + abs(mc - tc) + abs(mf - tf)) / 2
        macro_score = max(0.0, 1.0 - deviation)

    # ── 3. Variety ───────────────────────────────────────────────────────
    variety_score = 0.0 if meal["name"] in recently_used else 1.0

    return (calorie_score * 0.40) + (macro_score * 0.40) + (variety_score * 0.20)


def _select_meal(meal_type: str,
                 candidates: List[Dict],
                 daily_calorie_target: float,
                 daily_macros: Dict[str, float],
                 recently_used: Set[str]) -> Dict:
    """
    Score all candidates and return one using weighted-random selection
    among the top 3.  The best-scored meal is three times as likely to be
    chosen as the third-best, adding natural variety while still
    preferring nutritionally optimal options.
    """
    scored = sorted(
        candidates,
        key=lambda m: _score_meal(
            m, meal_type, daily_calorie_target, daily_macros, recently_used
        ),
        reverse=True,
    )
    top = scored[:3]
    weights = [3, 2, 1][: len(top)]
    return random.choices(top, weights=weights, k=1)[0]


# ─────────────────────────────────────────────────────────────────────────────
# Plan Generation
# ─────────────────────────────────────────────────────────────────────────────

def generate_meal_plan(user_profile: Dict[str, Any],
                       duration_days: int = 7,
                       start_date: Optional[date] = None) -> Dict[str, Any]:
    """
    Generate a personalised nutrition-aware meal plan.

    Args:
        user_profile:  Dict from the user_profiles DB row.
                       Expected keys: age, weight, height, activity_level,
                       health_goals, dietary_preferences, allergies.
        duration_days: Length of the plan (1–30 days).
        start_date:    First day of the plan (defaults to today).

    Returns:
        {
          "nutritional_target": { daily_calories, calories_min, calories_max,
                                  protein_g, carbs_g, fats_g },
          "meals": { "YYYY-MM-DD": { breakfast, lunch, dinner, snack } },
          "dietary_filters_applied": [...],
          "allergens_excluded": [...],
        }
    """
    if start_date is None:
        start_date = datetime.now().date()

    # ── Nutritional targets ───────────────────────────────────────────────
    bmr = calculate_bmr(
        age=int(user_profile.get("age", 30)),
        weight=float(user_profile.get("weight", 70)),
        height=float(user_profile.get("height", 170)),
    )
    tdee = calculate_tdee(bmr, user_profile.get("activity_level", "moderately_active"))
    goal = user_profile.get("health_goals", "maintain weight")
    target_calories = adjust_calories_for_goal(tdee, goal)
    target_macros   = calculate_macros(target_calories, goal)
    cal_range       = calorie_range(target_calories)

    # ── User preferences & allergen lists ────────────────────────────────
    preferences = _parse_csv(user_profile.get("dietary_preferences", ""))
    allergens   = _parse_csv(user_profile.get("allergies", ""))

    # Pre-filter the database once — avoids redundant work inside the loop
    filtered_db: Dict[str, List[Dict]] = {
        meal_type: _filter_meals(meals, preferences, allergens)
        for meal_type, meals in MEAL_DATABASE.items()
    }

    # ── Build the plan ────────────────────────────────────────────────────
    # Sliding window: track the last VARIETY_WINDOW meals per category
    # to prevent consecutive repetition.
    VARIETY_WINDOW = 3
    recent: Dict[str, List[str]] = {mt: [] for mt in MEAL_DATABASE}

    meal_plan: Dict[str, Any] = {
        "nutritional_target": {
            "daily_calories": round(target_calories),
            "calories_min":   cal_range["min"],
            "calories_max":   cal_range["max"],
            "protein_g":      target_macros["protein"],
            "carbs_g":        target_macros["carbs"],
            "fats_g":         target_macros["fats"],
        },
        "meals": {},
        "dietary_filters_applied": preferences,
        "allergens_excluded": allergens,
    }

    for day in range(duration_days):
        date_key = (start_date + timedelta(days=day)).strftime("%Y-%m-%d")
        daily_meals: Dict[str, Dict] = {}

        for meal_type in ("breakfast", "lunch", "dinner", "snack"):
            pool        = filtered_db[meal_type]
            used_lately = set(recent[meal_type])

            chosen = _select_meal(
                meal_type=meal_type,
                candidates=pool,
                daily_calorie_target=target_calories,
                daily_macros=target_macros,
                recently_used=used_lately,
            )

            # Scale the meal's portion to exactly hit the target calorie
            # allocation for this meal slot (e.g. 25 % of daily target for
            # breakfast).  This means macros scale proportionally too, so the
            # daily totals match the nutritional target regardless of which
            # base meal was picked.
            ideal_cal = target_calories * _MEAL_CAL_SPLIT[meal_type]
            scale     = ideal_cal / chosen["calories"]

            # Round scale to nearest 0.5 serving for realistic portion guidance
            servings = round(scale * 2) / 2
            servings = max(0.5, servings)  # minimum half a serving

            # Scale ingredients proportionally
            scaled_ingredients = [
                {
                    "name":   ing["name"],
                    "amount": round(ing["amount"] * servings, 1) if isinstance(ing["amount"], (int, float)) else ing["amount"],
                    "unit":   ing["unit"],
                }
                for ing in chosen.get("ingredients", [])
            ]

            scaled_meal = {
                "name":         chosen["name"],
                "calories":     round(chosen["calories"] * servings),
                "protein":      round(chosen["protein"]  * servings, 1),
                "carbs":        round(chosen["carbs"]    * servings, 1),
                "fats":         round(chosen["fats"]     * servings, 1),
                "tags":         chosen["tags"],
                "allergens":    chosen["allergens"],
                "ingredients":  scaled_ingredients,
                "instructions": MEAL_INSTRUCTIONS.get(chosen["name"], []),
                "serving_unit": chosen["serving_unit"],
            }

            # Show a serving note whenever the portion differs from the base
            if abs(servings - 1.0) > 0.1:
                weight_g = round(chosen["serving_size_g"] * servings)
                label    = "serving" if servings == 1.0 else "servings"
                scaled_meal["serving"] = f"{servings:g} {label} (~{weight_g}g)"
            else:
                scaled_meal["serving"] = f"1 serving (~{chosen['serving_size_g']}g)"

            daily_meals[meal_type] = scaled_meal

            # Advance the variety window (track by original name)
            recent[meal_type].append(chosen["name"])
            if len(recent[meal_type]) > VARIETY_WINDOW:
                recent[meal_type].pop(0)

        meal_plan["meals"][date_key] = daily_meals

    return meal_plan
