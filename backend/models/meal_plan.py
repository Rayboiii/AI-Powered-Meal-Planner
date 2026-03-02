from pydantic import BaseModel, Field
from typing import Optional, Dict, Any, Literal
from datetime import date

class MealPlanGenerate(BaseModel):
    start_date: date
    duration_days: int = Field(default=7, ge=1, le=30)

class MealPlanResponse(BaseModel):
    plan_id: int
    user_id: int
    created_at: str
    start_date: str
    end_date: str
    plan_data: Dict[str, Any]

class MealData(BaseModel):
    name: str = Field(min_length=1, max_length=255)
    calories: float = Field(ge=0, le=10000)
    protein: float = Field(ge=0, le=1000)
    carbs: float = Field(ge=0, le=1000)
    fats: float = Field(ge=0, le=1000)
    serving: Optional[str] = Field(default=None, max_length=100)

class MealUpdate(BaseModel):
    meal_date: date
    meal_type: Literal['breakfast', 'lunch', 'dinner', 'snack']
    new_meal_data: MealData
