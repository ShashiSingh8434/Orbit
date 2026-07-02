# Local Workspace Setup Guide

Follow this guide to get Orbit up and running on your local machine.

---

## 1. Prerequisites

Ensure you have the following installed:
- **Flutter SDK**: Stable version (version matching `pubspec.yaml` environment SDK).
- **Dart SDK**: Automatically bundled with Flutter.
- **Android Studio / Xcode**: For emulator setups and device configurations.
- **Git**: For source control management.

---

## 2. Setup Firebase

Orbit relies on Firebase Authentication and Firebase Cloud Firestore for storage.

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/).
2. Add an **Android App** and a **iOS App** to your Firebase project.
3. Download the configuration sheets:
   - For Android: Download `google-services.json` and move it to `android/app/google-services.json`.
   - For iOS: Download `GoogleService-Info.plist` and move it to `ios/Runner/GoogleService-Info.plist`.
4. Enable **Google Sign-In** under **Authentication**.
5. Enable **Cloud Firestore** and configure database rules.

---

## 3. Environment Variables Configuration

Orbit uses environment variables to manage model keys:

1. Copy the template file to `.env`:
   ```bash
   cp .env.example .env
   ```
2. Open `.env` and fill in your keys:
   - `GEMINI_API_KEY`: Google Generative AI API token.
   - `GROQ_API_KEY`: Groq Cloud API token.

---

## 4. Run the Project

1. Retrieve Flutter packages:
   ```bash
   flutter pub get
   ```
2. Verify system setup:
   ```bash
   flutter doctor
   ```
3. Run the development build:
   ```bash
   flutter run
   ```
