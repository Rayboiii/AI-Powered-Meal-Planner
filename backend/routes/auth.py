from fastapi import APIRouter, HTTPException, Depends
from models.user import UserRegister, UserLogin, Token
from utils.validation import get_current_user
from utils.auth_helper import (
    get_password_hash, verify_password,
    create_access_token, create_refresh_token,
    decode_token, ACCESS_TOKEN_EXPIRE_MINUTES,
)
from database.connection import execute_query
from datetime import timedelta
from pydantic import BaseModel, Field

router = APIRouter(prefix="/auth", tags=["Authentication"])


class RefreshRequest(BaseModel):
    refresh_token: str


class ResetPasswordRequest(BaseModel):
    email: str
    new_password: str = Field(min_length=8, max_length=100)


@router.post("/register", response_model=dict)
async def register(user: UserRegister):
    """F001: User Registration"""
    check_query = "SELECT user_id FROM users WHERE email = %s"
    if execute_query(check_query, (user.email,)):
        raise HTTPException(status_code=400, detail="Email already registered")

    hashed_password = get_password_hash(user.password)
    insert_query = """
        INSERT INTO users (email, password_hash, created_at)
        VALUES (%s, %s, NOW())
    """
    user_id = execute_query(insert_query, (user.email, hashed_password))

    if not user_id:
        raise HTTPException(status_code=500, detail="Failed to create user")

    execute_query("INSERT INTO user_profiles (user_id) VALUES (%s)", (user_id,))

    return {
        "message": "User registered successfully",
        "user_id": user_id,
        "email": user.email,
    }


@router.post("/login", response_model=Token)
async def login(user: UserLogin):
    """F002: User Login — returns access + refresh tokens"""
    query = "SELECT user_id, email, password_hash FROM users WHERE email = %s"
    db_user = execute_query(query, (user.email,))

    if not db_user:
        raise HTTPException(status_code=401, detail="Invalid email or password")

    db_user = db_user[0]

    if not verify_password(user.password, db_user['password_hash']):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    token_data = {"sub": db_user['email']}
    return {
        "access_token": create_access_token(token_data),
        "refresh_token": create_refresh_token(token_data),
        "token_type": "bearer",
    }


@router.post("/refresh", response_model=Token)
async def refresh(body: RefreshRequest):
    """Exchange a valid refresh token for new access + refresh tokens"""
    email = decode_token(body.refresh_token, expected_type="refresh")
    if not email:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    query = "SELECT user_id, email FROM users WHERE email = %s"
    user = execute_query(query, (email,))
    if not user:
        raise HTTPException(status_code=401, detail="User not found")

    token_data = {"sub": email}
    return {
        "access_token": create_access_token(token_data),
        "refresh_token": create_refresh_token(token_data),
        "token_type": "bearer",
    }


@router.post("/reset-password", response_model=dict)
async def reset_password(body: ResetPasswordRequest):
    """Reset password using email — no token required (self-service reset)"""
    query = "SELECT user_id FROM users WHERE email = %s"
    result = execute_query(query, (body.email,))
    if not result:
        raise HTTPException(status_code=404, detail="No account found with that email address")

    new_hash = get_password_hash(body.new_password)
    update_query = "UPDATE users SET password_hash = %s WHERE email = %s"
    execute_query(update_query, (new_hash, body.email))

    return {"message": "Password reset successfully"}


@router.delete("/account", response_model=dict)
async def delete_account(current_user: dict = Depends(get_current_user)):
    """Delete the authenticated user's account and all associated data"""
    user_id = current_user['user_id']
    execute_query("DELETE FROM meal_logs WHERE user_id = %s", (user_id,))
    execute_query("DELETE FROM progress_tracking WHERE user_id = %s", (user_id,))
    execute_query("DELETE FROM meal_plans WHERE user_id = %s", (user_id,))
    execute_query("DELETE FROM user_profiles WHERE user_id = %s", (user_id,))
    execute_query("DELETE FROM users WHERE user_id = %s", (user_id,))
    return {"message": "Account deleted successfully"}
