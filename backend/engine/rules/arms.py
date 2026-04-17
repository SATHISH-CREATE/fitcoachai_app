from .base import BaseRule

class BicepCurlRule(BaseRule):
    def process(self, landmarks):
        # MediaPipe Indices:
        # Left: 11 (S), 13 (E), 15 (W)
        # Right: 12 (S), 14 (E), 16 (W)
        
        # Check visibility for both sides
        left_visible = self.is_visible(landmarks, [11, 13, 15], 0.25)
        right_visible = self.is_visible(landmarks, [12, 14, 16], 0.25)
        
        if not left_visible and not right_visible:
            return {
                "counter": self.counter,
                "correct_reps": self.correct_reps,
                "stage": "Hidden",
                "feedback": "Step back for full body detection",
                "incorrect_indices": [],
                "visibility_ok": False
            }

        # Calculate angles for both sides to see which is more "active"
        l_shoulder, l_elbow, l_wrist = landmarks[11], landmarks[13], landmarks[15]
        r_shoulder, r_elbow, r_wrist = landmarks[12], landmarks[14], landmarks[16]
        
        l_angle = self.calculate_angle(l_shoulder, l_elbow, l_wrist)
        r_angle = self.calculate_angle(r_shoulder, r_elbow, r_wrist)
        
        # Determine active side (prefer visible side, then more flexed side)
        if right_visible and (not left_visible or r_angle < l_angle - 10):
            angle = r_angle
            shoulder, elbow, wrist = r_shoulder, r_elbow, r_wrist
            side_indices = [12, 14, 16]
        else:
            angle = l_angle
            shoulder, elbow, wrist = l_shoulder, l_elbow, l_wrist
            side_indices = [11, 13, 15]
        
        # Movement Consistency: In a curl, the wrist should move more than the hips
        if not self.validate_motion(landmarks, [side_indices[2]], [23, 24], sensitivity=0.015):
            self.feedback = "Stay stable! Too much body movement."
        
        # State machine with Hysteresis window to avoid noise jitter counts
        # Extension (Bottom Position)
        if angle > 160:
            self.stage = "down"
        
        # Form check: Elbow drift
        is_stable = self.is_vertical(shoulder, elbow, tolerance=0.25)
        incorrect_indices = []
        if not is_stable and angle < 140: # Only warn if actively curling
            incorrect_indices = [side_indices[1]] # Highlight elbow
            self.feedback = "Keep elbow fixed at side!"

        # Grip Check: Bicep Curl should be supinated (Palms facing up/forward)
        # Using 3D distance between thumb and pinky to detect palm rotation
        is_right = side_indices[2] == 16
        pinky = landmarks[18] if is_right else landmarks[17]
        thumb = landmarks[22] if is_right else landmarks[21]
        
        # In 3D, supinated grip usually means thumb is laterally away from pinky 
        # but also potentially at a different depth.
        grip_dist = self.get_distance(thumb, pinky)
        is_supinated = grip_dist > 0.03 # 3D threshold for spread hand/turned palm

        # Flexion (Top Position) - Trigger Rep
        # Relaxed from 55 to 65 to handle more users/noise
        if angle < 65 and self.stage == 'down':
            self.stage = "up"
            self.counter += 1
            
            if not is_supinated:
                self.feedback = "Counted! Tip: Turn palms UP more."
                incorrect_indices.extend([15, 16])
            elif is_stable:
                self.correct_reps += 1
                self.feedback = f"Great Curl! Count: {self.counter}"
            else:
                self.feedback = "Good work, but watch your elbow"
            
        if self.stage == "up" and angle > 150:
            self.stage = "down"
            if "Tip:" not in self.feedback and "watch" not in self.feedback:
                self.feedback = "Lower fully and repeat"

        return {
            "counter": self.counter,
            "correct_reps": self.correct_reps,
            "stage": self.stage,
            "feedback": self.feedback,
            "incorrect_indices": incorrect_indices,
            "current_angle": int(angle),
            "target_angle": 35
        }

