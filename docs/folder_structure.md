# Folder Structure

This document details the file and folder layout of the Orbit project.

---

## High-Level Layout

```text
orbit/
├── .github/              # GitHub Action workflows and Issue/PR templates
├── assets/               # Image assets and graphics
├── docs/                 # Project documentation and roadmap blueprints
├── lib/                  # Dart source code folder
│   ├── app/              # Application-wide routing and configuration
│   ├── core/             # Base elements, shared components, and generic utilities
│   │   ├── constants/    # Global constant values
│   │   ├── models/       # Shared models
│   │   ├── providers/    # Shared providers
│   │   ├── utils/        # Generic developer utilities (e.g. AppLogger)
│   │   └── voice/        # Core Speech-to-Text services
│   └── features/         # Modular feature folders (Feature-First Architecture)
│       ├── ai/           # AI request management, sync adapters, prompts, and settings
│       ├── auth/         # Authentication services and login views
│       ├── day/          # Core Daily Summary aggregates
│       ├── decision/     # Decision models and views
│       ├── event/        # Event schemas and views
│       ├── home/         # Home screen overlay elements
│       ├── learning/     # Learning logs and views
│       ├── mood/         # Mood indicators and views
│       ├── reflection/   # Daily reflections and editing boards
│       ├── settings/     # General settings features
│       └── tasks/        # Task models, lists, and managers
└── test/                 # Test suites
```

---

## Feature Folder Layout

Within `lib/features/`, every feature module uses a consistent structure separating concerns:
- **`data/`**: Repositories managing read/write interfaces to cloud datasources or local drafts.
- **`models/`**: Freeze-backed classes for data serialization.
- **`views/`**: View layouts, lists, and forms.
- **`widgets/`**: Private reusable UI widgets used within the views of this feature.
- **`controllers/`** / **`providers/`**: Business logic notifiers updating reactive UI state.
