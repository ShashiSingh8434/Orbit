# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Released]

## [1.0.1] - 2026-07-03

### Added
- **Academic Timetable Planner**:
  - Integrated AI-powered multimodal extraction using Groq fallback LLM models (`llama-4-scout-17b`, `qwen3.6-27b`) to parse uploaded timetable screenshots automatically.
  - Multi-day swipeable calendar interface with weekday navigation chips.
  - Interactive Course Directory to view, search, and manage enrolled courses (credits, faculty, slots).
  - Course editor allowing manual additions, edits, and deletions of classes and slots.
- **Home Screen Widget & Pinning**:
  - Native Android home screen widget to show the daily academic schedule at a glance.
  - `WidgetSyncService` to serialize and push updated schedules to native home screens.
  - One-click native Android interactive widget pinning using platform MethodChannels (`com.example.orbit/widget_pin`).

### Changed
- Centralized all console logging to use the secure `AppLogger` utility.
- Enabled native JSON schema validation for Google Gemini Provider API calls.

## [1.0.0] - 2026-07-02

### Added
- Initial release of Orbit — AI-powered Personal Operating System for students.
- Speech-to-text input system allowing voice recording for reflections.
- Integration of Google Gemini and Groq fallback transcription modules.
- Under-the-hood AI sync adapters translating reflections into tasks, decisions, learnings, events, and mood updates.
- Theme notifier allowing dynamic dark mode toggling.