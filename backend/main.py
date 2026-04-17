import sys
import os

# Ensure the current directory is at the front of the Python path
current_dir = os.path.dirname(os.path.abspath(__file__))
if current_dir not in sys.path:
    sys.path.insert(0, current_dir)

# Debug logging for Render environment
print(f"DEPLOY DEBUG: sys.path is {sys.path}")
print(f"DEPLOY DEBUG: files in {current_dir}: {os.listdir(current_dir)}")

from fastapi import FastAPI, HTTPException, Body, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import Optional, List
from engine.analyzer import PoseAnalyzer
import google.generativeai as genai
from dotenv import load_dotenv
import uvicorn
import shutil
import os
import tempfile

load_dotenv()

# ========== MULTI-KEY ROTATION ENGINE ==========
# Load all Gemini API keys from .env (GEMINI_API_KEY_1, _2, _3, etc.)
ALL_API_KEYS = []
for i in range(1, 10):
    key = os.environ.get(f"GEMINI_API_KEY_{i}")
    if key:
        ALL_API_KEYS.append(key)

# Also check legacy single key
legacy_key = os.environ.get("GEMINI_API_KEY")
if legacy_key and legacy_key not in ALL_API_KEYS:
    ALL_API_KEYS.append(legacy_key)

current_key_index = 0
model = None

def _init_model_with_key(key_index):
    """Initialize Gemini model with the key at the given index."""
    global model, current_key_index
    if not ALL_API_KEYS:
        print("FitCoachAI: NO API KEYS FOUND. AI features disabled.")
        model = None
        return
    current_key_index = key_index % len(ALL_API_KEYS)
    key = ALL_API_KEYS[current_key_index]
    masked = key[:10] + "..." + key[-4:]
    try:
        genai.configure(api_key=key)
        model = genai.GenerativeModel('gemini-2.0-flash')
        print(f"FitCoachAI: Initialized with key #{current_key_index + 1} ({masked}) -> gemini-2.0-flash")
    except Exception as e:
        print(f"FitCoachAI ERROR: Key #{current_key_index + 1} failed: {e}")
        try:
            model = genai.GenerativeModel('gemini-flash-lite-latest')
            print(f"FitCoachAI: Fallback to gemini-flash-lite-latest with key #{current_key_index + 1}")
        except Exception as fallback_error:
            print(f"FitCoachAI ERROR: All models failed: {fallback_error}")
            model = None

def rotate_key_and_retry():
    """Switch to the next API key. Returns True if a new key is available."""
    global current_key_index
    if len(ALL_API_KEYS) <= 1:
        return False
    next_index = (current_key_index + 1) % len(ALL_API_KEYS)
    print(f"FitCoachAI: Rotating from key #{current_key_index + 1} -> #{next_index + 1}")
    _init_model_with_key(next_index)
    return model is not None

def safe_generate(prompt, generation_config=None):
    """Call model.generate_content with automatic key failover on errors."""
    global model
    if not model:
        return {"error": "no_model", "message": "API key not configured"}
    
    for attempt in range(len(ALL_API_KEYS)):
        try:
            if generation_config:
                result = model.generate_content(prompt, generation_config=generation_config)
                return result
            else:
                result = model.generate_content(prompt)
                return result
        except Exception as e:
            err_str = str(e)
            print(f"FitCoachAI: Generation failed (Key #{current_key_index + 1}): {err_str[:150]}")
            
            # Check for quota exhaustion - specific handling
            if "quota" in err_str.lower() or "exceeded" in err_str.lower() or "RESOURCE_EXHAUSTED" in err_str:
                print(f"FitCoachAI: QUOTA EXHAUSTED for key #{current_key_index + 1}, rotating...")
                if not rotate_key_and_retry():
                    return {"error": "quota_exhausted", "message": "All API keys quota exhausted. Please add new keys in .env"}
                continue
            
            # Try falling back to the lite model before abandoning the key
            try:
                print("FitCoachAI: Retrying with gemini-flash-lite-latest...")
                lite_model = genai.GenerativeModel('gemini-2.0-flash')
                if generation_config:
                    return lite_model.generate_content(prompt, generation_config=generation_config)
                else:
                    return lite_model.generate_content(prompt)
            except Exception as lite_e:
                lite_err = str(lite_e)
                print(f"FitCoachAI: Lite version also failed: {lite_err[:150]}")
                
                if "quota" in lite_err.lower() or "exceeded" in lite_err.lower():
                    if not rotate_key_and_retry():
                        return {"error": "quota_exhausted", "message": "All API keys quota exhausted"}
                    continue
            
            if not rotate_key_and_retry():
                return {"error": "all_keys_failed", "message": "All API keys failed"}
    
    return {"error": "max_retries", "message": "Max retries exceeded"}

