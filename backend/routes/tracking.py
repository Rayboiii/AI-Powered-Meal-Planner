import json as _json
from fastapi import APIRouter, Depends, HTTPException, Query
from models.meal_log import MealLog, MealLogUpdate, ProgressQuery
from database.connection import execute_query
from utils.validation import get_current_user
from ai_engine.meal_planner import (
    MEAL_DATABASE, _filter_meals, _parse_csv, _MEAL_CAL_SPLIT,
    calculate_bmr, calculate_tdee, adjust_calories_for_goal, calculate_macros,
    calorie_range,
)
from datetime import datetime, timedelta, date
from pydantic import BaseModel, Field

router = APIRouter(prefix="/tracking", tags=["Meal Tracking"])


# ─── Meal logging ─────────────────────────────────────────────────────────────

@router.post("/log", response_model=dict)
async def log_meal(
    meal: MealLog,
    current_user: dict = Depends(get_current_user)
):
    """F006: Log daily meals"""
    base_data_json = _json.dumps(meal.base_meal_data) if meal.base_meal_data else None
    query = """
        INSERT INTO meal_logs (user_id, meal_date, meal_type, food_items, calories, protein, carbs, fats, base_meal_data, servings)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
    """
    log_id = execute_query(
        query,
        (current_user['user_id'], meal.meal_date, meal.meal_type, meal.food_items,
         meal.calories, meal.protein, meal.carbs, meal.fats,
         base_data_json, meal.servings)
    )

    if not log_id:
        raise HTTPException(status_code=500, detail="Failed to log meal")

    return {"message": "Meal logged successfully", "log_id": log_id}


@router.put("/log/{log_id}", response_model=dict)
async def update_meal_log(
    log_id: int,
    update: MealLogUpdate,
    current_user: dict = Depends(get_current_user),
):
    """Update an existing meal log entry"""
    check = execute_query(
        "SELECT log_id FROM meal_logs WHERE log_id = %s AND user_id = %s",
        (log_id, current_user['user_id'])
    )
    if not check:
        raise HTTPException(status_code=404, detail="Meal log not found")

    fields, values = [], []
    if update.food_items is not None:
        fields.append("food_items = %s"); values.append(update.food_items)
    if update.meal_type is not None:
        fields.append("meal_type = %s"); values.append(update.meal_type)
    if update.calories is not None:
        fields.append("calories = %s"); values.append(update.calories)
    if update.protein is not None:
        fields.append("protein = %s"); values.append(update.protein)
    if update.carbs is not None:
        fields.append("carbs = %s"); values.append(update.carbs)
    if update.fats is not None:
        fields.append("fats = %s"); values.append(update.fats)
    if update.servings is not None:
        fields.append("servings = %s"); values.append(update.servings)

    if not fields:
        return {"message": "Nothing to update"}

    values.extend([log_id, current_user['user_id']])
    execute_query(
        f"UPDATE meal_logs SET {', '.join(fields)} WHERE log_id = %s AND user_id = %s",
        tuple(values)
    )
    return {"message": "Meal log updated successfully"}


