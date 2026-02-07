from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
import bcrypt
import os
from dotenv import load_dotenv

load_dotenv()

SECRET_KEY = os.getenv('SECRET_KEY')
ALGORITHM = os.getenv('ALGORITHM')
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv('ACCESS_TOKEN_EXPIRE_MINUTES'))

print(f"Loaded SECRET_KEY: {SECRET_KEY[:20] if SECRET_KEY else 'None'}...")  # Debug
print(f"Loaded ALGORITHM: {ALGORITHM}")  # Debug

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against a hash"""
    return bcrypt.checkpw(
        plain_password.encode('utf-8'), 
        hashed_password.encode('utf-8')
    )

def get_password_hash(password: str) -> str:
    """Hash a password"""
    salt = bcrypt.gensalt()
    hashed = bcrypt.hashpw(password.encode('utf-8'), salt)
    return hashed.decode('utf-8')

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    """Create a JWT token"""
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    
    print(f"Creating token with data: {data}")  # Debug
    print(f"Token will expire at: {expire}")  # Debug
    
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def decode_token(token: str):
    """Decode and verify a JWT token"""
    try:
        print(f"Attempting to decode token: {token[:20]}...")  # Debug
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        print(f"Decoded payload: {payload}")  # Debug
        
        email: str = payload.get("sub")
        if email is None:
            print("No 'sub' field in payload")  # Debug
            return None
        
        print(f"Extracted email: {email}")  # Debug
        return email
        
    except JWTError as e:
        print(f"JWT decode error: {type(e).__name__} - {str(e)}")  # Debug
        return None
    except Exception as e:
        print(f"Unexpected decode error: {type(e).__name__} - {str(e)}")  # Debug
        return None