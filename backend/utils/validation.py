from fastapi import HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from utils.auth_helper import decode_token
from database.connection import execute_query

security = HTTPBearer()

async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """Validate token and return current user"""
    try:
        token = credentials.credentials

        email = decode_token(token)

        if email is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid token: Could not decode"
            )

        query = "SELECT user_id, email FROM users WHERE email = %s"
        user = execute_query(query, (email,))

        if not user:
            raise HTTPException(
                status_code=401,
                detail="User not found in database"
            )

        return user[0]

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=401,
            detail="Authentication failed"
        )