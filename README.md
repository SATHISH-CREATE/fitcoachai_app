# FitCoach AI - Flutter Mobile Application

A comprehensive AI-powered fitness coaching application built with Flutter and FastAPI.

---

## Abstract

FitCoach AI is a mobile fitness application that combines artificial intelligence with computer vision to provide personalized workout guidance. The app features real-time 3D pose detection using MediaPipe for exercise form correction, voice command control for hands-free workout management, an AI-powered fitness coach powered by Google Gemini, personalized diet plan generation, gym discovery with location services, and comprehensive fitness tracking including step counting and workout history.

I built this app because I wanted to solve a common problem - most fitness apps either track workouts OR provide coaching, but rarely both with intelligent feedback. By combining pose detection, voice commands, and AI coaching in a single application, users get a personal trainer experience without the high cost.

The technical implementation uses Flutter for cross-platform mobile development, FastAPI with Python for the backend services, MediaPipe 3D pose estimation for body tracking, and Google Gemini AI for natural language interactions. The app supports both gym-based equipment workouts and bodyweight exercises.

**Keywords:** AI Fitness Coach, Pose Detection, MediaPipe, Computer Vision, Voice Commands, Workout Tracking, Diet Planning, Flutter, FastAPI, Gemini AI, Mobile Fitness, Real-time Form Correction, Personal Training, Health Tracking, Gym Discovery

---

## Project Overview

| Property | Value |
|----------|-------|
| **Project Name** | gym_ai_flutter |
| **App Name** | FitCoach AI |
| **Package** | com.gymai.fitcoach |
| **Flutter SDK** | ^3.11.0 |
| **Dart Version** | >=3.0.0 <4.0.0 |
| **Backend** | Python FastAPI |
| **Database** | Supabase (PostgreSQL + Auth) |
| **AI/ML** | Google Gemini AI, MediaPipe 3D Pose |

---

## Architecture

**Pattern:** Feature-based Clean Architecture with Riverpod

### Layers:
1. **Presentation Layer** - UI components (Screens, Widgets)
2. **Business Logic Layer** - State management (Providers)
3. **Data Layer** - External services (API, Storage, Supabase)

### Folder Structure per Feature:
```
features/
  └── feature_name/
      └── presentation/
          ├── screens/
          │   └── feature_screen.dart
          ├── widgets/
          │   └── feature_widget.dart
          └── providers/
              └── feature_provider.dart
```

---

## Complete Project Structure

