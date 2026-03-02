# Security & QA Audit Report — AI Powered Meal Planner
**Date:** 2026-03-03
**Scope:** Backend (FastAPI/Python) + Frontend (Flutter/Dart)
**Audited by:** Claude Code (automated static analysis)

---

## Summary

| Severity | Count | Fixed |
|----------|-------|-------|
| CRITICAL | 3     | ✅ All fixed |
| HIGH     | 5     | ✅ All fixed |
| MEDIUM   | 6     | ✅ All fixed |
| LOW      | 2     | ✅ All fixed |
| **Total**| **16**| **✅ 16 / 16** |

---

## CRITICAL

### C-1 — `.env` committed without `.gitignore`
**File:** `backend/` (root)
**Risk:** The `.env` file containing `SECRET_KEY`, `DATABASE_PASSWORD`, and other credentials has no `.gitignore` protection. A single `git add .` or IDE auto-commit would push secrets to version control (local or remote).
**Fix:** Created `backend/.gitignore` that excludes `.env`, `__pycache__/`, `*.pyc`, `venv/`, `.venv/`.

---

### C-2 — CORS wildcard combined with `allow_credentials=True`
**File:** `backend/main.py:13-17`
**Risk:** `allow_origins=["*"]` with `allow_credentials=True` is an invalid combination per the CORS spec. Browsers refuse to honour credentialled requests to wildcard origins. The JWT tokens in this app travel in the `Authorization` header (not cookies), so `allow_credentials=True` provides no benefit and creates a misleading/broken security posture.
**Fix:** Removed `allow_credentials=True` from the CORS middleware.

---

### C-3 — `SECRET_KEY` can be `None` at startup
**File:** `backend/utils/auth_helper.py:10`
**Risk:** `SECRET_KEY = os.getenv('SECRET_KEY')` returns `None` if the variable is missing from `.env`. `python-jose` may silently sign tokens with `None`, producing tokens that appear valid but are trivially forgeable.
**Fix:** Added a startup-time check — `raise RuntimeError` if `SECRET_KEY` is not set, preventing the app from starting with an insecure configuration.

---

## HIGH

### H-1 — No password length cap (bcrypt DoS)
**File:** `backend/models/user.py:8`
**Risk:** bcrypt's work factor applies to the full password bytes up to the platform limit. Sending a 1 MB password triggers expensive hashing on every `/auth/login` or `/auth/register` call, enabling a CPU-exhaustion denial-of-service.
**Fix:** Added `Field(min_length=8, max_length=100)` to `UserRegister.password`.

---

### H-2 — Unbounded date range in progress endpoint
**File:** `backend/routes/tracking.py:82-94`
**Risk:** `GET /tracking/progress?start_date=2000-01-01&end_date=2030-12-31` scans the entire `meal_logs` table for a user over a multi-decade range, causing large memory allocations and slow queries.
**Fix:** Added a 90-day maximum range check — returns HTTP 400 if exceeded.

---

### H-3 — `json.loads()` without error handling
**File:** `backend/routes/meal_plan.py:76,102`
**Risk:** If a meal plan's `plan_data` column is corrupt or truncated in MySQL, `json.loads()` raises `json.JSONDecodeError`, which FastAPI surfaces as an unhandled 500 with a Python traceback potentially leaking internal paths.
**Fix:** Wrapped both `json.loads()` calls in `try/except json.JSONDecodeError` returning a clean HTTP 500.

---

### H-4 — `new_meal_data` not schema-validated
**File:** `backend/models/meal_plan.py:20`, `backend/routes/meal_plan.py:107`
**Risk:** `MealUpdate.new_meal_data: Dict[str, Any]` accepts any arbitrary dict from the user and writes it directly into the stored meal plan JSON. Attackers can inject unexpected keys, very large strings, or malformed values.
**Fix:** Replaced `Dict[str, Any]` with a typed `MealData` Pydantic model enforcing `name`, `calories`, `protein`, `carbs`, `fats`, `serving` with appropriate bounds.

---

### H-5 — `meal_type` field accepts arbitrary strings
**File:** `backend/models/meal_log.py:7`, `backend/models/meal_plan.py:19`
**Risk:** Any string is accepted as `meal_type` (e.g., `"'; DROP TABLE meal_logs; --"`). While parameterised queries prevent SQL injection here, inconsistent values break sorting, filtering, and the suggestion engine.
**Fix:** Changed both to `Literal['breakfast', 'lunch', 'dinner', 'snack']`.

---

## MEDIUM

### M-1 — Calories and macro fields have no bounds
**File:** `backend/models/meal_log.py:9-13`
**Risk:** A user can log `calories=-100` or `calories=9999999`. Negative values corrupt totals; impossibly large values distort averages and charts.
**Fix:** Added `Field(ge=0, le=10000)` for calories and `Field(ge=0, le=1000)` for protein/carbs/fats.

