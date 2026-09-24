# Contributing to Cue

English | [简体中文](CONTRIBUTING.zh.md)

First off, thank you for considering contributing to Cue! It's people like you that make open-source projects thrive.

## How to Contribute

### 1. Discuss Before You Build
For major changes or new features, please **open an issue first** to discuss what you would like to change. This ensures your hard work aligns with the project's direction and saves you time.

### 2. Fork & Branch
1. Fork the repository.
2. Create your feature branch: `git checkout -b feature/my-new-feature` or bugfix branch `git checkout -b fix/my-bugfix`.

### 3. Development Guidelines

**Frontend (Flutter):**
- Ensure your code follows the standard Dart formatting (`dart format`).
- Check for analyzer warnings: `flutter analyze`.
- Write or update tests if applicable, and ensure they pass: `flutter test`.

**Backend (NestJS):**
- Respect the existing ESLint and Prettier configurations.
- For new features, please add or update the relevant tests.
- Ensure integration tests pass:
  ```bash
  # Ensure your test DB container is running
  node --test test/api.integration.test.mjs
  ```

### 4. Commit Conventions
We use [Conventional Commits](https://www.conventionalcommits.org/). Please format your commit messages accordingly (e.g., `feat: add awesome feature`, `fix: resolve login bug`, `docs: update readme`).

### 5. Submit a Pull Request
- Push to your branch: `git push origin feature/my-new-feature`.
- Open a Pull Request against the `main` branch.
- Describe your changes clearly in the PR description. If your PR resolves an existing issue, link it using `Closes #IssueNumber`.

## Bug Reports & Feature Requests
If you find a bug or have a suggestion for improving Cue, please use the GitHub Issue tracker. Ensure you search existing issues to avoid duplicates.

*Note: For security-related issues, please refer to our [Security Policy](SECURITY.md) instead of creating a public issue.*
