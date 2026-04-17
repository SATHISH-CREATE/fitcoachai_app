import numpy as np

class BaseRule:
    def __init__(self):
        self.counter = 0
        self.correct_reps = 0
        self.stage = "Ready"
        self.feedback = "Get Ready"
        self.incorrect_indices = []
        self._last_angle = 0
        self.last_positions = {} # Store {index: (x, y)}

    def calculate_angle(self, a, b, c):
        """Calculate 2D angle between points a, b, c (b is vertex) to avoid Z-axis corruption."""
        a_vec = np.array([a.x, a.y])
        b_vec = np.array([b.x, b.y])
        c_vec = np.array([c.x, c.y])
        
        # Vectors from vertex
        ba = a_vec - b_vec
        bc = c_vec - b_vec
        
        # Cosine similarity for 2D angle
        cosine_angle = np.dot(ba, bc) / (np.linalg.norm(ba) * np.linalg.norm(bc) + 1e-6)
        angle = np.arccos(np.clip(cosine_angle, -1.0, 1.0))
        
        return np.degrees(angle)

    def calculate_3d_angle(self, a, b, c):
        """Calculate true 3D angle (Use ONLY with pose_world_landmarks)."""
        a_vec = np.array([a.x, a.y, a.z])
        b_vec = np.array([b.x, b.y, b.z])
        c_vec = np.array([c.x, c.y, c.z])
        
        ba = a_vec - b_vec
        bc = c_vec - b_vec
        
        cosine_angle = np.dot(ba, bc) / (np.linalg.norm(ba) * np.linalg.norm(bc) + 1e-6)
        angle = np.arccos(np.clip(cosine_angle, -1.0, 1.0))
        
        return np.degrees(angle)

    def get_distance(self, p1, p2):
        """Calculate 3D distance between two points."""
        return np.sqrt((p1.x - p2.x)**2 + (p1.y - p2.y)**2 + (p1.z - p2.z)**2)

    def is_visible(self, landmarks, indices, threshold=0.5):
        """Check if required landmarks meet the visibility threshold."""
        for idx in indices:
            if idx >= len(landmarks) or landmarks[idx].visibility < threshold:
                return False
        return True
    def is_vertical(self, p1, p2, tolerance=0.15):
        """Check if the line between p1 and p2 is roughly vertical in 3D space."""
        # Using 3D variance check for verticality
        return abs(p1.x - p2.x) < tolerance and abs(p1.z - p2.z) < tolerance

    def is_horizontal(self, p1, p2, tolerance=0.15):
        """Check if the line between p1 and p2 is roughly horizontal in 3D space."""
        # In 3D (assuming Y is up/down), horizontal means Y is similar.
        # We also check Z to ensure they are on the same depth plane if needed,
        # but for gravity-based horizontal, Y is the primary constraint.
        return abs(p1.y - p2.y) < tolerance

    def get_planar_distance(self, p1, p2, plane='xy'):
        """Calculate distance in a specific 2D projection plane."""
        if plane == 'xy':
            return np.sqrt((p1.x - p2.x)**2 + (p1.y - p2.y)**2)
        elif plane == 'xz':
            return np.sqrt((p1.x - p2.x)**2 + (p1.z - p2.z)**2)
        elif plane == 'yz':
            return np.sqrt((p1.y - p2.y)**2 + (p1.z - p2.z)**2)
        return self.get_distance(p1, p2)

    def process(self, landmarks):
        """Main processing method - override in subclasses."""
        # Generic visibility check (at least some body parts should be visible)
        if not self.is_visible(landmarks, [11, 12], 0.3) and not self.is_visible(landmarks, [23, 24], 0.3):
             return {
                "counter": self.counter,
                "correct_reps": self.correct_reps,
                "stage": "Hidden",
                "feedback": "Body not detected",
                "incorrect_indices": [],
                "visibility_ok": False
            }
            
        return {
            "counter": self.counter,
            "correct_reps": self.correct_reps,
            "stage": self.stage,
            "feedback": self.feedback,
            "incorrect_indices": [],
            "visibility_ok": True,
            "current_angle": 0,
            "target_angle": 0
        }

    def validate_motion(self, landmarks, active_indices, stable_indices, sensitivity=0.01):
        """
        Returns True if active_indices are moving MORE than stable_indices.
        Uses 3D coordinates for more accurate motion tracking.
        """
        is_valid = True
        active_motion = 0
        stable_motion = 0
        
        for idx in active_indices:
            if idx in self.last_positions:
                curr = landmarks[idx]
                prev = self.last_positions[idx]
                active_motion += abs(curr.x - prev[0]) + abs(curr.y - prev[1]) + abs(curr.z - prev[2])
            self.last_positions[idx] = (landmarks[idx].x, landmarks[idx].y, landmarks[idx].z)
            
        for idx in stable_indices:
            if idx in self.last_positions:
                curr = landmarks[idx]
                prev = self.last_positions[idx]
                stable_motion += abs(curr.x - prev[0]) + abs(curr.y - prev[1]) + abs(curr.z - prev[2])
            self.last_positions[idx] = (landmarks[idx].x, landmarks[idx].y, landmarks[idx].z)
            
        # If the 'stable' parts of the body are moving way more than the 'active' parts,
        if stable_motion > active_motion + sensitivity:
            is_valid = False
            
        return is_valid

