from fastapi import APIRouter, Depends, HTTPException
from models.meal_plan import MealPlanGenerate, MealPlanResponse, MealUpdate
from database.connection import execute_query
from utils.validation import get_current_user
from ai_engine.meal_planner import generate_meal_plan
import json
from datetime import datetime, timedelta

router = APIRouter(prefix="/meal-plan", tags=["Meal Plan"])

@router.post("/generate", response_model=dict)
async def create_meal_plan(
    plan_request: MealPlanGenerate,
    current_user: dict = Depends(get_current_user)
):
    """F004: Generate AI meal plan"""
    
    # Get user profile
    profile_query = """
        SELECT age, weight, height, dietary_preferences, 
               allergies, health_goals, activity_level
        FROM user_profiles 
        WHERE user_id = %s
    """
    profile = execute_query(profile_query, (current_user['user_id'],))
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found. Please complete your profile first.")
    
    # Generate meal plan
    meal_plan_data = generate_meal_plan(profile[0], plan_request.duration_days)
    
    # Calculate end date
    end_date = plan_request.start_date + timedelta(days=plan_request.duration_days - 1)
    
    # Save to database
    insert_query = """
        INSERT INTO meal_plans (user_id, created_at, start_date, end_date, plan_data)
        VALUES (%s, NOW(), %s, %s, %s)
    """
    plan_id = execute_query(
        insert_query,
        (current_user['user_id'], plan_request.start_date, end_date, json.dumps(meal_plan_data))
    )
    
    if not plan_id:
        raise HTTPException(status_code=500, detail="Failed to create meal plan")
    
    return {
        "message": "Meal plan generated successfully",
        "plan_id": plan_id,
        "meal_plan": meal_plan_data
    }

@router.get("/current", response_model=dict)
async def get_current_meal_plan(current_user: dict = Depends(get_current_user)):
    """Get user's current active meal plan"""
    query = """
        SELECT plan_id, created_at, start_date, end_date, plan_data
        FROM meal_plans
        WHERE user_id = %s
        AND end_date >= CURDATE()
        ORDER BY created_at DESC
        LIMIT 1
    """
    plan = execute_query(query, (current_user['user_id'],))
    
    if not plan:
        raise HTTPException(status_code=404, detail="No active meal plan found")
    
    plan_data = plan[0]
    plan_data['plan_data'] = json.loads(plan_data['plan_data'])
    
    return plan_data

@router.put("/customize", response_model=dict)
async def customize_meal(
    meal_update: MealUpdate,
    current_user: dict = Depends(get_current_user)
):
    """F005: Customize meal in plan"""
    
    # Get current plan
    query = """
        SELECT plan_id, plan_data
        FROM meal_plans
        WHERE user_id = %s
        AND start_date <= %s
        AND end_date >= %s
        ORDER BY created_at DESC
        LIMIT 1
    """
    plan = execute_query(query, (current_user['user_id'], meal_update.meal_date, meal_update.meal_date))
    
    if not plan:
        raise HTTPException(status_code=404, detail="No meal plan found for this date")
    
    plan_data = json.loads(plan[0]['plan_data'])
    date_str = meal_update.meal_date.strftime("%Y-%m-%d")
    
    # Update specific meal
    if date_str in plan_data['meals']:
        plan_data['meals'][date_str][meal_update.meal_type] = meal_update.new_meal_data
    else:
        raise HTTPException(status_code=404, detail="Date not found in meal plan")
    
    # Save updated plan
    update_query = """
        UPDATE meal_plans
        SET plan_data = %s
        WHERE plan_id = %s
    """
    execute_query(update_query, (json.dumps(plan_data), plan[0]['plan_id']))
    
    return {"message": "Meal updated successfully", "updated_plan": plan_data}