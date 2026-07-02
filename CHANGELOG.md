# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Added
- Open source infrastructure setup: GitHub Action workflows, Dependabot, Pull Request, and Issue templates.
- Explicit developer onboarding documentation in the `docs/` directory.

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
