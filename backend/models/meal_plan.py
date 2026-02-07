from pydantic import BaseModel
from typing import Optional, Dict, Any
from datetime import date

class MealPlanGenerate(BaseModel):
    start_date: date
    duration_days: int = 7

class MealPlanResponse(BaseModel):
    plan_id: int
    user_id: int
    created_at: str
    start_date: str
    end_date: str
    plan_data: Dict[str, Any]

class MealUpdate(BaseModel):
    meal_date: date
    meal_type: str  # breakfast, lunch, dinner, snack
    new_meal_data: Dict[str, Any]