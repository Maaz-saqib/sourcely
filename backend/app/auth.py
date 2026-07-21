"""
JWT Authentication middleware for Sourcely backend.
Validates Supabase Auth JWT tokens from the Authorization header.
"""

from fastapi import Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.database import get_supabase_client


security = HTTPBearer()


async def verify_jwt(
    credentials: HTTPAuthorizationCredentials = Depends(security),
) -> dict:
    token = credentials.credentials
    supabase = get_supabase_client()
    
    try:
        # Use Supabase's official method to validate the token securely
        response = supabase.auth.get_user(token)
        if response and response.user:
            return {"sub": response.user.id}
        else:
            raise HTTPException(status_code=401, detail="Invalid or expired token")
    except Exception as e:
        print(f"JWT VALIDATION ERROR: {str(e)}")
        # Fallback: if offline, you can technically decode without verification
        # but this is safer since Supabase issues ES256 tokens now
        raise HTTPException(status_code=401, detail=f"Auth error: {str(e)}")


def get_user_id(payload: dict = Depends(verify_jwt)) -> str:
    """Extract user_id from the verified JWT payload."""
    user_id = payload.get("sub")
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid token: no user ID")
    return user_id
