from fastapi import HTTPException, Request
from fastapi.responses import JSONResponse

class AppException(Exception):
    """Base application exception."""
    def __init__(self, code: str, message: str, status_code: int = 500):
        self.code = code
        self.message = message
        self.status_code = status_code
        super().__init__(self.message)

class DatabaseError(AppException):
    def __init__(self, message: str = "A database error occurred."):
        super().__init__(code="DATABASE_ERROR", message=message, status_code=500)

class ExternalServiceError(AppException):
    def __init__(self, message: str = "An external service failed."):
        super().__init__(code="EXTERNAL_SERVICE_ERROR", message=message, status_code=502)

class ResourceNotFoundError(AppException):
    def __init__(self, message: str = "The requested resource was not found."):
        super().__init__(code="NOT_FOUND", message=message, status_code=404)

async def app_exception_handler(request: Request, exc: AppException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"error": {"code": exc.code, "message": exc.message}},
    )

async def global_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"error": {"code": "INTERNAL_SERVER_ERROR", "message": f"An unexpected error occurred: {str(exc)}"}},
    )
