from fastapi import APIRouter, Depends, HTTPException
from models.user import UserProfile, UserProfileUpdate
from database.connection import execute_query
from utils.validation import get_current_user

router = APIRouter(prefix="/profile", tags=["Profile"])

@router.get("/")
async def get_profile(current_user: dict = Depends(get_current_user)):
    """F003: Get user profile"""
    print(f"Getting profile for user: {current_user}")  # Debug
    
    query = """
        SELECT age, weight, height, dietary_preferences, 
               allergies, health_goals, activity_level
        FROM user_profiles 
        WHERE user_id = %s
    """
    profile = execute_query(query, (current_user['user_id'],))
    
    if not profile:
        raise HTTPException(status_code=404, detail="Profile not found")
    
    return profile[0]

@router.put("/")
async def update_profile(
    profile_data: UserProfileUpdate,
    current_user: dict = Depends(get_current_user)
):
    """F003: Update user profile"""
    print(f"Updating profile for user: {current_user}")  # Debug
    
    # Build dynamic update query
    update_fields = []
    params = []
    
    for field, value in profile_data.dict(exclude_unset=True).items():
        if value is not None:
            update_fields.append(f"{field} = %s")
            params.append(value)
    
    if not update_fields:
        raise HTTPException(status_code=400, detail="No fields to update")
    
    params.append(current_user['user_id'])
    
    query = f"""
        UPDATE user_profiles 
        SET {', '.join(update_fields)}
        WHERE user_id = %s
    """
    
    result = execute_query(query, tuple(params))
    
    return {"message": "Profile updated successfully"}