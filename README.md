# SenseFood 🌿

> Connect your diet with your physical environment.

SenseFood is a Flutter mobile application developed for CASA0015: Mobile Systems & Interactions. It bridges the gap between nutrition tracking and ambient environmental sensing — when you log a meal, the app simultaneously captures your location and ambient noise level, creating a rich picture of *where* and *how* you eat.

---

## 📱 Download

[![Latest Release](https://img.shields.io/github/v/release/HCSSSSSS/casa0015-mobile-assessment)](https://github.com/HCSSSSSS/casa0015-mobile-assessment/releases/latest)

---

## ✨ Features

- **AI Food Recognition** — Snap a photo or describe your meal; Gemini 2.5 Flash returns calories, protein, carbs, and fat in seconds
- **Ambient Sensing** — Microphone captures real-time decibel levels; GPS records your location at the moment of eating
- **Calorie Dashboard** — Custom-painted progress ring with weekly calendar; tap any date to see that day's data
- **Monthly Heat Map** — Switch to month view; days glow green based on calorie intake intensity
- **Meal Map** — Google Maps view of every meal you've logged, colour-coded by calorie level
- **My Journal** — Chronological history of all meals grouped by date, with noise and location context
- **Personalised Goals** — Onboarding flow collects weight, age, and daily calorie target; synced to Firebase
- **Secure & Cross-device** — Firebase Auth + Firestore; data follows you across devices

---

## 🛠 Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter (Dart) |
| AI | Google Gemini 2.5 Flash |
| Backend | Firebase Auth + Cloud Firestore |
| Sensors | `geolocator`, `noise_meter`, `geocoding` |
| Maps | Google Maps Flutter SDK |
| State | Provider |
| Security | `flutter_dotenv` |

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK ≥ 3.10.7
- A Firebase project with Auth and Firestore enabled
- Google Gemini API key
- Google Maps API key

### Setup

```bash
git clone https://github.com/HCSSSSSS/casa0015-mobile-assessment.git
cd casa0015-mobile-assessment
flutter pub get
```

Create a `.env` file in the project root:
GEMINI_API_KEY=your_gemini_key_here

Create `android/local.properties` and add:
MAPS_API_KEY=your_maps_key_here

Replace `android/app/google-services.json` with your own Firebase config file.

```bash
flutter run
```

---

## 📸 Screenshots

| Login | Onboarding | Dashboard |
|---|---|---|
| ![Login](screenshots/login.png) | ![Onboarding](screenshots/onboarding.png) | ![Dashboard](screenshots/dashboard.png) |

| Camera Menu | AI Analyzing | AI Result |
|---|---|---|
| ![Camera](screenshots/camera_menu.png) | ![Analyzing](screenshots/analyzing.png) | ![Result](screenshots/ai_result.png) |

| Map | Journal | Settings |
|---|---|---|
| ![Map](screenshots/map.png) | ![Journal](screenshots/journal.png) | ![Settings](screenshots/settings.png) |

---

## 📁 Project Structure
lib/
├── main.dart              # App entry, navigation, dashboard
├── providers/
│   └── sensor_provider.dart   # Global state: sensors, calories, nutrients
├── screens/
│   ├── login_screen.dart      # Sign in / Register
│   ├── onboarding_screen.dart # First-time setup
│   ├── map_screen.dart        # Meal map
│   ├── journal_screen.dart    # Meal history
│   └── settings_screen.dart  # Profile & goals
└── service/
├── ai_service.dart        # Gemini API integration
└── database_service.dart  # Firestore read/write

---

## 🔒 Security

- API keys stored in `.env` (gitignored)
- `firebase_options.dart` excluded from version control
- Firestore rules require authenticated users only

---

## 📄 License

MIT
