import numpy as np
import base64
import tempfile
import os
import time
import threading
from .rules import EXERCISE_RULES



# Lazy import MediaPipe and OpenCV to avoid 60s startup hang on some systems
mp = None
cv2 = None
mp_python = None
mp_vision = None
HAS_TASKS = False

def _lazy_load_deps():
    global mp, cv2, mp_python, mp_vision, HAS_TASKS
    if mp is None:
        import mediapipe as _mp
        mp = _mp
        try:
            from mediapipe.tasks import python as _mp_python
            from mediapipe.tasks.python import vision as _mp_vision
            mp_python = _mp_python
            mp_vision = _mp_vision
            HAS_TASKS = True
        except ImportError:
            HAS_TASKS = False
            
    if cv2 is None:
        import cv2 as _cv2
        cv2 = _cv2

class PoseAnalyzer:
    def __init__(self):
        # Path to model file
        model_path = os.path.join(os.path.dirname(__file__), '..', 'pose_landmarker.task')
        print(f"Loading Pose Landmarker model from: {model_path}")
        if not os.path.exists(model_path):
            print(f"CRITICAL ERROR: Model file not found at {model_path}")
            # Try fallback to absolute from root root
            root_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
            print(f"Files in {root_path}: {os.listdir(root_path)}")
        
        try:
            print("INFO: Skipping local MediaPipe initialization.")
            print("INFO: Mobile app uses MLKit locally, enabling landmarks only mode.")
            self.detector = None
        except Exception as e:
            pass
            
        self.detector_lock = threading.Lock()
        
        # Session state to handle multiple users on a single process (Render)
        self.sessions = {} # {user_id: {"exercise": str, "rule_engine": obj, "last_active": float}}
        self.timestamp_ms = 0

        # Pure rules engine mode (optimized for low-RAM deployment)

    def get_user_session(self, user_id, exercise_name):
        now = time.time()
        
        # Create session if none exists or exercise changed
        if user_id not in self.sessions or self.sessions[user_id]["exercise"] != exercise_name:
            rule_engine = self.create_rule_engine(exercise_name)
            self.sessions[user_id] = {
                "exercise": exercise_name,
                "rule_engine": rule_engine,
                "last_active": now
            }
        else:
            self.sessions[user_id]["last_active"] = now
            
        # Optional: Cleanup old sessions every 100 calls (approx 15 seconds of frames)
        if len(self.sessions) > 50: # Limit memory footprint
            expired = [uid for uid, s in self.sessions.items() if now - s["last_active"] > 600] # 10 min
            for uid in expired:
                del self.sessions[uid]
                
        return self.sessions[user_id]["rule_engine"]

    def create_rule_engine(self, exercise_name):
        if exercise_name in EXERCISE_RULES:
            return EXERCISE_RULES[exercise_name]()
        
        # 2. Try keyword fallback
        name_lower = exercise_name.lower()
        engine = None
        
        # Check keywords in order of specificity
        if "push-up" in name_lower or "pushup" in name_lower:
            engine = EXERCISE_RULES["Push-ups"]()
        elif "leg press" in name_lower:
            engine = EXERCISE_RULES["Squats"]()
        elif "calf raise" in name_lower:
            engine = EXERCISE_RULES["Standing Calf Raises"]()
        elif "press" in name_lower:
            if "overhead" in name_lower or "arnold" in name_lower or "shoulder" in name_lower:
                engine = EXERCISE_RULES["Overhead Barbell Press"]()
            else:
                engine = EXERCISE_RULES["Flat Barbell Bench Press"]()
        elif "curl" in name_lower:
            if "wrist" in name_lower:
                engine = EXERCISE_RULES["Wrist Curl (Palms Up)"]()
            elif "hammer" in name_lower:
                engine = EXERCISE_RULES.get("Hammer Curl", EXERCISE_RULES["Bicep Curl"])()
            else:
                engine = EXERCISE_RULES["Bicep Curl"]()
        elif "squat" in name_lower:
            engine = EXERCISE_RULES["Squats"]()
        elif "lunge" in name_lower:
            engine = EXERCISE_RULES["Lunges"]()
        elif "pull-up" in name_lower or "pullup" in name_lower or "chin-up" in name_lower or "chinup" in name_lower:
            engine = EXERCISE_RULES["Pull-ups"]()
        elif "pulldown" in name_lower:
            engine = EXERCISE_RULES["Pull-ups"]() # Pulldowns are vertical pulls
        elif "row" in name_lower or "face pull" in name_lower:
            engine = EXERCISE_RULES["Barbell Bent-Over Rows"]()
        elif "deadlift" in name_lower or "thrust" in name_lower or "bridge" in name_lower or "extension" in name_lower and "back" in name_lower:
            engine = EXERCISE_RULES["Deadlift"]()
        elif "raise" in name_lower:
            if "leg" in name_lower or "knee" in name_lower:
                engine = EXERCISE_RULES["Hanging Leg Raises"]()
            else:
                engine = EXERCISE_RULES["Dumbbell Lateral Raises"]()
        elif "shrug" in name_lower:
            engine = EXERCISE_RULES["Dumbbell Lateral Raises"]() # Shrugs use lateral raise logic (shoulder height)
        elif "fly" in name_lower or "crossover" in name_lower or "pec deck" in name_lower:
            engine = EXERCISE_RULES["Incline Cable Fly"]()
        elif "crunch" in name_lower or "sit-up" in name_lower or "twist" in name_lower:
            engine = EXERCISE_RULES["Crunches"]()
        elif "dip" in name_lower:
            engine = EXERCISE_RULES["Weighted Bench Dips"]()
        elif "extension" in name_lower or "pushdown" in name_lower or "kickback" in name_lower:
            engine = EXERCISE_RULES["Overhead Triceps Extension"]()
        elif "plank" in name_lower or "bug" in name_lower or "rollout" in name_lower or "hold" in name_lower:
            engine = EXERCISE_RULES["Plank"]()
        elif "clean" in name_lower or "snatch" in name_lower or "thruster" in name_lower or "maker" in name_lower or "get-up" in name_lower:
            engine = EXERCISE_RULES["Clean and Press"]()
        elif "burpee" in name_lower or "devil" in name_lower:
            engine = EXERCISE_RULES["Burpee Pull-Up"]()
        elif "carry" in name_lower:
            engine = EXERCISE_RULES["Overhead Barbell Press"]() # Track standing stability
        else:
            # Absolute fallback to Bicep Curl if nothing else matches (best effort)
            engine = EXERCISE_RULES["Bicep Curl"]()
            
        return engine

    def set_exercise(self, exercise_name):
        # Deprecated: use get_user_session instead
        pass

    def reset_analyzer(self):
        # Resetting the analyzer now means clearing all sessions
        self.sessions = {}
        self.timestamp_ms = 0

    def is_correct_exercise(self, landmarks, exercise_name):
        # General heuristic check to ensure the user is not doing completely the wrong exercise
        name = exercise_name.lower()
        if not landmarks or len(landmarks) < 33:
            return True, ""
            
        l_shldr, r_shldr = landmarks[11], landmarks[12]
        l_hip, r_hip = landmarks[23], landmarks[24]
        l_wrist, r_wrist = landmarks[15], landmarks[16]
        l_ankle, r_ankle = landmarks[27], landmarks[28]
        
        # Calculate vertical standing check (hips lower than shoulders on screen)
        # Using 3D Y-axis primary distance
        # Calculate vertical orientation based on the ratio of vertical distance to body length
        # This is more robust than a fixed 0.45 threshold which depends on distance to camera
        body_len = self.get_distance(l_shldr, l_ankle) if len(landmarks) > 28 else 1.0
        dy_shldr_hip = abs(l_shldr.y - l_hip.y)
        
        # If the vertical distance between shoulder and hip is less than 25% of body length, 
        # the person is likely lying down (horizontal).
        is_horizontal = dy_shldr_hip < (body_len * 0.25)
        
        # Fallback for depth-heavy views (User lying towards/away from camera)
        depth_drift = abs(l_shldr.z - l_hip.z)
        if depth_drift > 0.6:
            is_horizontal = True 
        
        horizontal_ex = ["push-up", "pushup", "plank", "bench", "row", "crunch", "twist"]
        if any(x in name for x in horizontal_ex) and not is_horizontal:
            return False, "Lie down horizontally for this exercise!"
            
        vertical_ex = ["squat", "curl", "press", "raise", "lunge", "deadlift", "shrug", "jack", "calf"]
        if any(x in name for x in vertical_ex) and "bench" not in name and is_horizontal:
            return False, "Stand up vertically for this exercise!"
            
        return True, ""

    def process_landmarks(self, landmarks_list, exercise_name, user_id="default"):
        rule_engine = self.get_user_session(user_id, exercise_name)
        
        # Convert list of dicts to objects with attributes for the rule engine
        class Landmark:
            def __init__(self, d):
                self.x = d.get('x', 0)
                self.y = d.get('y', 0)
                self.z = d.get('z', 0)
                # Handle both MediaPipe (visibility) and ML Kit (likelihood)
                self.visibility = d.get('visibility', d.get('likelihood', 0.5))

        landmarks = [Landmark(l) for l in landmarks_list]

        feedback_data = {
            "exercise": exercise_name,
            "rep_count": 0,
            "correct_reps": 0,
            "form": "N/A",
            "feedback": "Ready",
            "landmarks": landmarks_list,
            "incorrect_indices": [],
            "is_correct": True,
            "visibility_ok": True,
            "smart_feedback": ""
        }

        if rule_engine:
            # Ensure the user isn't doing a completely different exercise archetype
            is_valid, err_msg = self.is_correct_exercise(landmarks, exercise_name)
            if not is_valid:
                feedback_data.update({
                    "rep_count": rule_engine.counter,
                    "correct_reps": rule_engine.correct_reps,
                    "form": "Wrong Ex.",
                    "feedback": err_msg,
                    "incorrect_indices": [],
                    "is_correct": False,
                    "visibility_ok": True,
                    "accuracy": (rule_engine.correct_reps / rule_engine.counter * 100) if rule_engine.counter > 0 else 0
                })
                return feedback_data

            # ============================================================
            # STEP 1: ALWAYS run rule engine first (rep counting is sacred)
            # The rules engine runs on EVERY frame — it is fast.
            # ============================================================
            analysis = rule_engine.process(landmarks)
            incorrect = analysis.get("incorrect_indices", [])
            is_correct = len(incorrect) == 0
            current_stage = analysis.get("stage", "N/A")
            
            # Strictness Check: If the movement doesn't match the exercise type at all,
            # we should avoid high-confidence feedback.
            # (Subclasses can implement specific logic, but here we use the feedback from rules)
            
            feedback_data.update({
                "rep_count": analysis.get("counter", 0),
                "correct_reps": analysis.get("correct_reps", 0),
                "form": current_stage,
                "feedback": analysis.get("feedback", ""),
                "incorrect_indices": incorrect,
                "is_correct": is_correct,
                "current_angle": analysis.get("current_angle", analysis.get("angle", 0)),
                "target_angle": analysis.get("target_angle", analysis.get("target", 0)),
                "visibility_ok": analysis.get("visibility_ok", True),
                "accuracy": (analysis.get("correct_reps", 0) / analysis.get("counter", 1) * 100) if analysis.get("counter", 0) > 0 else 0
            })

            feedback_data["smart_feedback"] = analysis.get("feedback", "")

            print(f"DEBUG: Feedback for {exercise_name}: Reps={feedback_data['rep_count']}, Angle={feedback_data['current_angle']}")
        
        return feedback_data


    def process_frame(self, image_data, exercise_name):
        _lazy_load_deps()
        if not self.detector:
            return {"feedback": "Server vision model not loaded", "visibility_ok": False}
            
        # Decode base64 image
        if isinstance(image_data, str) and "," in image_data:
            image_data = image_data.split(",")[1]
            nparr = np.frombuffer(base64.b64decode(image_data), np.uint8)
            frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        else:
            frame = image_data

        if frame is None:
            return None

        self.set_exercise(exercise_name)

        # Convert to RGB as required by MediaPipe Solutions
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Detect landmarks
        with self.detector_lock:
            results = self.detector.process(rgb_frame)

        feedback_data = {
            "exercise": exercise_name,
            "rep_count": 0,
            "correct_reps": 0,
            "form": "N/A",
            "feedback": "No body detected",
            "landmarks": []
        }

        if results.pose_landmarks:
            # Convert to list of dicts for frontend-compatible format
            landmarks_list = []
            for lm in results.pose_landmarks.landmark:
                landmarks_list.append({
                    "x": lm.x, 
                    "y": lm.y, 
                    "z": lm.z, 
                    "visibility": lm.visibility
                })
            
            return self.process_landmarks(landmarks_list, exercise_name)

        return feedback_data

    def analyze_video(self, video_path, exercise_name):
        _lazy_load_deps()
        self.set_exercise(exercise_name)
        cap = cv2.VideoCapture(video_path)
        
        total_reps = 0
        correct_reps = 0
        mistakes = []
        fps = cap.get(cv2.CAP_PROP_FPS) or 30
        frame_timestamp_ms = 0
        
        while cap.isOpened():
            ret, frame = cap.read()
            if not ret:
                break
            
            frame_timestamp_ms += 1000 // int(fps)
            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            if self.detector:
                results = self.detector.process(rgb_frame)
            else:
                results = None

            if results and results.pose_landmarks and self.get_user_session("temp", exercise_name):
                # We need to bridge to a list of dicts for consistency
                landmarks_list = []
                for lm in results.pose_landmarks.landmark:
                    landmarks_list.append({
                        "x": lm.x, "y": lm.y, "z": lm.z, "visibility": lm.visibility
                    })
                
                # We reuse the process_landmarks logic but only for internal analysis updates
                res = self.process_landmarks(landmarks_list, exercise_name, "temp")
                total_reps = res.get("rep_count", 0)
                correct_reps = res.get("correct_reps", 0)
                feedback = res.get("feedback", "")
                if feedback and "good" not in feedback.lower() and "ready" not in feedback.lower():
                    if feedback not in mistakes:
                        mistakes.append(feedback)

        cap.release()
        
        accuracy = f"{round((correct_reps / total_reps * 100), 2)}%" if total_reps > 0 else "0%"
        
        return {
            "total_reps": total_reps,
            "correct_reps": correct_reps,
            "accuracy": accuracy,
            "mistakes_summary": mistakes
        }
