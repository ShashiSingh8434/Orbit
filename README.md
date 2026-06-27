# Orbit

An AI-powered personal operating system for students — built with Flutter, Firebase, and Material 3.

Orbit handles the cognitive load of student life by allowing you to braindump your day in a single reflection. Orbit's AI brain parses your text and automatically organizes your classes, tasks, decisions, learnings, and mood.

## ✨ Features

- **Smart Reflection:** Write your daily thoughts naturally; Orbit automatically extracts structured Tasks, Events, Decisions, Learnings, and Moods.
- **AI Infrastructure Layer:** Robust multi-provider AI system (Google Gemini & Groq).
  - *Automatic Fallback:* If a provider hits a rate limit or goes offline, Orbit seamlessly fails over to another provider.
  - *Secure Keys:* Connect your own API keys, encrypted locally using `flutter_secure_storage`.
  - *Analytics Dashboard:* Track your AI token usage, request latency, and provider health in real-time.
- **Detailed Daily Summaries:** Choose between paragraph or bullet-point summaries of your day.
- **Modern UI/UX:** Space-themed custom splash screen, interactive "Slide to Sign In" slider, and Material 3 dynamic color theming.

## 🛠️ Tech Stack

- **Flutter** (Dart)
- **Firebase** (Auth, Firestore)
- **Riverpod** (State Management & Dependency Injection)
- **Gemini & Groq** (Generative AI)
- **Material 3** 

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.12.0`
- Dart `>=3.0.0`
- A Firebase project
- API Keys for Google Gemini (and optionally Groq)

### 1. Clone the repo

```bash
git clone https://github.com/ShashiSingh8434/Orbit.git
cd orbit
```

### 2. Environment Variables

Orbit uses a `.env` file to manage default API keys. Create a `.env` file in the root directory:

```bash
cp .env.example .env
```
Add your API keys to the `.env` file:
```env
GEMINI_API_KEY=your_gemini_key_here
GROQ_API_KEY=your_groq_key_here
```

### 3. Firebase Setup

Install the FlutterFire CLI if you haven't:

```bash
dart pub global activate flutterfire_cli
```

Configure your Firebase project:

```bash
flutterfire configure
```

#### Enable Authentication
1. Go to **Firebase Console → Authentication → Sign-in method**
2. Enable **Google** as a sign-in provider.
3. Add your **SHA-1** fingerprint (required for Android Google Sign-In).

#### Enable Firestore
1. Go to **Firebase Console → Firestore Database**
2. Create a database (start in **test mode** for development).

### 4. Install dependencies

```bash
flutter pub get
```

### 5. Run

```bash
flutter run
```

## 🏗️ Architecture

- **Feature-First Architecture:** Code is organized by domain (`ai`, `auth`, `day`, `event`, `tasks`, etc.) rather than by layer.
- **Riverpod Providers:** Heavy use of Riverpod for immutable state management, data caching, and dependency injection.
- **AI Abstraction Layer:** The `AiRequestManager` handles queueing, rate limits, and provider failovers to ensure reliable AI inferences regardless of the underlying SDK.