```
gym_ai_flutter/
├── mobile/                          # Flutter mobile application
│   ├── lib/
│   │   ├── main.dart              # App entry point & routing
│   │   ├── core/
│   │   │   ├── network/
│   │   │   │   └── api_constants.dart    # API endpoints & URLs
│   │   │   ├── services/
│   │   │   │   ├── api_service.dart              # HTTP client for backend
│   │   │   │   ├── exercise_data_service.dart    # Exercise data management
│   │   │   │   ├── notification_service.dart      # Local notifications
│   │   │   │   ├── storage_service.dart           # SharedPreferences wrapper
│   │   │   │   ├── supabase_service.dart          # Supabase auth/database
│   │   │   │   └── voice_service.dart             # TTS & STT services
│   │   │   ├── theme/
│   │   │   │   ├── app_colors.dart               # Color palette
│   │   │   │   └── app_theme.dart               # ThemeData & styling
│   │   │   └── utils/
│   │   │       ├── web_utils.dart               # Platform-conditional exports
│   │   │       ├── web_utils_web.dart           # Web-specific utils
│   │   │       └── web_utils_stub.dart          # Mobile stub
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   └── presentation/
│   │   │   │       ├── providers/
│   │   │   │       │   └── auth_provider.dart    # Auth state management
│   │   │   │       └── screens/
│   │   │   │           └── login_screen.dart    # Login/Signup UI
│   │   │   ├── coach/
│   │   │   │   └── presentation/
│   │   │   │       ├── screens/
│   │   │   │       │   └── coach_screen.dart    # Coach page wrapper
│   │   │   │       └── widgets/
│   │   │   │           └── coach_chat_widget.dart  # AI chat interface
│   │   │   ├── calculators/
│   │   │   │   └── presentation/
│   │   │   │       └── screens/
│   │   │   │           └── calculators_screen.dart  # Body fat, diet, nutrition calculators
│   │   │   ├── dashboard/
│   │   │   │   └── presentation/
│   │   │   │       └── screens/
│   │   │   │           ├── dashboard_screen.dart  # Main home screen
│   │   │   │           └── steps_screen.dart      # Step tracking screen
│   │   │   ├── exercises/
│   │   │   │   └── presentation/
│   │   │   │       └── screens/
│   │   │   │           └── exercises_screen.dart   # Exercise browser
│   │   │   ├── gyms/
│   │   │   │   └── presentation/
│   │   │   │       └── screens/
│   │   │   │           └── gyms_screen.dart         # Nearby gyms finder
│   │   │   ├── library/
│   │   │   │   └── presentation/
│   │   │   │       └── screens/
│   │   │   │           └── library_screen.dart      # Exercise library grid
│   │   │   ├── onboarding/
│   │   │   │   └── presentation/
│   │   │   │       └── screens/
│   │   │   │           └── landing_video_screen.dart  # Landing page
│   │   │   ├── profile/
│   │   │   │   └── presentation/
│   │   │   │       └── screens/
│   │   │   │           └── profile_screen.dart      # User profile & settings
│   │   │   ├── schedules/
│   │   │   │   └── presentation/
│   │   │   │       └── screens/
│   │   │   │           └── schedules_screen.dart    # Weekly workout planner
│   │   │   ├── setup/
│   │   │   │   └── presentation/
│   │   │   │       └── screens/
│   │   │   │           └── setup_screen.dart        # Onboarding setup
│   │   │   └── workout/
│   │   │       └── presentation/
│   │   │           └── screens/
│   │   │               ├── warmup_screen.dart       # Pre-workout warmup
│   │   │               ├── workout_screen.dart       # Main workout with pose detection
│   │   │               └── workout_summary_screen.dart  # Post-workout results
│   │   └── shared/
│   │       ├── models/
│   │       │   └── notification_model.dart   # Notification data model
│   │       ├── providers/
│   │       │   └── notifications_provider.dart  # Notifications state
│   │       ├── utils/
│   │       │   ├── auth_utils.dart      # Auth helper utilities
│   │       │   └── image_utils.dart    # Image utilities
│   │       └── widgets/
│   │           ├── app_background.dart  # Background widgets
│   │           ├── buttons.dart         # Custom button components
│   │           ├── floating_ai_coach.dart  # Floating AI coach FAB
│   │           ├── glass_card.dart     # Glass morphism cards
│   │           └── main_layout.dart    # Main navigation shell
│   ├── assets/
│   │   ├── exercises.json          # Exercise database
│   │   ├── images/
│   │   │   ├── download.png
│   │   │   ├── icon.png
│   │   │   ├── icon1.png
│   │   │   ├── icon2.png
│   │   │   ├── landing_video.mp4
│   │   │   ├── logo.png
│   │   │   └── welcome.png
│   ├── android/                   # Android native code
│   ├── ios/                       # iOS native code
│   ├── pubspec.yaml              # Dependencies
│   └── web/                      # Web platform
├── backend/                      # Python FastAPI backend
│   ├── main.py                   # API endpoints
│   ├── engine/                    # Pose analysis engine
│   ├── utils/                     # Utility functions
│   ├── requirements.txt          # Python dependencies
│   └── venv/                     # Virtual environment
├── run_all.bat
├── update_ip.py
└── zip_project.py
```

---

## All Screens & Routes

### Authentication Flow
| Screen | Route | Purpose |
|--------|-------|---------|
| `LandingVideoScreen` | `/landing` | Animated landing page with video background and swipe-to-start gesture |
| `LoginScreen` | `/login` | Email/password authentication + Google Sign-In |

### Onboarding Flow
| Screen | Route | Purpose |
|--------|-------|---------|
| `SetupScreen` | `/setup` | 4-step onboarding wizard: name, body stats, fitness goal, experience level |