---

### M-2 — `food_items` has no max length
**File:** `backend/models/meal_log.py:8`
**Risk:** No length cap allows storing megabyte-sized strings in the database `TEXT` column, wasting storage and slowing list queries.
**Fix:** Added `Field(min_length=1, max_length=500)`.

---

### M-3 — Profile fields have no value bounds
**File:** `backend/models/user.py:23-31`
**Risk:** `age=-5`, `weight=0`, `height=10000` are accepted and silently passed to the BMR/TDEE formula, producing nonsensical calorie targets.
**Fix:** Added sensible bounds: `age` 13–120, `weight` 1–500 kg, `height` 50–300 cm, `name` max 100 chars.

---

### M-4 — `duration_days` has no upper bound
**File:** `backend/models/meal_plan.py:7`
**Risk:** `duration_days=3650` (10 years) triggers the AI engine to generate a 10-year meal plan, consuming significant CPU and memory.
**Fix:** Added `Field(ge=1, le=30)`.

---

### M-5 — `StorageService.clearAll()` wipes onboarding flag
**File:** `meal_planner_app/lib/services/storage_service.dart:70-74`
**Risk:** `prefs.clear()` removes all SharedPreferences including `onboarded` and `dark_mode`. After logout, users are sent through the onboarding flow again and lose their dark mode preference.
**Fix:** Changed `clearAll()` to only remove `user_email` from SharedPreferences (and delete both secure-storage tokens). The `onboarded` and `dark_mode` keys are preserved.

---

### M-6 — Error state and empty state show the same UI in Progress screen
**File:** `meal_planner_app/lib/screens/insights/progress_screen.dart:192-194`
**Risk:** A network error (401, 500, no internet) and a genuinely empty dataset both display "No Data Yet — Start logging meals". Users cannot tell whether the app failed to load or they simply have no data.
**Fix:** Added a separate error widget that shows the error message with a Retry button when `_errorMessage` is non-empty.

---

## LOW

### L-1 — `execute_query` errors logged with `print()`
**File:** `backend/database/connection.py:34,48`
**Risk:** `print()` outputs to stdout which may appear in process logs, but errors are silently swallowed and returned as `None`. Callers see confusing 500 errors with no server-side context.
**Fix:** Changed `print()` to Python `logging` module calls (`logging.error()`), which integrates with uvicorn's log stream and can be redirected/filtered in production.

---

### L-2 — Weight validation duplicated in endpoint body
**File:** `backend/routes/tracking.py:348-349`
**Risk:** Manual if-checks in the route handler are easy to miss or bypass. Pydantic field validators run earlier and give consistent 422 responses.
**Fix:** Moved weight bounds (`gt=0, le=600`) into the `WeightLog` Pydantic model, and removed the manual check from the endpoint.

---

## No-Action Items (Noted for Awareness)

| Item | Reason no fix applied |
|------|-----------------------|
| Rate limiting on `/auth/login` | Requires `slowapi` package install + Redis or in-memory store. Architectural decision for deployment. Recommended for production. |
| JWT token revocation (logout blacklist) | Requires stateful token store (Redis). Complexity exceeds FYP scope. Current 24-hour expiry is acceptable for mobile app. |
| HTTPS enforcement | Deployment concern — handled at reverse proxy (nginx/Caddy). Not a code-level fix. |
| Backend URL hardcoded in `constants.dart` | Already fixed in a previous session using `--dart-define=BASE_URL`. |

---

## Files Modified

| File | Changes |
|------|---------|
| `backend/.gitignore` | **CREATED** — excludes `.env`, `__pycache__`, `*.pyc`, `venv/` |
| `backend/main.py` | Removed `allow_credentials=True` from CORS middleware |
| `backend/utils/auth_helper.py` | Added startup `RuntimeError` if `SECRET_KEY` is missing |
| `backend/database/connection.py` | Replaced `print()` with `logging.error()` |
| `backend/models/user.py` | Added `Field` bounds for password, age, weight, height, name |
| `backend/models/meal_log.py` | Added `Literal` for meal_type; `Field` bounds for all numeric/string fields |
| `backend/models/meal_plan.py` | Added `Field(ge=1,le=30)` for duration_days; `Literal` for meal_type; `MealData` schema for new_meal_data |
| `backend/routes/tracking.py` | Added 90-day date range cap; moved weight bounds to model |
| `backend/routes/meal_plan.py` | Wrapped `json.loads()` in try/except; use `.model_dump()` for `MealData` |
| `meal_planner_app/lib/services/storage_service.dart` | Fixed `clearAll()` to preserve `onboarded` + `dark_mode` |
| `meal_planner_app/lib/screens/insights/progress_screen.dart` | Added separate error state with Retry button |
