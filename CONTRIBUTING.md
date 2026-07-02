# Contributing to Orbit

Thank you for your interest in contributing to Orbit! We welcome contributions from developers, designers, and writers of all skill levels.

---

## Code of Conduct

Please treat everyone in the community with respect. We want to keep this space welcoming and friendly.

---

## Getting Started

### 1. Repository Setup

1. **Fork the Repository**: Create your own copy of the repository on GitHub.
2. **Clone the Fork**: Clone your fork to your local system:
   ```bash
   git clone https://github.com/ShashiSingh8434/Orbit.git
   cd Orbit
   ```
3. **Setup Environment**: Copy `.env.example` to `.env` and fill in your model API keys if you plan to test AI functionality locally:
   ```bash
   cp .env.example .env
   ```
4. **Get Dependencies**: Fetch the required Flutter and Dart packages:
   ```bash
   flutter pub get
   ```

### 2. Branch Naming Conventions

Always create a new branch for your changes instead of working directly on the `main` branch. Use the following prefix guidelines:

- `feature/` for new features (e.g. `feature/add-dark-mode`)
- `bugfix/` for bug fixes (e.g. `bugfix/fix-recording-crash`)
- `docs/` for documentation updates (e.g. `docs/improve-setup-guide`)
- `refactor/` for code refactoring with no behavior changes (e.g. `refactor/clean-routing-logic`)

---

## Commit Message Guidelines

We use **Conventional Commits** for commit messages to ensure clean changelogs. A commit message must follow this format:

```text
<type>(<scope>): <description>

[Optional body]
```

### Allowed Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semi-colons, style tweaks (no production code changes)
- `refactor`: Refactoring production code (e.g. renaming variables, extracting methods)
- `test`: Adding missing tests or correcting existing tests
- `chore`: Build tasks, package manager configurations, environment updates

### Example

```text
feat(reflection): add tag validation to reflection creation form
```

---

## Code Style & Formatting

### 1. Formatting
We strictly follow standard Dart formatting. Before committing any code, run:
```bash
dart format .
```

### 2. Static Analysis
Ensure there are no warnings or errors reported by the static analyzer:
```bash
flutter analyze
```

---

## Pull Request Process

1. **Keep it atomic**: Submit pull requests for single issues rather than bundling multiple unrelated updates.
2. **Run Tests**: Ensure all existing unit and widget tests pass:
   ```bash
   flutter test
   ```
3. **Submit PR**: Open a pull request against Orbit's `main` branch. Provide a clear description of the problem solved and link any related issues.
4. **Review**: The maintainers will review your code. Be prepared to address feedback!

---

## Reporting Issues

If you find a bug or have a feature suggestion, please open an issue on GitHub. Use the appropriate template:
- **Bug Report**: Provide clear steps to reproduce, actual vs. expected behavior, and device logs if available.
- **Feature Request**: Explain the use case and describe how the proposed feature would work.
