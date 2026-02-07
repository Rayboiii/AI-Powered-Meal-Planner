from fastapi import APIRouter, HTTPException
from models.user import UserRegister, UserLogin, Token
from utils.auth_helper import get_password_hash, verify_password, create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES
from database.connection import execute_query
from datetime import timedelta

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", response_model=dict)
async def register(user: UserRegister):
    """F001: User Registration"""
    # Check if user already exists
    check_query = "SELECT user_id FROM users WHERE email = %s"
    existing_user = execute_query(check_query, (user.email,))
    
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Hash password
    hashed_password = get_password_hash(user.password)
    
    # Insert new user
    insert_query = """
        INSERT INTO users (email, password_hash, created_at) 
        VALUES (%s, %s, NOW())
    """
    user_id = execute_query(insert_query, (user.email, hashed_password))
    
    if not user_id:
        raise HTTPException(status_code=500, detail="Failed to create user")
    
    # Create profile entry
    profile_query = "INSERT INTO user_profiles (user_id) VALUES (%s)"
    execute_query(profile_query, (user_id,))
    
    return {
        "message": "User registered successfully",
        "user_id": user_id,
        "email": user.email
    }

@router.post("/login", response_model=Token)
async def login(user: UserLogin):
    """F002: User Login"""
    # Get user from database
    query = "SELECT user_id, email, password_hash FROM users WHERE email = %s"
    db_user = execute_query(query, (user.email,))
    
    if not db_user:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    db_user = db_user[0]
    
    # Verify password
    if not verify_password(user.password, db_user['password_hash']):
        raise HTTPException(status_code=401, detail="Invalid email or password")
    
    # Create access token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": db_user['email']}, 
        expires_delta=access_token_expires
    )
    
    return {
        "access_token": access_token,
        "token_type": "bearer"
    }