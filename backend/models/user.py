from pydantic import BaseModel, EmailStr, Field
from typing import Optional
from datetime import datetime

class UserRegister(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=100)

class UserLogin(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=100)

class UserProfile(BaseModel):
    name: Optional[str] = Field(default=None, max_length=100)
    age: Optional[int] = None
    weight: Optional[float] = None
    height: Optional[float] = None
    dietary_preferences: Optional[str] = None
    allergies: Optional[str] = None
    health_goals: Optional[str] = None
    activity_level: Optional[str] = None

class UserProfileUpdate(BaseModel):
    name: Optional[str] = Field(default=None, max_length=100)
    age: Optional[int] = Field(default=None, ge=13, le=120)
    weight: Optional[float] = Field(default=None, gt=0, le=500)
    height: Optional[float] = Field(default=None, gt=0, le=300)
    dietary_preferences: Optional[str] = Field(default=None, max_length=500)
    allergies: Optional[str] = Field(default=None, max_length=500)
    health_goals: Optional[str] = None
    activity_level: Optional[str] = None

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str

class TokenData(BaseModel):
    email: Optional[str] = None
