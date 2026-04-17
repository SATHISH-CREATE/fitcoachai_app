from .base import BaseRule

class CardioRule(BaseRule):
    """
    General purpose rule for high-intensity cardio movements like Jumping Jacks, 
    High Knees, and Butt Kicks. Tracks rapid rhythmic changes.
    """
    def process(self, landmarks):
        if not landmarks or len(landmarks) < 33:
            return super().process(landmarks)

        # We track vertical oscillation of the center of mass (hips)
        l_hip, r_hip = landmarks[23], landmarks[24]
        l_ankle, r_ankle = landmarks[27], landmarks[28]
        
        avg_hip_y = (l_hip.y + r_hip.y) / 2
        avg_ankle_y = (l_ankle.y + r_ankle.y) / 2
        
        # relative height of hips normalized by ankle position
        rel_height = avg_ankle_y - avg_hip_y

        # Detect jumping/high-impact phase
        if rel_height > 0.65: # Peak of movement (standing tall or mid-jump)
            if self.stage == "low":
                self.stage = "high"
                self.counter += 1
                self.correct_reps += 1
                self.feedback = "Keep the tempo!"
        else: # Landing or compression phase
            self.stage = "low"

        return {
            "counter": self.counter,
            "correct_reps": self.correct_reps,
            "stage": self.stage,
            "feedback": self.feedback,
            "incorrect_indices": []
        }