@router.get("/date", response_model=dict)
async def get_meals_by_date(
    date: str = Query(..., pattern=r"^\d{4}-\d{2}-\d{2}$"),
    current_user: dict = Depends(get_current_user),
):
    """Get meal logs for a specific date"""
    try:
        datetime.strptime(date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD.")

    query = """
        SELECT log_id, meal_date, meal_type, food_items, calories, protein, carbs, fats, base_meal_data, servings
        FROM meal_logs
        WHERE user_id = %s AND meal_date = %s
        ORDER BY log_id ASC
    """
    logs = execute_query(query, (current_user['user_id'], date))
    if not logs:
        return {"logs": [], "total_calories": 0}
    for log in logs:
        if log.get('base_meal_data') and isinstance(log['base_meal_data'], str):
            log['base_meal_data'] = _json.loads(log['base_meal_data'])
    total_calories = sum(log['calories'] for log in logs)
    return {"logs": logs, "total_calories": total_calories}


@router.get("/today", response_model=dict)
async def get_today_logs(current_user: dict = Depends(get_current_user)):
    """Get today's meal logs"""
    query = """
        SELECT log_id, meal_date, meal_type, food_items, calories, protein, carbs, fats, base_meal_data, servings
        FROM meal_logs
        WHERE user_id = %s AND meal_date = CURDATE()
        ORDER BY log_id DESC
    """
    logs = execute_query(query, (current_user['user_id'],))

    if not logs:
        return {"message": "No meals logged today", "logs": [], "total_calories": 0}

    for log in logs:
        if log.get('base_meal_data') and isinstance(log['base_meal_data'], str):
            log['base_meal_data'] = _json.loads(log['base_meal_data'])
    total_calories = sum(log['calories'] for log in logs)
    return {"logs": logs, "total_calories": total_calories}


@router.delete("/log/{log_id}", response_model=dict)
async def delete_meal_log(
    log_id: int,
    current_user: dict = Depends(get_current_user)
):
    """Delete a specific meal log entry (must belong to the current user)"""
    check = execute_query(
        "SELECT log_id FROM meal_logs WHERE log_id = %s AND user_id = %s",
        (log_id, current_user['user_id'])
    )
    if not check:
        raise HTTPException(status_code=404, detail="Meal log not found")

    result = execute_query(
        "DELETE FROM meal_logs WHERE log_id = %s AND user_id = %s",
        (log_id, current_user['user_id'])
    )
    if result is None:
        raise HTTPException(status_code=500, detail="Failed to delete meal log")

    return {"message": "Meal log deleted successfully"}


@router.get("/progress", response_model=dict)
async def get_progress(
    start_date: str,
    end_date: str,
    current_user: dict = Depends(get_current_user)
):
    """F007: View progress insights"""
    try:
        parsed_start = datetime.strptime(start_date, "%Y-%m-%d").date()
        parsed_end = datetime.strptime(end_date, "%Y-%m-%d").date()
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date format. Use YYYY-MM-DD.")

    if parsed_end < parsed_start:
        raise HTTPException(status_code=400, detail="end_date must be on or after start_date.")

    if (parsed_end - parsed_start).days > 90:
        raise HTTPException(status_code=400, detail="Date range cannot exceed 90 days.")

    query = """
        SELECT
            meal_date,
            SUM(calories) as total_calories,
            SUM(protein) as total_protein,
            SUM(carbs) as total_carbs,
            SUM(fats) as total_fats,
            COUNT(*) as meal_count
        FROM meal_logs
        WHERE user_id = %s
        AND meal_date BETWEEN %s AND %s
        GROUP BY meal_date
        ORDER BY meal_date
    """
    progress_data = execute_query(query, (current_user['user_id'], start_date, end_date))

    if not progress_data:
        return {"message": "No data found for this period", "data": []}

    avg_calories = sum(day['total_calories'] for day in progress_data) / len(progress_data)

    return {
        "daily_data": progress_data,
        "summary": {
            "average_calories": round(avg_calories, 2),
            "days_tracked": len(progress_data),
            "period": f"{start_date} to {end_date}",
        }
    }


# ─── Food search (autocomplete) ───────────────────────────────────────────────

@router.get("/food-search")
async def food_search(
    q: str = Query(default="", min_length=1),
    current_user: dict = Depends(get_current_user),
):
    """Search MEAL_DATABASE by name for autocomplete suggestions."""
    q_lower = q.lower().strip()
    results = []
    for category, meals in MEAL_DATABASE.items():
        for meal in meals:
            if q_lower in meal["name"].lower():
                results.append({
                    "name": meal["name"],
                    "category": category,
                    "calories": meal["calories"],
                    "protein": meal["protein"],
                    "carbs": meal["carbs"],
                    "fats": meal["fats"],
                    "ingredients": meal.get("ingredients", []),
                    "serving_size_g": meal.get("serving_size_g"),
                    "serving_unit": meal.get("serving_unit"),
                })
    # Sort: names starting with query first, then others alphabetically
    results.sort(key=lambda m: (not m["name"].lower().startswith(q_lower), m["name"]))
    return results[:10]  # Return top 10 matches


# ─── Recently logged foods ────────────────────────────────────────────────────

@router.get("/recent-foods")
async def get_recent_foods(
    limit: int = Query(default=5, ge=1, le=20),
    current_user: dict = Depends(get_current_user),
):
    """Return the user's most recently logged distinct food items."""
    rows = execute_query(
        """SELECT food_items, calories, protein, carbs, fats, meal_type
           FROM meal_logs
           WHERE user_id = %s
           ORDER BY meal_date DESC, log_id DESC
           LIMIT 50""",
        (current_user['user_id'],)
    ) or []

    seen: set[str] = set()
    recent = []
    for row in rows:
        key = row['food_items'].strip().lower()
        if key not in seen:
            seen.add(key)
            recent.append(row)
            if len(recent) >= limit:
                break
    return recent


# ─── Smart meal suggestion ────────────────────────────────────────────────────

@router.get("/suggest", response_model=dict)
async def suggest_next_meal(current_user: dict = Depends(get_current_user)):
    """AI-powered: suggest the best next meal based on remaining daily budget."""
    user_id = current_user['user_id']

    # 1. Get today's logs
    logs = execute_query(
        """SELECT meal_type, calories, protein, carbs, fats
           FROM meal_logs WHERE user_id = %s AND meal_date = CURDATE()""",
        (user_id,)
    ) or []

    consumed_cal   = sum(float(l['calories'] or 0) for l in logs)
    consumed_pro   = sum(float(l['protein']  or 0) for l in logs)
    consumed_carbs = sum(float(l['carbs']    or 0) for l in logs)
    consumed_fats  = sum(float(l['fats']     or 0) for l in logs)
    logged_types   = list({l['meal_type'].lower() for l in logs})

    # 2. Get user profile
    profile = execute_query(
        """SELECT age, weight, height, activity_level, health_goals,
                  dietary_preferences, allergies
           FROM user_profiles WHERE user_id = %s""",
        (user_id,)
    )

    if not profile:
        return {"status": "no_profile"}

    p = profile[0]
    required = ('age', 'weight', 'height', 'activity_level', 'health_goals')
    if not all(p.get(k) for k in required):
        return {"status": "no_profile"}

    # Compute personalised daily targets (same logic as profile.py)
    try:
        bmr        = calculate_bmr(int(p['age']), float(p['weight']), float(p['height']))
        tdee       = calculate_tdee(bmr, p['activity_level'])
        target_cal = adjust_calories_for_goal(tdee, p['health_goals'])
        macros     = calculate_macros(target_cal, p['health_goals'])
    except Exception:
        return {"status": "no_profile"}

    cal_target   = float(target_cal)
    pro_target   = float(macros['protein'])
    carbs_target = float(macros['carbs'])
    fats_target  = float(macros['fats'])

    # 3. Check if all meal types are already logged today
    all_types = ["breakfast", "lunch", "dinner", "snack"]
    if all(t in logged_types for t in all_types):
        return {"status": "complete"}

    # 4. Determine next meal type (first unlogged in canonical order)
    next_meal_type = next(t for t in all_types if t not in logged_types)

    # 5. Remaining budget
    remaining_cal   = max(0.0, cal_target   - consumed_cal)
    remaining_pro   = max(0.0, pro_target   - consumed_pro)
    remaining_carbs = max(0.0, carbs_target - consumed_carbs)
    remaining_fats  = max(0.0, fats_target  - consumed_fats)

    # 6. Filter candidates by dietary preferences + allergens
    preferences = _parse_csv(p.get('dietary_preferences') or '')
    allergens   = _parse_csv(p.get('allergies') or '')
    candidates  = MEAL_DATABASE.get(next_meal_type, [])
    filtered    = _filter_meals(candidates, preferences, allergens)

    # 7. Score each candidate against the remaining budget
    def _score(meal):
        cal_score = max(0.0, 1 - abs(meal['calories'] - remaining_cal) / max(remaining_cal, 1))
        p_score   = max(0.0, 1 - abs(meal['protein']  - remaining_pro)   / max(remaining_pro, 1))
        c_score   = max(0.0, 1 - abs(meal['carbs']    - remaining_carbs) / max(remaining_carbs, 1))
        f_score   = max(0.0, 1 - abs(meal['fats']     - remaining_fats)  / max(remaining_fats, 1))
        macro_score = (p_score + c_score + f_score) / 3
        return round((0.5 * cal_score + 0.5 * macro_score) * 100)

    scored = sorted(
        [{"meal": m, "score": _score(m)} for m in filtered],
        key=lambda x: x["score"],
        reverse=True,
    )[:3]

    # 8. Scale each suggestion's portion to cover its proportional share of
    #    the remaining calorie budget (same approach as meal plan generation).
    #    This ensures "Log This Meal" pre-fills values that help the user
    #    reach their daily nutritional target.
    remaining_types = [t for t in all_types if t not in logged_types]
    remaining_split_sum = sum(_MEAL_CAL_SPLIT[t] for t in remaining_types)
    this_type_fraction  = (
        _MEAL_CAL_SPLIT[next_meal_type] / remaining_split_sum
        if remaining_split_sum > 0 else _MEAL_CAL_SPLIT[next_meal_type]
    )
    # Ideal calories for this meal slot based on what's still left for today
    ideal_slot_cal = (
        remaining_cal * this_type_fraction
        if remaining_cal > 0
        else cal_target * _MEAL_CAL_SPLIT[next_meal_type]
    )

    suggestions = []
    for s in scored:
        meal  = s["meal"]
        scale = ideal_slot_cal / meal["calories"] if meal["calories"] > 0 else 1.0
        # Round to nearest 0.5 serving for realistic portion guidance
        servings = max(0.5, round(scale * 2) / 2)
        s_cal = round(meal["calories"] * servings)
        s_pro = round(meal["protein"]  * servings, 1)
        s_cbs = round(meal["carbs"]    * servings, 1)
        s_fat = round(meal["fats"]     * servings, 1)
        cal_pct = round(s_cal / max(remaining_cal, 1) * 100)
        pro_pct = round(s_pro / max(remaining_pro,  1) * 100)
        # Build a realistic serving label
        serving_size_g = meal.get("serving_size_g", 0)
        serving_unit   = meal.get("serving_unit", "serving")
        if abs(servings - 1.0) > 0.1:
            weight_g     = round(serving_size_g * servings) if serving_size_g else None
            serving_label = f"{servings:g} serving{'s' if servings != 1 else ''}"
            if weight_g:
                serving_label += f" (~{weight_g}g)"
        else:
            weight_g      = serving_size_g or None
            serving_label = f"1 {serving_unit}"
            if weight_g:
                serving_label += f" (~{weight_g}g)"
        # Scale ingredients proportionally
        scaled_ingredients = [
            {
                "name":   ing["name"],
                "amount": round(ing["amount"] * servings, 1) if isinstance(ing["amount"], (int, float)) else ing["amount"],
                "unit":   ing["unit"],
            }
            for ing in meal.get("ingredients", [])
        ]
        suggestions.append({
            "name":        meal["name"],
            "category":    next_meal_type,
            "calories":    s_cal,
            "protein":     s_pro,
            "carbs":       s_cbs,
            "fats":        s_fat,
            "match_score": s["score"],
            "reason":      f"Covers {cal_pct}% of remaining calories and {pro_pct}% of remaining protein",
            "serving":     serving_label,
            "ingredients": scaled_ingredients,
        })

    cal_range = calorie_range(cal_target)
    return {
        "status":             "ok",
        "next_meal_type":     next_meal_type,
        "remaining": {
            "calories": round(remaining_cal),
            "protein":  round(remaining_pro),
            "carbs":    round(remaining_carbs),
            "fats":     round(remaining_fats),
        },
        # Full daily targets — used by the Flutter tracking screen as a
        # reliable fallback when the profile provider hasn't loaded yet.
        "targets": {
            "calories":     round(cal_target),
            "calories_min": cal_range["min"],
            "calories_max": cal_range["max"],
            "protein":      round(pro_target,   1),
            "carbs":        round(carbs_target, 1),
            "fats":         round(fats_target,  1),
        },
        "calorie_consumed":   round(consumed_cal),
        "calorie_target":     round(cal_target),
        "meals_logged_today": logged_types,
        "suggestions":        suggestions,
    }


# ─── Weight tracking ──────────────────────────────────────────────────────────

class WeightLog(BaseModel):
    weight_kg: float = Field(gt=0, le=600)
    logged_date: str = Field(pattern=r"^\d{4}-\d{2}-\d{2}$")


@router.post("/weight", response_model=dict)
async def log_weight(
    body: WeightLog,
    current_user: dict = Depends(get_current_user)
):
    """Log a weight entry. One entry per day — upsert on date."""
    # Validate that the date string is actually a real calendar date
    try:
        datetime.strptime(body.logged_date, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Invalid date. Use YYYY-MM-DD.")

    # Upsert: if an entry exists for this date, update it
    existing = execute_query(
        "SELECT log_id FROM weight_logs WHERE user_id = %s AND logged_date = %s",
        (current_user['user_id'], body.logged_date)
    )
    if existing:
        execute_query(
            "UPDATE weight_logs SET weight_kg = %s WHERE user_id = %s AND logged_date = %s",
            (body.weight_kg, current_user['user_id'], body.logged_date)
        )
        return {"message": "Weight updated", "date": body.logged_date}

    log_id = execute_query(
        "INSERT INTO weight_logs (user_id, weight_kg, logged_date) VALUES (%s, %s, %s)",
        (current_user['user_id'], body.weight_kg, body.logged_date)
    )
    if not log_id:
        raise HTTPException(status_code=500, detail="Failed to log weight")

    return {"message": "Weight logged", "log_id": log_id, "date": body.logged_date}


@router.get("/weight", response_model=list)
async def get_weight_history(
    days: int = Query(default=30, ge=7, le=365),
    current_user: dict = Depends(get_current_user)
):
    """Get weight log history for the past N days."""
    query = """
        SELECT logged_date, weight_kg
        FROM weight_logs
        WHERE user_id = %s
          AND logged_date >= DATE_SUB(CURDATE(), INTERVAL %s DAY)
        ORDER BY logged_date ASC
    """
    rows = execute_query(query, (current_user['user_id'], days))
    return rows or []
