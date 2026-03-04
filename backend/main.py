from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
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

# ── Friendly validation error messages ────────────────────────────────────────
_FIELD_MESSAGES: dict[str, str] = {
    'email':         'Please enter a valid email address.',
    'password':      'Password must be between 8 and 100 characters.',
    'age':           'Age must be between 13 and 120 years.',
    'weight':        'Weight must be between 1 and 500 kg.',
    'height':        'Height must be between 50 and 300 cm.',
    'name':          'Name must be 100 characters or fewer.',
    'calories':      'Calories must be between 0 and 10,000.',
    'protein':       'Protein must be between 0 and 1,000 g.',
    'carbs':         'Carbs must be between 0 and 1,000 g.',
    'fats':          'Fats must be between 0 and 1,000 g.',
    'food_items':    'Food description must be between 1 and 500 characters.',
    'meal_type':     'Meal type must be one of: breakfast, lunch, dinner, or snack.',
    'duration_days': 'Plan duration must be between 1 and 30 days.',
    'weight_kg':     'Weight must be between 0 and 600 kg.',
}

@app.exception_handler(RequestValidationError)
async def validation_exception_handler(_request, exc: RequestValidationError):
    messages = []
    for error in exc.errors():
        field = str(error.get('loc', [''])[-1])
        friendly = _FIELD_MESSAGES.get(field)
        if friendly:
            messages.append(friendly)
        else:
            # Fall back to Pydantic's msg with the "Value error, " prefix stripped
            msg = error.get('msg', 'Invalid input.')
            msg = msg.replace('Value error, ', '')
            messages.append(msg)

    return JSONResponse(
        status_code=422,
        content={'detail': ' '.join(messages) if messages else 'Invalid input.'},
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