### Main App Screens (Bottom Navigation)
| Screen | Route | Purpose |
|--------|-------|---------|
| `DashboardScreen` | `/` | Home screen with daily focus, stats cards, hydration tracker, steps widget |
| `ProfileScreen` | `/profile` | User profile with avatar, stats, settings, voice command toggle |
| `ExercisesScreen` | `/exercises?category=X` | Exercise list filtered by category (chest, back, legs, etc.) |
| `SchedulesScreen` | `/schedules` | 7-day weekly workout planner with drag-to-reorder |
| `LibraryScreen` | `/library` | Exercise library grid showing all body part categories |
| `CalculatorsScreen` | `/calculators` | Body fat calculator, diet plan generator, nutrition calculator |
| `GymsScreen` | `/gyms` | Nearby gyms map with TomTom API integration and search |
| `CoachScreen` | `/coach` | AI coach chat interface with natural language responses |

### Modal/Full Screen Routes
| Screen | Route | Purpose |
|--------|-------|---------|
| `StepsScreen` | `/steps` | Detailed step tracking with day/week/month/year views |
| `WarmupScreen` | `/warmup?exercise=X` | 5-minute animated warmup timer with exercises |
| `WorkoutScreen` | `/workout?exercise=X` | Live workout with real-time pose detection camera |
| `WorkoutSummaryScreen` | `/workout-summary` | Post-workout results with accuracy, duration, reps |

### Floating Components
| Widget | Type | Purpose |
|--------|------|---------|
| `FloatingAiCoach` | FAB | Floating action button that opens AI chat dialog |
| `CoachChatWidget` | Dialog | AI chatbot overlay for quick fitness questions |

---

## Features

### AI Features
- **AI Coach Chat** - Natural language fitness assistant using FastAPI backend with Gemini AI
- **Pose Detection** - Real-time exercise form analysis using MediaPipe 3D Pose Landmarker
- **Voice Commands** - "Start", "Pause", "Finish", "Flip Camera", "Record"
- **Voice Feedback** - Motivational announcements during workout using TTS

### Fitness Tracking
- **Step Counter** - Live pedometer integration with historical data
- **Workout History** - Rep counting, duration tracking, accuracy metrics
- **Weekly Planner** - Custom workout schedules with 7-day view
- **Body Fat Calculator** - Waist-to-height ratio method

### Nutrition
- **Diet Plan Generator** - AI-powered macro calculation via backend
- **Nutrition Tracker** - Food logging interface
- **Macro Calculator** - Calories, protein, carbs, fat calculation
- **Meal Plans** - 7-day personalized meal plans

### Discovery
- **Gym Finder** - Nearby gyms with interactive map view
- **Exercise Library** - 100+ exercises organized by body part
- **YouTube Integration** - Exercise video playback via iframe

### User Management
- **Google Sign-In** - OAuth authentication
- **Email/Password** - Traditional email-based auth
- **Guest Mode** - Limited access without login
- **Profile Customization** - Avatar, stats, preferences

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

## Novel Features & Research Contributions

When building this app, I researched existing fitness apps and academic papers to understand what was already available and where I could add unique value.

### What Makes This App Different

| Feature | What Others Do | What We Built |
|---------|---------------|---------------|
| Pose Detection | 2D only, or mobile/server alone | True 3D with world coordinates + hybrid processing |
| Voice Control | TTS announcements only | Voice commands during live workouts |
| AI Coach | Basic chatbots | Gemini AI with conversation memory |
| Gym Finder | Not implemented in most apps | TomTom API with interactive map |

### My Research Journey

**Pose Detection**
I studied how most apps use 2D estimation. I wanted true 3D depth, so I implemented MediaPipe with worldZ coordinates and built a hybrid system where mobile handles real-time inference while the backend validates using the same landmark format. This gives fast feedback plus accurate analysis.

**Voice Commands**
Most fitness apps just announce counts or encouragement. I wanted hands-free control so users can say "Start", "Pause", or "Flip camera" while working out - no touching the phone needed.

**AI Coach**
I tested GPT chatbots but found Gemini AI gave better contextual responses for fitness advice. The session memory allows it to remember your goals and progress.

**Gym Finder**
I noticed no fitness app helped users find nearby gyms. I integrated TomTom API with an interactive map so users can discover gyms without leaving the app.

### Key Technical Innovations

**Hybrid Mobile + Backend Processing**
- Mobile: Real-time 13-16ms inference using device NPU/GPU
- Backend: Server-side validation using identical MediaPipe landmark format
- Result: Fast feedback plus accurate analysis

**Unified Architecture**
- Built with Clean Architecture plus Riverpod for maintainability
- Single codebase for iOS/Android/Web

### References

