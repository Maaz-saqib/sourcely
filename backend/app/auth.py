"""
JWT Authentication middleware for Sourcely backend.
Validates Supabase Auth JWT tokens from the Authorization header.
"""

import jwt
from fastapi import Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.config import get_settings


security = HTTPBearer()


async def verify_jwt(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    """
    Verify the JWT token from the Authorization header.
    Returns the decoded token payload containing user_id and other claims.
    Raises HTTPException 401 if token is invalid or expired.
    """
    settings = get_settings()
    token = credentials.credentials

    try:
        payload = jwt.decode(
            token,
            settings.supabase_jwt_secret,
            algorithms=["HS256"],
            options={"verify_aud": False},
        )
        return payload
    except jwt.ExpiredSignatureError:
        print("JWT EXPIRED")
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError as e:
        print(f"JWT INVALID: {str(e)}")
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")
    except Exception as e:
        print(f"JWT UNKNOWN ERROR: {str(e)}")
        raise HTTPException(status_code=401, detail=f"Auth error: {str(e)}")


def get_user_id(payload: dict = Depends(verify_jwt)) -> str:
    """Extract user_id from the verified JWT payload."""
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token: no user ID")
    return user_id
