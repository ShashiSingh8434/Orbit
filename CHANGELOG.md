# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Released]

## [2.0.0] - 2026-07-04

### Added
- **AI Extraction Pipeline & Reliability**:
  - Restructured the AI reflection parser prompt (`understanding_prompt.dart`) with strict schema validation and constraints (`requiredProperties`), turning the app into a reliable daily companion that extracts events, tasks, decisions, and learnings with high correctness.
  - Added smart context matching to detect duplicate upcoming events and pending tasks, supporting automatic inline updates (e.g., changing due dates, event times, locations, and descriptions) without creating duplicates.
  - Implemented post-analysis notifications via `aiNotificationProvider` that tell the user exactly what got created or updated (e.g., "Insights extracted: 1 task created, 2 events updated").
- **Soothing Space-Themed UI Refresh**:
  - Transformed the app's visual identity into a calming, cosmic space theme.
  - Replaced flat white container styles with translucent card themes (`OrbitCard` using `Color(0xF21E2030)` and `Color(0xF2FFFFFF)`) that float over background layers.
  - Integrated `SubtleSpaceBackground` — an animated background rendering a slow-twinkling starry night and custom solar orbit system that eases visual strain.
  - Refreshed system backgrounds to deep space colors (`Color(0xFF07070F)` cosmic gradient) to match the dark theme and reduce brightness distraction.
- **Improved Bottom Navigation Bar**:
  - Replaced the vertical FAB menu with a horizontal bottom action bar (`BottomActionBar`) configured flush inside the bottom navigation slot, providing a balanced, space-themed edge-to-edge layout.
  - Arranged elements horizontally for clean utility access (Decision, Learning, Reflection +, Event, Task) and wrapped them in custom long-press Tooltips.
  - Implemented dynamic first-run onboarding arrow pointers (`arrow_black.png` and `arrow_light.png`) which adjust automatically to the active theme (black arrow for light theme, light arrow for dark theme).

### Removed
- **Mood Tracking**:
  - Completely stripped the redundant mood tracking cards, inputs, tags, and database average mood values to simplify app utilization.

### Fixed & Improved
- Redesigned custom-styled AppDrawer with a matching cosmic palette and premium transitions.
- Optimized timetables widget sync logic and Android/iOS notch physical border layouts.
- Production build speed and R8/ProGuard configuration files.

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