- Appiah, M.T. et al. (2024). Mobile pose estimation for gym form correction
- Chung, A.E. et al. (2018). Voice-activated assistants in health apps
- Moulya, S. et al. (2023). AI Voice-Assisted Fitness Coach
- Zhang, Y. et al. (2025). Systematic review of AI fitness apps

---

## Services

| Service | File | Purpose |
|---------|------|---------|
| `ApiService` | api_service.dart | HTTP client for backend API calls (chat, diet, pose) |
| `StorageService` | storage_service.dart | SharedPreferences wrapper for local storage |
| `SupabaseService` | supabase_service.dart | Authentication and database (users table) |
| `NotificationService` | notification_service.dart | Local push notifications with timezone |
| `VoiceService` | voice_service.dart | Text-to-speech and speech-to-text capabilities |
| `ExerciseDataService` | exercise_data_service.dart | Exercise database management from JSON |

### Service Details

#### ApiService
```dart
// Base URL configured in api_constants.dart
// Endpoints:
// - POST /chat - AI coach chat
// - POST /generate_diet - Diet plan generation
// - POST /process_landmarks - Pose detection processing
// - POST /reset - Session reset
// - GET /health - Backend health check
```

#### SupabaseService
```dart
// Manages user authentication via Supabase
// Handles email/password and Google OAuth
// Provides real-time database access
```

#### VoiceService
```dart
// TTS: Motivational messages, rep counting
// STT: Voice commands recognition
// Commands: "Start", "Pause", "Finish", "Flip", "Record"
```

#### ExerciseDataService
```dart
// Loads exercises from assets/exercises.json
// Categories: Chest, Back, Shoulders, Arms, Legs, Abs, Full Body
// Data: name, description, gifUrl, videoUrl, targetMuscles
```

---

## State Management

**Library:** Riverpod 2.5.1

### Providers

| Provider | Type | Purpose |
|----------|------|---------|
| `authProvider` | StateNotifierProvider | Authentication state (logged in, guest, loading) |
| `notificationsProvider` | StateNotifierProvider | Notifications list management |
| `routerProvider` | Provider | GoRouter instance |
| `supabaseServiceProvider` | Provider | Supabase client singleton |

### Auth State Structure
```dart
enum AuthStatus { initial, loading, authenticated, guest, unauthenticated }
```

---

## Dependencies

```yaml
# Core
flutter: sdk
cupertino_icons: ^1.0.8
google_fonts: ^8.0.2

# State & Routing
flutter_riverpod: ^2.5.1
go_router: ^14.2.0

# UI Enhancements
flutter_animate: ^4.5.2
flutter_svg: ^2.0.10
glassmorphism_ui: ^0.3.0
confetti: ^0.8.0

# Networking
http: ^1.6.0

# Backend Services
supabase_flutter: ^2.12.2
google_sign_in: 6.2.1

# Media
camera: ^0.12.0
video_player: ^2.11.1
image_picker: ^1.2.1
youtube_player_iframe: ^5.2.2
webview_flutter: ^4.13.1
webview_flutter_web: ^0.2.3+4
flutter_pose_detection: ^0.4.0

# Utilities
shared_preferences: ^2.5.4
path_provider: ^2.1.5
intl: ^0.20.2
permission_handler: ^12.0.1
url_launcher: ^6.3.2

# Location & Maps
geolocator: ^14.0.2
flutter_map: ^8.2.2
latlong2: ^0.9.1

# Sensors
pedometer: ^4.2.0

# Notifications
flutter_local_notifications: ^21.0.0
timezone: ^0.11.0
flutter_timezone: ^5.0.2

# Voice
flutter_tts: ^4.2.5
speech_to_text: ^7.3.0

# PDF
pdf: ^3.12.0
printing: ^5.14.3

# Gallery
gal: ^2.3.2
```

---

## API Integration

