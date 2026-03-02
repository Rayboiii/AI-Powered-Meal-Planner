from pydantic import BaseModel, Field
from datetime import date
from typing import Optional, Literal

class MealLog(BaseModel):
    meal_date: date
    meal_type: Literal['breakfast', 'lunch', 'dinner', 'snack']
    food_items: str = Field(min_length=1, max_length=500)
    calories: float = Field(ge=0, le=10000)
    protein: Optional[float] = Field(default=None, ge=0, le=1000)
    carbs: Optional[float] = Field(default=None, ge=0, le=1000)
    fats: Optional[float] = Field(default=None, ge=0, le=1000)

class ProgressQuery(BaseModel):
    start_date: date
    end_date: date
