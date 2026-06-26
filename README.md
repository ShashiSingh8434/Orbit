# Orbit

An AI-powered personal operating system for students — built with Flutter, Firebase, and Material 3.

Orbit handles the cognitive load of college life: classes, food, tasks, and reflection — all in one place.

## Screenshots

> Coming soon

## Tech Stack

- **Flutter** (Dart)
- **Firebase** (Auth, Firestore)
- **Google Sign-In**
- **Provider** (State Management)
- **Material 3** with dynamic theming

## Getting Started

### Prerequisites

- Flutter SDK `>=3.12.0`
- Dart `>=3.0.0`
- Android Studio / VS Code
- A Firebase project
- Node.js (for FlutterFire CLI)

### 1. Clone the repo

```bash
git clone https://github.com/ShashiSingh8434/Orbit.git
cd orbit
```

### 2. Firebase Setup

Install the FlutterFire CLI if you haven't:

```bash
dart pub global activate flutterfire_cli
```

Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com), then configure it:

```bash
flutterfire configure
```

This generates `lib/firebase_options.dart` with your project credentials.

#### Enable Authentication

1. Go to **Firebase Console → Authentication → Sign-in method**
2. Enable **Google** as a sign-in provider
3. Add your **SHA-1** and **SHA-256** fingerprints (Android):

```bash
cd android
./gradlew signingReport
```

#### Enable Firestore

1. Go to **Firebase Console → Firestore Database**
2. Create a database (start in **test mode** for development)

### 3. Google Sign-In (Android)

Ensure your `android/app/build.gradle` has the correct `applicationId` matching the one registered in Firebase.

For debug builds, Firebase uses the debug SHA-1 from `signingReport`. No additional configuration needed.

### 4. Install dependencies

```bash
flutter pub get
```

### 5. Run

```bash
flutter run
```

## Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── app/
│   ├── app.dart
│   └── theme/
│       ├── app_theme.dart
│       └── theme_provider.dart
├── core/
│   ├── constants/
│   └── widgets/
└── features/
    ├── auth/
    │   ├── services/
    │   ├── provider/
    │   ├── views/
    │   └── widgets/
    └── home/
        ├── views/
        └── widgets/
```

## Architecture

- **MVVM** with feature-first folder structure
- **Views** — UI only, no business logic
- **Providers** — state management via `ChangeNotifier`
- **Services** — Firebase communication layer

## License

MIT
