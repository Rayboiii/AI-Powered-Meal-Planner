from fastapi import FastAPI, Header
from fastapi.middleware.cors import CORSMiddleware
from routes import auth, profile, meal_plan, tracking
from typing import Optional

app = FastAPI(
    title="AI Meal Planner API",
    description="Backend API for AI-powered meal planning application",
    version="1.0.0"
)

# CORS middleware for Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Change this to specific origins in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(auth.router)
app.include_router(profile.router)
app.include_router(meal_plan.router)
app.include_router(tracking.router)

@app.get("/")
async def root():
    return {
        "message": "AI Meal Planner API",
        "version": "1.0.0",
        "status": "running"
    }

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

@app.get("/debug/token")
async def debug_token(authorization: Optional[str] = Header(None)):
    """Debug endpoint to check token"""
    if not authorization:
        return {"error": "No authorization header"}
    
    try:
        scheme, token = authorization.split()
        return {
            "scheme": scheme,
            "token_length": len(token),
            "token_preview": token[:20] + "...",
            "expected_scheme": "Bearer"
        }
    except:
        return {"error": "Invalid header format", "received": authorization}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)