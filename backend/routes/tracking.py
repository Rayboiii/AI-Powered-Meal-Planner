from fastapi import APIRouter, Depends, HTTPException
from models.meal_log import MealLog, ProgressQuery
from database.connection import execute_query
from utils.validation import get_current_user
from datetime import datetime, timedelta

router = APIRouter(prefix="/tracking", tags=["Meal Tracking"])

@router.post("/log", response_model=dict)
async def log_meal(
    meal: MealLog,
    current_user: dict = Depends(get_current_user)
):
    """F006: Log daily meals"""
    query = """
        INSERT INTO meal_logs (user_id, meal_date, meal_type, food_items, calories, protein, carbs, fats)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
    """
    log_id = execute_query(
        query,
        (current_user['user_id'], meal.meal_date, meal.meal_type, meal.food_items,
         meal.calories, meal.protein, meal.carbs, meal.fats)
    )
    
    if not log_id:
        raise HTTPException(status_code=500, detail="Failed to log meal")
    
    return {
        "message": "Meal logged successfully",
        "log_id": log_id
    }

@router.get("/today", response_model=dict)
async def get_today_logs(current_user: dict = Depends(get_current_user)):
    """Get today's meal logs"""
    query = """
        SELECT log_id, meal_date, meal_type, food_items, calories, protein, carbs, fats
        FROM meal_logs
        WHERE user_id = %s AND meal_date = CURDATE()
        ORDER BY log_id DESC
    """
    logs = execute_query(query, (current_user['user_id'],))
    
    if not logs:
        return {"message": "No meals logged today", "logs": [], "total_calories": 0}
    
    total_calories = sum(log['calories'] for log in logs)
    
    return {
        "logs": logs,
        "total_calories": total_calories
    }

@router.get("/progress", response_model=dict)
async def get_progress(
    start_date: str,
    end_date: str,
    current_user: dict = Depends(get_current_user)
):
    """F007: View progress insights"""
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
    
    # Calculate statistics
    avg_calories = sum(day['total_calories'] for day in progress_data) / len(progress_data)
    
    return {
        "daily_data": progress_data,
        "summary": {
            "average_calories": round(avg_calories, 2),
            "days_tracked": len(progress_data),
            "period": f"{start_date} to {end_date}"
        }
    }