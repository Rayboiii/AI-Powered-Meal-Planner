from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from utils.auth_helper import decode_token
from database.connection import execute_query

security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Validate token and return current user"""
    try:
        token = credentials.credentials
        print(f"Received token: {token[:20]}...")  # Debug
        
        # Decode token
        email = decode_token(token)
        print(f"Decoded email: {email}")  # Debug
        
        if email is None:
            print("Token decode returned None")  # Debug
            raise HTTPException(
                status_code=401, 
                detail="Invalid token: Could not decode"
            )
        
        # Get user from database
        query = "SELECT user_id, email FROM users WHERE email = %s"
        user = execute_query(query, (email,))
        print(f"User from DB: {user}")  # Debug
        
        if not user:
            print(f"User not found for email: {email}")  # Debug
            raise HTTPException(
                status_code=401, 
                detail="User not found in database"
            )
        
        print(f"Successfully authenticated user: {user[0]}")  # Debug
        return user[0]
        
    except HTTPException:
        raise
    except Exception as e:
        print(f"Auth error - Exception type: {type(e).__name__}")  # Debug
        print(f"Auth error - Details: {str(e)}")  # Debug
        import traceback
        print(f"Traceback: {traceback.format_exc()}")  # Debug
        raise HTTPException(
            status_code=401,
            detail=f"Authentication failed: {str(e)}"
        )