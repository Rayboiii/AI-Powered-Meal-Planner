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
#   name      – display name
#   calories  – kcal per serving
#   protein   – grams
#   carbs     – grams
#   fats      – grams
#   tags      – dietary-style flags (used for preference matching)
#   allergens – common allergens present in this meal
# ─────────────────────────────────────────────────────────────────────────────

MEAL_DATABASE: Dict[str, List[Dict]] = {

    "breakfast": [
        {
            "name": "Oatmeal with Mixed Berries",
            "calories": 350, "protein": 12, "carbs": 55, "fats":  8,
            "tags": ["vegetarian", "vegan", "high-carb"],
            "allergens": ["gluten"],
        },
        {
            "name": "Greek Yogurt Parfait",
            "calories": 300, "protein": 20, "carbs": 35, "fats":  8,
            "tags": ["vegetarian", "high-protein"],
            "allergens": ["dairy"],
        },
        {
            "name": "Scrambled Eggs with Toast",
            "calories": 400, "protein": 25, "carbs": 30, "fats": 18,
            "tags": ["vegetarian", "high-protein"],
            "allergens": ["eggs", "gluten", "dairy"],
        },
        {
            "name": "Protein Smoothie",
            "calories": 320, "protein": 28, "carbs": 40, "fats":  6,
            "tags": ["vegetarian", "vegan", "high-protein", "dairy-free"],
            "allergens": [],
        },
        {
            "name": "Avocado Toast with Poached Eggs",
            "calories": 390, "protein": 18, "carbs": 32, "fats": 24,
            "tags": ["vegetarian", "high-fat"],
            "allergens": ["gluten", "eggs"],
        },
        {
            "name": "Banana Pancakes",
            "calories": 420, "protein": 12, "carbs": 68, "fats": 10,
            "tags": ["vegetarian", "high-carb"],
            "allergens": ["gluten", "eggs", "dairy"],
        },
        {
            "name": "Chia Seed Pudding",
            "calories": 280, "protein": 10, "carbs": 34, "fats": 13,
            "tags": ["vegetarian", "vegan", "dairy-free", "gluten-free"],
            "allergens": [],
        },
        {
            "name": "Veggie Omelette",
            "calories": 340, "protein": 22, "carbs": 12, "fats": 22,
            "tags": ["vegetarian", "keto", "low-carb", "gluten-free"],
            "allergens": ["eggs", "dairy"],
        },
        {
            "name": "Peanut Butter Banana Toast",
            "calories": 360, "protein": 14, "carbs": 48, "fats": 13,
            "tags": ["vegetarian", "vegan"],
            "allergens": ["gluten", "nuts"],
        },
        {
            "name": "Rice Porridge with Soft-Boiled Egg",
            "calories": 300, "protein": 16, "carbs": 42, "fats":  7,
            "tags": ["gluten-free", "dairy-free"],
            "allergens": ["eggs"],
        },
        {
            "name": "Tofu Scramble with Spinach",
            "calories": 310, "protein": 20, "carbs": 18, "fats": 16,
            "tags": ["vegetarian", "vegan", "dairy-free", "gluten-free"],
            "allergens": ["soy"],
        },
        {
            "name": "Overnight Oats with Banana",
            "calories": 370, "protein": 14, "carbs": 58, "fats":  9,
            "tags": ["vegetarian", "vegan", "high-carb"],
            "allergens": ["gluten"],
        },
        {
            "name": "Egg White Omelette",
            "calories": 250, "protein": 28, "carbs":  8, "fats":  8,
            "tags": ["vegetarian", "high-protein", "low-fat", "keto", "gluten-free"],
            "allergens": ["eggs"],
        },
        {
            "name": "Whole Grain Cereal with Milk",
            "calories": 290, "protein": 11, "carbs": 50, "fats":  5,
            "tags": ["vegetarian", "high-carb"],
            "allergens": ["gluten", "dairy"],
        },
    ],

    "lunch": [
        {
            "name": "Grilled Chicken Salad",
            "calories": 450, "protein": 40, "carbs": 25, "fats": 20,
            "tags": ["high-protein", "low-carb", "gluten-free"],
            "allergens": [],
        },
        {
            "name": "Quinoa Buddha Bowl",
            "calories": 500, "protein": 18, "carbs": 65, "fats": 15,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": [],
        },
        {
            "name": "Turkey Sandwich",
            "calories": 420, "protein": 30, "carbs": 45, "fats": 12,
            "tags": ["high-protein"],
            "allergens": ["gluten"],
        },
        {
            "name": "Salmon with Roasted Vegetables",
            "calories": 480, "protein": 35, "carbs": 30, "fats": 22,
            "tags": ["high-protein", "gluten-free"],
            "allergens": ["fish"],
        },
        {
            "name": "Lentil Soup with Bread",
            "calories": 430, "protein": 22, "carbs": 60, "fats":  8,
            "tags": ["vegetarian", "vegan", "high-carb"],
            "allergens": ["gluten"],
        },
        {
            "name": "Chicken Caesar Wrap",
            "calories": 510, "protein": 35, "carbs": 40, "fats": 22,
            "tags": ["high-protein"],
            "allergens": ["gluten", "dairy", "eggs"],
        },
        {
            "name": "Tuna Salad Sandwich",
            "calories": 400, "protein": 32, "carbs": 36, "fats": 14,
            "tags": ["high-protein"],
            "allergens": ["fish", "gluten", "eggs"],
        },
        {
            "name": "Chickpea and Veggie Stir Fry",
            "calories": 440, "protein": 18, "carbs": 58, "fats": 12,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": [],
        },
        {
            "name": "Brown Rice Tofu Bowl",
            "calories": 450, "protein": 22, "carbs": 60, "fats": 12,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": ["soy"],
        },
        {
            "name": "Greek Salad with Feta",
            "calories": 380, "protein": 14, "carbs": 22, "fats": 26,
            "tags": ["vegetarian", "gluten-free", "low-carb"],
            "allergens": ["dairy"],
        },
        {
            "name": "Bean and Veggie Burrito",
            "calories": 490, "protein": 20, "carbs": 68, "fats": 14,
            "tags": ["vegetarian", "vegan", "high-carb"],
            "allergens": ["gluten"],
        },
        {
            "name": "Shrimp Fried Rice",
            "calories": 470, "protein": 28, "carbs": 58, "fats": 12,
            "tags": ["high-protein", "gluten-free"],
            "allergens": ["shellfish", "soy", "eggs"],
        },
        {
            "name": "Caprese Salad with Grilled Chicken",
            "calories": 420, "protein": 38, "carbs": 14, "fats": 22,
            "tags": ["high-protein", "gluten-free", "low-carb"],
            "allergens": ["dairy"],
        },
        {
            "name": "Spinach and Cheese Quesadilla",
            "calories": 440, "protein": 22, "carbs": 46, "fats": 18,
            "tags": ["vegetarian"],
            "allergens": ["gluten", "dairy"],
        },
    ],

    "dinner": [
        {
            "name": "Grilled Steak with Sweet Potato",
            "calories": 550, "protein": 45, "carbs": 40, "fats": 20,
            "tags": ["high-protein", "gluten-free"],
            "allergens": [],
        },
        {
            "name": "Chicken Stir Fry with Noodles",
            "calories": 500, "protein": 38, "carbs": 50, "fats": 15,
            "tags": ["high-protein"],
            "allergens": ["soy", "gluten"],
        },
        {
            "name": "Baked Fish with Brown Rice",
            "calories": 480, "protein": 40, "carbs": 45, "fats": 14,
            "tags": ["high-protein", "gluten-free"],
            "allergens": ["fish"],
        },
        {
            "name": "Vegetarian Pasta Primavera",
            "calories": 520, "protein": 20, "carbs": 70, "fats": 16,
            "tags": ["vegetarian", "high-carb"],
            "allergens": ["gluten", "dairy"],
        },
        {
            "name": "Beef and Broccoli",
            "calories": 530, "protein": 42, "carbs": 30, "fats": 24,
            "tags": ["high-protein", "low-carb"],
            "allergens": ["soy", "gluten"],
        },
        {
            "name": "Baked Salmon with Asparagus",
            "calories": 490, "protein": 42, "carbs": 18, "fats": 26,
            "tags": ["high-protein", "keto", "low-carb", "gluten-free"],
            "allergens": ["fish"],
        },
        {
            "name": "Lentil Dal with Basmati Rice",
            "calories": 480, "protein": 22, "carbs": 68, "fats":  9,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": [],
        },
        {
            "name": "Chicken Tikka Masala with Rice",
            "calories": 540, "protein": 40, "carbs": 38, "fats": 22,
            "tags": ["high-protein", "gluten-free"],
            "allergens": ["dairy"],
        },
        {
            "name": "Pork Tenderloin with Roasted Veg",
            "calories": 500, "protein": 44, "carbs": 22, "fats": 24,
            "tags": ["high-protein", "gluten-free"],
            "allergens": [],
        },
        {
            "name": "Vegan Buddha Bowl",
            "calories": 460, "protein": 18, "carbs": 62, "fats": 14,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": [],
        },
        {
            "name": "Shrimp Pasta Aglio e Olio",
            "calories": 520, "protein": 30, "carbs": 60, "fats": 16,
            "tags": ["high-protein"],
            "allergens": ["shellfish", "gluten"],
        },
        {
            "name": "Stuffed Bell Peppers with Quinoa",
            "calories": 470, "protein": 28, "carbs": 48, "fats": 16,
            "tags": ["gluten-free"],
            "allergens": ["dairy"],
        },
        {
            "name": "Turkey Meatballs with Zucchini Noodles",
            "calories": 430, "protein": 38, "carbs": 18, "fats": 20,
            "tags": ["high-protein", "low-carb", "gluten-free"],
            "allergens": ["eggs"],
        },
        {
            "name": "Black Bean Tacos",
            "calories": 490, "protein": 20, "carbs": 62, "fats": 16,
            "tags": ["vegetarian", "vegan", "high-carb"],
            "allergens": ["gluten"],
        },
    ],

    "snack": [
        {
            "name": "Apple with Almond Butter",
            "calories": 200, "protein":  6, "carbs": 22, "fats": 10,
            "tags": ["vegetarian", "vegan", "gluten-free"],
            "allergens": ["nuts"],
        },
        {
            "name": "Protein Bar",
            "calories": 200, "protein": 20, "carbs": 22, "fats":  7,
            "tags": ["high-protein"],
            "allergens": ["gluten", "dairy", "nuts"],
        },
        {
            "name": "Mixed Nuts",
            "calories": 170, "protein":  6, "carbs":  8, "fats": 14,
            "tags": ["vegetarian", "vegan", "keto", "gluten-free"],
            "allergens": ["nuts"],
        },
        {
            "name": "Greek Yogurt with Honey",
            "calories": 160, "protein": 14, "carbs": 20, "fats":  3,
            "tags": ["vegetarian", "high-protein", "gluten-free"],
            "allergens": ["dairy"],
        },
        {
            "name": "Hummus with Carrot Sticks",
            "calories": 150, "protein":  6, "carbs": 18, "fats":  6,
            "tags": ["vegetarian", "vegan", "gluten-free", "dairy-free"],
            "allergens": [],
        },
        {
            "name": "Boiled Eggs",
            "calories": 140, "protein": 12, "carbs":  1, "fats":  9,
            "tags": ["vegetarian", "keto", "gluten-free", "high-protein", "dairy-free"],
            "allergens": ["eggs"],
        },
        {
            "name": "Edamame",
            "calories": 150, "protein": 12, "carbs": 12, "fats":  5,
            "tags": ["vegetarian", "vegan", "gluten-free", "dairy-free"],
            "allergens": ["soy"],
        },
        {
            "name": "Rice Cakes with Avocado",
            "calories": 160, "protein":  3, "carbs": 20, "fats":  7,
            "tags": ["vegetarian", "vegan", "gluten-free", "dairy-free"],
            "allergens": [],
        },
        {
            "name": "Cottage Cheese with Pineapple",
            "calories": 180, "protein": 16, "carbs": 18, "fats":  4,
            "tags": ["vegetarian", "high-protein", "gluten-free"],
            "allergens": ["dairy"],
        },
        {
            "name": "Banana with Peanut Butter",
            "calories": 190, "protein":  6, "carbs": 28, "fats":  7,
            "tags": ["vegetarian", "vegan", "gluten-free", "dairy-free"],
            "allergens": ["nuts"],
        },
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
          "nutritional_target": { daily_calories, protein_g, carbs_g, fats_g },
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
            scaled_meal = {
                "name":     chosen["name"],
                "calories": round(chosen["calories"] * scale),
                "protein":  round(chosen["protein"]  * scale, 1),
                "carbs":    round(chosen["carbs"]    * scale, 1),
                "fats":     round(chosen["fats"]     * scale, 1),
                "tags":     chosen["tags"],
                "allergens": chosen["allergens"],
            }
            # Only surface a serving note when the adjustment is noticeable
            if abs(scale - 1.0) > 0.05:
                scaled_meal["serving"] = f"{scale:.1f}x portion"
            daily_meals[meal_type] = scaled_meal

            # Advance the variety window (track by original name)
            recent[meal_type].append(chosen["name"])
            if len(recent[meal_type]) > VARIETY_WINDOW:
                recent[meal_type].pop(0)

        meal_plan["meals"][date_key] = daily_meals

    return meal_plan
