# Development Guidelines

This document outlines the standard workflows, commands, and best practices for developing on Orbit.

---

## 1. Code Generation

Orbit uses packages like `freezed` and `json_serializable` for data serialization, which require generated boilerplate code.

Whenever you update models:
- Run the generator once:
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- Or run in watch mode to automatically generate code on file save:
  ```bash
  dart run build_runner watch --delete-conflicting-outputs
  ```

---

## 2. Formatting and Code Style

To keep the codebase consistent:
- Run the code formatter before committing:
  ```bash
  dart format .
  ```
- Run static analysis to check for warnings and errors:
  ```bash
  flutter analyze
  ```

---

## 3. Running Tests

We implement unit and widget tests. Always ensure all tests pass:
- Run all tests:
  ```bash
  flutter test
  ```

---

## 4. Centralized Logging Guidelines

Always avoid using `print` or `debugPrint` directly. Instead, import `package:orbit/core/utils/app_logger.dart` and use the centralized logger:

```dart
import 'package:orbit/core/utils/app_logger.dart';

// Examples
AppLogger.debug('Fine-grained details');
AppLogger.info('High-level workflow events');
AppLogger.warning('Recoverable glitches', exception);
AppLogger.error('Fatal crash or API failure', error, stackTrace);
```
Outputs are automatically suppressed in release mode.