class HammerCurlRule(BaseRule):
    def process(self, landmarks):
        # Check visibility for both sides
        left_visible = self.is_visible(landmarks, [11, 13, 15], 0.25)
        right_visible = self.is_visible(landmarks, [12, 14, 16], 0.25)
        
        if not left_visible and not right_visible:
            return {
                "counter": self.counter,
                "correct_reps": self.correct_reps,
                "stage": "Hidden",
                "feedback": "Step back for full body detection",
                "incorrect_indices": [],
                "visibility_ok": False
            }

        l_shoulder, l_elbow, l_wrist = landmarks[11], landmarks[13], landmarks[15]
        r_shoulder, r_elbow, r_wrist = landmarks[12], landmarks[14], landmarks[16]
        
        l_angle = self.calculate_angle(l_shoulder, l_elbow, l_wrist)
        r_angle = self.calculate_angle(r_shoulder, r_elbow, r_wrist)
        
        # Determine active side (prefer visible side, then more flexed side)
        if right_visible and (not left_visible or r_angle < l_angle - 10):
            angle = r_angle
            shoulder, elbow, wrist = r_shoulder, r_elbow, r_wrist
            side_indices = [12, 14, 16]
        else:
            angle = l_angle
            shoulder, elbow, wrist = l_shoulder, l_elbow, l_wrist
            side_indices = [11, 13, 15]
        
        if not self.validate_motion(landmarks, [side_indices[2]], [23, 24], sensitivity=0.015):
            self.feedback = "Stay stable! Too much body movement."
        
        if angle > 145:
            self.stage = "down"
        
        is_stable = self.is_vertical(shoulder, elbow, tolerance=0.25)
        incorrect_indices = []
        if not is_stable and angle < 140:
            incorrect_indices = [side_indices[1]]
            self.feedback = "Keep elbow fixed at side!"

        # Hammer Curl Grip Check (Neutral, smaller spreads)
        is_right = side_indices[2] == 16
        pinky = landmarks[18] if is_right else landmarks[17]
        thumb = landmarks[22] if is_right else landmarks[21]
        
        grip_dist = self.get_distance(thumb, pinky)
        is_hammer = grip_dist < 0.04

        # Relaxed from 60 to 70 for hammer curls
        if angle < 70 and self.stage == 'down':
            self.stage = "up"
            self.counter += 1
            
            if not is_hammer:
                self.feedback = "Counted! Tip: Keep palms IN."
                incorrect_indices.extend([15, 16])
            elif is_stable:
                self.correct_reps += 1
                self.feedback = f"Great Hammer! Count: {self.counter}"
            else:
                self.feedback = "Good work, but watch your elbow"
            
        if self.stage == "up" and angle > 145:
            self.stage = "down"
            if "Tip:" not in self.feedback and "watch" not in self.feedback:
                self.feedback = "Lower fully and repeat"

        return {
            "counter": self.counter,
            "correct_reps": self.correct_reps,
            "stage": self.stage,
            "feedback": self.feedback,
            "incorrect_indices": incorrect_indices,
            "current_angle": int(angle),
            "target_angle": 35
        }


class WristCurlRule(BaseRule):
    def process(self, landmarks):
        # 15 (W), 17 (P/Hand), 13 (E) - Simplified wrist flexion
        if not self.is_visible(landmarks, [13, 15], 0.6):
            return super().process(landmarks)
            
        elbow = landmarks[13]
        wrist = landmarks[15]
        
        # Wrist curls are small movements; tracking angle change in forearm
        # stage detection based on wrist Y relative to elbow
        if wrist.y > elbow.y:
            self.stage = "down"
        if wrist.y < elbow.y - 0.05 and self.stage == "down":
            self.stage = "up"
            self.counter += 1
            self.correct_reps += 1
            self.feedback = "Squeeze forearms!"
            
        return {
            "counter": self.counter,
            "correct_reps": self.correct_reps,
            "stage": self.stage,
            "feedback": self.feedback,
            "incorrect_indices": [],
            "current_angle": 0,
            "target_angle": 0
        }