# Initialize with the first available key
print(f"FitCoachAI: {len(ALL_API_KEYS)} API key(s) loaded for rotation.")
if ALL_API_KEYS:
    _init_model_with_key(0)
else:
    print("FitCoachAI: WARNING - No API keys found in .env!")
    model = None
# ================================================

class DietInput(BaseModel):
    user_profile: dict
    calorie_goal: int
    macros: dict
    diet_type: Optional[str] = "Standard"
    include_whey: Optional[bool] = False
    target_weight: Optional[float] = None

app = FastAPI(title="AI Gym Backend")

# Enable CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class FrameInput(BaseModel):
    image: str
    exercise: str

class ChatInput(BaseModel):
    message: str
    context: Optional[dict] = None

class LandmarksInput(BaseModel):
    user_id: str
    landmarks: List[dict]
    exercise: str

analyzer = PoseAnalyzer()

# Serve frontend static files
# We mount this at the end to avoid blocking other API routes
frontend_path = os.path.join(os.path.dirname(current_dir), "frontend")

@app.get("/health")
async def health():
    return {"status": "ok"}

# API Routes
@app.post("/chat")
async def chat_with_ai(input_data: ChatInput):
    """
    Handle AI coaching queries.
    Uses Google Gemini LLM with a heuristic fallback if API key is missing.
    """
    message = input_data.message.strip()
    context = input_data.context or {}
    user_profile = context.get("user_profile", {})
    user_name = user_profile.get("name", "there")
    history = context.get("history", [])
    
    # Keyword-based fallback response (useful if Gemini is offline or no key)
    kb = {
        "progressive overload": "Progressive overload is the foundation of muscle growth! It means gradually increasing the stress placed on your body during exercise.",
        "squat": "For perfect squats: Keep your feet shoulder-width apart, chest up, and sit back into your hips until thighs are parallel to the ground.",
        "bench press": "Bench press tips: Retract your shoulder blades, keep feet flat, and lower the bar to mid-chest under control.",
        "diet": "A solid diet focuses on high protein (1.8g-2.2g per kg), complex carbs for energy, and healthy fats.",
        "protein": "Protein is vital for muscle repair. Aim for 20-40g per meal from sources like chicken, eggs, or lentils.",
        "recovery": "Muscle grows while you rest! Aim for 7-9 hours of sleep and stay hydrated.",
        "form": "Perfect form is better than heavy weight. Focus on the mind-muscle connection."
    }

    # If Gemini is configured, use it
    if model:
        try:
            print(f"AI COACH DEBUG: Model is ACTIVE. Processing for {user_name}")
            print(f"AI COACH DEBUG: User Message: {message}")
            
            # Construct a more comprehensive system-like prompt
            chat_context = (
                f"You are the 'FIT COACH AI' Master Coach. Your user is {user_name}. Goal: {user_profile.get('goal', 'Fitness')}.\n"
                "INSTRUCTIONS: Provide elite, specific fitness/gym advice. Concise but punchy (max 4 sentences)."
            )
            
            prompt = f"{chat_context}\n\nUser: {message}\nCoach:"
            print("AI COACH DEBUG: Calling FitCoachAI with key rotation...")
            response = safe_generate(prompt)
            if response and isinstance(response, object) and hasattr(response, 'text'):
                print("AI COACH DEBUG: FitCoachAI Response Success!")
                return {
                    "response": response.text.strip(),
                    "model_type": "fitcoachai"
                }
            elif response and isinstance(response, dict):
                # Error response from safe_generate
                print(f"AI COACH ERROR: {response.get('message', 'Unknown')}")
        except Exception as e:
            err_str = str(e)
            print(f"AI COACH CRITICAL ERROR: All keys failed: {err_str}")
            # Fall through to the manual kb fallback for other transient errors
    else:
        print("AI COACH DEBUG: model is NONE. Check your API key.")
    
    # --- BROAD HEURISTIC FALLBACK (Keyword Logic) ---
    msg_low = message.lower()
    
    # Enhanced Knowledge Base for broad coverage
    kb = {
        "progressive overload": "Progressive overload is the holy grail of gains! It means gradually increasing weight, reps, or intensity to keep challenging your muscles.",
        "squat": "Master your squat: Bar across traps, feet shoulder-width, break at hips first, and descend until thighs are parallel. Drive hard through your heels.",
        "bench press": "For a bigger bench: Retract your scapula, keep a slight arch, and touch the bar to your lower chest before pressing up with total control.",
        "deadlift": "Deadlift form: Shins close to the bar, back flat, chest up. Pull the weight by pushing your feet into the floor, keeping the bar close to your legs.",
        "diet": "Nutrition is 70% of the game. Focus on a diet with adequate protein and a slight calorie surplus/deficit. Prioritize whole foods.",
        "food": "Food is your fuel! Prioritize lean proteins, complex carbs, and healthy fats. Stay away from heavily processed sugars.",
        "meal": "A balanced meal keeps you energized. Make sure every meal has a solid protein source (like chicken, eggs, or lentils) and ample veggies.",
        "protein": "Aim for 1.8g to 2.2g of protein per kg of bodyweight. Space it across 4-5 meals to keep muscle protein synthesis high.",
        "fat loss": "To lose fat, maintain a consistent caloric deficit while keeping protein high to preserve muscle. Add steady-state cardio and stay consistent.",
        "bulking": "When bulking, a 200-300 calorie surplus is usually enough to gain muscle without excessive fat. Focus on heavy compound movements.",
        "recovery": "You don't grow in the gym; you grow in your sleep. Aim for 8 hours of quality rest and manage stress to keep cortisol low.",
        "pre-workout": "A good pre-workout meal has complex carbs (oats/rice) and some protein, eaten 1-2 hours before training.",
        "creatine": "Creatine monohydrate is the most researched supplement. 5g a day will help with ATP production and power output.",
        "form": "Correct form is non-negotiable. It prevents injury and ensures the target muscle is actually doing the work.",
        "abs": "Abs are revealed in the kitchen but built in the gym with weighted crunches and leg raises. Don't skip your core work!"
    }

    # Check for direct matches
    for key, response in kb.items():
        if key in msg_low:
            return {"response": f"Hey {user_name}, {response}", "model_type": "standard"}

    # Greeting logic
    if any(greet in msg_low for greet in ["hello", "hi", "hey"]):
        return {"response": f"Hey {user_name}! I'm your FIT COACH AI. I can help with form tips, diet advice, or training concepts. What's on your mind?", "model_type": "standard"}

    if "thank" in msg_low:
        return {"response": f"You're very welcome, {user_name}! Keep pushing those limits.", "model_type": "standard"}

    # Generic fallback
    return {"response": f"That's a good training question about {message}, {user_name}. To give you the best advice, are you asking about form, frequency, or nutrition?", "model_type": "standard"}

