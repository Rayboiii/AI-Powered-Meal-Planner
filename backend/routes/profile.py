from fastapi import APIRouter, Depends, HTTPException
from models.user import UserProfile, UserProfileUpdate
from database.connection import execute_query
from utils.validation import get_current_user
from ai_engine.meal_planner import (
    calculate_bmr, calculate_tdee, adjust_calories_for_goal, calculate_macros,
    calorie_range,
)

router = APIRouter(prefix="/profile", tags=["Profile"])

# Maps Pydantic field names → exact SQL column names.
# Column names come exclusively from this dict — never from user input.
_FIELD_TO_COLUMN: dict[str, str] = {
    "name":                 "name",
    "age":                  "age",
    "weight":               "weight",
    "height":               "height",
    "dietary_preferences":  "dietary_preferences",
    "allergies":            "allergies",
    "health_goals":         "health_goals",
    "activity_level":       "activity_level",
}

@router.get("/")
async def get_profile(current_user: dict = Depends(get_current_user)):
    """F003: Get user profile with computed daily nutritional targets"""
    # Select only the columns that are guaranteed in the base schema.
    # 'name' is fetched separately so that a missing column in older
    # database versions never causes this endpoint to return 404.
    query = """
        SELECT age, weight, height, dietary_preferences,
               allergies, health_goals, activity_level
        FROM user_profiles
        WHERE user_id = %s
    """
    profile = execute_query(query, (current_user['user_id'],))

    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")

    profile_data = dict(profile[0])

    # Fetch name separately — missing column returns None, not an error
    name_row = execute_query(
        "SELECT name FROM user_profiles WHERE user_id = %s",
        (current_user['user_id'],)
    )
    profile_data['name'] = name_row[0].get('name') if name_row else None

    # Compute personalised daily targets whenever the profile is complete
    required = ('age', 'weight', 'height', 'activity_level', 'health_goals')
    if all(profile_data.get(k) for k in required):
        try:
            bmr = calculate_bmr(
                age=int(profile_data['age']),
                weight=float(profile_data['weight']),
                height=float(profile_data['height']),
            )
            tdee        = calculate_tdee(bmr, profile_data['activity_level'])
            target_cal  = adjust_calories_for_goal(tdee, profile_data['health_goals'])
            macros      = calculate_macros(target_cal, profile_data['health_goals'])

            cal_range = calorie_range(target_cal)
            profile_data['daily_calorie_target']     = round(target_cal)
            profile_data['daily_calorie_target_min'] = cal_range['min']
            profile_data['daily_calorie_target_max'] = cal_range['max']
            profile_data['daily_protein_target']     = macros['protein']
            profile_data['daily_carbs_target']       = macros['carbs']
            profile_data['daily_fats_target']        = macros['fats']
        except Exception:
            pass  # targets are optional; silently omit if calculation fails

    return profile_data

@router.put("/")
async def update_profile(
    profile_data: UserProfileUpdate,
    current_user: dict = Depends(get_current_user)
):
    """F003: Update user profile"""
    # Build dynamic UPDATE — column names come from our hardcoded dict only,
    # never from user-supplied input, eliminating SQL injection risk.
    set_clauses: list[str] = []
    params: list = []

    for field, value in profile_data.dict(exclude_unset=True).items():
        col = _FIELD_TO_COLUMN.get(field)
        if col is not None and value is not None:
            set_clauses.append(f"{col} = %s")
            params.append(value)

    if not set_clauses:
        raise HTTPException(status_code=400, detail="No fields to update")

    params.append(current_user['user_id'])

    query = "UPDATE user_profiles SET " + ", ".join(set_clauses) + " WHERE user_id = %s"

    result = execute_query(query, tuple(params))
    
    return {"message": "Profile updated successfully"}