### Backend
- **URL:** `https://fitcoachai-app.onrender.com`
- **Framework:** Python FastAPI
- **Endpoints:**

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/chat` | AI coach conversational responses |
| POST | `/generate_diet` | Generate personalized diet plans |
| POST | `/process_landmarks` | Process ML pose detection landmarks |
| POST | `/reset` | Reset conversation session |
| GET | `/health` | Backend health status check |

### External APIs
| Service | Purpose |
|---------|---------|
| **TomTom API** | Gym location search, geocoding, place details |
| **Supabase** | User authentication, database storage |
| **Google Sign-In** | OAuth 2.0 authentication |

---

## Assets

### Images
| File | Purpose |
|------|---------|
| `icon.png` | App launcher icon |
| `icon1.png`, `icon2.png` | Alternative icons |
| `logo.png` | App logo |
| `welcome.png` | Landing page illustration |
| `download.png` | Download placeholder |

### Media
| File | Purpose |
|------|---------|
| `landing_video.mp4` | Landing page background video |

### Data
| File | Purpose |
|------|---------|
| `exercises.json` | Exercise database with 100+ exercises |

### Exercise JSON Structure
```json
{
  "categories": [
    {
      "name": "Chest",
      "subcategories": [
        {
          "name": "Barbell",
          "exercises": [
            {
              "id": "bench_press",
              "name": "Bench Press",
              "description": "...",
              "gifUrl": "...",
              "videoUrl": "...",
              "targetMuscles": ["pectorals", "triceps", "shoulders"]
            }
          ]
        }
      ]
    }
  ]
}
```

---

## Theme & Styling

### Color Palette
| Color | Hex | Usage |
|-------|-----|-------|
| Primary | `#FF6D00` | Main accent, buttons, highlights |
| Primary Dark | `#E65100` | Pressed states |
| Primary Light | `#FFE0B2` | Light backgrounds |
| Background | `#FFF9F2` | Main background (cream) |
| Surface | `#FFFFFF` | Cards, dialogs |
| Text Primary | `#1A1A1A` | Main text |
| Text Secondary | `#757575` | Subtitle, captions |
| Success | `#4CAF50` | Positive actions |
| Warning | `#FFC107` | Caution states |
| Error | `#F44336` | Error states |

### Typography
- **Font Family:** Outfit (Google Fonts)
- **Weights:** Regular (400), Medium (500), SemiBold (600), Bold (700)

### Design System
- **Style:** Modern with glass morphism effects
- **Corners:** Rounded (16-24dp radius)
- **Shadows:** Soft elevation
- **Cards:** Glassmorphism with blur effect

---

## Navigation

### Router Configuration
- **Library:** GoRouter 14.2.0
- **Type:** Shell routes with persistent bottom navigation

### Route Structure
```
/landing        -> LandingVideoScreen (initial, unauthenticated)
/login         -> LoginScreen
/setup         -> SetupScreen (post-registration)
/loading       -> LoadingScreen (auth check)

Shell Routes (bottom nav bar persistent):
/              -> DashboardScreen
/profile       -> ProfileScreen
/exercises     -> ExercisesScreen
/schedules     -> SchedulesScreen
/history       -> WorkoutHistoryScreen
/library       -> LibraryScreen
/calculators   -> CalculatorsScreen
/gyms          -> GymsScreen

Modal Routes (full screen overlay):
/warmup        -> WarmupScreen
/workout       -> WorkoutScreen
/workout-summary -> WorkoutSummaryScreen
/steps         -> StepsScreen
/coach         -> CoachScreen
```

### Auth Guards
- Unauthenticated users redirected to `/landing`
- Guest users have limited access
- Protected routes check `authProvider` state

---

## Models

| Model | Location | Properties |
|-------|----------|------------|
| `Exercise` | exercise_data_service.dart | id, name, description, gifUrl, videoUrl, targetMuscles |
| `Subcategory` | exercise_data_service.dart | name, exercises list |
| `Category` | exercise_data_service.dart | name, subcategories list |
| `AppNotification` | notification_model.dart | id, title, body, scheduledDate, payload |
| `AuthState` | auth_provider.dart | status, user, error |

---

## Shared Widgets

| Widget | File | Description |
|--------|------|-------------|
| `AppBackground` | app_background.dart | Gradient background container |
| `PrimaryButton` | buttons.dart | Main CTA button with loading state |
| `FloatingAiCoach` | floating_ai_coach.dart | FAB for AI coach chat |
| `GlassCard` | glass_card.dart | Glassmorphism card component |
| `MainLayout` | main_layout.dart | Bottom navigation shell |

---

## Backend Technologies

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

## Platform Support

| Platform | Status |
|----------|--------|
| Android | Full support |
| iOS | Full support |
| Web | Partial (web_utils conditional imports) |

---

## License

MIT License
