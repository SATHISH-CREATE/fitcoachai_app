import time
print("Importing mediapipe...")
start = time.time()
import mediapipe as mp
print(f"Mediapipe imported in {time.time() - start:.2f}s")

print("Importing fastapi...")
start = time.time()
from fastapi import FastAPI
print(f"FastAPI imported in {time.time() - start:.2f}s")

print("All imports successful!")