@app.post("/generate_diet")
async def generate_diet_plan(input_data: DietInput):
    """
    Generate a full personalized meal plan using AI, or offline fallback.
    """
    
    profile = input_data.user_profile
    goal_cals = input_data.calorie_goal
    macros = input_data.macros
    target_weight = input_data.target_weight or profile.get('target_weight')
    current_weight = profile.get('weight', 'N/A')
    gender = profile.get('gender', 'person')
    
    diet_type = (input_data.diet_type or "Standard").lower()
    include_whey = input_data.include_whey or False
    
    if "veg" in diet_type and "non" not in diet_type:
        diet_pref = "STRICTLY VEGETARIAN. FATAL ERROR IF MEAT, FISH, OR CHICKEN IS INCLUDED. USE ONLY PLANT-BASED PROTEIN (DAHL, PANEER, TOFU, SOYA)."
    elif diet_type == "non-veg":
        diet_pref = "Non-Vegetarian (Include Lean Meats, Eggs, Chicken, Fish)"
    else:
        diet_pref = "Standard/Balanced (High Protein, varied sources)"
    
    if include_whey:
        whey_instr = "IMPORTANT: Include exactly 1-2 scoops of Whey Protein in the plan. Mention 'Whey Protein' clearly in the meal names."
    else:
        whey_instr = "STRICTLY PROHIBITED: Do NOT include Whey Protein, protein powder, or any supplements. Use ONLY whole food sources (Dal, Paneer, Chicken, etc.)."

    prompt = (
        f"Generate a professional, elite 7-DAY meal plan (Day 1 through Day 7) for a {gender} "
        f"who currently weighs {current_weight}kg and has a target weight of {target_weight}kg.\n"
        f"The plan must be specifically optimized to reach that target weight of {target_weight}kg starting from {current_weight}kg.\n"
        f"Primary Goal: {profile.get('goal', 'Fitness')}.\n"
        f"DIET PREFERENCE: {diet_pref}.\n"
        f"SUPPLEMENT RULES: {whey_instr}.\n"
        f"DAILY TARGETS: {goal_cals} kcal | P: {macros.get('p')}g | C: {macros.get('c')}g | F: {macros.get('f')}g.\n\n"
        "INSTRUCTIONS:\n"
        "1. MANDATORY: You must generate a FULL 7-DAY PLAN starting from DAY 1 through DAY 7.\n"
        "2. Structure each day with headers: --- DAY 1 ---, --- DAY 2 ---, up to --- DAY 7 ---.\n"
        "3. NEVER use generic terms; use ONLY real food names and specific portions.\n"
        "4. ZERO REPETITION: The food items should NOT repeat across the week. If Day 1 is Chicken, Day 2 should be Fish, Day 3 should be Lean Beef or Soya, etc. Variety is mandatory for every meal (Breakfast, Lunch, Dinner).\n"
        "5. Include a CORE HYDRATION RULE for every single day: 'Drink 4.2 Liters of Water minimum!'.\n"
        "6. Maintain the total daily calories and macros mentioned above for every single day without repeating the meals.\n"
    )
    
    try:
        if not model:
            raise Exception("No API Keys configured. Forcing offline fallback.")

        print(f"FITCOACH AI: Generating 7-Day Plan for {profile.get('goal')}...")
        response = safe_generate(
            prompt,
            generation_config={
                "candidate_count": 1,
                "max_output_tokens": 4096,
                "temperature": 0.7,
            }
        )
        if response and isinstance(response, object) and hasattr(response, 'text'):
            return {"plan": response.text.strip()}
        elif response and isinstance(response, dict):
            print(f"Diet AI Error: {response.get('message', 'Unknown')}")
            raise Exception(response.get('message', 'AI generation failed'))
        raise Exception("No valid response from AI")
    except Exception as e:
        err_str = str(e)
        print(f"Diet Generation AI Error: {err_str}")
        
        goal = profile.get('goal', 'Fitness').upper()
        target_p = int(macros.get('p', 150))
        target_c = int(macros.get('c', 200))
        target_f = int(macros.get('f', 60))
        
        # Personalized portions based on user's macros
        protein_per_meal = target_p / 4
        carbs_per_meal = target_c / 3
        fats_per_meal = target_f / 3
        
        chicken_g = int(protein_per_meal * 4)
        paneer_g = int(protein_per_meal * 4)
        egg_count = max(2, int(protein_per_meal / 6))
        rice_g = int(carbs_per_meal * 4)
        oats_g = int(carbs_per_meal * 4)
        
        is_veg = "veg" in diet_type and "non" not in diet_type
        print(f"DEBUG: diet_type is {diet_type}, is_veg={is_veg}") # Log for debugging
        
        diet_str = f"FITCOACH AI (Personalized 7-Day Plan)\nHYDRATION: Drink 4.2 Liters of Water daily!\n\n"

        
        days = ["MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY", "SUNDAY"]
        
        meals_bank = {
            "breakfast": [
                f"{egg_count} Eggs (Boiled) + {oats_g}g Oats + 1 Banana",
                f"{paneer_g}g Paneer + {oats_g}g Oats + 1 Apple",
                f"Greek Yogurt ({paneer_g}g) + 30g Almonds + 1 Apple",
                f"{egg_count} Egg Whites + {rice_g}g Rice + 1 Banana",
                f"Moong Dal Chilla + {oats_g}g Oats + 1 Orange",
                f"Muesli with Skimmed Milk + 10 Walnuts",
                f"Tofu Scramble + Whole Wheat Toast"
            ] if is_veg else [
                f"{egg_count} Eggs + {oats_g}g Oats + 1 Banana",
                f"{chicken_g}g Grilled Chicken + {oats_g}g Oats + 1 Apple",
                f"Greek Yogurt + 30g Almonds + 1 Apple",
                f"{egg_count} Egg Whites + {rice_g}g Rice + 1 Banana",
                f"3 Egg Omlette + 2 Slices Whole Wheat Bread",
                f"Chicken Sausage + 2 Boiled Eggs + 1 Pear",
                f"Smoked Salmon + Scrambled Eggs + 1 Orange"
            ],
            "lunch": [
                f"{paneer_g}g Tofu + {rice_g}g Rice + Veggies",
                f"{paneer_g}g Paneer Curry + 2 Roti + Salad",
                f"{paneer_g}g Soya chunks + {rice_g}g Rice + Salad",
                f"{paneer_g}g Paneer + {rice_g}g Rice + Veg",
                f"Chickpea Salad with Quinoa and Lemon",
                f"Lentil Soup (Dal) + 2 Rotis + Curd",
                f"Mixed Veg Khichdi + Roasted Papad + Salad"
            ] if is_veg else [
                f"{chicken_g}g Chicken + {rice_g}g Rice + Veggies",
                f"{chicken_g}g Fish Curry + {rice_g}g Rice + Salad",
                f"{chicken_g}g Egg Curry + {rice_g}g Rice + Salad",
                f"{chicken_g}g Grilled Chicken + {rice_g}g Quinoa + Veg",
                f"{chicken_g}g Turkey Breast + Steamed Broccoli + {rice_g}g Rice",
                f"{chicken_g}g Lean Beef Mince + 2 Rotis + Salad",
                f"{chicken_g}g Roasted Prawns + Brown Rice + Peppers"
            ],
            "dinner": [
                f"{paneer_g}g Paneer + steamed broccoli + 1 Roti",
                f"{paneer_g}g Tofu + salad + {int(rice_g*0.5)}g Rice",
                f"{paneer_g}g Cottage Cheese + mixed veggies + 1 Roti",
                f"Lentil Soup + salad + steamed veggies",
                f"Roasted Cauliflower and Chickpeas + 1 Roti",
                f"Lauki (Bottle Gourd) Kofta + {int(rice_g*0.5)}g Rice",
                f"Stuffed Capsicum with Cottage Cheese + Salad"
            ] if is_veg else [
                f"{chicken_g}g Grilled Chicken + salad + {int(rice_g*0.5)}g Rice",
                f"{chicken_g}g Fish + steamed broccoli + 1 Roti",
                f"{egg_count} Eggs + salad + {int(rice_g*0.5)}g Rice",
                f"{chicken_g}g Chicken + mixed veggies + 1 Roti",
                f"{chicken_g}g Grilled Fish + Roasted Asparagus + 1 Roti",
                f"{chicken_g}g Chicken Stew with Carrots and Peas",
                f"{chicken_g}g Soya chunks stir-fry with Peppers"
            ],
            "snack": [
                "1 Apple + Green Tea",
                "30g Almonds + 1 Orange",
                "Greek Yogurt + 1 Apple",
                "Roasted Makhana (Foxnuts)",
                "2 Walnuts + 1 Pear",
                "Sprouted Moong Salad",
                "Protein Shake / 2 Boiled Eggs"
            ]
        }
        
        for i, day in enumerate(days):
            diet_str += f"--- {day} ---\n"
            diet_str += f"Breakfast: {meals_bank['breakfast'][i]}\n"
            diet_str += f"Snack: {meals_bank['snack'][i]}\n"
            diet_str += f"Lunch: {meals_bank['lunch'][i]}\n"
            diet_str += f"Dinner: {meals_bank['dinner'][i]}\n\n"

        return {"plan": diet_str}


