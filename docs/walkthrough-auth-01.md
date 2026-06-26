# Orbit Refactor — Walkthrough

## Summary

Refactored the Orbit Flutter project from a Riverpod/GoRouter architecture to clean **MVVM + Provider + ChangeNotifier** with a **feature-first folder structure**, a complete **Material 3 theme system** (black & blue, light + dark), persistent **theme preference** (System/Light/Dark), a **redesigned premium login page** with staggered animations, and a **home page with full-featured drawer**.

## Verification

```
flutter analyze → No issues found! (0 errors, 0 warnings, 0 infos)
```

---

## Final Folder Structure

```
lib/
├── main.dart                                    ← Entry point with MultiProvider
├── firebase_options.dart                        ← Untouched
├── app/
│   ├── app.dart                                 ← MaterialApp root
│   └── theme/
│       ├── app_theme.dart                       ← Material 3 light + dark themes
│       └── theme_provider.dart                  ← System/Light/Dark with persistence
├── core/
│   ├── constants/
│   │   └── app_constants.dart                   ← Asset paths, keys, metadata
│   └── widgets/
│       └── orbit_logo.dart                      ← Reusable logo widget
├── features/
│   ├── auth/
│   │   ├── services/
│   │   │   └── auth_service.dart                ← Firebase Auth + Google Sign-In
│   │   ├── provider/
│   │   │   └── auth_provider.dart               ← ChangeNotifier with error handling
│   │   ├── views/
│   │   │   ├── auth_gate.dart                   ← StreamBuilder routing
│   │   │   └── login_page.dart                  ← Premium redesigned login
│   │   └── widgets/
│   │       └── google_sign_in_button.dart        ← Reusable sign-in button
│   └── home/
│       ├── views/
│       │   └── home_page.dart                   ← Home with drawer
│       └── widgets/
│           └── app_drawer.dart                  ← Profile, theme toggle, logout
```

---

## Files Modified

| File | Change |
|---|---|
| [pubspec.yaml](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/pubspec.yaml) | Removed `flutter_riverpod`, `riverpod_annotation`, `go_router`. Added `provider`, `shared_preferences`, `google_fonts` |
| [main.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/main.dart) | Rewritten with `MultiProvider` (ThemeProvider + AuthProvider), `SharedPreferences` init |
| [widget_test.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/test/widget_test.dart) | Replaced stale counter test with placeholder |

## New Files Created

| File | Purpose |
|---|---|
| [app.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/app/app.dart) | `MaterialApp` root with light/dark themes and `ThemeProvider` |
| [app_theme.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/app/theme/app_theme.dart) | Material 3 theme system — black & blue palette, Inter font, full component theming |
| [theme_provider.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/app/theme/theme_provider.dart) | `ChangeNotifier` for System/Light/Dark switching with `SharedPreferences` persistence |
| [app_constants.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/core/constants/app_constants.dart) | Centralized constants (asset paths, prefs keys, app metadata) |
| [orbit_logo.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/core/widgets/orbit_logo.dart) | Reusable logo widget rendering `app_logo.png` |
| [auth_service.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/features/auth/services/auth_service.dart) | Refactored auth service — Google Sign-In, Firestore user creation, sign-out |
| [auth_provider.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/features/auth/provider/auth_provider.dart) | `ChangeNotifier` ViewModel with loading/error state, Firebase error mapping |
| [auth_gate.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/features/auth/views/auth_gate.dart) | Pure routing widget — `StreamBuilder` on `authStateChanges` |
| [login_page.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/features/auth/views/login_page.dart) | Premium login page with staggered animations, responsive layout, error banner |
| [google_sign_in_button.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/features/auth/widgets/google_sign_in_button.dart) | Reusable Google button with `AnimatedSwitcher` loading state |
| [home_page.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/features/home/views/home_page.dart) | Home page with AppBar, drawer, personalized greeting |
| [app_drawer.dart](file:///c:/Shashi%20Singh/Personal%20Projects/Orbit/orbit/lib/features/home/widgets/app_drawer.dart) | Drawer with profile header, theme toggle, settings/about placeholders, logout |

## Files Deleted

| File | Reason |
|---|---|
| `lib/core/app_routes.dart` | GoRouter removed — replaced by StreamBuilder auth gate |
| `lib/core/app_theme.dart` | Replaced by `lib/app/theme/app_theme.dart` |
| `lib/features/auth/auth_gate.dart` | Replaced by `lib/features/auth/views/auth_gate.dart` |
| `lib/features/auth/auth_service.dart` | Replaced by `lib/features/auth/services/auth_service.dart` |
| `lib/features/auth/auth_provider.dart` | Replaced by `lib/features/auth/provider/auth_provider.dart` |
| `lib/features/dashboard/` (entire dir) | Replaced by `lib/features/home/` |

---

## Architectural Decisions

### 1. Riverpod → Provider
Your prompt specifies Provider. Migrated all state management from `flutter_riverpod` `StreamProvider`/`Provider` to `provider` package with `ChangeNotifier`. `AuthProvider` and `ThemeProvider` are the two notifiers, wired via `MultiProvider` in `main.dart`.

### 2. GoRouter → StreamBuilder Auth Gate
Replaced GoRouter's `redirect` + `refreshListenable` pattern with a simpler `StreamBuilder<User?>` in `AuthGate`. This keeps routing logic co-located with the auth feature and eliminates the need for a separate router file. The auth state stream from Firebase automatically triggers navigation.

### 3. MVVM Separation
- **View**: `LoginPage`, `HomePage` — only UI, no auth logic
- **ViewModel**: `AuthProvider` — loading state, error handling, sign-in/out methods
- **Service**: `AuthService` — pure Firebase/Google communication

### 4. Theme System
Black & blue palette using `ColorScheme.fromSeed()` for both light and dark variants. `ThemeProvider` persists the user's choice via `SharedPreferences` and notifies `MaterialApp` for instant updates.

### 5. RadioGroup (Flutter 3.32+)
Used the new `RadioGroup` widget pattern instead of deprecated `RadioListTile.groupValue`/`onChanged`.

---

## Dependency Changes

| Package | Action |
|---|---|
| `flutter_riverpod ^2.5.1` | **Removed** |
| `riverpod_annotation ^2.3.5` | **Removed** |
| `go_router ^14.3.0` | **Removed** |
| `provider ^6.1.2` | **Added** |
| `shared_preferences ^2.3.3` | **Added** |
| `google_fonts ^6.2.1` | **Added** |

---

## Migration Steps

No additional migration needed beyond what was executed:

1. ✅ `pubspec.yaml` updated
2. ✅ `flutter pub get` ran successfully
3. ✅ Old files deleted
4. ✅ New files created in correct locations
5. ✅ `flutter analyze` — 0 issues
6. ✅ Firebase configuration untouched
