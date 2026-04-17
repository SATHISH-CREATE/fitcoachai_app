from .base import BaseRule

class PushupRule(BaseRule):
    def process(self, landmarks):
        # Indices: 11 (S), 13 (E), 15 (W)
        if not self.is_visible(landmarks, [11, 13, 15], 0.4):
            return {
                "counter": self.counter,
                "correct_reps": self.correct_reps,
                "stage": "Hidden",
                "feedback": "Step back for detection",
                "incorrect_indices": [],
                "visibility_ok": False,
                "current_angle": 0,
                "target_angle": 90
            }

        shoulder = landmarks[11]
        elbow = landmarks[13]
        wrist = landmarks[15]

        # Movement Consistency: In a pushup, the body moves but the hands are fixed on floor
        if not self.validate_motion(landmarks, [11, 23], [15, 16], sensitivity=0.01):
            self.feedback = "Keep your hands firm on the ground"
        
        angle = self.calculate_angle(shoulder, elbow, wrist)
        
        # Form Check: Back Alignment
        is_straight = True
        incorrect_indices = []
        if self.is_visible(landmarks, [11, 23, 25], 0.5):
            back_angle = self.calculate_angle(landmarks[11], landmarks[23], landmarks[25])
            if back_angle < 155:
                is_straight = False
                self.feedback = "Keep back straight!"
                incorrect_indices = [23]

        if angle > 160: # Full extension
            if self.stage == "down":
                self.counter += 1
                if is_straight:
                    self.correct_reps += 1
                    self.feedback = "Great pushup! Go again."
                else:
                    self.feedback = "Counted. Keep back straight!"
            self.stage = "up"

        if angle < 95 and self.stage == 'up': # Require deeper pushup
            self.stage = "down"
            if is_straight:
                self.feedback = "Perfect depth! Push up."
            
        return {
            "counter": self.counter,
            "correct_reps": self.correct_reps,
            "stage": self.stage,
            "feedback": self.feedback,
            "incorrect_indices": incorrect_indices,
            "current_angle": int(angle),
            "target_angle": 90
        }

class ChestPressRule(BaseRule):
    def process(self, landmarks):
        # 11 (S), 13 (E), 15 (W)
        if not self.is_visible(landmarks, [11, 13, 15], 0.6):
            return super().process(landmarks)
            
        shoulder = landmarks[11]
        elbow = landmarks[13]
        
        # Chest Press (Side/Front variation): Elbow moves behind then forward
        if elbow.x < shoulder.x - 0.05:
            self.stage = "down"
        if elbow.x > shoulder.x + 0.1 and self.stage == "down":
            self.stage = "up"
            self.counter += 1
            self.correct_reps += 1
            self.feedback = "Solid press!"
            
        # Form Check: Elbow height
        incorrect_indices = []
        if elbow.y < shoulder.y - 0.05:
            self.feedback = "Lower your elbows slightly"
            incorrect_indices = [13]

        # Calculate angle for UI feedback (Shoulder-Elbow-Wrist might be too noisy, 
        # so we use a relative position angle)
        wrist = landmarks[15]
        press_angle = self.calculate_angle(shoulder, elbow, wrist)

        return {
            "counter": self.counter,
            "correct_reps": self.correct_reps,
            "stage": self.stage,
            "feedback": self.feedback,
            "incorrect_indices": incorrect_indices,
            "current_angle": int(press_angle),
            "target_angle": 160
        }

class ChestFlyRule(BaseRule):
    def process(self, landmarks):
        # 15 (LW), 16 (RW)
        if not self.is_visible(landmarks, [15, 16], 0.6):
            return super().process(landmarks)
            
        l_wrist = landmarks[15]
        r_wrist = landmarks[16]
        
        # Fly: Wrists move toward each other
        dist = self.get_distance(l_wrist, r_wrist)
        
        if dist > 0.4:
            self.stage = "open"
        if dist < 0.15 and self.stage == "open":
            self.stage = "closed"
            self.counter += 1
            self.correct_reps += 1
            self.feedback = "Big squeeze!"
            
        if self.stage == "closed" and dist > 0.4:
            self.stage = "open"
            
        # Form Check: Symmetry
        incorrect_indices = []
        if abs(l_wrist.y - r_wrist.y) > 0.1:
            self.feedback = "Keep arms level!"
            incorrect_indices = [15, 16]

        # Map distance (0.15 to 0.4) to a pseudo-angle (0-180) for UI
        # 0.4 -> 0 (open), 0.15 -> 180 (closed)
        fly_angle = max(0, min(180, (0.4 - dist) * 720))

        return {
            "counter": self.counter,
            "correct_reps": self.correct_reps,
            "stage": self.stage,
            "feedback": self.feedback,
            "incorrect_indices": incorrect_indices,
            "current_angle": int(fly_angle),
            "target_angle": 170
        }
