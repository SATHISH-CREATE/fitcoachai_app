from .base import BaseRule

class SquatRule(BaseRule):
    def process(self, landmarks):
        # MediaPipe Indices:
        # Left side: 23 (H), 25 (K), 27 (A)
        # Right side: 24 (H), 26 (K), 28 (A)
        
        # Check visibility for both sides
        l_vis = self.is_visible(landmarks, [23, 25, 27], 0.3)
        r_vis = self.is_visible(landmarks, [24, 26, 28], 0.3)
        
        if not l_vis and not r_vis:
            return {
                "counter": self.counter,
                "correct_reps": self.correct_reps,
                "stage": "Hidden",
                "feedback": "Step back for full body detection",
                "incorrect_indices": [],
                "visibility_ok": False,
                "current_angle": 0,
                "target_angle": 120
            }

        # Choose best side
        l_score = landmarks[25].visibility if l_vis else 0
        r_score = landmarks[26].visibility if r_vis else 0
        
        if r_score > l_score:
            hip, knee, ankle = landmarks[24], landmarks[26], landmarks[28]
            side_indices = [24, 26, 28]
        else:
            hip, knee, ankle = landmarks[23], landmarks[25], landmarks[27]
            side_indices = [23, 25, 27]
        
        # Movement Consistency: Hips move more than upper body
        if not self.validate_motion(landmarks, [side_indices[0]], [11, 12, 13, 14], sensitivity=0.015):
            self.feedback = "Focus on the squat movement"
        
        angle = self.calculate_angle(hip, knee, ankle)
        
        # State machine
        if angle > 158: # Standing straight - relaxed from 160
            if self.stage == 'down':
                self.counter += 1
                self.correct_reps += 1
                self.feedback = "Great rep! Stay steady."
            self.stage = "up"
            
        # Form Check: Knee Stability
        k_a_dist = abs(knee.x - ankle.x)
        is_stable = k_a_dist < 0.18 # More tolerant 
        
        incorrect_indices = []
        if not is_stable and angle < 120: 
            incorrect_indices = [side_indices[1]]
            self.feedback = "Knees too far forward!"

        if angle < 120 and self.stage == 'up': # Relaxed from 110
            self.stage = "down"
            if is_stable:
                self.feedback = "Good depth, now push up!"
            else:
                self.feedback = "Fix form: keep hips back"
            
        if self.stage == "down" and angle > 155:
            self.stage = "up"

        return {
            "counter": self.counter,
            "correct_reps": self.correct_reps,
            "stage": self.stage,
            "feedback": self.feedback,
            "incorrect_indices": incorrect_indices,
            "current_angle": int(angle),
            "target_angle": 120
        }


class LungeRule(BaseRule):
    def process(self, landmarks):
        # 23 (H), 25 (K), 27 (A)
        if not self.is_visible(landmarks, [23, 25, 27], 0.4):
            return super().process(landmarks)
            
        hip = landmarks[23]
        knee = landmarks[25]
        ankle = landmarks[27]
        
        angle = self.calculate_angle(hip, knee, ankle)
        
        if angle > 160:
            self.stage = "up"

        # Form Check: Knee alignment (3D depth aware)
        is_stable = self.get_planar_distance(knee, ankle, plane='xz') < 0.25
        incorrect_indices = []
        if not is_stable:
            incorrect_indices = [25]
            self.feedback = "Keep knee behind toes"

        if angle < 110 and self.stage == "up":
            if is_stable:
                self.stage = "down"
                self.counter += 1
                self.correct_reps += 1
                self.feedback = "Deep lunge!"
            else:
                self.stage = "down"
                self.feedback = "Fix form: knee forward"
            
        if self.stage == "down" and angle > 160:
            self.stage = "up"
            if "Fix" not in self.feedback:
                self.feedback = "Switch legs or repeat"
            
        return {
            "counter": self.counter,
            "correct_reps": self.correct_reps,
            "stage": self.stage,
            "feedback": self.feedback,
            "incorrect_indices": incorrect_indices,
            "current_angle": angle,
            "target_angle": 110
        }


class CalfRaiseRule(BaseRule):
    def process(self, landmarks):
        # 27 (A), 31 (Heel), 32 (Toe)
        if not self.is_visible(landmarks, [31, 32], 0.3):
            return super().process(landmarks)
            
        heel = landmarks[31]
        toe = landmarks[32]
        
        # Calf raise: Heel rises relative to toe
        # stage detection based on Y difference
        diff = toe.y - heel.y
        
        if diff < 0.02:
            self.stage = "down"
        if diff > 0.05 and self.stage == "down":
            self.stage = "up"
            self.counter += 1
            self.correct_reps += 1
            self.feedback = "High on toes!"
            
        # Map height diff to a pseudo-angle (0-90) for the UI to show progress
        pseudo_angle = min(90, max(0, diff * 1000))
        
        return {
            "counter": self.counter,
            "correct_reps": self.correct_reps,
            "stage": self.stage,
            "feedback": self.feedback,
            "incorrect_indices": [],
            "current_angle": int(pseudo_angle),
            "target_angle": 50
        }
