from pydantic import BaseModel
from datetime import date
from typing import Optional

class MealLog(BaseModel):
    meal_date: date
    meal_type: str
    food_items: str
    calories: float
    protein: Optional[float] = None
    carbs: Optional[float] = None
    fats: Optional[float] = None

class ProgressQuery(BaseModel):
    start_date: date
    end_date: date