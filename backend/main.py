from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import auth, profile, meal_plan, tracking

app = FastAPI(
    title="AI Meal Planner API",
    description="Backend API for AI-powered meal planning application",
    version="1.0.0"
)

# CORS middleware for Flutter app
# JWT travels in the Authorization header — credentials=True is not needed
# and is invalid with a wildcard origin per the CORS spec.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
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

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

    