@app.post("/reset")
async def reset_session():
    try:
        analyzer.reset_analyzer()
        return {"message": "Session reset successful"}
    except Exception as e:
        print(f"Error resetting session: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/process_landmarks")
async def process_landmarks(input_data: LandmarksInput):
    # print(f"DEBUG: Received landmarks for exercise '{input_data.exercise}' from user '{input_data.user_id}'")
    try:
        feedback = analyzer.process_landmarks(input_data.landmarks, input_data.exercise, input_data.user_id)
        return feedback
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"CRITICAL ERROR processing landmarks for user {input_data.user_id}: {e}")
        # Return a safe fallback rather than crashing
        return {"feedback": "AI Engine Busy", "rep_count": 0, "is_correct": True}

@app.post("/process_frame")
async def process_frame(input_data: FrameInput):
    try:
        feedback = analyzer.process_frame(input_data.image, input_data.exercise)
        if feedback is None:
            raise HTTPException(status_code=400, detail="Invalid image data")
        return feedback
    except Exception as e:
        print(f"Error processing frame: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/upload_video")
async def upload_video(exercise: str = Form(...), file: UploadFile = File(...)):
    try:
        # Create temp file
        with tempfile.NamedTemporaryFile(delete=False, suffix=".mp4") as tmp:
            shutil.copyfileobj(file.file, tmp)
            tmp_path = tmp.name
        
        result = analyzer.analyze_video(tmp_path, exercise)
        
        # Cleanup
        os.remove(tmp_path)
        
        return result
    except Exception as e:
        print(f"Error uploading video: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Mount the entire frontend directory for other assets (js, css, images)
if os.path.exists(frontend_path):
    app.mount("/", StaticFiles(directory=frontend_path, html=True), name="frontend")

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8086))
    uvicorn.run(app, host="0.0.0.0", port=port)
