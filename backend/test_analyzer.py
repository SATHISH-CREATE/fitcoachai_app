import cv2
import numpy as np
import os
import sys

# Add current dir to path
sys.path.append(os.getcwd())

from engine.analyzer import PoseAnalyzer

def test_init():
    print("Testing PoseAnalyzer initialization...")
    try:
        analyzer = PoseAnalyzer()
        print("Initialization successful!")
        
        # Create a dummy black frame
        frame = np.zeros((480, 640, 3), dtype=np.uint8)
        
        print("Testing process_frame with dummy image...")
        feedback = analyzer.process_frame(frame, "Bicep Curl")
        print(f"Feedback: {feedback.get('feedback', 'No feedback')}")
        
    except Exception as e:
        print(f"FAILED: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    test_init()
