# GymAI (FitCoach AI)

A comprehensive AI-powered fitness coaching mobile application built with Flutter and FastAPI.

## Project Name

**Gym AI Flutter** (also referred to as "FitCoach AI" in the app title)

---

## Architecture

This is a **full-stack mobile application** with:
- **Frontend**: Flutter mobile app (iOS & Android)
- **Backend**: Python FastAPI server
- **Database**: Supabase (PostgreSQL + Auth)

---

## Technologies Used

### Frontend (Mobile)

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.11+ |
| Language | Dart |
| State Management | Riverpod |
| Routing | GoRouter |
| UI | Material Design with Glassmorphism |
| Fonts | Google Fonts (Outfit) |
| Icons | Cupertino Icons |

**Key Dependencies:**
- `supabase_flutter` - Database & Auth
- `google_sign_in` - Google OAuth
- `flutter_pose_detection` - Pose estimation (MediaPipe 3D)
- `camera` - Camera access
- `flutter_tts` / `speech_to_text` - Voice features
- `flutter_map` - Maps for gym finder
- `pdf` / `printing` - PDF generation
- `pedometer` - Step counting
- `youtube_player_iframe` - Video content
- `webview_flutter` - Web content
- `geolocator` - Location services
- `flutter_local_notifications` - Push notifications
- `shared_preferences` - Local storage
- `intl` - Internationalization
- `glassmorphism_ui` - Glassmorphism UI components
- `image_picker` - Image selection
- `confetti` - Celebration animations

### Backend (API)

| Category | Technology |
|----------|------------|
| Framework | FastAPI |
| Server | Uvicorn |
| AI/ML | Google Gemini AI |
| Pose Analysis | MediaPipe + OpenCV |
| Environment | python-dotenv |

**Python Dependencies:**
- fastapi
- uvicorn
- opencv-python-headless
- mediapipe
- numpy
- python-multipart
- google-generativeai
- python-dotenv

---

## Features Implemented

1. **Authentication** - Supabase Auth + Google Sign-in
2. **User Profile** - Setup, profile management
3. **Dashboard** - Overview with stats
4. **Exercise Library** - Exercise database by category
5. **AI Coach** - Gemini-powered chat for fitness advice
6. **Workout Tracking** - Real-time pose detection & form correction (3D MediaPipe)
7. **Warmup/Workout Sessions** - Guided exercise flows
8. **Workout Summary** - Stats, calories, accuracy tracking
9. **Schedule** - Workout scheduling
10. **Gym Finder** - Map-based gym discovery
11. **Calculators** - BMI, calorie, macro calculators
12. **Diet Plan Generator** - AI-generated 7-day meal plans
13. **Library** - Content/resources
14. **Voice Features** - TTS (Text-to-Speech) & STT (Speech-to-Text)

---

## Pose Detection (3D Upgrade)

The app uses **MediaPipe Pose Landmarker** for real-time 3D pose detection.

### Before vs After

| Aspect | Old (Google ML Kit) | New (MediaPipe 3D) |
|--------|-------------------|-------------------|
| Type | 2D | True 3D |
| Depth | Approximate z | worldZ (world coordinates) |
| Hardware | TFLite only | NPU + GPU + CPU |
| Inference | ~30ms | ~13-16ms (with NPU) |
| Consistency | Different from backend | Same as backend |

### How It Works

- Mobile: `flutter_pose_detection` - Real-time camera pose detection
- Backend: `mediapipe` - Video analysis & exercise validation
- Both use same MediaPipe 3D landmarks for consistency

---

## Development Setup

### Prerequisites

- Flutter SDK 3.11+
- Python 3.8+
- Node.js (for Supabase CLI - optional)
- Supabase account (for database/auth)

### Backend Setup

```bash
cd backend
pip install -r requirements.txt
python main.py
```

The backend runs on **port 8086** by default.

**Environment Variables (.env):**
```
GEMINI_API_KEY=your_api_key_here
GEMINI_API_KEY_2=optional_additional_key
# Add more keys for load balancing
```

### Mobile Setup

```bash
cd mobile
flutter pub get
flutter run
```

### Running Both Services

On Windows, you can use the provided batch file:
```bash
run_all.bat
```

---

## Project Structure

```
gym_ai_flutter/
├── mobile/                 # Flutter app
│   ├── lib/
│   │   ├── core/          # Services, theme, utils
│   │   ├── features/      # Feature modules (auth, workout, etc.)
│   │   └── shared/        # Shared widgets and models
│   ├── android/           # Android platform files
│   ├── ios/               # iOS platform files
│   └── pubspec.yaml       # Flutter dependencies
│
├── backend/               # FastAPI backend
│   ├── main.py           # API endpoints
│   ├── engine/            # Pose analysis engine
│   ├── utils/            # Utility functions
│   ├── requirements.txt  # Python dependencies
│   └── venv/             # Virtual environment
│
├── run_all.bat           # Run both mobile and backend
├── update_ip.py          # Update backend IP address
└── zip_project.py        # Archive project
```

---

## License

MIT License
